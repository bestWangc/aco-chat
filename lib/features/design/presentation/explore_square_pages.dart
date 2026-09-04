part of 'aco_design_shell.dart';

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
