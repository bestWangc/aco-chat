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

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    children: [
      Row(
        children: [
          const Icon(CupertinoIcons.line_horizontal_3, color: _white, size: 24),
          const Spacer(),
          _AssetIconButton(
            asset: 'assets/icons/source_scan.svg',
            size: 20,
            onPressed: () => _showScanSheet(context),
          ),
          const SizedBox(width: 11),
          _AssetIconButton(
            asset: 'assets/icons/source_person.svg',
            size: 20,
            onPressed: () => _showWalletSheet(context, '添加好友'),
          ),
        ],
      ),
      const SizedBox(height: 26),
      Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/default_avatar.png',
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _SocialSearch(
              onPressed: () => _showNotice(context, '搜索', '正在搜索消息。'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      for (var i = 0; i < 5; i++)
        const _DesignChatRow(
          name: '克里斯蒂亚诺',
          preview: '你好，股票账户已就位',
          date: '2026-08-05',
          unread: '14',
        ),
    ],
  );
}

class _SocialSearch extends StatelessWidget {
  const _SocialSearch({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      border: Border.all(color: _muted),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const SizedBox(width: 12),
        const Icon(CupertinoIcons.search, color: _white, size: 21),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '搜索帖文或消息',
            style: TextStyle(color: _muted, fontSize: AcoTypography.body),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Container(
            width: 58,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: const Icon(CupertinoIcons.add, color: _black, size: 24),
          ),
        ),
      ],
    ),
  );
}

class _DesignChatRow extends StatelessWidget {
  const _DesignChatRow({
    required this.name,
    required this.preview,
    required this.date,
    required this.unread,
  });
  final String name, preview, date, unread;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _white,
                  fontSize: AcoTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                preview,
                style: const TextStyle(
                  color: _muted,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _lime,
                shape: BoxShape.circle,
              ),
              child: Text(
                unread,
                style: const TextStyle(
                  color: _black,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              date,
              style: const TextStyle(
                color: _muted,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
