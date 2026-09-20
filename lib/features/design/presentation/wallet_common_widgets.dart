part of 'aco_design_shell.dart';

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.palette,
    required this.child,
    this.title,
    this.titleWidget,
    this.right,
    this.onBack,
    this.titleFollowsBack = false,
    this.headerTopPadding = 0,
    this.headerRightPadding = 28,
    this.titleFontSize = AcoTypography.bodyEmphasis,
  });
  final AcoPalette palette;
  final Widget child;
  final String? title;
  final Widget? titleWidget;
  final Widget? right;
  final VoidCallback? onBack;
  final bool titleFollowsBack;
  final double headerTopPadding;
  final double headerRightPadding;
  final double titleFontSize;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          8,
          headerTopPadding,
          headerRightPadding,
          0,
        ),
        child: AcoPageHeader(
          palette: palette,
          title: title,
          titleWidget: titleWidget,
          right: right,
          titleFollowsBack: titleFollowsBack,
          titleFontSize: titleFontSize,
          backButtonOffset: Offset.zero,
          onBack: onBack ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

class _WalletMenuItem extends StatelessWidget {
  const _WalletMenuItem({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final AcoPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onPressed != null,
    enabled: onPressed != null,
    label: label,
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size.fromHeight(42),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, color: palette.primaryText, size: 17),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.palette,
    required this.onPressed,
    this.icon,
    this.height = 42,
    this.fontSize = AcoTypography.bodySmall,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.radius = 8,
    this.fontWeight = FontWeight.w600,
    this.leadingAsset,
    this.leadingImageAsset,
    this.iconSize = 16,
    this.iconGap = 6,
  });
  final String label;
  final IconData? icon;
  final AcoPalette palette;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final FontWeight fontWeight;
  final String? leadingAsset;
  final String? leadingImageAsset;
  final double iconSize;
  final double iconGap;
  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? palette.primaryText;
    final hasLeading =
        leadingAsset != null || leadingImageAsset != null || icon != null;
    return SizedBox(
      height: height,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? palette.surface,
            borderRadius: BorderRadius.circular(radius),
            border: borderWidth > 0
                ? Border.all(
                    color: borderColor ?? palette.border,
                    width: borderWidth,
                  )
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingAsset != null)
                  SvgPicture.asset(
                    leadingAsset!,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                  )
                else if (leadingImageAsset != null)
                  Image.asset(
                    leadingImageAsset!,
                    width: iconSize,
                    height: iconSize,
                  )
                else if (icon != null)
                  Icon(icon, color: foreground, size: iconSize),
                if (hasLeading) SizedBox(width: iconGap),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletTabs extends StatelessWidget {
  const _WalletTabs({
    required this.selected,
    required this.onChanged,
    required this.addButtonLink,
    required this.onAddToken,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final LayerLink addButtonLink;
  final VoidCallback onAddToken;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            _WalletTab(
              label: '资产',
              selected: selected == 0,
              onPressed: () => onChanged(0),
            ),
            const SizedBox(width: 22),
            _WalletTab(label: 'NFT', selected: selected == 1, onPressed: null),
          ],
        ),
      ),
      Semantics(
        button: true,
        label: '添加代币',
        child: Transform.translate(
          offset: const Offset(0, -5.5),
          child: CompositedTransformTarget(
            link: addButtonLink,
            child: CupertinoButton(
              key: const Key('add-token-button'),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onAddToken,
              child: SvgPicture.asset(
                'assets/icons/wallet_tabs_add.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  _walletHeaderLime,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _WalletTab extends StatelessWidget {
  const _WalletTab({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF141414) : _transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: selected ? const EdgeInsets.all(5) : EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF292929) : _transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _white : _walletHeaderMuted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          key: selected ? const Key('wallet-tab-selection-indicator') : null,
          duration: const Duration(milliseconds: 160),
          width: selected ? 16 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: selected ? _walletHeaderLime : _transparent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    ),
  );
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.palette,
    required this.labels,
    required this.selected,
    this.onChanged,
    this.itemSpacing = 32,
    this.fontSize = 18,
    this.horizontalPadding = 10,
    this.showSelectedIndicator = false,
  });
  final AcoPalette palette;
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;
  final double itemSpacing;
  final double fontSize;
  final double horizontalPadding;
  final bool showSelectedIndicator;

  Widget _tabLabel(String label, bool isSelected) {
    final content = Container(
      height: 28.42,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: isSelected
            ? (showSelectedIndicator
                  ? const Color(0xFF252525)
                  : const Color(0xFF212121))
            : _transparent,
        borderRadius: BorderRadius.circular(14.21),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? _white : _walletHeaderMuted,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          fontSize: fontSize,
          height: 1.15,
        ),
      ),
    );
    if (!showSelectedIndicator || !isSelected) return content;
    return Transform.translate(
      offset: const Offset(0, -4),
      child: Container(
        height: 37,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(19),
        ),
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Padding(
          padding: EdgeInsets.only(
            right: i == labels.length - 1 ? 0 : itemSpacing,
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 42),
            onPressed: onChanged == null ? null : () => onChanged!(i),
            child: SizedBox(
              height: showSelectedIndicator ? 46 : 42,
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tabLabel(labels[i], i == selected),
                    if (showSelectedIndicator && i == selected) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 14,
                        height: 3,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

class _WalletAssetIcon extends StatelessWidget {
  const _WalletAssetIcon({required this.symbol, this.logoUri, this.size = 24});
  final String symbol;
  final String? logoUri;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = symbol.toUpperCase();
    final asset = switch (normalized) {
      'USDT' => 'assets/icons/crypto/domi/tokens/usdt.png',
      'USDC' => 'assets/icons/crypto/domi/tokens/usdc.png',
      'IOST' => null,
      _ => 'assets/icons/crypto/tokens/${normalized.toLowerCase()}.svg',
    };
    final remoteLogo = logoUri;
    if (remoteLogo != null &&
        (remoteLogo.startsWith('https://') ||
            remoteLogo.startsWith('http://'))) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.network(
            remoteLogo,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                _WalletAssetIcon(symbol: symbol, size: size),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: asset == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: normalized == 'IOST'
                    ? const Color(0xFFE0E0E0)
                    : const Color(0xFF2680D9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  normalized.substring(0, 1),
                  style: const TextStyle(
                    color: _white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : asset.endsWith('.png')
          ? ClipOval(
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _MissingTokenIcon(),
              ),
            )
          : SvgPicture.asset(
              asset,
              errorBuilder: (_, _, _) => const _MissingTokenIcon(),
            ),
    );
  }
}

class _MissingTokenIcon extends StatelessWidget {
  const _MissingTokenIcon();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFF777777),
      shape: BoxShape.circle,
    ),
    child: const Center(
      child: Text(
        '?',
        style: TextStyle(
          color: _white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _WalletAssetRow extends StatelessWidget {
  const _WalletAssetRow({
    required this.palette,
    required this.symbol,
    required this.title,
    required this.amount,
    required this.value,
    this.onTap,
  });
  final AcoPalette palette;
  final String symbol, title, amount, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final primaryTextStyle = TextStyle(
      color: palette.primaryText,
      fontSize: AcoTypography.body,
      fontWeight: FontWeight.w400,
    );
    final secondaryTextStyle = TextStyle(
      color: palette.mutedText,
      fontSize: AcoTypography.caption,
    );

    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: onTap == null ? null : '查看$symbol详情',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 65,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      _WalletAssetIcon(symbol: symbol),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(symbol, style: primaryTextStyle),
                            const SizedBox(height: 3),
                            Text(title, style: secondaryTextStyle),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amount,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: primaryTextStyle,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: secondaryTextStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 40,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 1,
                  child: const ColoredBox(color: Color(0xFF161616)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
