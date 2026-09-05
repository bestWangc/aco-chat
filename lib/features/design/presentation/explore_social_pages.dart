part of 'aco_design_shell.dart';

class _SocialMessagesPage extends StatelessWidget {
  const _SocialMessagesPage({
    required this.palette,
    required this.onOpen,
    this.avatarUrl,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? avatarUrl;
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
              extent: 46 * .672 + 8 + 36,
              backgroundColor: palette.background,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 35),
                    child: AcoRootHeader(
                      palette: palette,
                      onOpen: onOpen,
                      scale: .672,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _MessageQuickActions(
                    hasFriendRequest: false,
                    palette: palette,
                    onContactsTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) =>
                            _ContactsPage(palette: palette, onOpen: onOpen),
                      ),
                    ),
                    onSearchTap: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => _MessageSearchPage(
                          palette: palette,
                          onOpen: onOpen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _FriendRequestChatSection(palette: palette),
                _OpenIMConversationList(palette: palette, onOpen: onOpen),
              ]),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FriendRequestChatSection extends StatefulWidget {
  const _FriendRequestChatSection({required this.palette});

  final AcoPalette palette;

  @override
  State<_FriendRequestChatSection> createState() =>
      _FriendRequestChatSectionState();
}

Future<List<FriendContact>> _fetchFriendRequests() async {
  final client = AccountApiClient();
  try {
    return await AccountSession(client).listFriendRequests();
  } finally {
    client.close();
  }
}

class _FriendRequestChatSectionState extends State<_FriendRequestChatSection> {
  late Future<List<FriendContact>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _load();
    OpenIMChatRepository.friendRequestNotifier.addListener(_reload);
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _requests = _load();
      });
    }
  }

  @override
  void dispose() {
    OpenIMChatRepository.friendRequestNotifier.removeListener(_reload);
    super.dispose();
  }

  Future<List<FriendContact>> _load() async {
    return _fetchFriendRequests();
  }

  Future<void> _openRequestsPage(BuildContext context) async {
    // Mark the badge as read immediately when the request list is opened.
    OpenIMChatRepository.friendRequestNotifier.value = null;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _FriendRequestsPage(palette: widget.palette),
      ),
    );
    // Treat the request list as read even if an SDK event arrived while it
    // was open. This keeps the bottom navigation badge in sync on return.
    OpenIMChatRepository.friendRequestNotifier.value = null;
    if (!mounted) return;
    setState(() {
      _requests = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<FriendContact>>(
    future: _requests,
    builder: (context, snapshot) {
      final requests = snapshot.data ?? const <FriendContact>[];
      if (requests.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ContactListTile(
          palette: widget.palette,
          name: '有新的好友请求（${requests.length}）',
          onTap: () {
            _openRequestsPage(context);
          },
          backgroundColor: widget.palette.accent,
          borderRadius: BorderRadius.circular(6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          nameMaxLines: 2,
          showAvatar: false,
          avatarSize: 30,
          avatarGap: 0,
          nameFontSize: 14,
          nameColor: const Color(0xFF000000),
          trailing: Icon(
            CupertinoIcons.chevron_right,
            color: const Color(0xFF000000),
            size: 16,
          ),
        ),
      );
    },
  );
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
    OpenIMChatRepository.friendRequestNotifier.value = null;
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
      OpenIMChatRepository.friendRequestNotifier.value = null;
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
  const _ContactsPage({required this.palette, required this.onOpen});

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<_ContactsPage> {
  late Future<List<FriendContact>> _friends;

  @override
  void initState() {
    super.initState();
    // Opening the contacts page marks the current friend requests as seen.
    OpenIMChatRepository.friendRequestNotifier.value = null;
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
              title: '通讯录',
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FriendContact>>(
              future: _friends,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint(
                    '[OpenIM] contacts load failed: ${snapshot.error}',
                  );
                  return _ContactsStateMessage(
                    message: '通讯录加载失败，点击重试',
                    onRetry: () => setState(() {
                      _friends = _loadFriends();
                    }),
                  );
                }
                final friends = snapshot.data ?? const <FriendContact>[];
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: friends.isEmpty ? 1 : friends.length,
                    itemBuilder: (context, index) {
                      if (friends.isEmpty) {
                        return const _ContactsStateMessage(message: '暂无好友');
                      }
                      final friend = friends[index];
                      final name = friend.nickname.isEmpty
                          ? friend.accountId
                          : friend.nickname;
                      return _ContactListTile(
                        palette: widget.palette,
                        name: name,
                        avatarUrl: friend.avatarUrl,
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute<void>(
                            builder: (_) => _ContactDetailPage(
                              palette: widget.palette,
                              name: name,
                              onMessagePressed: () {
                                OpenIMChatRepository.pendingConversation =
                                    ConversationInfo(
                                      conversationID: 'si_${friend.accountId}',
                                      userID: friend.accountId,
                                      showName: name,
                                    );
                                final navigator = Navigator.of(context);
                                navigator.pop();
                                navigator.pop();
                                widget.onOpen(AcoScreen.chatV1);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
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
  late Future<List<ConversationInfo>> _conversations;
  Timer? _reloadTimer;

  String _latestMessagePreview(Message? message) {
    final text = message?.textElem?.content;
    if (text?.isNotEmpty == true) return text!;
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
        final conversations = await OpenIM.iMManager.conversationManager
            .getAllConversationList()
            .timeout(const Duration(seconds: 3));
        final userIDs = conversations
            .map((conversation) => conversation.userID)
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
        if (userIDs.isNotEmpty) {
          try {
            final users = await OpenIM.iMManager.userManager
                .getUsersInfo(userIDList: userIDs)
                .timeout(const Duration(seconds: 3));
            final profiles = {
              for (final user in users)
                if (user.userID != null) user.userID!: user,
            };
            for (final conversation in conversations) {
              final profile = profiles[conversation.userID];
              if (profile == null) continue;
              if (profile.nickname?.trim().isNotEmpty == true) {
                conversation.showName = profile.nickname!.trim();
              }
              conversation.faceURL = profile.faceURL;
            }
          } catch (error) {
            debugPrint('[OpenIM] conversation profile load failed: $error');
          }
          // The application API is the source of truth for profile fields;
          // OpenIM may legitimately return the account ID as nickname.
          final client = AccountApiClient();
          try {
            final friends = await AccountSession(
              client,
            ).listFriends().timeout(const Duration(seconds: 5));
            final profiles = {
              for (final friend in friends) friend.accountId: friend,
            };
            for (final conversation in conversations) {
              final friend = profiles[conversation.userID];
              if (friend == null) continue;
              if (friend.nickname.isNotEmpty) {
                conversation.showName = friend.nickname;
              }
              if (friend.avatarUrl.isNotEmpty) {
                conversation.faceURL = friend.avatarUrl;
              }
            }
          } catch (error) {
            debugPrint('[API] conversation profile load failed: $error');
          } finally {
            client.close();
          }
        }
        if (conversations.isEmpty && _cachedConversations.isNotEmpty) {
          return _cachedConversations;
        }
        _cachedConversations = List<ConversationInfo>.unmodifiable(
          conversations,
        );
        return _cachedConversations;
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
        return Column(
          children: [
            for (final conversation in conversations)
              _SocialMessageTile(
                palette: widget.palette,
                name: conversation.showName ?? conversation.userID ?? '会话',
                message: _latestMessagePreview(conversation.latestMsg),
                avatarUrl: conversation.faceURL,
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
              ),
          ],
        );
      },
    );
  }
}
