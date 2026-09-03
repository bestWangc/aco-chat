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
                _OpenIMConversationList(palette: palette, onOpen: onOpen),
              ]),
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
    _friends = _loadFriends();
  }

  Future<List<FriendContact>> _loadFriends() async {
    final client = AccountApiClient();
    try {
      return await AccountSession(client).listFriends();
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
                  debugPrint('[OpenIM] contacts load failed: ${snapshot.error}');
                  return _ContactsStateMessage(
                    message: '通讯录加载失败，点击重试',
                    onRetry: () => setState(() => _friends = _loadFriends()),
                  );
                }
                final friends = snapshot.data ?? const <FriendContact>[];
                if (friends.isEmpty) {
                  return const _ContactsStateMessage(message: '暂无好友');
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
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
    child: CupertinoButton(
      onPressed: onRetry,
      child: Text(message),
    ),
  );
}

class _OpenIMConversationList extends StatelessWidget {
  const _OpenIMConversationList({required this.palette, required this.onOpen});

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationInfo>>(
      future: OpenIM.iMManager.conversationManager.getAllConversationList(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const <ConversationInfo>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        if (conversations.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('暂无会话')),
          );
        }
        return Column(
          children: [
            for (final conversation in conversations)
              _SocialMessageTile(
                palette: palette,
                name: conversation.showName ?? conversation.userID ?? '会话',
                message: conversation.latestMsg?.textElem?.content ?? '',
                onTap: () => onOpen(AcoScreen.chatV1),
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
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 10),
    onPressed: onTap,
    child: Row(
      children: [
        AcoAvatar(size: 42, imageUrl: avatarUrl),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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

const _chatV1History = [
  _ChatHistoryMessage('我想看下怎么可以买呢，有点难度的，你说是不是', mine: true),
  _ChatHistoryMessage('等发你个教程具体看下操作，说也说不清楚还是图文比较好操作', mine: false),
  _ChatHistoryMessage('好的，收到后我再试一下。', mine: true),
];

const _chatV2History = [
  _ChatHistoryMessage('我想看下怎么可以卖呢，交易在哪儿操作？', mine: true),
  _ChatHistoryMessage('等发你个教程具体看下操作，说也说不清楚还是图文比较好操作', mine: false),
  _ChatHistoryMessage('好的，收到后我再试一下。', mine: true),
];

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
  });

  final AcoPalette palette;
  final VoidCallback onContactsTap;
  final VoidCallback onSearchTap;

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
  });

  final IconData icon;
  final String label;
  final AcoPalette palette;
  final VoidCallback onPressed;

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    ),
  );
}

class _SocialMessageTile extends StatelessWidget {
  const _SocialMessageTile({
    required this.palette,
    required this.name,
    required this.onTap,
    required this.message,
    this.avatarUrl,
  });

  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  final String message;
  final String? avatarUrl;

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
    trailing: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _GreenBadge(
          label: '14',
          color: palette.accent,
          fontSize: AcoTypography.caption - 1,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        ),
        const SizedBox(height: 5),
        Text(
          '2026-08-05',
          style: TextStyle(
            color: const Color(0xFF9D9EA0),
            fontSize: AcoTypography.caption - 2,
          ),
        ),
      ],
    ),
    onTap: onTap,
  );
}

class _ChatPage extends StatefulWidget {
  const _ChatPage({required this.palette, required this.version});
  final AcoPalette palette;
  final int version;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final _messageController = TextEditingController();
  var _emojiPickerVisible = false;
  var _morePanelVisible = false;
  var _voiceInputActive = false;
  var _voiceRecording = false;
  late final List<_ChatHistoryMessage> _chatHistory = List.of(
    widget.version == 1 ? _chatV1History : _chatV2History,
  );

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isPanelVisible => _emojiPickerVisible || _morePanelVisible;

  String get _peerName => widget.version == 1 ? '克里斯蒂亚诺' : 'Builder';

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
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
                      itemCount: _chatHistory.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 18),
                      itemBuilder: (_, index) {
                        final message = _chatHistory[index];
                        return _ChatMessage(
                          palette: widget.palette,
                          text: message.text,
                          imageBytes: message.imageBytes,
                          mine: message.mine,
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
                      onSubmit: () => _showNotice(context, '消息已发送', '已发送至对方。'),
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
  });

  final AcoPalette palette;
  final String text;
  final Uint8List? imageBytes;
  final bool mine;

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
            if (!mine) ...[const AcoAvatar(size: 40), const SizedBox(width: 6)],
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
