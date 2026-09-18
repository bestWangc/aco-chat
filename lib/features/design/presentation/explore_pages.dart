part of 'aco_design_shell.dart';

const _squareComposerHorizontalInset = 35.0;

class _BrowserDiscoverPage extends StatefulWidget {
  const _BrowserDiscoverPage({
    required this.palette,
    required this.onOpen,
    required this.selectedChain,
    required this.walletIdentity,
    required this.onChainSelected,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final ValueChanged<int> onChainSelected;

  @override
  State<_BrowserDiscoverPage> createState() => _BrowserDiscoverPageState();
}

class _BrowserDiscoverPageState extends State<_BrowserDiscoverPage> {
  final _addressController = TextEditingController();
  late Future<List<DappEntry>> _hotDapps;
  late Future<List<DappEntry>> _earningsDapps;

  @override
  void initState() {
    super.initState();
    _hotDapps = DappDirectoryService().loadHot(
      widget.selectedChain.network.name,
    );
    _earningsDapps = DappDirectoryService().loadEarnings(
      widget.selectedChain.network.name,
    );
  }

  @override
  void didUpdateWidget(covariant _BrowserDiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChain.network != widget.selectedChain.network) {
      _hotDapps = DappDirectoryService().loadHot(
        widget.selectedChain.network.name,
      );
      _earningsDapps = DappDirectoryService().loadEarnings(
        widget.selectedChain.network.name,
      );
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CupertinoTextField(
          controller: _addressController,
          autocorrect: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          style: TextStyle(color: widget.palette.primaryText, fontSize: 16),
          placeholder: '请输入网址',
          placeholderStyle: TextStyle(
            color: widget.palette.mutedText,
            fontSize: 16,
          ),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(CupertinoIcons.globe, size: 18),
          ),
          suffix: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(38, 38),
            onPressed: _openAddress,
            child: Icon(
              CupertinoIcons.arrow_right_circle_fill,
              color: widget.palette.accent,
            ),
          ),
          decoration: BoxDecoration(
            color: widget.palette.background,
            border: Border.all(
              color: widget.palette.dark
                  ? const Color(0xFFD7D7D7)
                  : widget.palette.border,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          onSubmitted: (_) => _openAddress(),
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
                labels: const ['热门'],
                selected: 0,
                itemSpacing: 20,
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
                    '${widget.selectedChain.network.name} 暂无热门 DApp',
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
                for (final dapp in dapps.take(5))
                  Flexible(
                    child: _DiscoverShortcut(
                      palette: widget.palette,
                      dapp: dapp,
                      onTap: () => _openDapp(context, dapp),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      _DiscoverPromoCarousel(palette: widget.palette),
      const SizedBox(height: 30),
      _DiscoverEarningsHeader(palette: widget.palette),
      const SizedBox(height: 12),
      FutureBuilder<List<DappEntry>>(
        future: _earningsDapps,
        builder: (_, snapshot) {
          final lendingDapps = (snapshot.data ?? const <DappEntry>[])
              .take(5)
              .toList(growable: false);
          if (lendingDapps.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (final dapp in lendingDapps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EarningsDappTile(
                      palette: widget.palette,
                      dapp: dapp,
                      onTap: () => _openDapp(context, dapp),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );

  Future<void> _openDapp(BuildContext context, DappEntry dapp) async {
    final uri = _normalizeDappUri(dapp.url);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      _showNotice(context, '暂无法打开', '${dapp.name} 未提供有效的 HTTPS 地址。');
      return;
    }
    if (!await _confirmDappOpen(context, dapp) || !mounted) return;
    final chain = await _resolveDappChain(context, dapp);
    if (chain == null || !mounted) return;
    final chainIndex = _supportedWalletChains.indexOf(chain);
    if (chainIndex >= 0 && chain != widget.selectedChain) {
      widget.onChainSelected(chainIndex);
    }
    if (!mounted) return;
    await _openBrowser(uri, dapp.name, dapp.id, chain);
  }

  Future<void> _openBrowser(
    Uri uri,
    String title,
    String dappId,
    _WalletChain chain,
  ) => Navigator.of(context).push<void>(
    _AcoPageRoute<void>(
      builder: (_) => _DappBrowserPage(
        palette: widget.palette,
        initialUrl: uri.toString(),
        title: title,
        dappId: dappId,
        walletIdentity: widget.walletIdentity,
        selectedChain: chain,
        onChainSelected: widget.onChainSelected,
      ),
    ),
  );

  Future<bool> _confirmDappOpen(BuildContext context, DappEntry dapp) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      builder: (sheetContext) => _DappRiskSheet(
        palette: widget.palette,
        dapp: dapp,
        network: widget.selectedChain.network.name,
      ),
    );
    return result ?? false;
  }

  Future<_WalletChain?> _resolveDappChain(
    BuildContext context,
    DappEntry dapp,
  ) {
    final supportedChains = _supportedWalletChains
        .where((chain) => dapp.networks.contains(chain.network.name))
        .toList(growable: false);
    if (dapp.networks.isEmpty ||
        supportedChains.contains(widget.selectedChain)) {
      return Future.value(widget.selectedChain);
    }
    if (supportedChains.isEmpty) return Future.value(widget.selectedChain);
    return showCupertinoDialog<_WalletChain>(
      context: context,
      builder: (_) => _DappUnsupportedNetworkDialog(
        palette: widget.palette,
        supportedChains: supportedChains,
        currentChain: widget.selectedChain,
      ),
    );
  }

  Future<void> _openAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;
    final uri = _normalizeDappUri(address);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      _showNotice(context, '网址无效', '仅支持 HTTPS 网站。');
      return;
    }
    final approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => _ExternalUrlRiskDialog(palette: widget.palette, uri: uri),
    );
    if (approved != true || !mounted) return;
    await _openBrowser(uri, uri.host, uri.host, widget.selectedChain);
  }
}

class _ExternalUrlRiskDialog extends StatefulWidget {
  const _ExternalUrlRiskDialog({required this.palette, required this.uri});

  final AcoPalette palette;
  final Uri uri;

  @override
  State<_ExternalUrlRiskDialog> createState() => _ExternalUrlRiskDialogState();
}

class _ExternalUrlRiskDialogState extends State<_ExternalUrlRiskDialog> {
  var _accepted = true;

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: const Text('跳转提示'),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.palette.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.uri.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: widget.palette.primaryText, fontSize: 14),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '您即将进入第三方链接。第三方网站的使用行为适用其隐私政策和用户协议，并由第三方独立承担责任。请确认您信任该网站并自行承担访问可能产生的风险。',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: 14,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        _RiskCheckRow(
          value: _accepted,
          label: '我已仔细阅读并了解风险',
          palette: widget.palette,
          onChanged: (value) => setState(() => _accepted = value),
        ),
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
      CupertinoDialogAction(
        isDefaultAction: true,
        onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
        child: const Text('继续访问'),
      ),
    ],
  );
}

class _DappUnsupportedNetworkDialog extends StatefulWidget {
  const _DappUnsupportedNetworkDialog({
    required this.palette,
    required this.supportedChains,
    required this.currentChain,
  });

