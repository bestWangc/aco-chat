part of 'aco_design_shell.dart';

Color _dexChangeColor(String change) =>
    change.trim().startsWith('-') ? _danger : _lime;

class _DexTokenPage extends StatefulWidget {
  const _DexTokenPage({
    required this.palette,
    required this.selectedChain,
    this.walletIdentity,
    required this.onOpen,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final ValueChanged<AcoScreen> onOpen;
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
    _loadHotTokens();
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
    required this.onSectionChanged,
  });

  final AcoPalette palette;
  final WalletIdentity? walletIdentity;
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

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
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
    return RefreshIndicator(
      onRefresh: () => _loadMarkets(showLoading: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(15, 4, 15, 24),
        children: [
          _DexSectionTabs(
            palette: palette,
            selectedSection: 2,
            onChanged: widget.onSectionChanged,
          ),
          const SizedBox(height: 8),
          if (!_loading && _error == null && _markets.isNotEmpty) ...[
            _HyperliquidMarketHeader(palette: palette),
            const SizedBox(height: 4),
          ],
          if (_loading)
            const Center(child: CupertinoActivityIndicator())
          else if (_error != null)
            _buildMessage(palette, _error!, true)
          else if (_markets.isEmpty)
            _buildMessage(palette, '暂无可用合约', false)
          else
            ..._markets.map((market) => _buildMarketRow(palette, market)),
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
  double? _realtimePrice;
  DexKlineRealtimeClient? _realtimeClient;
  StreamSubscription<DexPriceUpdate>? _realtimeSubscription;
  final _chartController = KChartController();

  DexRankingToken get _displayToken => _tokenInfo ?? widget.token;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCandlesThenConnect(_selectedRange));
    _loadDexScreenerTokenInfo();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _realtimeClient?.close();
    super.dispose();
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
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: .58),
      builder: (_) => _DexTradeSheet(
        palette: widget.palette,
        token: _displayToken,
        buying: buying,
        selectedChain: widget.selectedChain,
        walletIdentity: widget.walletIdentity,
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
                        FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatDexPrice(price),
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: AcoTypography.metric,
                              fontWeight: FontWeight.w700,
                            ),
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
                      value: formatDexCompactCurrency(token.marketCap),
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
        const SizedBox(height: 24),
        _DexTokenDetailTabs(
          palette: palette,
          selected: _selectedDetailTab,
          onChanged: (index) => setState(() => _selectedDetailTab = index),
        ),
        const SizedBox(height: 20),
        if (_selectedDetailTab == 0)
          _DexTradeActivityCard(palette: palette, token: token)
        else
          _DexHolderList(palette: palette),
      ],
    );
  }

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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(15, 20, 15, 24),
                children: [_buildTokenDetails(palette)],
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
      _buildTab('持有者(456)', 1),
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

class _DexHolder {
  const _DexHolder({
    required this.nickname,
    required this.holdingTime,
    required this.totalValue,
  });

  final String nickname;
  final String holdingTime;
  final String totalValue;
}

const _mockDexHolders = <_DexHolder>[
  _DexHolder(nickname: '早起的鸟儿', holdingTime: '持有 18小时', totalValue: '\$18.72M'),
  _DexHolder(
    nickname: 'ZEC Builder',
    holdingTime: '持有 35天',
    totalValue: '\$14.04M',
  ),
  _DexHolder(nickname: '链上观察员', holdingTime: '持有 72天', totalValue: '\$10.28M'),
  _DexHolder(
    nickname: 'Moon Walker',
    holdingTime: '持有 150天',
    totalValue: '\$7.40M',
  ),
  _DexHolder(nickname: '长期主义者', holdingTime: '持有 12天', totalValue: '\$4.91M'),
  _DexHolder(
    nickname: 'Crypto Fox',
    holdingTime: '持有 28天',
    totalValue: '\$3.22M',
  ),
];

class _DexHolderList extends StatelessWidget {
  const _DexHolderList({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final holder in _mockDexHolders) ...[
        _DexHolderRow(holder: holder, palette: palette),
        if (holder != _mockDexHolders.last) const SizedBox(height: 8),
      ],
    ],
  );
}

class _DexHolderRow extends StatelessWidget {
  const _DexHolderRow({required this.holder, required this.palette});

