part of 'aco_design_shell.dart';

class _ChatPage extends StatefulWidget {
  const _ChatPage({
    required this.palette,
    required this.version,
    this.ownAvatarUrl,
    this.peerUserID,
    this.groupID,
    this.peerName,
    this.conversationID,
  });
  final AcoPalette palette;
  final int version;
  final String? ownAvatarUrl;
  final String? peerUserID;
  final String? groupID;
  final String? peerName;
  final String? conversationID;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  static const _chatImageMaxBytes = 1536 * 1024;
  static const _messageTimeGap = Duration(hours: 1);

  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _chatScrollController = ScrollController();
  var _emojiPickerVisible = false;
  var _morePanelVisible = false;
  var _voiceInputActive = false;
  var _voiceRecording = false;
  final _voiceRecorder = AudioRecorder();
  Timer? _voiceRecordingTimer;
  StreamSubscription<Amplitude>? _voiceAmplitudeSubscription;
  var _voiceFinishing = false;
  var _voiceLevel = 0.0;
  String? _voiceRecordingPath;
  DateTime? _voiceRecordingStartedAt;
  final List<_ChatHistoryMessage> _chatHistory = <_ChatHistoryMessage>[];
  final Map<String, Message> _messagesByClientMsgID = <String, Message>{};
  Future<void>? _loadFuture;
  String? _error;
  String? _resolvedConversationID;
  String? _resolvedPeerName;
  String? _resolvedPeerAvatar;
  int _resolvedPeerIdentity = 0;
  int _resolvedPeerStaffIdentity = 0;
  bool _loadingOlder = false;
  bool _historyEnd = false;
  bool _markingMessagesAsRead = false;
  bool _markMessagesAsReadDirty = false;
  bool _chatAccessGranted = false;
  bool _peerIsBlocked = false;
  bool _mentionVisible = false;
  bool _mentionLoading = false;
  int _mentionStart = -1;
  String _mentionQuery = '';
  List<GroupMembersInfo> _mentionMembers = const [];
  final List<_GroupMention> _selectedMentions = <_GroupMention>[];

  String? get _currentConversationID {
    if (_resolvedConversationID?.isNotEmpty == true) {
      return _resolvedConversationID;
    }
    if (widget.conversationID?.isNotEmpty == true) {
      return widget.conversationID;
    }
    final groupID = widget.groupID;
    if (groupID?.isNotEmpty == true) return 'sg_$groupID';
    final userID = widget.peerUserID;
    return userID?.isNotEmpty == true ? 'si_$userID' : null;
  }

  bool get _isGroup => widget.groupID?.isNotEmpty == true;

  String? get _conversationTarget =>
      _isGroup ? widget.groupID : widget.peerUserID;

  List<Message> get _historyMessages {
    final messages = _messagesByClientMsgID.values.toList();
    messages.sort(_compareMessages);
    return messages;
  }

  Message? get _oldestHistoryMessage {
    Message? oldest;
    for (final message in _messagesByClientMsgID.values) {
      if (oldest == null || _compareMessages(message, oldest) < 0) {
        oldest = message;
      }
    }
    return oldest;
  }

  int _compareMessages(Message a, Message b) {
    final aTime = a.sendTime ?? a.createTime ?? 0;
    final bTime = b.sendTime ?? b.createTime ?? 0;
    return aTime.compareTo(bTime);
  }

  bool _shouldShowMessageTime(int index) {
    final timestamp = _chatHistory[index].timestamp;
    if (timestamp == null || timestamp <= 0) return false;
    if (index == 0) return true;
    final previous = _chatHistory[index - 1].timestamp;
    if (previous == null || previous <= 0) return true;
    return (timestamp - previous).abs() >= _messageTimeGap.inMilliseconds;
  }

  String? _messageTimeLabel(int index) {
    if (!_shouldShowMessageTime(index)) return null;
    final timestamp = _chatHistory[index].timestamp;
    if (timestamp == null || timestamp <= 0) return null;
    final value = timestamp > 100000000000 ? timestamp : timestamp * 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    final now = DateTime.now();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
    }
    return '${date.year}年${date.month}月${date.day}日 '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  @override
  void initState() {
    super.initState();
    final target = _conversationTarget;
    if (target?.isNotEmpty == true) {
      OpenIMChatRepository.beginActiveChat(target!);
    }
    _loadFuture = _loadHistory();
    OpenIMChatRepository.conversationReady.addListener(_onReady);
    OpenIMChatRepository.messageNotifier.addListener(_onMessage);
    _chatScrollController.addListener(_onChatScroll);
    _messageController.addListener(_onComposerChanged);
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
    final mine = message.sendID == OpenIMChatRepository.currentUserID;
    if (_isGroup) {
      if (message.groupID != widget.groupID) return;
    } else if (!_isMessageInCurrentConversation(message)) {
      return;
    }
    if (_voiceCallInviteIDFromMessage(message) != null) return;
    if (!_ChatHistoryMessage.isDisplayable(message)) return;
    _rememberMessage(message);
    final added = _upsertDisplayedMessage(message, mine: mine);
    unawaited(_markCurrentConversationAsRead());
    if (added) _scrollToBottom();
  }

  void _rememberMessage(Message message) {
    final clientMsgID = message.clientMsgID;
    if (clientMsgID?.isNotEmpty != true) return;
    _messagesByClientMsgID[clientMsgID!] = message;
  }

  List<Message> _rememberMessagesIfAbsent(Iterable<Message> messages) {
    final added = <Message>[];
    for (final message in messages) {
      final clientMsgID = message.clientMsgID;
      if (clientMsgID?.isNotEmpty != true) continue;
      if (_messagesByClientMsgID.containsKey(clientMsgID)) continue;
      _messagesByClientMsgID[clientMsgID!] = message;
      added.add(message);
    }
    return added;
  }

  bool _upsertDisplayedMessage(
    Message message, {
    required bool mine,
    Uint8List? imageBytes,
  }) {
    final clientMsgID = message.clientMsgID;
    if (clientMsgID?.isNotEmpty != true ||
        !_ChatHistoryMessage.isDisplayable(message)) {
      return false;
    }
    final index = _chatHistory.indexWhere(
      (item) => item.clientMsgID == clientMsgID,
    );
    final existing = index < 0 ? null : _chatHistory[index];
    final messageFromOpenIM = _ChatHistoryMessage.fromOpenIM(
      message,
      mine: mine,
    );
    final retainedImageBytes = imageBytes ?? existing?.imageBytes;
    var historyMessage = messageFromOpenIM;
    if (retainedImageBytes != null && message.pictureElem != null) {
      historyMessage = _ChatHistoryMessage.image(
        mine: mine,
        clientMsgID: clientMsgID,
        timestamp: messageFromOpenIM.timestamp,
        imageBytes: retainedImageBytes,
        imageUrl: messageFromOpenIM.imageUrl,
        previewImageUrl: messageFromOpenIM.previewImageUrl,
        shouldCacheThumbnail: messageFromOpenIM.shouldCacheThumbnail,
      );
    }
    if (!mounted) return false;
    setState(() {
      if (index < 0) {
        _chatHistory.add(historyMessage);
      } else {
        _chatHistory[index] = historyMessage;
      }
    });
    return index < 0;
  }

