part of 'aco_design_shell.dart';

const _trustWalletDappLogos = <String, String>{
  'aave': 'aave.com.png',
  'aerodrome': 'aerodrome.finance.png',
  'b-ai': 'chat.b.ai.png',
  'balancer': 'balancer.finance.png',
  'camelot': 'camelot.exchange.png',
  'curve': 'curve.fi.png',
  'eigenlayer': 'www.eigenlayer.xyz:.png.png',
  'flap': 'flap.sh.png',
  'fluid': 'fluid.instadapp.io.png',
  'four-meme': 'four.meme.png',
  'gmgn': 'gmgn.ai.png',
  'gmx': 'gmx.io.png',
  'hyperliquid': 'hyperliquid.png',
  'jito': 'www.jito.network.png',
  'jupiter': 'jup.ag.png',
  'lido': 'lido.fi.png',
  'lista': 'lista.org.png',
  'magic-eden': 'magiceden.io.png',
  'morpho': 'app.morpho.org.png',
  'orca': 'www.orca.so.png',
  'opensea': 'opensea.io.png',
  'pancakeswap': 'pancakeswap.finance.png',
  'pump-fun': 'pump.fun.png',
  'quickswap': 'quickswap.exchange.png',
  'raydium': 'raydium.io.png',
  'sunpump': 'sunpump.meme.png',
  'uniswap': 'app.uniswap.org.png',
  'venus': 'app.venus.io.png',
};

String _dappLogoAsset(String dappId) {
  final trustWalletLogo = _trustWalletDappLogos[dappId];
  return trustWalletLogo == null
      ? 'assets/images/dapps/$dappId.webp'
      : 'assets/images/dapps/trustwallet/$trustWalletLogo';
}

