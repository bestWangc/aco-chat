part of 'aco_design_shell.dart';

class _SquareFeedPage extends StatefulWidget {
  const _SquareFeedPage({
    super.key,
    required this.palette,
    required this.onOpen,
    this.avatarUrl,
    this.identity = 0,
    this.staffIdentity = 0,
    this.walletLoginFuture,
    this.initialLives,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? avatarUrl;
  final int identity;
  final int staffIdentity;
  final Future<AccountProfile?>? walletLoginFuture;
  final List<LiveSession>? initialLives;

  @override
  State<_SquareFeedPage> createState() => _SquareFeedPageState();
}

class _SquareFeedPageState extends State<_SquareFeedPage>
    with WidgetsBindingObserver {
  static const _contentHorizontalInset = 35.0;
  static const _liveListHorizontalInset = 25.0;
  static const _liveRecommendationGap = 12.0;
  static const _liveRecommendationScrollInterval = Duration(milliseconds: 20);
  static const _liveRecommendationScrollPixelsPerTick = 1.0;

  var _selectedTab = _SquareFeedTab.recommended;
  final AccountApiClient _apiClient = AccountApiClient();
  List<LiveSession>? _loadedLives;
  final Set<int> _endedLiveIDs = <int>{};
  Object? _livesError;
  var _livesLoading = true;
  var _livesRequestID = 0;
  final ScrollController _liveRecommendationScrollController =
      ScrollController();
  final ScrollController _postsScrollController = ScrollController();
  Timer? _liveRecommendationScrollTimer;
  List<SquarePost>? _loadedPosts;
  _SquareFeedTab? _loadedPostsTab;
  Object? _postsError;
  var _postsLoading = true;
  var _postsLoadingMore = false;
  String? _postsNextCursor;
  var _postsRequestID = 0;
  final Set<int> _pendingLikePostIDs = <int>{};
  final Set<int> _pendingFollowUserIDs = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _postsScrollController.addListener(_maybeLoadMorePosts);
    unawaited(_beginLivesLoad());
    unawaited(_beginPostsLoad(_SquareFeedTab.recommended));
    _startLiveRecommendationScrolling();
  }

  void _startLiveRecommendationScrolling() {
    _liveRecommendationScrollTimer?.cancel();
    _liveRecommendationScrollTimer = Timer.periodic(
      _liveRecommendationScrollInterval,
      (_) => _scrollLiveRecommendations(),
    );
  }

  bool _isRecommendedLive(LiveSession live) =>
      live.status == 'live' && !_endedLiveIDs.contains(live.id);

  int get _recommendedLiveCount {
    var count = 0;
    for (final live in _loadedLives ?? const <LiveSession>[]) {
      if (_isRecommendedLive(live) && ++count == 2) return count;
    }
    return count;
  }

  void _scrollLiveRecommendations() {
    final controller = _liveRecommendationScrollController;
    final liveCount = _recommendedLiveCount;
    if (!mounted ||
        _selectedTab != _SquareFeedTab.recommended ||
        liveCount < 2 ||
        !controller.hasClients ||
        controller.position.maxScrollExtent <= 0) {
      return;
    }
    final loopDistance =
        (controller.position.viewportDimension * .5 + _liveRecommendationGap) *
        liveCount;
    final nextOffset =
        controller.offset + _liveRecommendationScrollPixelsPerTick;
    controller.jumpTo(
      nextOffset >= loopDistance ? nextOffset - loopDistance : nextOffset,
    );
  }

  // Kept for states preserved by hot reload while the scrolling behavior was
  // changed from a periodic card advance to continuous movement.
  // ignore: unused_element
  void _advanceLiveRecommendations() => _startLiveRecommendationScrolling();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        _selectedTab != _SquareFeedTab.recommended ||
        _livesLoading ||
        !(_loadedLives?.any((live) => live.status == 'live') ?? false)) {
      return;
    }
    unawaited(_refreshLives());
  }

  Future<List<LiveSession>> _loadLives({bool useInitialLives = true}) async {
    final initialLives = widget.initialLives;
    if (useInitialLives && initialLives != null) return initialLives;
    // Silent authentication persists the access token asynchronously.
    // Wait for it before calling the protected lives endpoint.
    await widget.walletLoginFuture;
    return AccountSession(_apiClient).listLives();
  }

  Future<void> _beginLivesLoad({bool useInitialLives = true}) async {
    final requestID = ++_livesRequestID;
    _livesLoading = true;
    _livesError = null;
    if (mounted) setState(() {});
    try {
      final lives = await _loadLives(useInitialLives: useInitialLives);
      if (!mounted || requestID != _livesRequestID) return;
      setState(() {
        _loadedLives = lives;
        _livesLoading = false;
      });
    } catch (error) {
      if (!mounted || requestID != _livesRequestID) return;
      setState(() {
        _livesError = error;
        _livesLoading = false;
      });
    }
  }

  void _retryLoadingLives() {
    unawaited(_beginLivesLoad(useInitialLives: false));
  }

  Future<void> _refreshLives() async {
    await _beginLivesLoad(useInitialLives: false);
  }

  Future<SquarePostPage> _loadPosts(
    _SquareFeedTab tab, {
    String? cursor,
  }) async {
    await widget.walletLoginFuture;
    final session = AccountSession(_apiClient);
    if (tab == _SquareFeedTab.friends) {
      return session.listFriendsPostsPage(cursor: cursor);
    }
    return session.listRecommendedPostsPage(cursor: cursor);
  }

  Future<void> _beginPostsLoad(_SquareFeedTab tab) async {
    final requestID = ++_postsRequestID;
    _postsNextCursor = null;
    _postsLoadingMore = false;
    _postsLoading = true;
    _postsError = null;
    if (mounted) setState(() {});
    try {
      final page = await _loadPosts(tab);
      if (!mounted || requestID != _postsRequestID) return;
      setState(() {
        _loadedPosts = page.posts;
        _loadedPostsTab = tab;
        _postsNextCursor = page.nextCursor;
        _postsLoading = false;
      });
    } catch (error) {
      if (!mounted || requestID != _postsRequestID) return;
      setState(() {
        _postsError = error;
        _postsLoading = false;
      });
    }
  }

  void _maybeLoadMorePosts() {
    final controller = _postsScrollController;
    if (!controller.hasClients ||
        controller.position.extentAfter > 600 ||
        _postsLoading ||
        _postsLoadingMore ||
        _postsNextCursor == null ||
        _loadedPostsTab == null) {
      return;
    }
    unawaited(_loadMorePosts(_loadedPostsTab!));
  }

  Future<void> _loadMorePosts(_SquareFeedTab tab) async {
    final cursor = _postsNextCursor;
    if (cursor == null || _postsLoadingMore) return;
    final requestID = _postsRequestID;
    setState(() => _postsLoadingMore = true);
    try {
      final page = await _loadPosts(tab, cursor: cursor);
      if (!mounted ||
          requestID != _postsRequestID ||
          _loadedPostsTab != tab ||
          cursor != _postsNextCursor) {
        return;
      }
      setState(() {
        _loadedPosts = [...?_loadedPosts, ...page.posts];
        _postsNextCursor = page.nextCursor;
      });
    } catch (error) {
      if (mounted) setState(() => _postsError = error);
    } finally {
      if (mounted) setState(() => _postsLoadingMore = false);
    }
  }

  void _retryLoadingPosts(_SquareFeedTab tab) {
    unawaited(_beginPostsLoad(tab));
  }

  Future<void> _refreshPosts() async {
    final tab = _selectedTab == _SquareFeedTab.friends
        ? _SquareFeedTab.friends
        : _SquareFeedTab.recommended;
    await _beginPostsLoad(tab);
  }

  Future<void> _refreshCurrentTab() async {
    if (_selectedTab == _SquareFeedTab.live) {
      await _refreshLives();
      return;
    }
    await _refreshPosts();
  }

  void _replacePost(SquarePost updatedPost) {
    final posts = _loadedPosts;
    if (!mounted || posts == null) return;
    final index = posts.indexWhere((post) => post.id == updatedPost.id);
    if (index < 0) return;
    final updated = List<SquarePost>.of(posts);
    updated[index] = updatedPost;
    setState(() => _loadedPosts = updated);
  }

  Future<void> _togglePostLike(SquarePost post) async {
    if (!_pendingLikePostIDs.add(post.id)) return;
    if (mounted) setState(() {});
    try {
      await widget.walletLoginFuture;
      final session = AccountSession(_apiClient);
      final result = await _requestPostLikeChange(
        session: session,
        postID: post.id,
        liked: post.liked,
      );
      if (!mounted) return;
      _replacePost(
        post.copyWith(likeCount: result.likeCount, liked: result.liked),
      );
    } catch (error) {
      if (mounted) _showPostLikeError(context, error);
    } finally {
      _pendingLikePostIDs.remove(post.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openPostDetail(SquarePost post) async {
    final updatedPost = await Navigator.of(context).push<SquarePost>(
      _AcoPageRoute<SquarePost>(
        builder: (_) => _PostDetailPage(
          palette: widget.palette,
          post: post,
          walletLoginFuture: widget.walletLoginFuture,
        ),
      ),
    );
    if (!mounted || updatedPost == null) return;
    _replacePost(updatedPost);
  }

  Future<void> _togglePostFollow(SquarePost post) async {
    if (post.authorId <= 0 || !_pendingFollowUserIDs.add(post.authorId)) {
      return;
    }
    if (mounted) setState(() {});
    try {
      await widget.walletLoginFuture;
      final session = AccountSession(_apiClient);
      final result = post.following
          ? await session.unfollowUser(post.authorId)
          : await session.followUser(post.authorId);
      if (!mounted) return;

      final posts = _loadedPosts;
      if (posts == null) return;
      final updatedPosts = posts
          .map((item) {
            if (item.authorId == result.userId) {
              return item.copyWith(following: result.following);
            }
            return item;
          })
          .toList(growable: false);
      final reorderedPosts = _loadedPostsTab == _SquareFeedTab.recommended
          ? _prioritizeFollowedSquarePosts(updatedPosts)
          : updatedPosts;
      setState(() => _loadedPosts = reorderedPosts);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '关注失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '关注失败', '请检查网络后重试。');
    } finally {
      _pendingFollowUserIDs.remove(post.authorId);
      if (mounted) setState(() {});
    }
  }

  void _selectTab(_SquareFeedTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    if (tab == _SquareFeedTab.recommended) {
      unawaited(_refreshLives());
    }
    if (tab != _SquareFeedTab.live && _loadedPostsTab != tab) {
      unawaited(_beginPostsLoad(tab));
    }
  }

  void _handleFloatingAction() {
    if (_selectedTab == _SquareFeedTab.live) {
      widget.onOpen(AcoScreen.createLive);
      return;
    }
    Navigator.of(context)
        .push<bool>(
          _AcoPageRoute<bool>(
            builder: (_) => _PublishPostPage(
              palette: widget.palette,
              walletLoginFuture: widget.walletLoginFuture,
            ),
          ),
        )
        .then((published) {
          if (published == true && mounted) unawaited(_refreshPosts());
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveRecommendationScrollTimer?.cancel();
    _liveRecommendationScrollController.dispose();
    _postsScrollController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _openLiveRoom(LiveSession session) async {
    switch (session.status) {
      case 'scheduled':
        showAcoAlertNotice(context, '预约会议', '该会议尚未开始。');
        return;
      case 'ended':
        if (session.canExportCheckIns) {
          unawaited(_confirmCheckInExport(session));
        } else {
          showAcoAlertNotice(context, '会议已结束', '该会议已经结束。');
        }
        return;
      case 'live':
        break;
      default:
        showAcoAlertNotice(context, '会议不可用', '该会议暂时无法进入。');
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
    final initialRoom = await _joinLiveRoom(session, joinPassword);
    if (!mounted || initialRoom == null) return;
    Navigator.of(context)
        .push<Object?>(
          _AcoPageRoute<Object?>(
            builder: (_) => CupertinoPageScaffold(
              backgroundColor: widget.palette.background,
              resizeToAvoidBottomInset: true,
              child: AcoSafeArea(
                bottom: false,
                child: ColoredBox(
                  color: widget.palette.background,
                  child: _VoiceRoomPage(
                    palette: widget.palette,
                    live: session,
                    joinPassword: joinPassword,
                    initialRoom: initialRoom,
                  ),
                ),
              ),
            ),
          ),
        )
        .then((ended) async {
          if (!mounted) return;
          if (ended == true) {
            setState(() => _endedLiveIDs.add(session.id));
          }
          await _refreshLives();
          if (!mounted) return;
          if (ended == LiveRoomExitReason.kicked) {
            showAcoAlertNotice(context, '你已被移出会议', '10分钟内不能再次进入该会议。');
          } else if (ended == true) {
            showAcoAlertNotice(context, '会议已结束', '主持人已结束会议。');
          }
        });
  }

  Future<LiveRoom?> _joinLiveRoom(
    LiveSession session,
    String? joinPassword,
  ) async {
    try {
      return await AccountSession(
        _apiClient,
      ).liveRoom(session.id, joinPassword: joinPassword, resetRole: true);
    } on AccountApiException catch (error) {
      if (mounted) {
        showAcoAlertNotice(
          context,
          error.isLiveKick ? '暂时无法进入会议' : '无法进入会议',
          error.localizedMessage,
        );
      }
    } catch (_) {
      if (mounted) showAcoAlertNotice(context, '无法进入会议', '请检查网络后重试。');
    }
    return null;
  }

  Future<String?> _requestLivePassword() {
    var password = '';
    return showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('输入会议密码'),
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
              placeholder: '请输入会议密码',
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
          child: Text('会议已结束，是否要下载签到数据？'),
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
            subject: '会议签到记录 - ${session.title}',
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
              child: AcoSafeArea(
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

  Widget _buildLiveSliver(AcoPalette palette) {
    if (_livesLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }
    if (_livesError != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: _LiveListMessage(
            palette: palette,
            message: '会议列表加载失败，请检查网络后重试。',
            actionLabel: '重试',
            onPressed: _retryLoadingLives,
          ),
        ),
      );
    }
    final sessions = _loadedLives ?? const <LiveSession>[];
    if (sessions.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: _LiveListMessage(palette: palette, message: '暂无会议，去创建一场吧。'),
        ),
      );
    }
    return SliverList.builder(
      itemCount: sessions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 24);
        final session = sessions[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _LiveCard(
            palette: palette,
            session: session,
            onTap: () => _openLiveRoom(session),
            onEdit: session.canEdit && session.status == 'scheduled'
                ? () => _editLive(session)
                : null,
          ),
        );
      },
    );
  }

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
          onRefresh: _refreshCurrentTab,
          child: CustomScrollView(
            controller: _postsScrollController,
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
                      _SquareTabs(
                        palette: palette,
                        selectedTab: _selectedTab,
                        onSelected: _selectTab,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 1,
                        child: const ColoredBox(color: Color(0xFF1C1C1C)),
                      ),
                    ],
                  ),
                ),
              ),
              _buildTabContent(palette),
            ],
          ),
        ),
        Positioned(
          right: 22,
          bottom: 0,
          child: Semantics(
            button: true,
            label: _selectedTab == _SquareFeedTab.live ? '创建会议' : '发布动态',
            child: CupertinoButton(
              key: const Key('create-live-button'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(54, 54),
              onPressed: _handleFloatingAction,
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

  Widget _buildTabContent(AcoPalette palette) {
    if (_selectedTab == _SquareFeedTab.live) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          _liveListHorizontalInset,
          0,
          _liveListHorizontalInset,
          96,
        ),
        sliver: _buildLiveSliver(palette),
      );
    }
    if (_selectedTab == _SquareFeedTab.friends) {
      return SliverPadding(
        padding: const EdgeInsets.only(top: 24, bottom: 96),
        sliver: SliverToBoxAdapter(
          child: _buildPosts(palette, _SquareFeedTab.friends),
        ),
      );
    }
    final recommendedLives = (_loadedLives ?? const <LiveSession>[])
        .where(_isRecommendedLive)
        .toList(growable: false);
    final scrollingLives = recommendedLives.length > 1
        ? [...recommendedLives, ...recommendedLives]
        : recommendedLives;
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 96),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Column(
            children: [
              if (recommendedLives.isEmpty)
                const SizedBox(height: 32)
              else ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    controller: _liveRecommendationScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < scrollingLives.length;
                          index++
                        ) ...[
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width * .5,
                            child: _LiveRecommendationCard(
                              key: ValueKey(
                                index < recommendedLives.length
                                    ? 'live-recommendation-${scrollingLives[index].id}'
                                    : 'live-recommendation-duplicate-$index-${scrollingLives[index].id}',
                              ),
                              palette: palette,
                              live: scrollingLives[index],
                              onTap: () => _openLiveRoom(scrollingLives[index]),
                            ),
                          ),
                          if (index < scrollingLives.length - 1)
                            const SizedBox(width: _liveRecommendationGap),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              _buildPosts(palette, _SquareFeedTab.recommended),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildPosts(AcoPalette palette, _SquareFeedTab tab) {
    final isFriends = tab == _SquareFeedTab.friends;
    final isCurrentTab = _loadedPostsTab == tab;
    if (_postsLoading && !isCurrentTab) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_postsError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: _LiveListMessage(
          palette: palette,
          message: isFriends ? '好友动态加载失败，请检查网络后重试。' : '推荐动态加载失败，请检查网络后重试。',
          actionLabel: '重试',
          onPressed: () => _retryLoadingPosts(tab),
        ),
      );
    }
    final posts = isCurrentTab
        ? (_loadedPosts ?? const <SquarePost>[])
        : const <SquarePost>[];
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: _LiveListMessage(
          palette: palette,
          message: isFriends ? '暂无好友动态' : '暂无推荐动态，发布一条吧。',
        ),
      );
    }
    return Column(
      children: [
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: _PostCard(
              key: ValueKey(post.id),
              palette: palette,
              post: post,
              likePending: _pendingLikePostIDs.contains(post.id),
              followPending: _pendingFollowUserIDs.contains(post.authorId),
              onLike: () => _togglePostLike(post),
              onOpen: () => _openPostDetail(post),
              onReply: () => _openPostDetail(post),
              onFollow: () => _togglePostFollow(post),
            ),
          ),
        if (_postsLoadingMore)
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }
}

