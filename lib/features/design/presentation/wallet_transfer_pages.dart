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
