part of 'aco_design_shell.dart';

class _ChatMoreSettingsPage extends StatefulWidget {
  const _ChatMoreSettingsPage({
    required this.palette,
    required this.peerName,
    required this.peerUserID,
    required this.conversationID,
    required this.onBlockChanged,
    required this.messages,
    required this.onMessageTap,
  });

  final AcoPalette palette;
  final String peerName;
  final String? peerUserID;
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadPinState());
    unawaited(_loadBlockState());
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 28, 0),
        child: AcoPageHeader(
          palette: widget.palette,
          title: '聊天信息',
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
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
        ),
      ),
    ],
  );
}

class _ChatSettingsActionRow extends StatelessWidget {
  const _ChatSettingsActionRow({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final AcoPalette palette;
  final String label;
  final VoidCallback onTap;

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
            style: TextStyle(color: palette.primaryText, fontSize: 15),
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
