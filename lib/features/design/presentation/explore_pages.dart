part of 'aco_design_shell.dart';

const _squareComposerHorizontalInset = 35.0;

class _BrowserDiscoverPage extends StatelessWidget {
  const _BrowserDiscoverPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
    children: [
      AcoPageHeader(
        palette: palette,
        title: '发现',
        onBack: () => Navigator.of(context).maybePop(),
        backButtonOffset: const Offset(-20, 0),
      ),
      const SizedBox(height: 20),
      AcoSearch(
        palette: palette,
        hint: '请输入网址或搜索',
        onSubmit: () => _showNotice(context, '浏览器', '正在打开搜索结果。'),
        height: 60,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.qrcode_viewfinder, color: palette.mutedText),
            const SizedBox(width: 14),
            _CountPill(palette: palette, label: '7'),
            const SizedBox(width: 4),
          ],
        ),
      ),
      const SizedBox(height: 18),
      AcoSurface(
        palette: palette,
        padding: EdgeInsets.zero,
        child: Container(
          height: 236,
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.compass,
              color: _lime.withValues(alpha: .8),
              size: 38,
            ),
          ),
        ),
      ),
      const SizedBox(height: 56),
      Row(
        children: [
          Expanded(
            child: _SectionTabs(
              palette: palette,
              labels: const ['热门', '探索', '我的'],
              selected: 0,
            ),
          ),
          Text(
            '更多',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: palette.mutedText,
            size: 18,
          ),
        ],
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final app in const ['链上数据', 'NFT 市场', '交易工具', 'Aco 学院'])
            _DiscoverShortcut(
              palette: palette,
              label: app,
              onTap: () => onOpen(AcoScreen.marketOverview),
            ),
        ],
      ),
    ],
  );
}

