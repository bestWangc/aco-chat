part of 'aco_design_shell.dart';

class _DexTokenPage extends StatefulWidget {
  const _DexTokenPage({
    required this.palette,
    required this.selectedChain,
    required this.onOpen,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final ValueChanged<AcoScreen> onOpen;
  @override
  State<_DexTokenPage> createState() => _DexTokenPageState();
}

class _DexTokenPageState extends State<_DexTokenPage> {
  bool showSwap = false;
  bool ethFirst = true;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        showSwap ? 10 : 51,
        20,
        showSwap ? 10 : 51,
        24,
      ),
      children: [
        Transform.translate(
          offset: Offset(showSwap ? 16 : -35, 0),
          child: _SectionTabs(
            palette: palette,
            labels: const ['闪兑', '代币', '合约'],
            selected: showSwap ? 0 : 1,
            itemSpacing: 12,
            fontSize: 18,
            horizontalPadding: 8,
            showSelectedIndicator: true,
            onChanged: (index) => setState(() => showSwap = index == 0),
          ),
        ),
        if (!showSwap) ...[
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
                          '--',
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
            onPressed: () => setState(() => showSwap = true),
          ),
        ] else ...[
          const SizedBox(height: 24),
          _DexSwapContent(
            palette: palette,
            selectedChain: widget.selectedChain,
            onOpen: widget.onOpen,
            ethFirst: ethFirst,
            onEthFirstChanged: (value) => setState(() => ethFirst = value),
            recentRecord: null,
          ),
        ],
      ],
    );
  }
}

class _DexSwapPage extends StatefulWidget {
  const _DexSwapPage({
    required this.palette,
    required this.selectedChain,
    required this.onOpen,
    this.walletIdentity,
    this.secretStore,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final ValueChanged<AcoScreen> onOpen;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore? secretStore;
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
        Transform.translate(
          offset: const Offset(-27, 0),
          child: _SectionTabs(
            palette: palette,
            labels: const ['闪兑', '代币', '合约'],
            selected: 0,
            itemSpacing: 12,
            fontSize: 18,
            horizontalPadding: 8,
            showSelectedIndicator: true,
          ),
        ),
        const SizedBox(height: 24),
        _DexSwapContent(
          palette: palette,
          selectedChain: widget.selectedChain,
          onOpen: widget.onOpen,
          walletIdentity: widget.walletIdentity,
          secretStore: widget.secretStore,
          ethFirst: ethFirst,
          onEthFirstChanged: (value) => setState(() => ethFirst = value),
          recentRecord: null,
        ),
      ],
    );
  }
}

