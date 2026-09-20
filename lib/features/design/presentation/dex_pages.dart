part of 'aco_design_shell.dart';

class _DexTokenPage extends StatefulWidget {
  const _DexTokenPage({required this.palette, required this.selectedChain});
  final AcoPalette palette;
  final _WalletChain selectedChain;
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
    this.walletIdentity,
    this.secretStore,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
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
    this.walletIdentity,
    this.secretStore,
    required this.ethFirst,
    required this.onEthFirstChanged,
    this.recentRecord,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore? secretStore;
  final bool ethFirst;
  final ValueChanged<bool> onEthFirstChanged;
  final Future<DexSwapRecord?>? recentRecord;

  @override
  State<_DexSwapContent> createState() => _DexSwapContentState();
}

class _DexSwapContentState extends State<_DexSwapContent> {
  late String _fromSymbol;
  late String _toSymbol;
  String _fromAmount = '0';
  LifiQuote? _quote;
  bool _loading = false;
  Timer? _quoteDebounce;
  WalletIdentity? _resolvedIdentity;

  AcoPalette get palette => widget.palette;
  _WalletChain get selectedChain => widget.selectedChain;
  WalletIdentity? get walletIdentity =>
      widget.walletIdentity ?? _resolvedIdentity;
  WalletSecretStore? get secretStore => widget.secretStore;
  bool get ethFirst => widget.ethFirst;

  @override
  void initState() {
    super.initState();
    _fromSymbol = _nativeSymbol;
    _toSymbol = 'USDC';
    if (widget.walletIdentity == null) unawaited(_loadWalletIdentity());
  }

  String get _nativeSymbol => selectedChain.nativeToken.symbol;

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

