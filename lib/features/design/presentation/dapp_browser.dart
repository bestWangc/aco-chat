part of 'aco_design_shell.dart';

class _DappBrowserPage extends StatefulWidget {
  const _DappBrowserPage({
    required this.palette,
    required this.initialUrl,
    required this.title,
    required this.dappId,
    required this.walletIdentity,
    required this.selectedChain,
    required this.onChainSelected,
  });

  final AcoPalette palette;
  final String initialUrl;
  final String title;
  final String dappId;
  final WalletIdentity? walletIdentity;
  final _WalletChain selectedChain;
  final ValueChanged<int> onChainSelected;

  @override
  State<_DappBrowserPage> createState() => _DappBrowserPageState();
}

class _DappBrowserLoading extends StatelessWidget {
  const _DappBrowserLoading({
    required this.palette,
    required this.title,
    required this.dappId,
  });

  final AcoPalette palette;
  final String title;
  final String dappId;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            _dappLogoAsset(dappId),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 64,
              height: 64,
              color: palette.surfaceRaised,
              child: Icon(
                CupertinoIcons.globe,
                color: palette.mutedText,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '正在跳转第三方网站',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _DappBrowserMenu extends StatelessWidget {
  const _DappBrowserMenu({
    required this.palette,
    required this.onCopy,
    required this.onRefresh,
    required this.onOpenExternal,
  });

  final AcoPalette palette;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: () => Navigator.of(context).pop(),
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: palette.mutedText,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DappBrowserMenuAction(
                icon: CupertinoIcons.doc_on_doc,
                label: '复制链接',
                palette: palette,
                onPressed: onCopy,
              ),
              _DappBrowserMenuAction(
                icon: CupertinoIcons.refresh,
                label: '刷新',
                palette: palette,
                onPressed: onRefresh,
              ),
              _DappBrowserMenuAction(
                icon: CupertinoIcons.globe,
                label: '系统浏览器打开',
                palette: palette,
                onPressed: onOpenExternal,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DappBrowserMenuAction extends StatelessWidget {
  const _DappBrowserMenuAction({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final AcoPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: SizedBox.square(
                dimension: 26,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Icon(icon, color: palette.primaryText),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(color: palette.primaryText, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class _DappBrowserPageState extends State<_DappBrowserPage> {
  static final _connectedPermissionKeys = <String>{};

  final _sessionConnectedOrigins = <String>{};
  var _reloadedAfterLayout = false;
  InAppWebViewController? _controller;
  late Uri _currentUri;
  late _WalletChain _activeChain;
  var _isLoading = true;
  String? _loadError;

  bool get _isEvmChain =>
      WalletChainRegistry.chains[_activeChain.network]?.isEvm ?? false;

  InAppWebViewSettings get _webViewSettings => InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: false,
    supportMultipleWindows: false,
    cacheEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    incognito: false,
    sharedCookiesEnabled: true,
    thirdPartyCookiesEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    useShouldOverrideUrlLoading: true,
    safeBrowsingEnabled: true,
    clearCache: false,
  );

  UnmodifiableListView<UserScript> get _initialUserScripts {
    final scripts = <UserScript>[_dappStorageUserScript];
    if (_isEvmChain) {
      scripts.add(_evmProviderUserScript);
    } else if (_activeChain.network == WalletNetwork.solana) {
      scripts.add(_solanaProviderUserScript);
    }
    return UnmodifiableListView(scripts);
  }

  @override
  void initState() {
    super.initState();
    _activeChain = widget.selectedChain;
    _currentUri = _normalizeDappUri(widget.initialUrl);
    unawaited(_restoreConnectedPermissions());
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: widget.palette.background,
    resizeToAvoidBottomInset: false,
    child: SafeArea(
      left: false,
      right: false,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_currentUri.toString()),
                  ),
                  initialSettings: _webViewSettings,
                  initialUserScripts: _initialUserScripts,
                  onWebViewCreated: _onWebViewCreated,
                  onLoadStart: (_, url) => _onLocationChanged(url),
                  onLoadStop: (controller, url) {
                    _onLocationChanged(url);
                    if (widget.dappId == 'wandering-earth' &&
                        !_reloadedAfterLayout) {
                      _reloadedAfterLayout = true;
                      if (mounted) setState(() => _isLoading = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) unawaited(controller.reload());
                      });
                      return;
                    }
                    if (mounted) setState(() => _isLoading = false);
                  },
                  onProgressChanged: (_, progress) {
                    if (mounted) setState(() => _isLoading = progress < 100);
                  },
                  onReceivedError: (_, request, error) {
                    if (request.isForMainFrame != true || !mounted) return;
                    setState(() {
                      _isLoading = false;
                      _loadError = '页面加载失败：${error.description}';
                    });
                  },
                  shouldOverrideUrlLoading: (_, action) =>
                      _allowNavigation(action.request.url),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: widget.palette.background,
                      child: _DappBrowserLoading(
                        palette: widget.palette,
                        title: widget.title,
                        dappId: widget.dappId,
                      ),
                    ),
                  ),
                if (_loadError case final error?)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: widget.palette.mutedText),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader() => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 88),
              child: Text(
                _currentUri.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              right: 5,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: widget.palette.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(34, 28),
                      onPressed: _showBrowserMenu,
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        color: widget.palette.primaryText,
                        size: 20,
                      ),
                    ),
                    Container(width: 1, color: widget.palette.border),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      minimumSize: const Size(30, 28),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: widget.palette.primaryText,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      Container(height: 1, color: widget.palette.border),
      AnimatedAlign(
        alignment: Alignment.centerLeft,
        duration: const Duration(milliseconds: 180),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 3,
          width: _isLoading ? MediaQuery.sizeOf(context).width * .25 : 0,
          color: widget.palette.accent,
        ),
      ),
    ],
  );

  void _showBrowserMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x88000000),
      builder: (menuContext) => _DappBrowserMenu(
        palette: widget.palette,
        onCopy: () => _copyCurrentUrl(menuContext),
        onRefresh: () => _refreshPage(menuContext),
        onOpenExternal: () => _openInSystemBrowser(menuContext),
      ),
    );
  }

  void _copyCurrentUrl(BuildContext menuContext) {
    Clipboard.setData(ClipboardData(text: _currentUri.toString()));
    Navigator.of(menuContext).pop();
  }

  void _refreshPage(BuildContext menuContext) {
    Navigator.of(menuContext).pop();
    _controller?.reload();
  }

  void _openInSystemBrowser(BuildContext menuContext) {
    Navigator.of(menuContext).pop();
    launchUrl(_currentUri, mode: LaunchMode.externalApplication);
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'acoDappProvider',
      callback: (arguments) => _handleProviderRequest(arguments),
    );
    controller.addJavaScriptHandler(
      handlerName: 'acoSolanaProvider',
      callback: (arguments) => _handleSolanaProviderRequest(arguments),
    );
    controller.addJavaScriptHandler(
      handlerName: 'acoDappStorageGet',
      callback: (arguments) => _loadDappStorage(arguments),
    );
    controller.addJavaScriptHandler(
      handlerName: 'acoDappStorageSet',
      callback: (arguments) => _saveDappStorage(arguments),
    );
  }

  Future<void> _restoreConnectedPermissions() async {
    final preferences = await SharedPreferences.getInstance();
    _connectedPermissionKeys.addAll(
      preferences.getStringList('dapp.connected_permissions') ?? const [],
    );
  }

  String? _connectionPermissionKey() {
    final origin = _origin;
    final identity = widget.walletIdentity;
    if (origin == null || identity == null) return null;
    return '$origin|${_activeChain.network.name}|${identity.address.toLowerCase()}';
  }

  bool _isOriginConnected() {
    final key = _connectionPermissionKey();
    return key != null && _connectedPermissionKeys.contains(key);
  }

  Future<void> _rememberOriginConnection() async {
    final key = _connectionPermissionKey();
    if (key == null) return;
    _connectedPermissionKeys.add(key);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'dapp.connected_permissions',
      _connectedPermissionKeys.toList(growable: false),
    );
  }

  Future<Map<String, String>> _loadDappStorage(List<dynamic> arguments) async {
    final origin = _storageOrigin(arguments);
    if (origin == null) return const {};
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_dappStorageKey(origin));
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const {};
      return decoded.map((key, value) => MapEntry('$key', '$value'));
    } on FormatException {
      return const {};
    }
  }

  Future<bool> _saveDappStorage(List<dynamic> arguments) async {
    if (arguments.length != 1 || arguments.first is! Map) return false;
    final payload = Map<String, dynamic>.from(arguments.first as Map);
    final origin = payload['origin'];
    final data = payload['data'];
    if (origin is! String || data is! Map) return false;
    final values = <String, String>{
      for (final entry in data.entries) '${entry.key}': '${entry.value}',
    };
    final preferences = await SharedPreferences.getInstance();
    return preferences.setString(_dappStorageKey(origin), jsonEncode(values));
  }

  String? _storageOrigin(List<dynamic> arguments) {
    if (arguments.length != 1 || arguments.first is! String) return null;
    final origin = arguments.first as String;
    return origin == _origin ? origin : null;
  }

  String _dappStorageKey(String origin) =>
      'dapp.local_storage.${Uri.encodeComponent(origin)}';

  Future<Map<String, dynamic>> _handleSolanaProviderRequest(
    List<dynamic> arguments,
  ) async {
    if (_activeChain.network != WalletNetwork.solana) {
      return _providerError(4200, '当前网络不支持 Solana Provider');
    }
    if (arguments.length != 1 || arguments.first is! String) {
      return _providerError(-32600, '无效的钱包请求');
    }
    try {
      final request = jsonDecode(arguments.first as String);
      if (request is! Map<String, dynamic> || request['method'] is! String) {
        return _providerError(-32600, '无效的钱包请求');
      }
      return switch (request['method'] as String) {
        'connect' => _connectSolanaWallet(),
        'disconnect' => _disconnectSolanaWallet(),
        'signMessage' => _signSolanaMessage(request['params']),
        'signTransaction' => _signSolanaTransaction(request['params']),
        'signAllTransactions' ||
        'signAndSendTransaction' => _providerError(4200, '当前仅支持单笔标准 SOL 转账签名'),
        _ => _providerError(4200, '暂不支持 ${request['method']}'),
      };
    } on FormatException {
      return _providerError(-32600, '钱包请求格式无效');
    }
  }

  Future<Map<String, dynamic>> _connectSolanaWallet() async {
    final identity = widget.walletIdentity;
    final origin = _origin;
    if (identity == null || origin == null) {
      return _providerError(4100, '请先创建或导入钱包');
    }
    final address = await _solanaAddress(identity);
    if (address == null) return _providerError(4100, 'Solana 地址尚未准备完成');
    if (!_sessionConnectedOrigins.contains(origin)) {
      final approved = await _confirm(
        title: '连接 Solana 钱包',
        message: '$origin 将读取 $address 的公开地址。',
        action: '连接',
      );
      if (!approved) return _providerError(4001, '用户拒绝连接钱包');
      _sessionConnectedOrigins.add(origin);
    }
    return _providerResult({'publicKey': address});
  }

  Map<String, dynamic> _disconnectSolanaWallet() {
    final origin = _origin;
    if (origin != null) _sessionConnectedOrigins.remove(origin);
    return _providerResult(null);
  }

  Future<Map<String, dynamic>> _signSolanaMessage(dynamic rawParams) async {
    final identity = widget.walletIdentity;
    final origin = _origin;
    if (identity == null ||
        origin == null ||
        !_sessionConnectedOrigins.contains(origin)) {
      return _providerError(4100, '请先连接钱包');
    }
    if (rawParams is! Map || rawParams['message'] is! String) {
      return _providerError(-32602, '签名内容无效');
    }
    final message = _base64Bytes(rawParams['message'] as String);
    if (message == null || message.length > 4096) {
      return _providerError(-32602, '签名内容无效或超过 4 KB');
    }
    final address = await _solanaAddress(identity);
    if (address == null) return _providerError(4100, 'Solana 地址尚未准备完成');
    final approved = await _confirm(
      title: '确认 Solana 消息签名',
      message:
          '$origin 请求使用 $address 签名。\n\n'
          '内容：${_messagePreview(message)}\n\n'
          '该签名不会发起链上交易。',
      action: '签名',
    );
    if (!approved) return _providerError(4001, '用户拒绝签名');
    try {
      final mnemonic = await _unlockWalletMnemonic(identity);
      if (mnemonic == null) return _providerError(4001, '用户取消钱包验证');
      final signature = await const SolanaSigningService().signMessage(
        mnemonic: mnemonic,
        message: message,
      );
      return _providerResult({'signature': signature, 'publicKey': address});
    } on WalletSecurityException catch (error) {
      return _providerError(4100, error.message);
    } catch (_) {
      return _providerError(-32603, 'Solana 消息签名失败');
    }
  }

  Future<Map<String, dynamic>> _signSolanaTransaction(dynamic rawParams) async {
    final identity = widget.walletIdentity;
    final origin = _origin;
    if (identity == null ||
        origin == null ||
        !_sessionConnectedOrigins.contains(origin)) {
      return _providerError(4100, '请先连接钱包');
    }
    if (rawParams is! Map || rawParams['transaction'] is! String) {
      return _providerError(-32602, '交易内容无效');
    }
    final encodedTransaction = rawParams['transaction'] as String;
    try {
      final signerAddress = await _solanaAddress(identity);
      if (signerAddress == null) return _providerError(4100, 'Solana 地址尚未准备完成');
      final preview = const SolanaSigningService()
          .inspectSerializedNativeTransfer(
            serializedTransaction: encodedTransaction,
            signerAddress: signerAddress,
          );
      final approved = await _confirm(
        title: '确认 SOL 转账',
        message:
            '$origin 请求发送一笔 SOL 转账。\n\n'
            '收款地址：${_shortAddress(preview.recipient)}\n'
            '金额：${_lamportsToSol(preview.lamports)} SOL\n\n'
            '交易签名已强制输入钱包密码。',
        action: '确认签名',
      );
      if (!approved) return _providerError(4001, '用户拒绝交易');
      final mnemonic = await _unlockWalletMnemonic(identity);
      if (mnemonic == null) return _providerError(4001, '用户取消钱包验证');
      final signed = const SolanaSigningService().signSerializedNativeTransfer(
        mnemonic: mnemonic,
        serializedTransaction: encodedTransaction,
      );
      return _providerResult({'transaction': signed.signedTransaction});
    } on WalletSecurityException catch (error) {
      return _providerError(4100, error.message);
    } on FormatException catch (error) {
      return _providerError(4200, error.message);
    } catch (_) {
      return _providerError(-32603, 'Solana 交易签名失败');
    }
  }

  Future<String?> _solanaAddress(WalletIdentity identity) async {
    final addresses = await WalletPreferences.derivedAddresses(identity);
    return addresses['solana'];
  }

  Future<Map<String, dynamic>> _handleProviderRequest(
    List<dynamic> arguments,
  ) async {
    if (!_isEvmChain) return _providerError(4200, '当前网络不支持 EVM Provider');
    if (arguments.length != 1 || arguments.first is! String) {
      return _providerError(-32600, '无效的钱包请求');
    }
    try {
      final request = jsonDecode(arguments.first as String);
      if (request is! Map<String, dynamic>) {
        return _providerError(-32600, '无效的钱包请求');
      }
      final method = request['method'];
      if (method is! String || method.isEmpty) {
        return _providerError(-32600, '缺少请求方法');
      }
      return switch (method) {
        'eth_chainId' => _providerResult(_evmChainId(_activeChain.network)),
        'net_version' => _providerResult(
          int.parse(
            _evmChainId(_activeChain.network).substring(2),
            radix: 16,
          ).toString(),
        ),
        'eth_accounts' => _accountsForCurrentOrigin(),
        'eth_requestAccounts' => _requestAccounts(),
        'eth_call' => _ethCall(request['params']),
        'wallet_switchEthereumChain' => _switchEthereumChain(request['params']),
        'personal_sign' => _signMessage(request['params'], personal: true),
        'eth_sign' => _signMessage(request['params'], personal: false),
        'eth_signTypedData' ||
        'eth_signTypedData_v3' ||
        'eth_signTypedData_v4' => _providerError(
          4200,
          'Typed Data 签名正在接入，当前请求已安全拒绝',
        ),
        'eth_sendTransaction' => _sendTransaction(request['params']),
        'eth_signTransaction' => _providerError(4200, '离线交易签名正在接入，当前请求已安全拒绝'),
        _ => _providerError(4200, '暂不支持 $method；签名与交易审批正在接入'),
      };
    } on FormatException {
      return _providerError(-32600, '钱包请求格式无效');
    }
  }

  Future<Map<String, dynamic>> _requestAccounts() async {
    await _restoreConnectedPermissions();
    final identity = widget.walletIdentity;
    if (identity == null) return _providerError(4100, '请先创建或导入钱包');
    final origin = _origin;
    if (origin == null) return _providerError(4100, '当前页面来源无效');
    if (!_isOriginConnected()) {
      final approved = await _confirm(
        title: '连接钱包',
        message: '$origin 将读取 ${identity.address} 的公开地址。',
        action: '连接',
      );
      if (!approved) return _providerError(4001, '用户拒绝连接钱包');
      await _rememberOriginConnection();
    }
    return _providerResult([identity.address]);
  }

  Future<Map<String, dynamic>> _ethCall(dynamic rawParams) async {
    if (rawParams is! List || rawParams.isEmpty || rawParams.first is! Map) {
      return _providerError(-32602, 'eth_call 参数无效');
    }
    final tokens = await SecureAccountTokenStore().read();
    if (tokens == null || tokens.accessToken.isEmpty) {
      return _providerError(4100, '账户尚未登录');
    }
    final call = Map<String, Object>.from(rawParams.first as Map);
    final blockTag = rawParams.length > 1 && rawParams[1] is String
        ? rawParams[1] as String
        : 'latest';
    final rpc = WalletRpcClient(
      client: http.Client(),
      directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
      ownsClient: true,
    );
    try {
      final endpoints = await rpc.loadEndpoints(
        network: _activeChain.network.name,
        accessToken: tokens.accessToken,
      );
      final response = await rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_call',
        'params': [call, blockTag],
      });
      final result = response['result'];
      if (result is! String) {
        return _providerError(-32000, 'eth_call 返回结果无效');
      }
      return _providerResult(result);
    } catch (_) {
      return _providerError(-32000, 'eth_call 执行失败');
    } finally {
      rpc.close();
    }
  }

  Future<Map<String, dynamic>> _switchEthereumChain(dynamic rawParams) async {
    if (rawParams is! List || rawParams.isEmpty || rawParams.first is! Map) {
      return _providerError(-32602, '缺少目标网络');
    }
    final chainId = rawParams.first['chainId'];
    if (chainId is! String) return _providerError(-32602, '网络标识无效');
    final targetIndex = _supportedWalletChains.indexWhere(
      (chain) =>
          _isEvmNetwork(chain.network) &&
          _evmChainId(chain.network).toLowerCase() == chainId.toLowerCase(),
    );
    if (targetIndex < 0) return _providerError(4902, 'Aco 暂未配置该网络');
    final target = _supportedWalletChains[targetIndex];
    if (target.network == _activeChain.network) return _providerResult(null);
    final approved = await _confirm(
      title: '切换网络',
      message:
          '此 DApp 请求从 ${_activeChain.displayLabel} 切换至 ${target.displayLabel}。',
      action: '切换',
    );
    if (!approved) return _providerError(4001, '用户拒绝切换网络');
    setState(() => _activeChain = target);
    widget.onChainSelected(targetIndex);
    return {'result': null, 'chainId': _evmChainId(target.network)};
  }

  Future<Map<String, dynamic>> _signMessage(
    dynamic rawParams, {
    required bool personal,
  }) async {
    final identity = widget.walletIdentity;
    final origin = _origin;
    if (identity == null || origin == null || !_isOriginConnected()) {
      return _providerError(4100, '请先连接钱包');
    }
    if (rawParams is! List || rawParams.length < 2) {
      return _providerError(-32602, '缺少签名参数');
    }
    final messageIndex = personal ? 0 : 1;
    final accountIndex = personal ? 1 : 0;
    final account = rawParams[accountIndex];
    final rawMessage = rawParams[messageIndex];
    if (account is! String || account.toLowerCase() != identity.address) {
      return _providerError(4100, '签名账户与已连接账户不一致');
    }
    if (rawMessage is! String) return _providerError(-32602, '签名内容无效');
    final message = _evmMessageBytes(rawMessage);
    if (message == null || message.length > 4096) {
      return _providerError(-32602, '签名内容无效或超过 4 KB');
    }

    final approved = await _confirm(
      title: personal ? '确认消息签名' : '确认原始签名',
      message:
          '$origin 请求使用 ${identity.address} 签名。\n\n'
          '内容：${_messagePreview(message)}\n\n'
          '${personal ? '该签名包含钱包标准前缀，不会发起链上交易。' : '原始签名可能被用于链上操作，请确认你信任该网站。'}',
      action: '签名',
    );
    if (!approved) return _providerError(4001, '用户拒绝签名');

    try {
      final mnemonic = await _unlockWalletMnemonic(identity);
      if (mnemonic == null) return _providerError(4001, '用户取消钱包验证');
      final signature = personal
          ? WalletIdentity.signPersonalMessage(
              mnemonic: mnemonic,
              message: message,
            )
          : WalletIdentity.signRawMessage(mnemonic: mnemonic, message: message);
      return _providerResult(signature);
    } on WalletSecurityException catch (error) {
      return _providerError(4100, error.message);
    } catch (_) {
      return _providerError(-32603, '消息签名失败');
    }
  }

  Future<Map<String, dynamic>> _sendTransaction(dynamic rawParams) async {
    final identity = widget.walletIdentity;
    final origin = _origin;
    if (identity == null || origin == null || !_isOriginConnected()) {
      return _providerError(4100, '请先连接钱包');
    }
    if (!_isEvmChain) return _providerError(4200, '当前网络不是 EVM 网络');
    if (rawParams is! List ||
        rawParams.length != 1 ||
        rawParams.first is! Map) {
      return _providerError(-32602, '交易参数无效');
    }
    final transaction = rawParams.first.cast<String, dynamic>();
    final from = transaction['from'];
    final to = transaction['to'];
    if (from is! String ||
        from.toLowerCase() != identity.address.toLowerCase()) {
      return _providerError(4100, '交易发起账户与已连接账户不一致');
    }
    if (to is! String || !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(to)) {
      return _providerError(-32602, '当前仅支持 EVM 原生资产转账');
    }
    final value = _parseHexInteger(transaction['value'] ?? '0x0');
    if (value == null || value < BigInt.zero) {
      return _providerError(-32602, '交易金额无效');
    }
    final chainId = transaction['chainId'];
    if (chainId is String &&
        chainId.toLowerCase() != _evmChainId(_activeChain.network)) {
      return _providerError(4901, '交易网络与当前钱包网络不一致');
    }

    final data = transaction['data'] ?? transaction['input'] ?? '0x';
    if (data is! String || !data.startsWith('0x')) {
      return _providerError(-32602, '交易调用数据无效');
    }
    final dataBytes = _evmMessageBytes(data);
    if (dataBytes == null) return _providerError(-32602, '交易调用数据无效');
    final hasContractData = data != '0x';
    final requestedGas = _parseHexInteger(transaction['gas'] ?? '');
    final gasLimit = _gasLimitFor(
      requestedGas,
      hasContractData: hasContractData,
    );
    final tokenCall = _parseSupportedTokenCall(
      contract: to,
      data: data,
      network: _activeChain.network,
    );

    final tokens = await SecureAccountTokenStore().read();
    if (tokens == null) {
      return _providerError(4900, '当前无法连接钱包 RPC，请稍后重试');
    }
    final approved = await _confirm(
      title: tokenCall?.isApproval == true ? '确认代币授权' : '确认交易',
      message: _transactionConfirmationMessage(
        origin: origin,
        to: to,
        value: value,
        tokenCall: tokenCall,
        hasContractData: hasContractData,
      ),
      action: tokenCall?.isApproval == true ? '确认授权' : '确认交易',
    );
    if (!approved) return _providerError(4001, '用户拒绝交易');

    try {
      final mnemonic = await _unlockWalletMnemonic(identity);
      if (mnemonic == null) return _providerError(4001, '用户取消钱包验证');
      final rpc = WalletRpcClient(
        client: http.Client(),
        directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
        ownsClient: true,
      );
      try {
        final result = await const WalletTransferService().executeWithRpc(
          mnemonic: mnemonic,
          from: identity.address,
          to: to,
          amount: _weiToDecimal(value),
          network: _activeChain.network,
          accessToken: tokens.accessToken,
          rpc: rpc,
          data: dataBytes,
          gasLimit: gasLimit,
        );
        return _providerResult(result.hash);
      } finally {
        rpc.close();
      }
    } on WalletSecurityException catch (error) {
      return _providerError(4100, error.message);
    } catch (_) {
      return _providerError(-32000, '交易签名或广播失败');
    }
  }

  String _transactionConfirmationMessage({
    required String origin,
    required String to,
    required BigInt value,
    required _Erc20Call? tokenCall,
    required bool hasContractData,
  }) {
    final base = '$origin 请求发送一笔交易。\n\n网络：${_activeChain.displayLabel}\n';
    if (tokenCall == null) {
      if (hasContractData) {
        return '$base'
            '目标合约：$to\n'
            '附带金额：${_weiToDecimal(value)} ${_activeChain.nativeToken.symbol}\n'
            '类型：智能合约调用\n\n'
            '请确认你信任该 DApp 及目标合约。网络费将按当前网络实时估算。';
      }
      return '$base'
          '收款地址：$to\n'
          '金额：${_weiToDecimal(value)} ${_activeChain.nativeToken.symbol}\n\n'
          '网络费将按当前网络实时估算。交易签名必须输入钱包密码。';
    }
    final amount = tokenCall.isUnlimited
        ? '无限额度'
        : '${_baseUnitsToDecimal(tokenCall.amount, tokenCall.token.decimals)} '
              '${tokenCall.token.symbol}';
    final action = tokenCall.isApproval ? '授权地址' : '收款地址';
    final warning = tokenCall.isApproval
        ? tokenCall.isUnlimited
              ? '此操作允许对方无限使用该代币，请仅授权可信 DApp。'
              : '授权后，对方可在额度内使用该代币。'
        : '这是标准 ERC-20 代币转账。';
    return '$base'
        '代币：${tokenCall.token.symbol}\n'
        '$action：${tokenCall.recipient}\n'
        '${tokenCall.isApproval ? '授权额度' : '金额'}：$amount\n'
        '代币合约：$to\n\n'
        '$warning\n网络费将按当前网络实时估算。交易签名必须输入钱包密码。';
  }

  int _gasLimitFor(BigInt? requested, {required bool hasContractData}) {
    final fallback = hasContractData ? 300000 : 21000;
    if (requested == null) return fallback;
    final minimum = BigInt.from(21000);
    final maximum = BigInt.from(2000000);
    if (requested < minimum) return minimum.toInt();
    if (requested > maximum) return maximum.toInt();
    return requested.toInt();
  }

  /// Unlocks wallet material for a DApp request.
  Future<String?> _unlockWalletMnemonic(WalletIdentity identity) async {
    return showWalletUnlockDialog(
      context: context,
      store: SecureWalletSecretStore(),
      walletAddress: identity.address,
    );
  }

  Future<Map<String, dynamic>> _accountsForCurrentOrigin() async {
    await _restoreConnectedPermissions();
    final identity = widget.walletIdentity;
    if (identity == null || !_isOriginConnected()) {
      return _providerResult(const []);
    }
    return _providerResult([identity.address]);
  }

  String? get _origin {
    if (_currentUri.scheme != 'https' || _currentUri.host.isEmpty) return null;
    return _currentUri.origin;
  }

  void _onLocationChanged(WebUri? url) {
    if (url == null) return;
    final uri = Uri.tryParse(url.toString());
    if (uri == null || !mounted) return;
    setState(() {
      _currentUri = uri;
      _loadError = null;
    });
  }

  Future<NavigationActionPolicy> _allowNavigation(WebUri? url) async {
    final uri = url == null ? null : Uri.tryParse(url.toString());
    if (uri == null || uri.scheme != 'https') {
      if (mounted) {
        setState(() => _loadError = '仅允许打开 HTTPS 网站');
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) => showAcoConfirmDialog(
    context: context,
    title: title,
    message: message,
    confirmLabel: action,
    contentPadding: const EdgeInsets.only(top: 12),
  );
}

Uri _normalizeDappUri(String value) {
  final trimmed = value.trim();
  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  return Uri.tryParse(withScheme) ?? Uri.parse('https://invalid.local');
}

bool _isEvmNetwork(WalletNetwork network) =>
    WalletChainRegistry.chains[network]?.isEvm ?? false;

String _evmChainId(WalletNetwork network) => switch (network) {
  WalletNetwork.ethereum => '0x1',
  WalletNetwork.bsc => '0x38',
  WalletNetwork.polygon => '0x89',
  WalletNetwork.arbitrum => '0xa4b1',
  WalletNetwork.optimism => '0xa',
  WalletNetwork.base => '0x2105',
  _ => throw ArgumentError.value(network, 'network', '不是 EVM 网络'),
};

Map<String, dynamic> _providerResult(Object? result) => {'result': result};

Map<String, dynamic> _providerError(int code, String message) => {
  'error': {'code': code, 'message': message},
};

List<int>? _evmMessageBytes(String value) {
  if (!value.startsWith('0x')) return utf8.encode(value);
  final hex = value.substring(2);
  if (hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex)) return null;
  return [
    for (var index = 0; index < hex.length; index += 2)
      int.parse(hex.substring(index, index + 2), radix: 16),
  ];
}