class _MarketOverviewPage extends StatelessWidget {
  const _MarketOverviewPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(35, 70, 35, 24),
    children: [
      AcoSearch(
        palette: palette,
        hint: '请输入网址或搜索',
        onSubmit: () {},
        height: 60,
      ),
      const SizedBox(height: 34),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.chart_bar_alt_fill,
            label: '现货',
          ),
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.chart_pie_fill,
            label: '合约',
          ),
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.money_dollar_circle_fill,
            label: '股票',
          ),
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.bolt_fill,
            label: '闪兑',
          ),
        ],
      ),
      const SizedBox(height: 54),
      _MarketTabs(palette: palette),
      const SizedBox(height: 28),
      _MarketRow(
        palette: palette,
        name: 'ALD',
        tag: 'DEX',
        price: '\$ 0.39827',
        change: '-0.63%',
      ),
      const SizedBox(height: 22),
      Center(
        child: Text(
          '查看更多  ›',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _SquareFeedPage extends StatefulWidget {
  const _SquareFeedPage({
    super.key,
    required this.palette,
    required this.onOpen,
    this.avatarUrl,
    this.walletLoginFuture,
    this.initialLives,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? avatarUrl;
  final Future<AccountProfile?>? walletLoginFuture;
  final List<LiveSession>? initialLives;

  @override
  State<_SquareFeedPage> createState() => _SquareFeedPageState();
}

class _SquareFeedPageState extends State<_SquareFeedPage> {
  static const _contentHorizontalInset = 35.0;
  static const _liveListHorizontalInset = 25.0;

  final bool _showLive = true;
  final AccountApiClient _apiClient = AccountApiClient();
  late Future<List<LiveSession>> _lives;

  @override
  void initState() {
    super.initState();
    _lives = _loadLives();
  }

  Future<List<LiveSession>> _loadLives({bool useInitialLives = true}) async {
    final initialLives = widget.initialLives;
    if (useInitialLives && initialLives != null) return initialLives;
    // Silent authentication persists the access token asynchronously.
    // Wait for it before calling the protected lives endpoint.
    await widget.walletLoginFuture;
    return AccountSession(_apiClient).listLives();
  }

  void _retryLoadingLives() {
    setState(() {
      _lives = _loadLives(useInitialLives: false);
    });
  }

  Future<void> _refreshLives() async {
    final refreshFuture = _loadLives(useInitialLives: false);
    setState(() {
      _lives = refreshFuture;
    });
    try {
      await refreshFuture;
    } catch (_) {
      // The FutureBuilder below presents the existing load error state.
    }
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _openLiveRoom(LiveSession session) async {
    switch (session.status) {
      case 'scheduled':
        showAcoAlertNotice(context, '预约直播', '该直播尚未开始。');
        return;
      case 'ended':
        if (session.canExportCheckIns) {
          unawaited(_confirmCheckInExport(session));
        } else {
          showAcoAlertNotice(context, '直播已结束', '该直播已经结束。');
        }
        return;
      case 'live':
        break;
      default:
        showAcoAlertNotice(context, '直播不可用', '该直播暂时无法进入。');
        return;
    }
    // Hosts can re-enter their own password-protected live without being
    // prompted again; the server identifies the host authoritatively.
    final joinPassword = session.access == 'password' && !session.canEdit
        ? await _requestLivePassword()
        : null;
    if (!mounted ||
        (session.access == 'password' &&
            !session.canEdit &&
            joinPassword == null)) {
      return;
    }
    if (joinPassword != null &&
        !await _verifyLivePassword(session, joinPassword)) {
      return;
    }
    // Check the kick block before pushing the room route. This keeps the
    // rejection in the live list instead of briefly entering a room page.
    if (joinPassword == null && !await _verifyLiveEntry(session)) return;
    if (!mounted) return;
    Navigator.of(context)
        .push<Object?>(
          _AcoPageRoute<Object?>(
            builder: (_) => CupertinoPageScaffold(
              backgroundColor: widget.palette.background,
              resizeToAvoidBottomInset: true,
              child: SafeArea(
                bottom: false,
                child: ColoredBox(
                  color: widget.palette.background,
                  child: _VoiceRoomPage(
                    palette: widget.palette,
                    live: session,
                    joinPassword: joinPassword,
                  ),
                ),
              ),
            ),
          ),
        )
        .then((ended) async {
          if (!mounted) return;
          await _refreshLives();
          if (!mounted) return;
          if (ended == LiveRoomExitReason.kicked) {
            showAcoAlertNotice(context, '你被踢出直播间', '10分钟内不能再次进入该直播间。');
          } else if (ended == true) {
            showAcoAlertNotice(context, '直播已结束', '主持人已结束直播。');
          }
        });
  }

  Future<bool> _verifyLivePassword(LiveSession session, String password) async {
    try {
      await AccountSession(
        _apiClient,
      ).liveRoom(session.id, joinPassword: password);
      return true;
    } on AccountApiException catch (error) {
      if (mounted) {
        showAcoAlertNotice(
          context,
          error.isLiveKick ? '暂时无法进入直播间' : '无法进入直播间',
          error.localizedMessage,
        );
      }
    } catch (_) {
      if (mounted) showAcoAlertNotice(context, '无法进入直播间', '请检查网络后重试。');
    }
    return false;
  }

  Future<bool> _verifyLiveEntry(LiveSession session) async {
    try {
      await AccountSession(_apiClient).liveRoom(session.id);
      return true;
    } on AccountApiException catch (error) {
      if (mounted) {
        showAcoAlertNotice(
          context,
          error.isLiveKick ? '暂时无法进入直播间' : '无法进入直播间',
          error.localizedMessage,
        );
      }
    } catch (_) {
      if (mounted) showAcoAlertNotice(context, '无法进入直播间', '请检查网络后重试。');
    }
    return false;
  }

  Future<String?> _requestLivePassword() {
    var password = '';
    return showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('输入直播密码'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              key: const Key('live-join-password-field'),
              autofocus: true,
              obscureText: true,
              onChanged: (value) => setDialogState(() => password = value),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(dialogContext).pop(value.trim());
                }
              },
              placeholder: '请输入直播密码',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: password.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(password.trim()),
              child: const Text('进入'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCheckInExport(LiveSession session) async {
    final shouldExport = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('下载签到数据'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('直播已结束，是否要下载签到数据？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            textStyle: TextStyle(color: widget.palette.accent),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (shouldExport == true && mounted) {
      await _exportLiveCheckIns(session);
    }
  }

  Future<void> _exportLiveCheckIns(LiveSession session) async {
    final apiClient = AccountApiClient();
    final accountSession = AccountSession(apiClient);
    try {
      final report = await accountSession.exportLiveCheckIns(session.id);
      final filename = 'live-check-ins-${session.id}.txt';
      if (defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel('aco/downloads').invokeMethod<void>(
          'saveText',
          {
            'filename': filename,
            'bytes': Uint8List.fromList(utf8.encode(report)),
          },
        );
        if (mounted) _showNotice(context, '导出成功', '文件已保存到下载目录。');
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                utf8.encode(report),
                mimeType: 'text/plain',
                name: filename,
              ),
            ],
            subject: '直播签到记录 - ${session.title}',
          ),
        );
      }
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '导出失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '导出失败', '请稍后重试。');
    } finally {
      apiClient.close();
    }
  }

  void _editLive(LiveSession session) {
    Navigator.of(context)
        .push<bool>(
          _AcoPageRoute<bool>(
            builder: (_) => CupertinoPageScaffold(
              backgroundColor: widget.palette.background,
              child: SafeArea(
                bottom: false,
                child: ColoredBox(
                  color: widget.palette.background,
                  child: _CreateLivePage(
                    palette: widget.palette,
                    live: session,
                    walletLoginFuture: widget.walletLoginFuture,
                  ),
                ),
              ),
            ),
          ),
        )
        .then((updated) {
          if (updated == true && mounted) {
            _retryLoadingLives();
          }
        });
  }

  List<Widget> _buildLiveContent(AcoPalette palette) => [
    const SizedBox(height: 24),
    FutureBuilder<List<LiveSession>>(
      future: _lives,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return _LiveListMessage(
            palette: palette,
            message: '直播列表加载失败，请检查网络后重试。',
            actionLabel: '重试',
            onPressed: _retryLoadingLives,
          );
        }
        final sessions = snapshot.data ?? const <LiveSession>[];
        if (sessions.isEmpty) {
          return _LiveListMessage(palette: palette, message: '暂无直播，去创建一场吧。');
        }
        return Column(
          children: [
            for (final session in sessions) ...[
              _LiveCard(
                palette: palette,
                session: session,
                onTap: () => _openLiveRoom(session),
                onEdit: session.canEdit && session.status == 'scheduled'
                    ? () => _editLive(session)
                    : null,
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final onOpen = widget.onOpen;
    // Keep the header in Flutter logical pixels. The surrounding flex layout
    // adapts its width; it does not scale a full design artboard at runtime.
    const headerScale = .672;
    const headerRightInset = 0.0;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshLives,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedHeaderDelegate(
                  extent: 46 * headerScale + 8 + 36 + 18 + 24 + 16 + 1,
                  backgroundColor: palette.background,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _contentHorizontalInset,
                        ),
                        child: SizedBox(
                          height: 46 * headerScale,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: headerRightInset),
                              child: AcoTopActions(
                                palette: palette,
                                onOpen: onOpen,
                                scale: headerScale,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SquareComposer(
                        palette: palette,
                        imageUrl: widget.avatarUrl,
                      ),
                      const SizedBox(height: 18),
                      _SquareTabs(palette: palette, showLive: _showLive),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 1,
                        child: ColoredBox(color: palette.border),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_showLive)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _liveListHorizontalInset,
                        ),
                        child: Column(children: _buildLiveContent(palette)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _contentHorizontalInset,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 32),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _TopicChip(
                                    palette: palette,
                                    label: '买买买!!',
                                    width: 164,
                                  ),
                                  const SizedBox(width: 10),
                                  _TopicChip(
                                    palette: palette,
                                    label: 'ALD! V587!',
                                    width: 184,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            _PostCard(palette: palette),
                          ],
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 22,
          bottom: 0,
          child: Semantics(
            button: true,
            label: '创建直播',
            child: CupertinoButton(
              key: const Key('create-live-button'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(54, 54),
              onPressed: () => onOpen(AcoScreen.createLive),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.add, color: _black, size: 30),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
                message: conversation.latestMsg?.textElem?.content ?? '',
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

class _ContactDetailPage extends StatelessWidget {
  const _ContactDetailPage({
    required this.palette,
    required this.name,
    required this.onMessagePressed,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onMessagePressed;

  String get _handle => '@${name.toLowerCase().replaceAll(' ', '_')}';

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: palette.background,
    child: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AcoPageHeader(
            palette: palette,
            title: '好友详情',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const AcoAvatar(size: 70),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _handle,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: AcoTypography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _ContactDetailActionRow(
            palette: palette,
            icon: CupertinoIcons.chat_bubble,
            label: '发消息',
            onTap: onMessagePressed,
          ),
          const SizedBox(height: 8),
          _ContactDetailActionRow(
            palette: palette,
            icon: CupertinoIcons.phone,
            label: '音频通话',
            onTap: () => _showNotice(context, '音频通话', '通话功能暂未开放。'),
          ),
        ],
      ),
    ),
  );
}

class _ContactDetailActionRow extends StatelessWidget {
  const _ContactDetailActionRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AcoPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 13),
    color: const Color(0xFF191919),
    borderRadius: BorderRadius.circular(12),
    onPressed: onTap,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: palette.accent, size: 19),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.palette,
    required this.name,
    required this.onTap,
    this.avatarUrl,
    this.trailing,
    this.backgroundColor,
    this.borderRadius,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 10),
    this.nameMaxLines = 1,
    this.avatarSize = 42,
    this.nameFontSize,
    this.avatarGap = 20,
    this.showAvatar = true,
    this.nameColor,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String? avatarUrl;
  final Widget? trailing;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets contentPadding;
  final int nameMaxLines;
  final double avatarSize;
  final double? nameFontSize;
  final double avatarGap;
  final bool showAvatar;
  final Color? nameColor;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Container(
      width: double.infinity,
      padding: contentPadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Row(
        children: [
          if (showAvatar) ...[
            AcoAvatar(size: avatarSize, imageUrl: avatarUrl),
            SizedBox(width: avatarGap),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: nameMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: nameColor ?? palette.primaryText,
                fontSize: nameFontSize ?? AcoTypography.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
  );
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({
    required this.extent,
    required this.backgroundColor,
    required this.child,
  });

  final double extent;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: backgroundColor, child: child);

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent ||
      backgroundColor != oldDelegate.backgroundColor ||
      child != oldDelegate.child;
}

const _socialMockMessages = [
  _SocialMockMessage('克里斯蒂亚诺', '你好，股票账户已就位'),
  _SocialMockMessage('Aco 社区', '你好，股票账户已就位'),
  _SocialMockMessage('Builder', '你好，股票账户已就位'),
  _SocialMockMessage('Satoshi', '你好，股票账户已就位'),
  _SocialMockMessage('链上观察者', '你好，股票账户已就位'),
  _SocialMockMessage('Nova', '你好，股票账户已就位'),
  _SocialMockMessage('产品讨论组', '你好，股票账户已就位'),
  _SocialMockMessage('Crypto Lab', '你好，股票账户已就位'),
  _SocialMockMessage(
    'Alice',
    '这是一条很长的消息内容，用来测试聊天列表在消息较长时是否能够正确省略并保持右侧未读数和日期布局稳定。',
  ),
  _SocialMockMessage('Web3 研究院', '你好，股票账户已就位'),
  _SocialMockMessage('Ming', '你好，股票账户已就位'),
  _SocialMockMessage('DAO 社区', '你好，股票账户已就位'),
  _SocialMockMessage('Block Runner', '你好，股票账户已就位'),
];

class _SocialMockMessage {
  const _SocialMockMessage(this.name, this.message);

  final String name;
  final String message;
}

class _ChatHistoryMessage {
  const _ChatHistoryMessage(this.text, {required this.mine})
    : imageBytes = null;

  const _ChatHistoryMessage.image(this.imageBytes, {required this.mine})
    : text = '';

  final String text;
  final bool mine;
  final Uint8List? imageBytes;
}

class _MessageSearchPage extends StatefulWidget {
  const _MessageSearchPage({required this.palette, required this.onOpen});

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends State<_MessageSearchPage> {
  final _controller = TextEditingController();
  var _query = '';

  List<_SocialMockMessage> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _socialMockMessages
        .where((message) => message.message.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return CupertinoPageScaffold(
      backgroundColor: widget.palette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AcoPageHeader(
                palette: widget.palette,
                title: '搜索聊天',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _MessageSearchField(
                controller: _controller,
                palette: widget.palette,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _SearchHint(palette: widget.palette, label: '搜索聊天内容')
                  : results.isEmpty
                  ? _SearchHint(palette: widget.palette, label: '没有找到相关聊天记录')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final message = results[index];
                        return _SocialMessageTile(
                          palette: widget.palette,
                          name: message.name,
                          message: message.message,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onOpen(
                              message.name == 'Builder'
                                  ? AcoScreen.chatV2
                                  : AcoScreen.chatV1,
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
}

class _ChatHistorySearchPage extends StatefulWidget {
  const _ChatHistorySearchPage({
    required this.palette,
    required this.peerName,
    required this.messages,
  });

  final AcoPalette palette;
  final String peerName;
  final List<_ChatHistoryMessage> messages;

  @override
  State<_ChatHistorySearchPage> createState() => _ChatHistorySearchPageState();
}

class _ChatHistorySearchPageState extends State<_ChatHistorySearchPage> {
  final _controller = TextEditingController();
  var _query = '';

  List<_ChatHistoryMessage> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return widget.messages
        .where((message) => message.text.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return CupertinoPageScaffold(
      backgroundColor: widget.palette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AcoPageHeader(
                palette: widget.palette,
                title: '查找聊天记录',
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _MessageSearchField(
                controller: _controller,
                palette: widget.palette,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _SearchHint(
                      palette: widget.palette,
                      label: '搜索与${widget.peerName}的聊天记录',
                    )
                  : results.isEmpty
                  ? _SearchHint(palette: widget.palette, label: '没有找到相关聊天记录')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) => _ChatHistoryResultTile(
                        palette: widget.palette,
                        peerName: widget.peerName,
                        message: results[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHistoryResultTile extends StatelessWidget {
  const _ChatHistoryResultTile({
    required this.palette,
    required this.peerName,
    required this.message,
  });

  final AcoPalette palette;
  final String peerName;
  final _ChatHistoryMessage message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.mine ? '我' : peerName,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption - 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message.text,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ],
    ),
  );
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.palette, required this.label});

  final AcoPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label,
      style: TextStyle(
        color: palette.mutedText,
        fontSize: AcoTypography.caption,
      ),
    ),
  );
}

class _MessageSearchField extends StatelessWidget {
  const _MessageSearchField({
    required this.controller,
    required this.palette,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AcoPalette palette;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(CupertinoIcons.search, color: palette.mutedText, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            cursorColor: palette.primaryText,
            placeholder: '搜索聊天内容',
            placeholderStyle: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.caption,
            ),
            decoration: null,
            padding: EdgeInsets.zero,
            onChanged: onChanged,
            onSubmitted: onChanged,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              child: Icon(
                CupertinoIcons.clear_circled_solid,
                color: palette.mutedText,
                size: 16,
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _SquareComposer extends StatelessWidget {
  const _SquareComposer({required this.palette, this.imageUrl, this.onSubmit});

  final AcoPalette palette;
  final String? imageUrl;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: _squareComposerHorizontalInset,
    ),
    child: SizedBox(
      height: 36,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        maxWidth: double.infinity,
        maxHeight: 36,
        child: Transform.translate(
          offset: const Offset(-11, 0),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width - 54,
            child: Row(
              children: [
                AcoAvatar(size: 36, imageUrl: imageUrl),
                const SizedBox(width: 6),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(10, 0),
                    child: AcoSearch(
                      palette: palette,
                      hint: '搜索帖文或消息',
                      height: 35,
                      variant: AcoSearchVariant.squareComposer,
                      submitIcon: CupertinoIcons.add,
                      showSubmit: true,
                      onSubmit: onSubmit,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SquareTabs extends StatelessWidget {
  const _SquareTabs({required this.palette, required this.showLive});

  final AcoPalette palette;
  final bool showLive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: _squareComposerHorizontalInset,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '推荐',
          style: TextStyle(
            color: showLive ? palette.mutedText : palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: showLive ? FontWeight.w400 : FontWeight.w700,
          ),
        ),
        const SizedBox(width: 54),
        Text(
          '好友',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
        const SizedBox(width: 54),
        Text(
          '直播',
          style: TextStyle(
            color: showLive ? palette.primaryText : palette.mutedText,
            fontSize: AcoTypography.body,
            fontWeight: showLive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _MessageQuickActions extends StatelessWidget {
  const _MessageQuickActions({
    required this.palette,
    required this.onContactsTap,
    required this.onSearchTap,
    this.hasFriendRequest = false,
  });

  final AcoPalette palette;
  final VoidCallback onContactsTap;
  final VoidCallback onSearchTap;
  final bool hasFriendRequest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: _MessageQuickTab(
              icon: CupertinoIcons.person_2,
              label: '通讯录',
              palette: palette,
              onPressed: onContactsTap,
              badge: hasFriendRequest,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MessageQuickTab(
              icon: CupertinoIcons.search,
              label: '搜索',
              palette: palette,
              onPressed: onSearchTap,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageQuickTab extends StatelessWidget {
  const _MessageQuickTab({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onPressed,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final AcoPalette palette;
  final VoidCallback onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: SizedBox(
        width: double.infinity,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF191919),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: palette.primaryText, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.caption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (badge)
                const Positioned(
                  right: 8,
                  top: 4,
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _formatConversationDate(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return '';
  final value = timestamp > 100000000000 ? timestamp : timestamp * 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(value);
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
}

class _SocialMessageTile extends StatelessWidget {
  const _SocialMessageTile({
    required this.palette,
    required this.name,
    required this.onTap,
    required this.message,
    this.avatarUrl,
    this.unreadCount = 0,
    this.timestamp,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String message;
  final String? avatarUrl;
  final int unreadCount;
  final int? timestamp;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 0,
    minLeadingWidth: 34,
    horizontalTitleGap: 12,
    leading: AcoAvatar(size: 34, imageUrl: avatarUrl),
    title: Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.primaryText,
        fontSize: AcoTypography.body - 1,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      message,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: const Color(0xFFA2A4A8),
        fontSize: AcoTypography.caption,
      ),
    ),
    trailing: SizedBox(
      width: 82,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (unreadCount > 0)
            _GreenBadge(
              label: unreadCount > 99 ? '99+' : '$unreadCount',
              color: palette.accent,
              fontSize: AcoTypography.caption - 1,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            ),
          const SizedBox(height: 5),
          Text(
            _formatConversationDate(timestamp),
            style: TextStyle(
              color: const Color(0xFF9D9EA0),
              fontSize: AcoTypography.caption - 2,
            ),
          ),
        ],
      ),
    ),
    onTap: onTap,
  );
}

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
      // Initial positioning should be instantaneous; animating from the
      // first message to the latest one makes opening a chat feel like a
      // whole-page scroll.
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
                          // Keep the last bubble above the composer when the
                          // list is scrolled to its end.
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
                SafeArea(
                  top: false,
                  bottom: !compactBottomBar,
                  minimum: compactBottomBar
                      ? EdgeInsets.zero
                      : const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      4,
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

class _ChatMoreSettingsPage extends StatefulWidget {
  const _ChatMoreSettingsPage({
    required this.palette,
    required this.peerName,
    required this.messages,
  });

  final AcoPalette palette;
  final String peerName;
  final List<_ChatHistoryMessage> messages;

  @override
  State<_ChatMoreSettingsPage> createState() => _ChatMoreSettingsPageState();
}

class _ChatMoreSettingsPageState extends State<_ChatMoreSettingsPage> {
  var _isPinned = false;
  var _isBlocked = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 28, 0),
        child: AcoPageHeader(
          palette: widget.palette,
          title: '聊天信息',
          onBack: () => Navigator.of(context).maybePop(),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          children: [
            _ChatSettingsActionRow(
              palette: widget.palette,
              label: '查找聊天记录',
              onTap: () => Navigator.of(context).push<void>(
                CupertinoPageRoute<void>(
                  builder: (_) => _ChatHistorySearchPage(
                    palette: widget.palette,
                    peerName: widget.peerName,
                    messages: widget.messages,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ChatSettingsToggleRow(
              palette: widget.palette,
              label: '置顶聊天',
              value: _isPinned,
              onChanged: (value) => setState(() => _isPinned = value),
            ),
            const SizedBox(height: 6),
            _ChatSettingsActionRow(
              palette: widget.palette,
              label: '清空聊天记录',
              onTap: () => _showNotice(context, '清空聊天记录', '聊天记录已清空。'),
            ),
            const SizedBox(height: 6),
            _ChatSettingsToggleRow(
              palette: widget.palette,
              label: '拉黑',
              value: _isBlocked,
              onChanged: (value) => setState(() => _isBlocked = value),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChatSettingsActionRow extends StatelessWidget {
  const _ChatSettingsActionRow({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final AcoPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size.fromHeight(46),
      color: const Color(0xFF191919),
      onPressed: onTap,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(color: palette.primaryText, fontSize: 15),
          ),
          const Spacer(),
          Icon(
            CupertinoIcons.chevron_right,
            color: palette.mutedText,
            size: 16,
          ),
        ],
      ),
    ),
  );
}

class _ChatSettingsToggleRow extends StatelessWidget {
  const _ChatSettingsToggleRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final AcoPalette palette;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: palette.primaryText, fontSize: 15)),
        const Spacer(),
        Transform.scale(
          scale: .78,
          child: CupertinoSwitch(
            value: value,
            activeTrackColor: palette.accent,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

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
          _ComposerImageIcon(
            assetPath: 'assets/icons/chat_voice.png',
            onPressed: onVoicePressed,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: voiceInputActive
              ? _HoldToTalkButton(onRecordingChanged: onRecordingChanged)
              : Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191919),
                    borderRadius: BorderRadius.circular(5),
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
        ),
        const SizedBox(width: 8),
        _ComposerImageIcon(
          assetPath: 'assets/icons/chat_add.png',
          onPressed: onMorePressed,
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
  const _ComposerImageIcon({required this.assetPath, required this.onPressed});

  final String assetPath;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(24, 24),
    onPressed: onPressed,
    child: Image.asset(assetPath, width: 24, height: 24),
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
