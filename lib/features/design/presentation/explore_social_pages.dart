part of 'aco_design_shell.dart';

class _SocialMessagesPage extends StatefulWidget {
  const _SocialMessagesPage({
    required this.palette,
    required this.onOpen,
    this.avatarUrl,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? avatarUrl;

  @override
  State<_SocialMessagesPage> createState() => _SocialMessagesPageState();
}

class _SocialMessagesPageState extends State<_SocialMessagesPage> {
  final _searchController = TextEditingController();
  var _query = '';
  var _showContacts = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: RefreshIndicator(
      onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 650)),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              extent: 46 * .672 + 8 + 61,
              backgroundColor: widget.palette.background,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35),
                    child: AcoRootHeader(
                      palette: widget.palette,
                      onOpen: widget.onOpen,
                      scale: .672,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ValueListenableBuilder<bool>(
                    valueListenable: OpenIMChatRepository.messageUnreadNotifier,
                    builder: (_, hasUnreadMessages, _) =>
                        ValueListenableBuilder<int>(
                          valueListenable:
                              OpenIMChatRepository.friendRequestCountNotifier,
                          builder: (_, friendRequestCount, _) =>
                              _MessageQuickActions(
                                controller: _searchController,
                                hasUnreadMessages: hasUnreadMessages,
                                hasFriendRequest: friendRequestCount > 0,
                                palette: widget.palette,
                                showContacts: _showContacts,
                                onQueryChanged: (query) =>
                                    setState(() => _query = query),
                                onMessagesTap: () =>
                                    setState(() => _showContacts = false),
                                onContactsTap: () =>
                                    setState(() => _showContacts = true),
                              ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              if (_showContacts)
                _ContactsPage(
                  palette: widget.palette,
                  onOpen: widget.onOpen,
                  embedded: true,
                )
              else
                _OpenIMConversationList(
                  palette: widget.palette,
                  onOpen: widget.onOpen,
                  query: _query,
                ),
            ]),
          ),
        ],
      ),
    ),
  );
}

Future<List<FriendContact>> _fetchFriendRequests() async {
  final client = AccountApiClient();
  try {
    return await AccountSession(client).listFriendRequests();
  } finally {
    client.close();
  }
}

class _FriendRequestsPage extends StatefulWidget {
  const _FriendRequestsPage({required this.palette});

  final AcoPalette palette;

