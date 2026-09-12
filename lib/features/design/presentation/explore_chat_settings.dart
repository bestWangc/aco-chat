part of 'aco_design_shell.dart';

const _maxGroupMemberCount = 19;
const _memberGridColumnCount = 5;
const _memberGridSpacing = 12.0;
const _settingsArrowAsset = 'assets/images/right_arrow.png';

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
    required this.onClearMessages,
  });

  final AcoPalette palette;
  final String peerName;
  final String? peerUserID;
  final String? groupID;
  final String? conversationID;
  final ValueChanged<bool> onBlockChanged;
  final List<_ChatHistoryMessage> messages;
  final ValueChanged<_ChatHistoryMessage> onMessageTap;
  final Future<void> Function() onClearMessages;

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
  var _isGroupOwner = false;
  List<GroupMembersInfo> _groupMembers = const [];
  Map<String, int> _identityByUserID = const {};
  Map<String, int> _staffIdentityByUserID = const {};
  late String _groupName = widget.peerName;

  bool get _isGroup => widget.groupID?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPinState());
    if (_isGroup) {
      unawaited(_loadGroupMembers());
      unawaited(_loadGroupOwnership());
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
        count: _maxGroupMemberCount,
      );
      if (mounted) {
        setState(() => _groupMembers = members);
        unawaited(_loadMemberIdentities(members));
      }
    } catch (_) {
      // Keep the settings usable when OpenIM has not completed its local sync.
    } finally {
      if (mounted) setState(() => _groupMembersLoading = false);
    }
    try {
      final groupInfo = await OpenIM.iMManager.groupManager.getGroupsInfo(
        groupIDList: [groupID],
      );
      final info = groupInfo.firstOrNull;
      final name = info?.groupName?.trim();
      if (mounted) {
        setState(() {
          if (name?.isNotEmpty == true) _groupName = name!;
          _isGroupOwner =
              info?.ownerUserID == OpenIMChatRepository.currentUserID;
        });
      }
    } catch (_) {
      // The name already shown by the conversation remains usable offline.
    }
  }

  Future<void> _loadMemberIdentities(List<GroupMembersInfo> members) async {
    final client = AccountApiClient();
    final session = AccountSession(client);
    try {
      final profiles = await Future.wait(
        members.take(_maxGroupMemberCount).map((member) async {
          final userID = member.userID;
          if (userID == null || userID.isEmpty) return null;
          try {
            final profile = await session.profileByAccountId(userID);
            return MapEntry(userID, profile);
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _identityByUserID = {
          for (final entry
              in profiles.whereType<MapEntry<String, AccountProfile>>())
            if (entry.value.identity > 0) entry.key: entry.value.identity,
        };
        _staffIdentityByUserID = {
          for (final entry
              in profiles.whereType<MapEntry<String, AccountProfile>>())
            if (entry.value.staffIdentity > 0)
              entry.key: entry.value.staffIdentity,
        };
      });
    } finally {
      client.close();
    }
  }

  Future<void> _loadGroupOwnership() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    final client = AccountApiClient();
    try {
      final groups = await AccountSession(client).listGroups();
      final group = groups.where((item) => item.groupId == groupID).firstOrNull;
      if (mounted && group != null) {
        setState(() => _isGroupOwner = group.isOwner);
      }
    } catch (_) {
      // OpenIM group information remains the fallback while offline.
    } finally {
      client.close();
    }
  }

  Future<void> _loadBlockState() async {
    final userID = widget.peerUserID;
    if (userID == null || userID.isEmpty) {
      if (mounted) setState(() => _blockLoading = false);
      return;
    }
    try {
      final blacklistedUserIDs =
          await OpenIMChatRepository.blacklistedUserIDs();
      if (mounted) {
        setState(() {
          _isBlocked = blacklistedUserIDs.contains(userID);
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
      OpenIMChatRepository.invalidateBlacklistCache();
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

  Future<void> _openAddMembers() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    final memberIDs = _groupMembers
        .map((member) => member.userID)
        .whereType<String>()
        .where((userID) => userID.isNotEmpty)
        .toSet();
    final added = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => _GroupMemberSelectionPage(
          palette: widget.palette,
          groupID: groupID,
          existingMemberIDs: memberIDs,
        ),
      ),
    );
    if (mounted && added == true) {
      unawaited(_refreshGroupMembersAfterInvite());
    }
  }

  Future<void> _refreshGroupMembersAfterInvite() async {
    // OpenIM delivers the membership update asynchronously after the invite
    // request succeeds. Refresh a few times so the grid reflects the server
    // state without requiring the user to leave and reopen this page.
    for (final delay in const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
    ]) {
      await Future<void>.delayed(delay);
      if (!mounted) return;
      await _loadGroupMembers();
    }
  }

  Future<void> _exitGroup() async {
    final groupID = widget.groupID;
    if (groupID == null || groupID.isEmpty) return;
    if (!await _confirm(
      title: '退出群聊',
      content: '退出后将不再接收该群消息。',
      action: '退出',
      destructive: true,
    )) {
      return;
    }
    OpenIMChatRepository.beginLeavingGroup(groupID);
    try {
      await AccountSession(AccountApiClient()).leaveGroup(groupID);
      OpenIMChatRepository.completeLeavingGroup();
      if (mounted) Navigator.of(context).pop(true);
    } on AccountApiException catch (error) {
      OpenIMChatRepository.cancelLeavingGroup(groupID);
      if (mounted) _showNotice(context, '退出群聊失败', error.localizedMessage);
    } catch (_) {
      OpenIMChatRepository.cancelLeavingGroup(groupID);
      if (mounted) _showNotice(context, '退出群聊失败', '请稍后重试。');
    }
  }

  Future<void> _dismissGroup() async {
    final groupID = widget.groupID;
    if (!_isGroupOwner || groupID == null || groupID.isEmpty) return;
    if (!await _confirm(
      title: '解散群聊',
      content: '解散后所有成员将无法继续访问该群。',
      action: '解散',
      destructive: true,
    )) {
      return;
    }
    OpenIMChatRepository.beginLeavingGroup(groupID);
    try {
      await AccountSession(AccountApiClient()).dismissGroup(groupID);
      OpenIMChatRepository.completeLeavingGroup();
      if (mounted) Navigator.of(context).pop(true);
    } on AccountApiException catch (error) {
      OpenIMChatRepository.cancelLeavingGroup(groupID);
      if (mounted) _showNotice(context, '解散群聊失败', error.localizedMessage);
    } catch (_) {
      OpenIMChatRepository.cancelLeavingGroup(groupID);
      if (mounted) _showNotice(context, '解散群聊失败', '请稍后重试。');
    }
  }

  Future<void> _clearMessages() async {
    if (!await _confirm(
      title: '清空聊天记录',
      content: '仅清空当前设备上的聊天记录，此操作无法恢复。',
      action: '清空',
      destructive: true,
    )) {
      return;
    }
    try {
      await widget.onClearMessages();
      if (mounted) _showNotice(context, '已清空', '当前聊天记录已清空。');
    } catch (_) {
      if (mounted) _showNotice(context, '清空聊天记录失败', '请稍后重试。');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    required String action,
    required bool destructive,
  }) async =>
      await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _editGroupName() async {
    final groupID = widget.groupID;
    if (!_isGroupOwner || groupID == null || groupID.isEmpty) return;
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
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          children: [
            if (_isGroup) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _GroupMemberGrid(
                  palette: widget.palette,
                  members: _groupMembers,
                  loading: _groupMembersLoading,
                  identityByUserID: _identityByUserID,
                  staffIdentityByUserID: _staffIdentityByUserID,
                  onAddPressed: _openAddMembers,
                ),
              ),
              const SizedBox(height: 18),
              _GroupSettingsCard(
                palette: widget.palette,
                groupName: _groupName,
                onEditName: _isGroupOwner ? _editGroupName : null,
                onShowQRCode: _showGroupQRCode,
              ),
              const SizedBox(height: 6),
            ],
            _ChatSettingsActionRow(
              palette: widget.palette,
              label: '查找聊天内容',
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
              if (_isGroupOwner) ...[
                _ChatSettingsActionRow(
                  palette: widget.palette,
                  label: '解散群聊',
                  destructive: true,
                  onTap: _dismissGroup,
                ),
              ],
            ] else ...[
              const SizedBox(height: 6),
              _ChatSettingsActionRow(
                palette: widget.palette,
                label: '清空聊天记录',
                onTap: _clearMessages,
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
      if (_isGroup)
        Padding(
          padding: const EdgeInsets.fromLTRB(44, 12, 44, 20),
          child: _GroupExitButton(onPressed: _exitGroup),
        ),
    ],
  );
}

class _GroupExitButton extends StatelessWidget {
  const _GroupExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.fromHeight(52),
    onPressed: onPressed,
    child: SizedBox(
      height: 52,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x99EB4B6E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEB4B6E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                '退出群聊',
                style: TextStyle(
                  color: _white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
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
    child: AcoSafeArea(
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
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size.fromHeight(58),
    onPressed: onTap,
    child: Container(
      height: 58,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF191919),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: destructive
                  ? const Color(0xFFFF5A5F)
                  : palette.primaryText,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Image.asset(_settingsArrowAsset, width: 7, fit: BoxFit.contain),
        ],
      ),
    ),
  );
}

