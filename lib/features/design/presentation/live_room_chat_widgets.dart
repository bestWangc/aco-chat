part of 'aco_design_shell.dart';

class _RoomChatHistory extends StatefulWidget {
  const _RoomChatHistory({
    required this.palette,
    required this.hasLive,
    required this.scrollToLatestSignal,
    this.liveMessages,
  });

  final AcoPalette palette;
  final bool hasLive;
  final int scrollToLatestSignal;
  final List<LiveMessage>? liveMessages;

  @override
  State<_RoomChatHistory> createState() => _RoomChatHistoryState();
}

class _RoomChatHistoryState extends State<_RoomChatHistory> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _RoomChatHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToLatestSignal == oldWidget.scrollToLatestSignal) return;
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomMessages = widget.liveMessages;
    if (roomMessages == null || roomMessages.isEmpty) {
      return Center(
        child: Text(
          widget.hasLive ? '还没有弹幕，来说点什么吧。' : '请选择会议后查看弹幕。',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('room-chat-history'),
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(24, 0, 18, 14),
      itemCount: roomMessages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final message = roomMessages[roomMessages.length - index - 1];
        return _RoomMessage(
          palette: widget.palette,
          name: message.nickname,
          text: message.text,
        );
      },
    );
  }
}

class _AcoEmojiPicker extends StatelessWidget {
  const _AcoEmojiPicker({
    required this.palette,
    required this.controller,
    required this.onEmojiSelected,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final VoidCallback onEmojiSelected;

  static const _commonEmoji = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '🙃',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😋',
    '😜',
    '🤪',
    '🤭',
    '🤗',
    '🤔',
    '🤫',
    '🤐',
    '😐',
    '😑',
    '😶',
    '🙄',
    '😏',
    '😣',
    '😥',
    '😮',
    '😭',
    '😤',
    '😡',
    '😱',
    '😴',
    '🤒',
    '🤮',
    '💩',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '👌',
    '🤝',
    '❤️',
    '🔥',
    '🎉',
    '🎂',
    '☺️',
    '💯',
    '✅',
    '❌',
    '👀',
  ];

  void _insertEmoji(String value) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    controller.value = controller.value.copyWith(
      text: controller.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
      composing: TextRange.empty,
    );
    onEmojiSelected();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _roomEmojiPickerHeight,
    child: ColoredBox(
      color: palette.surfaceRaised,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _commonEmoji.length,
        itemBuilder: (_, index) => CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _insertEmoji(_commonEmoji[index]),
          child: Text(
            _commonEmoji[index],
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    ),
  );
}

class _RoomComposer extends StatelessWidget {
  const _RoomComposer({
    required this.palette,
    required this.controller,
    required this.chatMuted,
    required this.onEmojiPressed,
    required this.onSubmitted,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final bool chatMuted;
  final VoidCallback onEmojiPressed;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final textColor = chatMuted ? palette.mutedText : palette.primaryText;
    return SizedBox(
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          color: chatMuted
              ? palette.surfaceRaised.withValues(alpha: 0.72)
              : palette.surfaceRaised,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: chatMuted ? null : onEmojiPressed,
                child: Icon(CupertinoIcons.smiley, color: textColor, size: 20),
              ),
            ),
            Expanded(
              child: CupertinoTextField(
                key: const Key('room-message-input'),
                maxLines: 1,
                controller: controller,
                enabled: !chatMuted,
                textInputAction: TextInputAction.send,
                cursorColor: palette.accent,
                padding: const EdgeInsets.only(right: 14),
                placeholder: chatMuted ? '全员禁言中' : '说点什么...',
                placeholderStyle: TextStyle(
                  color: textColor,
                  fontSize: AcoTypography.bodySmall,
                ),
                style: TextStyle(
                  color: textColor,
                  fontSize: AcoTypography.bodySmall,
                ),
                onSubmitted: (message) {
                  _dismissKeyboard();
                  if (!chatMuted && message.trim().isNotEmpty) onSubmitted();
                },
                decoration: const BoxDecoration(color: _transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomBottomBar extends StatelessWidget {
  const _RoomBottomBar({
    required this.palette,
    required this.muted,
    required this.canSpeak,
    required this.audioMuted,
    required this.showHandControl,
    required this.handRaised,
    required this.chatMuted,
    required this.onMic,
    required this.onHand,
    required this.controller,
    required this.onEmojiPressed,
    required this.onSubmitted,
  });

  final AcoPalette palette;
  final bool muted;
  final bool canSpeak;
  final bool audioMuted;
  final bool showHandControl;
  final bool handRaised;
  final bool chatMuted;
  final VoidCallback? onMic;
  final VoidCallback? onHand;
  final TextEditingController controller;
  final VoidCallback onEmojiPressed;
  final VoidCallback onSubmitted;

  // Supplied livestream microphone glyph for the active speaking state.
  static final _liveMicIcon = MemoryImage(
    base64Decode(
      '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',
    ),
  );

  IconData? get _micIcon {
    if (canSpeak && !muted && !audioMuted) return null;
    if (_micIconAsset != null) return null;
    return CupertinoIcons.mic_slash;
  }

  String? get _micIconAsset {
    if (!canSpeak || audioMuted || muted) {
      return 'assets/icons/live_muted_red.png';
    }
    return null;
  }

  ImageProvider? get _micIconImage =>
      canSpeak && !audioMuted && !muted ? _liveMicIcon : null;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(_roomBottomBarHeight, constraints.maxHeight);
      final verticalPadding = math.min(
        10.0,
        math.max(0.0, (height - 56.0) / 2),
      );
      final micColors = _micControlColors();
      return SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              if (showHandControl) ...[
                _RoomControl(
                  iconAsset: 'assets/icons/live_hand.png',
                  label: handRaised ? '已举手' : '举手',
                  background: palette.surfaceRaised,
                  foreground: palette.primaryText,
                  onPressed: handRaised ? null : onHand,
                  large: true,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _RoomComposer(
                  palette: palette,
                  controller: controller,
                  chatMuted: chatMuted,
                  onEmojiPressed: onEmojiPressed,
                  onSubmitted: onSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              _RoomControl(
                icon: _micIcon,
                iconAsset: _micIconAsset,
                iconImage: _micIconImage,
                label: audioMuted
                    ? '全员静音中'
                    : canSpeak
                    ? (muted ? '取消静音' : '静音')
                    : '获准后可发言',
                background: micColors.background,
                foreground: micColors.foreground,
                onPressed: onMic,
                large: true,
                iconSize: 26,
              ),
            ],
          ),
        ),
      );
    },
  );

  _RoomControlColors _micControlColors() {
    if (!canSpeak || audioMuted || muted) {
      return _RoomControlColors(
        background: palette.surfaceRaised,
        foreground: const Color(0xFFFF1027),
      );
    }
    return _RoomControlColors(background: palette.accent, foreground: _black);
  }
}

class _RoomControlColors {
  const _RoomControlColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class _RoomControl extends StatelessWidget {
  const _RoomControl({
    this.icon,
    this.iconAsset,
    this.iconImage,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.large = false,
    this.iconSize,
  });

  final IconData? icon;
  final String? iconAsset;
  final ImageProvider? iconImage;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool large;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final controlSize = large ? 56.0 : 48.0;
    final resolvedIconSize = iconSize ?? (large ? 20.0 : 17.0);
    final iconWidget = iconImage != null
        ? Image(
            image: iconImage!,
            width: resolvedIconSize,
            height: resolvedIconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          )
        : iconAsset == null
        ? Icon(icon, color: foreground, size: resolvedIconSize)
        : Image.asset(
            iconAsset!,
            width: resolvedIconSize,
            height: resolvedIconSize,
            fit: BoxFit.contain,
            color: foreground,
            colorBlendMode: BlendMode.srcIn,
          );
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: controlSize,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(controlSize),
          onPressed: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}

class _RoomMessage extends StatelessWidget {
  const _RoomMessage({
    required this.palette,
    required this.name,
    required this.text,
  });

  final AcoPalette palette;
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isSystemMessage = name.isEmpty;
    final messageStyle = TextStyle(
      color: isSystemMessage ? palette.accent : _white,
      fontSize: 15,
      fontWeight: isSystemMessage ? FontWeight.w500 : FontWeight.w400,
      height: 1.2,
    );
    final decoration = isSystemMessage
        ? BoxDecoration(
            color: palette.accent.withValues(alpha: .12),
            border: Border.all(color: palette.accent.withValues(alpha: .28)),
            borderRadius: BorderRadius.circular(16),
          )
        : BoxDecoration(
            color: palette.dark
                ? const Color(0xFF3D3D3D)
                : palette.surfaceRaised,
            borderRadius: BorderRadius.circular(28),
          );
    return Align(
      alignment: isSystemMessage ? Alignment.center : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: decoration,
        child: isSystemMessage
            ? Text(text, textAlign: TextAlign.center, style: messageStyle)
            : RichText(
                text: TextSpan(
                  style: messageStyle,
                  children: [
                    TextSpan(
                      text: '$name:  ',
                      style: TextStyle(color: palette.accent),
                    ),
                    TextSpan(text: text),
                  ],
                ),
              ),
      ),
    );
  }
}
