part of 'aco_design_shell.dart';

Future<({String symbol, int decimals})> _readTokenMetadata({
  required WalletNetwork network,
  required String address,
  WalletIdentity? identity,
}) async {
  final tokens = await SecureAccountTokenStore().read();
  if (tokens == null) throw StateError('未登录');

  final rpc = WalletRpcClient(
    client: http.Client(),
    directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
    ownsClient: true,
  );
  try {
    final endpoints = await rpc.loadEndpoints(
      network: network.name,
      accessToken: tokens.accessToken,
    );
    final owner = network == WalletNetwork.tron && identity != null
        ? (await WalletPreferences.derivedAddresses(identity))['tron']
        : null;
    return await WalletTokenMetadataReader(rpc).load(
      network: network,
      address: address,
      endpoints: endpoints,
      ownerAddress: owner,
    );
  } finally {
    rpc.close();
  }
}

class _ReceivePage extends StatefulWidget {
  const _ReceivePage({
    required this.palette,
    required this.walletIdentity,
    required this.selectedChain,
  });

  final AcoPalette palette;
  final WalletIdentity? walletIdentity;
  final _WalletChain selectedChain;

  @override
  State<_ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<_ReceivePage> {
  late Future<String?> _addressFuture;

  @override
  void initState() {
    super.initState();
    _addressFuture = _addressForChain(
      widget.walletIdentity,
      widget.selectedChain,
    );
  }

  @override
  void didUpdateWidget(covariant _ReceivePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletIdentity != widget.walletIdentity ||
        oldWidget.selectedChain.network != widget.selectedChain.network) {
      _addressFuture = _addressForChain(
        widget.walletIdentity,
        widget.selectedChain,
      );
    }
  }

  String get _networkNotice => switch (widget.selectedChain.network) {
    WalletNetwork.ethereum => '仅向该地址转入 Ethereum/ERC20 相关资产',
    WalletNetwork.bsc => '仅向该地址转入 BSC/BEP20 相关资产',
    WalletNetwork.polygon => '仅向该地址转入 Polygon 相关资产',
    WalletNetwork.arbitrum => '仅向该地址转入 Arbitrum One 相关资产',
    WalletNetwork.optimism => '仅向该地址转入 Optimism 相关资产',
    WalletNetwork.tron => '仅向该地址转入 TRON/TRC20 相关资产',
    WalletNetwork.solana => '仅向该地址转入 Solana 相关资产',
    WalletNetwork.base => '仅向该地址转入 Base 相关资产',
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _addressFuture,
    builder: (_, snapshot) => _ReceivePageContent(
      palette: widget.palette,
      walletAddress: snapshot.data,
      networkNotice: _networkNotice,
      networkLabel: widget.selectedChain.label,
    ),
  );
}

class _ReceivePageContent extends StatelessWidget {
  const _ReceivePageContent({
    required this.palette,
    required this.walletAddress,
    required this.networkNotice,
    required this.networkLabel,
  });

  final AcoPalette palette;
  final String? walletAddress;
  final String networkNotice;
  final String networkLabel;

  bool get _hasWalletAddress =>
      walletAddress != null && walletAddress!.trim().isNotEmpty;

  Future<void> _copyAddress(BuildContext context) async {
    final address = walletAddress;
    if (address == null || address.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      _showNotice(context, '已复制', '钱包地址已复制到剪贴板。');
    }
  }