  void _setSwap(String from, String to, String amount) {
    setState(() {
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
    final address = await _addressForChain(identity, selectedChain);
    if (!context.mounted) return;
    if (address == null || address.isEmpty) {
      if (showNotice) {
        _showNotice(context, '兑换', '当前公链钱包地址尚未准备完成。');
      }
      return;
    }
    final amount = _normalizedFromAmount;
    final parsedAmount = double.tryParse(amount);
    if (parsedAmount == null || parsedAmount <= 0) {
      if (showNotice) _showNotice(context, '兑换', '请输入有效的兑换金额。');
      return;
    }
    setState(() => _loading = true);
    final client = LifiApiClient();
    try {
      final nativeSymbol = switch (selectedChain.network) {
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
      final sourceDecimals = sourceSymbol == nativeSymbol
          ? (selectedChain.network == WalletNetwork.solana ? 9 : 18)
          : (WalletChainRegistry
                    .chains[selectedChain.network]
                    ?.usdc
                    ?.decimals ??
                6);
      List<LifiToken> availableTokens = const [];
      try {
        availableTokens = await client.tokens(selectedChain.network);
      } catch (_) {
        // The local registry remains a valid offline fallback.
      }
      final sourceToken = availableTokens.cast<LifiToken?>().firstWhere(
        (token) => token?.symbol.toUpperCase() == sourceSymbol.toUpperCase(),
        orElse: () => null,
      );
      final targetToken = availableTokens.cast<LifiToken?>().firstWhere(
        (token) => token?.symbol.toUpperCase() == targetSymbol.toUpperCase(),
        orElse: () => null,
      );
      final sourceTokenAddress = sourceToken?.address;
      final resolvedSourceDecimals = sourceToken?.decimals ?? sourceDecimals;
      final quote = await client.quote(
        fromNetwork: selectedChain.network,
        fromToken: sourceSymbol,
        toNetwork: selectedChain.network,
        toToken: targetSymbol,
        fromAmount: amount,
        fromDecimals: resolvedSourceDecimals,
        fromAddress: address,
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
      if (selectedChain.network == WalletNetwork.solana) {
        await _executeSolanaQuote(
          context,
          identity: identity,
          address: address,
          request: request,
        );
        return;
      }
      if (selectedChain.network == WalletNetwork.tron) {
        await _executeTronQuote(context, identity: identity, request: request);
        return;
      }
      if (!context.mounted || !await _confirmSwap(context, quote.tool)) return;
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
              LifiApiClient.tokenAddress(selectedChain.network, sourceSymbol);
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
                from: address,
                network: selectedChain.network,
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
              from: address,
              network: selectedChain.network,
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
          fromNetwork: selectedChain.network,
          toNetwork: selectedChain.network,
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
    if (!await _confirmSwap(context, 'LI.FI / Solana')) return;
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
    if (!await _confirmSwap(context, 'LI.FI / TRON')) return;
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

  Future<bool> _confirmSwap(BuildContext context, String tool) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('确认兑换'),
        content: Text('将通过 $tool 路由提交交易，是否继续？'),
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
        selectedChain: selectedChain,
        ethFirst: ethFirst,
        onEthFirstChanged: widget.onEthFirstChanged,
        onSwapChanged: _setSwap,
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
      _DexSwapQuoteCard(palette: palette, quote: _quote),
      const SizedBox(height: 28),
      _DexRecentSwapRecord(palette: palette, future: widget.recentRecord),
    ],
  );
}

class _DexSwapQuoteCard extends StatelessWidget {
  const _DexSwapQuoteCard({required this.palette, this.quote});
  final AcoPalette palette;
  final LifiQuote? quote;

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
          quote == null ? '-' : '${quote!.fromAmount} → ${quote!.toAmount}',
        ),
        _row('滑点', '2%'),
        _row('最少接收数量', quote?.toAmountMin ?? '-'),
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

final _mockDexSwapRecords = <DexSwapRecord>[
  DexSwapRecord(
    source: 'app',
    fromAmount: '0.25',
    fromSymbol: 'ETH',
    toAmount: '824.36',
    toSymbol: 'USDC',
    status: '已完成',
    createdAt: DateTime(2026, 9, 20, 14, 32),
  ),
  DexSwapRecord(
    source: 'app',
    fromAmount: '120',
    fromSymbol: 'USDT',
    toAmount: '0.036',
    toSymbol: 'ETH',
    status: '已完成',
    createdAt: DateTime(2026, 9, 19, 18, 8),
  ),
  DexSwapRecord(
    source: 'app',
    fromAmount: '500',
    fromSymbol: 'USDC',
    toAmount: '499.42',
    toSymbol: 'USDT',
    status: '处理中',
    createdAt: DateTime(2026, 9, 18, 9, 16),
  ),
  DexSwapRecord(
    source: 'app',
    fromAmount: '1.2',
    fromSymbol: 'ETH',
    toAmount: '3,958.80',
    toSymbol: 'USDT',
    status: '已完成',
    createdAt: DateTime(2026, 9, 17, 21, 44),
  ),
  DexSwapRecord(
    source: 'app',
    fromAmount: '860',
    fromSymbol: 'USDT',
    toAmount: '859.12',
    toSymbol: 'USDC',
    status: '已完成',
    createdAt: DateTime(2026, 9, 16, 11, 5),
  ),
  DexSwapRecord(
    source: 'app',
    fromAmount: '0.08',
    fromSymbol: 'ETH',
    toAmount: '264.18',
    toSymbol: 'USDC',
    status: '失败',
    createdAt: DateTime(2026, 9, 15, 16, 27),
  ),
];

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
              '最近一条记录',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '更多记录',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.bodyEmphasis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (future == null)
        _recordList(_mockDexSwapRecords)
      else
        FutureBuilder<DexSwapRecord?>(
          future: future,
          builder: (context, snapshot) {
            final record = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(height: 56);
            }
            if (record == null || record.source != 'app') return _emptyState();
            return _recordList([record, ..._mockDexSwapRecords.skip(1)]);
          },
        ),
    ],
  );

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

