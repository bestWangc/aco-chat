part of 'aco_design_shell.dart';

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
