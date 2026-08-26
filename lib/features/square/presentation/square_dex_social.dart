part of 'square_page.dart';

class DexPage extends StatefulWidget {
  const DexPage({super.key});

  @override
  State<DexPage> createState() => _DexPageState();
}

class _DexPageState extends State<DexPage> {
  final _from = TextEditingController();
  bool _flipped = false;

  @override
  void dispose() {
    _from.dispose();
    super.dispose();
  }

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
            'DEX',
            style: TextStyle(
              color: _white,
              fontSize: AcoTypography.headline,
              fontWeight: FontWeight.w700,
            ),
          ),
          AcoBadge(label: 'Ethereum', icon: CupertinoIcons.chevron_down),
        ],
      ),
      const SizedBox(height: 18),
      AcoCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _TokenInput(
              label: '支付',
              symbol: _flipped ? 'USDT' : 'ETH',
              controller: _from,
            ),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up_arrow_down,
                  color: _lime,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 5),
            _TokenInput(label: '收到', symbol: _flipped ? 'ETH' : 'USDT'),
            const SizedBox(height: 14),
            AcoButton(
              label: '连接钱包',
              icon: CupertinoIcons.arrow_right_arrow_left,
              onPressed: () => _showWalletSheet(context, '连接钱包'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        '热门交易对',
        style: TextStyle(
          color: _white,
          fontSize: AcoTypography.body,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      const _PairRow(pair: 'ETH / USDT', price: '\$3,238.20', change: '+4.72%'),
      const _PairRow(
        pair: 'BTC / USDT',
        price: '\$114,624.00',
        change: '+1.24%',
      ),
      const _PairRow(pair: 'SOL / USDT', price: '\$182.54', change: '-0.61%'),
    ],
  );
}

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
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
            '社交',
            style: TextStyle(
              color: _white,
              fontSize: AcoTypography.headline,
              fontWeight: FontWeight.w700,
            ),
          ),
          _IconButton(
            icon: CupertinoIcons.person_add,
            onPressed: () => _showWalletSheet(context, '添加好友'),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _SegmentedTabs(
        labels: const ['消息', '联系人'],
        selected: _tab,
        onSelected: (value) => setState(() => _tab = value),
      ),
      const SizedBox(height: 10),
      if (_tab == 0) ...const [
        _ChatRow(
          image: 'assets/images/avatar_host.jpg',
          name: 'Aco 社区',
          preview: '欢迎加入 Aco，开始探索链上世界',
          time: '刚刚',
          unread: '3',
        ),
        _ChatRow(
          image: 'assets/images/avatar_builder.jpg',
          name: 'Builder',
          preview: '你的交易已确认',
          time: '09:41',
        ),
        _ChatRow(
          image: 'assets/images/avatar_orbit.jpg',
          name: 'Orbit',
          preview: '周末一起参加线上 Space？',
          time: '昨天',
        ),
      ] else ...const [
        _ContactRow(
          image: 'assets/images/avatar_host.jpg',
          name: 'Aco 社区',
          handle: '@aco_community',
        ),
        _ContactRow(
          image: 'assets/images/avatar_builder.jpg',
          name: 'Builder',
          handle: '@build_on_chain',
        ),
        _ContactRow(
          image: 'assets/images/avatar_orbit.jpg',
          name: 'Orbit',
          handle: '@orbit_eth',
        ),
      ],
    ],
  );
}
