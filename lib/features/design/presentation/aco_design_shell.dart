import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

const _lime = Color(0xFFA1FF00);
const _danger = Color(0xFFFF3B4E);
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _transparent = Color(0x00000000);
const _navLabels = ['钱包', '探索', 'DEX', '广场', '社交'];
const _navAssets = [
  'assets/icons/source_wallet.svg',
  'assets/icons/source_explore.svg',
  'assets/icons/source_dex.svg',
  'assets/icons/source_square.svg',
  'assets/icons/source_social.svg',
];

enum AcoScreen {
  walletHome,
  walletChains,
  assetDetail,
  receive,
  addTokenV1,
  addTokenV2,
  dexToken,
  dexSwap,
  browserDiscover,
  marketOverview,
  squareFeed,
  socialMessages,
  chatV1,
  chatV2,
  liveStream,
  voiceRoom,
  mining,
  profile,
}

class AcoDesignShell extends StatefulWidget {
  const AcoDesignShell({super.key});

  @override
  State<AcoDesignShell> createState() => _AcoDesignShellState();
}

class _AcoDesignShellState extends State<AcoDesignShell> {
  final ValueNotifier<bool> _isDark = ValueNotifier<bool>(true);
  int _selectedNav = 3;

  @override
  void dispose() {
    _isDark.dispose();
    super.dispose();
  }

