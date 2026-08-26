part of 'square_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _hidden = false;
  int _tab = 0;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    children: [
      const _TopActions(),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '我的钱包',
            style: TextStyle(
              color: _white,
              fontSize: AcoTypography.titleLarge,
              fontWeight: FontWeight.w700,
            ),
          ),
          _IconButton(
            icon: _hidden ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ],
      ),
      const SizedBox(height: 14),
      AcoCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '总资产 (USD)',
              style: TextStyle(
                color: _muted,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hidden ? '••••••' : '\$12,854.30',
              style: const TextStyle(
                color: _white,
                fontSize: AcoTypography.display,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AcoButton(
                    label: '收款',
                    icon: CupertinoIcons.arrow_down_left,
                    onPressed: () => _showWalletSheet(context, '收款地址'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AcoButton(
                    label: '发送',
                    icon: CupertinoIcons.arrow_up_right,
                    outlined: true,
                    onPressed: () => _showWalletSheet(context, '发送资产'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _SegmentedTabs(
        labels: const ['资产', '活动'],
        selected: _tab,
        onSelected: (value) => setState(() => _tab = value),
      ),
      const SizedBox(height: 10),
      if (_tab == 0) ...const [
        _AssetRow(
          symbol: 'ETH',
          name: 'Ethereum',
          amount: '3.24 ETH',
          value: '\$10,487.20',
          change: '+2.8%',
        ),
        _AssetRow(
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '2,367.10 USDT',
          value: '\$2,367.10',
          change: '0.0%',
        ),
      ] else
        const _EmptyState(message: '暂无交易活动'),
    ],
  );
}

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    children: [
      const _TopActions(),
      const SizedBox(height: 24),
      const Text(
        '探索',
        style: TextStyle(
          color: _white,
          fontSize: AcoTypography.headline,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 14),
      const AcoInput(
        hint: '搜索应用、链和代币',
        leading: Icon(CupertinoIcons.search, color: _muted, size: 20),
      ),
      const SizedBox(height: 20),
      const Text(
        '热门应用',
        style: TextStyle(
          color: _white,
          fontSize: AcoTypography.bodyEmphasis,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.36,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _ExploreCard(
            icon: CupertinoIcons.chart_bar_alt_fill,
            title: '市场行情',
            subtitle: '实时价格与趋势',
            onTap: () => _showFeatureSheet(context, '市场行情'),
          ),
          _ExploreCard(
            icon: CupertinoIcons.globe,
            title: '链上浏览器',
            subtitle: '发现链上数据',
            onTap: () => _showFeatureSheet(context, '链上浏览器'),
          ),
          _ExploreCard(
            icon: CupertinoIcons.layers_alt_fill,
            title: 'NFT 市场',
            subtitle: '收藏你的数字资产',
            onTap: () => _showFeatureSheet(context, 'NFT 市场'),
          ),
          _ExploreCard(
            icon: CupertinoIcons.bookmark_fill,
            title: '知识中心',
            subtitle: '从零开始了解 Web3',
            onTap: () => _showFeatureSheet(context, '知识中心'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        '推荐内容',
        style: TextStyle(
          color: _white,
          fontSize: AcoTypography.body,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      const _FeatureRow(
        image: 'assets/images/post_chain.jpg',
        title: '链上世界的新秩序',
        subtitle: '深入理解去中心化基础设施',
      ),
      const _FeatureRow(
        image: 'assets/images/post_token.jpg',
        title: '代币经济学入门',
        subtitle: '读懂每一次市场波动',
      ),
    ],
  );
}
