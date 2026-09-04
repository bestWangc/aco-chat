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