  void _open(AcoScreen screen) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: _isDark,
          builder: (_, dark, _) => AcoScreenPage(
            screen: screen,
            dark: dark,
            isRoot: false,
            onOpen: _open,
            onThemeToggle: () => _isDark.value = !_isDark.value,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _isDark,
    builder: (_, dark, _) {
      final tabs = [
        AcoScreen.walletHome,
        AcoScreen.browserDiscover,
        AcoScreen.dexToken,
        AcoScreen.squareFeed,
        AcoScreen.socialMessages,
      ];
      return CupertinoPageScaffold(
        backgroundColor: AcoPalette(dark).background,
        child: _AcoViewport(
          child: SafeArea(
            left: false,
            right: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _selectedNav,
                    children: [
                      for (final page in tabs)
                        AcoScreenPage(
                          screen: page,
                          dark: dark,
                          isRoot: true,
                          onOpen: _open,
                          onThemeToggle: () => _isDark.value = !_isDark.value,
                        ),
                    ],
                  ),
                ),
                AcoBottomNav(
                  selected: _selectedNav,
                  dark: dark,
                  onSelected: (index) => setState(() => _selectedNav = index),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class AcoPalette {
  const AcoPalette(this.dark);
  final bool dark;

  Color get background => dark ? const Color(0xFF050505) : _white;
  Color get surface => dark ? const Color(0xFF181818) : const Color(0xFFF4F4F4);
  Color get surfaceRaised =>
      dark ? const Color(0xFF222222) : const Color(0xFFEDEDED);
  Color get primaryText =>
      dark ? const Color(0xFFF7F7F7) : const Color(0xFF151515);
  Color get mutedText =>
      dark ? const Color(0xFF929292) : const Color(0xFF939393);
  Color get border => dark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E2E2);
  Color get navInactive =>
      dark ? const Color(0xFF9E9E9E) : const Color(0xFF777777);
}

class AcoScreenPage extends StatelessWidget {
  const AcoScreenPage({
    required this.screen,
    required this.dark,
    required this.isRoot,
    required this.onOpen,
    required this.onThemeToggle,
    super.key,
  });

  final AcoScreen screen;
  final bool dark;
  final bool isRoot;
  final ValueChanged<AcoScreen> onOpen;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(dark);
    final page = switch (screen) {
      AcoScreen.walletHome => _WalletHome(palette: palette, onOpen: onOpen),
      AcoScreen.walletChains => _WalletChains(palette: palette, onOpen: onOpen),
      AcoScreen.assetDetail => _AssetDetail(palette: palette, onOpen: onOpen),
      AcoScreen.receive => _ReceivePage(palette: palette),
      AcoScreen.addTokenV1 => _AddTokenPage(palette: palette),
      AcoScreen.addTokenV2 => _AddTokenPage(palette: palette),
      AcoScreen.dexToken => _DexTokenPage(palette: palette, onOpen: onOpen),
      AcoScreen.dexSwap => _DexSwapPage(palette: palette),
      AcoScreen.browserDiscover => _BrowserDiscoverPage(
        palette: palette,
        onOpen: onOpen,
      ),
      AcoScreen.marketOverview => _MarketOverviewPage(palette: palette),
      AcoScreen.squareFeed => _SquareFeedPage(palette: palette, onOpen: onOpen),
      AcoScreen.socialMessages => _SocialMessagesPage(
        palette: palette,
        onOpen: onOpen,
      ),
      AcoScreen.chatV1 => _ChatPage(palette: palette, version: 1),
      AcoScreen.chatV2 => _ChatPage(palette: palette, version: 2),
      AcoScreen.liveStream => _LiveStreamPage(palette: palette, onOpen: onOpen),
      AcoScreen.voiceRoom => _VoiceRoomPage(palette: palette),
      AcoScreen.mining => _MiningPage(palette: palette),
      AcoScreen.profile => _ProfilePage(
        palette: palette,
        onThemeToggle: onThemeToggle,
        onOpen: onOpen,
      ),
    };

    return ColoredBox(
      color: palette.background,
      child: _AcoViewport(
        child: SafeArea(
          top: !isRoot,
          left: false,
          right: false,
          bottom: false,
          child: page,
        ),
      ),
    );
  }
}

class _AcoViewport extends StatelessWidget {
  const _AcoViewport({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: child,
  );
}

class AcoBottomNav extends StatelessWidget {
  const AcoBottomNav({
    required this.selected,
    required this.dark,
    required this.onSelected,
    super.key,
  });

  final int selected;
  final bool dark;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(dark);
    return SizedBox(
      // Keep the navigation footprint stable while positioning its visible
      // controls close to the bottom edge.
      height: 106,
      child: Transform.translate(
        offset: const Offset(0, 15),
        child: Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Row(
            children: List.generate(
              _navLabels.length,
              (index) => Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == index,
                  label: _navLabels[index],
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: () => onSelected(index),
                    child: _NavItem(
                      index: index,
                      active: selected == index,
                      palette: palette,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.active,
    required this.palette,
  });
  final int index;
  final bool active;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = active ? _lime : palette.navInactive;
    if (index == 2) {
      return SizedBox(
        width: 48,
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -8,
              left: -4,
              width: 55,
              height: 52,
              child: SvgPicture.asset(
                active
                    ? 'assets/icons/source_dex_active.svg'
                    : 'assets/icons/source_dex_inactive.svg',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: 48,
      height: 76,
      child: Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: SvgPicture.asset(
              _navAssets[index],
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 26,
            child: Text(
              _navLabels[index],
              maxLines: 1,
              style: TextStyle(color: color, fontSize: AcoTypography.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}

class AcoPageHeader extends StatelessWidget {
  const AcoPageHeader({
    required this.palette,
    this.title,
    this.onBack,
    this.right,
    super.key,
  });
  final AcoPalette palette;
  final String? title;
  final VoidCallback? onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: AcoIconButton(
              icon: CupertinoIcons.back,
              palette: palette,
              label: '返回',
              onPressed: onBack!,
            ),
          ),
        if (title != null)
          Text(
            title!,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodyEmphasis,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (right != null)
          Align(alignment: Alignment.centerRight, child: right!),
      ],
    ),
  );
}

class AcoIconButton extends StatelessWidget {
  const AcoIconButton({
    required this.icon,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.size = 25,
    super.key,
  });
  final IconData icon;
  final AcoPalette palette;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(icon, color: palette.primaryText, size: size),
    ),
  );
}

class AcoTopActions extends StatelessWidget {
  const AcoTopActions({required this.palette, required this.onOpen, super.key});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _AcoDesignActionButton(
        asset: 'assets/icons/source_scan.svg',
        palette: palette,
        label: '扫描二维码',
        onPressed: () => _showNotice(context, '扫码功能', '将打开二维码扫描器。'),
      ),
      const SizedBox(width: 12),
      _AcoDesignActionButton(
        asset: 'assets/icons/source_person.svg',
        palette: palette,
        label: '账户',
        onPressed: () => onOpen(AcoScreen.profile),
      ),
    ],
  );
}

class _AcoDesignActionButton extends StatelessWidget {
  const _AcoDesignActionButton({
    required this.asset,
    required this.palette,
    required this.label,
    required this.onPressed,
  });

  final String asset;
  final AcoPalette palette;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: SvgPicture.asset(
        asset,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          palette.dark ? const Color(0xFF737373) : palette.primaryText,
          BlendMode.srcIn,
        ),
      ),
    ),
  );
}

class AcoRootHeader extends StatelessWidget {
  const AcoRootHeader({
    required this.palette,
    required this.onOpen,
    this.title,
    this.trailing,
    this.onLeadingPressed,
    super.key,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onLeadingPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            label: onLeadingPressed == null ? '功能菜单' : '返回',
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed:
                  onLeadingPressed ??
                  () => _showNotice(context, '功能菜单', '功能菜单即将开放。'),
              child: const _MenuGlyph(),
            ),
          ),
        ),
        if (title != null)
          Text(
            title!,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: trailing ?? AcoTopActions(palette: palette, onOpen: onOpen),
        ),
      ],
    ),
  );
}

class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph();

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Icon(CupertinoIcons.line_horizontal_3_decrease, size: 27),
      Positioned(
        right: -3,
        top: -5,
        child: Icon(CupertinoIcons.sparkles, size: 11, color: _lime),
      ),
    ],
  );
}