class _EarningsDappTile extends StatelessWidget {
  const _EarningsDappTile({
    required this.palette,
    required this.dapp,
    required this.onTap,
  });
  final AcoPalette palette;
  final DappEntry dapp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = dapp.description;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              _dappLogoAsset(dapp.id),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: palette.surfaceRaised,
                child: const SizedBox(width: 64, height: 64),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dapp.name,
                  style: TextStyle(color: palette.primaryText, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  description == null || description.isEmpty
                      ? '热门 DeFi 收益工具'
                      : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverShortcut extends StatelessWidget {
  const _DiscoverShortcut({
    required this.palette,
    required this.dapp,
    required this.onTap,
  });
  final AcoPalette palette;
  final DappEntry dapp;
  final VoidCallback onTap;

  Widget _fallbackIcon(IconData icon) {
    if (dapp.iconUrl.isEmpty) {
      return Icon(icon, color: palette.primaryText);
    }
    return Image.network(
      dapp.iconUrl,
      width: 52,
      height: 52,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(icon, color: palette.primaryText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (dapp.category) {
      case 'dex':
      case 'swap':
        icon = CupertinoIcons.arrow_2_squarepath;
        break;
      case 'nft':
        icon = CupertinoIcons.photo;
        break;
      case 'lending':
        icon = CupertinoIcons.money_dollar_circle;
        break;
      default:
        icon = CupertinoIcons.chart_bar_alt_fill;
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                _dappLogoAsset(dapp.id),
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _fallbackIcon(icon),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            dapp.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketIcon extends StatelessWidget {
  const _MarketIcon({
    required this.palette,
    required this.icon,
    required this.label,
  });
  final AcoPalette palette;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.primaryText),
      ),
    ],
  );
}

class _MarketTabs extends StatelessWidget {
  const _MarketTabs({required this.palette});
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: palette.dark
              ? const Color(0xFFF0F0F0)
              : const Color(0xFF202020),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          '自选 ▼',
          style: TextStyle(
            color: _lime,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 30),
      for (final label in const ['现货', '合约', 'DEX'])
        Padding(
          padding: const EdgeInsets.only(right: 30),
          child: Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
      const Spacer(),
      Icon(CupertinoIcons.chevron_right, color: palette.mutedText, size: 20),
    ],
  );
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.palette,
    required this.name,
    required this.tag,
    required this.price,
    required this.change,
  });
  final AcoPalette palette;
  final String name, tag, price, change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  color: _lime,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: _black,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '\$29.73万',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.body,
              ),
            ),
            Text(
              change,
              style: TextStyle(
                color: change.startsWith('-') ? _danger : _lime,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _GreenBadge extends StatelessWidget {
  const _GreenBadge({
    required this.label,
    this.color = _lime,
    this.fontSize = AcoTypography.caption,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });
  final String label;
  final Color color;
  final double fontSize;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: padding,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      label,
      style: TextStyle(
        color: _black,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LiveRecommendationCard extends StatefulWidget {
  const _LiveRecommendationCard({
    required this.palette,
    required this.live,
    required this.onTap,
    super.key,
  });

  final AcoPalette palette;
  final LiveSession live;
  final VoidCallback onTap;

  @override
  State<_LiveRecommendationCard> createState() =>
      _LiveRecommendationCardState();
}

const _liveRecommendationBackground = Color(0xFF1C1C1C);
const _liveRecommendationBorder = Color(0xFF3D3D3D);

class _LiveRecommendationCardState extends State<_LiveRecommendationCard>
    with TickerProviderStateMixin {
  late final AnimationController _barsController;
  AnimationController? _titleController;

  @override
  void initState() {
    super.initState();
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _titleController = _createTitleController();
  }

  AnimationController _createTitleController() =>
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  @override
  void dispose() {
    _barsController.dispose();
    _titleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleController = _titleController ??= _createTitleController();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: _liveRecommendationBackground,
                  border: Border.all(color: _liveRecommendationBorder),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 54),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ScrollingLiveTitle(
                          title: widget.live.title,
                          color: widget.palette.accent,
                          animation: titleController,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 5, right: 12),
                        child: _AnimatedSignalBars(
                          animation: _barsController,
                          color: widget.palette.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -1,
              top: 0,
              child: Container(
                key: const ValueKey('live-recommendation-avatar-frame'),
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: _liveRecommendationBorder),
                  shape: BoxShape.circle,
                ),
                child: AcoAvatar(size: 42, imageUrl: widget.live.hostAvatarUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollingLiveTitle extends StatelessWidget {
  const _ScrollingLiveTitle({
    required this.title,
    required this.color,
    required this.animation,
  });

  final String title;
  final Color color;
  final Animation<double> animation;

  static const _gap = 24.0;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: AcoTypography.bodyEmphasis,
      fontWeight: FontWeight.w500,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: title, style: style),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        if (textPainter.width <= constraints.maxWidth) {
          return Text(title, maxLines: 1, style: style);
        }
        final offsetDistance = textPainter.width + _gap;
        return ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, _) => Transform.translate(
                offset: Offset(-offsetDistance * animation.value, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, style: style),
                    const SizedBox(width: _gap),
                    Text(title, maxLines: 1, style: style),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSignalBars extends StatelessWidget {
  const _AnimatedSignalBars({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, _) {
      final phase = animation.value * math.pi * 2;
      return SizedBox(
        width: 28,
        height: 18,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < 3; index++)
              Container(
                width: 5,
                height:
                    6 + 8 * ((math.sin(phase + index * math.pi / 2) + 1) / 2),
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    super.key,
    required this.palette,
    required this.post,
    required this.onLike,
    required this.onOpen,
    required this.onReply,
    required this.onFollow,
    this.likePending = false,
    this.followPending = false,
  });

  final AcoPalette palette;
  final SquarePost post;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final VoidCallback onReply;
  final VoidCallback onFollow;
  final bool likePending;
  final bool followPending;

  Future<void> _showMoreMenu(BuildContext context) async {
    final buttonBox = context.findRenderObject() as RenderBox;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    const popupWidth = 112.0;
    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final maxLeft = math.max(8.0, overlayBox.size.width - popupWidth - 8);
    final left = math.min(
      maxLeft,
      math.max(8.0, buttonTopLeft.dx + buttonBox.size.width - popupWidth),
    );
    final maxTop = math.max(8.0, overlayBox.size.height - 58);
    final top = math.min(maxTop, buttonTopLeft.dy + buttonBox.size.height + 4);

    final shouldFollow = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭动态操作菜单',
      barrierColor: const Color(0x33000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, _) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: SizedBox(
                width: popupWidth,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      post.following ? '取消关注' : '关注',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (shouldFollow == true && !followPending) onFollow();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcoAvatar(size: 52, imageUrl: post.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.nickname.isEmpty ? '未命名用户' : post.nickname,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: AcoTypography.bodyEmphasis,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          _PostIdentityBadges(
                            identity: post.identity,
                            staffIdentity: post.staffIdentity,
                          ),
                          if (post.following) ...[
                            const SizedBox(width: 7),
                            _PostFollowBadge(palette: palette),
                          ],
                          const SizedBox(width: 10),
                          Text(
                            _formatPostDateTime(post.createdAt),
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: AcoTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (menuContext) => CupertinoButton(
                        padding: const EdgeInsets.only(right: 12),
                        minimumSize: Size.zero,
                        onPressed: () => unawaited(_showMoreMenu(menuContext)),
                        child: Image.asset(
                          'assets/icons/post_more_indicator.png',
                          width: 20,
                          filterQuality: FilterQuality.high,
                          semanticLabel: '更多操作',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (post.content.isNotEmpty)
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: Color(0xFFF3F3F3),
                      height: 1.5,
                      fontSize: AcoTypography.body,
                    ),
                  ),
                if (post.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _PostImageGallery(
                    palette: palette,
                    imageUrls: post.imageUrls,
                    thumbnailUrls: post.thumbnailUrls,
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PostAction(
                        iconAsset: 'assets/icons/post_reply.png',
                        label: '${post.replyCount}',
                        palette: palette,
                        onTap: onReply,
                      ),
                      const SizedBox(width: 28),
                      _PostAction(
                        icon: post.liked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        label: '${post.likeCount}',
                        palette: palette,
                        active: post.liked,
                        onTap: likePending ? null : onLike,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PostImageGallery extends StatelessWidget {
  const _PostImageGallery({
    required this.palette,
    required this.imageUrls,
    required this.thumbnailUrls,
  });

  final AcoPalette palette;
  final List<String> imageUrls;
  final List<String> thumbnailUrls;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (imageUrls.length == 1) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(208.0, constraints.maxWidth),
            maxHeight: 208,
          ),
          child: _imageTile(
            context,
            imageUrls.first,
            thumbnailUrl: thumbnailUrls.first,
            fit: BoxFit.contain,
          ),
        );
      }

      const columns = 3;
      const spacing = 4.0;
      final width = math.min(260.0, constraints.maxWidth);
      final rows = (imageUrls.length + columns - 1) ~/ columns;
      final itemSize = (width - (columns - 1) * spacing) / columns;
      final height = rows * itemSize + (rows - 1) * spacing;
      return SizedBox(
        width: width,
        height: height,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: imageUrls.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: itemSize,
          ),
          itemBuilder: (_, index) => _imageTile(
            context,
            imageUrls[index],
            thumbnailUrl: thumbnailUrls[index],
            width: double.infinity,
          ),
        ),
      );
    },
  );

  Widget _imageTile(
    BuildContext context,
    String imageUrl, {
    required String thumbnailUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) => Semantics(
    button: true,
    label: '查看动态大图',
    child: GestureDetector(
      onTap: () => _openImage(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: palette.surface,
          child: Image.network(
            _liveCoverUrl(thumbnailUrl),
            width: width,
            height: height,
            // Feed cards are at most 260 logical pixels wide. Decode a bounded
            // bitmap here; tapping the card still opens the full resource.
            cacheWidth: (260 * MediaQuery.devicePixelRatioOf(context)).round(),
            cacheHeight: (260 * MediaQuery.devicePixelRatioOf(context)).round(),
            fit: fit,
            semanticLabel: '动态图片缩略图',
            errorBuilder: (_, _, _) => Center(
              child: Icon(
                CupertinoIcons.photo,
                color: palette.mutedText,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _openImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push<void>(
      _AcoPageRoute<void>(
        builder: (_) => _PostImagePreview(imageUrl: _liveCoverUrl(imageUrl)),
      ),
    );
  }
}

class _PostImagePreview extends StatelessWidget {
  const _PostImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _black,
    child: AcoSafeArea(
      child: Stack(
        children: [
          Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              semanticLabel: '动态大图',
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(CupertinoIcons.xmark, color: _white, size: 22),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatPostDateTime(DateTime value) {
  final elapsed = DateTime.now().difference(value);
  if (elapsed.isNegative || elapsed.inSeconds < 60) return '刚刚';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}分钟前';
  if (elapsed.inHours < 24) return '${elapsed.inHours}小时前';
  return '${elapsed.inDays}天前';
}

class _PostIdentityBadges extends StatelessWidget {
  const _PostIdentityBadges({
    required this.identity,
    required this.staffIdentity,
  });

  final int identity;
  final int staffIdentity;

  @override
  Widget build(BuildContext context) {
    final identityAsset = _identityNodeAsset(identity);
    final staffAsset = _staffBadgeAsset(staffIdentity);
    if (identityAsset == null && staffAsset == null) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (identityAsset != null)
          Image.asset(
            identityAsset,
            width: _shortBadgeWidth(identity),
            fit: BoxFit.contain,
          ),
        if (identityAsset != null && staffAsset != null)
          const SizedBox(width: 3),
        if (staffAsset != null)
          Image.asset(staffAsset, width: 18, fit: BoxFit.contain),
      ],
    );
  }
}

class _PostFollowBadge extends StatelessWidget {
  const _PostFollowBadge({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Text(
    '已关注',
    style: TextStyle(
      color: palette.accent,
      fontSize: AcoTypography.caption,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.palette,
    this.onTap,
    this.active = false,
  }) : assert(icon != null || iconAsset != null);
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final AcoPalette palette;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    onPressed: onTap,
    child: Row(
      children: [
        if (iconAsset != null)
          SizedBox(
            width: 18,
            height: 18,
            child: Image.asset(
              iconAsset!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: '回复',
            ),
          )
        else
          Icon(
            icon!,
            color: active ? palette.accent : palette.primaryText,
            size: 18,
          ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? palette.accent : palette.primaryText,
              fontSize: AcoTypography.body,
            ),
          ),
        ],
      ],
    ),
  );
}

const _chatBubbleTailWidth = 5.0;
const _chatBubbleTailHeight = 7.0;
const _chatBubbleRadius = 6.0;

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.palette,
    required this.text,
    required this.mine,
    this.onTextSelected,
  });
  final AcoPalette palette;
  final String text;
  final bool mine;
  final ValueChanged<String>? onTextSelected;
  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: mine ? _black : _white,
      height: 1.4,
      fontSize: 16,
    );
    final textWidget = SelectableText(
      text,
      style: textStyle,
      onSelectionChanged: (selection, _) {
        if (!selection.isCollapsed) {
          onTextSelected?.call(selection.textInside(text));
        }
      },
    );
    if (!mine) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: CustomPaint(
          painter: const _OtherBubblePainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: textWidget,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: CustomPaint(
        painter: const _MineBubblePainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
          child: textWidget,
        ),
      ),
    );
  }
}

class _OtherBubblePainter extends CustomPainter {
  const _OtherBubblePainter({this.color = const Color(0xFF2C2C2C)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = _chatBubbleTailWidth;
    final bubbleLeft = tailWidth;
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleLeft, 0, size.width - tailWidth, size.height),
        const Radius.circular(_chatBubbleRadius),
      ),
      paint,
    );
    // The message row is top-aligned and the avatar is 40 logical units tall, so the
    // tail should stay at the avatar's vertical center even for long text.
    final tailCenter = math.min(20.0, size.height / 2);
    final tail = Path()
      ..moveTo(bubbleLeft + 1, tailCenter - _chatBubbleTailHeight)
      ..lineTo(1, tailCenter - 1)
      ..quadraticBezierTo(0, tailCenter, 1, tailCenter + 1)
      ..lineTo(bubbleLeft + 1, tailCenter + _chatBubbleTailHeight)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _OtherBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MineBubblePainter extends CustomPainter {
  const _MineBubblePainter({this.color = const Color(0xFF28B561)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = _chatBubbleTailWidth;
    final bubbleWidth = size.width - tailWidth;
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, bubbleWidth, size.height),
        const Radius.circular(_chatBubbleRadius),
      ),
      paint,
    );
    // The message row is top-aligned and the avatar is 40 logical units tall, so the
    // tail should stay at the avatar's vertical center even for long text.
    final tailCenter = math.min(20.0, size.height / 2);
    final tail = Path()
      ..moveTo(bubbleWidth - 1, tailCenter - _chatBubbleTailHeight)
      ..lineTo(size.width - 1, tailCenter - 1)
      ..quadraticBezierTo(
        size.width,
        tailCenter,
        size.width - 1,
        tailCenter + 1,
      )
      ..lineTo(bubbleWidth - 1, tailCenter + _chatBubbleTailHeight)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant _MineBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.palette,
    required this.session,
    this.onTap,
    this.onEdit,
  });
  final AcoPalette palette;
  final LiveSession session;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  String? get _scheduledStartLabel {
    final scheduledAt = session.scheduledAt;
    if (session.status != 'scheduled' || scheduledAt == null) return null;
    final localTime = scheduledAt.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '开始时间 ${localTime.month}月${localTime.day}日 $hour:$minute';
  }

  bool get _isLive => session.status == 'live';

  String get _statusLabel {
    switch (session.status) {
      case 'live':
        return '进行中';
      case 'scheduled':
        return '预约中';
      case 'ended':
        return '已结束';
      default:
        return session.status;
    }
  }

  Color get _statusColor => _isLive || session.status == 'scheduled'
      ? palette.accent
      : palette.mutedText;

  Color get _statusBackground => _statusColor.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    final scheduledStartLabel = _scheduledStartLabel;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              palette.dark
                  ? 'assets/icons/live_brand_dark.png'
                  : 'assets/icons/live_brand_light.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (session.status.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: AcoTypography.caption,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (session.canExportCheckIns) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '我的会议',
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: AcoTypography.caption,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (scheduledStartLabel != null) ...[
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                scheduledStartLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: AcoTypography.caption,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              AcoIconButton(
                icon: CupertinoIcons.pencil,
                palette: palette,
                label: '修改会议',
                size: 20,
                onPressed: onEdit!,
              ),
            ],
          ],
        ),
        if (session.coverUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              _liveCoverUrl(session.coverUrl),
              width: double.infinity,
              height: 160,
              cacheWidth:
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              cacheHeight: (160 * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _LiveCoverPlaceholder(palette: palette),
            ),
          ),
        ],
      ],
    );
    return onTap == null
        ? content
        : CupertinoButton(
            padding: EdgeInsets.zero,
            pressedOpacity: 0.72,
            onPressed: onTap,
            child: content,
          );
  }
}

String _liveCoverUrl(String coverUrl) {
  if (Uri.tryParse(coverUrl)?.hasScheme ?? false) return coverUrl;
  final apiUri = Uri.parse(const AppConfig().apiBaseUrl);
  return apiUri.replace(path: coverUrl).toString();
}

class _LiveCoverPlaceholder extends StatelessWidget {
  const _LiveCoverPlaceholder({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 220,
    color: palette.surfaceRaised,
    alignment: Alignment.center,
    child: Icon(CupertinoIcons.photo, color: palette.mutedText, size: 30),
  );
}

class _LiveCoverThumbnailFallback extends StatelessWidget {
  const _LiveCoverThumbnailFallback({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 52,
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(CupertinoIcons.photo, color: palette.mutedText, size: 26),
  );
}

class _LiveListMessage extends StatelessWidget {
  const _LiveListMessage({
    required this.palette,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final AcoPalette palette;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(CupertinoIcons.video_camera, color: palette.mutedText, size: 32),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: onPressed,
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}
