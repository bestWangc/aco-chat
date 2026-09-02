part of 'aco_design_shell.dart';

class _AcoPageRoute<T> extends CupertinoPageRoute<T> {
  _AcoPageRoute({required super.builder});

  @override
  Color? get barrierColor => null;
}

class AcoScreenPage extends StatelessWidget {
  const AcoScreenPage({
    required this.screen,
    required this.dark,
    required this.isRoot,
    required this.onOpen,
    required this.onThemeToggle,
    this.onWalletReady,
    this.onWalletSelected,
    this.displayName,
    this.accountId,
    this.walletLoginFuture,
    this.username,
    this.avatarUrl,
    this.walletIdentity,
    this.walletSecretStore,
    this.walletName = 'Wallet1',
    this.onWalletNameChanged,
    this.walletChainIndex = 0,
    this.onWalletChainSelected,
    this.transferToken,
    this.onSendTokenSelected,
    this.onDisplayNameChanged,
    this.onUsernameChanged,
    this.onAvatarUrlChanged,
    this.language = '简体中文',
    this.liveListRevision = 0,
    this.onLanguageChanged,
    this.live,
    this.initialLives,
    this.hasAppUpdate = false,
    this.onOpenAppUpdate,
    super.key,
  });

  final AcoScreen screen;
  final bool dark;
  final bool isRoot;
  final ValueChanged<AcoScreen> onOpen;
  final VoidCallback onThemeToggle;
  final Future<void> Function(WalletIdentity, String)? onWalletReady;
  final Future<void> Function(WalletIdentity)? onWalletSelected;
  final String? displayName;
  final String? accountId;
  final Future<AccountProfile?>? walletLoginFuture;
  final String? username;
  final String? avatarUrl;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore? walletSecretStore;
  final String walletName;
  final Future<void> Function(String name)? onWalletNameChanged;
  final int walletChainIndex;
  final ValueChanged<int>? onWalletChainSelected;
  final TransferToken? transferToken;
  final ValueChanged<TransferToken>? onSendTokenSelected;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onUsernameChanged;
  final ValueChanged<String>? onAvatarUrlChanged;
  final String language;
  final int liveListRevision;
  final ValueChanged<String>? onLanguageChanged;
  final LiveSession? live;
  final List<LiveSession>? initialLives;
  final bool hasAppUpdate;
  final Future<bool> Function()? onOpenAppUpdate;

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(dark);
    final currentDisplayName = displayName;
    final currentAccountId = accountId;
    final currentUsername = username;
    final page = switch (screen) {
      AcoScreen.walletHome => _WalletHome(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletLoginFuture: walletLoginFuture,
        walletName: walletName,
        selectedChain: _supportedWalletChains[walletChainIndex],
        onSendTokenSelected: onSendTokenSelected ?? (_) {},
      ),
      AcoScreen.walletChains => _WalletChains(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletName: walletName,
        selectedChain: walletChainIndex,
        onChainSelected: onWalletChainSelected ?? (_) {},
        onWalletSelected: onWalletSelected ?? (_) async {},
      ),
      AcoScreen.walletSwitcher => _WalletChains(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletName: walletName,
        selectedChain: walletChainIndex,
        onChainSelected: onWalletChainSelected ?? (_) {},
        onWalletSelected: onWalletSelected ?? (_) async {},
      ),
      AcoScreen.walletSetupCreate => _WalletSetupFlow(
        dark: dark,
        mode: _WalletSetupMode.create,
        requireSecuritySetup: false,
        onBack: () => Navigator.of(context).pop(),
        onComplete: onWalletReady ?? (_, _) async {},
      ),
      AcoScreen.walletSetupImport => _WalletSetupFlow(
        dark: dark,
        mode: _WalletSetupMode.import,
        requireSecuritySetup: false,
        onBack: () => Navigator.of(context).pop(),
        onComplete: onWalletReady ?? (_, _) async {},
      ),
      AcoScreen.assetDetail => _AssetDetail(
        palette: palette,
        walletIdentity: walletIdentity,
        selectedChain: _supportedWalletChains[walletChainIndex],
        walletName: walletName,
        onWalletNameChanged: onWalletNameChanged,
        onOpen: onOpen,
      ),
      AcoScreen.backupMnemonic => _BackupMnemonicFlow(
        palette: palette,
        walletIdentity: walletIdentity,
        secretStore: walletSecretStore ?? SecureWalletSecretStore(),
      ),
      AcoScreen.exportPrivateKey => _BackupMnemonicFlow(
        palette: palette,
        walletIdentity: walletIdentity,
        secretStore: walletSecretStore ?? SecureWalletSecretStore(),
        exportType: _SensitiveExportType.privateKey,
      ),
      AcoScreen.send => _SendTransferPage(
        palette: palette,
        walletIdentity: walletIdentity,
        secretStore: walletSecretStore ?? SecureWalletSecretStore(),
        token:
            transferToken ??
            _transferTokensForChain(
              _supportedWalletChains[walletChainIndex],
            ).first,
      ),
      AcoScreen.receive => _ReceivePage(
        palette: palette,
        walletIdentity: walletIdentity,
        selectedChain: _supportedWalletChains[walletChainIndex],
      ),
      AcoScreen.scan => _ScanPage(palette: palette),
      AcoScreen.addTokenV1 => _AddTokenPage(palette: palette),
      AcoScreen.addTokenV2 => _AddTokenPage(palette: palette),
      AcoScreen.dexToken => _DexTokenPage(palette: palette, onOpen: onOpen),
      AcoScreen.dexSwap => _DexSwapPage(palette: palette),
      AcoScreen.browserDiscover => _BrowserDiscoverPage(
        palette: palette,
        onOpen: onOpen,
      ),
      AcoScreen.marketOverview => _MarketOverviewPage(palette: palette),
      AcoScreen.squareFeed => _SquareFeedPage(
        key: ValueKey('square-feed-$liveListRevision'),
        palette: palette,
        onOpen: onOpen,
        avatarUrl: avatarUrl,
        walletLoginFuture: walletLoginFuture,
        initialLives: initialLives,
      ),
      AcoScreen.socialMessages => _SocialMessagesPage(
        palette: palette,
        onOpen: onOpen,
        avatarUrl: avatarUrl,
      ),
      AcoScreen.chatV1 => _ChatPage(palette: palette, version: 1),
      AcoScreen.chatV2 => _ChatPage(palette: palette, version: 2),
      AcoScreen.liveStream => _LiveStreamPage(palette: palette, onOpen: onOpen),
      AcoScreen.voiceRoom => _VoiceRoomPage(palette: palette, live: live),
      AcoScreen.mining => _MiningPage(palette: palette),
      AcoScreen.profile =>
        currentDisplayName == null ||
                currentAccountId == null ||
                currentUsername == null
            ? _ProfileLoadingPage(palette: palette)
            : _ProfilePage(
                palette: palette,
                onOpen: onOpen,
                displayName: currentDisplayName,
                accountId: currentAccountId,
                username: currentUsername,
                avatarUrl: avatarUrl ?? '',
                hasAppUpdate: hasAppUpdate,
                onOpenAppUpdate: onOpenAppUpdate ?? () async => false,
                onBack: isRoot ? null : () => Navigator.of(context).maybePop(),
              ),
      AcoScreen.profileEdit =>
        currentDisplayName == null ||
                currentAccountId == null ||
                currentUsername == null
            ? _ProfileLoadingPage(palette: palette)
            : _ProfileEditPage(
                palette: palette,
                initialName: currentDisplayName,
                initialUsername: currentUsername,
                accountId: currentAccountId,
                initialAvatarUrl: avatarUrl ?? '',
                onDisplayNameChanged: onDisplayNameChanged,
                onUsernameChanged: onUsernameChanged,
                onAvatarUrlChanged: onAvatarUrlChanged,
              ),
      AcoScreen.profileQr =>
        currentDisplayName == null ||
                currentAccountId == null ||
                currentUsername == null
            ? _ProfileLoadingPage(palette: palette)
            : _ProfileQrPage(
                palette: palette,
                displayName: currentDisplayName,
                accountId: currentAccountId,
                username: currentUsername,
                avatarUrl: avatarUrl ?? '',
                onBack: () => Navigator.of(context).maybePop(),
              ),
      AcoScreen.profileTheme => _ThemeSettingsPage(
        palette: palette,
        dark: dark,
        onThemeToggle: onThemeToggle,
      ),
      AcoScreen.profileLanguage => _LanguageSettingsPage(
        palette: palette,
        initialLanguage: language,
        onLanguageChanged: onLanguageChanged,
      ),
      AcoScreen.comingSoon => const _ComingSoonPage(),
      AcoScreen.createLive => _CreateLivePage(
        palette: palette,
        walletLoginFuture: walletLoginFuture,
      ),
    };