  Future<void> _shareAddress() async {
    final address = walletAddress;
    if (address == null || address.isEmpty) return;

    await SharePlus.instance.share(
      ShareParams(text: '我的 $networkLabel 收款地址：$address'),
    );
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '收款',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.info_circle,
              color: palette.mutedText,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              networkNotice,
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 240,
            height: 240,
            key: const Key('receive-qr-surface'),
            color: _white,
            child: _hasWalletAddress
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: walletAddress!,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        size: 240,
                        padding: const EdgeInsets.all(8),
                        backgroundColor: _white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: _black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: _black,
                        ),
                        semanticsLabel: '收款二维码：$walletAddress',
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: _white,
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/crypto/tokens/usdt.svg',
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Text(
                      '钱包地址未就绪',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: AcoTypography.body,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          '收款地址',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              walletAddress ?? '钱包地址未就绪',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.mutedText, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ReceiveAction(
              palette: palette,
              icon: CupertinoIcons.share,
              label: '分享',
              onPressed: _hasWalletAddress ? _shareAddress : null,
            ),
            _ReceiveAction(
              palette: palette,
              icon: CupertinoIcons.doc_on_doc,
              label: '复制',
              onPressed: _hasWalletAddress ? () => _copyAddress(context) : null,
            ),
            _ReceiveAction(
              palette: palette,
              icon: CupertinoIcons.gear_alt,
              label: '设置数额',
              onPressed: () => _showNotice(context, '设置数额', '收款数额设置即将开放。'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage({required this.palette, this.currentAccountId});

  final AcoPalette palette;
  final String? currentAccountId;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _controller = MobileScannerController();
  final _accountSession = AccountSession(AccountApiClient());
  String? _result;
  AccountProfile? _profile;
  String? _error;
  bool _addingFriend = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_result != null || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    await _controller.stop();
    if (!mounted) return;
    final groupInviteCode = _groupInviteCodeFromQr(value);
    if (groupInviteCode != null) {
      setState(() => _result = value);
      try {
        await _accountSession.joinGroupByCode(groupInviteCode);
        if (!mounted) return;
        _showNotice(context, '已加入群聊', '请在消息列表中查看群聊。');
        Navigator.of(context).pop();
      } on AccountApiException catch (error) {
        if (mounted) setState(() => _error = error.localizedMessage);
      } on StateError {
        if (mounted) setState(() => _error = '请先登录后再加入群聊。');
      }
      return;
    }
    final accountId = _profileAccountIdFromQr(value);
    if (accountId == null) {
      setState(() {
        _result = value;
        _error = '该二维码不是 Aco 个人二维码。';
      });
      return;
    }
    if (accountId == widget.currentAccountId) {
      setState(() {
        _result = value;
        _error = '不能添加自己为好友。';
      });
      return;
    }
    setState(() => _result = value);
    try {
      final profile = await _accountSession.profileByAccountId(accountId);
      if (mounted) setState(() => _profile = profile);
    } on AccountApiException catch (error) {
      if (mounted) setState(() => _error = error.localizedMessage);
    } on StateError {
      if (mounted) setState(() => _error = '请先登录后再添加好友。');
    }
  }

  Future<void> _continueScanning() async {
    setState(() {
      _result = null;
      _profile = null;
      _error = null;
    });
    await _controller.start();
  }

  Future<void> _addFriend() async {
    final profile = _profile;
    if (profile == null || _addingFriend) return;
    setState(() => _addingFriend = true);
    try {
      await _accountSession.addFriend(profile.accountId);
      if (!mounted) return;
      setState(() {
        _result = null;
        _profile = null;
        _error = null;
      });
      await _controller.start();
      if (!mounted) return;
      _showNotice(context, '好友申请已发送', '已向 ${profile.nickname} 发送好友申请。');
    } on AccountApiException catch (error) {
      if (mounted) setState(() => _error = error.localizedMessage);
    } on StateError {
      if (mounted) setState(() => _error = '请先登录后再添加好友。');
    } finally {
      if (mounted) setState(() => _addingFriend = false);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MobileScanner(
        controller: _controller,
        onDetect: _handleCapture,
        errorBuilder: (_, _) => ColoredBox(
          color: widget.palette.background,
          child: Center(
            child: Text(
              '无法打开相机',
              style: TextStyle(
                color: widget.palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: (widget.palette.dark ? _black : _white).withValues(
            alpha: widget.palette.dark ? .38 : .76,
          ),
        ),
      ),
      AcoSafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
              child: AcoPageHeader(
                palette: widget.palette,
                title: '扫一扫',
                backButtonKey: const Key('scan-back-button'),
                backButtonOffset: Offset.zero,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            const Spacer(flex: 3),
            Container(
              key: const ValueKey('scan-frame'),
              width: 248,
              height: 248,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.palette.dark
                      ? _lime
                      : widget.palette.primaryText,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Align(
                alignment: Alignment.center,
                child: Container(width: 64, height: 2, color: _lime),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '将二维码放入框内，即可自动扫描',
              style: TextStyle(
                color: widget.palette.primaryText,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
            const Spacer(flex: 2),
            if (_result case final value?)
              _ScanResult(
                palette: widget.palette,
                value: value,
                profile: _profile,
                error: _error,
                addingFriend: _addingFriend,
                onAddFriend: _addFriend,
                onContinue: _continueScanning,
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _ScanControl(
                  palette: widget.palette,
                  icon: CupertinoIcons.bolt_fill,
                  label: '闪光灯',
                  onPressed: _controller.toggleTorch,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ScanControl extends StatelessWidget {
  const _ScanControl({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final AcoPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: SizedBox(
      width: 84,
      child: Column(
        children: [
          Icon(icon, color: palette.primaryText, size: 25),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({
    required this.palette,
    required this.value,
    required this.profile,
    required this.error,
    required this.addingFriend,
    required this.onAddFriend,
    required this.onContinue,
  });

  final AcoPalette palette;
  final String value;
  final AccountProfile? profile;
  final String? error;
  final bool addingFriend;
  final VoidCallback onAddFriend;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          profile == null ? '已识别二维码' : '添加好友',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (profile case final friend?) ...[
          AcoAvatar(size: 56, imageUrl: friend.avatarUrl),
          const SizedBox(height: 10),
          Text(
            friend.nickname,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodyEmphasis,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${friend.username}',
            style: TextStyle(color: palette.mutedText),
          ),
        ] else
          Text(
            error == null ? value : error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.mutedText),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: 280,
          child: profile != null && error == null
              ? AcoLimeButton(
                  label: addingFriend ? '发送中…' : '添加好友',
                  onPressed: addingFriend ? () {} : onAddFriend,
                  backgroundColor: palette.accent,
                )
              : AcoLimeButton(
                  label: '继续扫描',
                  onPressed: onContinue,
                  backgroundColor: palette.accent,
                ),
        ),
        if (profile != null && error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: palette.mutedText)),
        ],
      ],
    ),
  );
}

String? _profileAccountIdFromQr(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'aco' || uri.host != 'profile') {
    return null;
  }
  final accountId = uri.queryParameters['uid']?.trim();
  return accountId == null || accountId.isEmpty ? null : accountId;
}

String? _groupInviteCodeFromQr(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'aco' || uri.host != 'group') return null;
  final segments = uri.pathSegments;
  if (segments.length != 2 || segments.first != 'join') return null;
  final code = segments.last.trim();
  return code.isEmpty ? null : code;
}

class _ReceiveAction extends StatelessWidget {
  const _ReceiveAction({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final AcoPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: SizedBox(
      width: 64,
      child: Column(
        children: [
          Icon(icon, color: palette.mutedText, size: 26),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddTokenPage extends StatefulWidget {
  const _AddTokenPage({
    required this.palette,
    required this.selectedChain,
    this.walletIdentity,
  });
  final AcoPalette palette;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;

  @override
  State<_AddTokenPage> createState() => _AddTokenPageState();
}

class _AddTokenPageState extends State<_AddTokenPage> {
  late final WalletMetadataStore _metadataStore = WalletMetadataStore();
  late final WalletHotTokenService _hotTokenService = WalletHotTokenService();
  late List<WalletBalance> _tokens = _defaultTokens();
  late Future<List<WalletHotToken>> _hotTokensFuture;
  final Set<String> _removed = {};
  final Set<String> _addedAddresses = {};
  final Set<String> _addingAddresses = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _hotTokensFuture = _hotTokenService.load(widget.selectedChain.network.name);
    unawaited(_loadAddedTokens());
    final identity = widget.walletIdentity;
    if (identity != null) {
      _metadataStore
          .hiddenTokenSymbols(identity, widget.selectedChain.network.name)
          .then((symbols) {
            if (mounted) setState(() => _removed.addAll(symbols));
          });
    }
  }

  @override
  void didUpdateWidget(covariant _AddTokenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChain.network != widget.selectedChain.network) {
      setState(() {
        _tokens = _defaultTokens();
        _searchQuery = '';
        _addedAddresses.clear();
        _addingAddresses.clear();
        _hotTokensFuture = _hotTokenService.load(
          widget.selectedChain.network.name,
        );
      });
      unawaited(_loadAddedTokens());
    }
  }

  Future<void> _loadAddedTokens() async {
    final identity = widget.walletIdentity;
    if (identity == null) return;
    final network = widget.selectedChain.network.name;
    final tokens = await _metadataStore.customTokens(identity);
    if (!mounted || widget.selectedChain.network.name != network) return;
    setState(() {
      _addedAddresses.addAll(
        tokens
            .where((token) => token.network == network)
            .map((token) => token.address.toLowerCase()),
      );
    });
  }

  Widget _hotTokenRow(WalletHotToken token) => _AddTokenHotRow(
    token: token,
    palette: widget.palette,
    added: _isAdded(token),
    loading: _addingAddresses.contains(token.address.toLowerCase()),
    onPressed: () => _addHotToken(token),
  );

  bool _isAdded(WalletHotToken token) {
    final address = token.address.toLowerCase();
    if (_addedAddresses.contains(address)) return true;
    return _tokens.any(
      (asset) =>
          asset.tokenAddress?.toLowerCase() == address &&
          !_removed.contains(address) &&
          !_removed.contains(asset.symbol),
    );
  }

  Future<void> _addHotToken(WalletHotToken token) async {
    final identity = widget.walletIdentity;
    if (identity == null) {
      _showNotice(context, '添加失败', '请先创建或导入钱包。');
      return;
    }
    final network = widget.selectedChain.network;
    final address = token.address.trim();
    final key = address.toLowerCase();
    if (_addingAddresses.contains(key)) return;
    if (_isAdded(token)) {
      _showNotice(context, '已添加', '${token.symbol} 已在资产列表中。');
      return;
    }
    if (!WalletTokenMetadataReader.validAddress(network, address)) {
      _showNotice(context, '添加失败', '代币地址无效。');
      return;
    }
    setState(() => _addingAddresses.add(key));
    try {
      final builtIn = _tokens.where(
        (asset) => asset.tokenAddress?.toLowerCase() == key,
      );
      if (builtIn.isNotEmpty) {
        await _metadataStore.setTokenHidden(
          identity,
          network.name,
          builtIn.first.symbol,
          false,
          tokenAddress: address,
        );
        await _metadataStore.setTokenHidden(
          identity,
          network.name,
          builtIn.first.symbol,
          false,
        );
        if (mounted && widget.selectedChain.network == network) {
          setState(() => _removed.removeAll({key, builtIn.first.symbol}));
        }
      } else {
        final metadata = await _readTokenMetadata(
          network: network,
          address: address,
          identity: identity,
        );
        await _metadataStore.saveCustomToken(
          identity,
          CustomTokenDefinition(
            network: network.name,
            address: address,
            symbol: metadata.symbol.toUpperCase(),
            decimals: metadata.decimals,
          ),
        );
        if (mounted && widget.selectedChain.network == network) {
          setState(() => _addedAddresses.add(key));
        }
      }
      if (mounted) {
        _showNotice(context, '添加成功', '${token.symbol} 已添加至资产列表。');
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, '添加失败', '无法读取代币信息，请稍后重试。');
      }
    } finally {
      if (mounted) setState(() => _addingAddresses.remove(key));
    }
  }

  List<WalletBalance> _defaultTokens() {
    final chain = WalletChainRegistry.chains[widget.selectedChain.network]!;
    return [
      WalletBalance(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: widget.walletIdentity?.address ?? '',
        decimals: chain.decimals,
      ),
      if (chain.usdt != null)
        WalletBalance(
          chain: chain.name,
          symbol: chain.usdt!.symbol,
          assetName: chain.usdt!.name,
          isNative: false,
          address: widget.walletIdentity?.address ?? '',
          decimals: chain.usdt!.decimals,
          tokenAddress: chain.usdt!.address,
        ),
      if (chain.usdc != null)
        WalletBalance(
          chain: chain.name,
          symbol: chain.usdc!.symbol,
          assetName: chain.usdc!.name,
          isNative: false,
          address: widget.walletIdentity?.address ?? '',
          decimals: chain.usdc!.decimals,
          tokenAddress: chain.usdc!.address,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '添加代币',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(27, 12, 27, 26),
      children: [
        _AddTokenSearch(
          palette: widget.palette,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
          onSubmit: _searchContract,
        ),
        const SizedBox(height: 30),
        if (_searchQuery.isNotEmpty) ...[
          for (final token in _tokens.where(_matchesToken))
            _hotTokenRow(
              WalletHotToken(
                symbol: token.symbol,
                name: token.assetName,
                address: token.tokenAddress ?? '',
                decimals: token.decimals,
              ),
            ),
          if (!_tokens.any(_matchesToken))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '暂无匹配代币',
                textAlign: TextAlign.center,
                style: TextStyle(color: widget.palette.mutedText),
              ),
            ),
          const SizedBox(height: 12),
        ],
        _AddTokenEntry(
          label: '首页资产',
          palette: widget.palette,
          onPressed: () => Navigator.of(context).push(
            _AcoPageRoute(
              builder: (_) => _HomeAssetPage(
                palette: widget.palette,
                tokens: _tokens,
                removed: _removed,
                onRemove: _removeToken,
              ),
            ),
          ),
        ),
        _AddTokenEntry(
          label: '自定义代币',
          palette: widget.palette,
          onPressed: () async {
            final added = await Navigator.of(context).push<bool>(
              _AcoPageRoute(
                builder: (_) => _CustomTokenPage(
                  palette: widget.palette,
                  selectedChain: widget.selectedChain,
                  walletIdentity: widget.walletIdentity,
                ),
              ),
            );
            if (added == true && context.mounted) {
              await _loadAddedTokens();
              if (!context.mounted) return;
              _showNotice(context, '添加成功', '自定义代币已添加至资产列表。');
            }
          },
        ),
        const SizedBox(height: 12),
        Text(
          '热门代币',
          style: TextStyle(
            color: widget.palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<WalletHotToken>>(
          key: ValueKey(widget.selectedChain.network),
          future: _hotTokensFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CupertinoActivityIndicator(),
              );
            }
            final query = _searchQuery;
            final tokens = (snapshot.data ?? const <WalletHotToken>[]).where((
              token,
            ) {
              if (query.isEmpty) return true;
              return token.address.toLowerCase() == query;
            });
            return Column(
              children: [for (final token in tokens) _hotTokenRow(token)],
            );
          },
        ),
      ],
    ),
  );

  bool _matchesToken(WalletBalance token) {
    final query = _searchQuery;
    return token.tokenAddress?.toLowerCase() == query;
  }

  Future<void> _searchContract() async {
    final address = _searchQuery.trim();
    if (address.isEmpty) return;
    final added = await Navigator.of(context).push<bool>(
      _AcoPageRoute(
        builder: (_) => _CustomTokenPage(
          palette: widget.palette,
          selectedChain: widget.selectedChain,
          walletIdentity: widget.walletIdentity,
          initialContract: address,
        ),
      ),
    );
    if (added == true && mounted) await _loadAddedTokens();
  }

  Future<void> _removeToken(WalletBalance token) async {
    if (token.isNative) return;
    setState(() => _removed.add(token.symbol));
    final identity = widget.walletIdentity;
    if (identity != null) {
      await _metadataStore.setTokenHidden(
        identity,
        widget.selectedChain.network.name,
        token.symbol,
        true,
        tokenAddress: token.tokenAddress,
      );
    }
  }
}

/// Form for importing a token that is not included in the default token list.
class _CustomTokenPage extends StatefulWidget {
  const _CustomTokenPage({
    required this.palette,
    required this.selectedChain,
    this.walletIdentity,
    this.initialContract,
  });

  final AcoPalette palette;
  final _WalletChain selectedChain;
  final WalletIdentity? walletIdentity;
  final String? initialContract;

  @override
  State<_CustomTokenPage> createState() => _CustomTokenPageState();
}

class _CustomTokenPageState extends State<_CustomTokenPage> {
  final _contractController = TextEditingController();
  final _symbolController = TextEditingController();
  final _decimalsController = TextEditingController();
  final _contractFocus = FocusNode();
  Timer? _lookupDebounce;
  int _lookupGeneration = 0;
  String _lastContract = '';
  String? _resolvedAddress;
  String? _lookupError;
  bool _saving = false;
  bool _loadingMetadata = false;

  bool get _canSubmit {
    final decimals = int.tryParse(_decimalsController.text.trim());
    return !_saving &&
        !_loadingMetadata &&
        _resolvedAddress == _contractController.text.trim() &&
        _symbolController.text.trim().isNotEmpty &&
        decimals != null &&
        decimals >= 0 &&
        decimals <= 36;
  }

  @override
  void initState() {
    super.initState();
    _contractController.addListener(_contractChanged);
    final initialContract = widget.initialContract;
    if (initialContract != null && initialContract.isNotEmpty) {
      _contractController.text = initialContract;
    }
  }

  void _contractChanged() {
    final address = _contractController.text.trim();
    if (address == _lastContract) return;
    _lastContract = address;
    final generation = ++_lookupGeneration;
    _lookupDebounce?.cancel();
    _symbolController.clear();
    _decimalsController.clear();
    setState(() {
      _resolvedAddress = null;
      _lookupError = null;
      _loadingMetadata = false;
    });
    if (WalletTokenMetadataReader.validAddress(
      widget.selectedChain.network,
      address,
    )) {
      _lookupDebounce = Timer(
        const Duration(milliseconds: 350),
        () => _lookupTokenMetadata(address, generation),
      );
    }
  }

  Future<void> _lookupTokenMetadata(String address, int generation) async {
    if (generation != _lookupGeneration) {
      return;
    }
    setState(() => _loadingMetadata = true);
    try {
      final metadata = await _readTokenMetadata(
        network: widget.selectedChain.network,
        address: address,
        identity: widget.walletIdentity,
      );
      if (mounted && generation == _lookupGeneration) {
        _symbolController.text = metadata.symbol;
        _decimalsController.text = metadata.decimals.toString();
        setState(() => _resolvedAddress = address);
      }
    } catch (_) {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _lookupError = '无法获取代币信息，请检查合约地址后重试');
      }
    } finally {
      if (mounted && generation == _lookupGeneration) {
        setState(() => _loadingMetadata = false);
      }
    }
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _contractController.dispose();
    _symbolController.dispose();
    _decimalsController.dispose();
    _contractFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final definition = CustomTokenDefinition(
      network: widget.selectedChain.network.name,
      address: _contractController.text.trim(),
      symbol: _symbolController.text.trim().toUpperCase(),
      decimals: int.parse(_decimalsController.text.trim()),
    );
    if (widget.walletIdentity != null) {
      await WalletMetadataStore().saveCustomToken(
        widget.walletIdentity!,
        definition,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _retryLookup() {
    if (_loadingMetadata) return;
    final address = _contractController.text.trim();
    _lookupDebounce?.cancel();
    final generation = ++_lookupGeneration;
    if (WalletTokenMetadataReader.validAddress(
      widget.selectedChain.network,
      address,
    )) {
      setState(() => _lookupError = null);
      unawaited(_lookupTokenMetadata(address, generation));
    }
  }

  Widget _field({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    FocusNode? focusNode,
    bool readOnly = false,
    TextInputAction? textInputAction,
    VoidCallback? onSubmitted,
    Key? key,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final fieldHeight = (constraints.maxWidth * .14).clamp(54.0, 64.0);
      final horizontalPadding = (constraints.maxWidth * .07).clamp(18.0, 26.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: widget.palette.primaryText, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Container(
            height: fieldHeight,
            decoration: BoxDecoration(
              color: widget.palette.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: key,
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly,
                    enableInteractiveSelection: !readOnly,
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(color: _transparent),
                    placeholder: placeholder,
                    placeholderStyle: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 16,
                    ),
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: 16,
                    ),
                    textInputAction: textInputAction,
                    onSubmitted: onSubmitted == null
                        ? null
                        : (_) => onSubmitted(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: widget.palette.background,
    child: AcoSafeAreaPage(
      backgroundColor: widget.palette.background,
      applyTopSafeArea: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
            child: AcoPageHeader(
              palette: widget.palette,
              title: '添加代币',
              backButtonOffset: Offset.zero,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              children: [
                _field(
                  label: '代币合约',
                  placeholder: '请输入代币合约地址',
                  controller: _contractController,
                  focusNode: _contractFocus,
                  key: const Key('custom-token-contract-field'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _retryLookup,
                ),
                if (_loadingMetadata || _lookupError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _loadingMetadata ? '正在获取代币信息...' : _lookupError!,
                    style: TextStyle(
                      color: _lookupError == null
                          ? widget.palette.mutedText
                          : _danger,
                      fontSize: 13,
                    ),
                  ),
                  if (_lookupError != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: _retryLookup,
                      child: const Text('重新获取'),
                    ),
                ],
                const SizedBox(height: 20),
                _field(
                  label: '代币符号',
                  placeholder: '自动获取代币符号',
                  controller: _symbolController,
                  readOnly: true,
                  key: const Key('custom-token-symbol-field'),
                ),
                const SizedBox(height: 20),
                _field(
                  label: '代币精度',
                  placeholder: '自动获取代币精度',
                  controller: _decimalsController,
                  readOnly: true,
                  key: const Key('custom-token-decimals-field'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
            child: SizedBox(
              height: 54,
              width: double.infinity,
              child: CupertinoButton(
                key: const Key('custom-token-confirm-button'),
                padding: EdgeInsets.zero,
                onPressed: _canSubmit ? _submit : null,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _canSubmit
                        ? widget.palette.accent
                        : widget.palette.accent.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _saving
                      ? CupertinoActivityIndicator(
                          color: widget.palette.dark ? _black : _white,
                        )
                      : Text(
                          '确认',
                          style: TextStyle(
                            color: widget.palette.dark ? _black : _white,
                            fontSize: 22,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HomeAssetPage extends StatefulWidget {
  const _HomeAssetPage({
    required this.palette,
    required this.tokens,
    required this.removed,
    required this.onRemove,
  });
  final AcoPalette palette;
  final List<WalletBalance> tokens;
  final Set<String> removed;
  final ValueChanged<WalletBalance> onRemove;

  @override
  State<_HomeAssetPage> createState() => _HomeAssetPageState();
}

class _HomeAssetPageState extends State<_HomeAssetPage> {
  late final Set<String> _removed = {...widget.removed};

  @override
  Widget build(BuildContext context) => AcoSafeAreaPage(
    backgroundColor: widget.palette.background,
    applyTopSafeArea: true,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
          child: AcoPageHeader(
            palette: widget.palette,
            title: '首页资产',
            backButtonOffset: Offset.zero,
            onBack: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 26),
            children: [
              for (final token in widget.tokens)
                if (!_isRemoved(token))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(27, 10, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _WalletAssetIcon(symbol: token.symbol),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                token.symbol,
                                style: TextStyle(
                                  color: widget.palette.primaryText,
                                ),
                              ),
                              Text(
                                token.assetName,
                                style: TextStyle(
                                  color: widget.palette.mutedText,
                                ),
                              ),
                              if (token.tokenAddress != null)
                                Text(
                                  _breakAddress(token.tokenAddress!),
                                  style: TextStyle(
                                    color: widget.palette.mutedText,
                                    fontSize: 12,
                                  ),
                                  softWrap: true,
                                ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: token.isNative
                              ? null
                              : () {
                                  setState(() => _removed.add(token.symbol));
                                  widget.onRemove(token);
                                },
                          child: Icon(
                            CupertinoIcons.minus_circle_fill,
                            color: token.isNative
                                ? widget.palette.mutedText
                                : _danger,
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

  String _breakAddress(String address) =>
      '地址: ${address.replaceAllMapped(RegExp(r'(.{8})'), (match) => '${match.group(1)}\u200b')}';

  bool _isRemoved(WalletBalance token) =>
      _removed.contains(token.symbol) ||
      (token.tokenAddress != null &&
          _removed.contains(token.tokenAddress!.toLowerCase()));
}

class _AddTokenSearch extends StatelessWidget {
  const _AddTokenSearch({
    required this.palette,
    required this.onSubmit,
    required this.onChanged,
  });
  final AcoPalette palette;
  final VoidCallback onSubmit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    decoration: BoxDecoration(
      border: Border.all(
        color: palette.dark ? const Color(0xFFC6C6C6) : palette.border,
      ),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Row(
      children: [
        const SizedBox(width: 13),
        Icon(CupertinoIcons.search, color: palette.mutedText, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoTextField(
            padding: EdgeInsets.zero,
            decoration: const BoxDecoration(color: _transparent),
            cursorColor: _lime,
            placeholder: '通过合约地址进行搜索',
            placeholderStyle: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.caption,
            ),
            onChanged: onChanged,
            onSubmitted: (_) {
              _dismissKeyboard();
              onSubmit();
            },
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(50, 38),
          onPressed: onSubmit,
          child: Container(
            width: 50,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFD6D6D6),
              borderRadius: BorderRadius.all(Radius.circular(19)),
            ),
            child: const Icon(
              CupertinoIcons.arrow_right,
              color: _black,
              size: 22,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddTokenEntry extends StatelessWidget {
  const _AddTokenEntry({
    required this.label,
    required this.palette,
    this.onPressed,
  });
  final String label;
  final AcoPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 15),
    onPressed: onPressed ?? () => _showNotice(context, label, '$label列表即将开放。'),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Icon(CupertinoIcons.chevron_right, color: palette.mutedText, size: 18),
      ],
    ),
  );
}

class _AddTokenHotRow extends StatelessWidget {
  const _AddTokenHotRow({
    required this.token,
    required this.palette,
    required this.onPressed,
    this.added = false,
    this.loading = false,
  });
  final WalletHotToken token;
  final AcoPalette palette;
  final VoidCallback onPressed;
  final bool added;
  final bool loading;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 12),
    onPressed: loading ? null : onPressed,
    child: Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: .35)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: _HotTokenIcon(symbol: token.symbol, logoUrl: token.logoUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.symbol,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  token.name,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.caption,
                  ),
                ),
                if (token.address.isNotEmpty)
                  Text(
                    _breakHotTokenAddress(token.address),
                    softWrap: true,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
              ],
            ),
          ),
          if (loading)
            const CupertinoActivityIndicator()
          else
            Icon(
              added
                  ? CupertinoIcons.check_mark_circled
                  : CupertinoIcons.add_circled,
              color: _lime,
              size: 24,
            ),
        ],
      ),
    ),
  );

  String _breakHotTokenAddress(String address) =>
      '地址: ${address.replaceAllMapped(RegExp(r'(.{8})'), (match) => '${match.group(1)}\u200b')}';
}

class _HotTokenIcon extends StatelessWidget {
  const _HotTokenIcon({required this.symbol, this.logoUrl = ''});
  final String symbol;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final normalized = symbol.toUpperCase();
    final asset = switch (normalized) {
      'USDT' => 'assets/icons/crypto/domi/tokens/usdt.png',
      'USDC' => 'assets/icons/crypto/domi/tokens/usdc.png',
      'ALD' => 'assets/icons/crypto/tokens/ald.png',
      _ => null,
    };
    if (asset != null) {
      return ClipOval(child: Image.asset(asset, fit: BoxFit.cover));
    }
    if (logoUrl.startsWith('http://') || logoUrl.startsWith('https://')) {
      final imageUrl = _hotTokenLogoRequestUrl(logoUrl);
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => _letterIcon(normalized),
          errorWidget: (_, _, _) => _letterIcon(normalized),
        ),
      );
    }
    return _letterIcon(normalized);
  }

  Widget _letterIcon(String normalized) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0xFF2680D9),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        normalized.isEmpty ? '?' : normalized.substring(0, 1),
        style: const TextStyle(color: _white, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

String _hotTokenLogoRequestUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      (uri.host != 'cdn.dexscreener.com' && uri.host != 'dd.dexscreener.com')) {
    return value;
  }
  return 'https://img2.ant.fun/md/${base64Url.encode(utf8.encode(value))}';
}