class _TokenMark extends StatelessWidget {
  const _TokenMark();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF969DBE),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _NetworkGlyph extends StatelessWidget {
  const _NetworkGlyph({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/lucide/network.svg',
    width: 24,
    height: 24,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class AcoSurface extends StatelessWidget {
  const AcoSurface({
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.border = false,
    super.key,
  });
  final AcoPalette palette;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: border ? Border.all(color: palette.border) : null,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: shad.ShadCard(
      padding: padding,
      radius: BorderRadius.circular(radius),
      backgroundColor: palette.surface,
      child: child,
    ),
  );
}

class AcoLimeButton extends StatelessWidget {
  const AcoLimeButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.height,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height ?? (compact ? 36 : 42),
    child: shad.ShadButton(
      backgroundColor: _lime,
      foregroundColor: _black,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _black, size: 17),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

enum AcoSearchVariant { standard, squareComposer }

class AcoSearch extends StatelessWidget {
  const AcoSearch({
    required this.palette,
    required this.hint,
    this.onSubmit,
    this.action,
    this.height = 42,
    this.submitIcon = CupertinoIcons.arrow_right,
    this.variant = AcoSearchVariant.standard,
    super.key,
  });
  final AcoPalette palette;
  final String hint;
  final VoidCallback? onSubmit;
  final Widget? action;
  final double height;
  final IconData submitIcon;
  final AcoSearchVariant variant;

  @override
  Widget build(BuildContext context) {
    final isSquareComposer = variant == AcoSearchVariant.squareComposer;
    final submitWidth = isSquareComposer ? 52.0 : height;
    final borderColor = palette.dark ? const Color(0xFFC1C1C1) : palette.border;
    final iconColor = palette.dark
        ? (isSquareComposer ? const Color(0xFF191919) : const Color(0xFFF7F7F7))
        : palette.mutedText;
    final hintColor = palette.dark
        ? (isSquareComposer ? const Color(0xFFF2F2F2) : const Color(0xFF888888))
        : palette.mutedText;
    final submitChild = submitIcon == CupertinoIcons.add
        ? Center(
            child: SizedBox(
              width: isSquareComposer ? 20 : 32,
              height: isSquareComposer ? 20 : 32,
              child: Image.asset(
                'assets/icons/design_plus_dark.png',
                filterQuality: FilterQuality.high,
              ),
            ),
          )
        : Icon(submitIcon, color: _black, size: height > 48 ? 30 : 24);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            CupertinoIcons.search,
            color: iconColor,
            size: isSquareComposer ? 16 : 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(color: hintColor, fontSize: AcoTypography.body),
            ),
          ),
          ?action,
          if (onSubmit != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size(submitWidth, height),
              onPressed: onSubmit,
              child: Container(
                width: submitWidth,
                height: height,
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
                child: submitChild,
              ),
            ),
        ],
      ),
    );
  }
}

class AcoAvatar extends StatelessWidget {
  const AcoAvatar({this.large = false, this.size, super.key});
  final bool large;
  final double? size;
  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (large ? 76.0 : 42.0);
    return ClipOval(
      child: Image.asset(
        'assets/design_svg/source/images/img1.jpg',
        width: resolvedSize,
        height: resolvedSize,
        fit: BoxFit.cover,
        semanticLabel: 'Marry 的头像',
      ),
    );
  }
}

void _showNotice(BuildContext context, String title, String message) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => CupertinoActionSheet(
      title: Text(title),
      message: Text(message),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
    ),
  );
}