Future<PostLikeResult> _requestPostLikeChange({
  required AccountSession session,
  required int postID,
  required bool liked,
}) {
  if (liked) return session.unlikePost(postID);
  return session.likePost(postID);
}

List<SquarePost> _prioritizeFollowedSquarePosts(List<SquarePost> posts) {
  final followed = <SquarePost>[];
  final others = <SquarePost>[];
  for (final post in posts) {
    (post.following ? followed : others).add(post);
  }
  return [...followed, ...others];
}

void _showPostLikeError(BuildContext context, Object error) {
  final message = error is AccountApiException
      ? error.localizedMessage
      : '请检查网络后重试。';
  _showNotice(context, '操作失败', message);
}

class _PostDetailPage extends StatefulWidget {
  const _PostDetailPage({
    required this.palette,
    required this.post,
    this.walletLoginFuture,
  });

  final AcoPalette palette;
  final SquarePost post;
  final Future<AccountProfile?>? walletLoginFuture;

  @override
  State<_PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<_PostDetailPage> {
  final AccountApiClient _apiClient = AccountApiClient();
  late final AccountSession _session = AccountSession(_apiClient);
  final TextEditingController _textController = TextEditingController();
  List<PostReply>? _replies;
  Object? _error;
  var _loading = true;
  var _sending = false;
  var _likePending = false;
  late var _liked = widget.post.liked;
  late var _likeCount = widget.post.likeCount;
  late var _replyCount = widget.post.replyCount;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReplies());
  }

  Future<void> _loadReplies() async {
    try {
      await widget.walletLoginFuture;
      final replies = await _session.listPostReplies(widget.post.id);
      if (!mounted) return;
      setState(() {
        _replies = replies;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.walletLoginFuture;
      final reply = await _session.createPostReply(
        postID: widget.post.id,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        final replies = _replies ?? const <PostReply>[];
        _replies = [...replies, reply];
        _replyCount++;
        _textController.clear();
      });
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '回复失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '回复失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_likePending) return;
    setState(() => _likePending = true);
    try {
      await widget.walletLoginFuture;
      final result = await _requestPostLikeChange(
        session: _session,
        postID: widget.post.id,
        liked: _liked,
      );
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
      });
    } catch (error) {
      if (mounted) _showPostLikeError(context, error);
    } finally {
      if (mounted) setState(() => _likePending = false);
    }
  }

  void _close() {
    Navigator.of(context).pop(
      widget.post.copyWith(
        replyCount: _replyCount,
        likeCount: _likeCount,
        liked: _liked,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    navigationBar: CupertinoNavigationBar(
      backgroundColor: widget.palette.background,
      border: null,
      leading: CupertinoNavigationBarBackButton(
        color: widget.palette.primaryText,
        onPressed: _close,
      ),
      middle: Text('动态详情', style: TextStyle(color: widget.palette.primaryText)),
    ),
    child: Column(
      children: [
        Expanded(
          child: SafeArea(top: false, bottom: false, child: _buildReplies()),
        ),
        _buildComposer(),
      ],
    ),
  );

  Widget _buildReplies() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: CupertinoButton(
          onPressed: () {
            setState(() => _loading = true);
            unawaited(_loadReplies());
          },
          child: Text(
            '回复加载失败，点击重试',
            style: TextStyle(color: widget.palette.mutedText),
          ),
        ),
      );
    }
    final replies = _replies ?? const <PostReply>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      children: [
        _buildPostSummary(),
        const SizedBox(height: 28),
        if (replies.isEmpty)
          Center(
            child: Text(
              '还没有回复',
              style: TextStyle(color: widget.palette.mutedText),
            ),
          )
        else
          for (final reply in replies) ...[
            _buildReply(reply),
            const SizedBox(height: 20),
          ],
      ],
    );
  }

  Widget _buildPostSummary() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcoAvatar(size: 52, imageUrl: widget.post.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.post.nickname.isEmpty
                            ? '未命名用户'
                            : widget.post.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.palette.primaryText,
                          fontSize: AcoTypography.bodyEmphasis,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _PostIdentityBadges(
                      identity: widget.post.identity,
                      staffIdentity: widget.post.staffIdentity,
                    ),
                    if (widget.post.following) ...[
                      const SizedBox(width: 7),
                      _PostFollowBadge(palette: widget.palette),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPostDateTime(widget.post.createdAt),
                  style: TextStyle(
                    color: widget.palette.mutedText,
                    fontSize: AcoTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (widget.post.content.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          widget.post.content,
          style: TextStyle(
            color: widget.palette.primaryText,
            height: 1.5,
            fontSize: AcoTypography.body,
          ),
        ),
      ],
      if (widget.post.imageUrls.isNotEmpty) ...[
        const SizedBox(height: 18),
        _PostImageGallery(
          palette: widget.palette,
          imageUrls: widget.post.imageUrls,
        ),
      ],
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Image.asset(
            'assets/icons/post_reply.png',
            width: 18,
            height: 18,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 4),
          Text(
            '$_replyCount',
            style: TextStyle(
              color: widget.palette.mutedText,
              fontSize: AcoTypography.bodySmall,
            ),
          ),
          const SizedBox(width: 24),
          _PostAction(
            icon: _liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            label: '$_likeCount',
            palette: widget.palette,
            active: _liked,
            onTap: _likePending ? null : _toggleLike,
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(height: 1, color: widget.palette.border),
    ],
  );

  Widget _buildReply(PostReply reply) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AcoAvatar(size: 38, imageUrl: reply.avatarUrl),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    reply.nickname.isEmpty ? '未命名用户' : reply.nickname,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _PostIdentityBadges(
                  identity: reply.identity,
                  staffIdentity: reply.staffIdentity,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatPostDateTime(reply.createdAt),
                  style: TextStyle(
                    color: widget.palette.mutedText,
                    fontSize: AcoTypography.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              reply.content,
              style: TextStyle(
                color: widget.palette.primaryText,
                height: 1.45,
                fontSize: AcoTypography.body,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildComposer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: widget.palette.background,
        border: Border(top: BorderSide(color: widget.palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _textController,
              maxLines: 1,
              maxLength: 280,
              placeholder: '写下你的回复…',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.palette.inputSurface,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 10),
            minimumSize: const Size(42, 42),
            onPressed: _sending ? null : _sendReply,
            child: _sending
                ? const CupertinoActivityIndicator()
                : Text('发送', style: TextStyle(color: widget.palette.accent)),
          ),
        ],
      ),
    ),
  );
}

