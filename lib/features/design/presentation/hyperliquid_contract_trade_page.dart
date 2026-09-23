part of 'aco_design_shell.dart';

class _HyperliquidContractTradePage extends StatefulWidget {
  const _HyperliquidContractTradePage({
    required this.palette,
    required this.market,
    required this.walletIdentity,
  });

  final AcoPalette palette;
  final HyperliquidMarket market;
  final WalletIdentity? walletIdentity;

  @override
  State<_HyperliquidContractTradePage> createState() =>
      _HyperliquidContractTradePageState();
}

class _HyperliquidContractTradePageState
    extends State<_HyperliquidContractTradePage> {
  final _amountController = TextEditingController();
  final _limitPriceController = TextEditingController();
  final _takeProfitPriceController = TextEditingController();
  final _takeProfitRateController = TextEditingController();
  final _stopLossPriceController = TextEditingController();
  final _stopLossRateController = TextEditingController();
  final _client = HyperliquidApiClient();

  HyperliquidOrderBook? _orderBook;
  HyperliquidAccountState? _account;
  List<HyperliquidOpenOrder> _openOrders = const [];
  Timer? _refreshTimer;
  bool _loadingMarket = true;
  bool _loadingAccount = true;
  bool _isMarketOrder = true;
  bool _takeProfitStopLoss = false;
  bool _loadingSubmit = false;
  int _leverage = 20;
  int _selectedTab = 0;
  double _amountRatio = 0;

  AcoPalette get _palette => widget.palette;
  HyperliquidMarket get _market => widget.market;
  double get _available => _account?.withdrawable ?? 0;
  double get _referencePrice =>
      _orderBook?.asks.firstOrNull?.price ??
      _orderBook?.bids.firstOrNull?.price ??
      _market.markPrice ??
      0;

  @override
  void initState() {
    super.initState();
    _leverage = math.min(20, math.max(1, _market.maxLeverage));
    _limitPriceController.text = _formatPlainPrice(_market.markPrice);
    unawaited(_loadMarket());
    unawaited(_loadAccount());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_loadMarket(showLoading: false)),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _amountController.dispose();
    _limitPriceController.dispose();
    _takeProfitPriceController.dispose();
    _takeProfitRateController.dispose();
    _stopLossPriceController.dispose();
    _stopLossRateController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _loadMarket({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loadingMarket = true);
    try {
      final book = await _client.loadOrderBook(_market.name);
      if (mounted) setState(() => _orderBook = book);
    } catch (_) {
      // Keep the last successful book visible during brief network failures.
    } finally {
      if (mounted && showLoading) setState(() => _loadingMarket = false);
    }
  }

  Future<void> _loadAccount() async {
    final address = widget.walletIdentity?.address;
    if (address == null || address.isEmpty) {
      setState(() => _loadingAccount = false);
      return;
    }
    setState(() => _loadingAccount = true);
    try {
      final results = await Future.wait<Object>([
        _client.loadAccountState(address),
        _client.loadOpenOrders(address),
      ]);
      if (!mounted) return;
      setState(() {
        _account = results[0] as HyperliquidAccountState;
        _openOrders = results[1] as List<HyperliquidOpenOrder>;
      });
    } catch (_) {
      // Empty account data is a valid degraded state for the trading page.
    } finally {
      if (mounted) setState(() => _loadingAccount = false);
    }
  }

  void _setAmountRatio(double ratio) {
    final amount = _available * ratio * _leverage;
    setState(() {
      _amountRatio = ratio;
      _amountController.text = amount == 0
          ? ''
          : _trimTrailingZeros(amount.toStringAsFixed(2));
    });
  }

  Future<void> _chooseLeverage() async {
    if (_available <= 0) {
      await _showMessage('请先划转资金后再设置杠杆倍数');
      return;
    }
    final maxLeverage = math.max(1, _market.maxLeverage);
    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => _LeveragePickerSheet(
        palette: _palette,
        symbol: _market.name,
        initialLeverage: _leverage,
        maxLeverage: maxLeverage,
      ),
    );
    if (result != null && mounted) setState(() => _leverage = result);
  }

  Future<void> _submitOrder(bool isBuy) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      await _showMessage('请输入正确的下单金额');
      return;
    }
    if (!_isMarketOrder &&
        (double.tryParse(_limitPriceController.text) ?? 0) <= 0) {
      await _showMessage('请输入正确的限价');
      return;
    }
    if (_takeProfitStopLoss &&
        [
          _takeProfitPriceController,
          _takeProfitRateController,
          _stopLossPriceController,
          _stopLossRateController,
        ].any((controller) => controller.text.trim().isEmpty)) {
      await _showMessage('请完善止盈止损参数');
      return;
    }
    if (widget.walletIdentity == null) {
      await _showMessage('请先创建或导入钱包');
      return;
    }
    setState(() => _loadingSubmit = true);
    await _showMessage(
      '订单参数已确认。Hyperliquid 实盘下单需要 EIP-712 签名，当前版本尚未接入签名提交。',
      title: isBuy ? '做多 ${_market.name}' : '做空 ${_market.name}',
    );
    if (mounted) setState(() => _loadingSubmit = false);
  }

  Future<void> _showMessage(String message, {String title = '提示'}) =>
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _palette.background,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AcoPageHeader(
              palette: _palette,
              titleFollowsBack: true,
              backButtonOffset: Offset.zero,
              onBack: () => Navigator.pop(context),
              titleWidget: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _MarketTitle(palette: _palette, market: _market),
              ),
              right: AcoIconButton(
                icon: Icons.candlestick_chart_outlined,
                palette: _palette,
                label: '查看K线',
                onPressed: () => unawaited(
                  _showMessage('K线图功能正在接入中', title: '${_market.name} K线'),
                ),
              ),
            ),
          ),
          Container(height: 1, color: _palette.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  _FundingHeader(
                    palette: _palette,
                    market: _market,
                    currentPrice: _referencePrice,
                    leverage: _leverage,
                    onLeveragePressed: _chooseLeverage,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 10,
                          child: _OrderBookPanel(
                            palette: _palette,
                            book: _orderBook,
                            market: _market,
                            loading: _loadingMarket,
                            levelCount: _takeProfitStopLoss ? 11 : 8,
                            onPriceSelected: (price) => setState(() {
                              _isMarketOrder = false;
                              _limitPriceController.text = _formatPlainPrice(
                                price,
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(flex: 17, child: _buildOrderForm()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: _palette.border),
                  _buildAccountSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildOrderForm() => Column(
    children: [
      Row(
        children: [
          Text('可用', style: TextStyle(color: _palette.mutedText, fontSize: 13)),
          const Spacer(),
          if (_loadingAccount)
            const CupertinoActivityIndicator(radius: 7)
          else
            Text(
              '\$${_formatMoney(_available)} USDC',
              style: TextStyle(
                color: _palette.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      _OrderTypeField(
        palette: _palette,
        marketOrder: _isMarketOrder,
        onChanged: (marketOrder) => setState(() {
          _isMarketOrder = marketOrder;
          if (!marketOrder && _limitPriceController.text.isEmpty) {
            _limitPriceController.text = _formatPlainPrice(_referencePrice);
          }
        }),
      ),
      const SizedBox(height: 10),
      if (!_isMarketOrder) ...[
        _TradeTextField(
          palette: _palette,
          controller: _limitPriceController,
          placeholder: '价格',
          suffix: 'USDC',
        ),
        const SizedBox(height: 10),
      ],
      _TradeTextField(
        palette: _palette,
        controller: _amountController,
        placeholder: '金额',
        suffix: 'USDC',
        height: 40,
        horizontalPadding: 9,
        borderRadius: 8,
        onChanged: (_) => setState(() => _amountRatio = 0),
      ),
      const SizedBox(height: 14),
      _AmountSlider(
        palette: _palette,
        value: _amountRatio,
        onChanged: _setAmountRatio,
      ),
      const SizedBox(height: 14),
      CupertinoButton(
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        onPressed: () =>
            setState(() => _takeProfitStopLoss = !_takeProfitStopLoss),
        child: Row(
          children: [
            Icon(
              _takeProfitStopLoss
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              size: 22,
              color: _takeProfitStopLoss ? _palette.accent : _palette.mutedText,
            ),
            const SizedBox(width: 8),
            Text(
              '止盈止损',
              style: TextStyle(
                color: _palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      if (_takeProfitStopLoss) ...[
        const SizedBox(height: 4),
        _RiskInputGrid(
          palette: _palette,
          takeProfitPriceController: _takeProfitPriceController,
          takeProfitRateController: _takeProfitRateController,
          stopLossPriceController: _stopLossPriceController,
          stopLossRateController: _stopLossRateController,
        ),
        const SizedBox(height: 14),
      ],
      _OrderSummary(
        palette: _palette,
        available: _available,
        leverage: _leverage,
      ),
      const SizedBox(height: 10),
      _TradeActionButton(
        label: _available > 0 ? '做多' : '资金划转',
        color: const Color(0xFF25C26E),
        loading: _loadingSubmit,
        onPressed: () => _submitOrder(true),
      ),
      const SizedBox(height: 14),
      _OrderSummary(
        palette: _palette,
        available: _available,
        leverage: _leverage,
      ),
      const SizedBox(height: 10),
      _TradeActionButton(
        label: _available > 0 ? '做空' : '资金划转',
        color: const Color(0xFFF14D51),
        loading: _loadingSubmit,
        onPressed: () => _submitOrder(false),
      ),
    ],
  );

  Widget _buildAccountSection() {
    const labels = ['余额', '持仓', '挂单'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var index = 0; index < labels.length; index++)
                CupertinoButton(
                  padding: const EdgeInsets.fromLTRB(0, 10, 26, 7),
                  minimumSize: Size.zero,
                  onPressed: () => setState(() => _selectedTab = index),
                  child: Column(
                    children: [
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: index == _selectedTab
                              ? _palette.primaryText
                              : _palette.mutedText,
                          fontSize: 14,
                          fontWeight: index == _selectedTab
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: 2,
                        color: index == _selectedTab
                            ? _palette.primaryText
                            : _transparent,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_selectedTab == 0) _buildBalanceTab(),
          if (_selectedTab == 1) _buildPositionsTab(),
          if (_selectedTab == 2) _buildOrdersTab(),
        ],
      ),
    );
  }

  Widget _buildBalanceTab() => _AccountBalanceCard(
    palette: _palette,
    account: _account,
    loading: _loadingAccount,
  );

  Widget _buildPositionsTab() {
    final positions = _account?.positions ?? const [];
    if (_loadingAccount) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (positions.isEmpty) {
      return _EmptyTradeState(palette: _palette, text: '暂无持仓');
    }
    return Column(
      children: [
        for (final position in positions)
          _PositionRow(palette: _palette, position: position),
      ],
    );
  }

  Widget _buildOrdersTab() {
    if (_loadingAccount) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_openOrders.isEmpty) {
      return _EmptyTradeState(palette: _palette, text: '暂无挂单');
    }
    return Column(
      children: [
        for (final order in _openOrders)
          _OpenOrderRow(palette: _palette, order: order),
      ],
    );
  }
}

class _MarketTitle extends StatelessWidget {
  const _MarketTitle({required this.palette, required this.market});

  final AcoPalette palette;
  final HyperliquidMarket market;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HyperliquidTokenIcon(symbol: market.name, palette: palette, size: 30),
        const SizedBox(width: 9),
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
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _FundingHeader extends StatelessWidget {
  const _FundingHeader({
    required this.palette,
    required this.market,
    required this.currentPrice,
    required this.leverage,
    required this.onLeveragePressed,
  });

  final AcoPalette palette;
  final HyperliquidMarket market;
  final double currentPrice;
  final int leverage;
  final VoidCallback onLeveragePressed;

  @override
  Widget build(BuildContext context) {
    final funding = (market.funding ?? 0) * 100;
    final change = market.changePercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FundingMetric(
              palette: palette,
              label: '资金费率 / 每小时',
              value: '${funding >= 0 ? '+' : ''}${funding.toStringAsFixed(4)}%',
            ),
          ),
          _FundingMetric(
            palette: palette,
            label: '当前价格',
            value: _formatPlainPrice(currentPrice),
            alignment: CrossAxisAlignment.end,
          ),
          const SizedBox(width: 24),
          _FundingMetric(
            palette: palette,
            label: '24小时涨跌',
            value: _formatHyperliquidChange(change),
            valueColor: _hyperliquidChangeColor(change, palette),
            alignment: CrossAxisAlignment.end,
          ),
          const SizedBox(width: 12),
          const _MarginModeBadge(),
          const SizedBox(width: 6),
          _LeverageBadge(leverage: leverage, onPressed: onLeveragePressed),
        ],
      ),
    );
  }
}

class _MarginModeBadge extends StatelessWidget {
  const _MarginModeBadge();

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      '全仓',
      style: TextStyle(
        color: _white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _LeverageBadge extends StatelessWidget {
  const _LeverageBadge({required this.leverage, required this.onPressed});

  final int leverage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: CupertinoButton(
      minimumSize: const Size(54, 32),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(8),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${leverage}x',
            style: const TextStyle(
              color: _white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_down, color: _white, size: 11),
        ],
      ),
    ),
  );
}

class _LeveragePickerSheet extends StatefulWidget {
  const _LeveragePickerSheet({
    required this.palette,
    required this.symbol,
    required this.initialLeverage,
    required this.maxLeverage,
  });

  final AcoPalette palette;
  final String symbol;
  final int initialLeverage;
  final int maxLeverage;

  @override
  State<_LeveragePickerSheet> createState() => _LeveragePickerSheetState();
}

class _LeveragePickerSheetState extends State<_LeveragePickerSheet> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialLeverage.clamp(1, widget.maxLeverage);
  }

  @override
  Widget build(BuildContext context) => CupertinoPopupSurface(
    child: SafeArea(
      top: false,
      child: Container(
        color: widget.palette.background,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '${widget.symbol} 杠杆倍数',
                  style: TextStyle(
                    color: widget.palette.primaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_value}x',
                  style: TextStyle(
                    color: widget.palette.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlider(
                value: _value.toDouble(),
                min: 1,
                max: widget.maxLeverage.toDouble(),
                divisions: math.max(1, widget.maxLeverage - 1),
                activeColor: widget.palette.accent,
                onChanged: (value) => setState(() => _value = value.round()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    '1x',
                    style: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.maxLeverage}x',
                    style: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                color: widget.palette.accent,
                onPressed: () => Navigator.pop(context, _value),
                child: const Text(
                  '确认',
                  style: TextStyle(color: _black, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FundingMetric extends StatelessWidget {
  const _FundingMetric({
    required this.palette,
    required this.label,
    required this.value,
    this.valueColor,
    this.alignment = CrossAxisAlignment.start,
  });

  final AcoPalette palette;
  final String label;
  final String value;
  final Color? valueColor;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        style: TextStyle(
          color: valueColor ?? palette.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _OrderBookPanel extends StatelessWidget {
  const _OrderBookPanel({
    required this.palette,
    required this.book,
    required this.market,
    required this.loading,
    required this.levelCount,
    required this.onPriceSelected,
  });

  final AcoPalette palette;
  final HyperliquidOrderBook? book;
  final HyperliquidMarket market;
  final bool loading;
  final int levelCount;
  final ValueChanged<double> onPriceSelected;

  @override
  Widget build(BuildContext context) {
    final asks = (book?.asks ?? const [])
        .take(levelCount)
        .toList()
        .reversed
        .toList();
    final bids = (book?.bids ?? const []).take(levelCount).toList();
    final maxSize = [
      ...asks,
      ...bids,
    ].fold<double>(1, (current, level) => math.max(current, level.size ?? 0));
    final middlePrice =
        market.markPrice ??
        book?.asks.firstOrNull?.price ??
        book?.bids.firstOrNull?.price;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '价格\n(USDC)',
                style: TextStyle(color: palette.mutedText, fontSize: 11),
              ),
            ),
            Text(
              '数量\n(${market.name})',
              textAlign: TextAlign.right,
              style: TextStyle(color: palette.mutedText, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (loading && book == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: CupertinoActivityIndicator(),
          )
        else ...[
          for (final level in asks)
            _BookLevelRow(
              palette: palette,
              level: level,
              maxSize: maxSize,
              isAsk: true,
              onTap: onPriceSelected,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatPlainPrice(middlePrice),
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (final level in bids)
            _BookLevelRow(
              palette: palette,
              level: level,
              maxSize: maxSize,
              isAsk: false,
              onTap: onPriceSelected,
            ),
        ],
      ],
    );
  }
}

class _BookLevelRow extends StatelessWidget {
  const _BookLevelRow({
    required this.palette,
    required this.level,
    required this.maxSize,
    required this.isAsk,
    required this.onTap,
  });

  final AcoPalette palette;
  final HyperliquidOrderBookLevel level;
  final double maxSize;
  final bool isAsk;
  final ValueChanged<double> onTap;

  @override
  Widget build(BuildContext context) {
    final price = level.price;
    final ratio = ((level.size ?? 0) / maxSize).clamp(0.0, 1.0);
    final color = isAsk ? const Color(0xFFF14D51) : const Color(0xFF25C26E);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: price == null ? null : () => onTap(price),
      child: SizedBox(
        height: 22,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            FractionallySizedBox(
              widthFactor: ratio,
              child: ColoredBox(color: color.withValues(alpha: .10)),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatPlainPrice(price),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatQuantity(level.size),
                  style: TextStyle(color: palette.primaryText, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTypeField extends StatelessWidget {
  const _OrderTypeField({
    required this.palette,
    required this.marketOrder,
    required this.onChanged,
  });

  final AcoPalette palette;
  final bool marketOrder;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: CupertinoButton(
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      color: palette.inputSurface,
      borderRadius: BorderRadius.circular(8),
      onPressed: () async {
        final selected = await showCupertinoModalPopup<bool>(
          context: context,
          builder: (context) => CupertinoActionSheet(
            title: const Text('选择订单类型'),
            actions: [
              CupertinoActionSheetAction(
                isDefaultAction: marketOrder,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('市价'),
              ),
              CupertinoActionSheetAction(
                isDefaultAction: !marketOrder,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('限价'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ),
        );
        if (selected != null) onChanged(selected);
      },
      child: Row(
        children: [
          Text(
            marketOrder ? '市价' : '限价',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Icon(
            CupertinoIcons.chevron_down,
            color: palette.primaryText,
            size: 14,
          ),
        ],
      ),
    ),
  );
}

class _RiskInputGrid extends StatelessWidget {
  const _RiskInputGrid({
    required this.palette,
    required this.takeProfitPriceController,
    required this.takeProfitRateController,
    required this.stopLossPriceController,
    required this.stopLossRateController,
  });

  final AcoPalette palette;
  final TextEditingController takeProfitPriceController;
  final TextEditingController takeProfitRateController;
  final TextEditingController stopLossPriceController;
  final TextEditingController stopLossRateController;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _TradeTextField(
              palette: palette,
              controller: takeProfitPriceController,
              placeholder: '止盈价格',
              suffix: '',
              height: 40,
              horizontalPadding: 9,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TradeTextField(
              palette: palette,
              controller: takeProfitRateController,
              placeholder: '收益',
              suffix: '%',
              height: 40,
              horizontalPadding: 9,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _TradeTextField(
              palette: palette,
              controller: stopLossPriceController,
              placeholder: '止损价格',
              suffix: '',
              height: 40,
              horizontalPadding: 9,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TradeTextField(
              palette: palette,
              controller: stopLossRateController,
              placeholder: '亏损',
              suffix: '%',
              height: 40,
              horizontalPadding: 9,
            ),
          ),
        ],
      ),
    ],
  );
}

class _TradeTextField extends StatelessWidget {
  const _TradeTextField({
    required this.palette,
    required this.controller,
    required this.placeholder,
    required this.suffix,
    this.onChanged,
    this.height = 44,
    this.horizontalPadding = 10,
    this.borderRadius = 10,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final String placeholder;
  final String suffix;
  final ValueChanged<String>? onChanged;
  final double height;
  final double horizontalPadding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    decoration: BoxDecoration(
      color: palette.inputSurface,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: Row(
      children: [
        Expanded(
          child: CupertinoTextField(
            controller: controller,
            padding: EdgeInsets.zero,
            decoration: null,
            placeholder: placeholder,
            placeholderStyle: TextStyle(color: palette.mutedText),
            style: TextStyle(color: palette.primaryText, fontSize: 15),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          suffix,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _AmountSlider extends StatelessWidget {
  const _AmountSlider({
    required this.palette,
    required this.value,
    required this.onChanged,
  });

  final AcoPalette palette;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const ratios = [0.0, .24, .5, .75, .97];
    final selectedIndex = value > 0 ? _nearestRatioIndex(ratios, value) : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 22.0;
        const pointSize = 12.0;
        const tooltipWidth = 42.0;
        final trackWidth = constraints.maxWidth - thumbSize;
        final stepWidth = trackWidth / (ratios.length - 1);

        void updateFromPosition(double dx) {
          final position = (dx - thumbSize / 2).clamp(0.0, trackWidth);
          final index = (position / stepWidth).round();
          onChanged(ratios[index]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateFromPosition(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              updateFromPosition(details.localPosition.dx),
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Positioned(
                  left: thumbSize / 2,
                  right: thumbSize / 2,
                  bottom: (thumbSize - 3) / 2,
                  child: Container(height: 3, color: const Color(0xFFE5E5E5)),
                ),
                if (selectedIndex != null)
                  Positioned(
                    left: thumbSize / 2,
                    width: stepWidth * selectedIndex,
                    bottom: (thumbSize - 3) / 2,
                    child: Container(height: 3, color: palette.accent),
                  ),
                for (var index = 0; index < ratios.length; index++)
                  Positioned(
                    left:
                        thumbSize / 2 +
                        stepWidth * index -
                        (index == selectedIndex ? thumbSize : pointSize) / 2,
                    bottom:
                        (thumbSize -
                            (index == selectedIndex ? thumbSize : pointSize)) /
                        2,
                    child: Container(
                      width: index == selectedIndex ? thumbSize : pointSize,
                      height: index == selectedIndex ? thumbSize : pointSize,
                      decoration: BoxDecoration(
                        color: selectedIndex != null && index <= selectedIndex
                            ? palette.accent
                            : const Color(0xFFFFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedIndex != null && index <= selectedIndex
                              ? palette.accent
                              : const Color(0xFFD6D6D6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (selectedIndex != null)
                  Positioned(
                    top: 0,
                    left:
                        (thumbSize / 2 +
                                stepWidth * selectedIndex -
                                tooltipWidth / 2)
                            .clamp(0.0, constraints.maxWidth - tooltipWidth),
                    child: Container(
                      width: tooltipWidth,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.surfaceRaised,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${(ratios[selectedIndex] * 100).round()}%',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _nearestRatioIndex(List<double> ratios, double currentValue) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < ratios.length; index++) {
      final distance = (ratios[index] - currentValue).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.palette,
    required this.available,
    required this.leverage,
  });

  final AcoPalette palette;
  final double available;
  final int leverage;

  @override
  Widget build(BuildContext context) {
    final maxNotional = available * leverage;
    return Column(
      children: [
        _summaryRow('最大可开', '\$${_formatMoney(maxNotional)} USDC'),
        const SizedBox(height: 5),
        _summaryRow('强平价格', '--'),
      ],
    );
  }

  Widget _summaryRow(String label, String value) => Row(
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 12)),
      const Spacer(),
      Text(value, style: TextStyle(color: palette.primaryText, fontSize: 12)),
    ],
  );
}

class _TradeActionButton extends StatelessWidget {
  const _TradeActionButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 42,
    child: CupertinoButton(
      minimumSize: const Size(42, 42),
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: color,
      borderRadius: BorderRadius.circular(8),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const CupertinoActivityIndicator(color: _white)
          : Text(
              label,
              style: const TextStyle(
                color: _white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard({
    required this.palette,
    required this.account,
    required this.loading,
  });

  final AcoPalette palette;
  final HyperliquidAccountState? account;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CupertinoActivityIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: SvgPicture.asset(
                'assets/icons/crypto/tokens/usdc.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'USDC',
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
            Expanded(child: _metric('总余额', account?.accountValue ?? 0)),
            Expanded(child: _metric('可用余额', account?.withdrawable ?? 0)),
          ],
        ),
        const SizedBox(height: 16),
        _metric('未实现盈亏', account?.totalUnrealizedPnl ?? 0),
      ],
    );
  }

  Widget _metric(String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 12)),
      const SizedBox(height: 5),
      Text(
        '\$${_formatMoney(value)}',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({required this.palette, required this.position});

  final AcoPalette palette;
  final HyperliquidPosition position;

  @override
  Widget build(BuildContext context) {
    final isLong = (position.size ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${position.coin} ${isLong ? '多' : '空'}',
              style: TextStyle(
                color: isLong
                    ? const Color(0xFF25C26E)
                    : const Color(0xFFF14D51),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _valueColumn('持仓量', _formatQuantity(position.size?.abs())),
          const SizedBox(width: 22),
          _valueColumn(
            '未实现盈亏',
            '\$${_formatMoney(position.unrealizedPnl ?? 0)}',
          ),
        ],
      ),
    );
  }

  Widget _valueColumn(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 11)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: palette.primaryText, fontSize: 13)),
    ],
  );
}

class _OpenOrderRow extends StatelessWidget {
  const _OpenOrderRow({required this.palette, required this.order});

  final AcoPalette palette;
  final HyperliquidOpenOrder order;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: palette.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${order.coin} ${order.isBuy ? '买入' : '卖出'}',
            style: TextStyle(
              color: order.isBuy
                  ? const Color(0xFF25C26E)
                  : const Color(0xFFF14D51),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${_formatQuantity(order.size)} @ ${_formatPlainPrice(order.price)}',
          style: TextStyle(color: palette.primaryText, fontSize: 13),
        ),
      ],
    ),
  );
}

class _EmptyTradeState extends StatelessWidget {
  const _EmptyTradeState({required this.palette, required this.text});

  final AcoPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Text(
        text,
        style: TextStyle(color: palette.mutedText, fontSize: 14),
      ),
    ),
  );
}

String _formatPlainPrice(double? value) {
  if (value == null || !value.isFinite) return '--';
  final decimals = value >= 1000
      ? 1
      : value >= 100
      ? 2
      : value >= 1
      ? 3
      : 6;
  return _trimTrailingZeros(value.toStringAsFixed(decimals));
}

String _formatQuantity(double? value) {
  if (value == null || !value.isFinite) return '--';
  final absolute = value.abs();
  if (absolute >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (absolute >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
  return _trimTrailingZeros(value.toStringAsFixed(4));
}

String _formatMoney(double value) =>
    value == 0 ? '0' : _trimTrailingZeros(value.toStringAsFixed(2));
