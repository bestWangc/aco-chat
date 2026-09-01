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
    child: CustomScrollView(
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
                const SizedBox(height: 8),
                _SquareComposer(
                  palette: palette,
                  imageUrl: avatarUrl,
                  onSubmit: () => _showNotice(context, '搜索', '正在搜索消息。'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (final message in _socialMockMessages)
                _SocialMessageTile(
                  palette: palette,
                  name: message.name,
                  message: message.message,
                  onTap: () => onOpen(
                    message.name == 'Builder'
                        ? AcoScreen.chatV2
                        : AcoScreen.chatV1,
                  ),
                ),
            ]),
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
    contentPadding: EdgeInsets.zero,
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isPanelVisible => _emojiPickerVisible || _morePanelVisible;

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

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final compactBottomBar = _isPanelVisible || keyboardInset > 0;
    return _DetailScaffold(
      palette: widget.palette,
      title: widget.version == 1 ? '克里斯蒂亚诺' : 'Builder',
      headerRightPadding: 4,
      right: Semantics(
        button: true,
        label: '更多',
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(51, 30),
          onPressed: () => _showNotice(context, '更多', '暂无更多操作。'),
          child: Image.asset(
            'assets/icons/chat_more_mark.png',
            width: 26,
            height: 8,
            fit: BoxFit.contain,
          ),
        ),
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hidePanels,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 20, 8, 16),
                  children: [
                    _ChatMessage(
                      palette: widget.palette,
                      text: widget.version == 1
                          ? '我想看下怎么可以买呢，有点难度的，你说是不是'
                          : '我想看下怎么可以卖呢，交易在哪儿操作？',
                      mine: true,
                    ),
                    const SizedBox(height: 18),
                    _ChatMessage(
                      palette: widget.palette,
                      text: '等发你个教程具体看下操作，说也说不清楚还是图文比较好操作',
                      mine: false,
                    ),
                    const SizedBox(height: 18),
                    _ChatMessage(
                      palette: widget.palette,
                      text: '好的，收到后我再试一下。',
                      mine: true,
                    ),
                  ],
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
                padding: EdgeInsets.fromLTRB(8, 4, 8, compactBottomBar ? 2 : 8),
                child: _ChatComposer(
                  controller: _messageController,
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
              _ChatMorePanel(
                onSelected: (label) {
                  setState(() => _morePanelVisible = false);
                  _showNotice(context, label, '$label功能暂未开放。');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.onEmojiPressed,
    required this.onMorePressed,
    required this.onInputTapped,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onEmojiPressed;
  final VoidCallback onMorePressed;
  final VoidCallback onInputTapped;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Row(
      children: [
        _ComposerImageIcon(
          assetPath: 'assets/icons/chat_voice.png',
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
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

class _ChatMorePanel extends StatelessWidget {
  const _ChatMorePanel({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _items = [
    (label: '照片', assetPath: 'assets/icons/chat_more_photo.png'),
    (label: '拍摄', assetPath: 'assets/icons/chat_more_camera.png'),
    (label: '语音通话', assetPath: 'assets/icons/chat_more_call.png'),
    (label: '转账', assetPath: 'assets/icons/chat_more_transfer.png'),
    (label: '语音输入', assetPath: 'assets/icons/chat_more_voice_input.png'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 209,
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
    required this.mine,
  });

  final AcoPalette palette;
  final String text;
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
                child: _Bubble(palette: palette, text: text, mine: mine),
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