class _PublishPostPage extends StatefulWidget {
  const _PublishPostPage({required this.palette, this.walletLoginFuture});

  final AcoPalette palette;
  final Future<AccountProfile?>? walletLoginFuture;

  @override
  State<_PublishPostPage> createState() => _PublishPostPageState();
}

class _PublishPostPageState extends State<_PublishPostPage> {
  static const _maxPhotoCount = 9;
  static const _maxPostContentRunes = 500;
  static const _photoMaxDimension = 1600.0;
  static const _photoQuality = 72;

  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_PublishPhoto> _photos = [];
  var _pickingPhotos = false;
  var _submitting = false;

  AcoPalette get palette => widget.palette;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotoCount - _photos.length;
    if (remaining <= 0 || _pickingPhotos) return;

    setState(() => _pickingPhotos = true);
    try {
      // image_picker performs the resize and JPEG compression before the
      // files are returned, so the in-memory previews are already smaller.
      final picked = remaining == 1
          ? await _pickSinglePhoto()
          : await _imagePicker.pickMultiImage(
              maxWidth: _photoMaxDimension,
              maxHeight: _photoMaxDimension,
              imageQuality: _photoQuality,
              limit: remaining,
              requestFullMetadata: false,
            );
      final selected = picked.take(remaining).toList(growable: false);
      final photos = await Future.wait(
        selected.map((photo) async {
          final bytes = await photo.readAsBytes();
          return _PublishPhoto(file: photo, bytes: bytes);
        }),
      );
      if (!mounted) return;
      setState(() => _photos.addAll(photos));
    } catch (_) {
      if (mounted) {
        _showNotice(context, '选择照片失败', '请检查照片权限后重试。');
      }
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  Future<List<XFile>> _pickSinglePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _photoMaxDimension,
      maxHeight: _photoMaxDimension,
      imageQuality: _photoQuality,
      requestFullMetadata: false,
    );
    return [?photo];
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _publish() async {
    if (_submitting) return;
    if (_textController.text.trim().isEmpty && _photos.isEmpty) {
      _showNotice(context, '无法发布', '请输入内容或选择照片。');
      return;
    }
    final apiClient = AccountApiClient();
    setState(() => _submitting = true);
    try {
      await widget.walletLoginFuture;
      await AccountSession(apiClient).createPost(
        content: _textController.text.trim(),
        images: _photos.map((photo) => photo.bytes).toList(growable: false),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '发布失败', error.localizedMessage);
    } catch (_) {
      if (mounted) _showNotice(context, '发布失败', '请检查网络后重试。');
    } finally {
      apiClient.close();
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    navigationBar: CupertinoNavigationBar(
      backgroundColor: widget.palette.background,
      border: null,
      leading: CupertinoNavigationBarBackButton(
        color: widget.palette.primaryText,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      middle: Text(
        '发布动态',
        style: TextStyle(
          color: widget.palette.primaryText,
          fontSize: AcoTypography.bodyEmphasis,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _submitting ? null : _publish,
        child: Text(
          _submitting ? '发布中' : '发布',
          style: TextStyle(
            color: widget.palette.accent,
            fontSize: AcoTypography.body,
          ),
        ),
      ),
    ),
    child: AcoSafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CupertinoTextField(
            controller: _textController,
            autofocus: true,
            maxLength: _maxPostContentRunes,
            minLines: 8,
            maxLines: null,
            onChanged: (_) => setState(() {}),
            placeholder: '分享此刻想说的话…',
            placeholderStyle: TextStyle(color: widget.palette.mutedText),
            style: TextStyle(
              color: widget.palette.primaryText,
              fontSize: AcoTypography.body,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.palette.inputSurface,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_textController.text.runes.length}/$_maxPostContentRunes',
              style: TextStyle(
                color: widget.palette.mutedText,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '照片',
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_photos.length}/$_maxPhotoCount',
                style: TextStyle(
                  color: widget.palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PublishPhotoGrid(
            palette: widget.palette,
            photos: _photos,
            isPicking: _pickingPhotos,
            onAdd: _pickPhotos,
            onRemove: _removePhoto,
          ),
        ],
      ),
    ),
  );
}

class _PublishPhoto {
  const _PublishPhoto({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;
}

class _PublishPhotoGrid extends StatelessWidget {
  const _PublishPhotoGrid({
    required this.palette,
    required this.photos,
    required this.isPicking,
    required this.onAdd,
    required this.onRemove,
  });

  final AcoPalette palette;
  final List<_PublishPhoto> photos;
  final bool isPicking;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final itemCount = photos.length + (photos.length < 9 ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        if (index == photos.length) {
          return _AddPhotoTile(
            palette: palette,
            isPicking: isPicking,
            onTap: onAdd,
          );
        }
        return _PublishPhotoTile(
          photo: photos[index],
          palette: palette,
          onRemove: () => onRemove(index),
        );
      },
    );
  }
}

class _PublishPhotoTile extends StatelessWidget {
  const _PublishPhotoTile({
    required this.photo,
    required this.palette,
    required this.onRemove,
  });

  final _PublishPhoto photo;
  final AcoPalette palette;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(photo.bytes, fit: BoxFit.cover),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onRemove,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  CupertinoIcons.xmark,
                  color: Color(0xFFF3F3F3),
                  size: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.palette,
    required this.isPicking,
    required this.onTap,
  });

