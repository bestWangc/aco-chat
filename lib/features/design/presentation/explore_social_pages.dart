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
  Widget build(BuildContext context) {
    final content = _showContacts
        ? Column(
            children: [
              _header(),
              Expanded(
                child: _ContactsPage(
                  palette: widget.palette,
                  onOpen: widget.onOpen,
                  embedded: true,
                ),
              ),
            ],
          )
        : RefreshIndicator(
            onRefresh: () =>
                Future<void>.delayed(const Duration(milliseconds: 650)),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeaderDelegate(
                    extent: 46 * .672 + 8 + 61,
                    backgroundColor: widget.palette.background,
                    child: _header(),
                  ),
                ),
                _OpenIMConversationList(
                  palette: widget.palette,
                  onOpen: widget.onOpen,
                ),
              ],
            ),
          );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          content,
          if (_query.trim().isNotEmpty) _searchOverlay(context),
        ],
      ),
    );
  }

  Widget _searchOverlay(BuildContext context) => Positioned(
    top: 100,
    left: 12,
    right: 12,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .56,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFF1B1B1B),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF303030)),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: _SocialGlobalSearchResults(
            palette: widget.palette,
            onOpen: widget.onOpen,
            query: _query,
          ),
        ),
      ),
    ),
  );

  Widget _header() => Column(
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
        builder: (_, hasUnreadMessages, _) => ValueListenableBuilder<int>(
          valueListenable: OpenIMChatRepository.friendRequestCountNotifier,
          builder: (_, friendRequestCount, _) => _MessageQuickActions(
            controller: _searchController,
            hasUnreadMessages: hasUnreadMessages,
            hasFriendRequest: friendRequestCount > 0,
            palette: widget.palette,
            showContacts: _showContacts,
            onQueryChanged: (query) => setState(() => _query = query),
            onMessagesTap: () => setState(() => _showContacts = false),
            onContactsTap: () => setState(() => _showContacts = true),
          ),
        ),
      ),
    ],
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

class _SocialGlobalSearchResults extends StatefulWidget {
  const _SocialGlobalSearchResults({
    required this.palette,
    required this.onOpen,
    required this.query,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String query;

  @override
  State<_SocialGlobalSearchResults> createState() =>
      _SocialGlobalSearchResultsState();
}

class _SocialGlobalSearchResultsState
    extends State<_SocialGlobalSearchResults> {
  late final Future<_SocialSearchScope> _scope;
  Timer? _searchTimer;
  var _searchVersion = 0;
  var _loading = true;
  List<FriendContact> _friendResults = const [];
  List<_SocialMessageSearchResult> _messageResults = const [];

  @override
  void initState() {
    super.initState();
    _scope = _loadScope();
    _scheduleSearch();
  }

  @override
  void didUpdateWidget(covariant _SocialGlobalSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _scheduleSearch();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<_SocialSearchScope> _loadScope() async {
    final client = AccountApiClient();
    try {
      final session = AccountSession(client);
      final results = await Future.wait([
        session.listFriends(),
        session.listGroups(),
        OpenIM.iMManager.conversationManager.getAllConversationList(),
      ]);
      final friends = results[0] as List<FriendContact>;
      final groups = results[1] as List<ChatGroup>;
      final conversations = results[2] as List<ConversationInfo>;
      final friendIDs = friends.map((friend) => friend.accountId).toSet();
      final groupIDs = groups.map((group) => group.groupId).toSet();
      final allowedConversations = {
        for (final conversation in conversations)
          if (friendIDs.contains(conversation.userID) ||
              (conversation.isGroupChat &&
                  groupIDs.contains(conversation.groupID)))
            conversation.conversationID: conversation,
      };
      return _SocialSearchScope(
        friends: friends,
        conversationsByID: allowedConversations,
      );
    } finally {
      client.close();
    }
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    final keyword = widget.query.trim();
    final version = ++_searchVersion;
    setState(() => _loading = true);
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_search(keyword, version));
    });
  }

