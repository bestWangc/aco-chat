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
  final ValueChanged<_VoiceRecordingAction> onRecordingChanged;
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

  final ValueChanged<_VoiceRecordingAction> onRecordingChanged;

  @override
  State<_HoldToTalkButton> createState() => _HoldToTalkButtonState();
}

class _HoldToTalkButtonState extends State<_HoldToTalkButton> {
  var _isRecording = false;
  var _cancelled = false;

  Color get _backgroundColor {
    if (_isRecording || _cancelled) return const Color(0xFF303030);
    return const Color(0xFF2C2C2C);
  }

  String get _label {
    if (_cancelled) return '松开取消';
    if (_isRecording) return '松开结束';
    return '按住说话';
  }

  void _startRecording() {
    if (_isRecording) return;
    setState(() {
      _isRecording = true;
      _cancelled = false;
    });
    widget.onRecordingChanged(_VoiceRecordingAction.start);
  }

  void _finishRecording() {
    if (!_isRecording) return;
    final cancelled = _cancelled;
    setState(() => _isRecording = false);
    widget.onRecordingChanged(
      cancelled ? _VoiceRecordingAction.cancel : _VoiceRecordingAction.send,
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: _isRecording ? '松开结束录音' : '按住说话',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (details) {
        if (_isRecording && details.localOffsetFromOrigin.dy < -60) {
          if (!_cancelled) setState(() => _cancelled = true);
        } else if (_cancelled && details.localOffsetFromOrigin.dy > -30) {
          setState(() => _cancelled = false);
        }
      },
      onLongPressEnd: (_) => _finishRecording(),
      onLongPressCancel: _finishRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _backgroundColor,
          border: Border.all(color: const Color(0xFF464646)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _label,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
        ),
      ),
    ),
  );
}

enum _VoiceRecordingAction { start, send, cancel }
