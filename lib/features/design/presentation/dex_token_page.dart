part of 'aco_design_shell.dart';

Color _dexChangeColor(String change) =>
    change.trim().startsWith('-') ? _danger : _lime;

class _DexTokenPage extends StatefulWidget {
  const _DexTokenPage({
    required this.palette,
    required this.selectedChain,
    this.walletIdentity,
    this.avatarUrl = '',
    required this.onOpen,
    this.initialSection = 1,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final String avatarUrl;
  final ValueChanged<AcoScreen> onOpen;
  final int initialSection;
  @override
  State<_DexTokenPage> createState() => _DexTokenPageState();
}

class _DexTokenPageState extends State<_DexTokenPage> {
  bool ethFirst = true;
  List<DexRankingToken> _hotTokens = const [];
  bool _loadingTokens = true;
  String _rankingType = 'binance_alpha';
  String _rankingChain = 'all';
  int _selectedSection = 1;
  int _tokenRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _loadHotTokens();
  }

  @override
  void didUpdateWidget(covariant _DexTokenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection && mounted) {
      setState(() => _selectedSection = widget.initialSection);
    }
  }

  Future<void> _loadHotTokens() async {
    final requestId = ++_tokenRequestId;
    final type = _rankingType;
    final filter = _rankingChain;
    final isStock = type == 'xstock';
    final filterName = isStock ? 'slug' : 'chain';
    final interval = isStock ? '24h' : '5m';
    debugPrint(
      '[HotTokensPage] start requestId=$requestId type=$type '
      '$filterName=$filter interval=$interval',
    );
    final client = DexRankingApiClient();
    try {
      final tokens = await client.hotTokens(
        type: type,
        chain: isStock ? 'all' : filter,
        slug: isStock ? filter : null,
        interval: interval,
      );
      final stale = requestId != _tokenRequestId;
      debugPrint(
        '[HotTokensPage] finish requestId=$requestId stale=$stale '
        'tokens=${tokens.length} '
        'symbols=${tokens.take(5).map((token) => token.symbol).join(',')}',
      );
      if (mounted && requestId == _tokenRequestId) {
        setState(() => _hotTokens = tokens);
      }
    } catch (_) {
      // The page remains usable while a network request is unavailable.
    } finally {
      client.close();
      if (mounted && requestId == _tokenRequestId) {
        setState(() => _loadingTokens = false);
      }
    }
  }

  void _openToken(DexRankingToken token) {
    Navigator.of(context).push<void>(
      _AcoPageRoute<void>(
        builder: (_) => _DexTokenDetailPage(
          palette: widget.palette,
          token: token,
          selectedChain: widget.selectedChain,
          walletIdentity: widget.walletIdentity,
          onOpen: widget.onOpen,
        ),
      ),
    );
  }

  void _openSearchPage() {
    Navigator.of(context).push<void>(
      _AcoPageRoute<void>(
        builder: (_) => _DexSearchPage(
          palette: widget.palette,
          searchChain: 'all',
          selectedChain: widget.selectedChain,
          walletIdentity: widget.walletIdentity,
          onOpen: widget.onOpen,
        ),
      ),
    );
  }

  void _selectRankingChain(String chain) {
    if (_rankingChain == chain) return;
    final filterName = _rankingType == 'xstock' ? 'slug' : 'chain';
    debugPrint(
      '[HotTokensPage] filter changed type=$_rankingType '
      '$filterName=$_rankingChain->$chain',
    );
    setState(() {
      _rankingChain = chain;
      _loadingTokens = true;
      _hotTokens = const [];
    });
    _loadHotTokens();
  }

  void _selectSection(int section) {
    if (_selectedSection == section) return;

    final isStock = section == 3;
    final type = isStock ? 'xstock' : 'binance_alpha';
    final typeChanged = _rankingType != type;
    setState(() {
      _selectedSection = section;
      if (typeChanged) {
        _rankingType = type;
        _rankingChain = 'all';
        _loadingTokens = true;
        _hotTokens = const [];
      }
      if (isStock) _rankingChain = 'all';
    });
    if (typeChanged || isStock) _loadHotTokens();
  }

  void _selectRankingType(String type) {
    if (_rankingType == type) return;
    final chain =
        type == 'picks' && (_rankingChain == 'all' || _rankingChain == 'eth')
        ? 'sol'
        : _rankingChain;
    setState(() {
      _rankingType = type;
      _rankingChain = chain;
      _loadingTokens = true;
      _hotTokens = const [];
    });
    _loadHotTokens();
  }

  Widget _buildHotTokenList(AcoPalette palette) {
    final horizontalPadding = _selectedSection == 0 ? 10.0 : 15.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _DexSectionTabs(
              palette: palette,
              selectedSection: _selectedSection,
              onChanged: _selectSection,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            8,
            horizontalPadding,
            24,
          ),
          sliver: _DexHotTokenList(
            palette: palette,
            tokens: _hotTokens,
            loading: _loadingTokens,
            selectedType: _rankingType,
            isStock: _selectedSection == 3,
            onRefresh: _loadHotTokens,
            onTypeSelected: _selectRankingType,
            selectedChain: _rankingChain,
            onChainSelected: _selectRankingChain,
            onSelected: _openToken,
            onSearchTap: _openSearchPage,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      children: [
        Expanded(
          child: _selectedSection == 2
              ? _HyperliquidContractPage(
                  palette: palette,
                  walletIdentity: widget.walletIdentity,
                  selectedChain: widget.selectedChain,
                  onSectionChanged: _selectSection,
                )
              : _selectedSection == 0
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 24),
                  children: [
                    _DexSectionTabs(
                      palette: palette,
                      selectedSection: _selectedSection,
                      onChanged: _selectSection,
                    ),
                    const SizedBox(height: 24),
                    _DexSwapContent(
                      palette: palette,
                      selectedChain: widget.selectedChain,
                      onOpen: widget.onOpen,
                      walletIdentity: widget.walletIdentity,
                      ethFirst: ethFirst,
                      onEthFirstChanged: (value) =>
                          setState(() => ethFirst = value),
                      recentRecord: null,
                    ),
                  ],
                )
              : _buildHotTokenList(palette),
        ),
      ],
    );
  }
}

class _HyperliquidContractPage extends StatefulWidget {
  const _HyperliquidContractPage({
    required this.palette,
    required this.walletIdentity,
    required this.selectedChain,
    required this.onSectionChanged,
  });

  final AcoPalette palette;
  final WalletIdentity? walletIdentity;
  final _WalletChain selectedChain;
  final ValueChanged<int> onSectionChanged;

  @override
  State<_HyperliquidContractPage> createState() =>
      _HyperliquidContractPageState();
}

class _HyperliquidContractPageState extends State<_HyperliquidContractPage> {
  List<HyperliquidMarket> _markets = const [];
  bool _loading = true;
  String? _error;
  HyperliquidApiClient? _client;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  @override
  void dispose() {
    _client?.close();
    _searchController.dispose();
    super.dispose();
  }

  List<HyperliquidMarket> get _visibleMarkets {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _markets;
    return _markets
        .where((market) => market.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _loadMarkets({bool showLoading = true}) async {
    _client?.close();
    final client = HyperliquidApiClient();
    _client = client;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final markets = await client.loadMarkets();
      if (!mounted || _client != client) return;
      markets.removeWhere((market) => market.isDelisted);
      markets.sort(
        (left, right) => (right.volume24h ?? 0).compareTo(left.volume24h ?? 0),
      );
      setState(() => _markets = markets);
    } catch (error) {
      if (mounted && _client == client) {
        setState(() => _error = 'Hyperliquid 合约行情暂时不可用');
      }
    } finally {
      if (mounted && _client == client) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final markets = _visibleMarkets;
    return AcoRefreshIndicator(
      palette: palette,
      onRefresh: () => _loadMarkets(showLoading: false),
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(15, 4, 15, 24),
        children: [
          _DexSectionTabs(
            palette: palette,
            selectedSection: 2,
            onChanged: widget.onSectionChanged,
          ),
          const SizedBox(height: 8),
          _DexSearchField(
            key: const Key('dex-contract-search'),
            palette: palette,
            controller: _searchController,
            placeholder: '搜索合约名称或代码',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          if (!_loading && _error == null && markets.isNotEmpty) ...[
            _HyperliquidMarketHeader(palette: palette),
            const SizedBox(height: 4),
          ],
          if (_loading)
            const Center(child: CupertinoActivityIndicator())
          else if (_error != null)
            _buildMessage(palette, _error!, true)
          else if (_markets.isEmpty)
            _buildMessage(palette, '暂无可用合约', false)
          else if (markets.isEmpty)
            _buildMessage(palette, '未找到匹配合约', false)
          else
            ...markets.map((market) => _buildMarketRow(palette, market)),
        ],
      ),
    );
  }

  Widget _buildMessage(AcoPalette palette, String text, bool retry) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(text, style: TextStyle(color: palette.mutedText)),
        if (retry) ...[
          const SizedBox(height: 12),
          CupertinoButton(onPressed: _loadMarkets, child: const Text('重试')),
        ],
      ],
    );
  }

  Widget _buildMarketRow(AcoPalette palette, HyperliquidMarket market) {
    return _HyperliquidMarketRow(
      palette: palette,
      market: market,
      onPressed: () => Navigator.of(context).push<void>(
        _AcoPageRoute<void>(
          builder: (_) => _HyperliquidContractTradePage(
            palette: palette,
            market: market,
            walletIdentity: widget.walletIdentity,
            defaultNetwork: widget.selectedChain.network,
          ),
        ),
      ),
    );
  }
}