class _GroupSettingsCard extends StatelessWidget {
  const _GroupSettingsCard({
    required this.palette,
    required this.groupName,
    required this.onEditName,
    required this.onShowQRCode,
  });

  final AcoPalette palette;
  final String groupName;
  final VoidCallback? onEditName;
  final VoidCallback onShowQRCode;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          _GroupSettingsCardRow(
            palette: palette,
            label: '群聊名称',
            value: groupName,
            onTap: onEditName,
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: palette.mutedText.withValues(alpha: .12),
          ),
          _GroupSettingsCardRow(
            palette: palette,
            label: '群二维码',
            trailing: const Icon(CupertinoIcons.qrcode, size: 24),
            onTap: onShowQRCode,
          ),
        ],
      ),
    ),
  );
}

class _GroupSettingsCardRow extends StatelessWidget {
  const _GroupSettingsCardRow({
    required this.palette,
    required this.label,
    required this.onTap,
    this.value,
    this.trailing,
  });

  final AcoPalette palette;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final callback = onTap;
    final rightContent = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (value?.isNotEmpty == true)
          Flexible(
            child: Text(
              value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.primaryText, fontSize: 18),
            ),
          ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          IconTheme(
            data: IconThemeData(color: palette.primaryText),
            child: trailing!,
          ),
        ],
        if (callback != null) ...[
          const SizedBox(width: 12),
          Image.asset(_settingsArrowAsset, width: 7, fit: BoxFit.contain),
        ],
      ],
    );
    final right = callback == null
        ? rightContent
        : CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            alignment: Alignment.centerRight,
            onPressed: callback,
            child: rightContent,
          );
    final content = SizedBox(
      height: 58,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(color: palette.primaryText, fontSize: 18),
            ),
            Expanded(child: right),
          ],
        ),
      ),
    );
    return content;
  }
}

