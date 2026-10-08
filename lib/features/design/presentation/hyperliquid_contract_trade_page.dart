part of 'aco_design_shell.dart';

/// Agent keys live only for the current app process. Leaving a page does not
/// require another unlock, while an app restart naturally clears the cache.
final Map<String, String> _hyperliquidSessionAgentKeys = {};

class _HyperliquidContractTradePage extends StatefulWidget {
  const _HyperliquidContractTradePage({
    required this.palette,
    required this.market,
    required this.walletIdentity,
    required this.defaultNetwork,
  });

  final AcoPalette palette;
  final HyperliquidMarket market;
  final WalletIdentity? walletIdentity;
  final WalletNetwork defaultNetwork;

  @override
  State<_HyperliquidContractTradePage> createState() =>
      _HyperliquidContractTradePageState();
}

class _HyperliquidContractTradePageState
    extends State<_HyperliquidContractTradePage> {
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _limitPriceController = TextEditingController();
  final _takeProfitPriceController = TextEditingController();
  final _takeProfitRateController = TextEditingController();
  final _stopLossPriceController = TextEditingController();
  final _stopLossRateController = TextEditingController();
  final _client = HyperliquidApiClient();
  final _exchange = HyperliquidExchangeClient();
  final _agentStore = HyperliquidAgentStore();
  final _builderApprovalStore = HyperliquidBuilderApprovalStore();
  final _tradeFeeClient = TradeFeeConfigClient();
  final _realtimeClient = HyperliquidRealtimeClient();

  HyperliquidOrderBook? _orderBook;
  HyperliquidMarket? _liveMarket;
  HyperliquidAccountState? _account;
  List<HyperliquidOpenOrder> _openOrders = const [];
  List<HyperliquidUserFill> _userFills = const [];
  StreamSubscription<HyperliquidRealtimeUpdate>? _realtimeSubscription;
  Timer? _fallbackTimer;
  HyperliquidAgent? _agent;
  TradeFeeConfig? _tradeFeeConfig;
  double _spotUsdcAvailable = 0;
  bool _loadingMarket = true;
  bool _loadingAccount = true;
  bool _isMarketOrder = true;
  bool _takeProfitStopLoss = false;
  bool _loadingSubmit = false;
  int _leverage = 20;
  int _selectedTab = 0;
  double _amountRatio = 0;

  AcoPalette get _palette => widget.palette;
  HyperliquidMarket get _market => _liveMarket ?? widget.market;
  double get _available =>
      math.max(_account?.withdrawable ?? 0, _spotUsdcAvailable);
  double get _referencePrice =>
      _market.markPrice ??
      _orderBook?.asks.firstOrNull?.price ??
      _orderBook?.bids.firstOrNull?.price ??
      0;

  @override
  void initState() {
    super.initState();
    _leverage = math.min(20, math.max(1, _market.maxLeverage));
    _limitPriceController.text = _formatPlainPrice(_market.markPrice);
    unawaited(_loadMarket());
    unawaited(_loadAccount());
    unawaited(_loadAgent());
    unawaited(_loadTradeFeeConfig());
    _realtimeSubscription = _realtimeClient
        .subscribe(coin: _market.name, user: widget.walletIdentity?.address)
        .listen(_applyRealtimeUpdate, onError: (_) => _startHttpFallback());
  }

  void _applyRealtimeUpdate(HyperliquidRealtimeUpdate update) {
    final connected = update.connected;
    if (connected == true) {
      _fallbackTimer?.cancel();
    } else if (connected == false) {
      _startHttpFallback();
    }
    if (!mounted) return;
    setState(() {
      if (update.orderBook != null) {
        _orderBook = update.orderBook;
        _loadingMarket = false;
      }
      if (update.assetContext != null) {
        _liveMarket = widget.market.withContext(update.assetContext!);
      }
      if (update.account != null) {
        _account = update.account;
        _loadingAccount = false;
      }
      if (update.openOrders != null) {
        _openOrders = update.openOrders!;
        _loadingAccount = false;
      }
    });
  }

  void _startHttpFallback() {
    if (_fallbackTimer?.isActive == true) return;
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_loadMarket(showLoading: false));
      unawaited(_loadAccount(showLoading: false));
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_realtimeClient.close());
    _amountController.dispose();
    _amountFocusNode.dispose();
    _limitPriceController.dispose();
    _takeProfitPriceController.dispose();
    _takeProfitRateController.dispose();
    _stopLossPriceController.dispose();
    _stopLossRateController.dispose();
    _client.close();
    _exchange.close();
    _tradeFeeClient.close();
    super.dispose();
  }

  Future<void> _loadAgent() async {
    final identity = widget.walletIdentity;
    if (identity == null) return;
    try {
      final agent = await _agentStore.read(identity.address);
      if (mounted) setState(() => _agent = agent);
    } catch (_) {
      // The wallet page remains usable even if local agent metadata is absent.
    }
  }

  Future<TradeFeeConfig?> _loadTradeFeeConfig() async {
    try {
      final config = await _tradeFeeClient.load();
      debugPrint(
        '[HyperliquidBuilder] builderAddress=${config.hyperliquid.builderAddress}',
      );
      if (mounted) setState(() => _tradeFeeConfig = config);
      return config;
    } catch (error) {
      debugPrint('[HyperliquidBuilder] config load failed: $error');
      return null;
    }
  }

  Future<TradeFeeConfig?> _ensureTradeFeeConfig() async {
    return _tradeFeeConfig ?? await _loadTradeFeeConfig();
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

  Future<void> _loadAccount({bool showLoading = true}) async {
    final address = widget.walletIdentity?.address;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _loadingAccount = false);
      return;
    }
    if (showLoading) setState(() => _loadingAccount = true);
    try {
      final results = await Future.wait<Object>([
        _client.loadAccountState(address),
        _client.loadOpenOrders(address),
        _client.loadSpotBalances(address),
        _client.loadUserFills(address),
      ]);
      if (!mounted) return;
      setState(() {
        _account = results[0] as HyperliquidAccountState;
        _openOrders = results[1] as List<HyperliquidOpenOrder>;
        final spotBalances = results[2] as List<HyperliquidSpotBalance>;
        _spotUsdcAvailable = spotBalances
            .where((balance) => balance.coin.toUpperCase() == 'USDC')
            .fold<double>(0, (total, balance) => total + balance.available);
        _userFills = results[3] as List<HyperliquidUserFill>;
      });
    } catch (_) {
      // Empty account data is a valid degraded state for the trading page.
    } finally {
      if (mounted && showLoading) setState(() => _loadingAccount = false);
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
      await _showDepositSheet();
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
    if (result == null || !mounted) return;
    if (widget.walletIdentity == null) return;
    try {
      final agentPrivateKey = await _unlockApprovedAgent();
      if (agentPrivateKey == null) return;
      await _exchange.updateLeverage(
        agentPrivateKey: agentPrivateKey,
        asset: _market.asset,
        leverage: result,
      );
      if (mounted) setState(() => _leverage = result);
    } on WalletSecurityException catch (error) {
      if (mounted) await _showMessage(error.message);
    } on HyperliquidExchangeException catch (error) {
      if (mounted) await _showMessage(error.message);
    } catch (_) {
      if (mounted) await _showMessage('杠杆设置失败，请稍后重试');
    }
  }

  Future<void> _submitOrder(bool isBuy) async {
    if (_available <= 0) {
      await _showDepositSheet();
      return;
    }
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
    if (_takeProfitStopLoss) {
      final takeProfit = double.tryParse(_takeProfitPriceController.text);
      final stopLoss = double.tryParse(_stopLossPriceController.text);
      final takeProfitRate = double.tryParse(_takeProfitRateController.text);
      final stopLossRate = double.tryParse(_stopLossRateController.text);
      if (takeProfit == null ||
          stopLoss == null ||
          takeProfit <= 0 ||
          stopLoss <= 0 ||
          takeProfitRate == null ||
          stopLossRate == null ||
          takeProfitRate <= 0 ||
          stopLossRate <= 0) {
        await _showMessage('止盈止损参数必须是大于 0 的数字');
        return;
      }
    }
    if (widget.walletIdentity == null) {
      await _showMessage('请先创建或导入钱包');
      return;
    }
    final referencePrice = _referencePrice;
    if (referencePrice <= 0) {
      await _showMessage('暂时无法获取市场价格，请稍后重试');
      return;
    }
    final marketPrice = isBuy ? referencePrice * 1.05 : referencePrice * .95;
    final price = _isMarketOrder
        ? marketPrice
        : double.parse(_limitPriceController.text);
    final size = amount / price;
    if (size <= 0 || double.tryParse(_formatSize(size)) == 0) {
      await _showMessage('下单数量无效');
      return;
    }
    if (_takeProfitStopLoss) {
      final takeProfit = double.parse(_takeProfitPriceController.text);
      final stopLoss = double.parse(_stopLossPriceController.text);
      final valid = isBuy
          ? takeProfit > price && stopLoss < price
          : takeProfit < price && stopLoss > price;
      if (!valid) {
        await _showMessage('止盈止损价格方向与开仓方向不匹配');
        return;
      }
    }
    final feeConfig = await _ensureTradeFeeConfig();
    final action = _buildOrderAction(
      isBuy: isBuy,
      price: price,
      size: size,
      builder: feeConfig?.hyperliquid,
    );
    final confirmed = await _confirmOrder(
      title: isBuy ? '确认做多 ${_market.name}' : '确认做空 ${_market.name}',
      message:
          '${_isMarketOrder ? '市价' : '限价'}\n'
          '保证金 ${_formatMoney(amount)} USDC\n'
          '价格 ${_formatPlainPrice(price)}\n'
          '数量 ${_formatSize(size)}',
    );
    if (!confirmed || !mounted) return;
    setState(() => _loadingSubmit = true);
    try {
      final agentPrivateKey = await _unlockApprovedAgent(
        builder: feeConfig?.hyperliquid,
      );
      if (agentPrivateKey == null) return;
      await _exchange.placeOrder(
        agentPrivateKey: agentPrivateKey,
        action: action,
        expiresAfter: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
        debugSignerAddress: HyperliquidSigner.addressFromPrivateKey(
          agentPrivateKey,
        ),
      );
      await _loadAccount(showLoading: false);
      if (mounted) {
        await _showMessage('订单已提交。', title: '下单成功');
      }
    } on WalletSecurityException catch (error) {
      if (mounted) await _showMessage(error.message);
    } on HyperliquidExchangeException catch (error) {
      if (mounted) await _showMessage(error.message);
    } catch (_) {
      if (mounted) await _showMessage('下单失败，请检查余额、价格和市场状态');
    } finally {
      if (mounted) {
        setState(() => _loadingSubmit = false);
        await _dismissOrderAmountFocus();
      }
    }
  }

  Future<void> _dismissOrderAmountFocus() async {
    _amountFocusNode.unfocus();
    if (mounted) FocusScope.of(context).unfocus();
    await WidgetsBinding.instance.endOfFrame;
    _amountFocusNode.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  Map<String, dynamic> _buildOrderAction({
    required bool isBuy,
    required double price,
    required double size,
    HyperliquidBuilderFeeConfig? builder,
  }) {
    final sizeText = _formatSize(size);
    final priceText = _formatOrderPrice(price);
    final orders = <Map<String, dynamic>>[
      HyperliquidSigner.orderWire(
        asset: _market.asset,
        isBuy: isBuy,
        price: priceText,
        size: sizeText,
        reduceOnly: false,
        market: _isMarketOrder,
      ),
    ];
    if (_takeProfitStopLoss) {
      final takeProfit = double.parse(_takeProfitPriceController.text);
      final stopLoss = double.parse(_stopLossPriceController.text);
      orders.addAll([
        HyperliquidSigner.orderWire(
          asset: _market.asset,
          isBuy: !isBuy,
          price: _formatOrderPrice(takeProfit),
          size: sizeText,
          reduceOnly: true,
          triggerPrice: takeProfit,
          tpsl: 'tp',
        ),
        HyperliquidSigner.orderWire(
          asset: _market.asset,
          isBuy: !isBuy,
          price: _formatOrderPrice(stopLoss),
          size: sizeText,
          reduceOnly: true,
          triggerPrice: stopLoss,
          tpsl: 'sl',
        ),
      ]);
    }
    final action = <String, dynamic>{
      'type': 'order',
      'orders': orders,
      'grouping': _takeProfitStopLoss ? 'normalTpsl' : 'na',
    };
    final builderPayload = builder?.orderBuilder;
    if (builderPayload != null) {
      // Hyperliquid parses builder addresses as bytes and canonicalizes them
      // to lowercase before verifying the signature. Keep the exact same
      // canonical representation in both the MessagePack payload and JSON.
      action['builder'] = {
        ...builderPayload,
        'b': '${builderPayload['b']}'.toLowerCase(),
      };
    }
    return action;
  }

  Future<String?> _unlockApprovedAgent({
    HyperliquidBuilderFeeConfig? builder,
  }) async {
    final identity = widget.walletIdentity;
    if (identity == null) {
      await _showMessage('请先创建或导入钱包');
      return null;
    }
    final cacheKey = identity.address.toLowerCase();
    final cachedPrivateKey = _hyperliquidSessionAgentKeys[cacheKey];
    if (cachedPrivateKey != null) return cachedPrivateKey;
    final masterMnemonic = await _authorizeWallet(identity);
    await _ensureBuilderApproval(
      identity: identity,
      masterMnemonic: masterMnemonic,
      builder: builder,
    );
    var agent = _agent ?? await _agentStore.read(identity.address);
    agent ??= await _agentStore.create(identity.address);
    if (!agent.approved) {
      await _exchange.approveAgent(
        masterPrivateKey: WalletIdentity.privateKeyFromMnemonic(masterMnemonic),
        agentAddress: agent.address,
        agentName: agent.name,
      );
      await _agentStore.markApproved(identity.address, agent);
      agent = HyperliquidAgent(
        address: agent.address,
        name: agent.name,
        approved: true,
      );
      if (mounted) setState(() => _agent = agent);
    }
    final agentPrivateKey = WalletIdentity.privateKeyFromMnemonic(
      await _agentStore.unlock(agent),
    );
    final derivedAddress = HyperliquidSigner.addressFromPrivateKey(
      agentPrivateKey,
    );
    developer.log(
      'agent metadata=${agent.address} derived=$derivedAddress '
      'approved=${agent.approved} network=${AppConfig.hyperliquidTestnet ? 'testnet' : 'mainnet'}',
      name: 'HyperliquidAgent',
    );
    if (derivedAddress.toLowerCase() != agent.address.toLowerCase()) {
      throw const WalletSecurityException('API Agent 钱包数据不一致，请重新授权');
    }
    _hyperliquidSessionAgentKeys[cacheKey] = agentPrivateKey;
    return agentPrivateKey;
  }

  Future<String> _authorizeWallet(WalletIdentity identity) async {
    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    final store = SecureWalletSecretStore();
    final security = WalletSecurity();
    final biometric = await BiometricAuthentication.availability();
    if (biometric == BiometricAvailability.enrolled) {
      if (!await BiometricAuthentication.authenticateOrSkip()) {
        throw const WalletSecurityException('生物识别验证失败');
      }
      try {
        return await security.unlockMnemonicWithDeviceProtection(
          store: store,
          walletAddress: identity.address,
        );
      } on WalletSecurityException catch (error) {
        if (error.message != '未配置设备保护') rethrow;
      }
    }
    if (!mounted) throw const WalletSecurityException('钱包授权已取消');
    final password = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        var value = '';
        return StatefulBuilder(
          builder: (context, setState) => CupertinoAlertDialog(
            title: const Text('验证钱包密码'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                obscureText: true,
                autofocus: true,
                placeholder: '输入钱包密码',
                onChanged: (text) => setState(() => value = text),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: value.length < 8
                    ? null
                    : () => Navigator.of(dialogContext).pop(value),
                child: const Text('确认'),
              ),
            ],
          ),
        );
      },
    );
    await _dismissOrderAmountFocus();
    if (password == null) {
      throw const WalletSecurityException('钱包授权已取消');
    }
    return security.unlockMnemonic(
      store: store,
      walletAddress: identity.address,
      password: password,
    );
  }

  Future<void> _ensureBuilderApproval({
    required WalletIdentity identity,
    required String masterMnemonic,
    required HyperliquidBuilderFeeConfig? builder,
  }) async {
    debugPrint(
      '[HyperliquidBuilder] network=${AppConfig.hyperliquidTestnet ? 'testnet' : 'mainnet'} '
      'approval builderAddress=${builder?.builderAddress ?? '(none)'}',
    );
    if (builder == null || builder.orderBuilder == null) return;
    try {
      final builderAccount = await _client.loadAccountState(
        builder.builderAddress,
      );
      debugPrint(
        '[HyperliquidBuilder] builder perp accountValue=${builderAccount.accountValue} USDC',
      );
      final spotBalances = await _client.loadSpotBalances(
        builder.builderAddress,
      );
      final spotUsdc = spotBalances
          .where((balance) => balance.coin.toUpperCase() == 'USDC')
          .fold<double>(0, (total, balance) => total + balance.available);
      debugPrint('[HyperliquidBuilder] builder spot USDC available=$spotUsdc');
    } catch (error) {
      debugPrint('[HyperliquidBuilder] balance lookup failed: $error');
    }
    final existing = await _builderApprovalStore.read(identity.address);
    if (existing?.builderAddress == builder.builderAddress &&
        existing?.maxFeeRate == builder.maxFeeRate) {
      return;
    }
    await _exchange.approveBuilderFee(
      masterPrivateKey: WalletIdentity.privateKeyFromMnemonic(masterMnemonic),
      builderAddress: builder.builderAddress,
      maxFeeRate: builder.maxFeeRate,
    );
    await _builderApprovalStore.markApproved(
      identity.address,
      HyperliquidBuilderApproval(
        builderAddress: builder.builderAddress,
        maxFeeRate: builder.maxFeeRate,
      ),
    );
  }

  Future<bool> _confirmOrder({
    required String title,
    required String message,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String _formatSize(double value) =>
      _trimTrailingZeros(value.toStringAsFixed(_market.szDecimals));

  String _formatOrderPrice(double value) {
    if (!value.isFinite || value == 0) return '0';
    // Hyperliquid perp prices are limited both by the market's decimal
    // precision and by five significant digits. Merely using 6-szDecimals
    // can produce values such as 125.181, which are not divisible by the
    // actual tick size (0.01 for that price range).
    final maxDecimals = math.max(0, 6 - _market.szDecimals);
    final magnitude = (math.log(value.abs()) / math.ln10).floor();
    final significantDecimals = math.max(0, 5 - magnitude - 1);
    final decimals = math.min(maxDecimals, significantDecimals);
    return _trimTrailingZeros(value.toStringAsFixed(decimals));
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

  Future<void> _showDepositSheet({bool withdraw = false}) async {
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _HyperliquidUsdcDepositSheet(
        palette: _palette,
        contractAvailable: _account?.withdrawable ?? 0,
        walletIdentity: widget.walletIdentity,
        defaultNetwork: widget.defaultNetwork,
        onCompleted: () => unawaited(_loadAccount(showLoading: false)),
        initialWithdraw: withdraw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: _palette.background,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: FocusScope.of(context).unfocus,
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
                  onPressed: () => Navigator.of(context).push<void>(
                    _AcoPageRoute<void>(
                      builder: (_) => _HyperliquidContractKlinePage(
                        palette: _palette,
                        market: _market,
                      ),
                    ),
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
        focusNode: _amountFocusNode,
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
        label: _available > 0 ? '做多' : '请先充值',
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
        label: _available > 0 ? '做空' : '请先充值',
        color: const Color(0xFFF14D51),
        loading: _loadingSubmit,
        onPressed: () => _submitOrder(false),
      ),
    ],
  );

  Widget _buildAccountSection() {
    const labels = ['余额', '持仓', '挂单', '历史成交'];
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
          if (_selectedTab == 3) _buildFillsTab(),
        ],
      ),
    );
  }

  Widget _buildBalanceTab() => _AccountBalanceCard(
    palette: _palette,
    account: _account,
    available: _available,
    loading: _loadingAccount,
    onDeposit: () => _showDepositSheet(),
    onWithdraw: () => _showDepositSheet(withdraw: true),
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
          _PositionRow(
            palette: _palette,
            position: position,
            markPrice: _referencePrice,
            onClose: () => _closePosition(position),
          ),
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
          _OpenOrderRow(
            palette: _palette,
            order: order,
            onCancel: () => _cancelOrder(order),
          ),
      ],
    );
  }

  Widget _buildFillsTab() {
    if (_loadingAccount) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_userFills.isEmpty) {
      return _EmptyTradeState(palette: _palette, text: '暂无历史成交');
    }
    return Column(
      children: [
        for (final fill in _userFills)
          _UserFillRow(palette: _palette, fill: fill),
      ],
    );
  }

  Future<void> _cancelOrder(HyperliquidOpenOrder order) async {
    if (_loadingSubmit) return;
    final confirmed = await _confirmOrder(
      title: '撤销挂单',
      message:
          '${order.coin} ${order.isBuy ? '买入' : '卖出'} ${_formatQuantity(order.size)}',
    );
    if (!confirmed || !mounted) return;
    setState(() => _loadingSubmit = true);
    try {
      final agentPrivateKey = await _unlockApprovedAgent();
      if (agentPrivateKey == null) return;
      await _exchange.cancelOrder(
        agentPrivateKey: agentPrivateKey,
        asset: _market.asset,
        orderId: order.orderId,
      );
      await _loadAccount(showLoading: false);
      if (mounted) await _showMessage('挂单已撤销');
    } on WalletSecurityException catch (error) {
      if (mounted) await _showMessage(error.message);
    } on HyperliquidExchangeException catch (error) {
      if (mounted) await _showMessage(error.message);
    } catch (_) {
      if (mounted) await _showMessage('撤单失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loadingSubmit = false);
    }
  }

  Future<void> _closePosition(HyperliquidPosition position) async {
    final size = position.size?.abs() ?? 0;
    if (size <= 0 || _referencePrice <= 0) return;
    final isBuy = (position.size ?? 0) < 0;
    final confirmed = await _confirmOrder(
      title: '确认平仓 ${position.coin}',
      message:
          '市价平仓 ${_formatQuantity(size)}，预计价格 ${_formatPlainPrice(_referencePrice)}',
    );
    if (!confirmed || !mounted) return;
    setState(() => _loadingSubmit = true);
    try {
      final agentPrivateKey = await _unlockApprovedAgent();
      if (agentPrivateKey == null) return;
      await _exchange.placeOrder(
        agentPrivateKey: agentPrivateKey,
        action: HyperliquidSigner.orderAction(
          asset: _market.asset,
          isBuy: isBuy,
          price: _formatOrderPrice(_referencePrice * (isBuy ? 1.05 : .95)),
          size: _formatSize(size),
          reduceOnly: true,
          market: true,
        ),
        expiresAfter: DateTime.now().millisecondsSinceEpoch + 60 * 1000,
      );
      await _loadAccount(showLoading: false);
      if (mounted) await _showMessage('平仓订单已提交');
    } on WalletSecurityException catch (error) {
      if (mounted) await _showMessage(error.message);
    } on HyperliquidExchangeException catch (error) {
      if (mounted) await _showMessage(error.message);
    } catch (_) {
      if (mounted) await _showMessage('平仓失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loadingSubmit = false);
    }
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
              label: '资金费率',
              value: '${funding >= 0 ? '+' : ''}${funding.toString()}%',
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
            title: const Text('选择订单类型', style: TextStyle(fontSize: 16)),
            actions: [
              CupertinoActionSheetAction(
                isDefaultAction: marketOrder,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('市价', style: TextStyle(fontSize: 18)),
              ),
              CupertinoActionSheetAction(
                isDefaultAction: !marketOrder,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('限价', style: TextStyle(fontSize: 18)),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(fontSize: 17)),
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
    this.focusNode,
    this.height = 44,
    this.horizontalPadding = 10,
    this.borderRadius = 10,
  });

  final AcoPalette palette;
  final TextEditingController controller;
  final String placeholder;
  final String suffix;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
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
            focusNode: focusNode,
            autofocus: false,
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

class _HyperliquidUsdcDepositSheet extends StatefulWidget {
  const _HyperliquidUsdcDepositSheet({
    required this.palette,
    required this.contractAvailable,
    required this.walletIdentity,
    required this.defaultNetwork,
    required this.onCompleted,
    this.initialWithdraw = false,
  });

  final AcoPalette palette;
  final double contractAvailable;
  final WalletIdentity? walletIdentity;
  final WalletNetwork defaultNetwork;
  final VoidCallback onCompleted;
  final bool initialWithdraw;

  @override
  State<_HyperliquidUsdcDepositSheet> createState() =>
      _HyperliquidUsdcDepositSheetState();
}

class _HyperliquidUsdcDepositSheetState
    extends State<_HyperliquidUsdcDepositSheet> {
  static const _assets = [
    _ContractTransferAsset(chain: 'BNB Chain', symbol: 'BNB'),
    _ContractTransferAsset(chain: 'BNB Chain', symbol: 'USDC'),
    _ContractTransferAsset(chain: 'BNB Chain', symbol: 'USDT'),
    _ContractTransferAsset(chain: 'Ethereum', symbol: 'ETH'),
    _ContractTransferAsset(chain: 'Ethereum', symbol: 'USDC'),
    _ContractTransferAsset(chain: 'Ethereum', symbol: 'USDT'),
    _ContractTransferAsset(chain: 'Solana', symbol: 'SOL'),
    _ContractTransferAsset(chain: 'Solana', symbol: 'USDC'),
    _ContractTransferAsset(chain: 'Solana', symbol: 'USDT'),
  ];

  String _amount = '';
  bool _cashToContract = true;
  bool _showKeypad = true;
  _ContractTransferAsset _asset = _assets[4];
  bool _submitting = false;
  String? _progressLabel;
  WalletBalance? _walletBalance;
  HyperliquidSpotBalance? _spotBalance;
  bool _walletBalanceLoading = false;
  int _walletBalanceRequestId = 0;
  final _hyperliquidClient = HyperliquidApiClient();
  final _exchange = HyperliquidExchangeClient();

  AcoPalette get palette => widget.palette;

  double get _available {
    if (_cashToContract) return _walletBalanceAmount;
    return widget.contractAvailable;
  }

  double get _walletBalanceAmount {
    if (AppConfig.hyperliquidTestnet) {
      return _spotBalance?.available ?? 0;
    }
    final balance = _walletBalance;
    if (balance == null || balance.balance == null) return 0;
    return double.tryParse(
          formatChainAmount(balance.balance!, decimals: balance.decimals),
        ) ??
        0;
  }

  double get _parsedAmount => double.tryParse(_amount) ?? 0;
  bool get _canConfirm => !_submitting && _parsedAmount > 0;

  @override
  void initState() {
    super.initState();
    _cashToContract = !widget.initialWithdraw;
    unawaited(_loadWalletBalance());
  }

  @override
  void dispose() {
    _hyperliquidClient.close();
    _exchange.close();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    final requestId = ++_walletBalanceRequestId;
    final identity = widget.walletIdentity;
    if (mounted) {
      setState(() {
        _walletBalance = null;
        _spotBalance = null;
        _walletBalanceLoading = identity != null;
      });
    }
    if (identity == null) return;

    if (AppConfig.hyperliquidTestnet) {
      try {
        final balances = await _hyperliquidClient.loadSpotBalances(
          identity.address,
        );
        if (!mounted || requestId != _walletBalanceRequestId) return;
        HyperliquidSpotBalance? selected;
        for (final balance in balances) {
          if (balance.coin.toUpperCase() == 'USDC') {
            selected = balance;
            break;
          }
        }
        setState(() {
          _spotBalance = selected;
          _walletBalanceLoading = false;
        });
      } catch (_) {
        if (!mounted || requestId != _walletBalanceRequestId) return;
        setState(() => _walletBalanceLoading = false);
      }
      return;
    }

    final tokenStore = await SecureAccountTokenStore().read();
    if (!mounted || requestId != _walletBalanceRequestId) return;
    if (tokenStore == null) {
      setState(() {
        _walletBalanceLoading = false;
      });
      return;
    }

    final portfolio = WalletPortfolioService();
    try {
      final balances = await portfolio.loadBalances(
        network: _asset.mayanNetwork,
        identity: identity,
        derivedAddresses: await WalletPreferences.derivedAddresses(identity),
        accessToken: tokenStore.accessToken,
      );
      if (!mounted || requestId != _walletBalanceRequestId) return;

      WalletBalance? selectedBalance;
      for (final balance in balances) {
        if (balance.symbol.toUpperCase() == _asset.symbol.toUpperCase()) {
          selectedBalance = balance;
          break;
        }
      }
      setState(() {
        _walletBalance = selectedBalance;
        _walletBalanceLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _walletBalanceRequestId) return;
      setState(() {
        _walletBalance = null;
        _walletBalanceLoading = false;
      });
    } finally {
      portfolio.close();
    }
  }

  void _append(String value) {
    if (value == '.') {
      if (_amount.contains('.')) return;
      setState(() => _amount = _amount.isEmpty ? '0.' : '$_amount.');
      return;
    }
    final decimalIndex = _amount.indexOf('.');
    if (decimalIndex >= 0 && _amount.length - decimalIndex > 6) return;
    setState(() {
      if (_amount == '0') {
        _amount = value;
      } else if (_amount.length < 14) {
        _amount += value;
      }
    });
  }

  void _delete() {
    if (_amount.isEmpty) return;
    setState(() => _amount = _amount.substring(0, _amount.length - 1));
  }

  void _setFraction(double fraction) {
    if (_available <= 0) return;
    setState(() {
      _amount = _trimTrailingZeros((_available * fraction).toStringAsFixed(6));
    });
  }

  Future<void> _pickAsset() async {
    final selected = await showCupertinoModalPopup<_ContractTransferAsset>(
      context: context,
      builder: (context) => _ContractTransferAssetPicker(
        palette: palette,
        assets: _assets,
        selected: _asset,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.mayanNetwork == WalletNetwork.solana &&
        !await _hasSolanaAddress()) {
      if (mounted) {
        await _showNotice('当前钱包没有 Solana 地址，请先导入或创建 Solana 钱包后再充值');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _asset = selected;
      _amount = '';
    });
    unawaited(_loadWalletBalance());
  }

  Future<bool> _hasSolanaAddress() async {
    final identity = widget.walletIdentity;
    if (identity == null) return false;
    try {
      final addresses = await WalletPreferences.derivedAddresses(identity);
      return addresses['solana']?.isNotEmpty ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showNotice(String message) => showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('提示'),
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

  Future<bool> _hasSufficientWalletBalance() async {
    if (_walletBalanceLoading) {
      await _showNotice('正在获取 ${_asset.symbol} 余额，请稍后重试');
      return false;
    }
    if (AppConfig.hyperliquidTestnet) {
      if (_asset.symbol != 'USDC' || _spotBalance == null) {
        await _showNotice('测试网站内划转仅支持 Hyperliquid Spot USDC');
        return false;
      }
      if (_spotBalance!.available < _parsedAmount) {
        await _showNotice('Hyperliquid Spot USDC 余额不足');
        return false;
      }
      return true;
    }
    final selectedBalance = _walletBalance;
    if (selectedBalance == null ||
        selectedBalance.balance == null ||
        selectedBalance.error != null) {
      if (mounted) {
        await _showNotice('暂时无法获取 ${_asset.symbol} 余额，请稍后重试');
      }
      return false;
    }

    final requiredAmount = BigInt.parse(
      LifiApiClient.toBaseUnits(
        _trimTrailingZeros(_parsedAmount.toStringAsFixed(6)),
        _asset.decimals,
      ),
    );
    if (selectedBalance.balance! < requiredAmount) {
      await _showNotice(
        '当前 ${_asset.symbol} 余额不足，需要至少 '
        '${_trimTrailingZeros(_parsedAmount.toStringAsFixed(6))} ${_asset.symbol}',
      );
      return false;
    }
    return true;
  }

  Future<void> _submitDeposit() async {
    final identity = widget.walletIdentity;
    if (identity == null) {
      await _showNotice('请先创建或导入钱包');
      return;
    }
    if (!_canConfirm) {
      await _showNotice('请输入有效的划转金额');
      return;
    }
    setState(() {
      _submitting = true;
      _progressLabel = '正在准备交易，请稍候…';
    });
    try {
      if (_cashToContract && !await _hasSufficientWalletBalance()) return;
      if (!mounted) return;
      if (AppConfig.hyperliquidTestnet) {
        await _submitTestnetTransfer(identity);
        return;
      }
      if (!_cashToContract) {
        await _submitHyperliquidWithdrawal(identity);
        return;
      }
      await _submitLifiDeposit(identity);
    } on LifiException catch (error) {
      if (mounted) await _showNotice(error.message);
    } on HyperliquidExchangeException catch (error) {
      if (error.isUnifiedAccountActive) {
        widget.onCompleted();
        if (!mounted) return;
        await _showNotice(error.message);
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        await _showNotice(error.message);
      }
    } catch (error) {
      if (mounted) {
        final detail = error.toString().trim();
        await _showNotice(detail.isEmpty ? '获取资金划转路由失败，请稍后重试' : detail);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progressLabel = null;
        });
      }
    }
  }

  Future<void> _submitTestnetTransfer(WalletIdentity identity) async {
    // The trade page can remain mounted while the user switches wallets in
    // the shell. Never sign a transfer with the stale identity captured when
    // the page was opened.
    final activeIdentity = await WalletIdentityStore().activeIdentity();
    if (activeIdentity != null &&
        activeIdentity.address.toLowerCase() !=
            identity.address.toLowerCase()) {
      await _showNotice('当前页面仍绑定旧钱包地址，请返回后重新进入合约交易页面');
      return;
    }
    if (!_cashToContract && _parsedAmount > widget.contractAvailable) {
      await _showNotice('合约账户 USDC 余额不足');
      return;
    }
    final mnemonic = await _authorizeWallet(identity);
    final signedIdentity = WalletIdentity.fromMnemonic(mnemonic);
    if (signedIdentity.address.toLowerCase() !=
        identity.address.toLowerCase()) {
      throw WalletSecurityException(
        '钱包地址与安全存储中的助记词不一致：'
        '${signedIdentity.address}',
      );
    }
    await _exchange.usdClassTransfer(
      masterPrivateKey: WalletIdentity.privateKeyFromMnemonic(mnemonic),
      amount: _transferAmount,
      toPerp: _cashToContract,
      expectedSignerAddress: signedIdentity.address,
    );
    widget.onCompleted();
    if (!mounted) return;
    await _showNotice(
      _cashToContract ? 'Spot USDC 已划入合约账户' : '合约 USDC 已划回 Spot',
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _submitLifiDeposit(WalletIdentity identity) async {
    final token = _asset.lifiTokenAddress;
    if (token == null) {
      throw const LifiException('当前资产暂不支持划转');
    }
    if (_asset.mayanNetwork == WalletNetwork.tron) {
      throw const LifiException('当前充值只支持 EVM 网络资产');
    }

    final transferNetwork = _asset.mayanNetwork;
    final decimals = _asset.decimals;
    final sourceAddress = await _depositSourceAddress(identity);
    final tokenStore = await SecureAccountTokenStore().read();
    if (tokenStore == null) {
      throw const LifiException('请先登录账户后再进行链上充值');
    }
    final lifi = LifiApiClient();
    try {
      _updateProgress('正在获取 LI.FI 充值报价…');
      final quote = await lifi.hyperCoreDepositQuote(
        fromNetwork: transferNetwork,
        fromTokenAddress: token,
        amount: _transferAmount,
        decimals: decimals,
        walletAddress: sourceAddress,
        destinationAddress: identity.address,
      );
      final request = quote.transactionRequest;
      if (quote.fromTokenAddress?.toLowerCase() != token.toLowerCase()) {
        throw const LifiException('LI.FI 报价源代币与所选代币不一致，充值交易未发送');
      }
      if (quote.fromChainId != LifiApiClient.chainId(transferNetwork) ||
          quote.toChainId != LifiApiClient.hyperCoreChainId ||
          quote.toTokenAddress?.toLowerCase() !=
              LifiApiClient.hyperCorePerpsUsdc.toLowerCase() ||
          request == null ||
          (request['chainId'] is num &&
              (request['chainId'] as num).toInt() !=
                  LifiApiClient.chainId(transferNetwork))) {
        throw const LifiException('LI.FI 返回了无效的 HyperCore 充值交易');
      }
      final transactionData = request['data'];
      if (transferNetwork != WalletNetwork.solana &&
          token != '0x0000000000000000000000000000000000000000' &&
          (transactionData is! String ||
              !transactionData.toLowerCase().contains(
                token.substring(2).toLowerCase(),
              ))) {
        throw const LifiException('LI.FI 交易参数未使用所选代币，充值交易未发送');
      }
      if (!mounted) return;
      if (!await _confirmLifiDeposit(quote)) return;
      final mnemonic = await _authorizeWallet(identity);
      _updateProgress('密码验证成功，正在签名并提交充值交易…');
      if (transferNetwork == WalletNetwork.solana) {
        final signerAddress = const SolanaSigningService().addressForMnemonic(
          mnemonic,
        );
        if (signerAddress != sourceAddress) {
          throw const WalletSecurityException('Solana 地址与当前钱包不一致');
        }
        await _broadcastLifiSolanaDeposit(
          mnemonic: mnemonic,
          accessToken: tokenStore.accessToken,
          request: request,
        );
        return;
      }
      await _broadcastLifiDeposit(
        identity: identity,
        mnemonic: mnemonic,
        accessToken: tokenStore.accessToken,
        request: request,
        fromToken: token,
        spender: quote.approvalAddress,
        decimals: decimals,
      );
    } finally {
      lifi.close();
    }
  }

  Future<String> _depositSourceAddress(WalletIdentity identity) async {
    if (_asset.mayanNetwork != WalletNetwork.solana) return identity.address;
    final address = (await WalletPreferences.derivedAddresses(
      identity,
    ))['solana'];
    if (address == null || address.isEmpty) {
      throw const LifiException('当前钱包未配置 Solana 地址');
    }
    return address;
  }

  void _updateProgress(String message) {
    if (mounted) setState(() => _progressLabel = message);
  }

  Future<bool> _confirmLifiDeposit(LifiQuote quote) async =>
      await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('确认充值'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '充值：$_transferAmount ${_asset.symbol}（${_asset.chain}）\n'
              '预计到账：${_formatHyperCoreUsdc(quote.toAmount)} USDC\n'
              '最少到账：${_formatHyperCoreUsdc(quote.toAmountMin)} USDC\n'
              '预计路由费用：${quote.fee ?? '以报价为准'}',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认充值'),
            ),
          ],
        ),
      ) ??
      false;

  String _formatHyperCoreUsdc(String amount) {
    final baseUnits = BigInt.tryParse(amount);
    if (baseUnits == null) return amount;
    final unit = BigInt.from(1000000);
    final whole = baseUnits ~/ unit;
    final fraction = (baseUnits % unit).toString().padLeft(6, '0');
    final trimmedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmedFraction.isEmpty ? '$whole' : '$whole.$trimmedFraction';
  }

  Future<void> _broadcastLifiDeposit({
    required WalletIdentity identity,
    required String mnemonic,
    required String accessToken,
    required Map<String, dynamic> request,
    required String fromToken,
    required int decimals,
    String? spender,
  }) async {
    final rpc = WalletRpcClient(
      client: http.Client(),
      directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
      ownsClient: true,
    );
    try {
      final requiredAmount = LifiApiClient.toBaseUnits(
        _transferAmount,
        decimals,
      );
      final approvalSpender = spender ?? request['to'] as String?;
      if (fromToken != '0x0000000000000000000000000000000000000000' &&
          approvalSpender != null &&
          approvalSpender.isNotEmpty) {
        const transferService = WalletTransferService();
        _updateProgress('正在检查 ${_asset.symbol} 授权…');
        final approval = await transferService.ensureErc20AllowanceWithRpc(
          mnemonic: mnemonic,
          from: identity.address,
          network: _asset.mayanNetwork,
          accessToken: accessToken,
          rpc: rpc,
          tokenAddress: fromToken,
          spender: approvalSpender,
          requiredAmount: requiredAmount,
        );
        _updateProgress(approval == null ? '正在验证现有授权…' : '授权交易已发送，等待链上确认…');
        final approved = await transferService.waitForErc20AllowanceWithRpc(
          network: _asset.mayanNetwork,
          accessToken: accessToken,
          rpc: rpc,
          owner: identity.address,
          tokenAddress: fromToken,
          spender: approvalSpender,
          requiredAmount: requiredAmount,
        );
        if (!approved) {
          throw const LifiException('代币授权尚未确认，充值交易未发送，请稍后重试');
        }
        _updateProgress('授权已确认，正在提交充值交易…');
      }
      _updateProgress('正在提交充值交易…');
      final result = await const WalletTransferService()
          .executeTransactionRequestWithRpc(
            mnemonic: mnemonic,
            from: identity.address,
            network: _asset.mayanNetwork,
            accessToken: accessToken,
            rpc: rpc,
            transactionRequest: request,
          );
      widget.onCompleted();
      if (!mounted) return;
      await _showDepositSubmitted(result.hash);
      if (mounted) Navigator.pop(context);
    } finally {
      rpc.close();
    }
  }

  Future<void> _broadcastLifiSolanaDeposit({
    required String mnemonic,
    required String accessToken,
    required Map<String, dynamic> request,
  }) async {
    final serialized =
        request['serializedTransaction'] ??
        request['transaction'] ??
        request['data'];
    if (serialized is! String || serialized.isEmpty) {
      throw const LifiException('LI.FI 未返回可签名的 Solana 充值交易');
    }
    _updateProgress('正在签名 Solana 充值交易…');
    final signed = const SolanaSigningService().signSerializedTransaction(
      mnemonic: mnemonic,
      serializedTransaction: serialized,
    );
    final rpc = WalletRpcClient(
      client: http.Client(),
      directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
      ownsClient: true,
    );
    try {
      _updateProgress('正在提交 Solana 充值交易…');
      final endpoints = await rpc.loadEndpoints(
        network: WalletNetwork.solana.name,
        accessToken: accessToken,
      );
      final response = await rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'sendTransaction',
        'params': [
          signed,
          {'encoding': 'base64', 'skipPreflight': false},
        ],
      });
      final hash = response['result'];
      if (hash is! String || hash.isEmpty) {
        throw const LifiException('Solana RPC 未返回交易哈希');
      }
      widget.onCompleted();
      if (!mounted) return;
      await _showDepositSubmitted(hash);
      if (mounted) Navigator.pop(context);
    } finally {
      rpc.close();
    }
  }

  Future<void> _showDepositSubmitted(String hash) => showCupertinoDialog<void>(
    context: context,
    builder: (context) {
      var copied = false;
      return StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('充值已提交'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('交易已发送至源链，正在等待网络确认。'),
                const SizedBox(height: 10),
                const Text('交易哈希：'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(hash, textAlign: TextAlign.left),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 8),
                      minimumSize: Size.zero,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: hash));
                        setDialogState(() => copied = true);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            copied
                                ? CupertinoIcons.check_mark
                                : CupertinoIcons.doc_on_doc,
                            size: 16,
                            color: widget.palette.accent,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            copied ? '已复制' : '复制',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    },
  );

  Future<String> _authorizeWallet(WalletIdentity identity) async {
    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    final store = SecureWalletSecretStore();
    final security = WalletSecurity();
    final biometric = await BiometricAuthentication.availability();
    if (biometric == BiometricAvailability.enrolled) {
      if (!await BiometricAuthentication.authenticateOrSkip()) {
        throw const WalletSecurityException('生物识别验证失败');
      }
      try {
        return await security.unlockMnemonicWithDeviceProtection(
          store: store,
          walletAddress: identity.address,
        );
      } on WalletSecurityException catch (error) {
        if (error.message != '未配置设备保护') rethrow;
      }
    }
    if (!mounted) throw const WalletSecurityException('钱包授权已取消');
    final password = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) {
        var value = '';
        return StatefulBuilder(
          builder: (context, setState) => CupertinoAlertDialog(
            title: const Text('验证钱包密码'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                obscureText: true,
                autofocus: true,
                placeholder: '输入钱包密码',
                onChanged: (text) => setState(() => value = text),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: value.length < 8
                    ? null
                    : () => Navigator.of(dialogContext).pop(value),
                child: const Text('确认'),
              ),
            ],
          ),
        );
      },
    );
    if (password == null) {
      throw const WalletSecurityException('钱包授权已取消');
    }
    return security.unlockMnemonic(
      store: store,
      walletAddress: identity.address,
      password: password,
    );
  }

  String get _transferAmount =>
      _trimTrailingZeros(_parsedAmount.toStringAsFixed(6));
  String get _displayAssetSymbol =>
      !AppConfig.hyperliquidTestnet && !_cashToContract
      ? 'USDC'
      : _asset.symbol;

  Future<void> _submitHyperliquidWithdrawal(WalletIdentity identity) async {
    const withdrawalFee = 1.0;
    if (_parsedAmount <= withdrawalFee) {
      throw const HyperliquidExchangeException('提现金额需大于 1 USDC 手续费');
    }
    if (_parsedAmount > widget.contractAvailable) {
      throw const HyperliquidExchangeException('合约账户 USDC 余额不足');
    }
    if (!await _confirmHyperliquidWithdrawal()) return;
    if (!mounted) return;
    final mnemonic = await _authorizeWallet(identity);
    final signedIdentity = WalletIdentity.fromMnemonic(mnemonic);
    if (signedIdentity.address.toLowerCase() !=
        identity.address.toLowerCase()) {
      throw const WalletSecurityException('钱包地址与安全存储中的助记词不一致');
    }
    _updateProgress('正在提交 Hyperliquid 提现请求…');
    await _exchange.withdraw(
      masterPrivateKey: WalletIdentity.privateKeyFromMnemonic(mnemonic),
      destination: identity.address,
      amount: _transferAmount,
      expectedSignerAddress: signedIdentity.address,
    );
    widget.onCompleted();
    if (!mounted) return;
    await _showNotice(
      '提现请求已提交，预计约 5 分钟到账 Arbitrum。\n'
      '提现手续费：1 USDC\n'
      '收款地址：${identity.address}',
    );
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmHyperliquidWithdrawal() async =>
      await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('确认提现'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '提现：$_transferAmount USDC\n'
              '预计到账：${_trimTrailingZeros((_parsedAmount - 1).toStringAsFixed(6))} USDC\n'
              '到账网络：Arbitrum\n'
              '提现手续费：1 USDC',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认提现'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final controlColor = palette.dark
        ? const Color(0xFF1B1B1B)
        : const Color(0xFFF5F5F5);
    final spotLabel = AppConfig.hyperliquidTestnet ? 'Spot' : '现金';
    late final String destination;
    late final String transferTitle;
    late final String amountPlaceholder;
    if (_cashToContract) {
      destination = '合约';
      transferTitle = AppConfig.hyperliquidTestnet ? '划转' : '充值';
      amountPlaceholder = AppConfig.hyperliquidTestnet ? '输入划转金额' : '输入充值金额';
    } else {
      destination = AppConfig.hyperliquidTestnet ? spotLabel : 'Arbitrum';
      transferTitle = '提现';
      amountPlaceholder = '输入划转金额';
    }
    return CupertinoPopupSurface(
      isSurfacePainted: false,
      child: Container(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.mutedText.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      transferTitle,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _WalletAssetIcon(symbol: _displayAssetSymbol, size: 25),
                    const SizedBox(width: 7),
                    Text(
                      '至 $destination',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _showKeypad = true),
                        child: Text(
                          _amount.isEmpty ? '0' : _amount,
                          key: const Key('contract-transfer-amount'),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: TextStyle(
                            color: _amount.isEmpty
                                ? palette.mutedText.withValues(alpha: .68)
                                : palette.primaryText,
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    if (!AppConfig.hyperliquidTestnet && !_cashToContract)
                      Container(
                        padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
                        decoration: BoxDecoration(
                          color: controlColor,
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WalletAssetIcon(symbol: 'USDC', size: 21),
                            const SizedBox(width: 5),
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
                      )
                    else
                      CupertinoButton(
                        key: const Key('contract-transfer-asset-picker'),
                        padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
                        minimumSize: Size.zero,
                        color: controlColor,
                        borderRadius: BorderRadius.circular(19),
                        onPressed: AppConfig.hyperliquidTestnet
                            ? () => _showNotice('测试网仅支持 Hyperliquid Spot USDC')
                            : _pickAsset,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ContractTransferAssetIcon(
                              asset: _asset,
                              tokenSize: 21,
                              chainSize: 10,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _asset.symbol,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              CupertinoIcons.chevron_down,
                              color: palette.mutedText,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '可用 ${_walletBalanceLoading ? '--' : _formatMoney(_available)} $_displayAssetSymbol',
                      style: TextStyle(color: palette.mutedText, fontSize: 15),
                    ),
                    const SizedBox(width: 9),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      onPressed: () => unawaited(_loadWalletBalance()),
                      child: Icon(
                        CupertinoIcons.refresh,
                        size: 15,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final option in const [
                      ('10%', .1),
                      ('20%', .2),
                      ('50%', .5),
                      ('80%', .8),
                      ('100%', 1.0),
                    ])
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: option.$2 == 1 ? 0 : 8,
                          ),
                          child: CupertinoButton(
                            key: Key('contract-transfer-${option.$1}'),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size.fromHeight(38),
                            color: controlColor,
                            disabledColor: controlColor,
                            borderRadius: BorderRadius.circular(20),
                            onPressed: _available <= 0
                                ? null
                                : () => _setFraction(option.$2),
                            child: Text(
                              option.$1,
                              style: TextStyle(
                                color: _available <= 0
                                    ? palette.mutedText.withValues(alpha: .62)
                                    : palette.primaryText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_progressLabel case final progress?)
                  SizedBox(
                    height: 220,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(radius: 13),
                          const SizedBox(height: 12),
                          Text(
                            progress,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.mutedText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_showKeypad)
                  SizedBox(
                    height: 220,
                    child: _TransferNumberPad(
                      palette: palette,
                      canConfirm: _canConfirm,
                      onDigit: _append,
                      onDelete: _delete,
                      onClear: () => setState(() => _amount = ''),
                      onHide: () => setState(() => _showKeypad = false),
                      accentColor: palette.accent,
                      onConfirm: _submitDeposit,
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      color: controlColor,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => setState(() => _showKeypad = true),
                      child: Center(
                        child: Text(
                          amountPlaceholder,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 16,
                            height: 1.2,
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
    );
  }
}

class _ContractTransferAsset {
  const _ContractTransferAsset({required this.chain, required this.symbol});

  final String chain;
  final String symbol;

  bool isSameAs(_ContractTransferAsset other) =>
      chain == other.chain && symbol == other.symbol;

  String get chainIconAsset => switch (chain) {
    'BNB Chain' => 'assets/icons/crypto/domi/chains/network-bsc.png',
    'BSC' => 'assets/icons/crypto/domi/chains/network-bsc.png',
    'Arbitrum' => 'assets/icons/crypto/domi/chains/network-arbitrum.png',
    'Ethereum' => 'assets/icons/crypto/domi/chains/network-ethereum.png',
    'Base' => 'assets/icons/crypto/domi/chains/network-base.png',
    'Polygon' => 'assets/icons/crypto/domi/chains/network-polygon.png',
    'Optimism' => 'assets/icons/crypto/domi/chains/network-optimism.png',
    'Solana' => 'assets/icons/crypto/domi/chains/network-solana.png',
    _ => 'assets/icons/crypto/domi/chains/network-ethereum.png',
  };

  WalletNetwork get mayanNetwork => switch (chain) {
    'BNB Chain' => WalletNetwork.bsc,
    'Arbitrum' => WalletNetwork.arbitrum,
    'Ethereum' => WalletNetwork.ethereum,
    'Base' => WalletNetwork.base,
    'BSC' => WalletNetwork.bsc,
    'Polygon' => WalletNetwork.polygon,
    'Optimism' => WalletNetwork.optimism,
    'Solana' => WalletNetwork.solana,
    _ => WalletNetwork.arbitrum,
  };

  String get mayanChain => switch (chain) {
    'BNB Chain' => 'bsc',
    'BSC' => 'bsc',
    'Solana' => 'solana',
    _ => chain.toLowerCase(),
  };

  String? get lifiTokenAddress {
    if (symbol == 'SOL') {
      return LifiApiClient.tokenAddress(WalletNetwork.solana, 'SOL');
    }
    return mayanTokenAddress;
  }

  int get decimals {
    if (symbol == 'SOL') return 9;
    if (symbol == 'BNB' || symbol == 'ETH') return 18;
    if (mayanNetwork == WalletNetwork.solana) {
      return symbol == 'USDC'
          ? WalletChainRegistry.solanaUsdc.decimals
          : WalletChainRegistry.solanaUsdt.decimals;
    }
    final definition = WalletChainRegistry.chains[mayanNetwork];
    return switch (symbol) {
      'USDC' => definition?.usdc?.decimals ?? 6,
      'USDT' => definition?.usdt?.decimals ?? 6,
      _ => 18,
    };
  }

  String? get mayanTokenAddress {
    if (symbol == 'BNB' || symbol == 'ETH') {
      return '0x0000000000000000000000000000000000000000';
    }
    if (symbol == 'SOL') {
      return 'So11111111111111111111111111111111111111112';
    }
    if (mayanNetwork == WalletNetwork.solana) {
      return switch (symbol) {
        'USDC' => WalletChainRegistry.solanaUsdc.address,
        'USDT' => WalletChainRegistry.solanaUsdt.address,
        _ => null,
      };
    }
    final definition = WalletChainRegistry.chains[mayanNetwork];
    return switch (symbol) {
      'USDC' => definition?.usdc?.address,
      'USDT' => definition?.usdt?.address,
      _ => null,
    };
  }
}

class _ContractTransferAssetIcon extends StatelessWidget {
  const _ContractTransferAssetIcon({
    required this.asset,
    required this.tokenSize,
    required this.chainSize,
  });

  final _ContractTransferAsset asset;
  final double tokenSize;
  final double chainSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: tokenSize + 2,
    height: tokenSize + 2,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        _WalletAssetIcon(symbol: asset.symbol, size: tokenSize),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: chainSize + 3,
            height: chainSize + 3,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1B1B1B)),
            ),
            child: Image.asset(asset.chainIconAsset),
          ),
        ),
      ],
    ),
  );
}

class _ContractTransferAssetPicker extends StatelessWidget {
  const _ContractTransferAssetPicker({
    required this.palette,
    required this.assets,
    required this.selected,
  });

  final AcoPalette palette;
  final List<_ContractTransferAsset> assets;
  final _ContractTransferAsset selected;

  Widget _buildChainSection(BuildContext context, String chain) {
    final chainAssets = assets.where((asset) => asset.chain == chain).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 7),
          child: Row(
            children: [
              Image.asset(
                chainAssets.first.chainIconAsset,
                width: 17,
                height: 17,
              ),
              const SizedBox(width: 7),
              Text(
                chain,
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.inputSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var index = 0; index < chainAssets.length; index++)
                _ContractTransferAssetRow(
                  palette: palette,
                  asset: chainAssets[index],
                  selected: selected.isSameAs(chainAssets[index]),
                  showDivider: index < chainAssets.length - 1,
                  onPressed: () => Navigator.pop(context, chainAssets[index]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chains = assets.map((asset) => asset.chain).toSet();
    return CupertinoPopupSurface(
      isSurfacePainted: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .68,
        ),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.mutedText.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 8, 8),
                child: Row(
                  children: [
                    Text(
                      '选择划转币种',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 40),
                      onPressed: () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: palette.mutedText,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  children: [
                    for (final chain in chains)
                      _buildChainSection(context, chain),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContractTransferAssetRow extends StatelessWidget {
  const _ContractTransferAssetRow({
    required this.palette,
    required this.asset,
    required this.selected,
    required this.showDivider,
    required this.onPressed,
  });

  final AcoPalette palette;
  final _ContractTransferAsset asset;
  final bool selected;
  final bool showDivider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    key: Key('contract-transfer-asset-${asset.chain}-${asset.symbol}'),
    padding: EdgeInsets.zero,
    minimumSize: const Size.fromHeight(54),
    onPressed: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.border))
            : null,
      ),
      child: Row(
        children: [
          _ContractTransferAssetIcon(
            asset: asset,
            tokenSize: 28,
            chainSize: 12,
          ),
          const SizedBox(width: 11),
          Text(
            asset.symbol,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(
              CupertinoIcons.check_mark_circled_solid,
              color: palette.accent,
              size: 21,
            ),
        ],
      ),
    ),
  );
}

class _TransferNumberPad extends StatelessWidget {
  const _TransferNumberPad({
    required this.palette,
    required this.canConfirm,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.onHide,
    required this.accentColor,
    required this.onConfirm,
  });

  final AcoPalette palette;
  final bool canConfirm;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback onHide;
  final Color accentColor;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 3,
        child: Column(
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['hide', '0', '.'],
            ])
              Expanded(
                child: Row(
                  children: [
                    for (final value in row)
                      Expanded(
                        child: CupertinoButton(
                          key: Key('contract-transfer-key-$value'),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: value == 'hide'
                              ? onHide
                              : () => onDigit(value),
                          child: value == 'hide'
                              ? Icon(
                                  Icons.arrow_downward,
                                  color: palette.primaryText,
                                  size: 25,
                                )
                              : Text(
                                  value,
                                  style: TextStyle(
                                    color: palette.primaryText,
                                    fontSize: 28,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: Column(
          children: [
            Expanded(
              child: CupertinoButton(
                key: const Key('contract-transfer-delete'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onDelete,
                child: Icon(
                  CupertinoIcons.delete_left,
                  color: palette.primaryText,
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: CupertinoButton(
                key: const Key('contract-transfer-clear'),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onClear,
                child: Text(
                  '清除',
                  style: TextStyle(color: palette.primaryText, fontSize: 17),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 0, 4),
                child: SizedBox.expand(
                  child: CupertinoButton(
                    key: const Key('contract-transfer-confirm'),
                    padding: EdgeInsets.zero,
                    color: canConfirm ? accentColor : const Color(0xFF999999),
                    disabledColor: palette.dark
                        ? const Color(0xFF3B3B3B)
                        : const Color(0xFF999999),
                    borderRadius: BorderRadius.circular(14),
                    onPressed: canConfirm ? onConfirm : null,
                    child: const Text(
                      '确认',
                      style: TextStyle(
                        color: Color(0xFF000000),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _AccountBalanceCard extends StatelessWidget {
  const _AccountBalanceCard({
    required this.palette,
    required this.account,
    required this.available,
    required this.loading,
    required this.onDeposit,
    required this.onWithdraw,
  });

  final AcoPalette palette;
  final HyperliquidAccountState? account;
  final double available;
  final bool loading;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

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
            const Spacer(),
            CupertinoButton(
              key: const Key('hyperliquid-balance-deposit'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              color: palette.accent,
              onPressed: onDeposit,
              child: Text(
                '充值',
                style: TextStyle(
                  color: palette.dark ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              key: const Key('hyperliquid-balance-withdraw'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              color: palette.surfaceRaised,
              onPressed: onWithdraw,
              child: Text(
                '提现',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _metric(
                '总余额',
                math.max(account?.accountValue ?? 0, available),
              ),
            ),
            Expanded(child: _metric('可用余额', available)),
          ],
        ),
        const SizedBox(height: 16),
        _metric('盈亏', account?.totalUnrealizedPnl ?? 0),
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
  const _PositionRow({
    required this.palette,
    required this.position,
    required this.markPrice,
    required this.onClose,
  });

  final AcoPalette palette;
  final HyperliquidPosition position;
  final double markPrice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isLong = (position.size ?? 0) >= 0;
    final pnl = position.unrealizedPnl ?? 0;
    final sideColor = isLong
        ? const Color(0xFF25C26E)
        : const Color(0xFFF14D51);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 13),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: .55),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLong ? '多' : '空',
                  style: TextStyle(
                    color: sideColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                position.coin,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (position.leverage != null) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: palette.mutedText.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_formatQuantity(position.leverage)}x',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '盈亏',
                    style: TextStyle(color: palette.mutedText, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${pnl >= 0 ? '+' : ''}\$${_formatMoney(pnl)}',
                        style: TextStyle(
                          color: pnl >= 0 ? sideColor : const Color(0xFFF14D51),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (position.returnOnEquity != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${_formatPercent(position.returnOnEquity!)})',
                          style: TextStyle(
                            color: pnl >= 0
                                ? sideColor
                                : const Color(0xFFF14D51),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(72, 40),
                onPressed: onClose,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: .14),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: .82),
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '平仓',
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _valueColumn(
                  '持仓数量',
                  _formatQuantity(position.size?.abs()),
                ),
              ),
              Expanded(
                child: _valueColumn(
                  '开仓均价',
                  _formatPlainPrice(position.entryPrice),
                ),
              ),
              Expanded(
                child: _valueColumn(
                  '标记价格',
                  _formatPlainPrice(markPrice > 0 ? markPrice : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _valueColumn(
                  '持仓价值',
                  position.positionValue == null
                      ? '--'
                      : '\$${_formatMoney(position.positionValue!)}',
                ),
              ),
              Expanded(
                child: _valueColumn(
                  '保证金',
                  position.marginUsed == null
                      ? '--'
                      : '\$${_formatMoney(position.marginUsed!)}',
                ),
              ),
              Expanded(
                child: _valueColumn(
                  '资金费',
                  position.fundingSinceOpen == null
                      ? '--'
                      : '\$${_formatMoney(position.fundingSinceOpen!)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _valueColumn(
                  '强平价格',
                  _formatPlainPrice(position.liquidationPrice),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueColumn(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _OpenOrderRow extends StatelessWidget {
  const _OpenOrderRow({
    required this.palette,
    required this.order,
    required this.onCancel,
  });

  final AcoPalette palette;
  final HyperliquidOpenOrder order;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final sideColor = order.isBuy
        ? const Color(0xFF25C26E)
        : const Color(0xFFF14D51);
    final notional = order.price != null && order.size != null
        ? order.price! * order.size!.abs()
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 13),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: .55),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.isBuy ? '买入' : '卖出',
                  style: TextStyle(
                    color: sideColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                order.coin,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '限价单',
                style: TextStyle(color: palette.mutedText, fontSize: 11),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(64, 36),
                onPressed: onCancel,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: .14),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: .82),
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '撤单',
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _valueColumn('委托数量', _formatQuantity(order.size?.abs())),
              ),
              Expanded(
                child: _valueColumn('委托价格', _formatPlainPrice(order.price)),
              ),
              Expanded(
                child: _valueColumn(
                  '名义价值',
                  notional == null ? '--' : '\$${_formatMoney(notional)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '订单号 ${order.orderId} · ${_formatOrderTime(order.timestamp)}',
            style: TextStyle(color: palette.mutedText, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _valueColumn(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _UserFillRow extends StatelessWidget {
  const _UserFillRow({required this.palette, required this.fill});

  final AcoPalette palette;
  final HyperliquidUserFill fill;

  @override
  Widget build(BuildContext context) {
    final sideColor = fill.isBuy
        ? const Color(0xFF25C26E)
        : const Color(0xFFF14D51);
    final notional = fill.price != null && fill.size != null
        ? fill.price! * fill.size!.abs()
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: .55),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fill.isBuy ? '买入' : '卖出',
                  style: TextStyle(
                    color: sideColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fill.coin,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fill.direction.isEmpty ? '成交' : fill.direction,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.mutedText, fontSize: 11),
                ),
              ),
              Text(
                _formatOrderTime(fill.timestamp),
                style: TextStyle(color: palette.mutedText, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _valueColumn('成交数量', _formatQuantity(fill.size?.abs())),
              ),
              Expanded(
                child: _valueColumn('成交价格', _formatPlainPrice(fill.price)),
              ),
              Expanded(
                child: _valueColumn(
                  '成交额',
                  notional == null ? '--' : '\$${_formatMoney(notional)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _valueColumn(
                  '手续费',
                  fill.fee == null ? '--' : '\$${_formatMoney(fill.fee!)}',
                ),
              ),
              Expanded(
                child: _valueColumn(
                  '已实现盈亏',
                  fill.closedPnl == null
                      ? '--'
                      : '\$${_formatMoney(fill.closedPnl!)}',
                ),
              ),
              Expanded(
                child: _valueColumn(
                  '成交编号',
                  fill.tradeId == 0 ? '--' : '${fill.tradeId}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueColumn(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: palette.mutedText, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
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

String _formatOrderTime(int timestamp) {
  if (timestamp <= 0) return '--';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.month}/${date.day} $hour:$minute';
}

String _formatPercent(double value) {
  final percent = value * 100;
  return '${percent >= 0 ? '+' : ''}${_trimTrailingZeros(percent.toStringAsFixed(2))}%';
}