class _HyperliquidMarketRow extends StatelessWidget {
  const _HyperliquidMarketRow({
    required this.palette,
    required this.market,
    required this.onPressed,
  });

  final AcoPalette palette;
  final HyperliquidMarket market;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final change = market.changePercent;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 15),
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              flex: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: market.name,
                          style: TextStyle(color: palette.primaryText),
                        ),
                        TextSpan(
                          text: '-USDC',
                          style: TextStyle(color: palette.mutedText),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (market.maxLeverage > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${market.maxLeverage}x',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 9,
              child: _HyperliquidMarketMetric(
                palette: palette,
                primary: _formatHyperliquidCurrency(market.volume24h),
                secondary: _formatHyperliquidCurrency(
                  market.openInterestNotional,
                ),
              ),
            ),
            Expanded(
              flex: 8,
              child: _HyperliquidMarketMetric(
                palette: palette,
                primary: _formatHyperliquidPrice(market.markPrice),
                secondary: _formatHyperliquidChange(change),
                secondaryColor: _hyperliquidChangeColor(change, palette),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _hyperliquidChangeColor(double? change, AcoPalette palette) {
  if (change == null) return palette.mutedText;
  return change >= 0 ? _lime : _danger;
}

class _HyperliquidMarketHeader extends StatelessWidget {
  const _HyperliquidMarketHeader({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(flex: 12, child: _label('市场', TextAlign.left)),
      Expanded(flex: 9, child: _label('成交量\n合约持仓量', TextAlign.right)),
      Expanded(flex: 8, child: _label('最后价格\n24小时变化', TextAlign.right)),
    ],
  );

  Widget _label(String text, TextAlign align) => Text(
    text,
    textAlign: align,
    style: TextStyle(color: palette.mutedText, fontSize: 14, height: 1.3),
  );
}

class _HyperliquidMarketMetric extends StatelessWidget {
  const _HyperliquidMarketMetric({
    required this.palette,
    required this.primary,
    required this.secondary,
    this.secondaryColor,
  });

  final AcoPalette palette;
  final String primary;
  final String secondary;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        primary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        secondary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: secondaryColor ?? palette.mutedText,
          fontSize: 14,
        ),
      ),
    ],
  );
}

String _formatHyperliquidPrice(double? value) {
  if (value == null) return '--';
  final int decimals;
  if (value >= 1000) {
    decimals = 1;
  } else if (value >= 1) {
    decimals = 2;
  } else {
    decimals = 6;
  }
  return _trimTrailingZeros(value.toStringAsFixed(decimals));
}

String _formatHyperliquidCurrency(double? value) =>
    value == null ? '--' : formatDexCompactCurrency('$value');

String _formatHyperliquidChange(double? value) => value == null
    ? '--'
    : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}%';

class _HyperliquidTokenIcon extends StatelessWidget {
  const _HyperliquidTokenIcon({
    required this.symbol,
    required this.palette,
    required this.size,
  });

  final String symbol;
  final AcoPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = symbol.toLowerCase();
    const localSymbols = {
      'atom',
      'avax',
      'bnb',
      'btc',
      'doge',
      'dot',
      'eth',
      'ltc',
      'matic',
      'sol',
      'trx',
      'xrp',
    };
    final fallback = _HyperliquidTokenFallback(
      symbol: symbol,
      palette: palette,
      size: size,
    );
    if (localSymbols.contains(normalized)) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset('assets/icons/crypto/tokens/$normalized.svg'),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.network(
        'https://app.hyperliquid.xyz/coins/${Uri.encodeComponent(symbol)}.svg',
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _HyperliquidTokenFallback extends StatelessWidget {
  const _HyperliquidTokenFallback({
    required this.symbol,
    required this.palette,
    required this.size,
  });

  final String symbol;
  final AcoPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      shape: BoxShape.circle,
    ),
    child: Text(
      symbol.isEmpty ? '?' : symbol.characters.first.toUpperCase(),
      style: TextStyle(
        color: palette.primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DexTokenDetailPage extends StatefulWidget {
  const _DexTokenDetailPage({
    required this.palette,
    required this.token,
    required this.selectedChain,
    this.walletIdentity,
    required this.onOpen,
  });

  final AcoPalette palette;
  final DexRankingToken token;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_DexTokenDetailPage> createState() => _DexTokenDetailPageState();
}

class _DexTokenDetailPageState extends State<_DexTokenDetailPage> {
  static const _maxChartCandles = 500;

  String _selectedRange = '5分';
  int _selectedDetailTab = 0;
  List<KLineEntity> _chartData = const [];
  bool _loadingChart = false;
  int _chartRequestId = 0;
  DexRankingToken? _tokenInfo;
  List<DexSwapRecord> _tradeActivities = const [];
  bool _loadingTradeActivities = false;
  List<DexSwapRecord> _myTradeActivities = const [];
  bool _loadingMyTradeActivities = false;
  WalletIdentity? _resolvedWalletIdentity;
  double? _realtimePrice;
  DexKlineRealtimeClient? _realtimeClient;
  StreamSubscription<DexPriceUpdate>? _realtimeSubscription;
  final _chartController = KChartController();

  DexRankingToken get _displayToken => _tokenInfo ?? widget.token;

  WalletIdentity? get _activeWalletIdentity =>
      widget.walletIdentity ?? _resolvedWalletIdentity;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCandlesThenConnect(_selectedRange));
    _loadDexScreenerTokenInfo();
    unawaited(_loadTradeActivities());
    unawaited(_loadMyTradeActivities());
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtimeClient?.close();
    super.dispose();
  }

  Future<void> _loadTradeActivities() async {
    if (mounted) setState(() => _loadingTradeActivities = true);
    final tokens = await SecureAccountTokenStore().read();
    if (tokens == null) {
      if (mounted) setState(() => _loadingTradeActivities = false);
      return;
    }
    final api = AccountApiClient();
    try {
      final rows = await api.listDexTrades(
        tokenAddress: widget.token.address,
        token: tokens.accessToken,
      );
      final tokenAddress = widget.token.address.toLowerCase();
      final poolAddress = widget.token.pool.toLowerCase();
      final matchingRows = rows.where((row) {
        final pool = '${row['pool'] ?? ''}'.toLowerCase();
        final base = '${row['base_token'] ?? ''}'.toLowerCase();
        final quote = '${row['quote_token'] ?? ''}'.toLowerCase();
        return pool == poolAddress ||
            (tokenAddress.isNotEmpty &&
                (base == tokenAddress || quote == tokenAddress));
      });
      final records = matchingRows
          .map(_tradeActivityFromRow)
          .toList(growable: false);
      if (mounted) setState(() => _tradeActivities = records);
    } catch (error) {
      debugPrint('[DexDetail] trade activity load failed error=$error');
    } finally {
      api.close();
      if (mounted) setState(() => _loadingTradeActivities = false);
    }
  }

  Future<void> _refreshDetail() async {
    await Future.wait([
      _loadTradeActivities(),
      _loadDexScreenerTokenInfo(),
      _loadMyTradeActivities(),
    ]);
  }

  Future<void> _loadMyTradeActivities() async {
    final identity = await _resolveWalletIdentity();
    final tokens = await SecureAccountTokenStore().read();
    if (identity == null || tokens == null) {
      if (mounted) setState(() => _myTradeActivities = const []);
      return;
    }
    if (mounted) setState(() => _loadingMyTradeActivities = true);
    final api = AccountApiClient();
    try {
      final rows = await api.listDexTrades(
        wallet: identity.address,
        tokenAddress: widget.token.address,
        token: tokens.accessToken,
      );
      if (mounted) {
        setState(() {
          _myTradeActivities = rows
              .map(_tradeActivityFromRow)
              .toList(growable: false);
        });
      }
    } catch (error) {
      debugPrint('[DexDetail] current user trades load failed error=$error');
    } finally {
      api.close();
      if (mounted) setState(() => _loadingMyTradeActivities = false);
    }
  }

  Future<WalletIdentity?> _resolveWalletIdentity() async {
    final configuredIdentity = widget.walletIdentity;
    if (configuredIdentity != null) return configuredIdentity;

    final storedIdentity = await WalletPreferences.walletIdentity();
    if (mounted && storedIdentity != null) {
      setState(() => _resolvedWalletIdentity = storedIdentity);
    }
    return storedIdentity;
  }

  DexSwapRecord _tradeActivityFromRow(Map<String, dynamic> row) {
    final network = '${row['network'] ?? widget.token.chain}';
    final fromAddress = '${row['base_token'] ?? ''}';
    final toAddress = '${row['quote_token'] ?? ''}';
    final rawSide = '${row['side'] ?? ''}'.toLowerCase();
    final side = switch (rawSide) {
      'sell' || 'buy' => rawSide,
      _ when fromAddress.toLowerCase() == widget.token.address.toLowerCase() =>
        'sell',
      _ => 'buy',
    };
    return DexSwapRecord(
      source: 'app',
      network: network,
      fromAmount: '${row['base_amount'] ?? ''}',
      fromSymbol: _recordTokenSymbol(network, fromAddress),
      toAmount: '${row['quote_amount'] ?? ''}',
      toSymbol: _recordTokenSymbol(network, toAddress),
      fromAddress: fromAddress,
      toAddress: toAddress,
      status: '${row['status'] ?? 'pending'}',
      side: side,
      createdAt:
          DateTime.tryParse('${row['timestamp'] ?? ''}') ?? DateTime.now(),
      nickname: '${row['nickname'] ?? '匿名用户'}',
      avatarUrl: '${row['avatar_url'] ?? ''}',
    );
  }

  Future<void> _connectRealtime(String range) async {
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    await _realtimeClient?.close();
    _realtimeClient = null;
    if (widget.token.pool.trim().isEmpty || !mounted) return;

    final client = DexKlineRealtimeClient();
    _realtimeClient = client;
    try {
      final updates = await client.subscribe(
        widget.token,
        interval: _klineInterval(range),
      );
      if (!mounted || _realtimeClient != client) {
        await client.close();
        return;
      }
      _realtimeSubscription = updates.listen(
        _applyRealtimePrice,
        onError: (Object error) {
          debugPrint(
            '[DexKlineWS] update failed symbol=${widget.token.symbol} '
            'error=$error',
          );
        },
      );
    } catch (error) {
      debugPrint(
        '[DexKlineWS] connect failed symbol=${widget.token.symbol} '
        'error=$error',
      );
      await client.close();
    }
  }

  Future<void> _loadCandlesThenConnect(String range) async {
    await _loadCandles(range);
    if (mounted && _selectedRange == range) {
      await _connectRealtime(range);
    }
  }

  void _applyRealtimePrice(DexPriceUpdate update) {
    if (!mounted) return;
    final interval = _klineDuration(_selectedRange);
    final timestamp =
        (update.timestamp ~/ interval.inMilliseconds) * interval.inMilliseconds;
    final precision = _chartPrecisionForPrice(update.price);
    final price = _roundChartPrice(update.price, precision);
    final updated = [..._chartData];
    final index = updated.indexWhere((value) => value.time == timestamp);
    final item = index >= 0
        ? KLineEntity.fromCustom(
            open: updated[index].open,
            close: price,
            high: math.max(updated[index].high, price),
            low: math.min(updated[index].low, price),
            vol: updated[index].vol,
            time: timestamp,
          )
        : KLineEntity.fromCustom(
            open: price,
            close: price,
            high: price,
            low: price,
            vol: 0,
            time: timestamp,
          );
    if (index >= 0) {
      updated[index] = item;
    } else {
      updated.add(item);
      updated.sort(
        (left, right) => (left.time ?? 0).compareTo(right.time ?? 0),
      );
    }
    final bounded = _limitChartData(updated);
    DataUtil.calculate(bounded);
    setState(() {
      _chartData = bounded;
      _realtimePrice = update.price;
    });
  }

  Future<void> _loadDexScreenerTokenInfo() async {
    final client = DexRankingApiClient();
    try {
      debugPrint(
        '[DexDetail] enter symbol=${widget.token.symbol} '
        'chain=${widget.token.chain} pool=${widget.token.pool}',
      );
      final token = await client.dexScreenerTokenInfo(widget.token);
      if (mounted && token != null) setState(() => _tokenInfo = token);
    } catch (error) {
      debugPrint('[DexScreener] detail load failed error=$error');
    } finally {
      client.close();
    }
  }

  Future<void> _loadCandles(String range) async {
    final requestId = ++_chartRequestId;
    if (mounted) {
      setState(() {
        _loadingChart = true;
        _chartData = const [];
      });
    }

    final client = DexRankingApiClient();
    try {
      final candles = await client.klineHistory(
        widget.token,
        interval: _klineInterval(range),
      );
      final orderedCandles = [...candles]
        ..sort((left, right) => left.timestamp.compareTo(right.timestamp));
      final precision = _chartPrecision(orderedCandles);
      final data = orderedCandles
          .map(
            (candle) => KLineEntity.fromCustom(
              open: _roundChartPrice(candle.open, precision),
              close: _roundChartPrice(candle.close, precision),
              high: _roundChartPrice(candle.high, precision),
              low: _roundChartPrice(candle.low, precision),
              vol: candle.volume,
              time: candle.timestamp,
            ),
          )
          .toList(growable: true);
      final bounded = _limitChartData(data);
      DataUtil.calculate(bounded);
      if (mounted && requestId == _chartRequestId) {
        setState(() => _chartData = bounded);
      }
    } catch (error) {
      debugPrint(
        '[DexKline] load failed symbol=${widget.token.symbol} '
        'range=$range error=$error',
      );
    } finally {
      client.close();
      if (mounted && requestId == _chartRequestId) {
        setState(() => _loadingChart = false);
      }
    }
  }

  void _selectRange(String range) {
    if (_selectedRange == range) return;
    setState(() {
      _selectedRange = range;
    });
    unawaited(_loadCandlesThenConnect(range));
  }

  void _showTradeSheet(bool buying) {
    showCupertinoModalPopup<String>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: .58),
      builder: (_) => _DexTradeSheet(
        palette: widget.palette,
        token: _displayToken,
        buying: buying,
        selectedChain: widget.selectedChain,
        walletIdentity: widget.walletIdentity,
      ),
    ).then((hash) {
      if (hash != null && mounted) _showTradeSubmitted(hash);
    });
  }