class _WalletHome extends StatelessWidget {
  const _WalletHome({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(51, 20, 51, 22),
    children: [
      AcoRootHeader(palette: palette, onOpen: onOpen),
      const SizedBox(height: 57),
      Row(
        children: [
          Icon(CupertinoIcons.creditcard, color: palette.mutedText, size: 18),
          const SizedBox(width: 8),
          Text(
            'Wallet1',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.bodyEmphasis,
            ),
          ),
          const Icon(CupertinoIcons.chevron_down, color: _lime, size: 15),
          const SizedBox(width: 22),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _lime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Sepolia',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.bodyEmphasis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 40),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'USD',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.bodyEmphasis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '39800.00',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.balance,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 70),
      Row(
        children: [
          Expanded(
            child: AcoLimeButton(
              label: '发送资产',
              icon: CupertinoIcons.arrow_up_right,
              height: 60,
              onPressed: () => onOpen(AcoScreen.walletChains),
            ),
          ),
          const SizedBox(width: 58),
          Expanded(
            child: _OutlineButton(
              label: '接收资产',
              icon: CupertinoIcons.arrow_down_left,
              palette: palette,
              height: 60,
              onPressed: () => onOpen(AcoScreen.receive),
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      Row(
        children: [
          Expanded(
            child: _OutlineButton(
              label: '闪兑',
              icon: CupertinoIcons.bolt_fill,
              palette: palette,
              height: 60,
              onPressed: () => onOpen(AcoScreen.dexSwap),
            ),
          ),
          const SizedBox(width: 58),
          Expanded(
            child: _OutlineButton(
              label: '扫码',
              icon: CupertinoIcons.qrcode_viewfinder,
              palette: palette,
              height: 60,
              onPressed: () => _showNotice(context, '扫码', '扫描地址或二维码。'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 84),
      _SectionTabs(
        palette: palette,
        labels: const ['资产', 'NFT', '最近活动'],
        selected: 0,
      ),
      const SizedBox(height: 17),
      _WalletAssetRow(
        palette: palette,
        symbol: 'ETH',
        title: 'Ethereum',
        amount: '12.308 ETH',
        value: '\$24,766.80',
        onTap: () => onOpen(AcoScreen.assetDetail),
      ),
      _WalletAssetRow(
        palette: palette,
        symbol: 'USDT',
        title: 'Tether USD',
        amount: '15,033.20 USDT',
        value: '\$15,033.20',
        onTap: () => onOpen(AcoScreen.assetDetail),
      ),
      const SizedBox(height: 10),
      AcoLimeButton(
        label: '添加代币',
        icon: CupertinoIcons.add,
        onPressed: () => onOpen(AcoScreen.addTokenV2),
      ),
    ],
  );
}

class _WalletChains extends StatelessWidget {
  const _WalletChains({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '钱包详情',
    child: ListView(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE1E4E8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Text(
              '币安智能链',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.headline,
              ),
            ),
            const Spacer(),
            const Icon(CupertinoIcons.add_circled, color: _lime),
          ],
        ),
        const SizedBox(height: 22),
        for (final chain in const ['BSC-1', 'BSC-2', 'BSC-3'])
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _TappableSurface(
              palette: palette,
              onTap: () => onOpen(AcoScreen.assetDetail),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: chain == 'BSC-1'
                          ? const Color(0xFF119B33)
                          : palette.surfaceRaised,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chain,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: AcoTypography.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TASDFSk...FAGSGS2324t',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.caption,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$ 7,123,456,789,778.00',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: AcoTypography.bodyEmphasis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, color: _lime),
                ],
              ),
            ),
          ),
        AcoLimeButton(
          label: '添加代币',
          icon: CupertinoIcons.add,
          onPressed: () => onOpen(AcoScreen.addTokenV1),
        ),
      ],
    ),
  );
}

class _AssetDetail extends StatelessWidget {
  const _AssetDetail({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '钱包详情',
    right: AcoIconButton(
      icon: CupertinoIcons.ellipsis,
      palette: palette,
      label: '更多操作',
      onPressed: () => onOpen(AcoScreen.receive),
    ),
    child: ListView(
      children: [
        AcoSurface(
          palette: palette,
          border: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AcoAvatar(size: 80),
                  const SizedBox(width: 24),
                  Text(
                    'GRANDVEAGS',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.displaySmall,
                    ),
                  ),
                  const Spacer(),
                  Icon(CupertinoIcons.pencil, color: palette.mutedText),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '钱包地址',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: AcoTypography.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'TASDSADSFsdadsads..1232421212gdgd',
                            style: TextStyle(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: AcoTypography.body,
                            ),
                          ),
                        ),
                        Icon(
                          CupertinoIcons.doc_on_doc,
                          color: palette.mutedText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AcoSurface(
          palette: palette,
          border: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '资产分布',
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: AcoTypography.bodyEmphasis,
                ),
              ),
              const SizedBox(height: 24),
              _ProgressRow(
                palette: palette,
                label: 'ETH',
                value: '62.4%',
                fraction: .624,
              ),
              const SizedBox(height: 13),
              _ProgressRow(
                palette: palette,
                label: 'USDT',
                value: '37.6%',
                fraction: .376,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AcoLimeButton(
          label: '挖矿中心',
          icon: CupertinoIcons.flame,
          onPressed: () => onOpen(AcoScreen.mining),
        ),
      ],
    ),
  );
}

class _ReceivePage extends StatelessWidget {
  const _ReceivePage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '收款',
    child: ListView(
      children: [
        const SizedBox(height: 116),
        Text(
          '仅向该地址转入BSC/BEP20相关资产',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
        const SizedBox(height: 76),
        CustomPaint(size: const Size(404, 404), painter: _QrPainter(palette)),
        const SizedBox(height: 30),
        Text(
          'TASDSADSFsdadsads..1232421212gdgd',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        AcoLimeButton(
          label: '复制地址',
          icon: CupertinoIcons.doc_on_doc,
          onPressed: () => _showNotice(context, '已复制', '钱包地址已复制到剪贴板。'),
        ),
      ],
    ),
  );
}

class _AddTokenPage extends StatelessWidget {
  const _AddTokenPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '添加代币',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AcoSearch(
          palette: palette,
          hint: '通过代币名称或合约进行搜索',
          onSubmit: () => _showNotice(context, '搜索', '已开始搜索代币。'),
          height: 60,
        ),
        const SizedBox(height: 54),
        for (final entry in const ['首页资产', '我的资产', '自定义代币', '热门代币'])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Row(
              children: [
                Text(
                  entry,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.headline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (entry == '我的资产') _CountPill(palette: palette, label: '47'),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: palette.mutedText,
                  size: 21,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _DexTokenPage extends StatelessWidget {
  const _DexTokenPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(51, 20, 51, 24),
    children: [
      AcoRootHeader(palette: palette, onOpen: onOpen, title: 'DEX'),
      const SizedBox(height: 44),
      _SectionTabs(
        palette: palette,
        labels: const ['闪兑', '代币', '合约'],
        selected: 1,
        onChanged: (index) {
          if (index == 0) onOpen(AcoScreen.dexSwap);
        },
      ),
      const SizedBox(height: 38),
      Row(
        children: [
          const _TokenMark(),
          const SizedBox(width: 10),
          Text(
            'ETH',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(CupertinoIcons.chevron_down, color: _lime, size: 15),
          const Spacer(),
          const Icon(CupertinoIcons.sparkles, color: _lime, size: 24),
          const SizedBox(width: 24),
          const _NetworkGlyph(color: _lime),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        '023sdS2..324d   4个月',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.caption,
        ),
      ),
      const SizedBox(height: 72),
      Row(
        children: [
          Text(
            'Today',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            '+2.34%',
            style: TextStyle(
              color: _lime,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'USD',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '39800.00',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.balance,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '市值   \$4M',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '流动性   1.6M USDT',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '24h交易额   \$11.6M',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 104),
      _TimeRangeSelector(palette: palette),
      const SizedBox(height: 38),
      AcoLimeButton(
        label: '前往闪兑',
        icon: CupertinoIcons.arrow_right_arrow_left,
        onPressed: () => onOpen(AcoScreen.dexSwap),
      ),
    ],
  );
}

class _DexSwapPage extends StatefulWidget {
  const _DexSwapPage({required this.palette});
  final AcoPalette palette;
  @override
  State<_DexSwapPage> createState() => _DexSwapPageState();
}

class _DexSwapPageState extends State<_DexSwapPage> {
  bool ethFirst = true;
  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(43, 20, 28, 28),
      children: [
        AcoRootHeader(
          palette: palette,
          onOpen: (_) {},
          title: 'DEX',
          onLeadingPressed: () => Navigator.of(context).maybePop(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcoIconButton(
                icon: CupertinoIcons.slider_horizontal_3,
                palette: palette,
                label: '筛选',
                onPressed: () {},
                size: 23,
              ),
              Text(
                '••',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodyEmphasis,
                ),
              ),
              const Icon(CupertinoIcons.sparkles, color: _lime, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 38),
        _SectionTabs(
          palette: palette,
          labels: const ['闪兑', '代币', '合约'],
          selected: 0,
        ),
        const SizedBox(height: 24),
        _SectionTabs(palette: palette, labels: const ['市价', '限价'], selected: 0),
        const SizedBox(height: 28),
        _SwapField(
          palette: palette,
          label: '兑换货币',
          symbol: ethFirst ? 'ETH' : 'USDT',
          value: '35.68',
        ),
        Center(
          child: AcoIconButton(
            icon: CupertinoIcons.arrow_down,
            palette: palette,
            label: '切换币种',
            onPressed: () => setState(() => ethFirst = !ethFirst),
            size: 22,
          ),
        ),
        _SwapField(
          palette: palette,
          label: '收到货币',
          symbol: ethFirst ? 'USDT' : 'ETH',
          value: '0.00',
        ),
        const SizedBox(height: 20),
        AcoLimeButton(
          label: '连接钱包',
          onPressed: () => _showNotice(context, '连接钱包', '请选择一个钱包继续交易。'),
        ),
        const SizedBox(height: 24),
        Text(
          '交易信息',
          style: TextStyle(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: AcoTypography.body,
          ),
        ),
        const SizedBox(height: 10),
        _InfoLine(palette: palette, label: '预计收到', value: '0.00 USDT'),
        _InfoLine(palette: palette, label: '滑点容差', value: '0.5%'),
      ],
    );
  }
}

class _BrowserDiscoverPage extends StatelessWidget {
  const _BrowserDiscoverPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(35, 20, 35, 24),
    children: [
      AcoPageHeader(
        palette: palette,
        title: '发现',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      const SizedBox(height: 28),
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
        children: const [
          _MarketIcon(icon: CupertinoIcons.chart_bar_alt_fill, label: '现货'),
          _MarketIcon(icon: CupertinoIcons.chart_pie_fill, label: '合约'),
          _MarketIcon(
            icon: CupertinoIcons.money_dollar_circle_fill,
            label: '股票',
          ),
          _MarketIcon(icon: CupertinoIcons.bolt_fill, label: '闪兑'),
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

class _SquareFeedPage extends StatefulWidget {
  const _SquareFeedPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_SquareFeedPage> createState() => _SquareFeedPageState();
}

class _LiveSession {
  const _LiveSession({required this.title, required this.host});

  final String title;
  final String host;
}

const _defaultLiveSession = _LiveSession(
  title: '美股凭什么依然能打？3节课带你从小白上手美股交易！',
  host: 'OKX中文',
);

class _SquareFeedPageState extends State<_SquareFeedPage> {
  bool _showLive = false;
  static const List<_LiveSession> _liveSessions = [
    _defaultLiveSession,
    _LiveSession(title: 'BTC 强势突破后，接下来应该关注哪些关键位置？', host: '链上观察员'),
    _LiveSession(title: 'AI Agent 热潮持续，哪些项目值得长期跟踪？', host: 'Web3 研究社'),
    _LiveSession(title: '从零搭建交易策略：风险控制与仓位管理实战', host: '交易员阿峰'),
  ];

  List<Widget> _buildLiveContent(AcoPalette palette) => [
    const SizedBox(height: 24),
    for (final session in _liveSessions) ...[
      _LiveCard(palette: palette, session: session),
      const SizedBox(height: 24),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final onOpen = widget.onOpen;

    return ListView(
      padding: const EdgeInsets.fromLTRB(35, 16, 35, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AcoTopActions(palette: palette, onOpen: onOpen),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const AcoAvatar(size: 42),
            const SizedBox(width: 16),
            Expanded(
              child: AcoSearch(
                palette: palette,
                hint: '搜索帖文或消息',
                height: 44,
                variant: AcoSearchVariant.squareComposer,
                submitIcon: CupertinoIcons.add,
                onSubmit: () => _showNotice(context, '发布', '打开帖子编辑器。'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '推荐',
              style: TextStyle(
                color: _showLive ? palette.mutedText : palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
                fontWeight: _showLive ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
            const SizedBox(width: 40),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  '好友',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
                  ),
                ),
                const Positioned(
                  top: -10,
                  right: -24,
                  child: _GreenBadge(label: '77'),
                ),
              ],
            ),
            const SizedBox(width: 40),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _showLive = true),
              child: Text(
                '直播',
                style: TextStyle(
                  color: _showLive ? palette.primaryText : palette.mutedText,
                  fontSize: AcoTypography.bodyEmphasis,
                  fontWeight: _showLive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: palette.border),
        if (_showLive)
          ..._buildLiveContent(palette)
        else ...[
          const SizedBox(height: 32),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TopicChip(palette: palette, label: '买买买!!', width: 164),
                const SizedBox(width: 10),
                _TopicChip(palette: palette, label: 'ALD! V587!', width: 184),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _PostCard(palette: palette),
        ],
      ],
    );
  }
}

class _SocialMessagesPage extends StatelessWidget {
  const _SocialMessagesPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(35, 20, 35, 24),
    children: [
      AcoRootHeader(palette: palette, onOpen: onOpen),
      const SizedBox(height: 34),
      Row(
        children: [
          const AcoAvatar(size: 64),
          const SizedBox(width: 20),
          Expanded(
            child: AcoSearch(
              palette: palette,
              hint: '搜索帖文或消息',
              height: 60,
              submitIcon: CupertinoIcons.add,
              onSubmit: () => _showNotice(context, '搜索', '正在搜索消息。'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 52),
      for (final name in const ['克里斯蒂亚诺', 'Aco 社区', 'Builder'])
        _MessageRow(
          palette: palette,
          name: name,
          onTap: () =>
              onOpen(name == 'Builder' ? AcoScreen.chatV2 : AcoScreen.chatV1),
        ),
    ],
  );
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({required this.palette, required this.version});
  final AcoPalette palette;
  final int version;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '添加代币',
    child: Column(
      children: [
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Bubble(
                palette: palette,
                text: version == 1
                    ? '我想看下怎么可以买呢，有点难度的，你说是不是'
                    : '我想看下怎么可以卖呢，交易在哪儿操作？',
                mine: true,
              ),
              const SizedBox(width: 12),
              const AcoAvatar(size: 48),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'A',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.displaySmall,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _Bubble(
                palette: palette,
                text: '等发你个教程具体看下操作，说也说不清楚还是图文比较好操作',
                mine: false,
              ),
            ],
          ),
        ),
        const Spacer(),
        AcoSearch(
          palette: palette,
          hint: '发送消息',
          height: 60,
          submitIcon: CupertinoIcons.arrow_up,
          onSubmit: () => _showNotice(context, '消息已发送', '已发送至对方。'),
        ),
      ],
    ),
  );
}

class _LiveStreamPage extends StatelessWidget {
  const _LiveStreamPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '正在直播',
    right: AcoTopActions(palette: palette, onOpen: onOpen),
    child: ListView(
      children: [
        _LiveCard(palette: palette),
        const SizedBox(height: 28),
        _LiveCard(palette: palette),
        const SizedBox(height: 24),
        AcoLimeButton(
          label: '进入语音房',
          icon: CupertinoIcons.mic_fill,
          onPressed: () => onOpen(AcoScreen.voiceRoom),
        ),
      ],
    ),
  );
}

class _VoiceRoomPage extends StatelessWidget {
  const _VoiceRoomPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    child: ListView(
      children: [
        const SizedBox(height: 205),
        ClipOval(
          child: Image.asset(
            'assets/design_svg/source/images/img3.jpg',
            width: 140,
            height: 140,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Jason',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '主持人',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
        const SizedBox(height: 82),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final entry in const [
              ('img3.jpg', true),
              ('img4.jpg', false),
              ('img5.jpg', false),
              ('img3.jpg', false),
            ])
              _MicSeat(
                palette: palette,
                asset: 'assets/design_svg/source/images/${entry.$1}',
                active: entry.$2,
              ),
          ],
        ),
        const SizedBox(height: 38),
        AcoLimeButton(
          label: '申请上麦',
          icon: CupertinoIcons.mic,
          onPressed: () => _showNotice(context, '申请已发送', '等待主持人同意。'),
        ),
      ],
    ),
  );
}

class _MiningPage extends StatelessWidget {
  const _MiningPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '挖矿',
    right: AcoIconButton(
      icon: CupertinoIcons.bell,
      palette: palette,
      label: '挖矿通知',
      onPressed: () {},
    ),
    child: ListView(
      children: [
        AcoSurface(
          palette: palette,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Text(
            '质押仅支持Donmi Chain，请在钱包中手动切换后继续。',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.60,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.flame,
              label: '挖矿状态',
              value: '已激活',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.chart_bar,
              label: '年化收益率',
              value: '10%',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.creditcard,
              label: '已质押',
              value: '100DMT',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.hand_raised,
              label: '待领取',
              value: '100DMT',
            ),
          ],
        ),
        const SizedBox(height: 22),
        AcoLimeButton(
          label: '领取收益',
          onPressed: () => _showNotice(context, '领取成功', '100DMT 已进入钱包。'),
        ),
      ],
    ),
  );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.palette,
    required this.onThemeToggle,
    required this.onOpen,
  });
  final AcoPalette palette;
  final VoidCallback onThemeToggle;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(35, 70, 35, 24),
    children: [
      Row(
        children: [
          const AcoAvatar(size: 114),
          const SizedBox(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marry',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.metric,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'UID:213214214321',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    _VipBadge(color: _lime),
                    SizedBox(width: 8),
                    _VipBadge(color: _danger),
                  ],
                ),
              ],
            ),
          ),
          AcoIconButton(
            icon: CupertinoIcons.qrcode_viewfinder,
            palette: palette,
            label: '切换深浅主题',
            onPressed: onThemeToggle,
          ),
        ],
      ),
      const SizedBox(height: 52),
      AcoSurface(
        palette: palette,
        radius: 40,
        padding: const EdgeInsets.fromLTRB(28, 38, 28, 42),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '个人主页',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.displaySmall,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final data in const [
                  ('hand.thumbsup', '3.2k', '我的点赞'),
                  ('heart', '128', '粉丝'),
                  ('sparkles', '15m', '获赞'),
                  ('bell', '78', '我的订阅'),
                ])
                  _ProfileMetric(
                    palette: palette,
                    icon: data.$1,
                    value: data.$2,
                    label: data.$3,
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.palette,
    required this.child,
    this.title,
    this.right,
  });
  final AcoPalette palette;
  final Widget child;
  final String? title;
  final Widget? right;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 4, 28, 22),
    child: Column(
      children: [
        AcoPageHeader(
          palette: palette,
          title: title,
          right: right,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onPressed,
    this.height = 42,
  });
  final String label;
  final IconData icon;
  final AcoPalette palette;
  final VoidCallback onPressed;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.primaryText, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.palette,
    required this.labels,
    required this.selected,
    this.onChanged,
  });
  final AcoPalette palette;
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 23),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: onChanged == null ? null : () => onChanged!(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == selected ? _lime : _transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected ? _black : palette.mutedText,
                      fontWeight: i == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: AcoTypography.body,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i == selected ? _lime : _transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.palette});
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (final range in const ['1H', '1D', '1W', '1M', '1Y', 'ALL'])
        Container(
          constraints: const BoxConstraints(minWidth: 36),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: range == '1D' ? palette.surfaceRaised : _transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            range,
            style: TextStyle(
              color: range == '1D' ? palette.primaryText : palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
          ),
        ),
      Icon(
        CupertinoIcons.slider_horizontal_3,
        color: palette.mutedText,
        size: 21,
      ),
    ],
  );
}

