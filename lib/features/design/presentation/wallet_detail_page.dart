part of 'aco_design_shell.dart';

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