class _DexSwapContent extends StatefulWidget {
  const _DexSwapContent({
    required this.palette,
    required this.selectedChain,
    required this.onOpen,
    this.walletIdentity,
    this.secretStore,
    required this.ethFirst,
    required this.onEthFirstChanged,
    this.recentRecord,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final ValueChanged<AcoScreen> onOpen;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore? secretStore;
  final bool ethFirst;
  final ValueChanged<bool> onEthFirstChanged;
  final Future<DexSwapRecord?>? recentRecord;

  @override
  State<_DexSwapContent> createState() => _DexSwapContentState();
}

class _DexSwapContentState extends State<_DexSwapContent> {
  _WalletChain _fromChain = _supportedWalletChains.first;
  _WalletChain _toChain = _supportedWalletChains.first;
  late String _fromSymbol;
  late String _toSymbol;
  String _fromAmount = '0';
  LifiQuote? _quote;
  bool _loading = false;
  Timer? _quoteDebounce;
  WalletIdentity? _resolvedIdentity;

  AcoPalette get palette => widget.palette;
  _WalletChain get fromChain => _fromChain;
  _WalletChain get toChain => _toChain;
  WalletIdentity? get walletIdentity =>
      widget.walletIdentity ?? _resolvedIdentity;
  WalletSecretStore? get secretStore => widget.secretStore;
  bool get ethFirst => widget.ethFirst;

  @override
  void initState() {
    super.initState();
    _fromChain = widget.selectedChain;
    _toChain = widget.selectedChain;
    _fromSymbol = _nativeSymbol;
    _toSymbol = 'USDC';
    if (widget.walletIdentity == null) unawaited(_loadWalletIdentity());
  }

  String get _nativeSymbol => fromChain.nativeToken.symbol;

  int _decimalsFor(_WalletChain chain, String symbol) {
    if (symbol == chain.nativeToken.symbol) {
      return chain.network == WalletNetwork.solana ? 9 : 18;
    }
    return WalletChainRegistry.chains[chain.network]?.usdc?.decimals ?? 6;
  }

  String get _normalizedFromAmount => _fromAmount.replaceAll(',', '').trim();

  Future<void> _loadWalletIdentity() async {
    final identity = await WalletPreferences.walletIdentity();
    if (!mounted || widget.walletIdentity != null || identity == null) return;
    setState(() => _resolvedIdentity = identity);
    _scheduleQuote();
  }

  void _scheduleQuote() {
    _quoteDebounce?.cancel();
    final parsedAmount = double.tryParse(_normalizedFromAmount);
    if (parsedAmount == null || parsedAmount <= 0 || walletIdentity == null) {
      return;
    }
    _quoteDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _requestQuote(context, showNotice: false, execute: false);
      }
    });
  }

  void _setSwap(
    _WalletChain nextFromChain,
    String from,
    _WalletChain nextToChain,
    String to,
    String amount,
  ) {
    setState(() {
      _fromChain = nextFromChain;
      _toChain = nextToChain;
      _fromSymbol = from;
      _toSymbol = to;
      _fromAmount = amount;
      _quote = null;
    });
    _scheduleQuote();
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    super.dispose();
  }

  Future<void> _requestQuote(
    BuildContext context, {
    bool showNotice = true,
    bool execute = true,
  }) async {
    if (_loading) return;
    final identity = walletIdentity;
    if (identity == null) {
      if (showNotice) _showNotice(context, '兑换', '请先连接钱包继续兑换。');
      return;
    }
    final fromAddress = await _addressForChain(identity, fromChain);
    final toAddress = await _addressForChain(identity, toChain);
    if (!context.mounted) return;
    if (fromAddress == null || fromAddress.isEmpty) {
      if (showNotice) {
        await _showMissingChainWallet(context, fromChain);
      }
      return;
    }
    if (toAddress == null || toAddress.isEmpty) {
      if (showNotice) await _showMissingChainWallet(context, toChain);
      return;
    }
    final amount = _normalizedFromAmount;
    final parsedAmount = double.tryParse(amount);
    if (parsedAmount == null || parsedAmount <= 0) {
      if (showNotice) _showNotice(context, '兑换', '请输入有效的兑换金额。');
      return;
    }
    if (execute &&
        !await _hasSufficientBalance(context, identity, amount, fromChain)) {
      return;
    }
    setState(() => _loading = true);
    final client = LifiApiClient();
    try {
      final nativeSymbol = switch (fromChain.network) {
        WalletNetwork.ethereum ||
        WalletNetwork.base ||
        WalletNetwork.arbitrum ||
        WalletNetwork.optimism => 'ETH',
        WalletNetwork.bsc => 'BNB',
        WalletNetwork.polygon => 'POL',
        WalletNetwork.tron => 'TRX',
        WalletNetwork.solana => 'SOL',
      };
      final sourceSymbol = _fromSymbol;
      final targetSymbol = _toSymbol;
      final sourceDecimals = _decimalsFor(fromChain, sourceSymbol);
      List<LifiToken> sourceTokens = const [];
      List<LifiToken> targetTokens = const [];
      try {
        sourceTokens = await client.tokens(fromChain.network);
        targetTokens = fromChain.network == toChain.network
            ? sourceTokens
            : await client.tokens(toChain.network);
      } catch (_) {
        // The local registry remains a valid offline fallback.
      }
      final sourceToken = sourceTokens.cast<LifiToken?>().firstWhere(
        (token) => token?.symbol.toUpperCase() == sourceSymbol.toUpperCase(),
        orElse: () => null,
      );
      final targetToken = targetTokens.cast<LifiToken?>().firstWhere(
        (token) => token?.symbol.toUpperCase() == targetSymbol.toUpperCase(),
        orElse: () => null,
      );
      final sourceTokenAddress = sourceToken?.address;
      final resolvedSourceDecimals = sourceToken?.decimals ?? sourceDecimals;
      final quote = await client.quote(
        fromNetwork: fromChain.network,
        fromToken: sourceSymbol,
        toNetwork: toChain.network,
        toToken: targetSymbol,
        fromAmount: amount,
        fromDecimals: resolvedSourceDecimals,
        fromAddress: fromAddress,
        toAddress: toAddress,
        fromTokenAddress: sourceToken?.address,
        toTokenAddress: targetToken?.address,
      );
      client.close();
      if (!context.mounted) return;
      setState(() => _quote = quote);
      if (!execute) return;
      final request = quote.transactionRequest;
      if (request == null) {
        if (showNotice) {
          _showNotice(context, 'LI.FI 报价', '已获取报价，但当前路由没有可执行交易。');
        }
        return;
      }
      if (fromChain.network == WalletNetwork.solana) {
        await _executeSolanaQuote(
          context,
          identity: identity,
          address: fromAddress,
          request: request,
        );
        return;
      }
      if (fromChain.network == WalletNetwork.tron) {
        await _executeTronQuote(context, identity: identity, request: request);
        return;
      }
      if (!context.mounted || !await _confirmSwap(context)) return;
      final mnemonic = await _unlockMnemonic(identity);
      if (!context.mounted) return;
      if (mnemonic == null) return;
      final tokens = await SecureAccountTokenStore().read();
      if (!context.mounted) return;
      if (tokens == null) {
        _showNotice(context, '兑换失败', '钱包服务尚未连接，请稍后重试。');
        return;
      }
      final rpc = WalletRpcClient(
        client: http.Client(),
        directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
        ownsClient: true,
      );
      try {
        if (sourceSymbol != nativeSymbol) {
          final tokenAddress =
              sourceTokenAddress ??
              LifiApiClient.tokenAddress(fromChain.network, sourceSymbol);
          final spender = request['to'] as String?;
          if (spender == null || !spender.startsWith('0x')) {
            _showNotice(context, '兑换失败', 'LI.FI 返回的授权地址无效。');
            return;
          }
          final requiredAmount = LifiApiClient.toBaseUnits(
            amount,
            resolvedSourceDecimals,
          );
          if (!context.mounted ||
              !await _confirmApproval(context, sourceSymbol)) {
            return;
          }
          final approval = await const WalletTransferService()
              .ensureErc20AllowanceWithRpc(
                mnemonic: mnemonic,
                from: fromAddress,
                network: fromChain.network,
                accessToken: tokens.accessToken,
                rpc: rpc,
                tokenAddress: tokenAddress,
                spender: spender,
                requiredAmount: requiredAmount,
              );
          if (approval != null && context.mounted) {
            _showNotice(context, '授权已提交', '正在等待授权交易进入节点…');
          }
        }
        final result = await const WalletTransferService()
            .executeTransactionRequestWithRpc(
              mnemonic: mnemonic,
              from: fromAddress,
              network: fromChain.network,
              accessToken: tokens.accessToken,
              rpc: rpc,
              transactionRequest: request,
            );
        if (!context.mounted) return;
        _showNotice(context, '兑换已提交', '交易哈希：${result.hash}');
        await _trackLifiStatus(result.hash);
      } finally {
        rpc.close();
      }
    } on LifiException catch (error, stackTrace) {
      client.close();
      debugPrint('[LI.FI] quote failed: ${error.message}');
      debugPrintStack(stackTrace: stackTrace, label: 'LI.FI quote');
      if (!context.mounted) return;
      if (showNotice) _showNotice(context, 'LI.FI 报价失败', error.message);
    } catch (error, stackTrace) {
      client.close();
      debugPrint('[LI.FI] quote request failed: $error');
      debugPrintStack(stackTrace: stackTrace, label: 'LI.FI quote');
      if (!context.mounted) return;
      if (showNotice) {
        _showNotice(context, 'LI.FI 报价失败', _lifiFailureMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _hasSufficientBalance(
    BuildContext context,
    WalletIdentity identity,
    String amount,
    _WalletChain chain,
  ) async {
    final tokenStore = await SecureAccountTokenStore().read();
    if (!context.mounted) return false;
    if (tokenStore == null) {
      _showNotice(context, '兑换', '钱包服务尚未连接，请稍后重试。');
      return false;
    }
    final portfolio = WalletPortfolioService();
    try {
      final derivedAddresses = await WalletPreferences.derivedAddresses(
        identity,
      );
      if (!context.mounted) return false;
      final balances = await portfolio.loadBalances(
        network: chain.network,
        identity: identity,
        derivedAddresses: derivedAddresses,
        accessToken: tokenStore.accessToken,
      );
      if (!context.mounted) return false;
      WalletBalance? balance;
      for (final item in balances) {
        if (item.symbol.toUpperCase() == _fromSymbol.toUpperCase()) {
          balance = item;
          break;
        }
      }
      if (balance == null || balance.balance == null) return true;
      final required = LifiApiClient.toBaseUnits(
        amount,
        _decimalsFor(chain, _fromSymbol),
      );
      if (balance.balance! < BigInt.parse(required)) {
        _showNotice(context, '余额不足', '当前 $_fromSymbol 余额不足，无法提交本次兑换。');
        return false;
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        _showNotice(context, '余额查询失败', '暂时无法获取余额，请稍后重试。');
      }
      return false;
    } finally {
      portfolio.close();
    }
  }

  Future<void> _showMissingChainWallet(
    BuildContext context,
    _WalletChain chain,
  ) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('${chain.label}钱包未准备好'),
        content: Text('当前钱包还没有${chain.label}地址，请先导入或创建该公链钱包后再进行跨链兑换。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onOpen(AcoScreen.walletSetupImport);
            },
            child: const Text('去导入钱包'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onOpen(AcoScreen.walletSetupCreate);
            },
            child: const Text('去创建钱包'),
          ),
        ],
      ),
    );
  }

  String _lifiFailureMessage(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty || message == 'null') return '网络请求失败，请稍后重试。';
    return message.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _trackLifiStatus(String txHash) async {
    final client = LifiApiClient();
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final status = await client.status(
          txHash: txHash,
          fromNetwork: fromChain.network,
          toNetwork: toChain.network,
        );
        if (status.status.toUpperCase() == 'DONE' ||
            status.status.toUpperCase() == 'FAILED') {
          if (mounted) {
            _showNotice(
              context,
              status.status.toUpperCase() == 'DONE' ? '兑换完成' : '兑换失败',
              status.receivingTxHash == null
                  ? status.status
                  : '目标交易：${status.receivingTxHash}',
            );
          }
          return;
        }
      }
    } catch (_) {
      // The transaction is already broadcast; status polling is best effort.
    } finally {
      client.close();
    }
  }

  Future<void> _executeSolanaQuote(
    BuildContext context, {
    required WalletIdentity identity,
    required String address,
    required Map<String, dynamic> request,
  }) async {
    final encoded =
        request['serializedTransaction'] ??
        request['transaction'] ??
        request['data'];
    if (encoded is! String || encoded.isEmpty) {
      _showNotice(context, '兑换失败', 'LI.FI 未返回可签名的 Solana 交易。');
      return;
    }
    if (!await _confirmSwap(context)) return;
    final mnemonic = await _unlockMnemonic(identity);
    if (mnemonic == null || !context.mounted) return;
    try {
      final signed = const SolanaSigningService().signSerializedTransaction(
        mnemonic: mnemonic,
        serializedTransaction: encoded,
      );
      final tokens = await SecureAccountTokenStore().read();
      if (tokens == null || !context.mounted) return;
      final rpc = WalletRpcClient(
        client: http.Client(),
        directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
        ownsClient: true,
      );
      try {
        final endpoints = await rpc.loadEndpoints(
          network: WalletNetwork.solana.name,
          accessToken: tokens.accessToken,
        );
        final response = await rpc.postJson(endpoints, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'sendTransaction',
          'params': [
            signed,
            {'encoding': 'base64'},
          ],
        });
        if (context.mounted) {
          _showNotice(context, '兑换已提交', '交易哈希：${response['result'] ?? '-'}');
        }
      } finally {
        rpc.close();
      }
    } on FormatException catch (error) {
      if (context.mounted) _showNotice(context, '兑换失败', error.message);
    } catch (_) {
      if (context.mounted) _showNotice(context, '兑换失败', 'Solana 交易签名或广播失败。');
    }
  }

  Future<void> _executeTronQuote(
    BuildContext context, {
    required WalletIdentity identity,
    required Map<String, dynamic> request,
  }) async {
    final raw =
        request['transaction'] ??
        request['serializedTransaction'] ??
        request['data'];
    final transaction = raw is Map<String, dynamic>
        ? jsonEncode(raw)
        : raw is String
        ? raw
        : null;
    if (transaction == null) {
      _showNotice(context, '兑换失败', 'LI.FI 未返回可签名的 TRON 交易。');
      return;
    }
    if (!await _confirmSwap(context)) return;
    final mnemonic = await _unlockMnemonic(identity);
    if (mnemonic == null || !context.mounted) return;
    try {
      final signed = const TronSigningService().signSerializedTransaction(
        mnemonic: mnemonic,
        serializedTransaction: transaction,
      );
      final tokens = await SecureAccountTokenStore().read();
      if (tokens == null || !context.mounted) return;
      final rpc = WalletRpcClient(
        client: http.Client(),
        directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
        ownsClient: true,
      );
      try {
        final endpoints = await rpc.loadEndpoints(
          network: WalletNetwork.tron.name,
          accessToken: tokens.accessToken,
        );
        Map<String, dynamic>? response;
        for (final endpoint in endpoints) {
          final broadcastUri = endpoint.replace(
            path:
                '${endpoint.path.replaceFirst(RegExp(r'/$'), '')}/wallet/broadcasttransaction',
          );
          try {
            response = await rpc.postJsonTo(broadcastUri, jsonDecode(signed));
            break;
          } catch (_) {}
        }
        if (response == null) throw const FormatException('TRON 广播失败');
        if (context.mounted) {
          _showNotice(context, '兑换已提交', '交易 ID：${response['txid'] ?? '-'}');
        }
      } finally {
        rpc.close();
      }
    } on FormatException catch (error) {
      if (context.mounted) _showNotice(context, '兑换失败', error.message);
    } catch (_) {
      if (context.mounted) _showNotice(context, '兑换失败', 'TRON 交易签名或广播失败。');
    }
  }

  Future<String?> _unlockMnemonic(WalletIdentity identity) async {
    final store = secretStore ?? SecureWalletSecretStore();
    try {
      return await WalletSecurity().unlockMnemonicWithDeviceProtection(
        store: store,
        walletAddress: identity.address,
      );
    } on WalletSecurityException {
      return null;
    }
  }

  Future<bool> _confirmSwap(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认兑换'),
        content: const Text('确认提交本次兑换？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _confirmApproval(BuildContext context, String symbol) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('需要代币授权'),
        content: Text('首次使用 $symbol 兑换需要授权 LI.FI 使用代币，是否继续？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('授权并继续'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _DexSwapPanel(
        palette: palette,
        ethFirst: ethFirst,
        fromChain: fromChain,
        toChain: toChain,
        onEthFirstChanged: widget.onEthFirstChanged,
        onSwapChanged: _setSwap,
        outputAmount: _quote == null
            ? '-'
            : _formatTokenUnits(
                _quote!.toAmount,
                _decimalsFor(toChain, _toSymbol),
              ),
      ),
      const SizedBox(height: 28),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(34),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: AcoLimeButton(
            label: _loading ? '获取报价中…' : '兑换',
            onPressed: () {
              if (!_loading) _requestQuote(context);
            },
            height: 42,
            fontSize: 16,
            backgroundColor: palette.accent,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _DexSwapQuoteCard(
        palette: palette,
        quote: _quote,
        fromSymbol: _fromSymbol,
        toSymbol: _toSymbol,
        fromChain: fromChain.displayLabel,
        toChain: toChain.displayLabel,
        fromDecimals: _decimalsFor(fromChain, _fromSymbol),
        toDecimals: _decimalsFor(toChain, _toSymbol),
      ),
      const SizedBox(height: 28),
      _DexRecentSwapRecord(palette: palette, future: widget.recentRecord),
    ],
  );
}