  final AcoPalette palette;
  final List<_WalletChain> supportedChains;
  final _WalletChain currentChain;

  @override
  State<_DappUnsupportedNetworkDialog> createState() =>
      _DappUnsupportedNetworkDialogState();
}

class _DappUnsupportedNetworkDialogState
    extends State<_DappUnsupportedNetworkDialog> {
  _WalletChain? _selectedChain;

  Future<void> _selectChain() async {
    final chain = await showCupertinoModalPopup<_WalletChain>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('选择支持的公链'),
        actions: [
          for (final chain in widget.supportedChains)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop(chain),
              child: Text(chain.displayLabel),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (chain != null && mounted) setState(() => _selectedChain = chain);
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Row(
      children: [
        const Expanded(child: Text('温馨提示')),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 28,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(CupertinoIcons.xmark, color: widget.palette.mutedText),
        ),
      ],
    ),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('该 DApp 不支持您当前的钱包网络，请切换钱包后继续访问。'),
        const SizedBox(height: 22),
        Text('切换钱包', style: TextStyle(color: widget.palette.mutedText)),
        const SizedBox(height: 8),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          color: widget.palette.surfaceRaised,
          onPressed: _selectChain,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedChain?.displayLabel ?? '请选择支持的钱包',
                  style: TextStyle(color: widget.palette.mutedText),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: widget.palette.mutedText,
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: _selectedChain == null
            ? null
            : () => Navigator.of(context).pop(_selectedChain),
        child: const Text('确定进入'),
      ),
      CupertinoDialogAction(
        onPressed: () => Navigator.of(context).pop(widget.currentChain),
        child: const Text('忽略，仍然进入'),
      ),
    ],
  );
}