  final _DexHolder holder;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                holder.nickname,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                holder.holdingTime,
                style: TextStyle(color: palette.mutedText, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          holder.totalValue,
          style: TextStyle(
            color: palette.accent,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DexTradeActivityCard extends StatelessWidget {
  const _DexTradeActivityCard({required this.palette, required this.token});

  final AcoPalette palette;
  final DexRankingToken token;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF191919),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DexTokenDisplayIcon(token: token, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      token.name.isEmpty ? token.symbol : token.name,
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
                      color: const Color(0xFF173E0C),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '买入',
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '5天前',
                style: TextStyle(color: palette.mutedText, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'at ',
                      style: TextStyle(color: palette.mutedText, fontSize: 14),
                    ),
                    TextSpan(
                      text: '${formatDexCompactCurrency(token.marketCap)} MC',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                formatDexPrice(token.price),
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
      labels: const ['闪兑', '代币', '合约', '股票'],
      selected: selectedSection,
      itemSpacing: 12,
      fontSize: 18,
      horizontalPadding: 8,
      showSelectedIndicator: true,
      onChanged: onChanged,
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
  bool _loggedLoaded = false;
  bool _loggedFailure = false;

  @override
  void initState() {
    super.initState();
    _startLogoLoad();
  }

  @override
  void didUpdateWidget(covariant _DexTokenDisplayIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token.logoUri != widget.token.logoUri) {
      _startLogoLoad();
    }
  }

  void _startLogoLoad() {
    _loggedLoaded = false;
    _loggedFailure = false;
    _logRequest();
  }

  void _logRequest() {
    final uri = widget.token.logoUri;
    final requestUri = _normalizedDexLogoUrl(uri);
    if (uri.isEmpty) {
      debugPrint('[DexLogo] missing url symbol=${widget.token.symbol}');
    } else if (uri.startsWith('http://') || uri.startsWith('https://')) {
      debugPrint(
        '[DexLogo] request symbol=${widget.token.symbol} url=$requestUri',
      );
      if (requestUri != uri) {
        debugPrint('[DexLogo] original url=$uri');
      }
    } else {
      debugPrint(
        '[DexLogo] unsupported url symbol=${widget.token.symbol} url=$uri',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.token.logoUri;
    if (!(uri.startsWith('http://') || uri.startsWith('https://'))) {
      return _unknownTokenIcon();
    }

    final requestUri = _normalizedDexLogoUrl(uri);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: requestUri,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _loadingTokenIcon(),
        imageBuilder: (_, imageProvider) {
          if (!_loggedLoaded) {
            _loggedLoaded = true;
            debugPrint(
              '[DexLogo] loaded symbol=${widget.token.symbol} url=$requestUri',
            );
          }
          return Image(
            image: imageProvider,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          );
        },
        errorWidget: (context, url, error) {
          if (!_loggedFailure) {
            _loggedFailure = true;
            debugPrint(
              '[DexLogo] bitmap failed symbol=${widget.token.symbol} '
              'url=$url error=$error; fallback=placeholder',
            );
          }
          return _unknownTokenIcon();
        },
      ),
    );
  }

  Widget _unknownTokenIcon() => _dexUnknownTokenIcon(widget.size);

  Widget _loadingTokenIcon() => _dexLoadingTokenIcon(widget.size);
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

Widget _dexLoadingTokenIcon(double size) => Container(
  width: size,
  height: size,
  decoration: const BoxDecoration(
    color: Color(0xFF303030),
    shape: BoxShape.circle,
  ),
  child: const CupertinoActivityIndicator(color: CupertinoColors.white),
);

String _shortDexAddress(String address) {
  if (address.length <= 10) return address;
  return '${address.substring(0, 6)}..${address.substring(address.length - 4)}';
}

String? _dexTokenAge(DateTime? createdAt) {
  if (createdAt == null) return null;

  final now = DateTime.now();
  var months = (now.year - createdAt.year) * 12 + now.month - createdAt.month;
  if (now.day < createdAt.day) months--;
  if (months < 1) return '不足1个月';

  final years = months ~/ 12;
  final remainingMonths = months % 12;
  if (years == 0) return '$months个月';
  return remainingMonths == 0 ? '$years年' : '$years年$remainingMonths个月';
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

String formatDexCompactCurrency(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) return value.isEmpty ? '--' : '\$$value';

  final absolute = parsed.abs();
  final (divisor, suffix) = absolute >= 1e9
      ? (1e9, 'B')
      : absolute >= 1e6
      ? (1e6, 'M')
      : absolute >= 1e3
      ? (1e3, 'K')
      : (1, '');
  final number = _trimTrailingZeros((absolute / divisor).toStringAsFixed(2));
  final sign = parsed < 0 ? '-' : '';
  return '\$$sign$number$suffix';
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
      final balances = await portfolio.loadBalances(
        network: widget.selectedChain.network,
        identity: identity,
        derivedAddresses: await WalletPreferences.derivedAddresses(identity),
        accessToken: tokenStore.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _balances = {
          for (final balance in balances)
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

  void _setAmountFraction(double fraction) {
    final balance =
        double.tryParse(_balances[_paySymbol.toUpperCase()] ?? '') ?? 0;
    final amount = _formatTradeAmount(balance * fraction);
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
    return CupertinoPopupSurface(
      isSurfacePainted: false,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            placeholder: '0',
                            placeholderStyle: TextStyle(
                              color: palette.mutedText.withValues(alpha: .7),
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
                    style: TextStyle(color: palette.mutedText, fontSize: 16),
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
                  color: mutedSurface,
                  borderRadius: BorderRadius.circular(26),
                  onPressed: null,
                  child: Text(
                    _buying ? '买入' : '卖出',
                    style: TextStyle(
                      color: palette.mutedText.withValues(alpha: .7),
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
