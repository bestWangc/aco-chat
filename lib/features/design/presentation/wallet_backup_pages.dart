part of 'aco_design_shell.dart';

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