class _GroupMemberGrid extends StatelessWidget {
  const _GroupMemberGrid({
    required this.palette,
    required this.members,
    required this.loading,
    required this.identityByUserID,
    required this.staffIdentityByUserID,
    required this.onAddPressed,
  });

  final AcoPalette palette;
  final List<GroupMembersInfo> members;
  final bool loading;
  final Map<String, int> identityByUserID;
  final Map<String, int> staffIdentityByUserID;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    if (loading && members.isEmpty) {
      return const SizedBox(height: 126, child: CupertinoActivityIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const columnCount = _memberGridColumnCount;
        const spacing = _memberGridSpacing;
        final itemWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: 14,
          children: [
            for (final member in members.take(_maxGroupMemberCount))
              _GroupMemberAvatar(
                width: itemWidth,
                palette: palette,
                name: member.nickname?.trim().isNotEmpty == true
                    ? member.nickname!.trim()
                    : (member.userID ?? '成员'),
                avatarURL: member.faceURL,
                identity: identityByUserID[member.userID] ?? 0,
                staffIdentity: staffIdentityByUserID[member.userID] ?? 0,
              ),
            _GroupAddMemberButton(width: itemWidth, onPressed: onAddPressed),
          ],
        );
      },
    );
  }
}

class _GroupMemberAvatar extends StatelessWidget {
  const _GroupMemberAvatar({
    required this.width,
    required this.palette,
    required this.name,
    required this.identity,
    required this.staffIdentity,
    this.avatarURL,
  });

