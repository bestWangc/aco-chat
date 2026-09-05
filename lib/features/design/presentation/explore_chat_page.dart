part of 'aco_design_shell.dart';

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.palette,
    required this.version,
    this.peerUserID,
    this.peerName,
    this.conversationID,
  });
  final AcoPalette palette;
  final int version;
  final String? peerUserID;
  final String? peerName;
  final String? conversationID;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  var _emojiPickerVisible = false;
  var _morePanelVisible = false;
  var _voiceInputActive = false;
  var _voiceRecording = false;
  final List<_ChatHistoryMessage> _chatHistory = <_ChatHistoryMessage>[];
  final List<Message> _historyMessages = <Message>[];
  final List<Message> _pendingSentMessages = <Message>[];
  Future<void>? _loadFuture;
  String? _error;
  String? _resolvedConversationID;
  String? _resolvedPeerName;
  String? _resolvedPeerAvatar;
  bool _loadingOlder = false;
  bool _historyEnd = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadHistory();
    OpenIMChatRepository.conversationReady.addListener(_onReady);
    OpenIMChatRepository.messageNotifier.addListener(_onMessage);
    _chatScrollController.addListener(_onChatScroll);
  }

  void _onChatScroll() {
    if (_chatScrollController.hasClients &&
        _chatScrollController.position.maxScrollExtent > 0 &&
        _chatScrollController.position.pixels >=
            _chatScrollController.position.maxScrollExtent - 40) {
      unawaited(_loadOlderMessages());
    }
  }

  void _onMessage() {
    final message = OpenIMChatRepository.messageNotifier.value;
    final text = message?.textElem?.content;
    if (!mounted || message == null || text == null || text.isEmpty) return;
    if (message.sendID != widget.peerUserID) return;
    if (_chatHistory.any((item) => item.text == text && !item.mine)) return;
    _historyMessages.add(message);
    setState(() => _chatHistory.add(_ChatHistoryMessage(text, mine: false)));
    _scrollToBottom();
  }

  void _onReady() {
    if (!mounted || !OpenIMChatRepository.conversationReady.value) return;
    if (_error == '聊天服务正在连接，请稍候重试') {
      setState(() {
        _error = null;
        _loadFuture = _loadHistory();
      });
    }
  }

  Future<void> _loadPeerProfile(String userID) async {
    try {
      final users = await OpenIM.iMManager.userManager.getUsersInfo(
        userIDList: <String>[userID],
      );
      final user = users.isEmpty ? null : users.first;
      final nickname = user?.nickname?.trim();
      if (nickname?.isNotEmpty == true) _resolvedPeerName = nickname;
      if (user?.faceURL?.isNotEmpty == true) {
        _resolvedPeerAvatar = user!.faceURL;
      }
    } catch (error) {
      debugPrint('[OpenIM] user profile load failed: $error');
    }

    final client = AccountApiClient();
    try {
      final friends = await AccountSession(client).listFriends();
      for (final friend in friends) {
        if (friend.accountId != userID) continue;
        if (friend.nickname.isNotEmpty) _resolvedPeerName = friend.nickname;
        if (friend.avatarUrl.isNotEmpty) _resolvedPeerAvatar = friend.avatarUrl;
        break;
      }
    } catch (error) {
      debugPrint('[API] chat profile load failed: $error');
    } finally {
      client.close();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    final userID = widget.peerUserID;
    if (userID == null || userID.isEmpty) return;
    if (!OpenIMChatRepository.conversationReady.value) {
      _error = '聊天服务正在连接，请稍候重试';
      return;
    }
    try {
      await _loadPeerProfile(userID);
      final conversation = await OpenIM.iMManager.conversationManager
          .getOneConversation(
            sourceID: userID,
            sessionType: ConversationType.single,
          );
      _resolvedConversationID = conversation.conversationID;
      final result = await OpenIM.iMManager.messageManager
          .getAdvancedHistoryMessageList(
            conversationID: _resolvedConversationID!,
            count: 30,
          );
      final messages = result.messageList ?? const <Message>[];
      final loadedIDs = {
        for (final message in messages)
          if (message.clientMsgID?.isNotEmpty == true) message.clientMsgID,
      };
      final pending = _pendingSentMessages
          .where(
            (message) =>
                message.clientMsgID?.isNotEmpty == true &&
                !loadedIDs.contains(message.clientMsgID),
          )
          .toList();
      _pendingSentMessages.removeWhere(
        (message) => loadedIDs.contains(message.clientMsgID),
      );
      _historyMessages
        ..clear()
        ..addAll(messages)
        ..addAll(pending);
      _sortHistoryMessages();
      _historyEnd = result.isEnd ?? messages.length < 30;
      try {
        await OpenIM.iMManager.conversationManager
            .markConversationMessageAsRead(
              conversationID:
                  _resolvedConversationID ??
                  widget.conversationID ??
                  'si_$userID',
            );
        OpenIMChatRepository.pendingConversation?.unreadCount = 0;
        OpenIMChatRepository.conversationRevision.value++;
      } catch (error) {
        debugPrint('[OpenIM] mark read failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _chatHistory
          ..clear()
          ..addAll(
            _historyMessages
                .where((m) => m.textElem?.content?.isNotEmpty == true)
                .map(
                  (m) => _ChatHistoryMessage(
                    m.textElem!.content!,
                    mine: m.sendID != userID,
                  ),
                ),
          );
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '聊天记录加载失败，点击重试');
      debugPrint('[OpenIM] history load failed: $error');
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || _historyEnd || _historyMessages.isEmpty) return;
    final userID = widget.peerUserID;
    final conversationID = _resolvedConversationID;
    if (userID == null || conversationID == null) return;
    _loadingOlder = true;
    final oldMaxExtent = _chatScrollController.hasClients
        ? _chatScrollController.position.maxScrollExtent
        : 0.0;
    try {
      final result = await OpenIM.iMManager.messageManager
          .getAdvancedHistoryMessageList(
            conversationID: conversationID,
            startMsg: _historyMessages.first,
            count: 30,
          );
      final older = result.messageList ?? const <Message>[];
      if (older.isEmpty) {
        _historyEnd = true;
        return;
      }
      _historyMessages.insertAll(0, older);
      _sortHistoryMessages();
      if (!mounted) return;
      setState(() {
        _chatHistory
          ..clear()
          ..addAll(
            _historyMessages
                .where((m) => m.textElem?.content?.isNotEmpty == true)
                .map(
                  (m) => _ChatHistoryMessage(
                    m.textElem!.content!,
                    mine: m.sendID != userID,
                  ),
                ),
          );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatScrollController.hasClients) return;
        final delta =
            _chatScrollController.position.maxScrollExtent - oldMaxExtent;
        if (delta > 0) {
          _chatScrollController.jumpTo(
            (_chatScrollController.position.pixels + delta).clamp(
              0.0,
              _chatScrollController.position.maxScrollExtent,
            ),
          );
        }
      });
      _historyEnd = result.isEnd ?? older.length < 30;
    } catch (error) {
      debugPrint('[OpenIM] older messages load failed: $error');
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    final userID = widget.peerUserID;
    if (text.isEmpty || userID == null || userID.isEmpty) return;
    final shouldFollowNewMessage =
        !_chatScrollController.hasClients ||
        _chatScrollController.position.pixels <= 80;
    if (!OpenIMChatRepository.conversationReady.value) {
      _showNotice(context, '连接未就绪', '聊天连接恢复后再发送。');
      return;
    }
    _messageController.clear();
    try {
      final message = await OpenIM.iMManager.messageManager.createTextMessage(
        text: text,
      );
      final sent = await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: userID,
        offlinePushInfo: OfflinePushInfo(title: '新消息', desc: text),
      );
      debugPrint(
        '[OpenIM] message sent clientMsgID=${sent.clientMsgID} '
        'serverMsgID=${sent.serverMsgID} status=${sent.status} '
        'to=$userID',
      );
      if (!mounted) return;
      _historyMessages.add(sent);
      _pendingSentMessages.add(sent);
      setState(
        () => _chatHistory.add(
          _ChatHistoryMessage(sent.textElem?.content ?? text, mine: true),
        ),
      );
      // The composer/keyboard can resize the viewport in a later frame. Use
      // a short scroll when the user was already following the conversation.
      // When reading older messages, preserve their position like WeChat.
      _scrollToBottom(force: shouldFollowNewMessage, animate: false);
      if (shouldFollowNewMessage) {
        // The keyboard inset animation can finish after the list's first
        // layout. Re-check once it settles so the new bubble is not hidden.
        Future<void>.delayed(const Duration(milliseconds: 240), () {
          if (mounted) {
            _scrollToBottom(force: true, animate: false);
          }
        });
      }
      OpenIMChatRepository.conversationRevision.value++;
    } catch (error) {
      if (!mounted) return;
      _showNotice(context, '发送失败', '请稍后重试');
      debugPrint('[OpenIM] send failed: $error');
    }
  }

  void _sortHistoryMessages() {
    _historyMessages.sort((a, b) {
      final aTime = a.sendTime ?? a.createTime ?? 0;
      final bTime = b.sendTime ?? b.createTime ?? 0;
      return aTime.compareTo(bTime);
    });
  }

  @override
  void dispose() {
    OpenIMChatRepository.conversationReady.removeListener(_onReady);
    OpenIMChatRepository.messageNotifier.removeListener(_onMessage);
    _chatScrollController.removeListener(_onChatScroll);
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false, bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void applyScroll() {
        if (!mounted || !_chatScrollController.hasClients) return;
        final position = _chatScrollController.position;
        if (!force && position.pixels > 80) {
          return;
        }
        final target = 0.0;
        if ((target - position.pixels).abs() < 1) return;
        if (!animate) {
          _chatScrollController.jumpTo(target);
        } else {
          _chatScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      }

      applyScroll();
    });
  }

  bool get _isPanelVisible => _emojiPickerVisible || _morePanelVisible;

  String get _peerName {
    final name = _resolvedPeerName ?? widget.peerName?.trim();
    return name?.isNotEmpty == true ? name! : (widget.peerUserID ?? '聊天');
  }

  Future<void> _pickChatPhoto() async {
    setState(() => _morePanelVisible = false);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1440,
      );
      if (photo == null) return;
      final imageBytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _chatHistory.add(_ChatHistoryMessage.image(imageBytes, mine: true));
      });
    } catch (_) {
      if (!mounted) return;
      _showNotice(context, '照片选择失败', '请检查相册访问权限后重试。');
    }
  }

  Future<void> _handleMorePanelSelection(String label) async {
    if (label == '照片') {
      await _pickChatPhoto();
      return;
    }
    setState(() => _morePanelVisible = false);
    _showNotice(context, label, '$label功能暂未开放。');
  }

  void _hidePanels() {
    if (!_isPanelVisible) return;
    setState(() {
      _emojiPickerVisible = false;
      _morePanelVisible = false;
    });
  }

  void _toggleEmojiPicker() {
    _dismissKeyboard();
    setState(() {
      _emojiPickerVisible = !_emojiPickerVisible;
      _morePanelVisible = false;
    });
  }

  void _toggleMorePanel() {
    _dismissKeyboard();
    setState(() {
      _morePanelVisible = !_morePanelVisible;
      _emojiPickerVisible = false;
    });
  }

  void _toggleVoiceInput() {
    _dismissKeyboard();
    setState(() {
      _voiceInputActive = !_voiceInputActive;
      _emojiPickerVisible = false;
      _morePanelVisible = false;
    });
  }

  void _setVoiceRecording(bool isRecording) {
    if (_voiceRecording == isRecording) return;
    setState(() => _voiceRecording = isRecording);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final compactBottomBar = _isPanelVisible || keyboardInset > 0;
    return _DetailScaffold(
      palette: widget.palette,
      title: _peerName,
      headerRightPadding: 4,
      right: Semantics(
        button: true,
        label: '更多',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(51, 30),
          onPressed: () => Navigator.of(context).push<void>(
            _AcoPageRoute<void>(
              builder: (_) => CupertinoPageScaffold(
                backgroundColor: widget.palette.background,
                child: SafeArea(
                  left: false,
                  right: false,
                  bottom: false,
                  child: ColoredBox(
                    color: widget.palette.background,
                    child: _ChatMoreSettingsPage(
                      palette: widget.palette,
                      peerName: _peerName,
                      messages: _chatHistory,
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: Image.asset(
            'assets/icons/chat_more_mark.png',
            width: 26,
            height: 8,
            fit: BoxFit.contain,
          ),
        ),
      ),
      child: Stack(
        children: [
          AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _hidePanels,
                    child: FutureBuilder<void>(
                      future: _loadFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _chatHistory.isEmpty) {
                          return const Center(
                            child: CupertinoActivityIndicator(),
                          );
                        }
                        if (_error != null) {
                          return Center(
                            child: CupertinoButton(
                              onPressed: () => setState(() {
                                _error = null;
                                _loadFuture = _loadHistory();
                              }),
                              child: Text(_error!),
                            ),
                          );
                        }
                        if (_chatHistory.isEmpty) {
                          return const Center(child: Text('暂无消息'));
                        }
                        return ListView.separated(
                          controller: _chatScrollController,
                          reverse: true,
                          // Reserve space so the latest bubble stays above the
                          // composer at the bottom of the reversed list.
                          padding: const EdgeInsets.fromLTRB(8, 20, 8, 10),
                          itemCount: _chatHistory.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 18),
                          itemBuilder: (_, index) {
                            final message =
                                _chatHistory[_chatHistory.length - 1 - index];
                            return _ChatMessage(
                              palette: widget.palette,
                              text: message.text,
                              imageBytes: message.imageBytes,
                              mine: message.mine,
                              avatarUrl: _resolvedPeerAvatar,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1D1B),
                    border: Border(top: BorderSide(color: Color(0xFF2D2D2D))),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: !compactBottomBar,
                    minimum: compactBottomBar
                        ? EdgeInsets.zero
                        : const EdgeInsets.only(bottom: 20),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        8,
                        8,
                        compactBottomBar ? 2 : 8,
                      ),
                      child: _ChatComposer(
                        controller: _messageController,
                        voiceInputActive: _voiceInputActive,
                        onVoicePressed: _toggleVoiceInput,
                        onRecordingChanged: _setVoiceRecording,
                        onEmojiPressed: _toggleEmojiPicker,
                        onMorePressed: _toggleMorePanel,
                        onInputTapped: _hidePanels,
                        onSubmit: _sendText,
                      ),
                    ),
                  ),
                ),
                if (_emojiPickerVisible)
                  _AcoEmojiPicker(
                    palette: widget.palette,
                    controller: _messageController,
                    onEmojiSelected: () =>
                        setState(() => _emojiPickerVisible = false),
                  ),
                if (_morePanelVisible)
                  _ChatMorePanel(onSelected: _handleMorePanelSelection),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 360),
                reverseDuration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .9, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: _voiceRecording
                    ? const _VoiceRecordingOverlay(
                        key: ValueKey('voice-recording'),
                      )
                    : const SizedBox(key: ValueKey('voice-recording-idle')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceRecordingOverlay extends StatelessWidget {
  const _VoiceRecordingOverlay({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xB8000000),
    child: Stack(
      children: [
        Align(
          alignment: const Alignment(0, -.08),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF98EC63),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const _VoiceWaveform(),
              ),
              Positioned(
                bottom: -7,
                child: Transform.rotate(
                  angle: .785398,
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: ColoredBox(color: Color(0xFF98EC63)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 92,
            width: double.infinity,
            alignment: const Alignment(0, .45),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E2E2),
              borderRadius: BorderRadius.vertical(
                top: Radius.elliptical(240, 88),
              ),
            ),
            child: const Text(
              '松开 发送',
              style: TextStyle(
                color: Color(0xFF1C1C1C),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Positioned(
          right: -28,
          bottom: 132,
          child: Container(
            width: 196,
            height: 76,
            alignment: const Alignment(-.12, 0),
            decoration: const BoxDecoration(
              color: Color(0xFF666666),
              borderRadius: BorderRadius.horizontal(
                left: Radius.elliptical(76, 48),
              ),
            ),
            child: const Text(
              '取消',
              style: TextStyle(
                color: _white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (final height in const <double>[8, 11, 8, 13, 9, 12, 8, 11, 9])
        Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFF387B2B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      Container(width: 3, height: 22, color: const Color(0xFF387B2B)),
      for (final height in const <double>[9, 11, 8, 12, 9, 13, 8, 11, 8])
        Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFF387B2B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ],
  );
}

class _ComposerImageIcon extends StatelessWidget {
  const _ComposerImageIcon({
    required this.assetPath,
    required this.onPressed,
    this.size = 24,
  });

  final String assetPath;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size(size, size),
    onPressed: onPressed,
    child: Image.asset(assetPath, width: size, height: size),
  );
}

class _ComposerCupertinoIcon extends StatelessWidget {
  const _ComposerCupertinoIcon({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(24, 24),
      onPressed: onPressed,
      child: Icon(icon, color: _white, size: 23),
    ),
  );
}

class _ChatMorePanel extends StatelessWidget {
  const _ChatMorePanel({required this.onSelected});

  final Future<void> Function(String label) onSelected;

  static const _items = [
    (label: '照片', assetPath: 'assets/icons/chat_more_photo.png'),
    (label: '拍摄', assetPath: 'assets/icons/chat_more_camera.png'),
    (label: '语音通话', assetPath: 'assets/icons/chat_more_call.png'),
    (label: '转账', assetPath: 'assets/icons/chat_more_transfer.png'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 116,
    color: _black,
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 16,
        childAspectRatio: .77,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Semantics(
          button: true,
          label: item.label,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => onSelected(item.label),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191919),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Image.asset(item.assetPath, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9D9EA0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ChatMessage extends StatelessWidget {
  const _ChatMessage({
    required this.palette,
    required this.text,
    required this.imageBytes,
    required this.mine,
    this.avatarUrl,
  });

  final AcoPalette palette;
  final String text;
  final Uint8List? imageBytes;
  final bool mine;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxBubbleWidth = (constraints.maxWidth - 46).clamp(0.0, 245.0);
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              AcoAvatar(size: 40, imageUrl: avatarUrl),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: imageBytes == null
                    ? _Bubble(palette: palette, text: text, mine: mine)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.memory(
                          imageBytes!,
                          width: 180,
                          height: 180,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
              ),
            ),
            if (mine) ...[const SizedBox(width: 6), const AcoAvatar(size: 40)],
          ],
        ),
      );
    },
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Image.asset(
              'assets/images/coming_soon_mark.png',
              fit: BoxFit.contain,
              semanticLabel: 'Aco 标志',
            ),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Image.asset(
              'assets/images/coming_soon_wordmark.png',
              fit: BoxFit.contain,
              semanticLabel: 'Coming Soon',
            ),
          ),
        ],
      ),
    ),
  );
}