class _WalletAssetRow extends StatelessWidget {
  const _WalletAssetRow({
    required this.palette,
    required this.symbol,
    required this.title,
    required this.amount,
    required this.value,
    required this.onTap,
  });
  final AcoPalette palette;
  final String symbol, title, amount, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 10),
    onPressed: onTap,
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: symbol == 'ETH'
                ? const Color(0xFF969DBE)
                : const Color(0xFF23A46C),
            shape: BoxShape.circle,
          ),
          child: Text(
            symbol.substring(0, 1),
            style: const TextStyle(color: _white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: AcoTypography.body,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                amount,
                style: TextStyle(
                  color: palette.mutedText,
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
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              '+2.34%',
              style: TextStyle(color: _lime, fontSize: AcoTypography.caption),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TappableSurface extends StatelessWidget {
  const _TappableSurface({
    required this.palette,
    required this.child,
    required this.onTap,
  });
  final AcoPalette palette;
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: AcoSurface(palette: palette, border: true, child: child),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.fraction,
  });
  final AcoPalette palette;
  final String label, value;
  final double fraction;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(label, style: TextStyle(color: palette.primaryText)),
          const Spacer(),
          Text(value, style: TextStyle(color: palette.mutedText)),
        ],
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 7,
          child: ColoredBox(
            color: palette.surfaceRaised,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0, 1),
              child: const ColoredBox(color: _lime),
            ),
          ),
        ),
      ),
    ],
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.palette, required this.label});
  final AcoPalette palette;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
    child: Text(
      label,
      style: const TextStyle(
        color: _black,
        fontSize: AcoTypography.caption,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SwapField extends StatelessWidget {
  const _SwapField({
    required this.palette,
    required this.label,
    required this.symbol,
    required this.value,
  });
  final AcoPalette palette;
  final String label, symbol, value;
  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    border: true,
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: AcoTypography.headline,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                symbol,
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            const Spacer(),
            Text(
              '余额: 0.00',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Max',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.palette,
    required this.label,
    required this.value,
  });
  final AcoPalette palette;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _DiscoverShortcut extends StatelessWidget {
  const _DiscoverShortcut({
    required this.palette,
    required this.label,
    required this.onTap,
  });
  final AcoPalette palette;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final Color background;
    switch (label) {
      case '链上数据':
        background = const Color(0xFF3566D6);
        break;
      case 'NFT 市场':
        background = _black;
        break;
      case '交易工具':
        background = palette.surfaceRaised;
        break;
      default:
        background = const Color(0xFFEB2535);
    }

    return SizedBox(
      width: 108,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(CupertinoIcons.app_badge, color: _white),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketIcon extends StatelessWidget {
  const _MarketIcon({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFF222222),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _white),
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
  const _GreenBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
    child: Text(
      label,
      style: const TextStyle(
        color: _black,
        fontSize: AcoTypography.caption,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.palette,
    required this.label,
    required this.width,
  });
  final AcoPalette palette;
  final String label;
  final double width;
  @override
  Widget build(BuildContext context) {
    final isAldTopic = label == 'ALD! V587!';
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: palette.dark ? const Color(0xFF4A4A4A) : palette.border,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          if (isAldTopic)
            ClipOval(
              child: Image.asset(
                'assets/design_svg/source/images/img5.jpg',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4A4A4A)),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_rectangle,
                color: _lime,
                size: 22,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _lime,
                fontSize: AcoTypography.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 10),
            child: _SignalGlyph(),
          ),
        ],
      ),
    );
  }
}

