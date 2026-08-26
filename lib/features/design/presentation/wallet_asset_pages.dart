part of 'aco_design_shell.dart';

class _TokenAvatar extends StatelessWidget {
  const _TokenAvatar({required this.token});

  final TransferToken token;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 35,
    height: 35,
    child: token.iconAsset.endsWith('.png')
        ? ClipOval(child: Image.asset(token.iconAsset, fit: BoxFit.cover))
        : SvgPicture.asset(token.iconAsset),
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
      child: SafeArea(
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
  const _SendTransferPage({required this.palette, required this.token});

  final AcoPalette palette;
  final TransferToken token;

  @override
  State<_SendTransferPage> createState() => _SendTransferPageState();
}

class _SendTransferPageState extends State<_SendTransferPage> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  bool get _canConfirm {
    final amount = double.tryParse(_amountController.text.trim());
    final availableAmount = double.tryParse(widget.token.availableAmount);
    return _recipientController.text.trim().isNotEmpty &&
        amount != null &&
        availableAmount != null &&
        amount > 0 &&
        amount <= availableAmount;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canConfirm) return;
    _dismissKeyboard();
    _showNotice(context, '暂未发送', '链上签名和广播将在后续版本开放。');
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '转账',
    titleFontSize: AcoTypography.body,
    child: SafeArea(
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
                    onChanged: (_) => setState(() {}),
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
                              onChanged: (_) => setState(() {}),
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
                  action: '费用未估算',
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
                                '链上广播接入后将估算费用',
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
                onPressed: _canConfirm ? _submit : null,
                color: _canConfirm
                    ? widget.palette.accent
                    : widget.palette.surfaceRaised,
                disabledColor: widget.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  '确认转账',
                  style: TextStyle(
                    color: _canConfirm ? _black : widget.palette.mutedText,
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

class _TransferSectionLabel extends StatelessWidget {
  const _TransferSectionLabel({
    required this.palette,
    required this.label,
    this.action,
  });

  final AcoPalette palette;
  final String label;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (action case final action?)
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 28),
            onPressed: null,
            child: Text(
              action,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _TransferInputSurface extends StatelessWidget {
  const _TransferInputSurface({required this.palette, required this.child});

  final AcoPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: palette.border),
    ),
    child: child,
  );
}

class _WalletDetailDeleteButton extends StatelessWidget {
  const _WalletDetailDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '删除钱包',
    child: SizedBox(
      width: double.infinity,
      height: 38,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: _walletDetailDeleteColor,
        borderRadius: BorderRadius.circular(19),
        onPressed: onPressed,
        child: const Text(
          '删除钱包',
          style: TextStyle(
            color: _white,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

// Wallet detail action components.

class _WalletDetailAction extends StatelessWidget {
  const _WalletDetailAction({
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final AcoPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    minimumSize: const Size.fromHeight(60),
    onPressed: onPressed,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _WalletDetailChevron(color: palette.mutedText),
      ],
    ),
  );
}

class _WalletDetailChevron extends StatelessWidget {
  const _WalletDetailChevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(CupertinoIcons.chevron_right, color: color, size: 24),
        Transform.translate(
          offset: const Offset(-0.75, 0),
          child: Icon(CupertinoIcons.chevron_right, color: color, size: 24),
        ),
      ],
    ),
  );
}

class _WalletDetailActionCard extends StatelessWidget {
  const _WalletDetailActionCard({required this.palette, required this.child});

  final AcoPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 121,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.dark ? palette.background : palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.dark ? _walletDetailBorderColor : palette.border,
        ),
      ),
      child: child,
    ),
  );
}