  void _removeTrackedMessage(String? clientMsgID) {
    if (clientMsgID?.isNotEmpty != true) return;
    _messagesByClientMsgID.remove(clientMsgID);
    if (!mounted) return;
    setState(() {
      _chatHistory.removeWhere((item) => item.clientMsgID == clientMsgID);
    });
  }

  Future<void> _markCurrentConversationAsRead() async {
    final conversationID = _currentConversationID;
    if (conversationID == null) return;
    if (_markingMessagesAsRead) {
      _markMessagesAsReadDirty = true;
      return;
    }

    _markingMessagesAsRead = true;
    do {
      _markMessagesAsReadDirty = false;
      try {
        await OpenIM.iMManager.conversationManager
            .markConversationMessageAsRead(conversationID: conversationID);
        final pendingConversation = OpenIMChatRepository.pendingConversation;
        if (pendingConversation?.conversationID == conversationID) {
          pendingConversation?.unreadCount = 0;
        }
        OpenIMChatRepository.conversationRevision.value++;
        await OpenIMChatRepository.refreshMessageUnreadStatus();
      } catch (error) {
        debugPrint('[OpenIM] mark read failed: $error');
      }
    } while (_markMessagesAsReadDirty);
    _markingMessagesAsRead = false;
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

  Future<bool> _loadPeerProfile(String userID) async {
    final client = AccountApiClient();
    try {
      final friends = await AccountSession(client).listFriends();
      final matches = friends.where((friend) => friend.accountId == userID);
      if (matches.isEmpty) return false;
      final friend = matches.first;
      if (friend.nickname.isNotEmpty) _resolvedPeerName = friend.nickname;
      if (friend.avatarUrl.isNotEmpty) _resolvedPeerAvatar = friend.avatarUrl;
      _resolvedPeerIdentity = friend.identity;
      _resolvedPeerStaffIdentity = friend.staffIdentity;
      return true;
    } catch (error) {
      debugPrint('[API] chat profile load failed: $error');
      return false;
    } finally {
      client.close();
    }
  }

  Future<void> _loadHistory() async {
    final target = _conversationTarget;
    if (target == null || target.isEmpty) return;
    if (!OpenIMChatRepository.conversationReady.value) {
      _error = '聊天服务正在连接，请稍候重试';
      return;
    }
    try {
      if (!_isGroup && !await _loadPeerProfile(target)) {
        _chatAccessGranted = false;
        _error = '你们已不是好友，无法查看聊天记录';
        return;
      }
      _chatAccessGranted = true;
      if (!_isGroup) await _loadPeerBlockedState(target);
      if (mounted) setState(() {});
      final conversation = await OpenIM.iMManager.conversationManager
          .getOneConversation(
            sourceID: target,
            sessionType: _isGroup
                ? ConversationType.superGroup
                : ConversationType.single,
          );
      _resolvedConversationID = conversation.conversationID;
      final targetMessage = _takeSearchTargetMessage();
      final history = await _loadHistoryWindow(targetMessage);
      _rememberMessagesIfAbsent(history.messages);
      _historyEnd = history.isEnd;
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
                    mine: m.sendID == OpenIMChatRepository.currentUserID,
                  ),
                ),
          );
        _error = null;
      });
      _focusSearchTarget(targetMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '聊天记录加载失败，点击重试');
      debugPrint('[OpenIM] history load failed: $error');
    }
  }

  Message? _takeSearchTargetMessage() {
    final message = OpenIMChatRepository.pendingSearchMessage;
    if (message == null) return null;
    if (!_isMessageInCurrentConversation(message)) return null;
    OpenIMChatRepository.pendingSearchMessage = null;
    return message;
  }

  bool _isMessageInCurrentConversation(Message message) {
    if (_isGroup) return message.groupID == widget.groupID;
    return message.sendID == widget.peerUserID ||
        message.recvID == widget.peerUserID;
  }

  void _focusSearchTarget(Message? targetMessage) {
    final targetID = targetMessage?.clientMsgID;
    if (targetID == null || targetID.isEmpty) return;
    final target = _chatHistory
        .where((message) => message.clientMsgID == targetID)
        .firstOrNull;
    if (target != null) _focusMessage(target);
  }

  Future<_ChatHistoryWindow> _loadHistoryWindow(Message? target) async {
    final conversationID = _resolvedConversationID!;
    if (target == null) {
      final result = await OpenIM.iMManager.messageManager
          .getAdvancedHistoryMessageList(
            conversationID: conversationID,
            count: 30,
          );
      final messages = result.messageList ?? const <Message>[];
      return _ChatHistoryWindow(
        messages: messages,
        isEnd: result.isEnd ?? messages.length < 30,
      );
    }
    final results = await Future.wait([
      OpenIM.iMManager.messageManager.getAdvancedHistoryMessageList(
        conversationID: conversationID,
        startMsg: target,
        count: 18,
      ),
      OpenIM.iMManager.messageManager.getAdvancedHistoryMessageListReverse(
        conversationID: conversationID,
        startMsg: target,
        count: 18,
      ),
    ]);
    final before = results[0];
    final after = results[1];
    final messagesByID = <String, Message>{};
    for (final message in [
      ...?before.messageList,
      target,
      ...?after.messageList,
    ]) {
      final id = message.clientMsgID;
      if (id != null && id.isNotEmpty) messagesByID[id] = message;
    }
    return _ChatHistoryWindow(
      messages: messagesByID.values.toList(growable: false),
      isEnd: before.isEnd ?? false,
    );
  }

  Future<void> _loadPeerBlockedState(String userID) async {
    _peerIsBlocked = await _queryPeerBlockedState(userID);
  }

  Future<bool> _queryPeerBlockedState(
    String userID, {
    bool forceRefresh = false,
  }) async {
    final previousState = _peerIsBlocked;
    try {
      final blacklistedUserIDs = await OpenIMChatRepository.blacklistedUserIDs(
        forceRefresh: forceRefresh,
      );
      return blacklistedUserIDs.contains(userID);
    } catch (error) {
      debugPrint('[OpenIM] blacklist status load failed: $error');
      return previousState;
    }
  }

  Future<bool> _refreshPeerBlockedState(String userID) async {
    _peerIsBlocked = await _queryPeerBlockedState(userID, forceRefresh: true);
    return _peerIsBlocked;
  }

  bool _isBlockedByPeerError(Object error) =>
      (error is PlatformException && error.code == '1302') ||
      error.toString().contains('1302') ||
      error.toString().contains('BlockedByPeer');

  void _appendFailedText(String text, {String? clientMsgID}) {
    _removeTrackedMessage(clientMsgID);
    if (!mounted) return;
    setState(
      () => _chatHistory.add(
        _ChatHistoryMessage(text, mine: true, sendFailed: true),
      ),
    );
    _peerIsBlocked = true;
    _scrollToBottom(force: true, animate: false);
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || _historyEnd) return;
    final oldestMessage = _oldestHistoryMessage;
    if (oldestMessage == null) return;
    final target = _conversationTarget;
    final conversationID = _resolvedConversationID;
    if (target == null || conversationID == null) return;
    _loadingOlder = true;
    final oldMaxExtent = _chatScrollController.hasClients
        ? _chatScrollController.position.maxScrollExtent
        : 0.0;
    try {
      final result = await OpenIM.iMManager.messageManager
          .getAdvancedHistoryMessageList(
            conversationID: conversationID,
            startMsg: oldestMessage,
            count: 30,
          );
      final older = result.messageList ?? const <Message>[];
      if (older.isEmpty) {
        _historyEnd = true;
        return;
      }
      final addedMessages = _rememberMessagesIfAbsent(older)
        ..sort(_compareMessages);
      final olderHistory = addedMessages
          .where(_ChatHistoryMessage.isDisplayable)
          .map(
            (message) => _ChatHistoryMessage.fromOpenIM(
              message,
              mine: message.sendID == OpenIMChatRepository.currentUserID,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      if (olderHistory.isNotEmpty) {
        setState(() => _chatHistory.insertAll(0, olderHistory));
      }
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
    final target = _conversationTarget;
    if (text.isEmpty || target == null || target.isEmpty) return;
    if (!_isGroup) await _loadPeerBlockedState(target);
    if (_peerIsBlocked) {
      final shouldFollowNewMessage =
          !_chatScrollController.hasClients ||
          _chatScrollController.position.pixels <= 80;
      _messageController.clear();
      if (!mounted) return;
      setState(
        () => _chatHistory.add(
          _ChatHistoryMessage(text, mine: true, sendFailed: true),
        ),
      );
      _scrollToBottom(force: shouldFollowNewMessage, animate: false);
      return;
    }
    if (!_chatAccessGranted) {
      if (!mounted) return;
      _showNotice(context, '无法发送', '请先确认你们仍是好友。');
      return;
    }
    final shouldFollowNewMessage =
        !_chatScrollController.hasClients ||
        _chatScrollController.position.pixels <= 80;
    if (!OpenIMChatRepository.conversationReady.value) {
      if (!mounted) return;
      _showNotice(context, '连接未就绪', '聊天连接恢复后再发送。');
      return;
    }
    final mentions = _mentionsIn(text);
    _messageController.clear();
    _selectedMentions.clear();
    String? outgoingClientMsgID;
    try {
      final message = mentions.isEmpty
          ? await OpenIM.iMManager.messageManager.createTextMessage(text: text)
          : await OpenIM.iMManager.messageManager.createTextAtMessage(
              text: text,
              atUserIDList: mentions.map((mention) => mention.userID).toList(),
              atUserInfoList: mentions
                  .map(
                    (mention) => AtUserInfo(
                      atUserID: mention.userID,
                      groupNickname: mention.name,
                    ),
                  )
                  .toList(),
            );
      outgoingClientMsgID = message.clientMsgID;
      _rememberMessage(message);
      final sent = await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: _isGroup ? null : target,
        groupID: _isGroup ? target : null,
        offlinePushInfo: OfflinePushInfo(title: '新消息', desc: text),
      );
      debugPrint(
        '[OpenIM] message sent clientMsgID=${sent.clientMsgID} '
        'serverMsgID=${sent.serverMsgID} status=${sent.status} '
        'to=$target',
      );
      if (!mounted) return;
      _rememberMessage(sent);
      final added = _upsertDisplayedMessage(sent, mine: true);
      // The composer/keyboard can resize the viewport in a later frame. Use
      // a short scroll when the user was already following the conversation.
      // When reading older messages, preserve their position like WeChat.
      if (added) {
        _scrollToBottom(force: shouldFollowNewMessage, animate: false);
      }
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
      final blockedByPeer = _isBlockedByPeerError(error);
      if (blockedByPeer) await _refreshPeerBlockedState(target);
      if (_peerIsBlocked || blockedByPeer) {
        _appendFailedText(text, clientMsgID: outgoingClientMsgID);
        return;
      }
      _removeTrackedMessage(outgoingClientMsgID);
      if (!mounted) return;
      _showNotice(context, '发送失败', '请稍后重试');
      debugPrint('[OpenIM] send failed: $error');
    }
  }

  Future<void> _clearCurrentConversationMessages() async {
    final conversationID = _currentConversationID;
    if (conversationID == null || conversationID.isEmpty) {
      throw StateError('Conversation is unavailable');
    }
    await OpenIM.iMManager.conversationManager.markConversationMessageAsRead(
      conversationID: conversationID,
    );
    await OpenIM.iMManager.conversationManager.clearConversationAndDeleteAllMsg(
      conversationID: conversationID,
    );
    final pendingConversation = OpenIMChatRepository.pendingConversation;
    if (pendingConversation?.conversationID == conversationID) {
      pendingConversation?.unreadCount = 0;
    }
    OpenIMChatRepository.conversationRevision.value++;
    await OpenIMChatRepository.refreshMessageUnreadStatus();
    if (!mounted) return;
    setState(() {
      _messagesByClientMsgID.clear();
      _chatHistory.clear();
      _historyEnd = true;
    });
  }

  @override
  void dispose() {
    final target = _conversationTarget;
    if (target?.isNotEmpty == true) {
      OpenIMChatRepository.endActiveChat(target!);
    }
    OpenIMChatRepository.conversationReady.removeListener(_onReady);
    OpenIMChatRepository.messageNotifier.removeListener(_onMessage);
    _chatScrollController.removeListener(_onChatScroll);
    _messageController.removeListener(_onComposerChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _chatScrollController.dispose();
    _voiceRecordingTimer?.cancel();
    _voiceAmplitudeSubscription?.cancel();
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

  void _focusMessage(_ChatHistoryMessage message) {
    if (!_chatHistory.contains(message)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final historyIndex = _chatHistory.indexOf(message);
      if (historyIndex < 0) return;

      final position = _chatScrollController.position;
      if (_chatHistory.length > 1) {
        final reversedIndex = _chatHistory.length - historyIndex - 1;
        final estimatedOffset =
            position.maxScrollExtent *
            reversedIndex /
            (_chatHistory.length - 1);
        final target = estimatedOffset
            .clamp(0.0, position.maxScrollExtent)
            .toDouble();
        if ((position.pixels - target).abs() >= 1) {
          _chatScrollController.jumpTo(target);
        }
      }
    });
  }

  Key? _messageKey(_ChatHistoryMessage message) {
    final clientMsgID = message.clientMsgID;
    return clientMsgID?.isNotEmpty == true ? ValueKey(clientMsgID) : null;
  }

  bool get _isPanelVisible => _emojiPickerVisible || _morePanelVisible;

  String get _peerName {
    final name = _resolvedPeerName ?? widget.peerName?.trim();
    return name?.isNotEmpty == true ? name! : (_conversationTarget ?? '聊天');
  }

  Future<void> _pickChatImage(ImageSource source) async {
    setState(() => _morePanelVisible = false);
    File? pickedImage;
    Uint8List? pickedImageBytes;
    String? outgoingClientMsgID;
    final target = _conversationTarget;
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
      pickedImageBytes = imageBytes;
      if (target == null || target.isEmpty) return;
      if (!_isGroup) await _loadPeerBlockedState(target);
      if (_peerIsBlocked) {
        if (mounted) {
          setState(
            () => _chatHistory.add(
              _ChatHistoryMessage.image(
                mine: true,
                imageBytes: pickedImageBytes,
                sendFailed: true,
              ),
            ),
          );
          _scrollToBottom(force: true, animate: false);
        }
        return;
      }
      if (!_chatAccessGranted) {
        if (mounted) _showNotice(context, '无法发送', '请先确认你们仍是好友。');
        return;
      }
      if (!OpenIMChatRepository.conversationReady.value) {
        if (!mounted) return;
        _showNotice(context, '连接未就绪', '聊天连接恢复后再发送。');
        return;
      }
      final message = await OpenIM.iMManager.messageManager
          .createImageMessageFromFullPath(imagePath: photo.path);
      outgoingClientMsgID = message.clientMsgID;
      _rememberMessage(message);
      final sent = await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: _isGroup ? null : target,
        groupID: _isGroup ? target : null,
        offlinePushInfo: OfflinePushInfo(title: '新消息', desc: '[图片]'),
      );
      if (!mounted) return;
      _rememberMessage(sent);
      final added = _upsertDisplayedMessage(
        sent,
        mine: true,
        imageBytes: imageBytes,
      );
      if (added) _scrollToBottom(force: true, animate: false);
      OpenIMChatRepository.conversationRevision.value++;
    } catch (error) {
      _removeTrackedMessage(outgoingClientMsgID);
      final blockedByPeer = _isBlockedByPeerError(error);
      if (blockedByPeer && target?.isNotEmpty == true) {
        await _refreshPeerBlockedState(target!);
      }
      if (_peerIsBlocked || blockedByPeer) {
        if (mounted) {
          setState(
            () => _chatHistory.add(
              _ChatHistoryMessage.image(
                mine: true,
                imageBytes: pickedImageBytes,
                sendFailed: true,
              ),
            ),
          );
          _peerIsBlocked = true;
          _scrollToBottom(force: true, animate: false);
        }
        return;
      }
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
      if (_isGroup) {
        _showNotice(context, '暂不支持', '群语音将在后续版本开放。');
        return;
      }
      final userID = widget.peerUserID;
      if (userID == null || userID.isEmpty || !_chatAccessGranted) {
        _showNotice(context, '无法发起通话', '请先确认你们仍是好友。');
        return;
      }
      final client = AccountApiClient();
      try {
        final call = await AccountSession(client).startVoiceCall(userID);
        final invite = await OpenIM.iMManager.messageManager
            .createCustomMessage(
              data: jsonEncode({
                'type': 'aco.voice_call.invite',
                'call_id': call.callId,
              }),
              extension: 'aco.voice_call',
              description: '语音通话邀请',
            );
        await OpenIM.iMManager.messageManager.sendMessage(
          message: invite,
          userID: userID,
          offlinePushInfo: OfflinePushInfo(title: '语音通话', desc: '邀请你进行语音通话'),
        );
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          _AcoPageRoute<void>(
            builder: (_) => _VoiceCallPage(
              name: _peerName,
              avatarUrl: _resolvedPeerAvatar,
              callID: call.callId,
              peerUserID: userID,
            ),
          ),
        );
      } catch (error) {
        if (mounted) _showNotice(context, '无法发起通话', '请检查网络后重试。');
        debugPrint('[VoiceCall] start failed: $error');
      } finally {
        client.close();
      }
      return;
    }
    setState(() => _morePanelVisible = false);
    _showNotice(context, label, '$label功能暂未开放。');
  }

  void _hidePanels() {
    if (!_isPanelVisible && !_mentionVisible) return;
    setState(() {
      _emojiPickerVisible = false;
      _morePanelVisible = false;
      _mentionVisible = false;
    });
  }

  void _onComposerChanged() {
    if (!_isGroup) return;
    final selection = _messageController.selection;
    final cursor = selection.extentOffset;
    if (!selection.isValid || cursor < 0) return;
    final textBeforeCursor = _messageController.text.substring(0, cursor);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    final isMentionStart =
        atIndex >= 0 &&
        (atIndex == 0 || _isMentionBoundary(textBeforeCursor[atIndex - 1]));
    final query = isMentionStart ? textBeforeCursor.substring(atIndex + 1) : '';
    final shouldShow = isMentionStart && !query.contains(RegExp(r'\s'));
    if (_mentionVisible != shouldShow ||
        _mentionStart != (shouldShow ? atIndex : -1) ||
        _mentionQuery != (shouldShow ? query : '')) {
      setState(() {
        _mentionVisible = shouldShow;
        _mentionStart = shouldShow ? atIndex : -1;
        _mentionQuery = shouldShow ? query : '';
      });
    }
    if (shouldShow) unawaited(_loadMentionMembers());
  }

  bool _isMentionBoundary(String character) =>
      RegExp(r'\s').hasMatch(character);

  Future<void> _loadMentionMembers() async {
    final groupID = widget.groupID;
    if (_mentionLoading ||
        _mentionMembers.isNotEmpty ||
        groupID == null ||
        groupID.isEmpty) {
      return;
    }
    setState(() => _mentionLoading = true);
    try {
      final members = await OpenIM.iMManager.groupManager.getGroupMemberList(
        groupID: groupID,
        count: 500,
      );
      if (mounted) setState(() => _mentionMembers = members);
    } catch (error) {
      debugPrint('[OpenIM] load mention members failed: $error');
    } finally {
      if (mounted) setState(() => _mentionLoading = false);
    }
  }

  List<GroupMembersInfo> get _filteredMentionMembers {
    final query = _mentionQuery.trim().toLowerCase();
    final currentUserID = OpenIMChatRepository.currentUserID;
    return _mentionMembers
        .where((member) {
          final userID = member.userID;
          if (userID == null || userID.isEmpty) return false;
          if (userID == currentUserID) return false;
          if (query.isEmpty) return true;
          final name = _mentionName(member).toLowerCase();
          return name.contains(query) || userID.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  String _mentionName(GroupMembersInfo member) {
    final name = member.nickname?.trim() ?? '';
    return name.isEmpty ? (member.userID ?? '成员') : name;
  }

  void _insertMention(GroupMembersInfo member) {
    final userID = member.userID;
    final selection = _messageController.selection;
    if (userID == null ||
        userID.isEmpty ||
        _mentionStart < 0 ||
        !selection.isValid) {
      return;
    }
    final cursor = selection.extentOffset;
    _insertMentionToken(
      userID: userID,
      name: _mentionName(member),
      start: _mentionStart,
      end: cursor,
    );
  }

  void _mentionMessageSender({
    required String? userID,
    required String? nickname,
  }) {
    if (!_isGroup ||
        userID == null ||
        userID.isEmpty ||
        userID == OpenIMChatRepository.currentUserID) {
      return;
    }
    final selection = _messageController.selection;
    final text = _messageController.text;
    final cursor = selection.isValid
        ? selection.extentOffset.clamp(0, text.length).toInt()
        : text.length;
    final name = nickname?.trim();
    _insertMentionToken(
      userID: userID,
      name: name == null || name.isEmpty ? userID : name,
      start: cursor,
      end: cursor,
    );
    setState(() {
      _voiceInputActive = false;
      _emojiPickerVisible = false;
      _morePanelVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _messageFocusNode.requestFocus();
    });
  }

  void _insertMentionToken({
    required String userID,
    required String name,
    required int start,
    required int end,
  }) {
    final token = '@$name ';
    final text = _messageController.text;
    _messageController.value = TextEditingValue(
      text: '${text.substring(0, start)}$token${text.substring(end)}',
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    _selectedMentions.removeWhere((mention) => mention.userID == userID);
    _selectedMentions.add(_GroupMention(userID: userID, name: name));
  }

  List<_GroupMention> _mentionsIn(String text) => _selectedMentions
      .where((mention) => text.contains(mention.token))
      .toList(growable: false);

  void _toggleEmojiPicker() {
    _dismissKeyboard();
    setState(() {
      _emojiPickerVisible = !_emojiPickerVisible;
      _morePanelVisible = false;
      _mentionVisible = false;
    });
  }

  void _toggleMorePanel() {
    _dismissKeyboard();
    setState(() {
      _morePanelVisible = !_morePanelVisible;
      _emojiPickerVisible = false;
      _mentionVisible = false;
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
        await _voiceAmplitudeSubscription?.cancel();
        _voiceAmplitudeSubscription = _voiceRecorder
            .onAmplitudeChanged(const Duration(milliseconds: 80))
            .listen((amplitude) {
              if (!mounted || !_voiceRecording) return;
              final level = ((amplitude.current + 58) / 48).clamp(0.0, 1.0);
              if ((level - _voiceLevel).abs() >= .03) {
                setState(() => _voiceLevel = level);
              }
            });
        _voiceRecordingPath = path;
        _voiceRecordingStartedAt = DateTime.now();
        _voiceRecordingTimer?.cancel();
        _voiceRecordingTimer = Timer(
          const Duration(seconds: 60),
          () => unawaited(_finishVoiceRecording(send: true)),
        );
        if (mounted) {
          setState(() {
            _voiceLevel = 0;
            _voiceRecording = true;
          });
        }
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
      await _voiceAmplitudeSubscription?.cancel();
      _voiceAmplitudeSubscription = null;
      final startedAt = _voiceRecordingStartedAt;
      _voiceRecordingPath = null;
      _voiceRecordingStartedAt = null;
      if (mounted) {
        setState(() {
          _voiceLevel = 0;
          _voiceRecording = false;
        });
      }
      if (path == null) return;
      final file = File(path);
      if (!send || startedAt == null) {
        if (await file.exists()) await file.delete();
        return;
      }
      final target = _conversationTarget;
      if (!_isGroup && target != null && target.isNotEmpty) {
        await _loadPeerBlockedState(target);
      }
      if (_peerIsBlocked) {
        final duration = DateTime.now()
            .difference(startedAt)
            .inSeconds
            .clamp(1, 60);
        if (mounted) {
          setState(
            () => _chatHistory.add(
              _ChatHistoryMessage.sound(
                mine: true,
                soundPath: path,
                soundDuration: duration,
                sendFailed: true,
              ),
            ),
          );
          _scrollToBottom(force: true, animate: false);
        }
        return;
      }
      if (target == null ||
          target.isEmpty ||
          !_chatAccessGranted ||
          !OpenIMChatRepository.conversationReady.value) {
        if (await file.exists()) await file.delete();
        if (mounted) _showNotice(context, '发送失败', '聊天连接未就绪。');
        return;
      }
      var sentSuccessfully = false;
      String? outgoingClientMsgID;
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
        outgoingClientMsgID = message.clientMsgID;
        _rememberMessage(message);
        final sent = await OpenIM.iMManager.messageManager.sendMessage(
          message: message,
          userID: _isGroup ? null : target,
          groupID: _isGroup ? target : null,
          offlinePushInfo: OfflinePushInfo(title: '新语音消息', desc: '[语音]'),
        );
        if (!mounted) return;
        _rememberMessage(sent);
        final added = _upsertDisplayedMessage(sent, mine: true);
        if (added) _scrollToBottom(force: true, animate: false);
        OpenIMChatRepository.conversationRevision.value++;
        sentSuccessfully = true;
      } catch (error) {
        _removeTrackedMessage(outgoingClientMsgID);
        final blockedByPeer = _isBlockedByPeerError(error);
        if (blockedByPeer) await _refreshPeerBlockedState(target);
        if (_peerIsBlocked || blockedByPeer) {
          final failedDuration = DateTime.now()
              .difference(startedAt)
              .inSeconds
              .clamp(1, 60);
          if (mounted) {
            setState(
              () => _chatHistory.add(
                _ChatHistoryMessage.sound(
                  mine: true,
                  soundPath: path,
                  soundDuration: failedDuration,
                  sendFailed: true,
                ),
              ),
            );
            _peerIsBlocked = true;
            _scrollToBottom(force: true, animate: false);
          }
          sentSuccessfully = true;
          return;
        }
        if (mounted) _showNotice(context, '语音发送失败', '请稍后重试。');
        debugPrint('[OpenIM] voice send failed: $error');
      } finally {
        if (!sentSuccessfully && await file.exists()) await file.delete();
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
      titleWidget: _ChatHeaderTitle(
        palette: widget.palette,
        name: _peerName,
        identity: _resolvedPeerIdentity,
        staffIdentity: _resolvedPeerStaffIdentity,
      ),
      headerRightPadding: 4,
      right: Semantics(
        button: true,
        label: '更多',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(51, 30),
          onPressed: () async {
            final exitedGroup = await Navigator.of(context).push<bool>(
              _AcoPageRoute<bool>(
                builder: (_) => CupertinoPageScaffold(
                  backgroundColor: widget.palette.background,
                  child: SafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: ColoredBox(
                      color: widget.palette.background,
                      child: SizedBox.expand(
                        child: _ChatMoreSettingsPage(
                          palette: widget.palette,
                          peerName: _peerName,
                          peerUserID: widget.peerUserID,
                          groupID: widget.groupID,
                          conversationID: _currentConversationID,
                          onBlockChanged: (blocked) => _peerIsBlocked = blocked,
                          messages: _chatHistory,
                          onMessageTap: _focusMessage,
                          onClearMessages: _clearCurrentConversationMessages,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            if (exitedGroup != true || !mounted) return;
            Navigator.of(this.context).pop();
          },
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
                            final sourceMessage = message.clientMsgID == null
                                ? null
                                : _messagesByClientMsgID[message.clientMsgID];
                            final timeLabel = _messageTimeLabel(
                              _chatHistory.length - 1 - index,
                            );
                            return KeyedSubtree(
                              key: _messageKey(message),
                              child: Column(
                                children: [
                                  if (timeLabel != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Center(
                                        child: Text(
                                          timeLabel,
                                          style: const TextStyle(
                                            color: Color(0xFF8D8D8D),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  _ChatMessage(
                                    palette: widget.palette,
                                    text: message.text,
                                    imageBytes: message.imageBytes,
                                    imagePath: message.imagePath,
                                    imageUrl: message.imageUrl,
                                    previewImageUrl: message.previewImageUrl,
                                    shouldCacheThumbnail:
                                        message.shouldCacheThumbnail,
                                    soundPath: message.soundPath,
                                    soundUrl: message.soundUrl,
                                    soundDuration: message.soundDuration,
                                    isVoiceCallRecord:
                                        message.isVoiceCallRecord,
                                    sendFailed: message.sendFailed,
                                    mine: message.mine,
                                    avatarUrl: _isGroup
                                        ? sourceMessage?.senderFaceUrl ??
                                              _resolvedPeerAvatar
                                        : _resolvedPeerAvatar,
                                    ownAvatarUrl: widget.ownAvatarUrl,
                                    onAvatarLongPress: _isGroup
                                        ? () => _mentionMessageSender(
                                            userID: sourceMessage?.sendID,
                                            nickname:
                                                sourceMessage?.senderNickname,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (_mentionVisible)
                  _GroupMentionPanel(
                    members: _filteredMentionMembers,
                    loading: _mentionLoading,
                    onSelected: _insertMention,
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
                        5,
                        8,
                        compactBottomBar ? 5 : 8,
                      ),
                      child: _ChatComposer(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
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
                  _ChatMorePanel(
                    isGroup: _isGroup,
                    onSelected: _handleMorePanelSelection,
                  ),
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
                    ? _VoiceRecordingOverlay(
                        key: ValueKey('voice-recording'),
                        level: _voiceLevel,
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

class _ChatHistoryWindow {
  const _ChatHistoryWindow({required this.messages, required this.isEnd});

  final List<Message> messages;
  final bool isEnd;
}

class _ChatHeaderTitle extends StatelessWidget {
  const _ChatHeaderTitle({
    required this.palette,
    required this.name,
    required this.identity,
    required this.staffIdentity,
  });

  final AcoPalette palette;
  final String name;
  final int identity;
  final int staffIdentity;

  @override
  Widget build(BuildContext context) {
    final identityIconAsset = _identityNodeAsset(identity);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (identityIconAsset != null) ...[
            const SizedBox(width: 5),
            Image.asset(
              identityIconAsset,
              width: _shortBadgeWidth(identity),
              fit: BoxFit.contain,
            ),
          ],
          if (_staffBadgeAsset(staffIdentity) case final staffAsset?) ...[
            const SizedBox(width: 3),
            Image.asset(
              staffAsset,
              width: _shortBadgeWidth(staffIdentity),
              fit: BoxFit.contain,
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceRecordingOverlay extends StatelessWidget {
  const _VoiceRecordingOverlay({super.key, required this.level});

  final double level;

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
                  color: const Color(0xFF28B561),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _VoiceWaveform(level: level),
              ),
              Positioned(
                bottom: -7,
                child: Transform.rotate(
                  angle: .785398,
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: ColoredBox(color: Color(0xFF28B561)),
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
    required this.callID,
    required this.peerUserID,
    this.avatarUrl,
    this.incoming = false,
  });

  final String name;
  final String callID;
  final String peerUserID;
  final String? avatarUrl;
  final bool incoming;

  @override
  State<_VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<_VoiceCallPage> {
  var _microphoneEnabled = true;
  var _speakerEnabled = false;
  var _connected = false;
  var _connecting = false;
  var _ending = false;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;
  Timer? _statusTimer;
  var _statusRefreshing = false;
  Timer? _outgoingToneRestartTimer;
  Room? _room;
  final _callTonePlayer = AudioPlayer();
  StreamSubscription<void>? _outgoingToneCompleteSubscription;
  var _callToneStopped = false;
  late final AccountApiClient _apiClient;
  late final AccountSession _accountSession;

  @override
  void initState() {
    super.initState();
    _apiClient = AccountApiClient();
    _accountSession = AccountSession(_apiClient);
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshCallStatus());
    });
    unawaited(_startCallTone());
  }

  Future<void> _startCallTone() async {
    _callToneStopped = false;
    try {
      if (widget.incoming) {
        await _callTonePlayer.setReleaseMode(ReleaseMode.loop);
        await _callTonePlayer.play(AssetSource('sounds/ringtone.wav'));
        return;
      }

      await _callTonePlayer.setReleaseMode(ReleaseMode.stop);
      await _outgoingToneCompleteSubscription?.cancel();
      _outgoingToneCompleteSubscription = _callTonePlayer.onPlayerComplete
          .listen((_) => _scheduleOutgoingToneReplay());
      await _playOutgoingTone();
    } catch (error) {
      debugPrint('[VoiceCall] call tone playback failed: $error');
    }
  }

  Future<void> _playOutgoingTone() async {
    if (_callToneStopped) return;
    try {
      await _callTonePlayer.play(AssetSource('sounds/dial_tone.wav'));
    } catch (error) {
      debugPrint('[VoiceCall] outgoing call tone playback failed: $error');
    }
  }

  void _scheduleOutgoingToneReplay() {
    if (_callToneStopped) return;
    _outgoingToneRestartTimer?.cancel();
    _outgoingToneRestartTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_playOutgoingTone());
    });
  }

  Future<void> _stopCallTone() async {
    _callToneStopped = true;
    _outgoingToneRestartTimer?.cancel();
    _outgoingToneRestartTimer = null;
    await _outgoingToneCompleteSubscription?.cancel();
    _outgoingToneCompleteSubscription = null;
    try {
      await _callTonePlayer.stop();
    } catch (error) {
      debugPrint('[VoiceCall] call tone stop failed: $error');
    }
  }

  void _setConnecting(bool value) {
    _connecting = value;
    if (mounted) setState(() {});
  }

  Future<void> _refreshCallStatus() async {
    if (_connecting || _ending || _statusRefreshing) return;
    _statusRefreshing = true;
    try {
      final call = await _accountSession.voiceCallStatus(widget.callID);
      if (!mounted || _ending) return;
      if (call.status == 'active' && !_connected) {
        await _joinCall();
      } else if (call.status == 'ended') {
        await _closeAfterRemoteEnd();
      }
    } catch (error) {
      debugPrint('[VoiceCall] status failed: $error');
    } finally {
      _statusRefreshing = false;
    }
  }

  Future<void> _acceptCall() async {
    if (_connecting || _ending) return;
    _setConnecting(true);
    await _stopCallTone();
    try {
      final call = await _accountSession.acceptVoiceCall(widget.callID);
      await _connectLiveKit(call);
    } catch (error) {
      if (mounted) _showNotice(context, '无法接听', '请检查网络后重试。');
      debugPrint('[VoiceCall] accept failed: $error');
    } finally {
      _setConnecting(false);
    }
  }

  Future<void> _joinCall() async {
    if (_connecting || _connected || _ending) return;
    _setConnecting(true);
    await _stopCallTone();
    try {
      final call = await _accountSession.joinVoiceCall(widget.callID);
      await _connectLiveKit(call);
    } catch (error) {
      debugPrint('[VoiceCall] join failed: $error');
    } finally {
      _setConnecting(false);
    }
  }

  Future<void> _connectLiveKit(VoiceCallInfo call) async {
    if (!call.hasLiveKitCredentials) throw StateError('Missing LiveKit token');
    await LiveKitClient.initialize();
    final room = Room(
      roomOptions: const RoomOptions(
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: false),
      ),
    );
    try {
      await room.connect(call.url!, call.token!);
      await AudioManager.instance.setSpeakerOutputPreferred(false);
      await room.localParticipant?.setMicrophoneEnabled(_microphoneEnabled);
    } catch (_) {
      await room.disconnect();
      rethrow;
    }
    if (!mounted) {
      await room.disconnect();
      return;
    }
    _room = room;
    setState(() => _connected = true);
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _toggleMicrophone() async {
    final nextEnabled = !_microphoneEnabled;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(nextEnabled);
      if (mounted) setState(() => _microphoneEnabled = nextEnabled);
    } catch (error) {
      debugPrint('[VoiceCall] microphone toggle failed: $error');
    }
  }

  Future<void> _toggleSpeaker() async {
    final nextEnabled = !_speakerEnabled;
    try {
      await AudioManager.instance.setSpeakerOutputPreferred(nextEnabled);
      if (mounted) setState(() => _speakerEnabled = nextEnabled);
    } catch (error) {
      debugPrint('[VoiceCall] speaker toggle failed: $error');
    }
  }

  Future<void> _endAndClose() async {
    if (_ending) return;
    _ending = true;
    _statusTimer?.cancel();
    await _stopCallTone();
    var ended = false;
    try {
      await _accountSession.endVoiceCall(widget.callID);
      ended = true;
    } catch (error) {
      debugPrint('[VoiceCall] end failed: $error');
    }
    Message? record;
    if (ended) record = await _sendCallRecord();
    await _room?.disconnect();
    _room = null;
    if (mounted) Navigator.of(context).pop(record);
  }

  Future<Message?> _sendCallRecord() async {
    final status = _callRecordStatus;
    try {
      final message = await OpenIM.iMManager.messageManager.createCustomMessage(
        data: jsonEncode({
          'type': 'aco.voice_call.ended',
          'call_id': widget.callID,
          'status': status,
          'duration_seconds': _callDuration.inSeconds,
        }),
        extension: 'aco.voice_call',
        description: '语音通话',
      );
      final sent = await OpenIM.iMManager.messageManager.sendMessage(
        message: message,
        userID: widget.peerUserID,
        offlinePushInfo: OfflinePushInfo(title: '语音通话', desc: '语音通话记录'),
      );
      OpenIMChatRepository.publishLocalMessage(sent);
      return sent;
    } catch (error) {
      debugPrint('[VoiceCall] call record send failed: $error');
      return null;
    }
  }

  String get _callRecordStatus {
    if (_connected) return 'completed';
    if (widget.incoming) return 'declined';
    return 'cancelled';
  }

  Future<void> _closeAfterRemoteEnd() async {
    if (_ending) return;
    _ending = true;
    _statusTimer?.cancel();
    _callTimer?.cancel();
    await _stopCallTone();
    await _room?.disconnect();
    _room = null;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _statusTimer?.cancel();
    _callToneStopped = true;
    _outgoingToneRestartTimer?.cancel();
    unawaited(
      _outgoingToneCompleteSubscription?.cancel() ?? Future<void>.value(),
    );
    unawaited(_callTonePlayer.dispose());
    unawaited(_room?.disconnect() ?? Future<void>.value());
    _apiClient.close();
    super.dispose();
  }

  String get _statusLabel {
    if (_connected) {
      final minutes = _callDuration.inMinutes.toString().padLeft(2, '0');
      final seconds = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
    if (_connecting) return '正在连接...';
    if (widget.incoming) return '邀请你语音通话...';
    return '等待对方接受邀请.';
  }

  double get _statusFontSize => _connected ? 20 : 18;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              _VoiceCallAvatar(avatarUrl: widget.avatarUrl),
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
                      onPressed: _endAndClose,
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
                      onPressed: () => unawaited(_toggleMicrophone()),
                    ),
                    _VoiceCallControl(
                      icon: CupertinoIcons.phone_down_fill,
                      label: _connected ? '挂断' : '取消',
                      active: false,
                      destructive: true,
                      onPressed: _endAndClose,
                    ),
                    _VoiceCallControl(
                      icon: _speakerEnabled
                          ? CupertinoIcons.speaker_3_fill
                          : CupertinoIcons.speaker_slash_fill,
                      label: _speakerEnabled ? '扬声器已开' : '扬声器已关',
                      active: _speakerEnabled,
                      onPressed: () => unawaited(_toggleSpeaker()),
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
  const _VoiceCallAvatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    height: 104,
    child: ClipOval(
      child: avatarUrl?.isNotEmpty == true
          ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _defaultAvatar(),
            )
          : _defaultAvatar(),
    ),
  );

  Widget _defaultAvatar() => Image.asset(
    _defaultAvatarAsset,
    fit: BoxFit.cover,
    semanticLabel: '默认头像',
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
          width: 70,
          height: 70,
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
            size: 28,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(color: _white, fontSize: 16)),
    ],
  );
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
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
    final multiplier = 1 + level * 1.7;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final height in baseHeights)
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            width: 3,
            height: height * multiplier,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF387B2B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
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
  const _ChatMorePanel({required this.isGroup, required this.onSelected});

  final bool isGroup;
  final Future<void> Function(String label) onSelected;

  static const _items = [
    (
      label: '照片',
      assetPath: 'assets/icons/chat_more_photo.png',
      availableInGroup: true,
    ),
    (
      label: '拍摄',
      assetPath: 'assets/icons/chat_more_camera.png',
      availableInGroup: true,
    ),
    (
      label: '语音通话',
      assetPath: 'assets/icons/chat_more_call.png',
      availableInGroup: false,
    ),
    (
      label: '转账',
      assetPath: 'assets/icons/chat_more_transfer.png',
      availableInGroup: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = isGroup
        ? _items.where((item) => item.availableInGroup).toList()
        : _items;
    return Container(
      height: 116,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1D1B),
        border: Border(top: BorderSide(color: Color(0xFF515151))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 16,
          childAspectRatio: .77,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
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
                      color: const Color(0xFF2C2C2C),
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
    required this.soundPath,
    required this.soundUrl,
    required this.soundDuration,
    required this.isVoiceCallRecord,
    required this.sendFailed,
    required this.mine,
    this.avatarUrl,
    this.ownAvatarUrl,
    this.onAvatarLongPress,
  });

  final AcoPalette palette;
  final String text;
  final Uint8List? imageBytes;
  final String? imagePath;
  final String? imageUrl;
  final String? previewImageUrl;
  final bool shouldCacheThumbnail;
  final String? soundPath;
  final String? soundUrl;
  final int? soundDuration;
  final bool isVoiceCallRecord;
  final bool sendFailed;
  final bool mine;
  final String? avatarUrl;
  final String? ownAvatarUrl;
  final VoidCallback? onAvatarLongPress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxBubbleWidth = (constraints.maxWidth - 46).clamp(0.0, 245.0);
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              GestureDetector(
                onLongPress: onAvatarLongPress,
                child: AcoAvatar(size: 40, imageUrl: avatarUrl),
              ),
              const SizedBox(width: 6),
            ],
            if (mine && sendFailed)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  color: Color(0xFFFF3B30),
                  size: 19,
                ),
              ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                child: _copyableMessageBody(context, maxWidth: maxBubbleWidth),
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

    if (soundPath != null || soundUrl != null) {
      return _VoiceMessageBubble(
        path: soundPath,
        url: soundUrl,
        duration: soundDuration ?? 0,
        mine: mine,
      );
    }

    if (isVoiceCallRecord) {
      return _VoiceCallRecordBubble(text: text, mine: mine);
    }

    return _Bubble(
      palette: palette,
      text: text,
      mine: mine,
      onTextSelected: (selectedText) => _copyText(context, selectedText),
    );
  }

  Widget _copyableMessageBody(
    BuildContext context, {
    required double maxWidth,
  }) {
    final body = _messageBody(context, maxWidth: maxWidth);
    if (text.isEmpty) return body;
    return Semantics(button: true, hint: '长按选择并复制消息', child: body);
  }

  Future<void> _copyText(BuildContext context, String selectedText) async {
    await Clipboard.setData(ClipboardData(text: selectedText));
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        right: 0,
        bottom: 96,
        child: IgnorePointer(
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE6000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Text(
                  '已复制',
                  style: TextStyle(color: _white, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(const Duration(milliseconds: 1400), entry.remove);
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

class _VoiceCallRecordBubble extends StatelessWidget {
  const _VoiceCallRecordBubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final foreground = mine ? _black : _white;
    final background = mine ? const Color(0xFF28B561) : const Color(0xFF2C2C2C);
    return CustomPaint(
      painter: mine
          ? _MineBubblePainter(color: background)
          : _OtherBubblePainter(color: background),
      child: Padding(
        padding: EdgeInsets.fromLTRB(mine ? 12 : 18, 8, mine ? 18 : 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 18,
              child: Image.asset(
                'assets/icons/chat_voice_call_record.png',
                fit: BoxFit.contain,
                color: foreground,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: foreground, fontSize: 16)),
          ],
        ),
      ),
    );
  }
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

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.path,
    required this.url,
    required this.duration,
    required this.mine,
  });

  final String? path;
  final String? url;
  final int duration;
  final bool mine;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  final _player = AudioPlayer();
  StreamSubscription<void>? _completeSubscription;
  Timer? _playbackAnimationTimer;
  bool _playing = false;
  int _playbackAnimationFrame = 0;

  @override
  void initState() {
    super.initState();
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _stopPlaybackAnimation();
      if (mounted) {
        setState(() {
          _playing = false;
          _playbackAnimationFrame = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _stopPlaybackAnimation();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        _stopPlaybackAnimation();
        if (mounted) {
          setState(() {
            _playing = false;
            _playbackAnimationFrame = 0;
          });
        }
        return;
      }
      final source = await _source();
      if (source == null) return;
      await _player.play(source);
      _stopPlaybackAnimation();
      _playbackAnimationTimer = Timer.periodic(
        const Duration(milliseconds: 280),
        (_) {
          if (!mounted || !_playing) return;
          setState(
            () => _playbackAnimationFrame = (_playbackAnimationFrame + 1) % 3,
          );
        },
      );
      if (mounted) {
        setState(() {
          _playing = true;
          _playbackAnimationFrame = 0;
        });
      }
    } catch (error) {
      debugPrint('[OpenIM] voice playback failed: $error');
    }
  }

  void _stopPlaybackAnimation() {
    _playbackAnimationTimer?.cancel();
    _playbackAnimationTimer = null;
  }

  Future<Source?> _source() async {
    final path = widget.path;
    if (path?.isNotEmpty == true) {
      final exists = await File(path!).exists();
      if (exists) return DeviceFileSource(path);
    }

    final url = widget.url;
    if (url != null && url.isNotEmpty) {
      return UrlSource(_playbackUrl(url), mimeType: 'audio/mp4');
    }
    return null;
  }

  String _playbackUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'http' || uri.host != 'im.aco.chat') {
      return url;
    }
    return uri.replace(scheme: 'https').toString();
  }

  Widget _voiceIcon(Color foreground) {
    final frame = _playing ? _playbackAnimationFrame : 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icons/chat_voice_play_0.png',
          width: 5,
          height: 7,
          fit: BoxFit.contain,
          color: foreground,
          colorBlendMode: BlendMode.srcIn,
        ),
        if (frame >= 1)
          Transform.translate(
            offset: const Offset(-1, 0),
            child: Image.asset(
              'assets/icons/chat_voice_play_1.png',
              height: 13,
              fit: BoxFit.contain,
              color: foreground,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
        if (frame >= 2)
          Transform.translate(
            offset: const Offset(-2, 0),
            child: Image.asset(
              'assets/icons/chat_voice_play_2.png',
              height: 17,
              fit: BoxFit.contain,
              color: foreground,
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.mine ? _black : _white;
    final background = widget.mine
        ? const Color(0xFF28B561)
        : const Color(0xFF2C2C2C);
    return Semantics(
      button: true,
      label: '播放语音消息，${widget.duration}秒',
      child: GestureDetector(
        onTap: _toggle,
        child: CustomPaint(
          painter: widget.mine
              ? _MineBubblePainter(color: background)
              : _OtherBubblePainter(color: background),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.mine ? 12 : 18,
              8,
              widget.mine ? 18 : 12,
              8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.mine) ...[
                  Text(
                    '${widget.duration}"',
                    style: TextStyle(color: foreground, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                ],
                Transform.flip(
                  flipX: widget.mine,
                  child: SizedBox(
                    width: 20,
                    height: 18,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _voiceIcon(foreground),
                    ),
                  ),
                ),
                if (!widget.mine) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${widget.duration}"',
                    style: TextStyle(color: foreground, fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMention {
  const _GroupMention({required this.userID, required this.name});

  final String userID;
  final String name;

  String get token => '@$name ';
}

class _GroupMentionPanel extends StatelessWidget {
  const _GroupMentionPanel({
    required this.members,
    required this.loading,
    required this.onSelected,
  });

  final List<GroupMembersInfo> members;
  final bool loading;
  final ValueChanged<GroupMembersInfo> onSelected;

  String _memberName(GroupMembersInfo member) {
    final name = member.nickname?.trim() ?? '';
    return name.isEmpty ? (member.userID ?? '成员') : name;
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 208,
    decoration: const BoxDecoration(
      color: Color(0xFF252525),
      border: Border(top: BorderSide(color: Color(0xFF3A3A3A))),
    ),
    child: loading
        ? const Center(child: CupertinoActivityIndicator())
        : members.isEmpty
        ? const Center(
            child: Text('未找到群成员', style: TextStyle(color: Color(0xFFAAAAAA))),
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: members.length,
            separatorBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(left: 58),
              child: ColoredBox(
                color: Color(0xFF343434),
                child: SizedBox(height: 1),
              ),
            ),
            itemBuilder: (_, index) {
              final member = members[index];
              return CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onPressed: () => onSelected(member),
                child: Row(
                  children: [
                    AcoAvatar(size: 36, imageUrl: member.faceURL ?? ''),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _memberName(member),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            },
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
