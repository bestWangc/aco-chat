part of 'aco_design_shell.dart';

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.palette,
    required this.version,
    this.ownAvatarUrl,
    this.peerUserID,
    this.peerName,
    this.conversationID,
  });
  final AcoPalette palette;
  final int version;
  final String? ownAvatarUrl;
  final String? peerUserID;
  final String? peerName;
  final String? conversationID;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  static const _chatImageMaxBytes = 1536 * 1024;

  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  var _emojiPickerVisible = false;
  var _morePanelVisible = false;
  var _voiceInputActive = false;
  var _voiceRecording = false;
  final _voiceRecorder = AudioRecorder();
  Timer? _voiceRecordingTimer;
  var _voiceFinishing = false;
  String? _voiceRecordingPath;
  DateTime? _voiceRecordingStartedAt;
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
  bool _markingMessagesAsRead = false;

  String? get _currentConversationID {
    if (_resolvedConversationID?.isNotEmpty == true) {
      return _resolvedConversationID;
    }
    if (widget.conversationID?.isNotEmpty == true) {
      return widget.conversationID;
    }
    final userID = widget.peerUserID;
    return userID?.isNotEmpty == true ? 'si_$userID' : null;
  }

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
    if (!mounted || message == null) return;
    if (message.sendID != widget.peerUserID) return;
    if (!_ChatHistoryMessage.isDisplayable(message)) return;
    final clientMsgID = message.clientMsgID;
    if (clientMsgID?.isNotEmpty == true &&
        _historyMessages.any((item) => item.clientMsgID == clientMsgID)) {
      return;
    }
    _historyMessages.add(message);
    setState(
      () => _chatHistory.add(
        _ChatHistoryMessage.fromOpenIM(message, mine: false),
      ),
    );
    unawaited(_markCurrentConversationAsRead());
    _scrollToBottom();
  }

  Future<void> _markCurrentConversationAsRead() async {
    if (_markingMessagesAsRead) return;
    final conversationID = _currentConversationID;
    if (conversationID == null) return;

    _markingMessagesAsRead = true;
    try {
      await OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
        conversationID: conversationID,
      );
      final pendingConversation = OpenIMChatRepository.pendingConversation;
      if (pendingConversation?.conversationID == conversationID) {
        pendingConversation?.unreadCount = 0;
      }
      OpenIMChatRepository.conversationRevision.value++;
    } catch (error) {
      debugPrint('[OpenIM] mark read failed: $error');
    } finally {
      _markingMessagesAsRead = false;
    }
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
      await _markCurrentConversationAsRead();
      if (!mounted) return;
      setState(() {
        _chatHistory
          ..clear()
          ..addAll(
            _historyMessages
                .where(_ChatHistoryMessage.isDisplayable)
                .map(
                  (m) => _ChatHistoryMessage.fromOpenIM(
                    m,
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
                .where(_ChatHistoryMessage.isDisplayable)
                .map(
                  (m) => _ChatHistoryMessage.fromOpenIM(
                    m,
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
    _voiceRecordingTimer?.cancel();
    _voiceRecorder.dispose();
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

  Future<void> _pickChatImage(ImageSource source) async {
    setState(() => _morePanelVisible = false);
    File? pickedImage;
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (photo == null) return;
      pickedImage = File(photo.path);
      final photoSize = await photo.length();
      if (photoSize > _chatImageMaxBytes) {
        if (mounted) {
          _showNotice(context, '图片过大', '请重新选择一张不超过 1.5 MB 的图片。');
        }
        return;
      }
      final imageBytes = await photo.readAsBytes();
      final userID = widget.peerUserID;
      if (userID == null || userID.isEmpty) return;
      if (!OpenIMChatRepository.conversationReady.value) {
        if (!mounted) return;
        _showNotice(context, '连接未就绪', '聊天连接恢复后再发送。');
        return;
      }
      final message = await OpenIM.iMManager.messageManager
          .createImageMessageFromFullPath(imagePath: photo.path);
      final sent = await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: userID,
        offlinePushInfo: OfflinePushInfo(title: '新消息', desc: '[图片]'),
      );
      if (!mounted) return;
      _historyMessages.add(sent);
      _pendingSentMessages.add(sent);
      setState(() {
        _chatHistory.add(
          _ChatHistoryMessage.image(
            mine: true,
            imageBytes: imageBytes,
            imageUrl: _ChatHistoryMessage.imageUrlOf(sent.pictureElem),
            previewImageUrl: _ChatHistoryMessage.previewImageUrlOf(
              sent.pictureElem,
            ),
            shouldCacheThumbnail:
                sent.pictureElem?.snapshotPicture?.url?.isNotEmpty == true,
          ),
        );
      });
      _scrollToBottom(force: true, animate: false);
      OpenIMChatRepository.conversationRevision.value++;
    } catch (error) {
      if (!mounted) return;
      _showNotice(context, '图片发送失败', '请稍后重试。');
      debugPrint('[OpenIM] image send failed: $error');
    } finally {
      await _deletePickedImage(pickedImage);
    }
  }

  Future<void> _deletePickedImage(File? image) async {
    if (image == null || !await image.exists()) return;
    try {
      await image.delete();
    } catch (error) {
      debugPrint('[Chat] picked image cleanup failed: $error');
    }
  }

  Future<void> _handleMorePanelSelection(String label) async {
    if (label == '照片') {
      await _pickChatImage(ImageSource.gallery);
      return;
    }
    if (label == '拍摄') {
      await _pickChatImage(ImageSource.camera);
      return;
    }
    if (label == '语音通话') {
      setState(() => _morePanelVisible = false);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        _AcoPageRoute<void>(
          builder: (_) => _VoiceCallPage(
            name: _peerName,
            avatarUrl: _resolvedPeerAvatar ?? widget.ownAvatarUrl,
            incoming: false,
          ),
        ),
      );
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

  Future<void> _setVoiceRecording(_VoiceRecordingAction action) async {
    switch (action) {
      case _VoiceRecordingAction.start:
        if (!await _voiceRecorder.hasPermission() || !mounted) return;
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/aco_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
        await _voiceRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
          path: path,
        );
        _voiceRecordingPath = path;
        _voiceRecordingStartedAt = DateTime.now();
        _voiceRecordingTimer?.cancel();
        _voiceRecordingTimer = Timer(
          const Duration(seconds: 60),
          () => unawaited(_finishVoiceRecording(send: true)),
        );
        if (mounted) setState(() => _voiceRecording = true);
      case _VoiceRecordingAction.send:
        await _finishVoiceRecording(send: true);
      case _VoiceRecordingAction.cancel:
        await _finishVoiceRecording(send: false);
    }
  }

  Future<void> _finishVoiceRecording({required bool send}) async {
    if (_voiceFinishing || (!_voiceRecording && _voiceRecordingPath == null)) {
      return;
    }
    _voiceFinishing = true;
    try {
      final path = await _voiceRecorder.stop() ?? _voiceRecordingPath;
      _voiceRecordingTimer?.cancel();
      _voiceRecordingTimer = null;
      final startedAt = _voiceRecordingStartedAt;
      _voiceRecordingPath = null;
      _voiceRecordingStartedAt = null;
      if (mounted) setState(() => _voiceRecording = false);
      if (path == null) return;
      final file = File(path);
      if (!send || startedAt == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      final userID = widget.peerUserID;
      if (userID == null ||
          userID.isEmpty ||
          !OpenIMChatRepository.conversationReady.value) {
        if (await file.exists()) await file.delete();
        if (mounted) _showNotice(context, '发送失败', '聊天连接未就绪。');
        return;
      }
      try {
        final duration = DateTime.now()
            .difference(startedAt)
            .inSeconds
            .clamp(1, 60);
        final message = await OpenIM.iMManager.messageManager
            .createSoundMessageFromFullPath(
              soundPath: path,
              duration: duration,
            );
        final sent = await OpenIM.iMManager.messageManager.sendMessage(
          message: message,
          userID: userID,
          offlinePushInfo: OfflinePushInfo(title: '新语音消息', desc: '[语音]'),
        );
        if (!mounted) return;
        _historyMessages.add(sent);
        _pendingSentMessages.add(sent);
        setState(
          () => _chatHistory.add(_ChatHistoryMessage('[语音消息]', mine: true)),
        );
        _scrollToBottom(force: true, animate: false);
        OpenIMChatRepository.conversationRevision.value++;
      } catch (error) {
        if (mounted) _showNotice(context, '语音发送失败', '请稍后重试。');
        debugPrint('[OpenIM] voice send failed: $error');
      } finally {
        if (await file.exists()) await file.delete();
      }
    } finally {
      _voiceFinishing = false;
    }
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
                          padding: const EdgeInsets.fromLTRB(8, 20, 8, 28),
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
                              imagePath: message.imagePath,
                              imageUrl: message.imageUrl,
                              previewImageUrl: message.previewImageUrl,
                              shouldCacheThumbnail:
                                  message.shouldCacheThumbnail,
                              mine: message.mine,
                              avatarUrl: _resolvedPeerAvatar,
                              ownAvatarUrl: widget.ownAvatarUrl,
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

class _VoiceCallPage extends StatefulWidget {
  const _VoiceCallPage({
    required this.name,
    this.avatarUrl,
    this.incoming = false,
  });

  final String name;
  final String? avatarUrl;
  final bool incoming;

  @override
  State<_VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<_VoiceCallPage> {
  var _microphoneEnabled = true;
  var _speakerEnabled = false;
  var _connected = false;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    if (widget.incoming) return;
    // Until call signaling is wired up, present the connected state after a
    // short invite period so the dial screen can be previewed end to end.
    _callTimer = Timer(const Duration(seconds: 2), _connectCall);
  }

  void _connectCall() {
    if (!mounted) return;
    setState(() => _connected = true);
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  void _acceptCall() => _connectCall();

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String get _statusLabel {
    if (_connected) {
      final minutes = _callDuration.inMinutes.toString().padLeft(2, '0');
      final seconds = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
    if (widget.incoming) return '邀请你语音通话...';
    return '等待对方接受邀请.';
  }

  List<Color> get _backgroundColors {
    if (widget.incoming) {
      return const [Color(0xFF151515), Color(0xFF171B24)];
    }
    return const [Color(0xFF263D1B), Color(0xFF0C100C)];
  }

  double get _overlayOpacity => widget.incoming ? .42 : .2;

  double get _statusFontSize => _connected ? 20 : 18;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: const Color(0xFF1A2417),
    child: Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _backgroundColors,
            ),
          ),
        ),
        if (widget.avatarUrl?.isNotEmpty == true)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Opacity(
              opacity: .18,
              child: Image.network(
                widget.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withValues(alpha: _overlayOpacity),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 68,
                child: widget.incoming
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: CupertinoButton(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          onPressed: Navigator.of(context).pop,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A4A4D),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.bell_slash_fill,
                                    color: _white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '忽略',
                                    style: TextStyle(
                                      color: _white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(20),
                            onPressed: Navigator.of(context).pop,
                            child: const Icon(
                              CupertinoIcons.chevron_down,
                              color: _white,
                              size: 28,
                            ),
                          ),
                          if (_connected)
                            CupertinoButton(
                              padding: const EdgeInsets.all(20),
                              onPressed: () {},
                              child: const Icon(
                                CupertinoIcons.person_add,
                                color: _white,
                                size: 25,
                              ),
                            )
                          else
                            const SizedBox(width: 68),
                        ],
                      ),
              ),
              const Spacer(flex: 2),
              _VoiceCallAvatar(name: widget.name, avatarUrl: widget.avatarUrl),
              const SizedBox(height: 22),
              Text(
                widget.name,
                style: const TextStyle(
                  color: _white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusLabel,
                style: TextStyle(
                  color: const Color(0xFFB8B8B8),
                  fontSize: _statusFontSize,
                ),
              ),
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.incoming && !_connected) ...[
                    _VoiceCallControl(
                      icon: CupertinoIcons.phone_down_fill,
                      label: '拒绝',
                      active: false,
                      destructive: true,
                      onPressed: Navigator.of(context).pop,
                    ),
                    _VoiceCallControl(
                      icon: CupertinoIcons.phone_fill,
                      label: '接听',
                      active: true,
                      onPressed: _acceptCall,
                    ),
                  ] else ...[
                    _VoiceCallControl(
                      icon: _microphoneEnabled
                          ? CupertinoIcons.mic_fill
                          : CupertinoIcons.mic_slash_fill,
                      label: _microphoneEnabled ? '麦克风已开' : '麦克风已关',
                      active: _microphoneEnabled,
                      onPressed: () => setState(
                        () => _microphoneEnabled = !_microphoneEnabled,
                      ),
                    ),
                    _VoiceCallControl(
                      icon: CupertinoIcons.phone_down_fill,
                      label: _connected ? '挂断' : '取消',
                      active: false,
                      destructive: true,
                      onPressed: Navigator.of(context).pop,
                    ),
                    _VoiceCallControl(
                      icon: _speakerEnabled
                          ? CupertinoIcons.speaker_3_fill
                          : CupertinoIcons.speaker_slash_fill,
                      label: _speakerEnabled ? '扬声器已开' : '扬声器已关',
                      active: _speakerEnabled,
                      onPressed: () =>
                          setState(() => _speakerEnabled = !_speakerEnabled),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VoiceCallAvatar extends StatelessWidget {
  const _VoiceCallAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 104,
    decoration: BoxDecoration(
      color: const Color(0xFF78B844),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: avatarUrl?.isNotEmpty == true
        ? Image.network(avatarUrl!, fit: BoxFit.cover)
        : Center(
            child: Text(
              name.characters.firstOrNull ?? '?',
              style: const TextStyle(color: _white, fontSize: 64),
            ),
          ),
  );
}

class _VoiceCallControl extends StatelessWidget {
  const _VoiceCallControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: destructive
                ? const Color(0xFFE84D50)
                : active
                ? const Color(0xFFF4F4F4)
                : const Color(0xFF111111).withValues(alpha: .8),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: destructive || !active ? _white : _black,
            size: 34,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(color: _white, fontSize: 16)),
    ],
  );
}

class _VoiceWaveform extends StatefulWidget {
  const _VoiceWaveform();

  @override
  State<_VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<_VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      const baseHeights = <double>[
        8,
        11,
        8,
        13,
        9,
        12,
        8,
        11,
        9,
        22,
        9,
        11,
        8,
        12,
        9,
        13,
        8,
        11,
        8,
      ];
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var index = 0; index < baseHeights.length; index++)
            Container(
              width: 3,
              height:
                  baseHeights[index] *
                  (.72 +
                      .28 *
                          math
                              .sin(
                                _controller.value * math.pi * 2 + index * .75,
                              )
                              .abs()),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF387B2B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      );
    },
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
  static const _maxImageExtent = 215.0;

  const _ChatMessage({
    required this.palette,
    required this.text,
    required this.imageBytes,
    required this.imagePath,
    required this.imageUrl,
    required this.previewImageUrl,
    required this.shouldCacheThumbnail,
    required this.mine,
    this.avatarUrl,
    this.ownAvatarUrl,
  });

  final AcoPalette palette;
  final String text;
  final Uint8List? imageBytes;
  final String? imagePath;
  final String? imageUrl;
  final String? previewImageUrl;
  final bool shouldCacheThumbnail;
  final bool mine;
  final String? avatarUrl;
  final String? ownAvatarUrl;

  bool get _isImageMessage =>
      imageBytes != null || imagePath != null || imageUrl != null;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxBubbleWidth = (constraints.maxWidth - 46).clamp(0.0, 245.0);
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _isImageMessage
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              AcoAvatar(size: 40, imageUrl: avatarUrl),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: _messageBody(context, maxWidth: maxBubbleWidth),
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 6),
              AcoAvatar(size: 40, imageUrl: ownAvatarUrl),
            ],
          ],
        ),
      );
    },
  );

  Widget _messageBody(BuildContext context, {required double maxWidth}) {
    final bytes = imageBytes;
    if (bytes != null) {
      final image = Image.memory(
        bytes,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
      return _image(
        context,
        image,
        maxWidth: maxWidth,
        previewImage: image.image,
      );
    }

    if (imageUrl != null) {
      final previewUrl = previewImageUrl ?? imageUrl!;
      return _image(
        context,
        shouldCacheThumbnail
            ? _CachedChatThumbnail(url: imageUrl!)
            : Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) =>
                    const _ImageUnavailable(),
              ),
        maxWidth: maxWidth,
        previewImage: NetworkImage(previewUrl),
      );
    }

    if (imagePath != null) return const _ImageUnavailable();

    return _Bubble(palette: palette, text: text, mine: mine);
  }

  Widget _image(
    BuildContext context,
    Widget thumbnail, {
    required double maxWidth,
    required ImageProvider previewImage,
  }) => Semantics(
    button: true,
    label: '查看原图',
    child: GestureDetector(
      onTap: () => Navigator.of(context).push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => _ChatImagePreview(image: previewImage),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, _maxImageExtent),
            maxHeight: _maxImageExtent,
          ),
          child: thumbnail,
        ),
      ),
    ),
  );
}

class _ChatImagePreview extends StatelessWidget {
  const _ChatImagePreview({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: const Color(0xFF000000),
    child: SafeArea(
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image(image: image, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(
                CupertinoIcons.xmark,
                color: Color(0xFFFFFFFF),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF2C2C2C),
    child: SizedBox(
      width: 180,
      height: 180,
      child: Center(
        child: Icon(CupertinoIcons.photo, color: Color(0xFFAAAAAA)),
      ),
    ),
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