class _SignalGlyph extends StatelessWidget {
  const _SignalGlyph();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final height in [10.0, 16.0, 12.0])
        Container(
          width: 6,
          height: height,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ],
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/design_svg/source/images/img3.jpg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '素素姐',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.bodyEmphasis,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: _lime,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '7小时前',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '365天盈利榜第1名',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PostOptionDot(color: palette.primaryText),
                const SizedBox(width: 6),
                _PostOptionDot(color: palette.primaryText),
                const SizedBox(width: 8),
                const _PostOptionStar(),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '是非成败转头空，青山依旧在，惯看秋月春风。\n'
        '一壶浊酒喜相逢，古今多少事，滚滚长江东逝\n'
        '水，浪花淘尽英雄。几度夕阳红。白发渔樵江渚\n'
        '上，都付笑谈中。\n'
        '滚滚长江东逝水，浪花淘尽英雄。是非成败转头\n'
        '空，青山依旧在，几度夕阳红。白发渔樵江渚\n'
        '上，惯看秋月春风。一壶浊酒喜相逢，古今多少\n'
        '事，都付笑谈中。',
        style: TextStyle(
          color: palette.primaryText,
          height: 1.5,
          fontSize: AcoTypography.bodySmall,
        ),
      ),
      const SizedBox(height: 24),
      Container(
        height: 273,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PostAction(
            icon: CupertinoIcons.chat_bubble,
            label: '63',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.arrow_2_squarepath,
            label: '1',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.heart,
            label: '88',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.chart_bar,
            label: '12.64k',
            palette: palette,
          ),
          _PostAction(icon: CupertinoIcons.share, label: '', palette: palette),
        ],
      ),
    ],
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.palette,
  });
  final IconData icon;
  final String label;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: palette.primaryText, size: 22),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
          ),
        ),
      ],
    ],
  );
}

