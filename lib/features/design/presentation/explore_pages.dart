part of 'aco_design_shell.dart';

const _squareComposerHorizontalInset = 35.0;

class _BrowserDiscoverPage extends StatefulWidget {
  const _BrowserDiscoverPage({
    required this.palette,
    required this.onOpen,
    required this.chain,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String chain;

  @override
  State<_BrowserDiscoverPage> createState() => _BrowserDiscoverPageState();
}

class _BrowserDiscoverPageState extends State<_BrowserDiscoverPage> {
  late Future<List<DappEntry>> _hotDapps;

  @override
  void initState() {
    super.initState();
    _hotDapps = DappDirectoryService().loadHot(widget.chain);
  }

  @override
  void didUpdateWidget(covariant _BrowserDiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chain != widget.chain) {
      _hotDapps = DappDirectoryService().loadHot(widget.chain);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AcoSearch(
          palette: widget.palette,
          hint: '请输入网址或搜索',
          height: 40,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/search_scan.png',
                width: 18,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: 18),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: _DiscoverAdCarousel(palette: widget.palette),
      ),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SectionTabs(
                palette: widget.palette,
                labels: const ['热门', '探索', '我的'],
                selected: 0,
                itemSpacing: 20,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  Text(
                    '更多',
                    style: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: AcoTypography.body,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/icons/explore_more_chevron.png',
                    width: 8,
                    filterQuality: FilterQuality.high,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FutureBuilder<List<DappEntry>>(
          future: _hotDapps,
          builder: (_, snapshot) {
            final dapps = snapshot.data ?? const <DappEntry>[];
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 85);
            }
            if (dapps.isEmpty) {
              return SizedBox(
                height: 85,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '${widget.chain} 暂无热门 DApp',
                    style: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                ),
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final dapp in dapps.take(4))
                  _DiscoverShortcut(
                    palette: widget.palette,
                    dapp: dapp,
                    onTap: () => _showNotice(context, dapp.name, '功能暂未开放。'),
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      const _DiscoverPromoCarousel(),
      const SizedBox(height: 30),
      _DiscoverEarningsHeader(palette: widget.palette),
    ],
  );
}

class _DiscoverAdCarousel extends StatefulWidget {
  const _DiscoverAdCarousel({required this.palette});

  final AcoPalette palette;

  @override
  State<_DiscoverAdCarousel> createState() => _DiscoverAdCarouselState();
}

class _DiscoverAdCarouselState extends State<_DiscoverAdCarousel> {
  static const _adAssets = [
    'assets/images/explore_ad_newcomer.jpg',
    'assets/images/explore_ad_referral.jpg',
    'assets/images/explore_ad_promotion.jpg',
  ];
  var _currentPage = 0;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.76,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: const Color(0xFF212121),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) => CarouselSlider.builder(
                  options: CarouselOptions(
                    height: constraints.maxHeight,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    autoPlayAnimationDuration: const Duration(
                      milliseconds: 280,
                    ),
                    autoPlayCurve: Curves.easeOut,
                    enlargeCenterPage: false,
                    enableInfiniteScroll: false,
                    viewportFraction: 1,
                    padEnds: false,
                    onPageChanged: (page, _) =>
                        setState(() => _currentPage = page),
                  ),
                  itemCount: _adAssets.length,
                  itemBuilder: (_, index, _) => SizedBox.expand(
                    child: Image.asset(
                      _adAssets[index],
                      fit: BoxFit.fitWidth,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _adAssets.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 3,
                      margin: EdgeInsets.only(
                        right: index == _adAssets.length - 1 ? 0 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: index == _currentPage ? _lime : _black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DiscoverPromoCarousel extends StatefulWidget {
  const _DiscoverPromoCarousel();

  @override
  State<_DiscoverPromoCarousel> createState() => _DiscoverPromoCarouselState();
}

class _DiscoverPromoCarouselState extends State<_DiscoverPromoCarousel> {
  static const _adAssets = [
    'assets/images/explore_promo_msb_license.jpg',
    'assets/images/explore_promo_cayman_qualification.jpg',
    'assets/images/explore_promo_us_qualification.jpg',
  ];
  var _currentPage = 0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 92,
        child: CarouselSlider.builder(
          options: CarouselOptions(
            height: 92,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 280),
            autoPlayCurve: Curves.easeOut,
            enlargeCenterPage: false,
            enableInfiniteScroll: false,
            viewportFraction: .72,
            padEnds: false,
            onPageChanged: (page, _) => setState(() => _currentPage = page),
          ),
          itemCount: _adAssets.length,
          itemBuilder: (_, index, _) => Padding(
            padding: EdgeInsets.only(left: index == 0 ? 20 : 12, right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                _adAssets[index],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < _adAssets.length; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 2,
              margin: EdgeInsets.only(
                right: index == _adAssets.length - 1 ? 0 : 2,
              ),
              decoration: BoxDecoration(
                color: index == _currentPage ? _lime : _black,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    ],
  );
}

class _DiscoverEarningsHeader extends StatelessWidget {
  const _DiscoverEarningsHeader({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '收益专区',
                style: TextStyle(
                  color: const Color(0xFFC2C2C2),
                  fontSize: AcoTypography.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '更多',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.body,
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/icons/explore_more_chevron.png',
              width: 8,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '实用、快速赚币工具集合，最大化闲置资金收益!',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
      ],
    ),
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
