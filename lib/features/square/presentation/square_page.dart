import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircleAvatar, Colors;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

const _lime = Color(0xFFA1FF00);
const _surface = Color(0xFF151515);
const _surfaceRaised = Color(0xFF1D1D1D);
const _white = Color(0xFFF5F5F5);
const _muted = Color(0xFF888888);
const _navInactive = Color(0xFFC4C4C4);
const _navLabels = ['钱包', '探索', 'DEX', '广场', '社交'];
const _navAssets = [
  'assets/icons/source_wallet.svg',
  'assets/icons/source_explore.svg',
  'assets/icons/source_dex.svg',
  'assets/icons/source_square.svg',
  'assets/icons/source_social.svg',
];

/// The mobile shell used by every top-level screen.  Its controls are small,
/// composable primitives with shadcn-style tokens (surface, border, accent).
class SquarePage extends StatefulWidget {
  const SquarePage({super.key});

  @override
  State<SquarePage> createState() => _SquarePageState();
}

class _SquarePageState extends State<SquarePage> {
  int _selectedNav = 3;
  late final List<Widget> _pages = [
    const WalletPage(),
    const ExplorePage(),
    const DexPage(),
    SquareHome(onLive: _openLive),
    const SocialPage(),
  ];

  void _openLive() => Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => LivePage(
        onNav: (value) {
          Navigator.of(context).pop();
          setState(() => _selectedNav = value);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(index: _selectedNav, children: _pages),
            ),
            BottomNav(
              selected: _selectedNav,
              onSelected: (v) => setState(() => _selectedNav = v),
            ),
          ],
        ),
      ),
    );
  }
}

class SquareHome extends StatelessWidget {
  const SquareHome({required this.onLive, super.key});
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
    children: [
      const _TopActions(),
      const SizedBox(height: 22),
      Row(
        children: [
          Transform.translate(
            offset: const Offset(0, -1),
            child: const CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/images/avatar_design.png'),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: AcoInput(
              hint: '搜索帖文或消息',
              trailing: const Icon(
                CupertinoIcons.add,
                color: Colors.black,
                size: 21,
              ),
              onTrailingTap: () => _showComposer(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Transform.translate(
        offset: const Offset(1, 0),
        child: _SquareTabs(onLive: onLive),
      ),
      const SizedBox(height: 700),
    ],
  );
}

class LivePage extends StatelessWidget {
  const LivePage({this.onNav, super.key});
  final ValueChanged<int>? onNav;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: Colors.black,
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _IconButton(
                      icon: CupertinoIcons.back,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const _TopActions(),
                  ],
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    '正在直播',
                    style: TextStyle(
                      color: _white,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _LiveItem(),
                const SizedBox(height: 38),
                const _LiveItem(),
              ],
            ),
          ),
          BottomNav(
            selected: 3,
            onSelected: (value) {
              if (value != 3) {
                onNav?.call(value);
                if (onNav == null) Navigator.of(context).maybePop();
              }
            },
          ),
        ],
      ),
    ),
  );
}

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
              fontSize: 21,
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
              style: TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              _hidden ? '••••••' : '\$12,854.30',
              style: const TextStyle(
                color: _white,
                fontSize: 30,
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
        onSelected: (v) => setState(() => _tab = v),
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
          fontSize: 25,
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
          fontSize: 17,
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
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      _FeatureRow(
        image: 'assets/images/post_chain.jpg',
        title: '链上世界的新秩序',
        subtitle: '深入理解去中心化基础设施',
      ),
      _FeatureRow(
        image: 'assets/images/post_token.jpg',
        title: '代币经济学入门',
        subtitle: '读懂每一次市场波动',
      ),
    ],
  );
}

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
              fontSize: 25,
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
          fontSize: 16,
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
              fontSize: 25,
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
        onSelected: (v) => setState(() => _tab = v),
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

class _TopActions extends StatelessWidget {
  const _TopActions();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.only(right: 36),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AssetIconButton(
            asset: 'assets/icons/source_scan.svg',
            size: 20,
            onPressed: () => _showScanSheet(context),
          ),
          const SizedBox(width: 11),
          _AssetIconButton(
            asset: 'assets/icons/source_person.svg',
            size: 20,
            onPressed: () => _showWalletSheet(context, '账户'),
          ),
        ],
      ),
    ),
  );
}