  final AcoPalette palette;
  final bool isPicking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isPicking ? null : onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.inputSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: isPicking
            ? CupertinoActivityIndicator(color: palette.mutedText)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.photo,
                    color: palette.mutedText,
                    size: 26,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '添加照片',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _SquareComposer extends StatelessWidget {
  const _SquareComposer({required this.palette, this.imageUrl});

  final AcoPalette palette;
  final String? imageUrl;

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

enum _SquareFeedTab { recommended, friends, live }

class _SquareTabs extends StatelessWidget {
  const _SquareTabs({
    required this.palette,
    required this.selectedTab,
    required this.onSelected,
  });

  final AcoPalette palette;
  final _SquareFeedTab selectedTab;
  final ValueChanged<_SquareFeedTab> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: _squareComposerHorizontalInset,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SquareTabButton(
          label: '推荐',
          selected: selectedTab == _SquareFeedTab.recommended,
          palette: palette,
          onPressed: () => onSelected(_SquareFeedTab.recommended),
        ),
        const SizedBox(width: 54),
        _SquareTabButton(
          label: '好友',
          selected: selectedTab == _SquareFeedTab.friends,
          palette: palette,
          onPressed: () => onSelected(_SquareFeedTab.friends),
        ),
        const SizedBox(width: 54),
        _SquareTabButton(
          label: '会议',
          selected: selectedTab == _SquareFeedTab.live,
          palette: palette,
          onPressed: () => onSelected(_SquareFeedTab.live),
        ),
      ],
    ),
  );
}