class _WalletChains extends StatefulWidget {
  const _WalletChains({
    required this.palette,
    required this.onOpen,
    required this.selectedChain,
    required this.onChainSelected,
    required this.onWalletSelected,
    required this.walletName,
    this.walletIdentity,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final int selectedChain;
  final ValueChanged<int> onChainSelected;
  final Future<void> Function(WalletIdentity) onWalletSelected;
  final String walletName;
  final WalletIdentity? walletIdentity;

  @override
  State<_WalletChains> createState() => _WalletChainsState();
}

class _WalletChainsState extends State<_WalletChains> {
  late int _selectedChain;
  late Future<List<_WalletListItem>> _walletsFuture;

  @override
  void initState() {
    super.initState();
    _selectedChain = widget.selectedChain;
    _walletsFuture = _loadWallets();
  }

  @override
  void didUpdateWidget(covariant _WalletChains oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChain != widget.selectedChain ||
        oldWidget.walletIdentity?.address != widget.walletIdentity?.address ||
        oldWidget.walletName != widget.walletName) {
      _selectedChain = widget.selectedChain;
      _walletsFuture = _loadWallets(widget.selectedChain);
    }
  }

  void _selectChain(int index) {
    if (index == _selectedChain) return;
    setState(() {
      _selectedChain = index;
      _walletsFuture = _loadWallets(index);
    });
    widget.onChainSelected(index);
  }

  Future<void> _showAddWalletSheet(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          '添加钱包',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: AcoTypography.bodySmall,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              widget.onOpen(AcoScreen.walletSetupCreate);
            },
            child: Text(
              '创建钱包',
              style: TextStyle(
                color: widget.palette.accent,
                fontSize: AcoTypography.body,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              widget.onOpen(AcoScreen.walletSetupImport);
            },
            child: Text(
              '导入钱包',
              style: TextStyle(
                color: widget.palette.accent,
                fontSize: AcoTypography.body,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(
            '取消',
            style: TextStyle(
              color: widget.palette.accent,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Future<List<_WalletListItem>> _loadWallets([int? chainIndex]) async {
    if (widget.walletIdentity == null) return const [];
    final storedWallets = await WalletPreferences.storedWallets(
      fallback: widget.walletIdentity,
    );
    final selectedChain = _supportedWalletChains[chainIndex ?? _selectedChain];
    final currentAddress = widget.walletIdentity!.address.toLowerCase();
    final wallets = <_WalletListItem>[];
    for (final storedWallet in storedWallets) {
      final identity = storedWallet.identity;
      final address = await _addressForChain(identity, selectedChain);
      if (address == null || address.isEmpty) continue;
      wallets.add(
        _WalletListItem(
          identity: identity,
          address: address,
          name: storedWallet.name,
          current: identity.address.toLowerCase() == currentAddress,
        ),
      );
    }
    return wallets;
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '钱包列表',
    child: Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _walletChainRailWidth + 18 + 5,
                8,
                20,
                8,
              ),
              child: Row(
                children: [
                  Text(
                    _supportedWalletChains[_selectedChain].displayLabel,
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: AcoTypography.bodyEmphasis,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: '添加钱包',
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () => _showAddWalletSheet(context),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: const Offset(-.2, 0),
                              child: Icon(
                                CupertinoIcons.add_circled,
                                color: widget.palette.accent,
                                size: 19,
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(.2, 0),
                              child: Icon(
                                CupertinoIcons.add_circled,
                                color: widget.palette.accent,
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: FutureBuilder<List<_WalletListItem>>(
                future: _walletsFuture,
                builder: (context, snapshot) {
                  final wallets = snapshot.data;
                  if (wallets == null) {
                    return Center(
                      child: CupertinoActivityIndicator(
                        color: widget.palette.accent,
                      ),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: _walletChainRailWidth),
                      Expanded(
                        child: wallets.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无钱包',
                                  style: TextStyle(
                                    color: widget.palette.mutedText,
                                    fontSize: AcoTypography.bodyEmphasis,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  0,
                                  12,
                                  0,
                                ),
                                itemCount: wallets.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final wallet = wallets[index];
                                  return _WalletChainCard(
                                    palette: widget.palette,
                                    name: wallet.name,
                                    address: wallet.address,
                                    current: wallet.current,
                                    onSelect: () => widget.onWalletSelected(
                                      wallet.identity,
                                    ),
                                    onOpenDetails: () =>
                                        widget.onOpen(AcoScreen.assetDetail),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _walletChainRailWidth,
          child: _WalletChainRail(
            palette: widget.palette,
            chains: _supportedWalletChains,
            selected: _selectedChain,
            onSelected: _selectChain,
          ),
        ),
      ],
    ),
  );
}

class _WalletListItem {
  const _WalletListItem({
    required this.identity,
    required this.address,
    required this.name,
    required this.current,
  });

  final WalletIdentity identity;
  final String address;
  final String name;
  final bool current;
}

class _WalletChainRail extends StatelessWidget {
  const _WalletChainRail({
    required this.palette,
    required this.chains,
    required this.selected,
    required this.onSelected,
  });

  final AcoPalette palette;
  final List<_WalletChain> chains;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: palette.background,
    child: ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: chains.length,
      itemBuilder: (_, index) {
        final active = index == selected;
        final chain = chains[index];
        return SizedBox(
          height: _walletChainRailItemHeight,
          child: Stack(
            children: [
              if (active)
                Positioned.fill(
                  child: ColoredBox(
                    color: palette.dark
                        ? const Color(0xFF1C1C1C)
                        : palette.surfaceRaised,
                  ),
                ),
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: '选择公链 ${chain.label}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(index),
                    child: Center(
                      child: _WalletChainLogo(
                        asset: chain.asset,
                        muted: !active,
                        backgroundColor: chain.backgroundColor,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: _walletChainRailIndicatorWidth,
                    height: _walletChainRailItemHeight,
                    color: palette.accent,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _WalletChainLogo extends StatelessWidget {
  const _WalletChainLogo({
    required this.asset,
    this.muted = false,
    this.backgroundColor,
    this.size = 40,
  });
  final String asset;
  final bool muted;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Opacity(
      opacity: muted ? .58 : 1,
      child: ClipOval(
        child: ColoredBox(
          color: backgroundColor ?? _transparent,
          child: asset.endsWith('.svg')
              ? SvgPicture.asset(asset, fit: BoxFit.cover)
              : Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    ),
  );
}

class _WalletChainCard extends StatelessWidget {
  const _WalletChainCard({
    required this.palette,
    required this.name,
    required this.address,
    required this.current,
    required this.onSelect,
    required this.onOpenDetails,
  });
  final AcoPalette palette;
  final String name;
  final String address;
  final bool current;
  final VoidCallback onSelect;
  final VoidCallback onOpenDetails;

  String _displayAddress() {
    if (address.length <= 19) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 6)}';
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    // Reserve comfortable room for all three text rows on narrow screens
    // without relying on a device-specific fixed height.
    aspectRatio: 2.45,
    child: Stack(
      children: [
        Semantics(
          button: true,
          selected: current,
          label: '选择$name',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                _walletChainCardHorizontalPadding,
                11,
                12,
                10,
              ),
              decoration: current
                  ? BoxDecoration(
                      color: _walletCurrentCardColor,
                      borderRadius: BorderRadius.circular(8),
                    )
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _walletInactiveCardBorderColor),
                    ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: AcoTypography.bodyEmphasis,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (current)
                        Container(
                          margin: const EdgeInsets.only(left: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '当前',
                            style: TextStyle(
                              color: _black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _displayAddress(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.caption,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.doc_on_doc,
                        color: palette.mutedText,
                        size: 14,
                      ),
                    ],
                  ),
                  Text(
                    r'$0.00',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.body,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 4,
          child: Semantics(
            button: true,
            label: '查看$name详情',
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: onOpenDetails,
              child: SizedBox(
                width: 18,
                height: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(-.5, 0),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        color: palette.accent,
                        size: 15,
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(.5, 0),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        color: palette.accent,
                        size: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AssetDetail extends StatefulWidget {
  const _AssetDetail({
    required this.palette,
    required this.walletIdentity,
    required this.selectedChain,
    required this.walletName,
    required this.onOpen,
    this.onWalletNameChanged,
  });

  final AcoPalette palette;
  final WalletIdentity? walletIdentity;
  final _WalletChain selectedChain;
  final String walletName;
  final ValueChanged<AcoScreen> onOpen;
  final Future<void> Function(String name)? onWalletNameChanged;

  @override
  State<_AssetDetail> createState() => _AssetDetailState();
}

class _AssetDetailState extends State<_AssetDetail> {
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
  void didUpdateWidget(covariant _AssetDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletIdentity != widget.walletIdentity ||
        oldWidget.selectedChain.network != widget.selectedChain.network) {
      _addressFuture = _addressForChain(
        widget.walletIdentity,
        widget.selectedChain,
      );
    }
  }

  Future<void> _copyAddress(String address) async {
    if (address.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (mounted) _showNotice(context, '已复制', '钱包地址已复制到剪贴板。');
  }

  Future<void> _editWalletName() async {
    final controller = TextEditingController(text: widget.walletName);
    var name = widget.walletName;
    final savedName = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: widget.palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: _lime,
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
            title: const Text('修改钱包名称'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                key: const Key('wallet-name-input'),
                controller: controller,
                autofocus: true,
                maxLength: WalletPreferences.walletNameMaxLength,
                textInputAction: TextInputAction.done,
                onChanged: (value) => setDialogState(() => name = value.trim()),
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) {
                    Navigator.of(dialogContext).pop(trimmed);
                  }
                },
                placeholder: '请输入钱包名称',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: name.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(name),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (savedName == null || widget.onWalletNameChanged == null) return;
    await widget.onWalletNameChanged!(savedName);
  }

  void _confirmDeleteWallet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('删除钱包'),
        message: const Text('删除后需要通过助记词或私钥重新导入。'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showNotice(context, '删除钱包', '钱包删除功能即将开放。');
            },
            child: const Text('确认删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _addressFuture,
    builder: (_, snapshot) {
      final address = snapshot.data ?? '钱包地址未就绪';
      final addressReady = snapshot.data?.isNotEmpty ?? false;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
            child: AcoPageHeader(
              palette: widget.palette,
              title: '钱包详情',
              backButtonOffset: Offset.zero,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(21, 24, 21, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: widget.palette.dark
                          ? _walletDetailBorderColor
                          : widget.palette.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(30, 18, 30, 14),
                        child: Row(
                          children: [
                            KeyedSubtree(
                              key: const Key('wallet-detail-chain-logo'),
                              child: _WalletChainLogo(
                                asset: widget.selectedChain.asset,
                                backgroundColor:
                                    widget.selectedChain.backgroundColor,
                                size: 48,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Text(
                                widget.walletName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.palette.primaryText,
                                  fontSize: AcoTypography.bodyEmphasis,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              key: const Key('edit-wallet-name'),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                              onPressed: widget.onWalletNameChanged == null
                                  ? null
                                  : _editWalletName,
                              child: Image.asset(
                                'assets/icons/wallet_edit_pencil.png',
                                width: 18,
                                height: 16,
                                color: widget.palette.primaryText,
                                errorBuilder: (_, _, _) => Icon(
                                  CupertinoIcons.pencil,
                                  color: widget.palette.primaryText,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(22, 20, 20, 16),
                        decoration: BoxDecoration(
                          color: widget.palette.dark
                              ? _walletDetailBorderColor
                              : widget.palette.surfaceRaised,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '钱包地址',
                                  style: TextStyle(
                                    color: widget.palette.mutedText,
                                    fontSize: AcoTypography.bodySmall,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  key: const Key('wallet-detail-copy-address'),
                                  onTap: addressReady
                                      ? () => _copyAddress(address)
                                      : null,
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Icon(
                                      CupertinoIcons.doc_on_doc,
                                      color: widget.palette.mutedText,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    address,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: widget.palette.primaryText,
                                      fontSize: AcoTypography.bodySmall,
                                      fontWeight: FontWeight.w400,
                                    ),
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
                const SizedBox(height: 48),
                _WalletDetailActionCard(
                  palette: widget.palette,
                  child: Column(
                    children: [
                      _WalletDetailAction(
                        label: '导出助记词',
                        palette: widget.palette,
                        onPressed: () =>
                            widget.onOpen(AcoScreen.backupMnemonic),
                      ),
                      Container(
                        height: 1,
                        color: widget.palette.dark
                            ? _walletDetailBorderColor
                            : widget.palette.border,
                      ),
                      _WalletDetailAction(
                        label: '导出私钥',
                        palette: widget.palette,
                        onPressed: () =>
                            widget.onOpen(AcoScreen.exportPrivateKey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(53, 8, 53, 25),
            child: _WalletDetailDeleteButton(onPressed: _confirmDeleteWallet),
          ),
        ],
      );
    },
  );
}

enum _SensitiveExportStep { warning, value }

enum _SensitiveExportType { mnemonic, privateKey }

class _BackupMnemonicFlow extends StatefulWidget {
  const _BackupMnemonicFlow({
    required this.palette,
    required this.walletIdentity,
    required this.secretStore,
    this.exportType = _SensitiveExportType.mnemonic,
  });

  final AcoPalette palette;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore secretStore;
  final _SensitiveExportType exportType;

  @override
  State<_BackupMnemonicFlow> createState() => _BackupMnemonicFlowState();
}

class _BackupMnemonicFlowState extends State<_BackupMnemonicFlow> {
  final _walletSecurity = WalletSecurity();
  var _step = _SensitiveExportStep.warning;
  String? _exportValue;
  var _exportValueVisible = false;
  var _exportValueCopied = false;

  bool get _isMnemonicExport =>
      widget.exportType == _SensitiveExportType.mnemonic;

  String get _credentialLabel => _isMnemonicExport ? '助记词' : '私钥';

  String get _actionLabel {
    if (_step == _SensitiveExportStep.warning) return '下一步';
    return _exportValueCopied ? '已复制$_credentialLabel' : '复制$_credentialLabel';
  }

  @override
  void dispose() {
    SensitiveScreenProtection.setEnabled(false);
    super.dispose();
  }

  Future<void> _continue() async {
    switch (_step) {
      case _SensitiveExportStep.warning:
        await _showPasswordPrompt();
        return;
      case _SensitiveExportStep.value:
        await _copyExportValue();
        return;
    }
  }

  Future<void> _showPasswordPrompt() async {
    final identity = widget.walletIdentity;
    if (identity == null) return;
    final controller = TextEditingController();
    var password = '';
    var isVerifying = false;
    String? errorMessage;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: widget.palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: _lime,
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
            title: const Text('验证钱包密码'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  CupertinoTextField(
                    key: Key(
                      _isMnemonicExport
                          ? 'export-mnemonic-password'
                          : 'export-private-key-password',
                    ),
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _dismissKeyboard(),
                    onTapOutside: (_) => _dismissKeyboard(),
                    onChanged: (value) => setDialogState(() {
                      password = value;
                      errorMessage = null;
                    }),
                    placeholder: '请输入钱包密码',
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: AcoTypography.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: isVerifying
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: password.length < 8 || isVerifying
                    ? null
                    : () async {
                        setDialogState(() => isVerifying = true);
                        try {
                          await Future<void>.delayed(Duration.zero);
                          final mnemonic = await _walletSecurity.unlockMnemonic(
                            store: widget.secretStore,
                            walletAddress: identity.address,
                            password: password,
                          );
                          final exportValue = _isMnemonicExport
                              ? mnemonic
                              : await compute(
                                  WalletIdentity.privateKeyFromMnemonic,
                                  mnemonic,
                                );
                          if (!dialogContext.mounted || !mounted) return;
                          Navigator.of(dialogContext).pop();
                          setState(() {
                            _exportValue = exportValue;
                            _step = _SensitiveExportStep.value;
                            _exportValueVisible = false;
                            _exportValueCopied = false;
                          });
                          await SensitiveScreenProtection.setEnabled(true);
                        } on WalletSecurityException catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              errorMessage = error.message;
                              isVerifying = false;
                            });
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              errorMessage = '验证失败，请稍后重试。';
                              isVerifying = false;
                            });
                          }
                        }
                      },
                child: Text(isVerifying ? '验证中...' : '确认'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _copyExportValue() async {
    final value = _exportValue;
    if (value == null || value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _exportValueCopied = true);
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: _isMnemonicExport ? '备份助记词' : '导出私钥',
    headerTopPadding: 8,
    titleFontSize: AcoTypography.body,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              children: [
                switch (_step) {
                  _SensitiveExportStep.warning => _MnemonicBackupWarning(
                    palette: widget.palette,
                    type: widget.exportType,
                  ),
                  _SensitiveExportStep.value =>
                    _isMnemonicExport
                        ? _MnemonicPhraseView(
                            palette: widget.palette,
                            mnemonic: _exportValue ?? '',
                            visible: _exportValueVisible,
                            onReveal: () =>
                                setState(() => _exportValueVisible = true),
                          )
                        : _PrivateKeyView(
                            palette: widget.palette,
                            privateKey: _exportValue ?? '',
                            visible: _exportValueVisible,
                            onReveal: () =>
                                setState(() => _exportValueVisible = true),
                          ),
                },
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: CupertinoButton(
                key: const Key('backup-mnemonic-continue'),
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(44),
                onPressed: _continue,
                child: Container(
                  width: double.infinity,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.palette.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _actionLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _black,
                      fontSize: AcoTypography.body,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
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

class _MnemonicBackupWarning extends StatelessWidget {
  const _MnemonicBackupWarning({required this.palette, required this.type});

  final AcoPalette palette;
  final _SensitiveExportType type;

  bool get _isMnemonicExport => type == _SensitiveExportType.mnemonic;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        height: 144,
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            CupertinoIcons.shield_lefthalf_fill,
            color: palette.accent,
            size: 52,
          ),
        ),
      ),
      const SizedBox(height: 22),
      Text(
        _isMnemonicExport ? '备份助记词，保护钱包安全' : '导出私钥，保护钱包安全',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.bodyEmphasis,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _isMnemonicExport
            ? '助记词是恢复钱包的唯一凭证。请妥善备份，并确保仅由你自己保存。'
            : '私钥可直接控制钱包资产。请仅在安全环境下导出，并确保仅由你自己保存。',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.bodySmall,
          height: 1.55,
        ),
      ),
      const SizedBox(height: 18),
      _MnemonicNoticeCard(
        palette: palette,
        icon: CupertinoIcons.exclamationmark_circle,
        title: '重要提醒',
        message: _isMnemonicExport
            ? '任何人只要获取助记词，即可控制你的资产。'
            : '任何人只要获取私钥，即可控制你的资产。',
      ),
      const SizedBox(height: 24),
      Text(
        _isMnemonicExport ? '建议备份方式' : '安全提示',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.bodyEmphasis,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _isMnemonicExport
            ? '使用笔和纸按顺序抄写\n保存到安全地点\n不要截屏、复制或通过网络传输'
            : '确认当前环境无人窥视\n导出后妥善保管\n不要通过网络传输或分享给他人',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.bodySmall,
          height: 1.55,
        ),
      ),
    ],
  );
}

class _MnemonicPhraseView extends StatelessWidget {
  const _MnemonicPhraseView({
    required this.palette,
    required this.mnemonic,
    required this.visible,
    required this.onReveal,
  });

  final AcoPalette palette;
  final String mnemonic;
  final bool visible;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final words = mnemonic.split(' ').where((word) => word.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '请妥善保管助记词',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.titleLarge,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '点击下方区域查看并按顺序抄写。不要向任何人透露。',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
        const SizedBox(height: 24),
        _MnemonicNoticeCard(
          palette: palette,
          icon: CupertinoIcons.eye_slash_fill,
          title: '安全保护已开启',
          message: '助记词默认隐藏，离开此页面后将自动清除显示。',
        ),
        const SizedBox(height: 20),
        Semantics(
          button: !visible,
          label: visible ? '助记词已显示' : '点击显示助记词',
          child: CupertinoButton(
            key: const Key('mnemonic-reveal-button'),
            padding: EdgeInsets.zero,
            minimumSize: const Size.fromHeight(0),
            onPressed: visible ? null : onReveal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: visible
                  ? _MnemonicWordGrid(palette: palette, words: words)
                  : SizedBox(
                      height: 276,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.eye_slash,
                              color: palette.mutedText,
                              size: 30,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '助记词已隐藏',
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: AcoTypography.bodyEmphasis,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '点击查看',
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: AcoTypography.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivateKeyView extends StatelessWidget {
  const _PrivateKeyView({
    required this.palette,
    required this.privateKey,
    required this.visible,
    required this.onReveal,
  });

  final AcoPalette palette;
  final String privateKey;
  final bool visible;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '请妥善保管私钥',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.titleLarge,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        '点击下方区域查看私钥。不要向任何人透露。',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.body,
        ),
      ),
      const SizedBox(height: 24),
      _MnemonicNoticeCard(
        palette: palette,
        icon: CupertinoIcons.eye_slash_fill,
        title: '安全保护已开启',
        message: '私钥默认隐藏，离开此页面后将自动清除显示。',
      ),
      const SizedBox(height: 20),
      Semantics(
        button: !visible,
        label: visible ? '私钥已显示' : '点击显示私钥',
        child: CupertinoButton(
          key: const Key('private-key-reveal-button'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.fromHeight(0),
          onPressed: visible ? null : onReveal,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 148),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: visible
                ? Text(
                    privateKey,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.bodySmall,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      height: 1.6,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.eye_slash,
                          color: palette.mutedText,
                          size: 30,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '私钥已隐藏',
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.bodyEmphasis,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '点击查看',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}

class _MnemonicWordGrid extends StatelessWidget {
  const _MnemonicWordGrid({required this.palette, required this.words});

  final AcoPalette palette;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final rowCount = (words.length + 1) ~/ 2;
    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rowCount; rowIndex++)
          _buildRow(rowIndex, rowCount),
      ],
    );
  }

  Widget _buildRow(int rowIndex, int rowCount) {
    final firstIndex = rowIndex * 2;
    final secondIndex = firstIndex + 1;
    return Padding(
      padding: EdgeInsets.only(bottom: rowIndex == rowCount - 1 ? 0 : 10),
      child: Row(
        children: [
          Expanded(
            child: _MnemonicWordChip(
              palette: palette,
              index: firstIndex + 1,
              word: words[firstIndex],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: secondIndex < words.length
                ? _MnemonicWordChip(
                    palette: palette,
                    index: secondIndex + 1,
                    word: words[secondIndex],
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _MnemonicNoticeCard extends StatelessWidget {
  const _MnemonicNoticeCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.message,
  });

  final AcoPalette palette;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: palette.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.mutedText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MnemonicWordChip extends StatelessWidget {
  const _MnemonicWordChip({
    required this.palette,
    required this.index,
    required this.word,
  });

  final AcoPalette palette;
  final int index;
  final String word;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$index',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          word,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
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
  const _ScanPage({required this.palette});

  final AcoPalette palette;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  final _controller = MobileScannerController();
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_result != null || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _controller.stop();
    setState(() => _result = value);
  }

  Future<void> _continueScanning() async {
    setState(() => _result = null);
    await _controller.start();
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
      SafeArea(
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
                borderRadius: BorderRadius.circular(20),
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
    required this.onContinue,
  });

  final AcoPalette palette;
  final String value;
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
          '已识别二维码',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.mutedText),
        ),
        const SizedBox(height: 18),
        AcoLimeButton(label: '继续扫描', onPressed: onContinue),
      ],
    ),
  );
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

class _AddTokenPage extends StatelessWidget {
  const _AddTokenPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '添加代币',
    right: _AddTokenMoreButton(palette: palette),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(27, 12, 27, 26),
      children: [
        _AddTokenSearch(
          palette: palette,
          onSubmit: () => _showNotice(context, '搜索', '已开始搜索代币。'),
        ),
        const SizedBox(height: 30),
        _AddTokenEntry(label: '首页资产', palette: palette),
        _AddTokenEntry(label: '我的资产', palette: palette, count: '47'),
        _AddTokenEntry(label: '自定义代币', palette: palette),
        const SizedBox(height: 12),
        Text(
          '热门代币',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _AddTokenHotRow(symbol: 'USDT', assetSymbol: 'usdt', palette: palette),
        _AddTokenHotRow(symbol: 'USDC', assetSymbol: 'usdc', palette: palette),
      ],
    ),
  );
}

class _AddTokenMoreButton extends StatelessWidget {
  const _AddTokenMoreButton({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(44, 44),
    onPressed: () => _showNotice(context, '更多', '更多代币设置即将开放。'),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(CupertinoIcons.ellipsis, color: palette.primaryText, size: 26),
        Positioned(
          right: -1,
          top: 6,
          child: Icon(CupertinoIcons.sparkles, color: _lime, size: 11),
        ),
      ],
    ),
  );
}

class _AddTokenSearch extends StatelessWidget {
  const _AddTokenSearch({required this.palette, required this.onSubmit});
  final AcoPalette palette;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      border: Border.all(
        color: palette.dark ? const Color(0xFFC6C6C6) : palette.border,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        const SizedBox(width: 16),
        Icon(CupertinoIcons.search, color: palette.mutedText, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: CupertinoTextField(
            padding: EdgeInsets.zero,
            decoration: const BoxDecoration(color: _transparent),
            cursorColor: _lime,
            placeholder: '通过代币名称或合约进行搜索',
            placeholderStyle: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.caption,
            ),
            onSubmitted: (_) {
              _dismissKeyboard();
              onSubmit();
            },
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(68, 44),
          onPressed: onSubmit,
          child: Container(
            width: 68,
            height: 44,
            decoration: const BoxDecoration(
              color: _lime,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: const Icon(
              CupertinoIcons.arrow_right,
              color: _black,
              size: 25,
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
    this.count,
  });
  final String label;
  final String? count;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 15),
    onPressed: () => _showNotice(context, label, '$label列表即将开放。'),
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
        if (count != null) ...[
          _CountPill(palette: palette, label: count!, size: 24),
          const SizedBox(width: 16),
        ],
        Icon(CupertinoIcons.chevron_right, color: palette.mutedText, size: 18),
      ],
    ),
  );
}

class _AddTokenHotRow extends StatelessWidget {
  const _AddTokenHotRow({
    required this.symbol,
    required this.assetSymbol,
    required this.palette,
  });
  final String symbol;
  final String assetSymbol;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 12),
    onPressed: () => _showNotice(context, '已添加 $symbol', '$symbol 已添加至资产列表。'),
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
            child: ClipOval(
              child: Image.asset(
                'assets/icons/crypto/domi/tokens/$assetSymbol.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '0s232sdsfs...das232s',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          const Icon(CupertinoIcons.add_circled, color: _lime, size: 24),
        ],
      ),
    ),
  );
}
