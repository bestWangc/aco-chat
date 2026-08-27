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
          widget.hasLive ? '还没有弹幕，来说点什么吧。' : '请选择直播间后查看弹幕。',
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

class _RoomEmojiPicker extends StatelessWidget {
  const _RoomEmojiPicker({
    required this.palette,
    required this.controller,
    required this.onEmojiSelected,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final VoidCallback onEmojiSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _roomEmojiPickerHeight,
    child: emoji.EmojiPicker(
      textEditingController: controller,
      onEmojiSelected: (_, _) => onEmojiSelected(),
      config: emoji.Config(
        height: _roomEmojiPickerHeight,
        checkPlatformCompatibility: false,
        emojiViewConfig: emoji.EmojiViewConfig(
          backgroundColor: palette.surfaceRaised,
          columns: 8,
          emojiSizeMax: 28,
          buttonMode: emoji.ButtonMode.CUPERTINO,
        ),
        categoryViewConfig: emoji.CategoryViewConfig(
          initCategory: emoji.Category.SMILEYS,
          backgroundColor: palette.surfaceRaised,
          indicatorColor: palette.accent,
          iconColor: palette.mutedText,
          iconColorSelected: palette.accent,
          backspaceColor: palette.primaryText,
          dividerColor: _transparent,
        ),
        bottomActionBarConfig: const emoji.BottomActionBarConfig(
          enabled: false,
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

  bool get _showMutedMicAsset => canSpeak && muted && !audioMuted;

  IconData? get _micIcon {
    if (canSpeak && (!muted || _showMutedMicAsset)) return null;
    return CupertinoIcons.mic_slash;
  }

  String? get _micIconAsset {
    if (!canSpeak) return null;
    return _showMutedMicAsset
        ? 'assets/icons/live_muted_red.png'
        : 'assets/icons/live_mic.png';
  }

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
              _RoomControl(
                icon: _micIcon,
                iconAsset: _micIconAsset,
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
              const SizedBox(width: 8),
              Expanded(
                child: _RoomComposer(
                  palette: palette,
                  controller: controller,
                  chatMuted: chatMuted,
                  onEmojiPressed: onEmojiPressed,
                  onSubmitted: onSubmitted,
                ),
              ),
              if (showHandControl) ...[
                const SizedBox(width: 8),
                _RoomControl(
                  iconAsset: 'assets/icons/live_hand.png',
                  label: handRaised ? '已举手' : '举手',
                  background: palette.surfaceRaised,
                  foreground: palette.primaryText,
                  onPressed: handRaised ? null : onHand,
                  large: true,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  _RoomControlColors _micControlColors() {
    if (!canSpeak || audioMuted) {
      return _RoomControlColors(
        background: palette.surfaceRaised,
        foreground: palette.mutedText,
      );
    }
    if (muted) {
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
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.large = false,
    this.iconSize,
  });

  final IconData? icon;
  final String? iconAsset;
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
    final iconWidget = iconAsset == null
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
      color: isSystemMessage
          ? palette.accent
          : palette.dark
          ? palette.accent
          : palette.primaryText,
      fontSize: AcoTypography.bodySmall,
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
            borderRadius: BorderRadius.circular(8),
          );
    return Align(
      alignment: isSystemMessage ? Alignment.center : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: decoration,
        child: Text(
          isSystemMessage ? text : '$name:  $text',
          textAlign: isSystemMessage ? TextAlign.center : TextAlign.start,
          style: messageStyle,
        ),
      ),
    );
  }
}