class _AssetIconButton extends StatelessWidget {
  const _AssetIconButton({
    required this.asset,
    required this.size,
    required this.onPressed,
  });
  final String asset;
  final double size;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size(size, size),
    onPressed: onPressed,
    child: SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(_white, BlendMode.srcIn),
    ),
  );
}

class BottomNav extends StatelessWidget {
  const BottomNav({
    required this.selected,
    required this.onSelected,
    super.key,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 97,
      child: Padding(
        padding: const EdgeInsets.only(top: 39),
        child: Row(
          children: List.generate(
            _navLabels.length,
            (index) => Expanded(
              child: _BottomNavItem(
                index: index,
                active: selected == index,
                onTap: () => onSelected(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.index,
    required this.active,
    required this.onTap,
  });

  final int index;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = index == 2
        ? _DexNavIcon(active: active)
        : SvgPicture.asset(
            _navAssets[index],
            width: 24,
            height: 27,
            colorFilter: ColorFilter.mode(
              active ? _lime : _navInactive,
              BlendMode.srcIn,
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          icon,
          if (index != 2) ...[
            const SizedBox(height: 2),
            Text(
              _navLabels[index],
              style: TextStyle(
                color: active ? _lime : _navInactive,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DexNavIcon extends StatelessWidget {
  const _DexNavIcon({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 58,
    child: Center(
      child: Transform.translate(
        offset: const Offset(0, -17),
        child: SvgPicture.asset(
          active
              ? 'assets/icons/source_dex_active.svg'
              : 'assets/icons/source_dex_inactive.svg',
          // The selected solid mark is intentionally smaller in the source UI.
          width: active ? 50 : 54,
          height: active ? 43 : 46,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

class AcoInput extends StatelessWidget {
  const AcoInput({
    required this.hint,
    this.leading,
    this.trailing,
    this.onTrailingTap,
    super.key,
  });
  final String hint;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  @override
  Widget build(BuildContext context) => Container(
    height: 39,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFCACACA), width: 1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const SizedBox(width: 12),
        leading ??
            const Icon(
              CupertinoIcons.search,
              color: Color(0xFF8A8A8A),
              size: 20,
            ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            hint,
            style: const TextStyle(color: Color(0xFFD5D5D5), fontSize: 15),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Container(
              width: 45,
              height: 37,
              decoration: const BoxDecoration(
                color: _lime,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: trailing,
            ),
          ),
      ],
    ),
  );
}

class AcoCard extends StatelessWidget {
  const AcoCard({
    required this.child,
    this.padding = const EdgeInsets.all(13),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => shad.ShadCard(
    padding: padding,
    backgroundColor: _surface,
    radius: BorderRadius.circular(20),
    child: child,
  );
}

class AcoButton extends StatelessWidget {
  const AcoButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool outlined;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: outlined ? Border.all(color: _lime) : null,
      ),
      child: shad.ShadButton(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: outlined ? Colors.transparent : _lime,
        foregroundColor: outlined ? _lime : Colors.black,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: outlined ? _lime : Colors.black),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: outlined ? _lime : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AcoBadge extends StatelessWidget {
  const AcoBadge({required this.label, this.icon, super.key});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => shad.ShadBadge.outline(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    backgroundColor: _surface,
    foregroundColor: _white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: _white, fontSize: 11)),
        if (icon != null) ...[
          const SizedBox(width: 4),
          Icon(icon, color: _muted, size: 13),
        ],
      ],
    ),
  );
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(29, 29),
    onPressed: onPressed,
    child: Icon(icon, color: _white, size: 27),
  );
}

class _SquareTabs extends StatelessWidget {
  const _SquareTabs({required this.onLive});
  final VoidCallback onLive;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(
        width: 50,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '推荐',
              style: TextStyle(
                color: _white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 8),
            _DownMark(),
          ],
        ),
      ),
      const SizedBox(width: 45),
      const SizedBox(
        width: 68,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('好友', style: TextStyle(color: _muted, fontSize: 16)),
            SizedBox(width: 4),
            _CountBadge(),
          ],
        ),
      ),
      const SizedBox(width: 26),
      GestureDetector(
        onTap: onLive,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 34,
          child: Text('直播', style: TextStyle(color: _muted, fontSize: 16)),
        ),
      ),
    ],
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge();
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(1, 1),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _lime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '77',
        style: TextStyle(color: Colors.black, fontSize: 10),
      ),
    ),
  );
}

class _DownMark extends StatelessWidget {
  const _DownMark();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(10, 7), painter: _DownMarkPainter());
}

class _DownMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = _lime);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LiveItem extends StatelessWidget {
  const _LiveItem();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          SvgPicture.asset(
            'assets/icons/source_live_brand.svg',
            width: 46,
            height: 46,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '美股凭什么依然能打？3节课带你从小白\n上手美股交易！',
                  style: TextStyle(
                    color: _white,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      'OKX中文',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: _lime,
                      size: 19,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        height: 155,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    ],
  );
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.symbol,
    required this.name,
    required this.amount,
    required this.value,
    required this.change,
  });
  final String symbol, name, amount, value, change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _surfaceRaised,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            symbol.substring(0, 1),
            style: const TextStyle(
              color: _lime,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(amount, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(change, style: const TextStyle(color: _lime, fontSize: 11)),
          ],
        ),
      ],
    ),
  );
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AcoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _lime, size: 25),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: _white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.image,
    required this.title,
    required this.subtitle,
  });
  final String image, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(image, width: 70, height: 54, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TokenInput extends StatelessWidget {
  const _TokenInput({
    required this.label,
    required this.symbol,
    this.controller,
  });
  final String label, symbol;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
    decoration: BoxDecoration(
      color: _surfaceRaised,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: controller == null
                  ? const Text(
                      '0.0',
                      style: TextStyle(
                        color: _white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : CupertinoTextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      placeholder: '0.0',
                      placeholderStyle: const TextStyle(
                        color: _white,
                        fontSize: 22,
                      ),
                      style: const TextStyle(
                        color: _white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: null,
                    ),
            ),
            AcoBadge(label: symbol),
          ],
        ),
      ],
    ),
  );
}