    return SizedBox.expand(
      child: ColoredBox(
        color: dark && screen == AcoScreen.walletHome
            ? _black
            : palette.background,
        child: _AcoViewport(
          child: SafeArea(
            top: !isRoot,
            minimum: EdgeInsets.zero,
            left: false,
            right: false,
            bottom: false,
            child: page,
          ),
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
    this.backgroundColor,
    super.key,
  });

  final int selected;
  final bool dark;
  final ValueChanged<int> onSelected;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(dark);
    return ColoredBox(
      color:
          backgroundColor ??
          (dark ? const Color(0xFF000000) : palette.background),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: SizedBox(
          height: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _navLabels.length; index++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected == index,
                    label: _navLabels[index],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(index),
                      child: SizedBox.expand(
                        child: _FigmaNavItem(
                          index: index,
                          selected: selected == index,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FigmaNavItem extends StatelessWidget {
  const _FigmaNavItem({
    required this.index,
    required this.selected,
    required this.palette,
  });

  final int index;
  final bool selected;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (selected) {
      color = palette.dark ? _walletHeaderLime : palette.primaryText;
    } else {
      color = palette.dark ? _walletNavInactive : palette.navInactive;
    }
    if (index == 2) {
      return ExcludeSemantics(child: _DexBottomNavIcon(selected: selected));
    }
    // Normal navigation icons share one visual scale.
    final iconSize = switch (index) {
      0 => const Size(22, 18),
      1 => const Size(24, 21),
      3 => const Size(20, 19),
      4 => const Size(24, 20),
      _ => const Size(26, 24),
    };
    final icon = ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(_navAssets[index], fit: BoxFit.contain),
    );
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // All icons share the same bottom edge, then the label follows
          // immediately. This avoids SVG-specific offsets.
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: SizedBox(
                  width: iconSize.width,
                  height: iconSize.height,
                  child: icon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _navLabels[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DexBottomNavIcon extends StatelessWidget {
  const _DexBottomNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    // DEX is a two-part mark (wordmark + triangle), not an icon with a label.
    // Its visual bounds are intentionally taller and sit slightly higher than
    // the four regular navigation destinations.
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: 40,
      height: 38,
      child: Transform.translate(
        offset: const Offset(0, -16),
        child: Transform.scale(
          scale: .90,
          child: SvgPicture.asset(
            selected
                ? 'assets/icons/source_dex_active.svg'
                : 'assets/icons/source_dex_inactive.svg',
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

class AcoTopActions extends StatelessWidget {
  const AcoTopActions({
    required this.palette,
    required this.onOpen,
    this.scale = 1,
    super.key,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final double scale;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _AcoDesignActionButton(
        asset: 'assets/icons/source_scan.svg',
        palette: palette,
        scale: scale,
        label: '扫描二维码',
        onPressed: () => onOpen(AcoScreen.scan),
      ),
      SizedBox(width: 6 * scale),
      _AcoDesignActionButton(
        asset: 'assets/icons/source_person.svg',
        palette: palette,
        scale: scale,
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
    this.scale = 1,
  });

  final String asset;
  final AcoPalette palette;
  final String label;
  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(44 * scale, 44 * scale),
      onPressed: onPressed,
      child: SvgPicture.asset(
        asset,
        // Keep the original aspect ratios while reducing the visual weight;
        // the surrounding 44pt button remains the touch target.
        width: (asset.contains('source_scan') ? 22 : 22.5) * scale,
        height: (asset.contains('source_scan') ? 27 : 25) * scale,
        colorFilter: ColorFilter.mode(
          palette.dark ? _white : palette.primaryText,
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
    this.leadingButtonOffset = Offset.zero,
    this.scale = 1,
    super.key,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onLeadingPressed;
  final Offset leadingButtonOffset;
  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46 * scale,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (onLeadingPressed != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: leadingButtonOffset,
              child: AcoIconButton(
                icon: CupertinoIcons.back,
                palette: palette,
                label: '返回',
                onPressed: onLeadingPressed!,
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
          child:
              trailing ??
              AcoTopActions(palette: palette, onOpen: onOpen, scale: scale),
        ),
      ],
    ),
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
    this.backgroundColor,
    this.minHeight,
    super.key,
  });
  final AcoPalette palette;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;
  final Color? backgroundColor;
  final double? minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: minHeight == null
        ? null
        : BoxConstraints(minHeight: minHeight!),
    decoration: BoxDecoration(
      border: border ? Border.all(color: palette.border) : null,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: shad.ShadCard(
      padding: padding,
      radius: BorderRadius.circular(radius),
      backgroundColor: backgroundColor ?? palette.surface,
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
    this.fontSize = AcoTypography.bodySmall,
    this.backgroundColor = _lime,
    this.fontWeight = FontWeight.w700,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;
  final double? height;
  final double fontSize;
  final Color backgroundColor;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height ?? (compact ? 36 : 42),
    child: shad.ShadButton(
      backgroundColor: backgroundColor,
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
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
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
    this.showSubmit = false,
    super.key,
  });
  final AcoPalette palette;
  final String hint;
  final VoidCallback? onSubmit;
  final Widget? action;
  final double height;
  final IconData submitIcon;
  final AcoSearchVariant variant;
  final bool showSubmit;

  @override
  Widget build(BuildContext context) {
    final isSquareComposer = variant == AcoSearchVariant.squareComposer;
    final submitWidth = isSquareComposer ? 48.0 : height;
    final borderColor = _borderColor(isSquareComposer);
    var iconColor = palette.mutedText;
    var hintColor = palette.mutedText;
    if (palette.dark) {
      iconColor = isSquareComposer
          ? const Color(0xFF212121)
          : const Color(0xFFF7F7F7);
      hintColor = isSquareComposer
          ? const Color(0xFFF2F2F2)
          : const Color(0xFF888888);
    }
    final submitChild = _buildSubmitChild(isSquareComposer);

    return Container(
      height: height,
      clipBehavior: isSquareComposer ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          if (isSquareComposer)
            SizedBox(
              width: 20,
              height: 16,
              child: Image.asset(
                'assets/icons/square_search.png',
                filterQuality: FilterQuality.high,
              ),
            )
          else
            Icon(CupertinoIcons.search, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: hintColor,
                fontSize: isSquareComposer
                    ? AcoTypography.caption
                    : AcoTypography.body,
              ),
            ),
          ),
          ?action,
          if (onSubmit != null || showSubmit)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size(submitWidth, height),
              onPressed: onSubmit,
              child: Container(
                key: isSquareComposer
                    ? const Key('square-search-submit')
                    : null,
                width: submitWidth,
                height: height,
                decoration: BoxDecoration(
                  color: isSquareComposer ? const Color(0xFFD7D7D7) : _lime,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
                child: submitChild,
              ),
            ),
        ],
      ),
    );
  }

  Color _borderColor(bool isSquareComposer) {
    if (!palette.dark) return palette.border;
    return isSquareComposer ? const Color(0xFFD7D7D7) : const Color(0xFFC1C1C1);
  }

  Widget _buildSubmitChild(bool isSquareComposer) {
    if (submitIcon != CupertinoIcons.add) {
      return Icon(submitIcon, color: _black, size: height > 48 ? 30 : 24);
    }

    if (isSquareComposer) {
      return Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: Image.asset(
            'assets/icons/square_search_add.png',
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }

    final plusAsset = palette.dark
        ? 'assets/icons/design_plus_dark.png'
        : 'assets/icons/design_plus_light.png';
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: Image.asset(plusAsset, filterQuality: FilterQuality.high),
      ),
    );
  }
}

const _defaultAvatarAsset = 'assets/images/default_avatar.png';
const _liveRoomHostAvatarAsset = 'assets/design_svg/source/images/img3.jpg';
const _liveRoomListenerAvatarAsset = 'assets/design_svg/source/images/img5.jpg';

class AcoAvatar extends StatelessWidget {
  const AcoAvatar({
    this.large = false,
    this.size,
    this.assetPath = _defaultAvatarAsset,
    this.imageUrl,
    super.key,
  });
  final bool large;
  final double? size;
  final String assetPath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (large ? 76.0 : 42.0);
    final parsed = imageUrl == null || imageUrl!.isEmpty
        ? null
        : Uri.tryParse(imageUrl!);
    final url = parsed?.hasScheme == true
        ? imageUrl
        : (parsed == null
              ? null
              : Uri.parse(
                  const AppConfig().apiBaseUrl,
                ).replace(path: parsed.path).toString());
    final fallback = Image.asset(
      assetPath,
      width: resolvedSize,
      height: resolvedSize,
      fit: BoxFit.cover,
      semanticLabel: '用户头像',
    );
    return ClipOval(
      child: url == null
          ? fallback
          : Image.network(
              url,
              width: resolvedSize,
              height: resolvedSize,
              fit: BoxFit.cover,
              semanticLabel: '用户头像',
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

void _showNotice(BuildContext context, String title, String message) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) {
      const themeColor = _accentGreen;
      return CupertinoActionSheet(
        title: Text(
          title,
          style: TextStyle(
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w700,
          ),
        ),
        message: Text(
          message,
          style: TextStyle(fontSize: AcoTypography.caption),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(
              '知道了',
              style: TextStyle(color: themeColor, fontSize: AcoTypography.body),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: themeColor, fontSize: AcoTypography.body),
          ),
        ),
      );
    },
  );
}

void showAcoAlertNotice(BuildContext context, String title, String message) {
  showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) {
      final themeColor = CupertinoTheme.of(dialogContext).primaryColor;
      return CupertinoAlertDialog(
        title: Text(title, style: TextStyle(color: themeColor)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message, style: TextStyle(color: themeColor)),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('知道了', style: TextStyle(color: themeColor)),
          ),
        ],
      );
    },
  );
}

void showCheckInSuccessDialog(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: _black.withValues(alpha: .55),
    pageBuilder: (dialogContext, _, _) => Center(
      child: SizedBox(
        width: 300,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF202020),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 80,
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/check_in_success.png',
                    fit: BoxFit.cover,
                    semanticLabel: '签到成功',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '签到成功',
                style: TextStyle(
                  color: _white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 240,
                height: 32,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(16),
                  color: _accentGreen,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    '我知道了',
                    style: TextStyle(
                      color: _black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