  Widget _recordCard(DexSwapRecord record) => Container(
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

class _DexSwapPanel extends StatefulWidget {
  const _DexSwapPanel({
    required this.palette,
    required this.selectedChain,
    required this.ethFirst,
    required this.onEthFirstChanged,
    required this.onSwapChanged,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final bool ethFirst;
  final ValueChanged<bool> onEthFirstChanged;
  final void Function(String from, String to, String amount) onSwapChanged;

  @override
  State<_DexSwapPanel> createState() => _DexSwapPanelState();
}

class _DexSwapPanelState extends State<_DexSwapPanel> {
  late String _fromSymbol;
  late String _toSymbol;
  String _fromLogoUri = '';
  String _toLogoUri = '';
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _syncSymbols(widget.ethFirst);
    _amountController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _syncSymbols(bool ethFirst) {
    final native = widget.selectedChain.nativeToken.symbol;
    _fromSymbol = ethFirst ? native : 'USDC';
    _toSymbol = ethFirst ? 'USDC' : native;
    _fromLogoUri = '';
    _toLogoUri = '';
  }

  @override
  void didUpdateWidget(covariant _DexSwapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNative = oldWidget.selectedChain.nativeToken.symbol;
    final isNativePair =
        (_fromSymbol == oldNative && _toSymbol == 'USDC') ||
        (_fromSymbol == 'USDC' && _toSymbol == oldNative);
    if (oldWidget.selectedChain.network != widget.selectedChain.network ||
        (oldWidget.ethFirst != widget.ethFirst && isNativePair)) {
      _syncSymbols(widget.ethFirst);
    }
  }

  void _pickToken(BuildContext context, String current, bool source) {
    showCupertinoModalPopup<(String, String)>(
      context: context,
      builder: (context) => _DexTokenPicker(
        palette: widget.palette,
        selectedChain: widget.selectedChain,
        selectedSymbol: current,
        excludedSymbol: source ? _toSymbol : _fromSymbol,
      ),
    ).then((selection) {
      if (selection == null) return;
      final (symbol, logoUri) = selection;
      setState(() {
        if (source) {
          _fromSymbol = symbol;
          _fromLogoUri = logoUri;
          if (_toSymbol == symbol)
            _toSymbol = current == symbol
                ? _toSymbol
                : (symbol == widget.selectedChain.nativeToken.symbol
                      ? 'USDC'
                      : widget.selectedChain.nativeToken.symbol);
          if (_toSymbol != symbol) _toLogoUri = '';
        } else {
          _toSymbol = symbol;
          _toLogoUri = logoUri;
          if (_fromSymbol == symbol)
            _fromSymbol = symbol == widget.selectedChain.nativeToken.symbol
                ? 'USDC'
                : widget.selectedChain.nativeToken.symbol;
          if (_fromSymbol != symbol) _fromLogoUri = '';
        }
      });
      widget.onSwapChanged(_fromSymbol, _toSymbol, _amountController.text);
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
          label: '兑换货币',
          symbol: _fromSymbol,
          logoUri: _fromLogoUri,
          value: _amountController.text,
          showMax: true,
          editable: true,
          onValueChanged: (value) {
            _amountController.text = value;
            widget.onSwapChanged(_fromSymbol, _toSymbol, value);
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
                  final logoUri = _fromLogoUri;
                  _fromLogoUri = _toLogoUri;
                  _toLogoUri = logoUri;
                });
                widget.onSwapChanged(
                  _fromSymbol,
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
          label: '至',
          symbol: _toSymbol,
          logoUri: _toLogoUri,
          value: '-',
          onTokenTap: (symbol) => _pickToken(context, symbol, false),
        ),
      ],
    ),
  );
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
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  List<LifiToken> _remoteTokens = const [];
  bool _loadingTokens = true;
  int _displayLimit = 80;

  @override
  void initState() {
    super.initState();
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
      final tokens = await client.tokens(widget.selectedChain.network);
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
      widget.selectedChain.nativeToken.symbol: (
        widget.selectedChain.nativeToken.symbol,
        widget.selectedChain.nativeToken.symbol,
        '',
        '0',
        '',
      ),
      'USDT': (
        'USDT',
        'USDT',
        LifiApiClient.tokenAddress(widget.selectedChain.network, 'USDT'),
        '0',
        '',
      ),
      'USDC': (
        'USDC',
        'USDC',
        LifiApiClient.tokenAddress(widget.selectedChain.network, 'USDC'),
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
    widget.selectedChain.nativeToken.symbol,
    'USDT',
    'USDC',
  ].where((symbol) => symbol != widget.excludedSymbol).toList();

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
                              onTap: () =>
                                  Navigator.of(context).pop((symbol, '')),
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
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop((token.$1, token.$5)),
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
            : () => widget.onTokenTap!(widget.symbol),
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