class _DexSwapQuoteCard extends StatelessWidget {
  const _DexSwapQuoteCard({
    required this.palette,
    required this.fromSymbol,
    required this.toSymbol,
    required this.fromChain,
    required this.toChain,
    required this.fromDecimals,
    required this.toDecimals,
    this.quote,
  });
  final AcoPalette palette;
  final LifiQuote? quote;
  final String fromSymbol;
  final String toSymbol;
  final String fromChain;
  final String toChain;
  final int fromDecimals;
  final int toDecimals;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: palette.inputSurface,
      border: Border.all(color: palette.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        _row(
          '兑换价格',
          quote == null
              ? '-'
              : '${_formatTokenUnits(quote!.fromAmount, fromDecimals)} $fromSymbol → '
                    '${_formatTokenUnits(quote!.toAmount, toDecimals)} $toSymbol',
        ),
        _row('滑点', '2%'),
        if (fromChain != toChain) _row('网络', '$fromChain → $toChain'),
        _row(
          '最少接收数量',
          quote == null
              ? '-'
              : '${_formatTokenUnits(quote!.toAmountMin, toDecimals)} $toSymbol',
        ),
        _row('兑换路径', quote?.tool ?? 'LI.FI'),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
          ),
        ),
      ],
    ),
  );
}

