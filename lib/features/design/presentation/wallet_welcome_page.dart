part of 'aco_design_shell.dart';

class AcoWalletWelcomePage extends StatefulWidget {
  const AcoWalletWelcomePage({
    required this.dark,
    required this.onWalletReady,
    super.key,
  });

  final bool dark;
  final Future<void> Function(WalletIdentity, String) onWalletReady;

  @override
  State<AcoWalletWelcomePage> createState() => _AcoWalletWelcomePageState();
}

class _AcoWalletWelcomePageState extends State<AcoWalletWelcomePage> {
  _WalletSetupMode _mode = _WalletSetupMode.welcome;
  late final VideoPlayerController _backgroundVideo;
  bool _backgroundVideoReady = false;
  bool _backgroundVideoDisposed = false;
  bool _hasAcceptedTerms = false;

  void _openLegalDocument(LegalDocument document) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LegalDocumentPage(document: document),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _backgroundVideo = VideoPlayerController.asset(
      'assets/videos/login_background.mp4',
    );
    _initializeBackgroundVideo();
  }

  Future<void> _initializeBackgroundVideo() async {
    try {
      await _backgroundVideo.initialize();
      if (_backgroundVideoDisposed) return;
      await _backgroundVideo.setLooping(true);
      if (_backgroundVideoDisposed) return;
      await _backgroundVideo.setVolume(0);
      if (_backgroundVideoDisposed) return;
      await _backgroundVideo.play();
      if (mounted && !_backgroundVideoDisposed) {
        setState(() => _backgroundVideoReady = true);
      }
    } catch (_) {
      // The welcome screen remains usable on platforms without video playback.
    }
  }

  void _startWalletSetup(_WalletSetupMode mode) {
    if (!_hasAcceptedTerms) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: const Text('请先同意用户协议和隐私政策'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _mode = mode);
    // The welcome widget stays mounted while the setup flow is displayed, so
    // release its decoder now instead of keeping it active through wallet
    // creation and biometric authentication.
    unawaited(_disposeBackgroundVideo());
  }

  @override
  void dispose() {
    unawaited(_disposeBackgroundVideo());
    super.dispose();
  }

  Future<void> _disposeBackgroundVideo() async {
    if (_backgroundVideoDisposed) return;
    _backgroundVideoDisposed = true;
    if (mounted && _backgroundVideoReady) {
      setState(() => _backgroundVideoReady = false);
    }
    try {
      await _backgroundVideo.pause();
    } catch (_) {
      // Initialization can still be in flight when the setup flow opens.
    }
    try {
      await _backgroundVideo.dispose();
    } catch (_) {
      // The page can still be replaced if the platform decoder is already
      // being torn down by Android.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(widget.dark);
    if (_mode != _WalletSetupMode.welcome) {
      return _WalletSetupFlow(
        dark: widget.dark,
        mode: _mode,
        requireSecuritySetup: true,
        onBack: () => setState(() => _mode = _WalletSetupMode.welcome),
        onComplete: (identity, mnemonic) async {
          // Release the Android decoder before constructing the wallet home.
          // This avoids a surface migration and a new first-frame render in
          // the same lifecycle turn.
          await _disposeBackgroundVideo();
          await widget.onWalletReady(identity, mnemonic);
        },
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_backgroundVideoReady && !_backgroundVideoDisposed)
          ClipRect(
            child: FittedBox(
              // Preserve the whole portrait scene on tall phones. The video
              // has pillarbox pixels baked into both sides, so crop only that
              // narrow edge area after it is fitted to the viewport.
              fit: BoxFit.fill,
              child: Transform.scale(
                scaleX: 1.22,
                child: SizedBox(
                  width: _backgroundVideo.value.size.width,
                  height: _backgroundVideo.value.size.height,
                  child: VideoPlayer(_backgroundVideo),
                ),
              ),
            ),
          ),
        ColoredBox(
          color: (palette.dark ? _black : palette.background).withValues(
            alpha: .72,
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalInset = (constraints.maxWidth * 0.08).clamp(
                _welcomeContentInsetMin,
                _welcomeContentInsetMax,
              );
              // The supplied mobile artboard anchors the onboarding block in
              // the lower half. Scale that anchor by width so it retains the
              // same composition across phone sizes. The available height also
              // constrains the block, so tall screens do not push it too close
              // to the gesture area and short screens keep the actions visible.
              final designContentTop =
                  _welcomeContentTop *
                  constraints.maxWidth /
                  _welcomeDesignWidth;
              final heightBasedContentTop = constraints.maxHeight * .5;
              final safeContentTop = math.max(
                0.0,
                constraints.maxHeight -
                    _welcomeContentEstimatedHeight -
                    _welcomeContentBottomInset,
              );
              final contentTop = math.min(
                designContentTop,
                math.min(heightBasedContentTop, safeContentTop),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  contentTop,
                  horizontalInset,
                  24,
                ),
                child: _WalletWelcomeContent(
                  palette: palette,
                  hasAcceptedTerms: _hasAcceptedTerms,
                  onTermsChanged: (accepted) =>
                      setState(() => _hasAcceptedTerms = accepted),
                  onOpenUserAgreement: () =>
                      _openLegalDocument(LegalDocument.userAgreement),
                  onOpenPrivacyPolicy: () =>
                      _openLegalDocument(LegalDocument.privacyPolicy),
                  onCreate: () => _startWalletSetup(_WalletSetupMode.create),
                  onImport: () => _startWalletSetup(_WalletSetupMode.import),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WalletWelcomeContent extends StatelessWidget {
  const _WalletWelcomeContent({
    required this.palette,
    required this.hasAcceptedTerms,
    required this.onTermsChanged,
    required this.onOpenUserAgreement,
    required this.onOpenPrivacyPolicy,
    required this.onCreate,
    required this.onImport,
  });

  final AcoPalette palette;
  final bool hasAcceptedTerms;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onOpenUserAgreement;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final widthScale = MediaQuery.sizeOf(context).width / 400.0;
    final titleFontSize = (_welcomeTitleFontSize * widthScale).clamp(
      26.0,
      _welcomeTitleFontSize,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/welcome-brand.png',
          width: _welcomeBrandWidth,
          height: _welcomeBrandHeight,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Aco Chat 品牌标识',
        ),
        const SizedBox(height: _welcomeBrandToTitleGap),
        Transform.translate(
          offset: const Offset(-2, 0),
          child: Padding(
            padding: const EdgeInsets.only(left: 5.3756),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '创建新钱包或导入已有钱包\n开始使用',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: _welcomeTitleToAgreementGap),
        Padding(
          padding: const EdgeInsets.only(left: 5.3756),
          child: _WalletWelcomeAgreement(
            palette: palette,
            selected: hasAcceptedTerms,
            onChanged: onTermsChanged,
            onOpenUserAgreement: onOpenUserAgreement,
            onOpenPrivacyPolicy: onOpenPrivacyPolicy,
          ),
        ),
        const SizedBox(height: _welcomeAgreementToActionsGap),
        Row(
          children: [
            Expanded(
              child: _WalletSetupButton(
                key: const Key('create-wallet-button'),
                label: '创建钱包',
                enabled: true,
                filled: true,
                palette: palette,
                backgroundColor: _accentGreen,
                borderColor: _accentGreen,
                height: _welcomeButtonHeight,
                fontSize: _welcomeActionFontSize,
                fontWeight: FontWeight.w700,
                onPressed: onCreate,
              ),
            ),
            const SizedBox(width: _welcomeButtonGap),
            Expanded(
              child: _WalletSetupButton(
                key: const Key('import-wallet-button'),
                label: '导入钱包',
                enabled: true,
                filled: false,
                palette: palette,
                backgroundColor: _loginSecondarySurface,
                borderColor: _loginSecondarySurface,
                height: _welcomeButtonHeight,
                fontSize: _welcomeActionFontSize,
                fontWeight: FontWeight.w700,
                onPressed: onImport,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _WalletSetupMode { welcome, create, import }

class _WalletWelcomeAgreement extends StatelessWidget {
  const _WalletWelcomeAgreement({
    required this.palette,
    required this.selected,
    required this.onChanged,
    required this.onOpenUserAgreement,
    required this.onOpenPrivacyPolicy,
  });

  final AcoPalette palette;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenUserAgreement;
  final VoidCallback onOpenPrivacyPolicy;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: _welcomeCheckboxTopInset),
        child: Semantics(
          label: '同意用户协议和隐私政策',
          checked: selected,
          child: CupertinoButton(
            key: const Key('wallet-terms-checkbox'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(_welcomeCheckboxSize, _welcomeCheckboxSize),
            onPressed: () => onChanged(!selected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: _welcomeCheckboxSize,
              height: _welcomeCheckboxSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _accentGreen : _transparent,
                border: Border.all(
                  color: selected ? _accentGreen : palette.primaryText,
                  width: .672,
                ),
              ),
              child: selected
                  ? Icon(CupertinoIcons.check_mark, color: _black, size: 10.5)
                  : null,
            ),
          ),
        ),
      ),
      const SizedBox(width: _welcomeCheckboxSize),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _AgreementText(text: '我已阅读并同意 ', palette: palette),
                _AgreementLink(label: '《用户协议》', onPressed: onOpenUserAgreement),
                _AgreementText(text: ' 和 ', palette: palette),
                _AgreementLink(label: '《隐私政策》', onPressed: onOpenPrivacyPolicy),
              ],
            ),
            Text(
              '由 Aladdin Dao Inc 提供',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: _welcomeAgreementFontSize,
                fontWeight: FontWeight.w400,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _AgreementText extends StatelessWidget {
  const _AgreementText({required this.text, required this.palette});

  final String text;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: palette.primaryText,
      fontSize: _welcomeAgreementFontSize,
      fontWeight: FontWeight.w400,
      height: 1.25,
    ),
  );
}

class _AgreementLink extends StatelessWidget {
  const _AgreementLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: Size.zero,
    onPressed: onPressed,
    child: Text(
      label,
      style: const TextStyle(
        color: _accentGreen,
        fontSize: _welcomeAgreementFontSize,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
    ),
  );
}

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

class _WelcomeGlobe extends StatefulWidget {
  const _WelcomeGlobe();

  @override
  State<_WelcomeGlobe> createState() => _WelcomeGlobeState();
}

class _WelcomeGlobeState extends State<_WelcomeGlobe>
    with SingleTickerProviderStateMixin {
  ui.Image? _texture;
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _loadTexture();
  }

  Future<void> _loadTexture() async {
    final data = await rootBundle.load('assets/images/welcome-globe.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _texture = frame.image);
  }

  @override
  void dispose() {
    _rotation.dispose();
    _texture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _rotation,
    builder: (_, _) => _texture == null
        ? _globeImage()
        : CustomPaint(
            size: const Size.square(255),
            painter: _WelcomeGlobePainter(
              texture: _texture!,
              phase: _rotation.value * math.pi * 2,
            ),
          ),
  );

  Widget _globeImage() => Image.asset(
    'assets/images/welcome-globe.png',
    width: 255,
    height: 255,
    filterQuality: FilterQuality.high,
    errorBuilder: (_, _, _) => const SizedBox.square(dimension: 255),
  );
}

class _WelcomeGlobePainter extends CustomPainter {
  const _WelcomeGlobePainter({required this.texture, required this.phase});

  final ui.Image texture;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .457;
    final clip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final background = Paint()..color = const Color(0xFFF8F8F8);
    canvas.drawCircle(center, radius, background);
    canvas.save();
    canvas.clipPath(clip);

    const segments = 48;
    final positions = <Offset>[];
    final textureCoordinates = <Offset>[];
    final vertexIndex = List<int?>.filled(
      (segments + 1) * (segments + 1),
      null,
    );
    final sourceCenter = Offset(texture.width / 2, texture.height / 2);
    final sourceRadius = texture.width * .457;
    final cosPhase = math.cos(phase);
    final sinPhase = math.sin(phase);

    for (var row = 0; row <= segments; row++) {
      final y = -1 + row * 2 / segments;
      for (var column = 0; column <= segments; column++) {
        final x = -1 + column * 2 / segments;
        final distanceSquared = x * x + y * y;
        if (distanceSquared > 1) continue;

        final frontDepth = math.sqrt(1 - distanceSquared);
        final sourceX = x * cosPhase - frontDepth * sinPhase;
        final sourceDepth = x * sinPhase + frontDepth * cosPhase;
        // The supplied artwork has one visible hemisphere. Mirror its texture
        // for the unseen side so the globe remains filled throughout a turn.
        final wrappedX = sourceDepth < 0 ? -sourceX : sourceX;
        vertexIndex[row * (segments + 1) + column] = positions.length;
        positions.add(Offset(center.dx + x * radius, center.dy + y * radius));
        textureCoordinates.add(
          Offset(
            sourceCenter.dx + wrappedX * sourceRadius,
            sourceCenter.dy + y * sourceRadius,
          ),
        );
      }
    }

    final indices = <int>[];
    for (var row = 0; row < segments; row++) {
      for (var column = 0; column < segments; column++) {
        final topLeft = vertexIndex[row * (segments + 1) + column];
        final topRight = vertexIndex[row * (segments + 1) + column + 1];
        final bottomLeft = vertexIndex[(row + 1) * (segments + 1) + column];
        final bottomRight =
            vertexIndex[(row + 1) * (segments + 1) + column + 1];
        if (topLeft == null ||
            topRight == null ||
            bottomLeft == null ||
            bottomRight == null) {
          continue;
        }
        indices.addAll([
          topLeft,
          bottomLeft,
          topRight,
          topRight,
          bottomLeft,
          bottomRight,
        ]);
      }
    }

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: textureCoordinates,
      indices: indices,
    );
    final texturePaint = Paint()
      ..shader = ui.ImageShader(
        texture,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      );
    canvas.drawVertices(vertices, BlendMode.srcOver, texturePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WelcomeGlobePainter oldDelegate) =>
      oldDelegate.texture != texture || oldDelegate.phase != phase;
}