  final double width;
  final AcoPalette palette;
  final String name;
  final int identity;
  final int staffIdentity;
  final String? avatarURL;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      children: [
        AcoAvatar(size: 52, imageUrl: avatarURL ?? ''),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: identity == 0
                      ? palette.mutedText
                      : _identityColor(identity, palette),
                  fontSize: 12,
                ),
              ),
            ),
            if (_identityNodeAsset(identity) case final badgeAsset?) ...[
              const SizedBox(width: 2),
              Image.asset(
                badgeAsset,
                width: _shortBadgeWidth(identity),
                fit: BoxFit.contain,
              ),
            ],
            if (_staffBadgeAsset(staffIdentity) case final staffAsset?) ...[
              const SizedBox(width: 2),
              Image.asset(
                staffAsset,
                width: _shortBadgeWidth(staffIdentity),
                fit: BoxFit.contain,
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _GroupAddMemberButton extends StatelessWidget {
  const _GroupAddMemberButton({required this.width, required this.onPressed});

  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onPressed,
          child: Image.asset(
            'assets/images/add_group_member.png',
            width: 52,
            height: 52,
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

class _GroupMemberSelectionPage extends StatefulWidget {
  const _GroupMemberSelectionPage({
    required this.palette,
    required this.groupID,
    required this.existingMemberIDs,
  });

  final AcoPalette palette;
  final String groupID;
  final Set<String> existingMemberIDs;

  @override
  State<_GroupMemberSelectionPage> createState() =>
      _GroupMemberSelectionPageState();
}

class _GroupMemberSelectionPageState extends State<_GroupMemberSelectionPage> {
  static final _alphabetInitial = RegExp(r'^[A-Z]$');
  final _searchController = TextEditingController();
  final _selected = <String>{};
  late Future<List<FriendContact>> _friends;
  var _query = '';
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _friends = _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FriendContact>> _loadFriends() async {
    final client = AccountApiClient();
    try {
      return await AccountSession(client).listFriends();
    } finally {
      client.close();
    }
  }

  String _initialOf(FriendContact friend) {
    final initial = friend.initial.trim().toUpperCase();
    return _alphabetInitial.hasMatch(initial) ? initial : '#';
  }

  String _displayNameOf(FriendContact friend) =>
      friend.nickname.isEmpty ? friend.accountId : friend.nickname;

  Future<void> _complete() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final client = AccountApiClient();
    try {
      await AccountSession(client).addGroupMembers(
        groupID: widget.groupID,
        memberAccountIds: _selected.toList(growable: false),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '添加成员失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '添加成员失败', '请稍后重试。');
    } finally {
      client.close();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    child: AcoSafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 28, 0),
            child: AcoPageHeader(
              palette: widget.palette,
              title: '选择联系人',
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: CupertinoTextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              clearButtonMode: OverlayVisibilityMode.editing,
              prefix: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(
                  CupertinoIcons.search,
                  color: widget.palette.mutedText,
                  size: 22,
                ),
              ),
              placeholder: '搜索',
              placeholderStyle: TextStyle(
                color: widget.palette.mutedText,
                fontSize: 18,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              style: TextStyle(color: widget.palette.primaryText, fontSize: 18),
              decoration: BoxDecoration(
                color: widget.palette.inputSurface,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Expanded(child: _buildFriendList()),
          _GroupMemberSelectionBottomBar(
            palette: widget.palette,
            selectedCount: _selected.length,
            submitting: _submitting,
            onComplete: _complete,
          ),
        ],
      ),
    ),
  );

  Widget _buildFriendList() => FutureBuilder<List<FriendContact>>(
    future: _friends,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CupertinoActivityIndicator());
      }
      if (snapshot.hasError) {
        return _ContactsStateMessage(
          message: '联系人加载失败，点击重试',
          onRetry: () => setState(() => _friends = _loadFriends()),
        );
      }
      final keyword = _query.toLowerCase();
      final groupedFriends = <String, List<FriendContact>>{};
      final availableFriends = (snapshot.data ?? const <FriendContact>[])
          .where(
            (friend) => !widget.existingMemberIDs.contains(friend.accountId),
          )
          .toList(growable: false);
      for (final friend in availableFriends) {
        final name = _displayNameOf(friend).toLowerCase();
        if (keyword.isNotEmpty &&
            !name.contains(keyword) &&
            !friend.accountId.toLowerCase().contains(keyword)) {
          continue;
        }
        groupedFriends.putIfAbsent(_initialOf(friend), () => []).add(friend);
      }
      final letters = groupedFriends.keys.toList()..sort();
      if (letters.isEmpty) {
        return const _ContactsStateMessage(message: '暂无可添加的联系人');
      }
      return Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final letter in letters) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: 15,
                    ),
                  ),
                ),
                for (final friend in groupedFriends[letter]!)
                  _GroupSelectableContactRow(
                    palette: widget.palette,
                    friend: friend,
                    name: _displayNameOf(friend),
                    selected: _selected.contains(friend.accountId),
                    onTap: () => setState(() {
                      if (_selected.contains(friend.accountId)) {
                        _selected.remove(friend.accountId);
                      } else {
                        _selected.add(friend.accountId);
                      }
                    }),
                  ),
              ],
            ],
          ),
        ],
      );
    },
  );
}