String _formatTokenUnits(String raw, int decimals) {
  if (raw.isEmpty) return '-';
  try {
    final value = BigInt.parse(raw);
    if (decimals == 0) return value.toString();
    final negative = value.isNegative;
    final digits = (negative ? -value : value).toString().padLeft(
      decimals + 1,
      '0',
    );
    final split = digits.length - decimals;
    final fraction = digits.substring(split).replaceFirst(RegExp(r'0+$'), '');
    return '${negative ? '-' : ''}${digits.substring(0, split)}'
        '${fraction.isEmpty ? '' : '.$fraction'}';
  } catch (_) {
    return raw;
  }
}

class DexSwapRecord {
  const DexSwapRecord({
    required this.source,
    required this.fromAmount,
    required this.fromSymbol,
    required this.toAmount,
    required this.toSymbol,
    required this.status,
    required this.createdAt,
  });

  final String source;
  final String fromAmount;
  final String fromSymbol;
  final String toAmount;
  final String toSymbol;
  final String status;
  final DateTime createdAt;
}

class _DexRecentSwapRecord extends StatelessWidget {
  const _DexRecentSwapRecord({required this.palette, this.future});
  final AcoPalette palette;
  final Future<DexSwapRecord?>? future;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '最近10条记录',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openAllRecords(context),
            child: Text(
              '更多记录',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (future == null)
        _buildRecords(_records)
      else
        FutureBuilder<DexSwapRecord?>(
          future: future,
          builder: (context, snapshot) {
            final record = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 56);
            }
            if (record == null || record.source != 'app') return _emptyState();
            return _buildRecords(_recordsWithLatest(record));
          },
        ),
    ],
  );

  List<DexSwapRecord> get _records => const [];

  Future<void> _openAllRecords(BuildContext context) async {
    final latest = await future;
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => _DexSwapRecordListPage(
          palette: palette,
          records: latest == null || latest.source != 'app'
              ? _records
              : _recordsWithLatest(latest),
        ),
      ),
    );
  }

  List<DexSwapRecord> _recordsWithLatest(DexSwapRecord record) => [record];

  Widget _buildRecords(List<DexSwapRecord> records) {
    if (records.isEmpty) return _emptyState();
    return _recordList(records);
  }

  Widget _emptyState() => Container(
    margin: const EdgeInsets.only(top: 2),
    constraints: const BoxConstraints(minHeight: 108),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: palette.inputSurface,
      border: Border.all(color: palette.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Center(
      child: Text(
        '暂无闪兑记录',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.bodyEmphasis,
          height: 1.2,
        ),
      ),
    ),
  );

  Widget _recordCard(DexSwapRecord record) =>
      _DexSwapRecordCard(palette: palette, record: record);

  Widget _recordList(List<DexSwapRecord> records) => Column(
    children: [
      _recordCard(records.first),
      if (records.length > 1) ...[
        const SizedBox(height: 22),
        for (final record in records.skip(1)) ...[
          _recordCard(record),
          if (record != records.last) const SizedBox(height: 10),
        ],
      ],
    ],
  );
}