class _SquareTabButton extends StatelessWidget {
  const _SquareTabButton({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final AcoPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onPressed,
    child: Text(
      label,
      style: TextStyle(
        color: selected ? palette.primaryText : palette.mutedText,
        fontSize: AcoTypography.bodyEmphasis,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
  );
}

class _MessageQuickActions extends StatelessWidget {
  const _MessageQuickActions({
    required this.palette,
    required this.onContactsTap,
    required this.onMessagesTap,
    required this.controller,
    required this.onQueryChanged,
    this.hasUnreadMessages = false,
    this.hasFriendRequest = false,
    this.showContacts = false,
  });

  final AcoPalette palette;
  final VoidCallback onContactsTap;
  final VoidCallback onMessagesTap;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final bool hasUnreadMessages;
  final bool hasFriendRequest;
  final bool showContacts;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF191919), width: 1)),
    ),
    child: SizedBox(
      height: 44,
      child: Row(
        children: [
          _MessageHeaderLabel(
            asset: showContacts
                ? 'assets/icons/chat_messages.png'
                : 'assets/icons/chat_messages_selected.png',
            label: '消息',
            palette: palette,
            selected: !showContacts,
            onPressed: onMessagesTap,
            badge: hasUnreadMessages,
            useAssetColor: !showContacts,
          ),
          const SizedBox(width: 8),
          _MessageHeaderLabel(
            asset: showContacts
                ? 'assets/icons/chat_contacts_selected.png'
                : 'assets/icons/chat_contacts.png',
            label: '通讯录',
            palette: palette,
            onPressed: onContactsTap,
            badge: hasFriendRequest,
            selected: showContacts,
            useAssetColor: showContacts,
          ),
          Expanded(
            child: _MessageListSearchField(
              palette: palette,
              controller: controller,
              onChanged: onQueryChanged,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MessageListSearchField extends StatelessWidget {
  const _MessageListSearchField({
    required this.palette,
    required this.controller,
    required this.onChanged,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: palette.dark ? const Color(0xFF191919) : const Color(0xFFF1F2F3),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(CupertinoIcons.search, color: palette.mutedText, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            maxLines: 1,
            textInputAction: TextInputAction.search,
            cursorColor: palette.accent,
            placeholder: '搜索',
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
                size: 17,
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _MessageHeaderLabel extends StatelessWidget {
  const _MessageHeaderLabel({
    required this.asset,
    required this.label,
    required this.palette,
    this.onPressed,
    this.badge = false,
    this.selected = false,
    this.useAssetColor = false,
  });

  final String asset;
  final String label;
  final AcoPalette palette;
  final VoidCallback? onPressed;
  final bool badge;
  final bool selected;
  final bool useAssetColor;

  @override
  Widget build(BuildContext context) {
    final color = selected ? palette.accent : palette.primaryText;
    final content = SizedBox(
      width: label == '通讯录' ? 42 : 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                asset,
                width: 23,
                height: 20,
                color: useAssetColor ? null : color,
                colorBlendMode: useAssetColor ? null : BlendMode.srcIn,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: AcoTypography.caption - 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (badge)
            const Positioned(
              top: -1,
              right: 1,
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
    );
    if (onPressed == null) return ExcludeSemantics(child: content);
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(46, 44),
        onPressed: onPressed,
        child: content,
      ),
    );
  }
}

String _formatConversationDate(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return '';
  final value = timestamp > 100000000000 ? timestamp : timestamp * 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(value);
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
