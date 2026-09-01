import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_session.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

part 'square_home_live.dart';
part 'square_wallet_explore.dart';
part 'square_dex_social.dart';

const _lime = Color(0xFFA1FF00);
const _surface = Color(0xFF151515);
const _surfaceRaised = Color(0xFF1D1D1D);
const _white = Color(0xFFF5F5F5);
const _black = Color(0xFF000000);
const _transparent = Color(0x00000000);
const _muted = Color(0xFF888888);
const _navInactive = Color(0xFFC4C4C4);
const _navLabels = ['钱包', '探索', 'DEX', '广场', '社交'];

void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
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
      backgroundColor: _black,
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

/* Tab pages live in square_wallet_explore.dart and square_dex_social.dart. */
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
                fontSize: AcoTypography.caption,
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
            style: const TextStyle(
              color: Color(0xFFD5D5D5),
              fontSize: AcoTypography.body,
            ),
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
        backgroundColor: outlined ? _transparent : _lime,
        foregroundColor: outlined ? _lime : _black,
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: outlined ? _lime : _black),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: outlined ? _lime : _black,
                fontSize: AcoTypography.bodySmall,
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
        Text(
          label,
          style: const TextStyle(
            color: _white,
            fontSize: AcoTypography.caption,
          ),
        ),
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
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(icon, color: _white, size: 25),
    ),
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
              fontSize: AcoTypography.bodySmall,
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
                  fontSize: AcoTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                amount,
                style: const TextStyle(
                  color: _muted,
                  fontSize: AcoTypography.caption,
                ),
              ),
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
                fontSize: AcoTypography.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              change,
              style: const TextStyle(
                color: _lime,
                fontSize: AcoTypography.caption,
              ),
            ),
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
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: _muted,
              fontSize: AcoTypography.caption,
            ),
          ),
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
                  fontSize: AcoTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: AcoTypography.caption,
                ),
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
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: AcoTypography.caption,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: controller == null
                  ? const Text(
                      '0.0',
                      style: TextStyle(
                        color: _white,
                        fontSize: AcoTypography.titleLarge,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : CupertinoTextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _dismissKeyboard(),
                      onTapOutside: (_) => _dismissKeyboard(),
                      placeholder: '0.0',
                      placeholderStyle: const TextStyle(
                        color: _white,
                        fontSize: AcoTypography.titleLarge,
                      ),
                      style: const TextStyle(
                        color: _white,
                        fontSize: AcoTypography.titleLarge,
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
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: _white,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          change,
          style: TextStyle(
            color: change.startsWith('-') ? const Color(0xFFFF6868) : _lime,
            fontSize: AcoTypography.caption,
          ),
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
                color: selected == i ? _lime : _transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: selected == i ? _black : _muted,
                  fontSize: AcoTypography.caption,
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
      child: Text(
        message,
        style: const TextStyle(
          color: _muted,
          fontSize: AcoTypography.bodySmall,
        ),
      ),
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