class _DexSwapRecordListPage extends StatelessWidget {
  const _DexSwapRecordListPage({required this.palette, required this.records});

  final AcoPalette palette;
  final List<DexSwapRecord> records;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(middle: Text('兑换记录')),
    child: SafeArea(
      child: records.isEmpty
          ? Center(
              child: Text('暂无闪兑记录', style: TextStyle(color: palette.mutedText)),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) =>
                  _DexSwapRecordCard(palette: palette, record: records[index]),
            ),
    ),
  );
}

class _DexSwapRecordCard extends StatelessWidget {
  const _DexSwapRecordCard({required this.palette, required this.record});

  final AcoPalette palette;
  final DexSwapRecord record;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: palette.inputSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: palette.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${record.fromAmount} ${record.fromSymbol}  →  '
            '${record.toAmount} ${record.toSymbol}',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          record.status,
          style: TextStyle(
            color: palette.accent,
            fontSize: AcoTypography.caption,
          ),
        ),
      ],
    ),
  );
}

class _DexSwapPanel extends StatefulWidget {
  const _DexSwapPanel({
    required this.palette,
    required this.fromChain,
    required this.toChain,
    required this.ethFirst,
    required this.onEthFirstChanged,
    required this.onSwapChanged,
    required this.outputAmount,
  });
  final AcoPalette palette;
  final _WalletChain fromChain;
  final _WalletChain toChain;
  final bool ethFirst;
  final ValueChanged<bool> onEthFirstChanged;
  final void Function(
    _WalletChain fromChain,
    String from,
    _WalletChain toChain,
    String to,
    String amount,
  )
  onSwapChanged;
  final String outputAmount;

