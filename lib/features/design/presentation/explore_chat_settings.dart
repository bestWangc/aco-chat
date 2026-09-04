part of 'aco_design_shell.dart';

class _ChatMoreSettingsPage extends StatefulWidget {
  const _ChatMoreSettingsPage({
    required this.palette,
    required this.peerName,
    required this.messages,
  });

  final AcoPalette palette;
  final String peerName;
  final List<_ChatHistoryMessage> messages;

  @override
  State<_ChatMoreSettingsPage> createState() => _ChatMoreSettingsPageState();
}

class _ChatMoreSettingsPageState extends State<_ChatMoreSettingsPage> {
  var _isPinned = false;
  var _isBlocked = false;

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
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ChatSettingsToggleRow(
              palette: widget.palette,
              label: '置顶聊天',
              value: _isPinned,
              onChanged: (value) => setState(() => _isPinned = value),
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
              onChanged: (value) => setState(() => _isBlocked = value),
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
  final ValueChanged<bool> onChanged;

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