class _GroupSelectableContactRow extends StatelessWidget {
  const _GroupSelectableContactRow({
    required this.palette,
    required this.friend,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final AcoPalette palette;
  final FriendContact friend;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final identityAsset = _identityBadgeAsset(friend.identity);
    final staffAsset = _staffLongBadgeAsset(friend.staffIdentity);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.fromLTRB(18, 8, 32, 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: palette.border.withValues(alpha: .55)),
          ),
        ),
        child: Row(
          children: [
            _GroupMemberSelectionIndicator(
              palette: palette,
              selected: selected,
            ),
            const SizedBox(width: 16),
            AcoAvatar(size: 48, imageUrl: friend.avatarUrl),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.primaryText, fontSize: 16),
              ),
            ),
            if (identityAsset != null || staffAsset != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (identityAsset != null)
                    Image.asset(
                      identityAsset,
                      width: _longBadgeWidth(friend.identity),
                      fit: BoxFit.contain,
                    ),
                  if (identityAsset != null && staffAsset != null)
                    const SizedBox(width: 4),
                  if (staffAsset != null)
                    Image.asset(
                      staffAsset,
                      width: _longBadgeWidth(friend.staffIdentity),
                      fit: BoxFit.contain,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupMemberSelectionIndicator extends StatelessWidget {
  const _GroupMemberSelectionIndicator({
    required this.palette,
    required this.selected,
  });

  final AcoPalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? palette.accent : null,
      border: selected ? null : Border.all(color: palette.mutedText, width: 2),
    ),
    child: selected
        ? Icon(CupertinoIcons.check_mark, color: palette.background, size: 15)
        : null,
  );
}

class _GroupMemberSelectionBottomBar extends StatelessWidget {
  const _GroupMemberSelectionBottomBar({
    required this.palette,
    required this.selectedCount,
    required this.submitting,
    required this.onComplete,
  });

  final AcoPalette palette;
  final int selectedCount;
  final bool submitting;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      border: Border(top: BorderSide(color: palette.border)),
    ),
    child: AcoSafeArea(
      top: false,
      child: Row(
        children: [
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            borderRadius: BorderRadius.circular(8),
            color: selectedCount == 0 ? palette.border : palette.accent,
            onPressed: selectedCount == 0 || submitting ? null : onComplete,
            child: Text(
              submitting ? '添加中' : '完成',
              style: TextStyle(
                color: selectedCount == 0
                    ? palette.mutedText
                    : palette.background,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
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
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    color: const Color(0xFF191919),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: palette.primaryText, fontSize: 18)),
        const Spacer(),
        CupertinoSwitch(
          value: value,
          activeTrackColor: palette.accent,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
