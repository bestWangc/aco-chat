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