  @override
  State<_DexSwapPanel> createState() => _DexSwapPanelState();
}

class _DexSwapPanelState extends State<_DexSwapPanel> {
  late String _fromSymbol;
  late String _toSymbol;
  _WalletChain _fromChain = _supportedWalletChains.first;
  _WalletChain _toChain = _supportedWalletChains.first;
  String _fromLogoUri = '';
  String _toLogoUri = '';
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _fromChain = widget.fromChain;
    _toChain = widget.toChain;
    _syncSymbols(widget.ethFirst);
    _amountController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _syncSymbols(bool ethFirst) {
    final native = _fromChain.nativeToken.symbol;
    _fromSymbol = ethFirst ? native : 'USDC';
    _toSymbol = ethFirst ? 'USDC' : native;
    _fromLogoUri = '';
    _toLogoUri = '';
  }

  @override
  void didUpdateWidget(covariant _DexSwapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _pickToken(BuildContext context, String current, bool source) {
    final chain = source ? _fromChain : _toChain;
    showCupertinoModalPopup<_DexTokenChoice>(
      context: context,
      builder: (context) => _DexTokenPicker(
        palette: widget.palette,
        selectedChain: chain,
        selectedSymbol: current,
        excludedSymbol: source && _fromChain.network == _toChain.network
            ? _toSymbol
            : !source && _fromChain.network == _toChain.network
            ? _fromSymbol
            : null,
      ),
    ).then((selection) {
      if (selection == null) return;
      setState(() {
        if (source) {
          _fromChain = selection.chain;
          _fromSymbol = selection.symbol;
          _fromLogoUri = selection.logoUri;
        } else {
          _toChain = selection.chain;
          _toSymbol = selection.symbol;
          _toLogoUri = selection.logoUri;
        }
      });
      widget.onSwapChanged(
        _fromChain,
        _fromSymbol,
        _toChain,
        _toSymbol,
        _amountController.text,
      );
      widget.onEthFirstChanged(_fromSymbol == 'ETH');
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(30, 28, 30, 26),
    decoration: BoxDecoration(
      border: Border.all(color: widget.palette.border, width: 1.5),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      children: [
        _DexSwapTokenRow(
          palette: widget.palette,
          label: '兑换货币 · ${_fromChain.displayLabel}',
          symbol: _fromSymbol,
          logoUri: _fromLogoUri,
          value: _amountController.text,
          showMax: true,
          editable: true,
          onValueChanged: (value) {
            _amountController.text = value;
            widget.onSwapChanged(
              _fromChain,
              _fromSymbol,
              _toChain,
              _toSymbol,
              value,
            );
          },
          onTokenTap: (symbol) => _pickToken(context, symbol, true),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Container(height: 1.5, color: widget.palette.border),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  final symbol = _fromSymbol;
                  _fromSymbol = _toSymbol;
                  _toSymbol = symbol;
                  final chain = _fromChain;
                  _fromChain = _toChain;
                  _toChain = chain;
                  final logoUri = _fromLogoUri;
                  _fromLogoUri = _toLogoUri;
                  _toLogoUri = logoUri;
                });
                widget.onSwapChanged(
                  _fromChain,
                  _fromSymbol,
                  _toChain,
                  _toSymbol,
                  _amountController.text,
                );
                widget.onEthFirstChanged(_fromSymbol == 'ETH');
              },
              child: Image.asset(
                'assets/icons/dex_swap_arrow.png',
                width: 44,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 1.5, color: widget.palette.border),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _DexSwapTokenRow(
          palette: widget.palette,
          label: '至 · ${_toChain.displayLabel}',
          symbol: _toSymbol,
          logoUri: _toLogoUri,
          value: widget.outputAmount,
          onTokenTap: (symbol) => _pickToken(context, symbol, false),
        ),
      ],
    ),
  );
}

class _DexTokenChoice {
  const _DexTokenChoice({
    required this.chain,
    required this.symbol,
    required this.logoUri,
  });

  final _WalletChain chain;
  final String symbol;
  final String logoUri;
}

class _DexTokenPicker extends StatefulWidget {
  const _DexTokenPicker({
    required this.palette,
    required this.selectedChain,
    required this.selectedSymbol,
    this.excludedSymbol,
  });

  final AcoPalette palette;
  final _WalletChain selectedChain;
  final String selectedSymbol;
  final String? excludedSymbol;

  @override
  State<_DexTokenPicker> createState() => _DexTokenPickerState();
}

class _DexTokenPickerState extends State<_DexTokenPicker> {
  late _WalletChain _activeChain;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  List<LifiToken> _remoteTokens = const [];
  bool _loadingTokens = true;
  int _displayLimit = 80;