  void _showTradeSubmitted(String hash) {
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: .58),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF173E0C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.check_mark,
                    color: Color(0xFF8BEA25),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '交易已提交',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  '已发送到区块链，等待网络确认',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('交易哈希', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 5),
                      Text(
                        hash.isEmpty ? '等待节点返回交易标识' : hash,
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          color: widget.palette.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: hash.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: hash),
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                        child: Text(
                          '复制哈希',
                          style: TextStyle(color: widget.palette.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: widget.palette.accent,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: widget.palette.dark ? _black : _white,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _klineInterval(String range) => switch (range) {
    '5分' => '5m',
    '15分' => '15m',
    '1小时' => '1h',
    '4小时' => '4h',
    '12小时' => '12h',
    '1天' => '1d',
    _ => '5m',
  };

  Duration _klineDuration(String range) => switch (range) {
    '5分' => const Duration(minutes: 5),
    '15分' => const Duration(minutes: 15),
    '1小时' => const Duration(hours: 1),
    '4小时' => const Duration(hours: 4),
    '12小时' => const Duration(hours: 12),
    '1天' => const Duration(days: 1),
    _ => const Duration(minutes: 5),
  };

  List<KLineEntity> _limitChartData(List<KLineEntity> data) {
    if (data.length <= _maxChartCandles) return data;
    return data.sublist(data.length - _maxChartCandles);
  }

  int _chartPrecision(Iterable<DexKline> candles) {
    var maxPrice = 0.0;
    for (final candle in candles) {
      maxPrice = math.max(
        maxPrice,
        math.max(
          candle.open.abs(),
          math.max(
            candle.close.abs(),
            math.max(candle.high.abs(), candle.low.abs()),
          ),
        ),
      );
    }
    return _chartPrecisionForPrice(maxPrice);
  }

  int _chartPrecisionForPrice(double price) {
    if (price >= 1) return 4;
    if (price >= .01) return 6;
    if (price >= .0001) return 8;
    return 10;
  }

  double _roundChartPrice(double value, int precision) =>
      double.parse(value.toStringAsFixed(precision));

  Widget _buildTokenDetails(AcoPalette palette) {
    final token = _displayToken;
    final price = _realtimePrice?.toString() ?? token.price;
    final marketCap = _tokenInfo?.marketCap ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final marketWidth = (constraints.maxWidth * .28).clamp(
              135.0,
              180.0,
            );
            final priceWidth = constraints.maxWidth - marketWidth - 12;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: priceWidth,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDexChange(token.change),
                          style: TextStyle(
                            color: _dexChangeColor(token.change),
                            fontSize: AcoTypography.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatDexPrice(price),
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.metric,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MarketStat(
                      label: '市值',
                      value: formatDexCompactCurrency(marketCap),
                      palette: palette,
                      width: marketWidth,
                    ),
                    const SizedBox(height: 10),
                    _MarketStat(
                      label: '流动性',
                      value: formatDexCompactCurrency(token.liquidity),
                      palette: palette,
                      width: marketWidth,
                    ),
                    const SizedBox(height: 10),
                    _MarketStat(
                      label: '24h交易额',
                      value: formatDexCompactCurrency(token.volume),
                      palette: palette,
                      width: marketWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _TimeRangeSelector(
          palette: palette,
          ranges: const ['5分', '15分', '1小时', '4小时', '12小时', '1天'],
          selectedRange: _selectedRange,
          onChanged: _selectRange,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: _chartData.isEmpty
              ? Center(
                  child: _loadingChart
                      ? const CupertinoActivityIndicator()
                      : Text(
                          '暂无K线数据',
                          style: TextStyle(color: palette.mutedText),
                        ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    KChartWidget(
                      _chartData,
                      controller: _chartController,
                      xFrontPadding: 24,
                      isTrendLine: false,
                      mainState: MainState.MA,
                      secondaryState: SecondaryState.NONE,
                      volHidden: true,
                      showInfoDialog: false,
                      numberFormatter: formatDexChartPrice,
                      hideGrid: false,
                      enableTheme: false,
                      enablePerformanceMode: true,
                      chartColors: ChartColors.dark().copyWith(
                        bgColor: [palette.background, palette.background],
                        gridColor: palette.border,
                        defaultTextColor: palette.mutedText,
                        nowPriceUpColor: _lime,
                        nowPriceTextColor: _black,
                      ),
                      chartStyle: ChartStyle().copyWith(
                        pointWidth: 7,
                        candleWidth: 5,
                        candleLineWidth: 1.2,
                        topPadding: 12,
                        bottomPadding: 18,
                        childPadding: 8,
                        gridRows: 3,
                        gridColumns: 4,
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Text(
                          'ACO',
                          style: TextStyle(
                            color: palette.mutedText.withValues(alpha: .12),
                            fontSize: 140,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTradeActivityRefresh(AcoPalette palette) => AcoRefreshIndicator(
    palette: palette,
    onRefresh: _refreshDetail,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
      children: [
        _DexTradeActivityCard(
          palette: palette,
          token: _displayToken,
          records: _tradeActivities,
          loading: _loadingTradeActivities,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return CupertinoPageScaffold(
      backgroundColor: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            _DexDetailHeader(
              palette: palette,
              token: _displayToken,
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 20, 15, 0),
                      child: Column(
                        children: [
                          _buildTokenDetails(palette),
                          const SizedBox(height: 24),
                          _DexTokenDetailTabs(
                            palette: palette,
                            selected: _selectedDetailTab,
                            onChanged: (index) =>
                                setState(() => _selectedDetailTab = index),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
                body: _selectedDetailTab == 0
                    ? _buildTradeActivityRefresh(palette)
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
                        children: [
                          _DexTradeActivityCard(
                            palette: palette,
                            token: _displayToken,
                            records: _myTradeActivities,
                            loading: _loadingMyTradeActivities,
                            emptyMessage: _activeWalletIdentity == null
                                ? '连接钱包后查看你的买入卖出记录'
                                : '暂无买入卖出记录',
                          ),
                        ],
                      ),
              ),
            ),
            _DexTradeActions(
              onBuy: () => _showTradeSheet(true),
              onSell: () => _showTradeSheet(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _DexDetailHeader extends StatelessWidget {
  const _DexDetailHeader({
    required this.palette,
    required this.token,
    required this.onPressed,
  });

  final AcoPalette palette;
  final DexRankingToken token;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        SizedBox(
          width: 44,
          child: Transform.translate(
            offset: const Offset(-8, 0),
            child: Semantics(
              container: true,
              button: true,
              label: '返回',
              child: SizedBox(
                width: 44,
                height: 44,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: onPressed,
                  child: Icon(
                    CupertinoIcons.back,
                    color: palette.primaryText,
                    size: 25,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _DexTokenDisplayIcon(token: token, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      token.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                  if (token.verified) ...[
                    const SizedBox(width: 8),
                    const _VerifiedTokenBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _shortDexAddress(token.address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 14,
                        height: 1,
                      ),
                    ),
                  ),
                  if (token.address.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(24, 24),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: token.address)),
                      child: Icon(
                        CupertinoIcons.doc_on_doc,
                        color: palette.mutedText,
                        size: 15,
                      ),
                    ),
                  ],
                  if (_dexTokenAge(token.createdAt) case final age?) ...[
                    const SizedBox(width: 8),
                    Text(
                      age,
                      style: TextStyle(color: palette.mutedText, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DexTokenDetailTabs extends StatelessWidget {
  const _DexTokenDetailTabs({
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  final AcoPalette palette;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _buildTab('交易动态', 0),
      const SizedBox(width: 20),
      _buildTab('持仓', 1),
    ],
  );

  Widget _buildTab(String label, int index) {
    final isSelected = selected == index;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () => onChanged(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF252525) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? _white : palette.mutedText,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: isSelected ? 28 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DexTradeActivityCard extends StatelessWidget {
  const _DexTradeActivityCard({
    required this.palette,
    required this.token,
    this.records = const [],
    this.loading = false,
    this.emptyMessage = '暂无交易动态',
  });

  final AcoPalette palette;
  final DexRankingToken token;
  final List<DexSwapRecord> records;
  final bool loading;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        child: Text(
          loading ? '加载中' : emptyMessage,
          style: TextStyle(color: palette.mutedText, fontSize: 13),
        ),
      );
    }
    return Column(
      children: [
        for (final record in records) ...[
          _buildRow(record),
          if (record != records.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildRow(DexSwapRecord record) {
    final fromAmount = _formatRecordAmount(
      record.fromAmount,
      record.network,
      record.fromAddress,
    );
    final toAmount = _formatRecordAmount(
      record.toAmount,
      record.network,
      record.toAddress,
    );
    final toIsUsdt = record.toSymbol.toUpperCase() == 'USDT';
    var usdtAmount = fromAmount;
    var tokenAmount = toAmount;
    if (toIsUsdt) {
      usdtAmount = toAmount;
      tokenAmount = fromAmount;
    }
    final usdtValue = double.tryParse(usdtAmount);
    final tokenValue = double.tryParse(tokenAmount);
    final cost = usdtValue != null && tokenValue != null && tokenValue > 0
        ? usdtValue / tokenValue
        : null;
    final tradeSummary = switch (record.status.toLowerCase()) {
      'failed' || 'reverted' => '交易失败',
      _ =>
        record.side == 'sell'
            ? '卖出 $tokenAmount，获得 $usdtAmount USDT'
            : '$usdtAmount USDT 买入 $tokenAmount',
    };
    final costSummary = cost == null ? '' : '成本价 ${_formatCost(cost)} USDT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF191919),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AcoAvatar(size: 36, imageUrl: record.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.nickname.isEmpty ? '匿名用户' : record.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(record),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _statusLabel(record),
                        style: TextStyle(
                          color: _statusTextColor(record),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _relativeRecordTime(record.createdAt),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tradeSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 16,
                        ),
                      ),
                      if (costSummary.isNotEmpty)
                        Text(
                          costSummary,
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(DexSwapRecord record) {
    switch (record.status.toLowerCase()) {
      case 'failed':
      case 'reverted':
        return '失败';
      case 'pending':
      case 'processing':
        return '处理中';
      default:
        return record.side == 'sell' ? '卖出' : '买入';
    }
  }

  Color _statusColor(DexSwapRecord record) {
    switch (record.status.toLowerCase()) {
      case 'failed':
      case 'reverted':
        return const Color(0xFF4A1D24);
      case 'pending':
      case 'processing':
        return const Color(0xFF3E3A19);
      default:
        return const Color(0xFF173E0C);
    }
  }

  Color _statusTextColor(DexSwapRecord record) {
    switch (record.status.toLowerCase()) {
      case 'failed':
      case 'reverted':
        return const Color(0xFFFF6B7A);
      case 'pending':
      case 'processing':
        return const Color(0xFFFFD866);
      default:
        return record.side == 'sell' ? const Color(0xFFFF6B7A) : palette.accent;
    }
  }

  String _formatCost(double value) {
    final digits = value >= 1 ? 6 : 10;
    return value
        .toStringAsFixed(digits)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

String _relativeRecordTime(DateTime value) {
  final minutes = DateTime.now().difference(value.toLocal()).inMinutes;
  if (minutes < 1) return '刚刚';
  if (minutes < 60) return '$minutes分钟前';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours小时前';
  final days = hours ~/ 24;
  return '$days天前';
}

class _DexSectionTabs extends StatelessWidget {
  const _DexSectionTabs({
    required this.palette,
    required this.selectedSection,
    required this.onChanged,
  });

  final AcoPalette palette;
  final int selectedSection;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(selectedSection == 0 ? 16 : 0, 0),
    child: _SectionTabs(
      palette: palette,
      labels: const ['闪兑&跨链', '代币', '合约', '股票'],
      selected: selectedSection,
      itemSpacing: 12,
      fontSize: 18,
      horizontalPadding: 8,
      showSelectedIndicator: true,
      onChanged: onChanged,
    ),
  );
}

class _DexSearchField extends StatelessWidget {
  const _DexSearchField({
    required this.palette,
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    super.key,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: palette.border),
    ),
    child: CupertinoTextField(
      controller: controller,
      onChanged: onChanged,
      onTapOutside: (_) => _dismissKeyboard(),
      placeholder: placeholder,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(CupertinoIcons.search, color: palette.mutedText, size: 18),
      ),
      clearButtonMode: OverlayVisibilityMode.editing,
      placeholderStyle: TextStyle(color: palette.mutedText, fontSize: 15),
      style: TextStyle(color: palette.primaryText, fontSize: 15),
      cursorColor: palette.accent,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(color: _transparent),
    ),
  );
}

class _DexSearchButton extends StatelessWidget {
  const _DexSearchButton({
    required this.palette,
    required this.placeholder,
    required this.onPressed,
    super.key,
  });

  final AcoPalette palette;
  final String placeholder;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    onPressed: onPressed,
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(CupertinoIcons.search, color: palette.mutedText, size: 18),
          const SizedBox(width: 8),
          Text(
            placeholder,
            style: TextStyle(color: palette.mutedText, fontSize: 15),
          ),
        ],
      ),
    ),
  );
}

class _DexHotTokenList extends StatelessWidget {
  const _DexHotTokenList({
    required this.palette,
    required this.tokens,
    required this.loading,
    required this.selectedType,
    required this.isStock,
    required this.selectedChain,
    required this.onRefresh,
    required this.onTypeSelected,
    required this.onChainSelected,
    required this.onSelected,
    required this.onSearchTap,
  });

  final AcoPalette palette;
  final List<DexRankingToken> tokens;
  final bool loading;
  final String selectedType;
  final bool isStock;
  final String selectedChain;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onTypeSelected;
  final ValueChanged<String> onChainSelected;
  final ValueChanged<DexRankingToken> onSelected;
  final VoidCallback onSearchTap;

  static const _categories = <(String, String?)>[
    ('热门', 'binance_alpha'),
    ('Meme', 'picks'),
  ];
  static const _chains = <(String, String)>[
    ('all', '全部'),
    ('eth', 'Ethereum'),
    ('sol', 'Solana'),
    ('bsc', 'BSC'),
  ];
  static const _memeChains = <(String, String)>[
    ('sol', 'Solana'),
    ('bsc', 'BSC'),
  ];

  List<(String, String)> get _availableFilters =>
      selectedType == 'picks' ? _memeChains : _chains;

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: tokens.isEmpty ? 1 : tokens.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) return _buildHeader();
      final token = tokens[index - 1];
      return _DexHotTokenRow(
        token: token,
        palette: palette,
        isStock: isStock,
        onTap: () => onSelected(token),
      );
    },
  );

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DexSearchButton(
        key: Key(isStock ? 'dex-stock-search' : 'dex-token-search'),
        palette: palette,
        placeholder: '搜索代币或股票',
        onPressed: onSearchTap,
      ),
      const SizedBox(height: 14),
      if (!isStock) ...[
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final type = category.$2;
              final selected = type == selectedType;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: type == null ? null : () => onTypeSelected(type),
                child: Align(
                  child: Text(
                    category.$1,
                    style: TextStyle(
                      color: selected ? palette.primaryText : palette.mutedText,
                      fontSize: 18,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableFilters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final chain = _availableFilters[index];
              final selected = chain.$1 == selectedChain;
              return CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                color: selected ? palette.surfaceRaised : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                onPressed: () => onChainSelected(chain.$1),
                child: Text(
                  chain.$2,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 17,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
      ],
      Row(
        children: [
          Text(
            isStock ? '公司｜币种' : '市值｜成交额',
            style: TextStyle(color: palette.mutedText, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '价格｜涨跌幅',
            style: TextStyle(color: palette.mutedText, fontSize: 14),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (loading && tokens.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 88),
          child: Center(child: CupertinoActivityIndicator()),
        )
      else if (tokens.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 88),
          child: Center(
            child: Column(
              children: [
                Text('暂无热门代币', style: TextStyle(color: palette.mutedText)),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onRefresh,
                  child: const Text('重新加载'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _DexSearchPage extends StatefulWidget {
  const _DexSearchPage({
    required this.palette,
    required this.searchChain,
    required this.selectedChain,
    required this.walletIdentity,
    required this.onOpen,
  });

  final AcoPalette palette;
  final String searchChain;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final ValueChanged<AcoScreen> onOpen;

  @override
  State<_DexSearchPage> createState() => _DexSearchPageState();
}

class _DexSearchPageState extends State<_DexSearchPage> {
  static const _recentLimit = 10;
  static final _recentTokens = <DexRankingToken>[];

  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<DexRankingToken> _results = const [];
  bool _loading = false;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    ++_requestId;
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _query = query;
      _results = const [];
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    final client = DexRankingApiClient();
    try {
      final results = await client.searchTokens(
        query,
        chain: widget.searchChain,
        marketCode: null,
      );
      if (mounted && requestId == _requestId) {
        setState(() => _results = results);
      }
    } catch (error) {
      debugPrint('[DexSearchPage] request failed query=$query error=$error');
      if (mounted && requestId == _requestId) {
        setState(() => _results = const []);
      }
    } finally {
      client.close();
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  void _openToken(DexRankingToken token) {
    _rememberToken(token);
    Navigator.of(context).push<void>(
      _AcoPageRoute<void>(
        builder: (_) => _DexTokenDetailPage(
          palette: widget.palette,
          token: token,
          selectedChain: widget.selectedChain,
          walletIdentity: widget.walletIdentity,
          onOpen: widget.onOpen,
        ),
      ),
    );
  }

  void _rememberToken(DexRankingToken token) {
    _recentTokens.removeWhere((recent) => _sameToken(recent, token));
    _recentTokens.insert(0, token);
    if (_recentTokens.length > _recentLimit) {
      _recentTokens.removeRange(_recentLimit, _recentTokens.length);
    }
  }

  void _clearRecent() {
    if (_recentTokens.isEmpty) return;
    setState(_recentTokens.clear);
  }

  bool _sameToken(DexRankingToken first, DexRankingToken second) {
    final firstIdentity =
        '${first.chain}|${first.address}|${first.pool}|${first.symbol}';
    final secondIdentity =
        '${second.chain}|${second.address}|${second.pool}|${second.symbol}';
    return firstIdentity == secondIdentity;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _results
        .where((token) => token.stockNameZh.isEmpty)
        .toList();
    final stocks = _results
        .where((token) => token.stockNameZh.isNotEmpty)
        .toList();
    return CupertinoPageScaffold(
      backgroundColor: widget.palette.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _DexSearchField(
                      key: const Key('dex-search-page-field'),
                      palette: widget.palette,
                      controller: _controller,
                      placeholder: '搜索代币或股票',
                      onChanged: _onChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: widget.palette.primaryText,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults(tokens, stocks)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
    List<DexRankingToken> tokens,
    List<DexRankingToken> stocks,
  ) {
    if (_query.isEmpty) {
      return ListView(
        key: const Key('dex-recent-results'),
        padding: const EdgeInsets.fromLTRB(15, 24, 15, 24),
        children: [
          Row(
            children: [
              Text(
                '最近浏览',
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                key: const Key('dex-recent-clear'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _clearRecent,
                child: Text(
                  '清空',
                  style: TextStyle(
                    color: widget.palette.mutedText,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (_recentTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  '暂无最近浏览',
                  style: TextStyle(
                    color: widget.palette.mutedText,
                    fontSize: 15,
                  ),
                ),
              ),
            )
          else
            ..._recentTokens.map(_buildResultRow),
        ],
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (tokens.isEmpty && stocks.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配结果',
          style: TextStyle(color: widget.palette.mutedText, fontSize: 15),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 24),
      children: [
        if (tokens.isNotEmpty) _buildGroup('代币', tokens),
        if (tokens.isNotEmpty && stocks.isNotEmpty) const SizedBox(height: 24),
        if (stocks.isNotEmpty) _buildGroup('股票', stocks),
      ],
    );
  }

  Widget _buildResultRow(DexRankingToken token) => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: widget.palette.border)),
    ),
    child: _DexSearchResultRow(
      token: token,
      palette: widget.palette,
      onTap: () => _openToken(token),
    ),
  );

  Widget _buildGroup(String title, List<DexRankingToken> tokens) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: widget.palette.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      for (final token in tokens) _buildResultRow(token),
    ],
  );
}

class _DexSearchResultRow extends StatelessWidget {
  const _DexSearchResultRow({
    required this.token,
    required this.palette,
    required this.onTap,
  });

  final DexRankingToken token;
  final AcoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = token.symbol;
    final quote = token.quoteSymbol.trim();
    final age = _dexTokenAge(token.createdAt) ?? '--';
    const metricGap = SizedBox(width: 6);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DexTokenDisplayIcon(token: token, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: title,
                                      style: TextStyle(
                                        color: palette.primaryText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (quote.isNotEmpty)
                                      TextSpan(
                                        text: '/$quote',
                                        style: TextStyle(
                                          color: palette.mutedText,
                                          fontSize: 15,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (token.verified) ...[
                              const SizedBox(width: 5),
                              const _VerifiedTokenBadge(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatDexCompactCurrency(token.marketCap),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatDexPrice(token.price),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              metricGap,
                              Text(
                                _formatDexChange(token.change),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: TextStyle(
                                  color: _dexChangeColor(token.change),
                                  fontSize: 15,
                                ),
                              ),
                              metricGap,
                              Text(
                                '(24h)',
                                style: TextStyle(
                                  color: palette.mutedText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        age,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DexHotTokenRow extends StatelessWidget {
  const _DexHotTokenRow({
    required this.token,
    required this.palette,
    required this.isStock,
    required this.onTap,
  });

  final DexRankingToken token;
  final AcoPalette palette;
  final bool isStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = isStock && token.stockNameZh.isNotEmpty
        ? token.stockNameZh
        : token.symbol;
    final subtitle = isStock
        ? token.symbol
        : '${formatDexCompactCurrency(token.marketCap)}  |  '
              '${formatDexCompactCurrency(token.volume)}';

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Row(
        children: [
          _DexTokenDisplayIcon(token: token, size: 44),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (token.verified) ...[
                      const SizedBox(width: 4),
                      const _VerifiedTokenBadge(),
                    ],
                    if (!isStock && token.chain.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _DexChainBadge(chain: token.chain),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.mutedText, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  alignment: Alignment.centerRight,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatDexPrice(token.price),
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDexChange(token.change),
                  style: TextStyle(
                    color: _dexChangeColor(token.change),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DexChainBadge extends StatelessWidget {
  const _DexChainBadge({required this.chain});

  final String chain;

  @override
  Widget build(BuildContext context) {
    final asset = _dexChainIconAsset(chain);
    if (asset == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          _dexChainShortName(chain),
          style: const TextStyle(
            color: Color(0xFFB8B8B8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      );
    }

    return Semantics(
      label: _dexChainName(chain),
      image: true,
      child: ClipOval(
        child: Image.asset(asset, width: 18, height: 18, fit: BoxFit.cover),
      ),
    );
  }
}

String? _dexChainIconAsset(String chain) => switch (chain
    .trim()
    .toLowerCase()) {
  'sol' || 'solana' => 'assets/icons/crypto/domi/chains/network-solana.png',
  'eth' || 'ethereum' => 'assets/icons/crypto/domi/chains/network-ethereum.png',
  'bsc' ||
  'bnb' ||
  'binance' ||
  'binance smart chain' => 'assets/icons/crypto/domi/chains/network-bsc.png',
  'polygon' || 'matic' => 'assets/icons/crypto/domi/chains/network-polygon.png',
  'arbitrum' || 'arb' => 'assets/icons/crypto/domi/chains/network-arbitrum.png',
  'optimism' || 'op' => 'assets/icons/crypto/domi/chains/network-optimism.png',
  'base' => 'assets/icons/crypto/domi/chains/network-base.png',
  _ => null,
};

String _dexChainName(String chain) => switch (chain.trim().toLowerCase()) {
  'sol' || 'solana' => 'Solana',
  'eth' || 'ethereum' => 'Ethereum',
  'bsc' || 'bnb' || 'binance' || 'binance smart chain' => 'BSC',
  'polygon' || 'matic' => 'Polygon',
  'arbitrum' || 'arb' => 'Arbitrum',
  'optimism' || 'op' => 'Optimism',
  'base' => 'Base',
  _ => chain.trim(),
};

String _dexChainShortName(String chain) {
  final normalized = chain.trim();
  if (normalized.isEmpty) return '?';
  return normalized.length <= 5
      ? normalized.toUpperCase()
      : normalized.substring(0, 5).toUpperCase();
}

class _VerifiedTokenBadge extends StatelessWidget {
  const _VerifiedTokenBadge();

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/dex_verified_badge.png',
    width: 16,
    height: 16,
    fit: BoxFit.contain,
  );
}

class _DexTokenDisplayIcon extends StatefulWidget {
  const _DexTokenDisplayIcon({required this.token, required this.size});

  final DexRankingToken token;
  final double size;

  @override
  State<_DexTokenDisplayIcon> createState() => _DexTokenDisplayIconState();
}

class _DexTokenDisplayIconState extends State<_DexTokenDisplayIcon> {
  @override
  Widget build(BuildContext context) {
    if (_isAldToken) {
      return ClipOval(
        child: Image.asset(
          'assets/icons/crypto/tokens/ald.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        ),
      );
    }
    final uri = widget.token.logoUri;
    if (!(uri.startsWith('http://') || uri.startsWith('https://'))) {
      return _unknownTokenIcon();
    }

    final requestUri = _dexLogoRequestUrl(_normalizedDexLogoUrl(uri));
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: requestUri,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _letterTokenIcon(widget.token.symbol),
        imageBuilder: (_, imageProvider) {
          return Image(
            image: imageProvider,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          );
        },
        errorWidget: (context, url, error) =>
            _letterTokenIcon(widget.token.symbol),
      ),
    );
  }

  Widget _unknownTokenIcon() => _dexUnknownTokenIcon(widget.size);

  bool get _isAldToken =>
      widget.token.address.toLowerCase() ==
      '0x3cbd513239d9e5538a4caed8ed53ef77009df473';

  Widget _letterTokenIcon(String symbol) =>
      _dexLetterTokenIcon(symbol, widget.size);
}

Widget _dexUnknownTokenIcon(double size) => Container(
  width: size,
  height: size,
  decoration: const BoxDecoration(
    color: Color(0xFF303030),
    shape: BoxShape.circle,
  ),
  child: Icon(
    CupertinoIcons.question,
    color: const Color(0xFF9A9A9A),
    size: size * .52,
  ),
);

Widget _dexLetterTokenIcon(String symbol, double size) {
  final normalized = symbol.trim().toUpperCase();
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFF2680D9),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      normalized.isEmpty ? '?' : normalized.substring(0, 1),
      style: TextStyle(
        color: CupertinoColors.white,
        fontSize: size * .42,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _shortDexAddress(String address) {
  if (address.length <= 10) return address;
  return '${address.substring(0, 6)}..${address.substring(address.length - 4)}';
}

String? _dexTokenAge(DateTime? createdAt) {
  if (createdAt == null) return null;

  final days = DateTime.now().difference(createdAt).inDays;
  return '${days < 0 ? 0 : days}天';
}

String _normalizedDexLogoUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host != 'cdn.dexscreener.com' ||
      uri.queryParameters['format'] != 'auto') {
    return value;
  }
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'format': 'png'})
      .toString();
}

String _dexLogoRequestUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      !_shouldProxyDexLogoHost(uri.host)) {
    return value;
  }
  final encoded = base64Url.encode(utf8.encode(value));
  return 'https://img2.ant.fun/md/$encoded';
}

bool _shouldProxyDexLogoHost(String host) => switch (host.toLowerCase()) {
  'cdn.dexscreener.com' || 'dd.dexscreener.com' => true,
  _ => false,
};

String formatDexCompactCurrency(String value) {
  final normalized = value.trim().replaceFirst(RegExp(r'^\$'), '');
  final suffixed = RegExp(
    r'^(-?[\d.,]+)\s*([KMBT])$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (suffixed != null) {
    final number = double.tryParse(suffixed.group(1)!.replaceAll(',', ''));
    if (number != null && number.isFinite) {
      return _formatDexCompactValue(
        number * _dexCurrencyMultiplier(suffixed.group(2)!),
      );
    }
  }

  final parsed = double.tryParse(normalized.replaceAll(',', ''));
  if (parsed == null) return value.isEmpty ? '--' : '\$$value';

  return _formatDexCompactValue(parsed);
}

String _formatDexCompactValue(double parsed) {
  if (!parsed.isFinite) return '\$$parsed';

  final absolute = parsed.abs();
  var divisor = 1.0;
  var suffix = '';
  if (absolute >= 1e12) {
    divisor = 1e12;
    suffix = 'T';
  } else if (absolute >= 1e9) {
    divisor = 1e9;
    suffix = 'B';
  } else if (absolute >= 1e6) {
    divisor = 1e6;
    suffix = 'M';
  } else if (absolute >= 1e3) {
    divisor = 1e3;
    suffix = 'K';
  }
  final number = _trimTrailingZeros((absolute / divisor).toStringAsFixed(2));
  final sign = parsed < 0 ? '-' : '';
  return '\$$sign$number$suffix';
}

double _dexCurrencyMultiplier(String suffix) {
  switch (suffix.toUpperCase()) {
    case 'K':
      return 1e3;
    case 'M':
      return 1e6;
    case 'B':
      return 1e9;
    case 'T':
      return 1e12;
    default:
      return 1;
  }
}

String formatDexPrice(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) return '--';
  if (normalized.startsWith('\$')) normalized = normalized.substring(1);

  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite) return '\$$normalized';
  if (parsed == 0) return '\$0';

  final sign = parsed < 0 ? '-' : '';
  final absolute = parsed.abs();
  if (absolute < 0.001) {
    final decimalDigits = _priceDecimalDigits(normalized, absolute);
    final firstNonZero = decimalDigits.indexOf(RegExp(r'[1-9]'));
    if (firstNonZero >= 2) {
      var significant = decimalDigits.substring(firstNonZero);
      significant = significant.replaceFirst(RegExp(r'0+$'), '');
      significant = significant.substring(0, significant.length.clamp(0, 4));
      return '\$${sign}0.0${_toSubscript(firstNonZero - 1)}$significant';
    }
  }

  final decimals = absolute >= 1 ? 2 : 5;
  final number = _trimTrailingZeros(absolute.toStringAsFixed(decimals));
  return '\$$sign$number';
}

String formatDexChartPrice(double value) {
  final formatted = formatDexPrice(value.toString());
  return formatted.startsWith('\$') ? formatted.substring(1) : formatted;
}

String _priceDecimalDigits(String value, double absolute) {
  final exponent = value.indexOf(RegExp(r'[eE]'));
  if (exponent >= 0) {
    return absolute.toStringAsFixed(20).split('.').last;
  }
  final decimalPoint = value.indexOf('.');
  return decimalPoint < 0 ? '' : value.substring(decimalPoint + 1);
}

String _toSubscript(int value) {
  const digits = {
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
  };
  return value.toString().split('').map((digit) => digits[digit]!).join();
}

String _trimTrailingZeros(String value) {
  if (!value.contains('.')) return value;
  return value
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatDexChange(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '--';
  if (normalized.startsWith('-') || normalized.startsWith('+')) {
    return normalized;
  }
  final numeric = double.tryParse(normalized.replaceAll('%', ''));
  if (numeric == null || numeric <= 0) return normalized;
  return '+$normalized';
}

class _DexTradeActions extends StatelessWidget {
  const _DexTradeActions({required this.onBuy, required this.onSell});

  final VoidCallback onBuy;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = ((constraints.maxWidth - 32) / 2).clamp(
          125.0,
          150.0,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: buttonWidth,
              child: _DexTradeButton(
                label: '买入',
                color: Color(0xFF25A957),
                onPressed: onBuy,
              ),
            ),
            const SizedBox(width: 32),
            SizedBox(
              width: buttonWidth,
              child: _DexTradeButton(
                label: '卖出',
                color: Color(0xFFEB456C),
                onPressed: onSell,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DexTradeButton extends StatelessWidget {
  const _DexTradeButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      color: color,
      borderRadius: BorderRadius.circular(10),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _DexTradeSheet extends StatefulWidget {
  const _DexTradeSheet({
    required this.palette,
    required this.token,
    required this.buying,
    required this.selectedChain,
    this.walletIdentity,
  });

  final AcoPalette palette;
  final DexRankingToken token;
  final bool buying;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;

  @override
  State<_DexTradeSheet> createState() => _DexTradeSheetState();
}

class _DexTradeSheetState extends State<_DexTradeSheet> {
  late bool _buying = widget.buying;
  final _amountController = TextEditingController();
  late final List<_DexQuoteAsset> _availableQuotes = _buildAvailableQuotes();
  late _DexQuoteAsset _quoteAsset = _availableQuotes.first;
  Map<String, String> _balances = const {};
  bool _loadingBalance = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBalances());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalances() async {
    final identity = widget.walletIdentity;
    final tokenStore = await SecureAccountTokenStore().read();
    if (identity == null || tokenStore == null) {
      if (mounted) setState(() => _loadingBalance = false);
      return;
    }
    final portfolio = WalletPortfolioService();
    try {
      final network = _network;
      final derivedAddresses = await WalletPreferences.derivedAddresses(
        identity,
      );
      final balances = await portfolio.loadBalances(
        network: network,
        identity: identity,
        derivedAddresses: derivedAddresses,
        accessToken: tokenStore.accessToken,
      );
      final customTokens = await WalletMetadataStore().customTokens(identity);
      final tokenMetadata = customTokens
          .cast<CustomTokenDefinition?>()
          .firstWhere(
            (token) =>
                token?.network == network.name &&
                token?.address.toLowerCase() ==
                    widget.token.address.toLowerCase(),
            orElse: () => null,
          );
      final customAssets = [
        if (tokenMetadata != null)
          WalletAsset(
            network: network,
            symbol: tokenMetadata.symbol,
            name: tokenMetadata.symbol,
            decimals: tokenMetadata.decimals,
            isNative: false,
            tokenAddress: tokenMetadata.address,
          ),
        if (tokenMetadata == null && widget.token.address.isNotEmpty)
          WalletAsset(
            network: network,
            symbol: widget.token.symbol,
            name: widget.token.name,
            decimals: _decimals(widget.token.symbol),
            isNative: false,
            tokenAddress: widget.token.address,
          ),
      ];
      final allBalances = [...balances];
      if (customAssets.isNotEmpty) {
        await for (final balance in portfolio.loadAssetBalances(
          network: network,
          identity: identity,
          accessToken: tokenStore.accessToken,
          assets: customAssets,
        )) {
          allBalances.add(balance);
        }
      }
      if (!mounted) return;
      setState(() {
        _balances = {
          for (final balance in allBalances)
            balance.symbol.toUpperCase(): balance.balance == null
                ? '0'
                : formatChainAmount(
                    balance.balance!,
                    decimals: balance.decimals,
                  ),
        };
        _loadingBalance = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    } finally {
      portfolio.close();
    }
  }

  List<_DexQuoteAsset> _buildAvailableQuotes() {
    final chain = widget.token.chain.trim().toLowerCase();
    if (chain == 'sol' || chain == 'solana') {
      return [
        _DexQuoteAsset('USDT', WalletChainRegistry.solanaUsdt.address),
        _DexQuoteAsset('USDC', WalletChainRegistry.solanaUsdc.address),
        const _DexQuoteAsset('SOL', ''),
      ];
    }
    if (chain == 'tron' || chain == 'trx') {
      return [
        _DexQuoteAsset('USDT', WalletChainRegistry.tronUsdt.address),
        _DexQuoteAsset('USDC', WalletChainRegistry.tronUsdc.address),
        const _DexQuoteAsset('TRX', ''),
      ];
    }
    final network = switch (chain) {
      'bsc' || 'bnb' || 'bnb chain' => WalletNetwork.bsc,
      'polygon' || 'matic' => WalletNetwork.polygon,
      'base' => WalletNetwork.base,
      'arbitrum' => WalletNetwork.arbitrum,
      'optimism' => WalletNetwork.optimism,
      _ => WalletNetwork.ethereum,
    };
    final definition = WalletChainRegistry.chains[network]!;
    return [
      _DexQuoteAsset('USDT', definition.usdt!.address),
      _DexQuoteAsset('USDC', definition.usdc!.address),
      _DexQuoteAsset(definition.symbol, ''),
    ];
  }

  String get _quoteSymbol => _quoteAsset.symbol;
  String get _paySymbol => _buying ? _quoteSymbol : widget.token.symbol;
  String get _receiveSymbol => _buying ? widget.token.symbol : _quoteSymbol;
  double get _tokenPrice {
    final price = widget.token.price.replaceFirst(RegExp(r'^\$'), '');
    return double.tryParse(price) ?? 0;
  }

  String get _estimatedReceive {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0 || _tokenPrice <= 0) return '0';
    final estimated = _buying ? amount / _tokenPrice : amount * _tokenPrice;
    return _formatTradeAmount(estimated);
  }

  String get _availableBalance => _loadingBalance
      ? '读取中…'
      : '${_balances[_paySymbol.toUpperCase()] ?? '0'} $_paySymbol';

  double get _availableBalanceValue =>
      double.tryParse(_balances[_paySymbol.toUpperCase()] ?? '') ?? 0;

  bool get _canSubmit {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    return !_submitting &&
        !_loadingBalance &&
        widget.walletIdentity != null &&
        amount > 0 &&
        amount <= _availableBalanceValue;
  }

  WalletNetwork get _network {
    switch (widget.token.chain.trim().toLowerCase()) {
      case 'bsc':
      case 'bnb':
      case 'bnb chain':
        return WalletNetwork.bsc;
      case 'polygon':
      case 'matic':
        return WalletNetwork.polygon;
      case 'base':
        return WalletNetwork.base;
      case 'arbitrum':
        return WalletNetwork.arbitrum;
      case 'optimism':
        return WalletNetwork.optimism;
      case 'sol':
      case 'solana':
        return WalletNetwork.solana;
      case 'tron':
      case 'trx':
        return WalletNetwork.tron;
      default:
        return WalletNetwork.ethereum;
    }
  }

  _WalletChain get _tradeChain => _supportedWalletChains.firstWhere(
    (chain) => chain.network == _network,
    orElse: () => widget.selectedChain,
  );

  String _nativeSymbol(WalletNetwork network) => switch (network) {
    WalletNetwork.ethereum ||
    WalletNetwork.arbitrum ||
    WalletNetwork.optimism ||
    WalletNetwork.base => 'ETH',
    WalletNetwork.bsc => 'BNB',
    WalletNetwork.polygon => 'POL',
    WalletNetwork.tron => 'TRX',
    WalletNetwork.solana => 'SOL',
  };

  int _decimals(String symbol) {
    final normalized = symbol.trim().toUpperCase();
    final definition = WalletChainRegistry.chains[_network];
    if (normalized == definition?.usdt?.symbol.toUpperCase()) {
      return definition!.usdt!.decimals;
    }
    if (normalized == definition?.usdc?.symbol.toUpperCase()) {
      return definition!.usdc!.decimals;
    }
    return definition?.decimals ?? 18;
  }

  Future<void> _submitTrade() async {
    if (_submitting) return;
    final amount = _amountController.text.trim();
    final parsed = double.tryParse(amount);
    final identity = widget.walletIdentity;
    if (parsed == null || parsed <= 0) {
      _showTradeMessage('交易', '请输入有效的交易数量。');
      return;
    }
    if (identity == null) {
      _showTradeMessage('交易', '请先连接钱包。');
      return;
    }
    final payAddress = _buying ? _quoteAsset.address : widget.token.address;
    final receiveAddress = _buying ? widget.token.address : _quoteAsset.address;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _buying ? '确认买入' : '确认卖出',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _confirmationRow('交易方向', _buying ? '买入' : '卖出'),
                  _confirmationRow(
                    _buying ? '支付数量' : '卖出数量',
                    '$amount $_paySymbol',
                  ),
                  _confirmationTokenRow(
                    _buying ? '买入代币' : '获得代币',
                    _receiveSymbol,
                    receiveAddress,
                  ),
                  _confirmationTokenRow(
                    _buying ? '支付代币' : '卖出代币',
                    _paySymbol,
                    payAddress,
                  ),
                  _confirmationRow('网络', _networkLabel(_network)),
                  _confirmationRow(
                    '交易路由',
                    widget.token.dex.trim().isEmpty
                        ? 'LI.FI'
                        : widget.token.dex,
                  ),
                  _confirmationRow('钱包', _shortWallet(identity.address)),
                  const SizedBox(height: 8),
                  const Text(
                    '实际到账数量、网络手续费和路由费用以链上执行结果为准。',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            child: Text(
                              '取消',
                              style: TextStyle(
                                color: widget.palette.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: widget.palette.accent,
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            child: Text(
                              '确认交易',
                              style: TextStyle(
                                color: CupertinoColors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final tokenStore = await SecureAccountTokenStore().read();
      if (tokenStore == null) throw const FormatException('钱包服务尚未连接。');
      if (_network == WalletNetwork.solana || _network == WalletNetwork.tron) {
        throw const FormatException('当前买卖流程暂支持 EVM 公链。');
      }
      final mnemonic = await _unlockTradeMnemonic(identity);
      if (!mounted || mnemonic == null) return;
      final client = LifiApiClient();
      try {
        final fromAddress = await _addressForChain(identity, _tradeChain);
        if (fromAddress == null || fromAddress.isEmpty) {
          throw const FormatException('当前公链钱包地址不可用。');
        }
        final quote = await client.quote(
          fromNetwork: _network,
          fromToken: _paySymbol,
          toNetwork: _network,
          toToken: _receiveSymbol,
          fromAmount: amount,
          fromDecimals: _decimals(_paySymbol),
          fromAddress: fromAddress,
          toAddress: fromAddress,
          fromTokenAddress: _nonEmptyAddress(
            _buying ? _quoteAsset.address : widget.token.address,
          ),
          toTokenAddress: _nonEmptyAddress(
            _buying ? widget.token.address : _quoteAsset.address,
          ),
        );
        final request = quote.transactionRequest;
        if (request == null) throw const FormatException('暂时无法构造交易。');
        final rpc = WalletRpcClient(
          client: http.Client(),
          directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
          ownsClient: true,
        );
        try {
          final isEvm =
              _network != WalletNetwork.solana &&
              _network != WalletNetwork.tron;
          final isNativePayment =
              _paySymbol.toUpperCase() == _nativeSymbol(_network);
          if (isEvm && !isNativePayment) {
            final spender = request['to'] as String?;
            if (spender == null || !spender.startsWith('0x')) {
              throw const FormatException('交易授权地址无效。');
            }
            final tokenAddress = _buying
                ? _quoteAsset.address
                : widget.token.address;
            final approval = await const WalletTransferService()
                .ensureErc20AllowanceWithRpc(
                  mnemonic: mnemonic,
                  from: fromAddress,
                  network: _network,
                  accessToken: tokenStore.accessToken,
                  rpc: rpc,
                  tokenAddress: tokenAddress,
                  spender: spender,
                  requiredAmount: LifiApiClient.toBaseUnits(
                    amount,
                    _decimals(_paySymbol),
                  ),
                );
            if (approval != null) {
              final approved = await const WalletTransferService()
                  .waitForErc20AllowanceWithRpc(
                    network: _network,
                    accessToken: tokenStore.accessToken,
                    rpc: rpc,
                    owner: fromAddress,
                    tokenAddress: tokenAddress,
                    spender: spender,
                    requiredAmount: LifiApiClient.toBaseUnits(
                      amount,
                      _decimals(_paySymbol),
                    ),
                  );
              if (!approved) throw const FormatException('代币授权尚未生效。');
            }
          }
          final result = await const WalletTransferService()
              .executeTransactionRequestWithRpc(
                mnemonic: mnemonic,
                from: fromAddress,
                network: _network,
                accessToken: tokenStore.accessToken,
                rpc: rpc,
                transactionRequest: request,
              );
          if (!mounted) return;
          unawaited(_recordTrade(result.hash, fromAddress, request, quote));
          Navigator.of(context).pop(result.hash);
        } finally {
          rpc.close();
        }
      } finally {
        client.close();
      }
    } on WalletSecurityException catch (error) {
      if (mounted) _showTradeMessage('交易失败', error.message);
    } catch (error) {
      if (mounted) _showTradeMessage('交易失败', '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _confirmationRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _confirmationTokenRow(String label, String symbol, String address) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    symbol,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.trim().isEmpty ? '合约地址未知' : address,
                    textAlign: TextAlign.right,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  String _networkLabel(WalletNetwork network) => switch (network) {
    WalletNetwork.ethereum => 'Ethereum',
    WalletNetwork.arbitrum => 'Arbitrum',
    WalletNetwork.optimism => 'Optimism',
    WalletNetwork.base => 'Base',
    WalletNetwork.bsc => 'BNB Chain',
    WalletNetwork.polygon => 'Polygon',
    WalletNetwork.tron => 'TRON',
    WalletNetwork.solana => 'Solana',
  };

  String _shortWallet(String address) {
    final value = address.trim();
    if (value.length <= 14) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }

  String? _nonEmptyAddress(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Future<void> _recordTrade(
    String txHash,
    String wallet,
    Map<String, dynamic> request,
    LifiQuote quote,
  ) async {
    final service = DexTradeService();
    try {
      await service.record(
        network: _network.name,
        wallet: wallet,
        dex: quote.tool,
        pool: '${quote.pool ?? request['to'] ?? quote.tool}',
        txHash: txHash,
        baseToken: quote.fromTokenAddress,
        quoteToken: quote.toTokenAddress,
        side: _buying ? 'buy' : 'sell',
        toNetwork: _network.name,
      );
    } catch (error) {
      debugPrint('[DexTrade] detail trade record failed: $error');
    } finally {
      service.close();
    }
  }

  Future<String?> _unlockTradeMnemonic(WalletIdentity identity) async {
    final store = SecureWalletSecretStore();
    if (!mounted) return null;
    return showWalletUnlockDialog(
      context: context,
      store: store,
      walletAddress: identity.address,
    );
  }

  void _showTradeMessage(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _setAmountFraction(double fraction) {
    final balanceText = _balances[_paySymbol.toUpperCase()] ?? '0';
    final balance = double.tryParse(balanceText) ?? 0;
    final amount = fraction == 1
        ? balanceText
        : _formatTradeAmount(balance * fraction);
    _amountController
      ..text = amount
      ..selection = TextSelection.collapsed(offset: amount.length);
    setState(() {});
  }

  void _pickQuote() {
    if (_availableQuotes.length < 2) return;
    showCupertinoModalPopup<_DexQuoteAsset>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          '选择交易代币',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          for (final asset in _availableQuotes)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(asset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    asset.symbol,
                    style: TextStyle(
                      color: widget.palette.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (asset.symbol == _quoteAsset.symbol) ...[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.check_mark,
                      color: widget.palette.accent,
                      size: 17,
                    ),
                  ],
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(
              color: widget.palette.accent,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ).then((asset) {
      if (asset != null && mounted) setState(() => _quoteAsset = asset);
    });
  }

  void _setBuying(bool buying) {
    if (_buying == buying) return;
    setState(() {
      _buying = buying;
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final mutedSurface = palette.primaryText.withValues(alpha: .07);
    final inputSurface = palette.primaryText.withValues(alpha: .05);
    final inputBorder = palette.primaryText.withValues(alpha: .12);
    return PopScope(
      canPop: !_submitting,
      child: CupertinoPopupSurface(
        isSurfacePainted: false,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: AbsorbPointer(
              absorbing: _submitting,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.mutedText.withValues(alpha: .42),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: mutedSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              _DexTradeModeTab(
                                label: '买入',
                                selected: _buying,
                                color: const Color(0xFF25C66A),
                                onPressed: () => _setBuying(true),
                              ),
                              _DexTradeModeTab(
                                label: '卖出',
                                selected: !_buying,
                                color: const Color(0xFFEB456C),
                                onPressed: () => _setBuying(false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 15),
                    decoration: BoxDecoration(
                      color: inputSurface,
                      border: Border.all(color: inputBorder),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                placeholder: '0',
                                placeholderStyle: TextStyle(
                                  color: palette.mutedText.withValues(
                                    alpha: .7,
                                  ),
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                ),
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                ),
                                padding: EdgeInsets.zero,
                                decoration: const BoxDecoration(),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Text(
                              _paySymbol,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _availableQuotes.length > 1
                                ? _pickQuote
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      color: palette.mutedText,
                                      fontSize: 14,
                                    ),
                                    children: [
                                      const TextSpan(text: '可用 '),
                                      TextSpan(
                                        text: _availableBalance,
                                        style: TextStyle(
                                          color: palette.primaryText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_availableQuotes.length > 1) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    CupertinoIcons.chevron_down,
                                    color: palette.primaryText,
                                    size: 13,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        '预计获得数量',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_estimatedReceive $_receiveSymbol',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (final option in const [
                        ('10%', .1),
                        ('25%', .25),
                        ('50%', .5),
                        ('MAX', 1.0),
                      ])
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: option.$1 == 'MAX' ? 0 : 10,
                            ),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.fromHeight(42),
                              color: mutedSurface,
                              borderRadius: BorderRadius.circular(10),
                              onPressed: _loadingBalance
                                  ? null
                                  : () => _setAmountFraction(option.$2),
                              child: Text(
                                option.$1,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: _canSubmit
                          ? (_buying
                                ? const Color(0xFF25C66A)
                                : const Color(0xFFEB456C))
                          : mutedSurface,
                      borderRadius: BorderRadius.circular(26),
                      onPressed: _canSubmit ? _submitTrade : null,
                      child: Text(
                        _submitting ? '处理中…' : (_buying ? '买入' : '卖出'),
                        style: TextStyle(
                          color: _canSubmit
                              ? Colors.white
                              : palette.mutedText.withValues(alpha: .7),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DexQuoteAsset {
  const _DexQuoteAsset(this.symbol, this.address);

  final String symbol;
  final String address;
}

String _formatTradeAmount(double value) {
  if (!value.isFinite || value <= 0) return '0';
  final digits = value >= 1 ? 4 : 8;
  return value
      .toStringAsFixed(digits)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class _DexTradeModeTab extends StatelessWidget {
  const _DexTradeModeTab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      color: selected ? color : _transparent,
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? CupertinoColors.white : CupertinoColors.systemGrey,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _MarketStat extends StatelessWidget {
  const _MarketStat({
    required this.label,
    required this.value,
    required this.palette,
    required this.width,
  });

  final String label;
  final String value;
  final AcoPalette palette;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
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
