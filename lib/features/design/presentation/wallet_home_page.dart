part of 'aco_design_shell.dart';

class _WalletHome extends StatefulWidget {
  const _WalletHome({
    super.key,
    required this.palette,
    required this.onOpen,
    required this.selectedChain,
    required this.onSendTokenSelected,
    required this.walletName,
    this.walletIdentity,
    this.walletLoginFuture,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final _WalletChain selectedChain;
  final ValueChanged<TransferToken> onSendTokenSelected;
  final String walletName;
  final WalletIdentity? walletIdentity;
  final Future<AccountProfile?>? walletLoginFuture;

  @override
  State<_WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<_WalletHome> {
  late final WalletPortfolioService _portfolioService;
  late final WalletValuationService _valuationService;
  late final AccountTokenStore _tokenStore;
  late final WalletMetadataStore _metadataStore;
  late Future<List<WalletBalance>> _balancesFuture;
  late Future<double?> _totalBalanceFuture;
  late List<WalletBalance> _initialBalances;
  List<WalletBalance> _displayBalances = const [];
  int _loadGeneration = 0;
  final Map<WalletNetwork, List<WalletBalance>> _balanceCache = {};
  final LayerLink _walletActionsLink = LayerLink();
  OverlayEntry? _walletActionsEntry;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _portfolioService = WalletPortfolioService();
    _valuationService = WalletValuationService();
    _tokenStore = SecureAccountTokenStore();
    _metadataStore = WalletMetadataStore();
    _initialBalances = widget.walletIdentity == null
        ? _placeholderBalances()
        : _placeholderBalances().where((balance) => balance.isNative).toList();
    _displayBalances = _initialBalances;
    _balancesFuture = _loadAndCacheBalances(widget.selectedChain.network);
    _totalBalanceFuture = _loadTotalBalance(_balancesFuture);
    unawaited(_prepareInitialBalances(widget.selectedChain.network));
    unawaited(_streamBalances(widget.selectedChain.network, ++_loadGeneration));
    _watchWalletLogin(widget.walletLoginFuture);
  }

  @override
  void didUpdateWidget(covariant _WalletHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChain.network != widget.selectedChain.network ||
        oldWidget.walletIdentity != widget.walletIdentity) {
      _reloadBalances();
    }
    if (oldWidget.walletLoginFuture != widget.walletLoginFuture) {
      _watchWalletLogin(widget.walletLoginFuture);
    }
  }

  void _watchWalletLogin(Future<AccountProfile?>? loginFuture) {
    if (loginFuture == null) return;
    unawaited(
      loginFuture
          .then<void>((_) {
            if (mounted) _reloadBalances();
          })
          .catchError((_) {
            if (mounted) _reloadBalances();
          }),
    );
  }

  Future<List<WalletBalance>> _loadBalances(WalletNetwork network) async {
    final identity = widget.walletIdentity;
    if (identity == null) return _placeholderBalances();
    final tokens = await _tokenStore.read();
    if (tokens == null) return _visiblePlaceholderBalancesAsync(network);
    final customTokens = await _metadataStore.customTokens(identity);
    final hidden = await _metadataStore.hiddenTokenSymbols(
      identity,
      network.name,
    );
    final assets = _assetsFor(network, customTokens);
    final results = <WalletBalance>[];
    await for (final balance in _portfolioService.loadAssetBalances(
      network: network,
      identity: identity,
      accessToken: tokens.accessToken,
      assets: assets,
    )) {
      if (balance.isNative || !_isHidden(balance, hidden)) results.add(balance);
    }
    return results;
  }

  List<WalletAsset> _assetsFor(
    WalletNetwork network,
    List<CustomTokenDefinition> custom,
  ) {
    final chain = WalletChainRegistry.chains[network]!;
    final assets = <WalletAsset>[
      WalletAsset(
        network: network,
        symbol: chain.symbol,
        name: chain.nativeAssetName,
        decimals: chain.decimals,
        isNative: true,
      ),
      if (chain.usdt != null)
        WalletAsset(
          network: network,
          symbol: chain.usdt!.symbol,
          name: chain.usdt!.name,
          decimals: chain.usdt!.decimals,
          isNative: false,
          tokenAddress: chain.usdt!.address,
        ),
      if (chain.usdc != null)
        WalletAsset(
          network: network,
          symbol: chain.usdc!.symbol,
          name: chain.usdc!.name,
          decimals: chain.usdc!.decimals,
          isNative: false,
          tokenAddress: chain.usdc!.address,
        ),
      if (network == WalletNetwork.tron) ...[
        WalletAsset(
          network: network,
          symbol: WalletChainRegistry.tronUsdt.symbol,
          name: WalletChainRegistry.tronUsdt.name,
          decimals: 6,
          isNative: false,
          tokenAddress: WalletChainRegistry.tronUsdt.address,
        ),
        WalletAsset(
          network: network,
          symbol: WalletChainRegistry.tronUsdc.symbol,
          name: WalletChainRegistry.tronUsdc.name,
          decimals: 6,
          isNative: false,
          tokenAddress: WalletChainRegistry.tronUsdc.address,
        ),
      ],
      if (network == WalletNetwork.solana) ...[
        WalletAsset(
          network: network,
          symbol: WalletChainRegistry.solanaUsdt.symbol,
          name: WalletChainRegistry.solanaUsdt.name,
          decimals: 6,
          isNative: false,
          tokenAddress: WalletChainRegistry.solanaUsdt.address,
        ),
        WalletAsset(
          network: network,
          symbol: WalletChainRegistry.solanaUsdc.symbol,
          name: WalletChainRegistry.solanaUsdc.name,
          decimals: 6,
          isNative: false,
          tokenAddress: WalletChainRegistry.solanaUsdc.address,
        ),
      ],
    ];
    for (final token in custom.where((t) => t.network == network.name)) {
      if (!assets.any(
        (a) => a.tokenAddress?.toLowerCase() == token.address.toLowerCase(),
      )) {
        assets.add(
          WalletAsset(
            network: network,
            symbol: token.symbol,
            name: token.symbol,
            decimals: token.decimals,
            isNative: false,
            tokenAddress: token.address,
          ),
        );
      }
    }
    return assets;
  }

  Future<void> _prepareInitialBalances(WalletNetwork network) async {
    final identity = widget.walletIdentity;
    if (identity == null) return;

    final hidden = await _metadataStore.hiddenTokenSymbols(
      identity,
      network.name,
    );
    _setInitialBalances(
      network,
      _placeholderBalances()
          .where((balance) => balance.isNative || !_isHidden(balance, hidden))
          .toList(),
    );
  }

  bool _isHidden(WalletBalance balance, Set<String> hidden) =>
      hidden.contains(balance.symbol) ||
      (balance.tokenAddress != null &&
          hidden.contains(balance.tokenAddress!.toLowerCase()));

  void _setInitialBalances(
    WalletNetwork network,
    List<WalletBalance> balances,
  ) {
    if (!mounted || widget.selectedChain.network != network) return;
    setState(() {
      _initialBalances = balances;
    });
  }

  Future<List<WalletBalance>> _loadAndCacheBalances(
    WalletNetwork network,
  ) async {
    try {
      final balances = await _loadBalances(network);
      _balanceCache[network] = balances;
      return balances;
    } catch (_) {
      return _visiblePlaceholderBalancesAsync(network);
    }
  }

  Future<List<WalletBalance>> _visiblePlaceholderBalancesAsync(
    WalletNetwork network,
  ) async {
    final identity = widget.walletIdentity;
    if (identity == null) return _placeholderBalances();
    final hidden = await _metadataStore.hiddenTokenSymbols(
      identity,
      network.name,
    );
    return _placeholderBalances()
        .where((balance) => balance.isNative || !_isHidden(balance, hidden))
        .toList();
  }

  List<WalletBalance> _placeholderBalances() {
    final chain = widget.selectedChain;
    final identity = widget.walletIdentity;
    final decimals = switch (chain.network) {
      WalletNetwork.tron => 6,
      WalletNetwork.solana => 9,
      _ => 18,
    };
    final native = WalletBalance(
      chain: chain.label,
      symbol: chain.nativeToken.symbol,
      assetName: chain.nativeToken.title,
      isNative: true,
      address: identity?.address ?? '',
      decimals: decimals,
      balance: BigInt.zero,
    );
    return [
      native,
      WalletBalance(
        chain: chain.label,
        symbol: 'USDT',
        assetName: 'Tether USD',
        isNative: false,
        address: identity?.address ?? '',
        decimals:
            WalletChainRegistry.chains[chain.network]?.usdt?.decimals ?? 6,
        balance: BigInt.zero,
      ),
      WalletBalance(
        chain: chain.label,
        symbol: 'USDC',
        assetName: 'USD Coin',
        isNative: false,
        address: identity?.address ?? '',
        decimals:
            WalletChainRegistry.chains[chain.network]?.usdc?.decimals ?? 6,
        balance: BigInt.zero,
      ),
    ];
  }

  void _reloadBalances() {
    final network = widget.selectedChain.network;
    final balancesFuture = _loadAndCacheBalances(network);
    final cachedBalances = _balanceCache[network];
    setState(() {
      _balancesFuture = balancesFuture;
      _totalBalanceFuture = _loadTotalBalance(balancesFuture);
      _initialBalances =
          cachedBalances ??
          (widget.walletIdentity == null
              ? _placeholderBalances()
              : _placeholderBalances()
                    .where((balance) => balance.isNative)
                    .toList());
      _displayBalances = _initialBalances;
    });
    unawaited(_prepareInitialBalances(network));
    final generation = ++_loadGeneration;
    unawaited(_streamBalances(network, generation));
  }

  Future<void> _streamBalances(WalletNetwork network, int generation) async {
    final identity = widget.walletIdentity;
    if (identity == null) return;
    final tokens = await _tokenStore.read();
    if (tokens == null) return;
    final custom = await _metadataStore.customTokens(identity);
    final hidden = await _metadataStore.hiddenTokenSymbols(
      identity,
      network.name,
    );
    final assets = _assetsFor(network, custom);
    final placeholders = assets
        .where(
          (a) =>
              a.isNative ||
              (!_isHidden(
                WalletBalance(
                  chain: widget.selectedChain.label,
                  symbol: a.symbol,
                  assetName: a.name,
                  isNative: a.isNative,
                  address: identity.address,
                  decimals: a.decimals,
                  tokenAddress: a.tokenAddress,
                  balance: BigInt.zero,
                ),
                hidden,
              )),
        )
        .map(
          (a) => WalletBalance(
            chain: widget.selectedChain.label,
            symbol: a.symbol,
            assetName: a.name,
            isNative: a.isNative,
            address: identity.address,
            decimals: a.decimals,
            tokenAddress: a.tokenAddress,
            balance: BigInt.zero,
          ),
        )
        .toList();
    if (mounted && generation == _loadGeneration) {
      setState(() => _displayBalances = placeholders);
    }
    final byId = <String, WalletBalance>{};
    await for (final balance in _portfolioService.loadAssetBalances(
      network: network,
      identity: identity,
      accessToken: tokens.accessToken,
      assets: assets,
    )) {
      if (generation != _loadGeneration ||
          !mounted ||
          widget.selectedChain.network != network) {
        return;
      }
      if (!balance.isNative && _isHidden(balance, hidden)) {
        continue;
      }
      byId[WalletAsset(
            network: network,
            symbol: balance.symbol,
            name: balance.assetName,
            decimals: balance.decimals,
            isNative: balance.isNative,
            tokenAddress: balance.tokenAddress,
          ).id] =
          balance;
      final ordered = assets
          .where(
            (a) =>
                !(!a.isNative &&
                    hidden.contains(a.tokenAddress?.toLowerCase())),
          )
          .map(
            (a) =>
                byId[a.id] ??
                WalletBalance(
                  chain: widget.selectedChain.label,
                  symbol: a.symbol,
                  assetName: a.name,
                  isNative: a.isNative,
                  address: identity.address,
                  decimals: a.decimals,
                  tokenAddress: a.tokenAddress,
                  balance: BigInt.zero,
                ),
          )
          .toList();
      setState(() => _displayBalances = ordered);
    }
  }

  Future<double?> _loadTotalBalance(
    Future<List<WalletBalance>> balances,
  ) async {
    try {
      return _valuationService.totalUsd(await balances);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showSendTokenPicker() async {
    final token = await showCupertinoModalPopup<TransferToken>(
      context: context,
      builder: (_) => _SendTokenPicker(
        palette: widget.palette,
        tokens: _transferTokensForChain(widget.selectedChain),
      ),
    );
    if (token != null && mounted) widget.onSendTokenSelected(token);
  }

  void _dismissWalletActions() {
    _walletActionsEntry?.remove();
    _walletActionsEntry = null;
  }

  @override
  void dispose() {
    _dismissWalletActions();
    _portfolioService.close();
    _valuationService.dispose();
    super.dispose();
  }

  void _showWalletActions() {
    if (_walletActionsEntry != null) {
      _dismissWalletActions();
      return;
    }

    _walletActionsEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissWalletActions,
            ),
          ),
          CompositedTransformFollower(
            link: _walletActionsLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, -7),
            child: Semantics(
              container: true,
              label: '钱包操作菜单',
              child: Container(
                width: 154,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.palette.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WalletMenuItem(
                      icon: CupertinoIcons.refresh,
                      label: '刷新列表',
                      palette: widget.palette,
                      onPressed: () {
                        _dismissWalletActions();
                        _reloadBalances();
                      },
                    ),
                    _WalletMenuItem(
                      icon: CupertinoIcons.add,
                      label: '添加代币',
                      palette: widget.palette,
                      onPressed: () {
                        _dismissWalletActions();
                        widget.onOpen(AcoScreen.addTokenV2);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_walletActionsEntry!);
  }

  @override
  Widget build(BuildContext context) {
    // The wallet artboard intentionally uses light action cards on black.
    final actionSurface = _walletActionSurface;
    final actionForeground = _walletActionForeground;
    final networkLabel = widget.selectedChain.displayLabel;
    // Wallet dimensions are fixed logical pixels. Flex layouts below
    // provide adaptation without scaling an entire artboard at runtime.
    const scale = .672;
    final totalBalanceTextStyle = TextStyle(
      color: widget.palette.primaryText,
      fontSize: 56 * scale,
      fontWeight: FontWeight.w700,
    );
    return ColoredBox(
      color: widget.palette.dark
          ? const Color(0xFF000000)
          : widget.palette.background,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              49 * scale,
              _rootPageTopInset * scale,
              53.5 * scale,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AcoRootHeader(
                  palette: widget.palette,
                  onOpen: widget.onOpen,
                  scale: scale,
                ),
                // Keep the wallet selector close to the top action row while
                // preserving a clear separation between the two controls.
                SizedBox(height: 40 * scale),
                SizedBox(
                  height: 44 * scale,
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: '切换钱包',
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () =>
                                widget.onOpen(AcoScreen.walletSwitcher),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(width: 10.9 * scale),
                                SizedBox(
                                  width: _walletHeaderWalletIconWidth * scale,
                                  height: _walletHeaderWalletIconHeight * scale,
                                  child: SvgPicture.asset(
                                    'assets/icons/wallet_selector_figma.svg',
                                  ),
                                ),
                                SizedBox(width: 16 * scale),
                                Flexible(
                                  child: Transform.translate(
                                    offset: Offset(0, 6 * scale),
                                    child: Text(
                                      widget.walletName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _walletHeaderMuted,
                                        fontSize: 32 * scale,
                                        fontWeight: FontWeight.w400,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8 * scale),
                                SizedBox(
                                  height: _walletHeaderWalletIconHeight * scale,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Transform.translate(
                                      offset: Offset(0, 6 * scale),
                                      child: SizedBox(
                                        width:
                                            _walletHeaderWalletArrowWidth *
                                            scale,
                                        height:
                                            _walletHeaderWalletArrowHeight *
                                            scale,
                                        child: SvgPicture.asset(
                                          'assets/icons/wallet_selector_chevron_figma.svg',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Semantics(
                        button: true,
                        label: '切换网络',
                        child: GestureDetector(
                          key: const Key('wallet-network-selector'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onOpen(AcoScreen.walletChains),
                          child: Transform.translate(
                            offset: Offset(0, -4 * scale),
                            child: SizedBox(
                              width: _walletHeaderNetworkWidth * scale,
                              child: Row(
                                children: [
                                  Container(
                                    width: 11 * scale,
                                    height: 11 * scale,
                                    decoration: const BoxDecoration(
                                      color: _walletHeaderLime,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6.52 * scale),
                                  Expanded(
                                    child: Text(
                                      networkLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _walletHeaderMuted,
                                        fontSize: 20.16 * scale,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18 * scale),
                Transform.translate(
                  offset: Offset(6 * scale, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('\$', style: totalBalanceTextStyle),
                      SizedBox(width: 21.45 * scale),
                      FutureBuilder<double?>(
                        future: _totalBalanceFuture,
                        builder: (context, snapshot) => Text(
                          (snapshot.data ?? 0).toStringAsFixed(2),
                          style: totalBalanceTextStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 43 * scale),
                Padding(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: '发送资产',
                          palette: widget.palette,
                          height: 36,
                          fontSize: 15,
                          backgroundColor: _accentGreen,
                          foregroundColor: _walletActionForeground,
                          radius: 8,
                          fontWeight: FontWeight.w500,
                          onPressed: _showSendTokenPicker,
                        ),
                      ),
                      const SizedBox(width: 39),
                      Expanded(
                        child: _OutlineButton(
                          label: '接收资产',
                          icon: null,
                          palette: widget.palette,
                          height: 36,
                          fontSize: 15,
                          backgroundColor: actionSurface,
                          foregroundColor: actionForeground,
                          radius: 8,
                          fontWeight: FontWeight.w500,
                          onPressed: () => widget.onOpen(AcoScreen.receive),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: EdgeInsets.zero,
                  child: Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: '闪兑',
                          icon: CupertinoIcons.bolt_fill,
                          palette: widget.palette,
                          height: 36,
                          fontSize: 15,
                          leadingImageAsset:
                              'assets/icons/wallet_swap_action.png',
                          iconSize: 14.5,
                          iconGap: 12,
                          backgroundColor: actionSurface,
                          foregroundColor: actionForeground,
                          radius: 8,
                          fontWeight: FontWeight.w500,
                          onPressed: () =>
                              showAcoAlertNotice(context, '提示', 'comming soon'),
                        ),
                      ),
                      const SizedBox(width: 39),
                      Expanded(
                        child: _OutlineButton(
                          label: '扫码',
                          icon: CupertinoIcons.qrcode_viewfinder,
                          palette: widget.palette,
                          height: 36,
                          fontSize: 15,
                          leadingAsset: 'assets/icons/source_scan.svg',
                          iconSize: 13.5,
                          iconGap: 12,
                          backgroundColor: actionSurface,
                          foregroundColor: actionForeground,
                          radius: 8,
                          fontWeight: FontWeight.w500,
                          onPressed: () => widget.onOpen(AcoScreen.scan),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 45),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 47, right: 16),
            child: _WalletTabs(
              selected: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
              addButtonLink: _walletActionsLink,
              onAddToken: _showWalletActions,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 5, 16, 15),
              itemCount: _displayBalances.length,
              itemBuilder: (context, index) {
                final balance = _displayBalances[index];
                final rawAmount = balance.balance ?? BigInt.zero;
                final amount = rawAmount == BigInt.zero
                    ? '0.00'
                    : formatChainAmount(rawAmount, decimals: balance.decimals);
                return _WalletAssetRow(
                  palette: widget.palette,
                  symbol: balance.symbol,
                  title: balance.assetName,
                  amount: amount,
                  value: '≈0.00 USD',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
