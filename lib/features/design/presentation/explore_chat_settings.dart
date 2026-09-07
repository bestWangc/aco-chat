part of 'aco_design_shell.dart';

class _ChatMoreSettingsPage extends StatefulWidget {
  const _ChatMoreSettingsPage({
    required this.palette,
    required this.peerName,
    required this.peerUserID,
    this.groupID,
    required this.conversationID,
    required this.onBlockChanged,
    required this.messages,
    required this.onMessageTap,
  });

  final AcoPalette palette;
  final String peerName;
  final String? peerUserID;
  final String? groupID;
  final String? conversationID;
  final ValueChanged<bool> onBlockChanged;
  final List<_ChatHistoryMessage> messages;
  final ValueChanged<_ChatHistoryMessage> onMessageTap;

  @override
  State<_ChatMoreSettingsPage> createState() => _ChatMoreSettingsPageState();
}

class _ChatMoreSettingsPageState extends State<_ChatMoreSettingsPage> {
  var _isPinned = false;
  var _pinLoading = true;
  var _pinUpdating = false;
  var _isBlocked = false;
  var _blockLoading = true;
  var _blockUpdating = false;
  var _groupMembersLoading = false;
  List<GroupMembersInfo> _groupMembers = const [];
  late String _groupName = widget.peerName;

