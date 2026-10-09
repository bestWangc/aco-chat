part of 'aco_design_shell.dart';

class _TokenAvatar extends StatelessWidget {
  const _TokenAvatar({required this.token});

  final TransferToken token;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 35,
    height: 35,
    child: token.iconAsset.endsWith('.png')
        ? ClipOval(
            child: Image.asset(
              token.iconAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _MissingTokenIcon(),
            ),
          )
        : SvgPicture.asset(
            token.iconAsset,
            errorBuilder: (_, _, _) => const _MissingTokenIcon(),
          ),
  );
}

class _SendTokenPicker extends StatefulWidget {
  const _SendTokenPicker({required this.palette, required this.tokens});

  final AcoPalette palette;
  final List<TransferToken> tokens;

  @override
  State<_SendTokenPicker> createState() => _SendTokenPickerState();
}

class _SendTokenPickerState extends State<_SendTokenPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransferToken> get _visibleTokens {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.tokens;
    return widget.tokens
        .where(
          (token) =>
              token.symbol.toLowerCase().contains(query) ||
              token.name.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '选择转账代币',
    child: Align(
      alignment: Alignment.bottomCenter,
      child: AcoSafeArea(
        top: false,
        child: Container(
          key: const Key('send-token-picker'),
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: BoxDecoration(
            color: widget.palette.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(top: BorderSide(color: widget.palette.border)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择转账代币',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.palette.primaryText,
                          fontSize: AcoTypography.title,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: widget.palette.primaryText,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.palette.border),
                  ),
                  child: CupertinoTextField(
                    key: const Key('send-token-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onTapOutside: (_) => _dismissKeyboard(),
                    onSubmitted: (_) => _dismissKeyboard(),
                    placeholder: '搜索代币名称或符号',
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        CupertinoIcons.search,
                        color: widget.palette.mutedText,
                        size: 19,
                      ),
                    ),
                    placeholderStyle: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: AcoTypography.body,
                    ),
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: AcoTypography.body,
                    ),
                    cursorColor: widget.palette.accent,
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(color: _transparent),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _visibleTokens.isEmpty
                    ? Center(
                        child: Text(
                          '未找到代币',
                          style: TextStyle(color: widget.palette.mutedText),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                        itemCount: _visibleTokens.length,
                        separatorBuilder: (_, _) =>
                            Container(height: 1, color: widget.palette.border),
                        itemBuilder: (context, index) {
                          final token = _visibleTokens[index];
                          return Semantics(
                            button: true,
                            label: '选择代币 ${token.symbol}',
                            child: CupertinoButton(
                              key: Key('send-token-${token.symbol}'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              onPressed: () {
                                _dismissKeyboard();
                                Navigator.of(context).pop(token);
                              },
                              child: Row(
                                children: [
                                  _TokenAvatar(token: token),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          token.symbol,
                                          style: TextStyle(
                                            color: widget.palette.primaryText,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          token.name,
                                          style: TextStyle(
                                            color: widget.palette.mutedText,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        token.availableAmount,
                                        style: TextStyle(
                                          color: widget.palette.primaryText,
                                          fontSize: AcoTypography.body,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '可用余额',
                                        style: TextStyle(
                                          color: widget.palette.mutedText,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

class _SendTransferPage extends StatefulWidget {
  const _SendTransferPage({
    required this.palette,
    required this.token,
    this.walletIdentity,
    required this.secretStore,
  });

  final AcoPalette palette;
  final TransferToken token;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore secretStore;

  @override
  State<_SendTransferPage> createState() => _SendTransferPageState();
}

class _SendTransferPageState extends State<_SendTransferPage> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  bool _submitting = false;
  WalletFeeEstimate? _feeEstimate;
  String? _feeError;
  int _estimateGeneration = 0;

  BigInt? get _amountRaw {
    try {
      return BigInt.parse(
        WalletTransferService.decimalToBaseUnits(
          _amountController.text.trim(),
          decimals: widget.token.decimals,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String get _feeLabel {
    final estimate = _feeEstimate;
    if (estimate == null) return _isEvm ? '输入金额后估算' : '暂不支持';
    return '${formatChainAmount(estimate.feeWei, decimals: 18)} ${widget.token.feeSymbol}';
  }

  String get _feeDescription {
    final error = _feeError;
    if (error != null) return error;
    return _isEvm ? '网络费已通过当前 RPC 估算' : '该公链转账功能正在接入';
  }

  bool get _isEvm => switch (widget.token.network) {
    WalletNetwork.ethereum ||
    WalletNetwork.bsc ||
    WalletNetwork.polygon ||
    WalletNetwork.arbitrum ||
    WalletNetwork.optimism ||
    WalletNetwork.base => true,
    WalletNetwork.tron || WalletNetwork.solana => false,
  };

  String get _sourceAddress {
    final sourceAddress = widget.token.sourceAddress;
    if (sourceAddress != null && sourceAddress.isNotEmpty) {
      return sourceAddress;
    }
    return widget.walletIdentity?.address ?? '';
  }

  bool get _supportsNonEvmTransfer =>
      _sourceAddress.isNotEmpty &&
      (widget.token.network == WalletNetwork.solana ||
          widget.token.tokenAddress != null);

  bool get _hasValidEvmEstimate {
    final estimate = _feeEstimate;
    final amountRaw = _amountRaw;
    if (!_isEvm ||
        (!widget.token.isNative && widget.token.tokenAddress == null) ||
        estimate == null ||
        amountRaw == null ||
        estimate.assetBalanceWei < amountRaw ||
        !estimate.hasSufficientNativeBalance) {
      return false;
    }
    if (!widget.token.isNative) return true;
    return estimate.nativeBalanceWei >= estimate.feeWei + amountRaw;
  }

  bool get _canConfirm {
    final amount = double.tryParse(_amountController.text.trim());
    final availableAmount = double.tryParse(widget.token.availableAmount);
    final recipient = _recipientController.text.trim();
    final validAddress = switch (widget.token.chain) {
      'Tron' => RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(recipient),
      'Solana' => RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(recipient),
      _ => RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(recipient),
    };
    final validAmount =
        amount != null &&
        availableAmount != null &&
        amount > 0 &&
        amount <= availableAmount;
    if (!validAddress || !validAmount) return false;
    return _isEvm ? _hasValidEvmEstimate : _supportsNonEvmTransfer;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _scheduleEstimate() {
    final generation = ++_estimateGeneration;
    setState(() {
      _feeEstimate = null;
      _feeError = null;
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted || generation != _estimateGeneration || !_isEvm) return;
      final identity = widget.walletIdentity;
      final tokens = await SecureAccountTokenStore().read();
      final amount = _amountController.text.trim();
      if (identity == null || tokens == null || amount.isEmpty) return;
      if (!widget.token.isNative && widget.token.tokenAddress == null) {
        if (mounted && generation == _estimateGeneration) {
          setState(() => _feeError = '缺少代币合约地址');
        }
        return;
      }
      try {
        final amountRaw = BigInt.parse(
          WalletTransferService.decimalToBaseUnits(
            amount,
            decimals: widget.token.decimals,
          ),
        );
        final rpc = WalletRpcClient(
          client: http.Client(),
          directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
          ownsClient: true,
        );
        try {
          final estimate = await const WalletTransferService()
              .estimateEvmTransfer(
                from: identity.address,
                to: _recipientController.text.trim(),
                network: widget.token.network,
                accessToken: tokens.accessToken,
                rpc: rpc,
                amountRaw: amountRaw,
                tokenAddress: widget.token.isNative
                    ? null
                    : widget.token.tokenAddress,
              );
          if (!mounted || generation != _estimateGeneration) return;
          setState(() => _feeEstimate = estimate);
        } finally {
          rpc.close();
        }
      } catch (error) {
        if (!mounted || generation != _estimateGeneration) return;
        setState(() => _feeError = '$error');
      }
    });
  }

  Future<void> _submit() async {
    if (!_canConfirm) return;
    _dismissKeyboard();
    final identity = widget.walletIdentity;
    if (identity == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final mnemonic = await showWalletUnlockDialog(
        context: context,
        store: widget.secretStore,
        walletAddress: identity.address,
        passwordFieldKey: const Key('transfer-password-field'),
      );
      if (mnemonic == null) return;
      final tokens = await SecureAccountTokenStore().read();
      final rpc = WalletRpcClient(
        client: http.Client(),
        directoryBaseUri: Uri.parse(const AppConfig().apiBaseUrl),
        ownsClient: true,
      );
      late WalletTransferResult result;
      try {
        if (tokens == null) {
          throw const WalletSecurityException('请先登录账户以获取链上 RPC');
        }
        final amountRaw = BigInt.parse(
          WalletTransferService.decimalToBaseUnits(
            _amountController.text.trim(),
            decimals: widget.token.decimals,
          ),
        );
        if (_isEvm) {
          result = await const WalletTransferService()
              .executeEvmTransferWithRpc(
                mnemonic: mnemonic,
                from: identity.address,
                to: _recipientController.text.trim(),
                network: widget.token.network,
                accessToken: tokens.accessToken,
                rpc: rpc,
                amountRaw: amountRaw,
                tokenAddress: widget.token.isNative
                    ? null
                    : widget.token.tokenAddress,
              );
        } else if (widget.token.network == WalletNetwork.tron) {
          final transfer = await const TronTransferService().transferTrc20(
            mnemonic: mnemonic,
            from: _sourceAddress,
            to: _recipientController.text.trim(),
            contract: widget.token.tokenAddress!,
            amount: amountRaw,
            accessToken: tokens.accessToken,
            rpc: rpc,
          );
          result = WalletTransferResult(hash: transfer.hash, status: '已广播');
        } else {
          final transfer = await const SolanaTransferService().transfer(
            mnemonic: mnemonic,
            from: _sourceAddress,
            to: _recipientController.text.trim(),
            amount: amountRaw,
            mint: widget.token.isNative ? null : widget.token.tokenAddress,
            decimals: widget.token.decimals,
            accessToken: tokens.accessToken,
            rpc: rpc,
          );
          result = WalletTransferResult(hash: transfer.hash, status: '已广播');
        }
      } finally {
        rpc.close();
      }
      if (result.status == '已广播') {
        await _recordBroadcastTransaction(identity: identity, result: result);
      }
      if (mounted) {
        final title = result.status == '已广播' ? '转账成功' : '交易已签名';
        _showNotice(context, title, '交易哈希：${result.hash}');
      }
    } on WalletSecurityException catch (error) {
      if (mounted) _showNotice(context, '转账失败', error.message);
    } catch (error) {
      if (mounted) _showNotice(context, '转账失败', '交易构造失败：$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _recordBroadcastTransaction({
    required WalletIdentity identity,
    required WalletTransferResult result,
  }) async {
    final transactionService = WalletTransactionService();
    try {
      await transactionService
          .recordAppTransfer(
            network: widget.token.network,
            address: identity.address,
            contractAddress: widget.token.tokenAddress,
            symbol: widget.token.symbol,
            decimals: widget.token.decimals,
            to: _recipientController.text.trim(),
            amountRaw: WalletTransferService.decimalToBaseUnits(
              _amountController.text.trim(),
              decimals: widget.token.decimals,
            ),
            hash: result.hash,
          )
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint('record wallet transaction failed: $error');
    } finally {
      transactionService.close();
    }
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '转账',
    titleFontSize: AcoTypography.body,
    child: AcoSafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
              children: [
                _TransferSectionLabel(palette: widget.palette, label: '收款地址'),
                const SizedBox(height: 11),
                _TransferInputSurface(
                  palette: widget.palette,
                  child: CupertinoTextField(
                    key: const Key('transfer-recipient-field'),
                    controller: _recipientController,
                    onChanged: (_) {
                      setState(() {});
                      _scheduleEstimate();
                    },
                    onTapOutside: (_) => _dismissKeyboard(),
                    placeholder: '输入或粘贴钱包地址',
                    placeholderStyle: TextStyle(
                      color: widget.palette.mutedText,
                      fontSize: AcoTypography.body,
                    ),
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: AcoTypography.body,
                    ),
                    cursorColor: _lime,
                    padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
                    decoration: const BoxDecoration(color: _transparent),
                    suffix: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(42, 42),
                      onPressed: () {
                        _dismissKeyboard();
                        _showNotice(context, '扫码', '请使用钱包首页的扫码功能。');
                      },
                      child: Icon(
                        CupertinoIcons.qrcode_viewfinder,
                        color: widget.palette.primaryText,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _TransferSectionLabel(
                  palette: widget.palette,
                  label: '转账金额',
                  action: widget.token.symbol,
                ),
                const SizedBox(height: 11),
                _TransferInputSurface(
                  palette: widget.palette,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              key: const Key('transfer-amount-field'),
                              controller: _amountController,
                              onChanged: (_) {
                                setState(() {});
                                _scheduleEstimate();
                              },
                              onTapOutside: (_) => _dismissKeyboard(),
                              placeholder: '请输入数量',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp('[0-9.]'),
                                ),
                              ],
                              placeholderStyle: TextStyle(
                                color: widget.palette.mutedText,
                                fontSize: AcoTypography.bodyEmphasis,
                              ),
                              style: TextStyle(
                                color: widget.palette.primaryText,
                                fontSize: AcoTypography.bodyEmphasis,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: widget.palette.accent,
                              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                              decoration: const BoxDecoration(
                                color: _transparent,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(right: 14),
                            minimumSize: const Size(50, 36),
                            onPressed: () {
                              _dismissKeyboard();
                              _amountController.text =
                                  widget.token.availableAmount;
                              setState(() {});
                              _scheduleEstimate();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: widget.palette.accent.withValues(
                                    alpha: .75,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                '全部',
                                style: TextStyle(
                                  color: widget.palette.accent,
                                  fontSize: AcoTypography.bodySmall,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(height: 1, color: widget.palette.border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                        child: Row(
                          children: [
                            Text(
                              '可用余额',
                              style: TextStyle(
                                color: widget.palette.mutedText,
                                fontSize: AcoTypography.bodySmall,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.token.availableAmount} ${widget.token.symbol}',
                              style: TextStyle(
                                color: widget.palette.primaryText,
                                fontSize: AcoTypography.bodySmall,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _TransferSectionLabel(
                  palette: widget.palette,
                  label: '网络费',
                  action: _feeLabel,
                ),
                const SizedBox(height: 11),
                _TransferInputSurface(
                  palette: widget.palette,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.speedometer,
                          color: widget.palette.accent,
                          size: 23,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '推荐网络费',
                                style: TextStyle(
                                  color: widget.palette.primaryText,
                                  fontSize: AcoTypography.body,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _feeDescription,
                                style: TextStyle(
                                  color: widget.palette.mutedText,
                                  fontSize: AcoTypography.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '0 ${widget.token.feeSymbol}',
                          style: TextStyle(
                            color: widget.palette.primaryText,
                            fontSize: AcoTypography.bodySmall,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 22),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: CupertinoButton(
                key: const Key('transfer-confirm-button'),
                padding: EdgeInsets.zero,
                onPressed: _canConfirm && !_submitting ? _submit : null,
                color: _canConfirm
                    ? widget.palette.accent
                    : widget.palette.surfaceRaised,
                disabledColor: _submitting
                    ? widget.palette.accent
                    : widget.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                child: _submitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(color: _black),
                          SizedBox(width: 8),
                          Text(
                            '转账中…',
                            style: TextStyle(
                              color: _black,
                              fontSize: AcoTypography.body,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '确认转账',
                        style: TextStyle(
                          color: _canConfirm
                              ? _black
                              : widget.palette.mutedText,
                          fontSize: AcoTypography.body,
                          fontWeight: FontWeight.w700,
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
