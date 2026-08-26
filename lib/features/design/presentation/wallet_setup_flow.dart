part of 'aco_design_shell.dart';

class _WalletSetupFlow extends StatefulWidget {
  const _WalletSetupFlow({
    required this.dark,
    required this.mode,
    required this.requireSecuritySetup,
    required this.onBack,
    required this.onComplete,
  });

  final bool dark;
  final _WalletSetupMode mode;
  final bool requireSecuritySetup;
  final VoidCallback onBack;
  final Future<void> Function(WalletIdentity, String) onComplete;

  @override
  State<_WalletSetupFlow> createState() => _WalletSetupFlowState();
}

class _WalletSetupFlowState extends State<_WalletSetupFlow> {
  final _walletSecurity = WalletSecurity();
  final _secretStore = SecureWalletSecretStore();
  final _phraseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _step = 0;
  var _backedUp = false;
  var _isCompletingWalletSetup = false;
  String? _completionStatus;
  var _mnemonicCopied = false;
  late final String _createdMnemonic = _walletSecurity.createMnemonic();
  late final List<String> _createdWords = _createdMnemonic.split(' ');
  late final List<int> _verificationIndexes = _createVerificationIndexes();
  late final List<int> _verificationChoiceIndexes =
      _createVerificationChoiceIndexes();
  final List<int> _selectedVerificationIndexes = [];
  var _verificationError = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == _WalletSetupMode.create) {
      _step = 1;
      SensitiveScreenProtection.setEnabled(true);
    }
  }

  @override
  void dispose() {
    SensitiveScreenProtection.setEnabled(false);
    _phraseController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(widget.dark);
    return ColoredBox(
      color: palette.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-20, 0),
                  child: AcoIconButton(
                    icon: CupertinoIcons.back,
                    palette: palette,
                    label: '返回',
                    onPressed: _goBack,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: AcoTypography.displaySmall,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _description,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: AcoTypography.body,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_isCreating && _step == 1) _backupWords(palette),
                      if (_isVerificationStep) _verifyWords(palette),
                      if (!_isCreating && _step == 0) _importField(palette),
                      if (_isSecurityStep) _securityFields(palette),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _WalletSetupButton(
                key: Key(
                  _isCreating
                      ? 'continue-create-wallet-button'
                      : 'confirm-import-wallet-button',
                ),
                label: _isCompletingWalletSetup
                    ? (_completionStatus ?? '正在创建钱包...')
                    : _continueLabel,
                enabled: _canContinue,
                loading: _isCompletingWalletSetup,
                filled: true,
                palette: palette,
                height: 44,
                fontSize: AcoTypography.bodyEmphasis,
                fontWeight: FontWeight.w500,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backupWords(AcoPalette palette) {
    return Column(
      children: [
        _MnemonicWordGrid(palette: palette, words: _createdWords),
        const SizedBox(height: 22),
        CupertinoButton(
          key: const Key('backup-confirmation'),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _backedUp = !_backedUp),
          child: Row(
            children: [
              Icon(
                _backedUp
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: _backedUp ? _lime : palette.mutedText,
              ),
              const SizedBox(width: 10),
              Text(
                '我已安全备份，绝不分享给他人',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CupertinoButton(
          key: const Key('copy-mnemonic-button'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          onPressed: _copyMnemonic,
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _mnemonicCopied
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.doc_on_doc,
                size: 17,
                color: palette.primaryText,
              ),
              const SizedBox(width: 8),
              Text(
                _mnemonicCopied ? '已复制' : '复制助记词',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verifyWords(AcoPalette palette) {
    final targetLabels = _verificationIndexes
        .map((index) => '第 ${index + 1} 个')
        .join('、');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '请按顺序选择：$targetLabels',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedVerificationIndexes.isEmpty
                ? [
                    Text(
                      '从下方词库中依次点选',
                      style: TextStyle(color: palette.mutedText),
                    ),
                  ]
                : _selectedVerificationIndexes
                      .map(
                        (index) => _wordChip(
                          palette: palette,
                          index: index,
                          selected: true,
                          onPressed: () => _removeVerificationWord(index),
                        ),
                      )
                      .toList(),
          ),
        ),
        if (_verificationError) ...[
          const SizedBox(height: 10),
          Text(
            '助记词顺序不正确，请重新选择。',
            style: const TextStyle(
              color: _danger,
              fontSize: AcoTypography.bodySmall,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          '词库',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: _verificationChoiceIndexes
              .where((index) => !_selectedVerificationIndexes.contains(index))
              .map(
                (index) => _wordChip(
                  palette: palette,
                  index: index,
                  onPressed: () => _selectVerificationWord(index),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _wordChip({
    required AcoPalette palette,
    required int index,
    required VoidCallback onPressed,
    bool selected = false,
  }) => CupertinoButton(
    key: Key('mnemonic-word-$index'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: Size.zero,
    color: selected ? _lime.withValues(alpha: .16) : palette.surfaceRaised,
    borderRadius: BorderRadius.circular(9),
    onPressed: onPressed,
    child: Text(
      _createdWords[index],
      style: TextStyle(
        color: palette.primaryText,
        fontSize: AcoTypography.bodySmall,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _importField(AcoPalette palette) => CupertinoTextField(
    key: const Key('recovery-phrase-field'),
    controller: _phraseController,
    minLines: 5,
    maxLines: 6,
    textInputAction: TextInputAction.done,
    onChanged: (_) => setState(() {}),
    onSubmitted: (_) => _dismissKeyboard(),
    onTapOutside: (_) => _dismissKeyboard(),
    placeholder: '在此粘贴助记词',
    style: TextStyle(color: palette.primaryText),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.inputSurface,
      borderRadius: BorderRadius.circular(14),
    ),
  );

  Widget _securityFields(AcoPalette palette) => Column(
    children: [
      CupertinoTextField(
        key: const Key('wallet-password-field'),
        controller: _passwordController,
        obscureText: true,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        onTapOutside: (_) => _dismissKeyboard(),
        placeholder: '设置钱包密码（至少 8 位）',
        style: TextStyle(color: palette.primaryText),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.inputSurface,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      const SizedBox(height: 12),
      CupertinoTextField(
        key: const Key('wallet-password-confirm-field'),
        controller: _confirmPasswordController,
        obscureText: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _dismissKeyboard(),
        onTapOutside: (_) => _dismissKeyboard(),
        placeholder: '再次输入钱包密码',
        style: TextStyle(color: palette.primaryText),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.inputSurface,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ],
  );

  bool get _hasValidPhrase {
    return _walletSecurity.isValidMnemonic(_phraseController.text);
  }

  bool get _passwordsMatch =>
      _passwordController.text.length >= 8 &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _hasSelectedAllVerificationWords =>
      _selectedVerificationIndexes.length == _verificationIndexes.length;

  bool get _isCreating => widget.mode == _WalletSetupMode.create;

  bool get _isVerificationStep => _isCreating && _step == 2;

  bool get _isSecurityStep =>
      widget.requireSecuritySetup && _step == _securityStep;

  int get _securityStep => widget.requireSecuritySetup
      ? (_isCreating ? 3 : 1)
      : (_isCreating ? 2 : 0);

  String get _continueLabel {
    if (_isSecurityStep) return '完成并进入钱包';
    if (!_isCreating) return '导入钱包';

    return switch (_step) {
      1 => '我已安全备份',
      _ => '确认助记词',
    };
  }

  bool get _canContinue {
    if (_isSecurityStep) {
      return _passwordsMatch && !_isCompletingWalletSetup;
    }
    if (!_isCreating) return _hasValidPhrase;

    return switch (_step) {
      1 => _backedUp,
      _ => _hasSelectedAllVerificationWords,
    };
  }

  List<int> _createVerificationIndexes() {
    final indexes = List<int>.generate(_createdWords.length, (i) => i)
      ..shuffle(math.Random.secure());
    return (indexes.take(3).toList()..sort());
  }

  List<int> _createVerificationChoiceIndexes() {
    final choices = List<int>.generate(_createdWords.length, (index) => index)
      ..shuffle(math.Random.secure());
    return choices;
  }

  void _selectVerificationWord(int index) {
    if (_selectedVerificationIndexes.length >= _verificationIndexes.length) {
      return;
    }
    setState(() {
      _verificationError = false;
      _selectedVerificationIndexes.add(index);
    });
  }

  void _removeVerificationWord(int index) {
    setState(() {
      _verificationError = false;
      _selectedVerificationIndexes.remove(index);
    });
  }

  bool get _verificationMatches =>
      _selectedVerificationIndexes.length == _verificationIndexes.length &&
      _selectedVerificationIndexes.asMap().entries.every(
        (entry) => entry.value == _verificationIndexes[entry.key],
      );

  Future<void> _copyMnemonic() async {
    await Clipboard.setData(ClipboardData(text: _createdMnemonic));
    if (mounted) setState(() => _mnemonicCopied = true);
  }

  String get _title {
    if (_isSecurityStep) return '保护你的钱包';
    if (!_isCreating) return '导入已有钱包';
    return _step == 1 ? '备份助记词' : '验证助记词';
  }

  String get _description {
    if (_isSecurityStep) return '设置钱包密码，并使用设备验证以完成操作。';
    if (!_isCreating) return '输入 12 或 24 个助记词，单词之间用空格分隔。';
    if (_isVerificationStep) return '确认你已妥善备份。请从词库中按顺序选择指定单词。';
    return '请按顺序安全备份这些助记词，任何人索取它们都是诈骗。';
  }

  Future<void> _continue() async {
    if (_step < _securityStep) {
      if (_isVerificationStep && !_verificationMatches) {
        setState(() {
          _verificationError = true;
          _selectedVerificationIndexes.clear();
        });
        return;
      }
      await _advanceSetupStep();
      return;
    }

    await _completeWalletSetup();
  }

  Future<void> _advanceSetupStep() async {
    final nextStep = _step + 1;
    setState(() => _step = nextStep);
    await SensitiveScreenProtection.setEnabled(
      _isCreating && nextStep >= 1 && nextStep <= 2,
    );
  }

  Future<void> _completeWalletSetup() async {
    if (_isCompletingWalletSetup) return;
    setState(() {
      _isCompletingWalletSetup = true;
      _completionStatus = '正在验证身份...';
    });

    // Render the loading state before starting platform authentication.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      if (widget.requireSecuritySetup) {
        final authenticated = await BiometricAuthentication.authenticateOrSkip()
            .timeout(const Duration(seconds: 30), onTimeout: () => false);
        if (!authenticated) {
          _showCompletionError('设备验证未完成，请重试。');
          return;
        }
      }

      await SensitiveScreenProtection.setEnabled(false);
      _setCompletionStatus('正在生成钱包...');
      final mnemonic = _isCreating
          ? _createdMnemonic
          : _walletSecurity.normalizeMnemonic(_phraseController.text);
      final identity = kIsWeb
          ? WalletIdentity.fromMnemonic(mnemonic)
          : await compute(
              _walletIdentityFromMnemonic,
              mnemonic,
            ).timeout(const Duration(seconds: 60));
      _setCompletionStatus('正在加密保存...');
      final saveMnemonic = widget.requireSecuritySetup
          ? _walletSecurity.saveMnemonic(
              store: _secretStore,
              walletAddress: identity.address,
              mnemonic: mnemonic,
              password: _passwordController.text,
            )
          : _walletSecurity.saveMnemonicWithDeviceProtection(
              store: _secretStore,
              walletAddress: identity.address,
              mnemonic: mnemonic,
            );
      await saveMnemonic.timeout(const Duration(seconds: 20));
      _setCompletionStatus('正在同步账户登录...');
      await widget
          .onComplete(identity, mnemonic)
          .timeout(const Duration(seconds: 15));
      // Non-EVM address derivation allocates a large native crypto workspace.
      // Derive those addresses lazily when their respective chain is opened.
    } on TimeoutException {
      _showCompletionError('创建超时，请重试');
    } catch (error) {
      debugPrint('Wallet setup failed: $error');
      _showCompletionError('创建失败，请重试');
    }
  }

  void _setCompletionStatus(String status) {
    if (mounted) setState(() => _completionStatus = status);
  }

  void _showCompletionError(String message) {
    if (!mounted) return;
    setState(() {
      _isCompletingWalletSetup = false;
      _completionStatus = null;
    });
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _goBack() async {
    if (_step == 0 || (_isCreating && _step == 1)) {
      widget.onBack();
      return;
    }
    final previousStep = _step - 1;
    setState(() => _step = previousStep);
    await SensitiveScreenProtection.setEnabled(
      _isCreating && previousStep >= 1 && previousStep <= 2,
    );
  }
}

WalletIdentity _walletIdentityFromMnemonic(String mnemonic) =>
    WalletIdentity.fromMnemonic(mnemonic);

class _WalletSetupButton extends StatelessWidget {
  const _WalletSetupButton({
    required this.label,
    required this.enabled,
    required this.filled,
    required this.palette,
    required this.onPressed,
    this.height = 48,
    this.fontSize = AcoTypography.titleLarge,
    this.fontWeight = FontWeight.w600,
    this.backgroundColor,
    this.borderColor,
    this.loading = false,
    super.key,
  });

  final String label;
  final bool enabled;
  final bool filled;
  final AcoPalette palette;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool loading;

  Color get _backgroundColor =>
      backgroundColor ?? (filled ? palette.accent : _transparent);

  Color get _borderColor =>
      borderColor ?? (filled ? palette.accent : palette.mutedText);

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled || loading ? 1 : .42,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(double.infinity, height),
      onPressed: enabled ? onPressed : null,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _backgroundColor,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: loading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(
                    color: filled
                        ? (palette.dark ? _black : _white)
                        : palette.primaryText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: filled
                          ? (palette.dark ? _black : _white)
                          : palette.primaryText,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  color: filled
                      ? (palette.dark ? _black : _white)
                      : palette.primaryText,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
              ),
      ),
    ),
  );
}
