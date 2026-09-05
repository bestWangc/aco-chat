part of 'aco_design_shell.dart';

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.voiceInputActive,
    required this.onVoicePressed,
    required this.onRecordingChanged,
    required this.onEmojiPressed,
    required this.onMorePressed,
    required this.onInputTapped,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool voiceInputActive;
  final VoidCallback onVoicePressed;
  final ValueChanged<bool> onRecordingChanged;
  final VoidCallback onEmojiPressed;
  final VoidCallback onMorePressed;
  final VoidCallback onInputTapped;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        if (voiceInputActive)
          _ComposerCupertinoIcon(
            icon: CupertinoIcons.keyboard,
            label: '切换到文字输入',
            onPressed: onVoicePressed,
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _ComposerImageIcon(
              assetPath: 'assets/icons/chat_voice.png',
              onPressed: onVoicePressed,
              size: 26,
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: voiceInputActive
              ? _HoldToTalkButton(onRecordingChanged: onRecordingChanged)
              : Container(
                  height: 40,
                  padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    border: Border.all(color: const Color(0xFF464646)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoTextField(
                    controller: controller,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    cursorColor: _white,
                    padding: EdgeInsets.zero,
                    placeholder: '发送消息',
                    placeholderStyle: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 16,
                    ),
                    style: const TextStyle(color: _white, fontSize: 16),
                    decoration: null,
                    onTap: onInputTapped,
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        _ComposerImageIcon(
          assetPath: 'assets/icons/chat_emoji.png',
          onPressed: onEmojiPressed,
          size: 26,
        ),
        const SizedBox(width: 8),
        _ComposerImageIcon(
          assetPath: 'assets/icons/chat_add.png',
          onPressed: onMorePressed,
          size: 26,
        ),
      ],
    ),
  );
}

class _HoldToTalkButton extends StatefulWidget {
  const _HoldToTalkButton({required this.onRecordingChanged});

  final ValueChanged<bool> onRecordingChanged;

  @override
  State<_HoldToTalkButton> createState() => _HoldToTalkButtonState();
}

class _HoldToTalkButtonState extends State<_HoldToTalkButton> {
  var _isRecording = false;

  void _setRecording(bool value) {
    setState(() => _isRecording = value);
    widget.onRecordingChanged(value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: _isRecording ? '松开结束录音' : '按住说话',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _setRecording(true),
      onLongPressEnd: (_) => _setRecording(false),
      onLongPressCancel: () => _setRecording(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isRecording
              ? const Color(0xFF303030)
              : const Color(0xFF191919),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          _isRecording ? '松开结束' : '按住说话',
          style: const TextStyle(color: Color(0xFFD6D6D6), fontSize: 14),
        ),
      ),
    ),
  );
}