  @override
  void initState() {
    super.initState();
    _activeChain = widget.selectedChain;
    _scrollController.addListener(_loadMoreWhenNeeded);
    _loadTokens();
  }

  void _loadMoreWhenNeeded() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240 ||
        _displayLimit >= _remoteTokens.length + 3) {
      return;
    }
    if (mounted) setState(() => _displayLimit += 80);
  }

  Future<void> _loadTokens() async {
    final client = LifiApiClient();
    try {
      final tokens = await client.tokens(_activeChain.network);
      if (mounted) setState(() => _remoteTokens = tokens);
    } catch (_) {
      // Keep the local native/USDT/USDC fallback when LI.FI is unavailable.
    } finally {
      client.close();
      if (mounted) setState(() => _loadingTokens = false);
    }
  }

  List<(String, String, String, String, String)> get _tokens {
    final values = <String, (String, String, String, String, String)>{
      _activeChain.nativeToken.symbol: (
        _activeChain.nativeToken.symbol,
        _activeChain.nativeToken.symbol,
        '',
        '0',
        '',
      ),
      'USDT': (
        'USDT',
        'USDT',
        LifiApiClient.tokenAddress(_activeChain.network, 'USDT'),
        '0',
        '',
      ),
      'USDC': (
        'USDC',
        'USDC',
        LifiApiClient.tokenAddress(_activeChain.network, 'USDC'),
        '0',
        '',
      ),
    };
    for (final token in _remoteTokens) {
      final symbol = token.symbol.trim();
      if (symbol.isNotEmpty && token.address.isNotEmpty) {
        // LI.FI is the source of truth for token metadata and logos. This
        // also replaces the local USDT/USDC fallback when LI.FI has a logo.
        values[symbol.toUpperCase()] = (
          symbol,
          symbol,
          token.address,
          '0',
          token.logoUri ?? '',
        );
      }
    }
    return values.values.toList();
  }

  List<String> get _commonSymbols => [
    _activeChain.nativeToken.symbol,
    'USDT',
    'USDC',
  ].where((symbol) => symbol != widget.excludedSymbol).toList();

  void _selectChain(_WalletChain chain) {
    if (chain.network == _activeChain.network) return;
    setState(() {
      _activeChain = chain;
      _remoteTokens = const [];
      _loadingTokens = true;
      _displayLimit = 80;
    });
    _loadTokens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The picker follows the dark transfer-sheet treatment; its content and
    // token data remain driven by the active chain.
    const palette = AcoPalette(true);
    final panelColor = palette.dark
        ? const Color(0xFF222222)
        : palette.background;
    final query = _query.trim().toLowerCase();
    final filtered = _tokens
        .where(
          (token) =>
              token.$1 != widget.excludedSymbol &&
              (query.isEmpty ||
                  token.$1.toLowerCase().contains(query) ||
                  token.$2.toLowerCase().contains(query) ||
                  token.$3.toLowerCase().contains(query)),
        )
        .toList();
    // The common-token cards already provide the primary quick choices. Keep
    // those tokens out of the initial list so they are not repeated directly
    // underneath the cards; once the user searches, matching common tokens
    // should still be discoverable in the normal results.
    final commonSymbols = _commonSymbols
        .map((symbol) => symbol.toLowerCase())
        .toSet();
    final listTokens = query.isEmpty
        ? filtered
              .where((token) => !commonSymbols.contains(token.$1.toLowerCase()))
              .toList()
        : filtered;
    final visibleTokens = listTokens.take(_displayLimit).toList();
    final hasMore = visibleTokens.length < listTokens.length;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Material(
          color: panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                SizedBox(
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '选择代币',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 36,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Icon(
                            CupertinoIcons.xmark,
                            color: palette.primaryText,
                            size: 25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoSearchTextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _displayLimit = 80;
                  }),
                  placeholder: '输入代币名称或合约地址',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    color: palette.mutedText,
                    size: 25,
                  ),
                  suffixIcon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: palette.mutedText,
                    size: 17,
                  ),
                  backgroundColor: palette.dark
                      ? const Color(0xFF3A3A3A)
                      : palette.surfaceRaised,
                  style: TextStyle(color: palette.primaryText, fontSize: 16),
                  placeholderStyle: TextStyle(
                    color: palette.mutedText,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _supportedWalletChains.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final chain = _supportedWalletChains[index];
                      final selected = chain.network == _activeChain.network;
                      return CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minSize: 0,
                        color: selected
                            ? palette.accent
                            : const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(17),
                        onPressed: () => _selectChain(chain),
                        child: Text(
                          chain.displayLabel,
                          style: TextStyle(
                            color: selected
                                ? Colors.black
                                : palette.primaryText,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '常用代币',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: Row(
                    children: [
                      for (final symbol in _commonSymbols)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _DexCommonToken(
                              symbol: symbol,
                              palette: palette,
                              onTap: () => Navigator.of(context).pop(
                                _DexTokenChoice(
                                  chain: _activeChain,
                                  symbol: symbol,
                                  logoUri: '',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: _loadingTokens && listTokens.isEmpty
                      ? const Center(child: CupertinoActivityIndicator())
                      : listTokens.isEmpty && query.isEmpty
                      ? const SizedBox.shrink()
                      : listTokens.isEmpty
                      ? Center(
                          child: Text(
                            '未找到代币',
                            style: TextStyle(color: palette.mutedText),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: visibleTokens.length + (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= visibleTokens.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: CupertinoActivityIndicator(),
                              );
                            }
                            final token = visibleTokens[index];
                            return Column(
                              children: [
                                _TokenPickerRow(
                                  symbol: token.$1,
                                  address: token.$3,
                                  balance: token.$4,
                                  logoUri: token.$5,
                                  palette: palette,
                                  selected: widget.selectedSymbol == token.$1,
                                  onTap: () => Navigator.of(context).pop(
                                    _DexTokenChoice(
                                      chain: _activeChain,
                                      symbol: token.$1,
                                      logoUri: token.$5,
                                    ),
                                  ),
                                ),
                                if (index < visibleTokens.length - 1)
                                  Container(height: 1, color: palette.border),
                              ],
                            );
                          },
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

class _DexCommonToken extends StatelessWidget {
  const _DexCommonToken({
    required this.symbol,
    required this.palette,
    required this.onTap,
  });

  final String symbol;
  final AcoPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 8),
    minSize: 0,
    color: palette.dark ? const Color(0xFF181818) : palette.inputSurface,
    borderRadius: BorderRadius.circular(16),
    onPressed: onTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _WalletAssetIcon(symbol: symbol, size: 40),
        const SizedBox(height: 5),
        Text(
          symbol,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.primaryText, fontSize: 14),
        ),
      ],
    ),
  );
}

class _TokenPickerRow extends StatelessWidget {
  const _TokenPickerRow({
    required this.symbol,
    required this.address,
    required this.balance,
    required this.logoUri,
    required this.palette,
    required this.selected,
    required this.onTap,
  });
  final String symbol, address, balance, logoUri;
  final AcoPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 6),
    minSize: 0,
    onPressed: onTap,
    child: Row(
      children: [
        _DexTokenLogo(logoUri: logoUri, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                symbol,
                style: TextStyle(
                  color: selected ? palette.accent : palette.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (address.isNotEmpty)
                Text(
                  address,
                  softWrap: true,
                  style: TextStyle(color: palette.mutedText, fontSize: 13),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(
            balance,
            textAlign: TextAlign.right,
            style: TextStyle(color: palette.primaryText, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

class _DexTokenLogo extends StatelessWidget {
  const _DexTokenLogo({required this.logoUri, required this.size});

  final String logoUri;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isRemote =
        logoUri.startsWith('https://') || logoUri.startsWith('http://');
    if (!isRemote) {
      return SizedBox(
        width: size,
        height: size,
        child: const _MissingTokenIcon(),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          logoUri,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _MissingTokenIcon(),
        ),
      ),
    );
  }
}

class _DexSwapTokenRow extends StatefulWidget {
  const _DexSwapTokenRow({
    required this.palette,
    required this.label,
    required this.symbol,
    required this.value,
    this.logoUri = '',
    this.showMax = false,
    this.editable = false,
    this.onTokenTap,
    this.onValueChanged,
  });
  final AcoPalette palette;
  final String label, symbol, value, logoUri;
  final bool showMax, editable;
  final ValueChanged<String>? onTokenTap;
  final ValueChanged<String>? onValueChanged;

  @override
  State<_DexSwapTokenRow> createState() => _DexSwapTokenRowState();
}

class _DexSwapTokenRowState extends State<_DexSwapTokenRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: widget.palette.mutedText,
                fontSize: AcoTypography.body,
              ),
            ),
            const SizedBox(height: 10),
            widget.editable
                ? CupertinoTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final valid = RegExp(
                          r'^[0-9,]*(?:\.[0-9]{0,18})?$',
                        ).hasMatch(newValue.text);
                        return valid ? newValue : oldValue;
                      }),
                    ],
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(),
                    onTap: _focusNode.requestFocus,
                    onTapOutside: (_) => _focusNode.unfocus(),
                    onSubmitted: (_) => _focusNode.unfocus(),
                    onChanged: widget.onValueChanged,
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      height: .95,
                    ),
                  )
                : Text(
                    widget.value,
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      height: .95,
                    ),
                  ),
          ],
        ),
      ),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTokenTap == null
            ? null
            : () {
                _focusNode.unfocus();
                widget.onTokenTap!(widget.symbol);
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                _WalletAssetIcon(
                  symbol: widget.symbol,
                  logoUri: widget.logoUri.isEmpty ? null : widget.logoUri,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.symbol,
                  style: TextStyle(
                    color: widget.palette.primaryText,
                    fontSize: AcoTypography.bodyEmphasis,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Image.asset(
                  'assets/icons/dex_dropdown_arrow.png',
                  width: 8,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '余额: 0.00',
                  style: TextStyle(
                    color: widget.palette.mutedText,
                    fontSize: AcoTypography.bodySmall,
                  ),
                ),
                if (widget.showMax) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.palette.mutedText),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Max',
                      style: TextStyle(
                        color: widget.palette.mutedText,
                        fontSize: AcoTypography.bodySmall,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