class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.pair,
    required this.price,
    required this.change,
  });
  final String pair, price, change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            pair,
            style: const TextStyle(
              color: _white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(price, style: const TextStyle(color: _white, fontSize: 13)),
        const SizedBox(width: 10),
        Text(
          change,
          style: TextStyle(
            color: change.startsWith('-') ? const Color(0xFFFF6868) : _lime,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.image,
    required this.name,
    required this.preview,
    required this.time,
    this.unread,
  });
  final String image, name, preview, time;
  final String? unread;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        ClipOval(
          child: Image.asset(image, width: 40, height: 40, fit: BoxFit.cover),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time, style: const TextStyle(color: _muted, fontSize: 10)),
            if (unread != null) ...[
              const SizedBox(height: 4),
              Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _lime,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread!,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.image,
    required this.name,
    required this.handle,
  });
  final String image, name, handle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        ClipOval(
          child: Image.asset(image, width: 40, height: 40, fit: BoxFit.cover),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(handle, style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
        AcoButton(
          label: '聊天',
          icon: CupertinoIcons.chat_bubble,
          onPressed: () => _showChatSheet(context, name),
        ),
      ],
    ),
  );
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected == i ? _lime : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: selected == i ? Colors.black : _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 90),
    child: Center(
      child: Text(message, style: const TextStyle(color: _muted, fontSize: 14)),
    ),
  );
}

void _showComposer(BuildContext context) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) => CupertinoActionSheet(
    title: const Text('创建内容'),
    actions: [
      CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('发布帖子'),
      ),
      CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
          Navigator.of(
            context,
          ).push<void>(CupertinoPageRoute(builder: (_) => const LivePage()));
        },
        child: const Text('开启直播'),
      ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(context),
      child: const Text('取消'),
    ),
  ),
);

void _showScanSheet(BuildContext context) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) => CupertinoActionSheet(
    title: const Text('扫描'),
    message: const Text('扫描二维码以连接钱包或查看地址'),
    actions: [
      CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('打开相机'),
      ),
      CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('从相册选择'),
      ),
    ],
    cancelButton: CupertinoActionSheetAction(
      onPressed: () => Navigator.pop(context),
      child: const Text('取消'),
    ),
  ),
);

void _showFeatureSheet(BuildContext context, String title) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(title),
        message: const Text('功能即将开放，先收藏这个入口'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );

void _showChatSheet(BuildContext context, String name) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text('与 $name 聊天'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('发送消息'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );

void _showWalletSheet(BuildContext context, String title) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('钱包 1 · 0x71...A92F'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('钱包 2 · 0xE3...4D10'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