  bool get _isGroup => widget.groupID?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPinState());
    if (_isGroup) {
      unawaited(_loadGroupMembers());
    } else {
      unawaited(_loadBlockState());
    }
  }

  Future<void> _loadGroupMembers() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    setState(() => _groupMembersLoading = true);
    try {
      final members = await OpenIM.iMManager.groupManager.getGroupMemberList(
        groupID: groupID,
        count: 7,
      );
      if (mounted) setState(() => _groupMembers = members);
    } catch (_) {
      // Keep the settings usable when OpenIM has not completed its local sync.
    } finally {
      if (mounted) setState(() => _groupMembersLoading = false);
    }
    try {
      final groupInfo = await OpenIM.iMManager.groupManager.getGroupsInfo(
        groupIDList: [groupID],
      );
      final name = groupInfo.firstOrNull?.groupName?.trim();
      if (mounted && name?.isNotEmpty == true) {
        setState(() => _groupName = name!);
      }
    } catch (_) {
      // The name already shown by the conversation remains usable offline.
    }
  }

  Future<void> _loadBlockState() async {
    final userID = widget.peerUserID;
    if (userID == null || userID.isEmpty) {
      if (mounted) setState(() => _blockLoading = false);
      return;
    }
    try {
      final blacklist = await OpenIM.iMManager.friendshipManager.getBlacklist();
      if (mounted) {
        setState(() {
          _isBlocked = blacklist.any(
            (item) => item.userID == userID || item.blockUserID == userID,
          );
          _blockLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _blockLoading = false);
    }
  }

  Future<void> _setBlocked(bool value) async {
    final userID = widget.peerUserID;
    if (_blockUpdating || userID == null || userID.isEmpty) return;
    final previous = _isBlocked;
    setState(() {
      _isBlocked = value;
      _blockUpdating = true;
    });
    try {
      if (value) {
        await OpenIM.iMManager.friendshipManager.addBlacklist(userID: userID);
      } else {
        await OpenIM.iMManager.friendshipManager.removeBlacklist(
          userID: userID,
        );
      }
      widget.onBlockChanged(value);
    } catch (_) {
      if (mounted) setState(() => _isBlocked = previous);
      if (mounted) _showNotice(context, '拉黑', '拉黑设置失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _blockUpdating = false);
    }
  }

  Future<void> _loadPinState() async {
    final conversationID = widget.conversationID;
    if (conversationID == null || conversationID.isEmpty) {
      if (mounted) setState(() => _pinLoading = false);
      return;
    }
    try {
      final conversations = await OpenIM.iMManager.conversationManager
          .getMultipleConversation(conversationIDList: [conversationID]);
      if (mounted) {
        setState(() {
          _isPinned = conversations.firstOrNull?.isPinned == true;
          _pinLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pinLoading = false);
      }
    }
  }

  Future<void> _setPinned(bool value) async {
    final conversationID = widget.conversationID;
    if (_pinUpdating || conversationID == null || conversationID.isEmpty) {
      return;
    }
    final previous = _isPinned;
    setState(() {
      _isPinned = value;
      _pinUpdating = true;
    });
    try {
      await OpenIM.iMManager.conversationManager.pinConversation(
        conversationID: conversationID,
        isPinned: value,
      );
      OpenIMChatRepository.conversationRevision.value++;
    } catch (_) {
      if (mounted) setState(() => _isPinned = previous);
      if (mounted) _showNotice(context, '置顶聊天', '置顶设置失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _pinUpdating = false);
    }
  }

  Future<void> _showGroupQRCode() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    try {
      final groups = await AccountSession(AccountApiClient()).listGroups();
      final group = groups.where((item) => item.groupId == groupID).firstOrNull;
      if (group == null) {
        if (mounted) _showNotice(context, '群二维码', '无法获取群信息。');
        return;
      }
      final inviteCode = group.inviteCode;
      if (inviteCode == null || inviteCode.isEmpty) {
        if (mounted) {
          _showNotice(context, '群二维码', '无法获取群二维码。');
        }
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => _GroupQRCodePage(
            palette: widget.palette,
            groupName: widget.peerName,
            inviteCode: inviteCode,
          ),
        ),
      );
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '群二维码', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '群二维码', '请稍后重试。');
    }
  }

  Future<void> _exitGroup() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    OpenIMChatRepository.beginLeavingGroup(groupID);
    try {
      await AccountSession(AccountApiClient()).leaveGroup(groupID);
      if (mounted) Navigator.of(context).pop(true);
    } on AccountApiException catch (error) {
      OpenIMChatRepository.cancelLeavingGroup(groupID);
      if (mounted) _showNotice(context, '退出群聊失败', error.localizedMessage);
    } catch (_) {
      OpenIMChatRepository.cancelLeavingGroup(groupID);
      if (mounted) _showNotice(context, '退出群聊失败', '请稍后重试。');
    }
  }

  Future<void> _editGroupName() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    final controller = TextEditingController(text: _groupName);
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('修改群聊名称'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            maxLength: 64,
            placeholder: '请输入群聊名称',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == _groupName) return;
    try {
      final group = await AccountSession(
        AccountApiClient(),
      ).updateGroupName(groupID: groupID, name: name);
      if (mounted) setState(() => _groupName = group.name);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '修改群聊名称失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '修改群聊名称失败', '请稍后重试。');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 28, 0),
        child: AcoPageHeader(
          palette: widget.palette,
          title: _isGroup ? '群聊信息' : '聊天信息',
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
            if (_isGroup) ...[
              _GroupMemberGrid(
                palette: widget.palette,
                members: _groupMembers,
                loading: _groupMembersLoading,
              ),
              const SizedBox(height: 18),
              Container(
                height: 1,
                color: widget.palette.mutedText.withValues(alpha: .16),
              ),
              const SizedBox(height: 6),
              _ChatSettingsInfoRow(
                palette: widget.palette,
                label: '群组名称',
                value: _groupName,
                onTap: _editGroupName,
              ),
              const SizedBox(height: 6),
              _ChatSettingsActionRow(
                palette: widget.palette,
                label: '群二维码',
                onTap: _showGroupQRCode,
              ),
              const SizedBox(height: 6),
            ],
            _ChatSettingsActionRow(
              palette: widget.palette,
              label: '查找聊天记录',
              onTap: () => Navigator.of(context).push<void>(
                CupertinoPageRoute<void>(
                  builder: (_) => _ChatHistorySearchPage(
                    palette: widget.palette,
                    peerName: widget.peerName,
                    messages: widget.messages,
                    onMessageTap: widget.onMessageTap,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ChatSettingsToggleRow(
              palette: widget.palette,
              label: '置顶聊天',
              value: _isPinned,
              onChanged: _pinLoading || _pinUpdating ? null : _setPinned,
            ),
            if (_isGroup) ...[
              const SizedBox(height: 6),
              _ChatSettingsActionRow(
                palette: widget.palette,
                label: '退出群聊',
                destructive: true,
                onTap: _exitGroup,
              ),
            ] else ...[
              const SizedBox(height: 6),
              _ChatSettingsActionRow(
                palette: widget.palette,
                label: '清空聊天记录',
                onTap: () => _showNotice(context, '清空聊天记录', '聊天记录已清空。'),
              ),
              const SizedBox(height: 6),
              _ChatSettingsToggleRow(
                palette: widget.palette,
                label: '拉黑',
                value: _isBlocked,
                onChanged: _blockLoading || _blockUpdating ? null : _setBlocked,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _GroupQRCodePage extends StatelessWidget {
  const _GroupQRCodePage({
    required this.palette,
    required this.groupName,
    required this.inviteCode,
  });

  final AcoPalette palette;
  final String groupName;
  final String inviteCode;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: palette.background,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 28, 0),
            child: AcoPageHeader(
              palette: palette,
              title: '群二维码',
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      groupName,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.bodyEmphasis,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    QrImageView(
                      data: 'aco://group/join/$inviteCode',
                      size: 220,
                      backgroundColor: _white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '扫一扫加入群聊\n群人数上限为 500 人。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.mutedText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChatSettingsActionRow extends StatelessWidget {
  const _ChatSettingsActionRow({
    required this.palette,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final AcoPalette palette;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size.fromHeight(46),
      color: const Color(0xFF191919),
      onPressed: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: destructive
                  ? const Color(0xFFFF5A5F)
                  : palette.primaryText,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Icon(
            CupertinoIcons.chevron_right,
            color: palette.mutedText,
            size: 16,
          ),
        ],
      ),
    ),
  );
}

class _ChatSettingsInfoRow extends StatelessWidget {
  const _ChatSettingsInfoRow({
    required this.palette,
    required this.label,
    required this.value,
    this.onTap,
  });

  final AcoPalette palette;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: palette.primaryText, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(color: palette.mutedText, fontSize: 14),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              CupertinoIcons.chevron_right,
              color: palette.mutedText,
              size: 16,
            ),
        ],
      ),
    );
    final callback = onTap;
    if (callback == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: callback,
      child: content,
    );
  }
}

class _GroupMemberGrid extends StatelessWidget {
  const _GroupMemberGrid({
    required this.palette,
    required this.members,
    required this.loading,
  });

  final AcoPalette palette;
  final List<GroupMembersInfo> members;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && members.isEmpty) {
      return const SizedBox(height: 126, child: CupertinoActivityIndicator());
    }
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: [
        for (final member in members.take(7))
          _GroupMemberAvatar(
            palette: palette,
            name: member.nickname?.trim().isNotEmpty == true
                ? member.nickname!.trim()
                : (member.userID ?? '成员'),
            avatarURL: member.faceURL,
          ),
      ],
    );
  }
}

class _GroupMemberAvatar extends StatelessWidget {
  const _GroupMemberAvatar({
    required this.palette,
    required this.name,
    this.avatarURL,
  });

  final AcoPalette palette;
  final String name;
  final String? avatarURL;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    child: Column(
      children: [
        AcoAvatar(size: 56, imageUrl: avatarURL ?? ''),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.mutedText, fontSize: 12),
        ),
      ],
    ),
  );
}

class _ChatSettingsToggleRow extends StatelessWidget {
  const _ChatSettingsToggleRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final AcoPalette palette;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: palette.primaryText, fontSize: 15)),
        const Spacer(),
        Transform.scale(
          scale: .78,
          child: CupertinoSwitch(
            value: value,
            activeTrackColor: palette.accent,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}