List<int>? _base64Bytes(String value) {
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}

String _messagePreview(List<int> message) {
  const previewBytes = 16;
  final preview = message
      .take(previewBytes)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  final suffix = message.length > previewBytes ? '…' : '';
  return '0x$preview$suffix（${message.length} 字节）';
}

BigInt? _parseHexInteger(Object value) {
  if (value is! String || !value.startsWith('0x')) return null;
  final digits = value.substring(2);
  if (digits.isEmpty || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(digits)) {
    return null;
  }
  return BigInt.tryParse(digits, radix: 16);
}

String _weiToDecimal(BigInt value) {
  final unit = BigInt.from(10).pow(18);
  final whole = value ~/ unit;
  final fraction = (value % unit)
      .toString()
      .padLeft(18, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}

String _shortAddress(String address) => address.length < 14
    ? address
    : '${address.substring(0, 8)}…${address.substring(address.length - 6)}';

class _Erc20Call {
  const _Erc20Call({
    required this.token,
    required this.recipient,
    required this.amount,
    required this.isApproval,
    required this.data,
  });

  final WalletTokenDefinition token;
  final String recipient;
  final BigInt amount;
  final bool isApproval;
  final List<int> data;

  bool get isUnlimited => amount == (BigInt.one << 256) - BigInt.one;
}

_Erc20Call? _parseSupportedTokenCall({
  required String contract,
  required String data,
  required WalletNetwork network,
}) {
  final chain = WalletChainRegistry.chains[network];
  final candidates = [
    chain?.usdt,
    chain?.usdc,
  ].whereType<WalletTokenDefinition>();
  final token = candidates.where(
    (item) => item.address.toLowerCase() == contract.toLowerCase(),
  );
  if (token.length != 1 || !RegExp(r'^0x[0-9a-fA-F]{136}$').hasMatch(data)) {
    return null;
  }
  final selector = data.substring(2, 10).toLowerCase();
  if (selector != 'a9059cbb' && selector != '095ea7b3') return null;
  final recipient = '0x${data.substring(34, 74)}';
  final amount = BigInt.parse(data.substring(74), radix: 16);
  return _Erc20Call(
    token: token.single,
    recipient: recipient,
    amount: amount,
    isApproval: selector == '095ea7b3',
    data: _evmMessageBytes(data)!,
  );
}

String _baseUnitsToDecimal(BigInt value, int decimals) {
  final unit = BigInt.from(10).pow(decimals);
  final whole = value ~/ unit;
  final fraction = (value % unit)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}

String _lamportsToSol(BigInt lamports) => _baseUnitsToDecimal(lamports, 9);

final _dappStorageUserScript = UserScript(
  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  forMainFrameOnly: true,
  source: '''
(() => {
  if (!window.flutter_inappwebview) return;
  const origin = window.location.origin;
  const snapshot = () => {
    const data = {};
    for (let index = 0; index < window.localStorage.length; index += 1) {
      const key = window.localStorage.key(index);
      if (key !== null) data[key] = window.localStorage.getItem(key);
    }
    return window.flutter_inappwebview.callHandler(
      'acoDappStorageSet',
      {origin, data},
    ).catch(() => null);
  };
  const restore = async () => {
    try {
      const saved = await window.flutter_inappwebview.callHandler(
        'acoDappStorageGet',
        origin,
      );
      if (saved && typeof saved === 'object') {
        Object.keys(saved).forEach((key) => {
          if (window.localStorage.getItem(key) === null) {
            window.localStorage.setItem(key, saved[key]);
          }
        });
      }
    } catch (_) {}
    window.localStorage.addEventListener?.('storage', snapshot);
    const originalSetItem = window.localStorage.setItem.bind(window.localStorage);
    const originalRemoveItem = window.localStorage.removeItem.bind(window.localStorage);
    window.localStorage.setItem = (...args) => {
      originalSetItem(...args);
      snapshot();
    };
    window.localStorage.removeItem = (...args) => {
      originalRemoveItem(...args);
      snapshot();
    };
    snapshot();
    window.setInterval(snapshot, 1000);
    window.addEventListener('beforeunload', snapshot);
  };
  restore();
})();
''',
);

final _evmProviderUserScript = UserScript(
  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  forMainFrameOnly: true,
  source: '''
(() => {
  if (window.ethereum || !window.flutter_inappwebview) return;
  const listeners = {};
  const emit = (event, value) => (listeners[event] || []).forEach((listener) => listener(value));
  const provider = {
    isAco: true,
    isMetaMask: false,
    chainId: null,
    selectedAddress: null,
    request: ({method, params = []}) => window.flutter_inappwebview.callHandler(
      'acoDappProvider', JSON.stringify({method, params})
    ).then((response) => {
      if (response && response.error) return Promise.reject(response.error);
      if (response && response.chainId) {
        provider.chainId = response.chainId;
        emit('chainChanged', response.chainId);
      }
      if (method === 'eth_requestAccounts' && response && response.result) {
        provider.selectedAddress = response.result[0] || null;
        emit('accountsChanged', response.result);
      }
      return response ? response.result : null;
    }),
    enable: () => provider.request({method: 'eth_requestAccounts'}),
    on: (event, listener) => { (listeners[event] ||= []).push(listener); return provider; },
    removeListener: (event, listener) => {
      listeners[event] = (listeners[event] || []).filter((item) => item !== listener);
      return provider;
    },
    send: (methodOrPayload, params) => typeof methodOrPayload === 'string'
      ? provider.request({method: methodOrPayload, params: params || []})
      : provider.request(methodOrPayload),
    sendAsync: (payload, callback) => provider.request(payload).then(
      (result) => callback(null, {id: payload.id, jsonrpc: '2.0', result}),
      (error) => callback(error, {id: payload.id, jsonrpc: '2.0', error})
    ),
  };
  Object.defineProperty(window, 'ethereum', {value: provider, configurable: false});
  window.dispatchEvent(new Event('ethereum#initialized'));
})();
''',
);

final _solanaProviderUserScript = UserScript(
  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  forMainFrameOnly: true,
  source: '''
(() => {
  if (window.solana || !window.flutter_inappwebview) return;
  const listeners = {};
  const emit = (event, value) => (listeners[event] || []).forEach((listener) => listener(value));
  const toBase64 = (bytes) => {
    let binary = '';
    new Uint8Array(bytes).forEach((byte) => binary += String.fromCharCode(byte));
    return btoa(binary);
  };
  const fromBase64 = (value) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
  const publicKey = (value) => ({
    toString: () => value,
    toBase58: () => value,
  });
  const provider = {
    isPhantom: true,
    publicKey: null,
    isConnected: false,
    connect: (options = {}) => window.flutter_inappwebview.callHandler(
      'acoSolanaProvider', JSON.stringify({method: 'connect', params: options})
    ).then((response) => {
      if (response && response.error) return Promise.reject(response.error);
      provider.publicKey = publicKey(response.result.publicKey);
      provider.isConnected = true;
      emit('connect', provider.publicKey);
      return {publicKey: provider.publicKey};
    }),
    disconnect: () => {
      provider.publicKey = null;
      provider.isConnected = false;
      emit('disconnect');
      return window.flutter_inappwebview.callHandler(
        'acoSolanaProvider', JSON.stringify({method: 'disconnect', params: {}})
      );
    },
    signMessage: (message, display) => window.flutter_inappwebview.callHandler(
      'acoSolanaProvider', JSON.stringify({
        method: 'signMessage',
        params: {message: toBase64(message), display: display || 'utf8'}
      })
    ).then((response) => {
      if (response && response.error) return Promise.reject(response.error);
      return {
        signature: fromBase64(response.result.signature),
        publicKey: publicKey(response.result.publicKey),
      };
    }),
    signTransaction: (transaction) => window.flutter_inappwebview.callHandler(
      'acoSolanaProvider', JSON.stringify({
        method: 'signTransaction',
        params: {transaction: toBase64(transaction.serialize())}
      })
    ).then((response) => {
      if (response && response.error) return Promise.reject(response.error);
      // The returned bytes can be reconstructed by Solana web3.js callers.
      // We deliberately do not mutate an unknown transaction object here.
      return fromBase64(response.result.transaction);
    }),
    signAllTransactions: (transactions) => Promise.reject({code: 4200, message: 'Solana 交易解析正在接入'}),
    signAndSendTransaction: (transaction, options) => Promise.reject({code: 4200, message: 'Solana 交易解析正在接入'}),
    on: (event, listener) => { (listeners[event] ||= []).push(listener); return provider; },
    removeListener: (event, listener) => {
      listeners[event] = (listeners[event] || []).filter((item) => item !== listener);
      return provider;
    },
  };
  Object.defineProperty(window, 'solana', {value: provider, configurable: false});
  window.phantom = window.phantom || {};
  window.phantom.solana = provider;
})();
''',
);
