part of 'aco_design_shell.dart';

class _HyperliquidContractKlinePage extends StatefulWidget {
  const _HyperliquidContractKlinePage({
    required this.palette,
    required this.market,
  });

  final AcoPalette palette;
  final HyperliquidMarket market;

  @override
  State<_HyperliquidContractKlinePage> createState() =>
      _HyperliquidContractKlinePageState();
}

class _HyperliquidContractKlinePageState
    extends State<_HyperliquidContractKlinePage> {
  static const _ranges = ['15分', '1小时', '4小时', '1天', '周线', '月线'];
  static const _maxCandles = 300;
  static const _orderBookDepth = 20;
  static const _visibleTradeCount = 20;
  static const _maxStoredTrades = 50;

  final _chartController = KChartController();
  final _api = HyperliquidApiClient();
  HyperliquidRealtimeClient? _realtime;
  StreamSubscription<HyperliquidRealtimeUpdate>? _subscription;
  List<KLineEntity> _candles = const [];
  List<HyperliquidTrade> _trades = const [];
  HyperliquidOrderBook? _orderBook;
  HyperliquidMarket? _liveMarket;
  String _selectedRange = '15分';
  String _selectedIndicator = 'VOL';
  int _selectedMarketTab = 0;
  bool _loading = true;
  int _requestId = 0;

  AcoPalette get _palette => widget.palette;
  HyperliquidMarket get _market => _liveMarket ?? widget.market;
  double? get _latestPrice =>
      _market.markPrice ??
      _orderBook?.asks.firstOrNull?.price ??
      _orderBook?.bids.firstOrNull?.price;

  @override
  void initState() {
    super.initState();
    unawaited(_load(_selectedRange));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_realtime?.close());
    _api.close();
    super.dispose();
  }

  String _interval(String range) => switch (range) {
    '15分' => '15m',
    '1小时' => '1h',
    '4小时' => '4h',
    '1天' => '1d',
    '周线' => '1w',
    '月线' => '1M',
    _ => '15m',
  };

  Duration _duration(String range) => switch (range) {
    '15分' => const Duration(minutes: 15),
    '1小时' => const Duration(hours: 1),
    '4小时' => const Duration(hours: 4),
    '1天' => const Duration(days: 1),
    '周线' => const Duration(days: 7),
    '月线' => const Duration(days: 30),
    _ => const Duration(minutes: 15),
  };

  Future<void> _load(String range) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _candles = const [];
    });
    await _subscription?.cancel();
    await _realtime?.close();
    _subscription = null;
    _realtime = null;
    try {
      final end = DateTime.now().millisecondsSinceEpoch;
      final start = end - _duration(range).inMilliseconds * _maxCandles;
      final results = await Future.wait<Object>([
        _api.loadCandles(
          coin: _market.name,
          interval: _interval(range),
          startTime: start,
          endTime: end,
        ),
        _api.loadOrderBook(_market.name),
      ]);
      if (!mounted || requestId != _requestId) return;
      final candles = results[0] as List<HyperliquidCandle>;
      final chartData = candles.map(_toChartEntity).toList(growable: true);
      DataUtil.calculate(chartData);
      setState(() {
        _candles = chartData;
        _orderBook = results[1] as HyperliquidOrderBook;
      });
      _connectRealtime(range, requestId);
    } catch (_) {
      // Keep the page interactive and show the empty state during failures.
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  void _connectRealtime(String range, int requestId) {
    final client = HyperliquidRealtimeClient();
    _realtime = client;
    _subscription = client
        .subscribe(
          coin: _market.name,
          candleInterval: _interval(range),
          includeTrades: true,
        )
        .listen((update) => _applyRealtimeUpdate(update, requestId));
  }

  void _applyRealtimeUpdate(HyperliquidRealtimeUpdate update, int requestId) {
    if (!mounted || requestId != _requestId) return;
    setState(() {
      final orderBook = update.orderBook;
      if (orderBook != null) _orderBook = orderBook;

      final assetContext = update.assetContext;
      if (assetContext != null) {
        _liveMarket = widget.market.withContext(assetContext);
      }

      final candle = update.candle;
      if (candle != null) _applyCandle(candle);

      final trades = update.trades;
      if (trades != null) _applyTrades(trades);
    });
  }

  void _applyTrades(List<HyperliquidTrade> trades) {
    _trades = [...trades.reversed, ..._trades].take(_maxStoredTrades).toList();
  }

  void _applyCandle(HyperliquidCandle candle) {
    final updated = [..._candles];
    final entity = _toChartEntity(candle);
    final index = updated.indexWhere((item) => item.time == candle.openTime);
    if (index >= 0) {
      updated[index] = entity;
    } else {
      updated.add(entity);
      if (updated.length > _maxCandles) updated.removeAt(0);
    }
    DataUtil.calculate(updated);
    _candles = updated;
  }

  KLineEntity _toChartEntity(HyperliquidCandle candle) =>
      KLineEntity.fromCustom(
        open: candle.open,
        close: candle.close,
        high: candle.high,
        low: candle.low,
        vol: candle.volume,
        time: candle.openTime,
      );

  void _selectRange(String range) {
    if (_selectedRange == range) return;
    setState(() => _selectedRange = range);
    unawaited(_load(range));
  }

  void _selectIndicator(String indicator) {
    if (indicator == 'EMA') {
      unawaited(
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('EMA'),
            content: const Text('当前图表组件暂不支持 EMA 指标'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      );
      return;
    }
    setState(() => _selectedIndicator = indicator);
  }

  MainState get _mainState => switch (_selectedIndicator) {
    'MA' => MainState.MA,
    'BOLL' => MainState.BOLL,
    _ => MainState.NONE,
  };

  SecondaryState get _secondaryState => switch (_selectedIndicator) {
    'MACD' => SecondaryState.MACD,
    'KDJ' => SecondaryState.KDJ,
    'RSI' => SecondaryState.RSI,
    'WR' => SecondaryState.WR,
    _ => SecondaryState.NONE,
  };

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _palette.background,
    child: SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Container(height: 1, color: _palette.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  _buildMarketSummary(),
                  _buildRangeSelector(),
                  _buildChart(),
                  _buildIndicatorBar(),
                  Container(height: 1, color: _palette.border),
                  _buildMarketTabs(),
                  _buildMarketContent(),
                ],
              ),
            ),
          ),
          _buildTradeActions(),
        ],
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: AcoPageHeader(
      palette: _palette,
      titleFollowsBack: true,
      onBack: () => Navigator.pop(context),
      titleWidget: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _MarketTitle(palette: _palette, market: _market),
      ),
    ),
  );

  Widget _buildMarketSummary() {
    final price = _latestPrice;
    final previous = _market.previousDayPrice;
    final changeAmount = price != null && previous != null
        ? price - previous
        : null;
    final change = _market.changePercent;
    final changeColor = _hyperliquidChangeColor(change, _palette);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatHyperliquidPrice(price),
                    style: TextStyle(
                      color: _palette.primaryText,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  changeAmount == null || change == null
                      ? '--'
                      : '${changeAmount >= 0 ? '+' : ''}${_formatHyperliquidPrice(changeAmount)}  (${_formatHyperliquidChange(change)})  24H',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 8,
            child: Column(
              children: [
                _KlineStatRow(
                  palette: _palette,
                  leftLabel: '标记价格',
                  leftValue: _formatHyperliquidPrice(_market.markPrice),
                  rightLabel: '24小时交易额',
                  rightValue: _formatHyperliquidCurrency(_market.volume24h),
                ),
                const SizedBox(height: 12),
                _KlineStatRow(
                  palette: _palette,
                  leftLabel: '预言机价格',
                  leftValue: _formatHyperliquidPrice(_market.oraclePrice),
                  rightLabel: '合约持仓量',
                  rightValue: _formatHyperliquidCurrency(
                    _market.openInterestNotional,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() => SizedBox(
    height: 25,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      scrollDirection: Axis.horizontal,
      itemCount: _ranges.length,
      separatorBuilder: (_, _) => const SizedBox(width: 2),
      itemBuilder: (context, index) {
        final range = _ranges[index];
        final selected = range == _selectedRange;
        return CupertinoButton(
          minimumSize: const Size(54, 25),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onPressed: () => _selectRange(range),
          child: Text(
            range,
            style: TextStyle(
              color: selected ? _palette.primaryText : _palette.mutedText,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
      },
    ),
  );

  Widget _buildChart() => SizedBox(
    height: 430,
    child: _candles.isEmpty
        ? Center(
            child: _loading
                ? const CupertinoActivityIndicator()
                : Text('暂无K线数据', style: TextStyle(color: _palette.mutedText)),
          )
        : Padding(
            padding: const EdgeInsets.only(left: 4),
            child: KChartWidget(
              _candles,
              controller: _chartController,
              xFrontPadding: 24,
              isTrendLine: false,
              mainState: _mainState,
              secondaryState: _secondaryState,
              volHidden: _selectedIndicator != 'VOL',
              showInfoDialog: true,
              numberFormatter: formatDexChartPrice,
              hideGrid: false,
              enableTheme: false,
              enablePerformanceMode: true,
              chartColors: ChartColors.dark().copyWith(
                bgColor: [_palette.background, _palette.background],
                gridColor: _palette.border.withValues(alpha: .55),
                defaultTextColor: _palette.mutedText,
                nowPriceUpColor: _lime,
                nowPriceTextColor: _black,
              ),
              chartStyle: ChartStyle().copyWith(
                pointWidth: 7,
                candleWidth: 5,
                candleLineWidth: 1.2,
                topPadding: 18,
                bottomPadding: 16,
                childPadding: 8,
                gridRows: 4,
                gridColumns: 4,
              ),
            ),
          ),
  );

  Widget _buildIndicatorBar() => SizedBox(
    height: 48,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      scrollDirection: Axis.horizontal,
      children: [
        for (final indicator in const [
          'MA',
          'EMA',
          'BOLL',
          'VOL',
          'MACD',
          'KDJ',
          'RSI',
          'WR',
        ])
          _KlineIndicatorLabel(
            indicator,
            selected: indicator == _selectedIndicator,
            supported: indicator != 'EMA',
            onPressed: () => _selectIndicator(indicator),
          ),
      ],
    ),
  );

  Widget _buildMarketTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        _KlineMarketTab(
          palette: _palette,
          label: '订单簿',
          selected: _selectedMarketTab == 0,
          onPressed: () => setState(() => _selectedMarketTab = 0),
        ),
        const SizedBox(width: 24),
        _KlineMarketTab(
          palette: _palette,
          label: '最新成交',
          selected: _selectedMarketTab == 1,
          onPressed: () => setState(() => _selectedMarketTab = 1),
        ),
      ],
    ),
  );

  Widget _buildMarketContent() {
    if (_selectedMarketTab == 1) {
      return _KlineTrades(
        palette: _palette,
        trades: _trades.take(_visibleTradeCount).toList(),
      );
    }
    final asks = (_orderBook?.asks ?? const []).take(_orderBookDepth).toList();
    final bids = (_orderBook?.bids ?? const []).take(_orderBookDepth).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _KlineBookSide(
              palette: _palette,
              title: '买盘',
              levels: bids,
              color: const Color(0xFF25C26E),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: _KlineBookSide(
              palette: _palette,
              title: '卖盘',
              levels: asks,
              color: const Color(0xFFF14D51),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeActions() => DecoratedBox(
    decoration: BoxDecoration(
      color: _palette.background,
      border: Border(top: BorderSide(color: _palette.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _KlineTradeButton(
              label: '开多 ${_market.name}',
              color: const Color(0xFF25C26E),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KlineTradeButton(
              label: '开空 ${_market.name}',
              color: const Color(0xFFF14D51),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    ),
  );
}

class _KlineStatRow extends StatelessWidget {
  const _KlineStatRow({
    required this.palette,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final AcoPalette palette;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _KlineStat(palette, leftLabel, leftValue)),
      const SizedBox(width: 12),
      Expanded(child: _KlineStat(palette, rightLabel, rightValue)),
    ],
  );
}

class _KlineStat extends StatelessWidget {
  const _KlineStat(this.palette, this.label, this.value);

  final AcoPalette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 11)),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _KlineIndicatorLabel extends StatelessWidget {
  const _KlineIndicatorLabel(
    this.label, {
    required this.selected,
    required this.supported,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool supported;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    minimumSize: const Size(56, 44),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: SizedBox(
      width: 56,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected
              ? _white
              : supported
              ? const Color(0xFF868686)
              : const Color(0xFF555555),
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _KlineMarketTab extends StatelessWidget {
  const _KlineMarketTab({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final AcoPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    minimumSize: const Size(72, 44),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? palette.primaryText : palette.mutedText,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 42,
          height: 3,
          decoration: BoxDecoration(
            color: selected ? palette.primaryText : _transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    ),
  );
}

class _KlineBookSide extends StatelessWidget {
  const _KlineBookSide({
    required this.palette,
    required this.title,
    required this.levels,
    required this.color,
  });

  final AcoPalette palette;
  final String title;
  final List<HyperliquidOrderBookLevel> levels;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12)),
          const Spacer(),
          Text('数量', style: TextStyle(color: palette.mutedText, fontSize: 11)),
        ],
      ),
      const SizedBox(height: 6),
      for (final level in levels)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatPlainPrice(level.price),
                  style: TextStyle(color: color, fontSize: 11),
                ),
              ),
              Text(
                _formatQuantity(level.size),
                style: TextStyle(color: palette.primaryText, fontSize: 11),
              ),
            ],
          ),
        ),
    ],
  );
}

class _KlineTrades extends StatelessWidget {
  const _KlineTrades({required this.palette, required this.trades});

  final AcoPalette palette;
  final List<HyperliquidTrade> trades;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          '暂无成交数据',
          style: TextStyle(color: palette.mutedText, fontSize: 13),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '价格',
                  style: TextStyle(color: palette.mutedText, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  '数量',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: palette.mutedText, fontSize: 11),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 58,
                child: Text(
                  '时间',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: palette.mutedText, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final trade in trades)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatPlainPrice(trade.price),
                      style: TextStyle(
                        color: trade.isBuy
                            ? const Color(0xFF25C26E)
                            : const Color(0xFFF14D51),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatQuantity(trade.size),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 58,
                    child: Text(
                      _formatTradeTime(trade.timestamp),
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.mutedText, fontSize: 11),
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

String _formatTradeTime(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(time.hour)}:${twoDigits(time.minute)}:${twoDigits(time.second)}';
}

class _KlineTradeButton extends StatelessWidget {
  const _KlineTradeButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    minimumSize: const Size(double.infinity, 42),
    padding: EdgeInsets.zero,
    color: color,
    borderRadius: BorderRadius.circular(8),
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(
        color: _white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