  Future<void> _search(String keyword, int version) async {
    try {
      final scope = await _scope;
      final result = await OpenIM.iMManager.messageManager
          .searchLocalMessages(keywordList: [keyword], count: 100)
          .timeout(const Duration(seconds: 5));
      final normalizedKeyword = keyword.toLowerCase();
      final friends = scope.friends
          .where((friend) => _matchesFriend(friend, normalizedKeyword))
          .toList(growable: false);
      final messages = _messageMatches(result, scope.conversationsByID);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _friendResults = friends;
        _messageResults = messages;
        _loading = false;
      });
    } catch (error) {
      debugPrint('[OpenIM] global social search failed: $error');
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _friendResults = const [];
        _messageResults = const [];
        _loading = false;
      });
    }
  }

  static bool _matchesFriend(FriendContact friend, String keyword) {
    return friend.nickname.toLowerCase().contains(keyword) ||
        friend.accountId.toLowerCase().contains(keyword);
  }

  static List<_SocialMessageSearchResult> _messageMatches(
    SearchResult result,
    Map<String, ConversationInfo> conversationsByID,
  ) {
    final matches = <_SocialMessageSearchResult>[];
    final items =
        result.searchResultItems ?? result.findResultItems ?? const [];
    for (final item in items) {
      final conversation = conversationsByID[item.conversationID];
      final messages = item.messageList;
      if (conversation == null || messages == null || messages.isEmpty) {
        continue;
      }
      matches.add(
        _SocialMessageSearchResult(
          conversation: conversation,
          message: messages.reduce(_newerMessage),
        ),
      );
    }
    matches.sort(
      (first, second) =>
          _messageTime(second.message).compareTo(_messageTime(first.message)),
    );
    return matches;
  }

  static Message _newerMessage(Message first, Message second) =>
      _messageTime(first) >= _messageTime(second) ? first : second;

  static int _messageTime(Message message) =>
      message.sendTime ?? message.createTime ?? 0;

  void _openConversation(_SocialMessageSearchResult result) {
    final conversation = result.conversation;
    conversation.unreadCount = 0;
    OpenIMChatRepository.pendingConversation = conversation;
    OpenIMChatRepository.pendingSearchMessage = result.message;
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
  }

  void _openFriend(FriendContact friend) {
    OpenIMChatRepository.pendingSearchMessage = null;
    OpenIMChatRepository.pendingConversation = ConversationInfo(
      conversationID: 'si_${friend.accountId}',
      userID: friend.accountId,
      showName: friend.nickname.isEmpty ? friend.accountId : friend.nickname,
      faceURL: friend.avatarUrl,
    );
    widget.onOpen(AcoScreen.chatV1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 84,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_friendResults.isEmpty && _messageResults.isEmpty) {
      return SizedBox(
        height: 84,
        child: _SearchHint(palette: widget.palette, label: '没有找到相关联系人或聊天记录'),
      );
    }
    return ListView(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        if (_friendResults.isNotEmpty) ...[
          const _ContactsSectionLabel(label: '联系人'),
          const SizedBox(height: 4),
          for (final friend in _friendResults)
            _ContactListTile(
              palette: widget.palette,
              name: friend.nickname.isEmpty
                  ? friend.accountId
                  : friend.nickname,
              avatarUrl: friend.avatarUrl,
              identity: friend.identity,
              onTap: () => _openFriend(friend),
              avatarSize: 40,
              avatarGap: 16,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              nameFontSize: 15,
            ),
        ],
        if (_friendResults.isNotEmpty && _messageResults.isNotEmpty)
          const SizedBox(height: 16),
        if (_messageResults.isNotEmpty) ...[
          const _ContactsSectionLabel(label: '聊天记录'),
          const SizedBox(height: 4),
          for (final result in _messageResults)
            _SocialMessageTile(
              palette: widget.palette,
              name:
                  result.conversation.showName ??
                  result.conversation.userID ??
                  '会话',
              message:
                  OpenIMChatRepository.messageText(result.message) ?? '[消息]',
              avatarUrl: result.conversation.faceURL,
              timestamp: _messageTime(result.message),
              onTap: () => _openConversation(result),
            ),
        ],
      ],
    );
  }
}