class _DappRiskSheet extends StatefulWidget {
  const _DappRiskSheet({
    required this.palette,
    required this.dapp,
    required this.network,
  });

  final AcoPalette palette;
  final DappEntry dapp;
  final String network;

  @override
  State<_DappRiskSheet> createState() => _DappRiskSheetState();
}

class _DappRiskSheetState extends State<_DappRiskSheet> {
  var _accepted = true;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        color: widget.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  _dappLogoAsset(widget.dapp.id),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 44,
                    height: 44,
                    color: widget.palette.surfaceRaised,
                    child: Icon(
                      CupertinoIcons.cube_box,
                      color: widget.palette.mutedText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dapp.name,
                      style: TextStyle(
                        color: widget.palette.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '此服务由 ${Uri.tryParse(widget.dapp.url)?.host ?? widget.dapp.name} 提供',
                      style: TextStyle(
                        color: widget.palette.mutedText,
                        fontSize: AcoTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 32,
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(
                  CupertinoIcons.xmark,
                  color: widget.palette.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            widget.dapp.description?.trim().isNotEmpty == true
                ? widget.dapp.description!
                : '该 DApp 由第三方提供。使用前请确认服务内容并谨慎进行链上操作。',
            style: TextStyle(
              color: widget.palette.mutedText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '支持的网络',
            style: TextStyle(
              color: widget.palette.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final network in _displayNetworks)
                _DappNetworkChip(chain: _walletChainForNetwork(network)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '类别',
            style: TextStyle(
              color: widget.palette.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _DappInfoChip(
            label: widget.dapp.category.isEmpty ? '工具' : widget.dapp.category,
            palette: widget.palette,
          ),
          const SizedBox(height: 18),
          _RiskCheckRow(
            value: _accepted,
            label: '我已仔细阅读并了解风险',
            palette: widget.palette,
            onChanged: (value) => setState(() => _accepted = value),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: widget.palette.accent,
              onPressed: _accepted
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(
                '进入${widget.dapp.name}',
                style: const TextStyle(fontSize: 16, color: _black),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<String> get _displayNetworks => widget.dapp.networks.isEmpty
      ? <String>[widget.network]
      : widget.dapp.networks;

  _WalletChain? _walletChainForNetwork(String network) =>
      _supportedWalletChains.cast<_WalletChain?>().firstWhere(
        (chain) => chain?.network.name == network,
        orElse: () => null,
      );
}

class _DappNetworkChip extends StatelessWidget {
  const _DappNetworkChip({required this.chain});

  final _WalletChain? chain;

  @override
  Widget build(BuildContext context) => chain == null
      ? const SizedBox.shrink()
      : _WalletChainLogo(
          asset: chain!.asset,
          backgroundColor: chain!.backgroundColor,
          size: 32,
        );
}

class _DappInfoChip extends StatelessWidget {
  const _DappInfoChip({required this.label, required this.palette});

  final String label;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: palette.primaryText, fontSize: 14),
    ),
  );
}

class _RiskCheckRow extends StatelessWidget {
  const _RiskCheckRow({
    required this.value,
    required this.label,
    required this.palette,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final AcoPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(0, 32),
    onPressed: () => onChanged(!value),
    child: Row(
      children: [
        Icon(
          value
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.circle,
          color: value ? palette.accent : palette.mutedText,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: palette.mutedText, fontSize: 14),
          ),
        ),
      ],
    ),
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
                        color: index == _currentPage
                            ? widget.palette.accent
                            : widget.palette.accent.withValues(alpha: .35),
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
  const _DiscoverPromoCarousel({required this.palette});

  final AcoPalette palette;

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
                color: index == _currentPage
                    ? widget.palette.accent
                    : widget.palette.accent.withValues(alpha: .35),
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