  @override
  State<_FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<_FriendRequestsPage> {
  late Future<List<FriendContact>> _requests;

  @override
  void initState() {
    super.initState();
    OpenIMChatRepository.setFriendRequestCount(0);
    _requests = _load();
  }

  Future<List<FriendContact>> _load() async {
    return _fetchFriendRequests();
  }

  Future<void> _respond(FriendContact request, bool accept) async {
    final client = AccountApiClient();
    try {
      final session = AccountSession(client);
      if (accept) {
        await session.acceptFriend(request.accountId);
        // Notify the requester in the newly established conversation.
        try {
          final message = await OpenIM.iMManager.messageManager
              .createTextMessage(text: '我通过了你的好友请求');
          await OpenIM.iMManager.messageManager.sendMessage(
            message: message,
            userID: request.accountId,
            offlinePushInfo: OfflinePushInfo(title: '好友申请', desc: '我通过了你的好友请求'),
          );
        } catch (error) {
          // Acceptance is already persisted; a transient IM send failure
          // should not make the request appear unprocessed.
          debugPrint('[OpenIM] accept friend sync failed: $error');
        }
        OpenIMChatRepository.conversationRevision.value++;
      } else {
        await session.refuseFriend(request.accountId);
      }
      if (mounted) {
        final refreshed = await _load();
        final visible = refreshed
            .where((item) => item.accountId != request.accountId)
            .toList(growable: false);
        setState(() {
          _requests = Future.value(visible);
        });
      }
      OpenIMChatRepository.setFriendRequestCount(0);
    } catch (error) {
      if (!mounted) return;
      final message = error is AccountApiException
          ? error.localizedMessage
          : '请检查网络后重试。';
      _showNotice(context, accept ? '通过失败' : '拒绝失败', message);
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AcoPageHeader(
              palette: widget.palette,
              title: '好友请求',
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FriendContact>>(
              future: _requests,
              builder: (context, snapshot) {
                final requests = snapshot.data ?? const <FriendContact>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (requests.isEmpty) {
                  return const _ContactsStateMessage(message: '暂无好友请求');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: requests.length,
                  itemBuilder: (_, index) {
                    final request = requests[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ContactListTile(
                        palette: widget.palette,
                        name:
                            '${request.nickname.isEmpty ? request.accountId : request.nickname} 请求添加你为好友',
                        avatarUrl: request.avatarUrl,
                        onTap: () => _respond(request, true),
                        backgroundColor: const Color(0xFF151515),
                        borderRadius: BorderRadius.circular(10),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        nameMaxLines: 2,
                        avatarSize: 30,
                        avatarGap: 8,
                        nameFontSize: 14,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _respond(request, false),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF292929),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: widget.palette.mutedText,
                                  size: 15,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _respond(request, true),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: widget.palette.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.check_mark,
                                  color: Color(0xFF000000),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _ContactsPage extends StatefulWidget {
  const _ContactsPage({
    required this.palette,
    required this.onOpen,
    this.embedded = false,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final bool embedded;

  @override
  State<_ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<_ContactsPage> {
  late Future<List<FriendContact>> _friends;
  final _sectionKeys = <String, GlobalKey>{};
  OverlayEntry? _alphabetOverlay;

  @override
  void initState() {
    super.initState();
    _friends = _loadFriends();
  }

  Future<List<FriendContact>> _loadFriends() async {
    final client = AccountApiClient();
    try {
      return await AccountSession(
        client,
      ).listFriends().timeout(const Duration(seconds: 8));
    } finally {
      client.close();
    }
  }

  Future<void> _refresh() async {
    final future = _loadFriends();
    setState(() => _friends = future);
    await future;
  }

  String _initialOf(FriendContact friend) {
    final name = _displayNameOf(friend).trim();
    if (name.isEmpty) return '#';
    final initial = name[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(initial) ? initial : '#';
  }

  String _displayNameOf(FriendContact friend) =>
      friend.nickname.isEmpty ? friend.accountId : friend.nickname;

  void _scrollToSection(String letter) {
    final context = _sectionKeys[letter]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _alphabetOverlay?.remove();
    super.dispose();
  }

  void _updateAlphabetOverlay(BuildContext context, List<String> letters) {
    if (!widget.embedded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _alphabetOverlay?.remove();
      _alphabetOverlay = null;
      if (letters.isEmpty) return;
      final overlay = Overlay.of(context, rootOverlay: true);
      _alphabetOverlay = OverlayEntry(
        builder: (_) => Positioned(
          right: 8,
          top: MediaQuery.sizeOf(context).height * .30,
          bottom: 48,
          child: _ContactsAlphabetIndex(
            letters: letters,
            onLetterTap: _scrollToSection,
          ),
        ),
      );
      overlay.insert(_alphabetOverlay!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<FriendContact>>(
      future: _friends,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('[OpenIM] contacts load failed: ${snapshot.error}');
          return _ContactsStateMessage(
            message: '通讯录加载失败，点击重试',
            onRetry: () => setState(() {
              _friends = _loadFriends();
            }),
          );
        }
        final friends = snapshot.data ?? const <FriendContact>[];
        final groupedFriends = <String, List<FriendContact>>{};
        for (final friend in friends) {
          groupedFriends.putIfAbsent(_initialOf(friend), () => []).add(friend);
        }
        final letters = groupedFriends.keys.toList()..sort();
        _updateAlphabetOverlay(context, letters);
        _sectionKeys
          ..clear()
          ..addEntries(letters.map((letter) => MapEntry(letter, GlobalKey())));
        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height,
          ),
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  shrinkWrap: widget.embedded,
                  physics: widget.embedded
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),
                    ValueListenableBuilder<int>(
                      valueListenable:
                          OpenIMChatRepository.friendRequestCountNotifier,
                      builder: (_, friendRequestCount, _) =>
                          _ContactsQuickAction(
                            palette: widget.palette,
                            label: '新的朋友',
                            icon: CupertinoIcons.person_add_solid,
                            assetPath: 'assets/icons/contact_new_friend.png',
                            color: const Color(0xFFFF9E38),
                            dividerLeftPadding: 18 + 40 + 16,
                            requestCount: friendRequestCount,
                            onTap: () {
                              OpenIMChatRepository.setFriendRequestCount(0);
                              Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => _FriendRequestsPage(
                                    palette: widget.palette,
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                    _ContactsQuickAction(
                      palette: widget.palette,
                      label: '群聊',
                      icon: CupertinoIcons.person_2_fill,
                      assetPath: 'assets/icons/contact_group_chat.png',
                      color: const Color(0xFF00C976),
                      onTap: () => _showNotice(context, '群聊', '群聊功能暂未开放。'),
                    ),
                    const SizedBox(height: 12),
                    if (friends.isEmpty)
                      const _ContactsStateMessage(message: '暂无好友')
                    else
                      for (final letter in letters) ...[
                        Padding(
                          key: _sectionKeys[letter],
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _ContactsSectionLabel(label: letter),
                        ),
                        const SizedBox(height: 4),
                        for (final friend in groupedFriends[letter]!)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: _ContactListTile(
                              palette: widget.palette,
                              name: _displayNameOf(friend),
                              avatarUrl: friend.avatarUrl,
                              identity: friend.identity,
                              onTap: () => _openFriend(context, friend),
                              avatarSize: 40,
                              avatarGap: 16,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              nameFontSize: 15,
                            ),
                          ),
                      ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (!widget.embedded && letters.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 80,
                  bottom: 0,
                  child: _ContactsAlphabetIndex(
                    letters: letters,
                    onLetterTap: _scrollToSection,
                  ),
                ),
            ],
          ),
        );
      },
    );
    if (widget.embedded) return content;
    return CupertinoPageScaffold(
      backgroundColor: widget.palette.background,
      child: SafeArea(bottom: false, child: content),
    );
  }

  Future<void> _openFriend(BuildContext context, FriendContact friend) async {
    final name = _displayNameOf(friend);
    // The index is in the root overlay, outside this route's Navigator.
    // Remove it while a contact detail page is visible.
    _alphabetOverlay?.remove();
    _alphabetOverlay = null;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _ContactDetailPage(
          palette: widget.palette,
          name: name,
          onMessagePressed: () {
            OpenIMChatRepository.pendingConversation = ConversationInfo(
              conversationID: 'si_${friend.accountId}',
              userID: friend.accountId,
              showName: name,
            );
            final navigator = Navigator.of(context);
            navigator.pop();
            if (!widget.embedded) navigator.pop();
            widget.onOpen(AcoScreen.chatV1);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _ContactsQuickAction extends StatelessWidget {
  const _ContactsQuickAction({
    required this.palette,
    required this.label,
    required this.icon,
    this.assetPath,
    required this.color,
    this.dividerLeftPadding = 0,
    this.requestCount = 0,
    required this.onTap,
  });
  final AcoPalette palette;
  final String label;
  final IconData icon;
  final String? assetPath;
  final Color color;
  final double dividerLeftPadding;
  final int requestCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: SizedBox(
      height: 60,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: assetPath == null
                        ? Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              color: const Color(0xFFFFFFFF),
                              size: 21,
                            ),
                          )
                        : Image.asset(assetPath!, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (requestCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: _danger,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        '$requestCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: dividerLeftPadding),
            child: const SizedBox(
              width: double.infinity,
              height: 1,
              child: ColoredBox(color: Color(0xFF191919)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContactsSectionLabel extends StatelessWidget {
  const _ContactsSectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFFD5D5D5),
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _ContactsAlphabetIndex extends StatelessWidget {
  const _ContactsAlphabetIndex({
    required this.letters,
    required this.onLetterTap,
  });

  final List<String> letters;
  final ValueChanged<String> onLetterTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fittedFontSize = constraints.maxHeight / letters.length;
      final fontSize = fittedFontSize < 16 ? fittedFontSize : 16.0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final letter in letters)
            GestureDetector(
              onTap: () => onLetterTap(letter),
              behavior: HitTestBehavior.opaque,
              child: Text(
                letter,
                style: TextStyle(
                  color: const Color(0xFF858585),
                  fontSize: fontSize,
                  height: 1,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _ContactsStateMessage extends StatelessWidget {
  const _ContactsStateMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: CupertinoButton(onPressed: onRetry, child: Text(message)),
  );
}

class _OpenIMConversationList extends StatefulWidget {
  const _OpenIMConversationList({
    required this.palette,
    required this.onOpen,
    this.query = '',
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String query;

  @override
  State<_OpenIMConversationList> createState() =>
      _OpenIMConversationListState();
}

class _OpenIMConversationListState extends State<_OpenIMConversationList> {
  static List<ConversationInfo> _cachedConversations = const [];
  late Future<List<ConversationInfo>> _conversations;
  Timer? _reloadTimer;
  Map<String, int> _identityByUserID = const {};

  String _latestMessagePreview(Message? message) {
    final text = message?.textElem?.content;
    if (text?.isNotEmpty == true) return text!;
    if (message?.soundElem != null) return '[语音消息]';
    if (message?.pictureElem != null) return '[图片]';
    return '';
  }

  @override
  void initState() {
    super.initState();
    _conversations = _load();
    OpenIMChatRepository.conversationRevision.addListener(_reload);
    OpenIMChatRepository.conversationReady.addListener(_reload);
    OpenIMChatRepository.messageNotifier.addListener(_updateLatestMessage);
  }

  void _updateLatestMessage() {
    final message = OpenIMChatRepository.messageNotifier.value;
    if (!mounted || message == null) return;
    final peerID = message.sendID == OpenIMChatRepository.currentUserID
        ? message.recvID
        : message.sendID;
    if (peerID == null) return;
    ConversationInfo? conversation;
    for (final item in _cachedConversations) {
      if (item.userID == peerID) {
        conversation = item;
        break;
      }
    }
    if (conversation == null) return;
    conversation.latestMsg = message;
    conversation.latestMsgSendTime = message.sendTime ?? message.createTime;
    setState(() {});
  }

  Future<List<ConversationInfo>> _load() async {
    if (!OpenIMChatRepository.conversationReady.value) {
      return _cachedConversations;
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final openIMConversations = await OpenIM.iMManager.conversationManager
            .getAllConversationList()
            .timeout(const Duration(seconds: 3));
        // Aco owns friend relationships and profile data. OpenIM only supplies
        // message transport metadata, so fail closed when Aco cannot review
        // the list instead of exposing its complete conversation history.
        final client = AccountApiClient();
        try {
          final friends = await AccountSession(
            client,
          ).listFriends().timeout(const Duration(seconds: 5));
          final profiles = {
            for (final friend in friends) friend.accountId: friend,
          };
          final conversations = openIMConversations
              .where(
                (conversation) => profiles.containsKey(conversation.userID),
              )
              .toList(growable: false);
          _identityByUserID = {
            for (final friend in friends)
              if (friend.identity > 0) friend.accountId: friend.identity,
          };
          for (final conversation in conversations) {
            final friend = profiles[conversation.userID]!;
            if (friend.nickname.isNotEmpty) {
              conversation.showName = friend.nickname;
            }
            if (friend.avatarUrl.isNotEmpty) {
              conversation.faceURL = friend.avatarUrl;
            }
          }
          _cachedConversations = List<ConversationInfo>.unmodifiable(
            conversations,
          );
          return _cachedConversations;
        } catch (error) {
          debugPrint('[API] conversation authorization failed: $error');
          _identityByUserID = const {};
          return const <ConversationInfo>[];
        } finally {
          client.close();
        }
      } catch (error) {
        final isResourceNotReady =
            error.toString().contains('10004') ||
            error.toString().contains('Resource initialization incomplete');
        if (!isResourceNotReady || attempt == 2) {
          if (isResourceNotReady) return const <ConversationInfo>[];
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return const <ConversationInfo>[];
  }

  void _reload() {
    if (!mounted) return;
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _conversations = _load();
      });
    });
  }

  @override
  void dispose() {
    OpenIMChatRepository.conversationRevision.removeListener(_reload);
    OpenIMChatRepository.conversationReady.removeListener(_reload);
    OpenIMChatRepository.messageNotifier.removeListener(_updateLatestMessage);
    _reloadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationInfo>>(
      future: _conversations,
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? _cachedConversations;
        if (snapshot.connectionState == ConnectionState.waiting &&
            conversations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        if (conversations.isEmpty &&
            !OpenIMChatRepository.conversationReady.value) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        if (conversations.isEmpty &&
            snapshot.connectionState == ConnectionState.done &&
            OpenIMChatRepository.conversationReady.value) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('暂无会话')),
          );
        }
        final query = widget.query.trim().toLowerCase();
        final filteredConversations = query.isEmpty
            ? conversations
            : conversations.where((conversation) {
                final name = conversation.showName ?? conversation.userID ?? '';
                return name.toLowerCase().contains(query) ||
                    _latestMessagePreview(
                      conversation.latestMsg,
                    ).toLowerCase().contains(query);
              }).toList();
        if (filteredConversations.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '未找到相关会话',
                style: TextStyle(
                  color: widget.palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final entry in filteredConversations.asMap().entries) ...[
              _SocialMessageTile(
                palette: widget.palette,
                name: entry.value.showName ?? entry.value.userID ?? '会话',
                message: _latestMessagePreview(entry.value.latestMsg),
                avatarUrl: entry.value.faceURL,
                identity: _identityByUserID[entry.value.userID] ?? 0,
                horizontalMargin: 16,
                unreadCount: entry.value.unreadCount,
                timestamp: entry.value.latestMsgSendTime,
                onTap: () {
                  final conversation = entry.value;
                  conversation.unreadCount = 0;
                  OpenIMChatRepository.pendingConversation = conversation;
                  OpenIMChatRepository.conversationRevision.value++;
                  unawaited(
                    OpenIM.iMManager.conversationManager
                        .markConversationMessageAsRead(
                          conversationID: conversation.conversationID,
                        )
                        .catchError((error) {
                          debugPrint('[OpenIM] mark read failed: $error');
                        }),
                  );
                  widget.onOpen(AcoScreen.chatV1);
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
