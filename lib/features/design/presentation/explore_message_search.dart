part of 'aco_design_shell.dart';

class _MessageSearchPage extends StatefulWidget {
  const _MessageSearchPage({required this.palette, required this.onOpen});

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends State<_MessageSearchPage> {
  final _controller = TextEditingController();
  var _query = '';

  List<_SocialMockMessage> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _socialMockMessages
        .where((message) => message.message.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return CupertinoPageScaffold(
      backgroundColor: widget.palette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AcoPageHeader(
                palette: widget.palette,
                title: '搜索聊天',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _MessageSearchField(
                controller: _controller,
                palette: widget.palette,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _SearchHint(palette: widget.palette, label: '搜索聊天内容')
                  : results.isEmpty
                  ? _SearchHint(palette: widget.palette, label: '没有找到相关聊天记录')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final message = results[index];
                        return _SocialMessageTile(
                          palette: widget.palette,
                          name: message.name,
                          message: message.message,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpen(
                              message.name == 'Builder'
                                  ? AcoScreen.chatV2
                                  : AcoScreen.chatV1,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHistorySearchPage extends StatefulWidget {
  const _ChatHistorySearchPage({
    required this.palette,
    required this.peerName,
    required this.messages,
  });

  final AcoPalette palette;
  final String peerName;
  final List<_ChatHistoryMessage> messages;

  @override
  State<_ChatHistorySearchPage> createState() => _ChatHistorySearchPageState();
}

class _ChatHistorySearchPageState extends State<_ChatHistorySearchPage> {
  final _controller = TextEditingController();
  var _query = '';

  List<_ChatHistoryMessage> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return widget.messages
        .where((message) => message.text.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return CupertinoPageScaffold(
      backgroundColor: widget.palette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AcoPageHeader(
                palette: widget.palette,
                title: '查找聊天记录',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _MessageSearchField(
                controller: _controller,
                palette: widget.palette,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _SearchHint(
                      palette: widget.palette,
                      label: '搜索与${widget.peerName}的聊天记录',
                    )
                  : results.isEmpty
                  ? _SearchHint(palette: widget.palette, label: '没有找到相关聊天记录')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) => _ChatHistoryResultTile(
                        palette: widget.palette,
                        peerName: widget.peerName,
                        message: results[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHistoryResultTile extends StatelessWidget {
  const _ChatHistoryResultTile({
    required this.palette,
    required this.peerName,
    required this.message,
  });

  final AcoPalette palette;
  final String peerName;
  final _ChatHistoryMessage message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.mine ? '我' : peerName,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption - 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message.text,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ],
    ),
  );
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.palette, required this.label});

  final AcoPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label,
      style: TextStyle(
        color: palette.mutedText,
        fontSize: AcoTypography.caption,
      ),
    ),
  );
}

class _MessageSearchField extends StatelessWidget {
  const _MessageSearchField({
    required this.controller,
    required this.palette,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AcoPalette palette;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(CupertinoIcons.search, color: palette.mutedText, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            cursorColor: palette.primaryText,
            placeholder: '搜索聊天内容',
            placeholderStyle: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.caption,
            ),
            decoration: null,
            padding: EdgeInsets.zero,
            onChanged: onChanged,
            onSubmitted: onChanged,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(
                CupertinoIcons.clear_circled_solid,
                color: palette.mutedText,
                size: 16,
              ),
            );
          },
        ),
      ],
    ),
  );
}