class _PostOptionDot extends StatelessWidget {
  const _PostOptionDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _PostOptionStar extends StatelessWidget {
  const _PostOptionStar();

  @override
  Widget build(BuildContext context) =>
      const Icon(CupertinoIcons.sparkles, color: _lime, size: 10);
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.palette,
    required this.name,
    required this.onTap,
  });
  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 12),
    onPressed: onTap,
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '你好，股票账户已就位',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _GreenBadge(label: '14'),
            const SizedBox(height: 5),
            Text(
              '2026-08-05',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.palette,
    required this.text,
    required this.mine,
  });
  final AcoPalette palette;
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 390),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: mine ? _lime : palette.surfaceRaised,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: mine ? _black : palette.primaryText,
        height: 1.4,
        fontSize: AcoTypography.bodyEmphasis,
      ),
    ),
  );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.palette, this.session = _defaultLiveSession});
  final AcoPalette palette;
  final _LiveSession session;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            palette.dark
                ? 'assets/icons/live_brand_dark.png'
                : 'assets/icons/live_brand_light.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.host,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      AcoSurface(
        palette: palette,
        radius: 22,
        padding: EdgeInsets.zero,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    ],
  );
}

class _MicSeat extends StatelessWidget {
  const _MicSeat({
    required this.palette,
    required this.asset,
    required this.active,
  });
  final AcoPalette palette;
  final String asset;
  final bool active;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.asset(asset, width: 80, height: 80, fit: BoxFit.cover),
          ),
          if (active)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.mic_fill,
                  color: _black,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        active ? 'Jason' : '等待上麦',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.caption,
        ),
      ),
    ],
  );
}