class _SocialSearchScope {
  const _SocialSearchScope({
    required this.friends,
    required this.conversationsByID,
  });

  final List<FriendContact> friends;
  final Map<String, ConversationInfo> conversationsByID;
}

class _SocialMessageSearchResult {
  const _SocialMessageSearchResult({
    required this.conversation,
    required this.message,
  });

  final ConversationInfo conversation;
  final Message message;
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
  static final _alphabetInitial = RegExp(r'^[A-Z]$');
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
    final initial = friend.initial.toUpperCase();
    return _alphabetInitial.hasMatch(initial) ? initial : '#';
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
          debugPrint('[Aco] contacts load failed: ${snapshot.error}');
          return _ContactsStateMessage(
            message: '通讯录加载失败，点击重试',
            onRetry: () => setState(() => _friends = _loadFriends()),
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
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable:
                        OpenIMChatRepository.friendRequestCountNotifier,
                    builder: (_, friendRequestCount, _) => _ContactsQuickAction(
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
                            builder: (_) =>
                                _FriendRequestsPage(palette: widget.palette),
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
                    onTap: () async {
                      // The index is inserted in the root overlay, so it
                      // would otherwise remain above the group-creation page.
                      _alphabetOverlay?.remove();
                      _alphabetOverlay = null;
                      final group = await Navigator.of(context).push<ChatGroup>(
                        CupertinoPageRoute<ChatGroup>(
                          builder: (_) =>
                              _CreateGroupPage(palette: widget.palette),
                        ),
                      );
                      if (!mounted) return;
                      if (group == null) {
                        setState(() {});
                        return;
                      }
                      OpenIMChatRepository.pendingConversation =
                          ConversationInfo(
                            conversationID: 'sg_${group.groupId}',
                            groupID: group.groupId,
                            showName: group.name,
                          );
                      widget.onOpen(AcoScreen.chatV1);
                    },
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

class _CreateGroupPage extends StatefulWidget {
  const _CreateGroupPage({required this.palette});

  final AcoPalette palette;

  @override
  State<_CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<_CreateGroupPage> {
  final _nameController = TextEditingController();
  final _session = AccountSession(AccountApiClient());
  final _selected = <String>{};
  late final Future<List<FriendContact>> _friends = _session.listFriends();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showNotice(context, '请输入群名称', '群名称长度为 1–64 个字符。');
      return;
    }
    if (_selected.isEmpty) {
      _showNotice(context, '请选择成员', '至少邀请一位好友创建群聊。');
      return;
    }
    setState(() => _submitting = true);
    try {
      final group = await _session.createGroup(
        name: name,
        memberAccountIds: _selected.toList(growable: false),
      );
      if (mounted && group.inviteCode != null) {
        await Navigator.of(context).push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => _GroupQRCodePage(
              palette: widget.palette,
              groupName: group.name,
              inviteCode: group.inviteCode!,
            ),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(group);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '创建群聊失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '创建群聊失败', '请稍后重试。');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    navigationBar: CupertinoNavigationBar(
      middle: const Text('创建群聊'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _submitting ? null : _create,
        child: Text(_submitting ? '创建中' : '创建'),
      ),
    ),
    child: SafeArea(
      child: FutureBuilder<List<FriendContact>>(
        future: _friends,
        builder: (_, snapshot) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            CupertinoTextField(
              controller: _nameController,
              placeholder: '群名称',
              maxLength: 64,
              style: TextStyle(color: widget.palette.primaryText),
              decoration: BoxDecoration(
                color: widget.palette.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '选择好友（最多 499 人）',
              style: TextStyle(color: widget.palette.mutedText),
            ),
            const SizedBox(height: 8),
            for (final friend in snapshot.data ?? const <FriendContact>[])
              CupertinoListTile(
                padding: EdgeInsets.zero,
                title: Text(
                  friend.nickname.isEmpty ? friend.accountId : friend.nickname,
                  style: TextStyle(color: widget.palette.primaryText),
                ),
                trailing: CupertinoCheckbox(
                  value: _selected.contains(friend.accountId),
                  onChanged: (selected) => setState(() {
                    if (selected == true && _selected.length < 499) {
                      _selected.add(friend.accountId);
                    } else {
                      _selected.remove(friend.accountId);
                    }
                  }),
                ),
              ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CupertinoActivityIndicator()),
          ],
        ),
      ),
    ),
  );
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
  const _OpenIMConversationList({required this.palette, required this.onOpen});

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_OpenIMConversationList> createState() =>
      _OpenIMConversationListState();
}

class _OpenIMConversationListState extends State<_OpenIMConversationList> {
  static List<ConversationInfo> _cachedConversations = const [];
  static final Map<String, _GroupAvatarCache> _groupAvatarCache = {};
  static const _groupAvatarCacheTTL = Duration(hours: 24);
  late Future<List<ConversationInfo>> _conversations;
  Timer? _reloadTimer;
  Map<String, int> _identityByUserID = const {};
  Map<String, List<String>> _groupAvatarUrls = const {};

  String _latestMessagePreview(Message? message) {
    final text = OpenIMChatRepository.messageText(message);
    if (text != null) return text;
    if (message?.soundElem != null) return '[语音消息]';
    if (message?.pictureElem != null) return '[图片]';
    if (OpenIMChatRepository.isVoiceCallMessage(message)) {
      return '[语音通话]';
    }
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
    final groupID = message.groupID;
    if (groupID?.isNotEmpty == true) {
      for (final item in _cachedConversations) {
        if (item.groupID == groupID) {
          item.latestMsg = message;
          item.latestMsgSendTime = message.sendTime ?? message.createTime;
          setState(() {});
          return;
        }
      }
      return;
    }
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
          final session = AccountSession(client);
          final results = await Future.wait([
            session.listFriends().timeout(const Duration(seconds: 5)),
            session.listGroups().timeout(const Duration(seconds: 5)),
          ]);
          final friends = results[0] as List<FriendContact>;
          final groups = results[1] as List<ChatGroup>;
          final profiles = {
            for (final friend in friends) friend.accountId: friend,
          };
          final groupsByID = {for (final group in groups) group.groupId: group};
          final conversations = openIMConversations
              .where(
                (conversation) =>
                    profiles.containsKey(conversation.userID) ||
                    (conversation.isGroupChat &&
                        groupsByID.containsKey(conversation.groupID)),
              )
              .toList(growable: false);
          for (final conversation in conversations) {
            conversation.unreadCount = OpenIMChatRepository.visibleUnreadCount(
              conversation,
            );
          }
          OpenIMChatRepository.updateAuthorizedConversations(conversations);
          _identityByUserID = {
            for (final friend in friends)
              if (friend.identity > 0) friend.accountId: friend.identity,
          };
          for (final conversation in conversations) {
            final friend = profiles[conversation.userID];
            if (friend != null) {
              if (friend.nickname.isNotEmpty) {
                conversation.showName = friend.nickname;
              }
              if (friend.avatarUrl.isNotEmpty) {
                conversation.faceURL = friend.avatarUrl;
              }
              continue;
            }
            final group = groupsByID[conversation.groupID];
            if (group == null) continue;
            if (group.name.isNotEmpty) conversation.showName = group.name;
            if (group.faceUrl.isNotEmpty) conversation.faceURL = group.faceUrl;
          }
          _groupAvatarUrls = await _loadGroupAvatarUrls(conversations);
          conversations.sort(_compareConversations);
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

  Future<Map<String, List<String>>> _loadGroupAvatarUrls(
    Iterable<ConversationInfo> conversations,
  ) async {
    final groupIDs = conversations
        .where((conversation) => conversation.isGroupChat)
        .map((conversation) => conversation.groupID)
        .whereType<String>()
        .toSet();
    if (groupIDs.isEmpty) return const {};
    final now = DateTime.now();
    final resolved = <String, List<String>>{};
    final missing = <String>{};
    for (final groupID in groupIDs) {
      final cached = _groupAvatarCache[groupID];
      if (cached != null &&
          now.difference(cached.updatedAt) < _groupAvatarCacheTTL) {
        resolved[groupID] = cached.urls;
      } else {
        missing.add(groupID);
      }
    }
    const maxConcurrentRequests = 4;
    final missingGroupIDs = missing.toList(growable: false);
    final entries = <MapEntry<String, List<String>>>[];
    for (
      var offset = 0;
      offset < missingGroupIDs.length;
      offset += maxConcurrentRequests
    ) {
      final batch = missingGroupIDs.skip(offset).take(maxConcurrentRequests);
      entries.addAll(
        await Future.wait(
          batch.map((groupID) async {
            try {
              final members = await OpenIM.iMManager.groupManager
                  .getGroupMemberList(groupID: groupID, count: 4)
                  .timeout(const Duration(seconds: 2));
              final urls = members
                  .map((member) => member.faceURL?.trim() ?? '')
                  .take(4)
                  .toList(growable: false);
              return MapEntry(groupID, urls);
            } catch (_) {
              return MapEntry(groupID, const <String>[]);
            }
          }),
        ),
      );
    }
    for (final entry in entries) {
      _groupAvatarCache[entry.key] = _GroupAvatarCache(
        urls: entry.value,
        updatedAt: now,
      );
      resolved[entry.key] = entry.value;
    }
    return Map<String, List<String>>.unmodifiable(resolved);
  }

  int _compareConversations(ConversationInfo a, ConversationInfo b) {
    if (a.isPinned != b.isPinned) return a.isPinned == true ? -1 : 1;
    final aTime = [
      a.draftTextTime ?? 0,
      a.latestMsgSendTime ?? 0,
    ].reduce(math.max);
    final bTime = [
      b.draftTextTime ?? 0,
      b.latestMsgSendTime ?? 0,
    ].reduce(math.max);
    return bTime.compareTo(aTime);
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
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          );
        }
        if (conversations.isEmpty &&
            !OpenIMChatRepository.conversationReady.value) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          );
        }
        if (conversations.isEmpty &&
            snapshot.connectionState == ConnectionState.done &&
            OpenIMChatRepository.conversationReady.value) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无会话')),
            ),
          );
        }
        final sortedConversations = List<ConversationInfo>.of(conversations)
          ..sort(_compareConversations);
        if (sortedConversations.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
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
            ),
          );
        }
        return SliverList.builder(
          itemCount: sortedConversations.length,
          itemBuilder: (context, index) {
            final conversation = sortedConversations[index];
            return _SocialMessageTile(
              palette: widget.palette,
              name: conversation.showName ?? conversation.userID ?? '会话',
              message: _latestMessagePreview(conversation.latestMsg),
              avatarUrl: conversation.faceURL,
              groupAvatarUrls: conversation.isGroupChat
                  ? (_groupAvatarUrls[conversation.groupID] ?? const <String>[])
                  : null,
              identity: _identityByUserID[conversation.userID] ?? 0,
              horizontalMargin: 16,
              unreadCount: conversation.unreadCount,
              timestamp: conversation.latestMsgSendTime,
              onTap: () {
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
            );
          },
        );
      },
    );
  }
}

class _GroupAvatarCache {
  const _GroupAvatarCache({required this.urls, required this.updatedAt});

  final List<String> urls;
  final DateTime updatedAt;
}