class _MiningTile extends StatelessWidget {
  const _MiningTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
  });
  final AcoPalette palette;
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.primaryText, size: 30),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.headline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 66,
    height: 27,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'Vip',
      style: TextStyle(
        color: _black,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.palette,
    required this.icon,
    required this.value,
    required this.label,
  });
  final AcoPalette palette;
  final String icon, value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(
        icon == 'heart'
            ? CupertinoIcons.heart
            : icon == 'sparkles'
            ? CupertinoIcons.sparkles
            : icon == 'bell'
            ? CupertinoIcons.bell
            : CupertinoIcons.hand_thumbsup,
        color: palette.primaryText,
        size: 27,
      ),
      const SizedBox(height: 10),
      Text(
        value,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.body,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.caption,
        ),
      ),
    ],
  );
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.palette);
  final AcoPalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    final square = size.width / 25;
    final paint = Paint()..color = palette.primaryText;
    for (var y = 0; y < 25; y++) {
      for (var x = 0; x < 25; x++) {
        final finder =
            (x < 7 && y < 7) || (x > 17 && y < 7) || (x < 7 && y > 17);
        if (finder || ((x * 17 + y * 11 + x * y) % 7 < 3)) {
          canvas.drawRect(
            Rect.fromLTWH(x * square, y * square, square, square),
            paint,
          );
        }
      }
    }
    final center = Paint()..color = const Color(0xFF23A46C);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 15, center);
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.palette.dark != palette.dark;
}
