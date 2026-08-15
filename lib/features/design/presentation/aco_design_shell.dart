import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_session.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/services/biometric_authentication.dart';
import 'package:aco_chat/services/wallet_chain_identity_service.dart';
import 'package:aco_chat/services/sensitive_screen_protection.dart';
import 'package:aco_chat/services/wallet_security.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:aco_chat/services/wallet_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _lime = Color(0xFFA1FF00);
const _danger = Color(0xFFFF3B4E);
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _transparent = Color(0x00000000);
const _loginAccent = Color(0xFFA6DE00);
// Colors and geometry are sampled from 设计图/钱包页-dark.svg.
const _loginSecondarySurface = Color(0xFF515151);
// Coordinates are taken from 设计图/首页-dark.svg (595.28 × 1290.89).
const _loginArtboardWidth = 595.28;
const _loginArtboardHeight = 1290.89;
const _loginContentLeftInset = 36.0;
const _loginContentRightInset = 36.0;
const _loginContentTopInset = 725.0;
// Preserves the SVG's 73.11pt source height at the desktop design scale.
const _loginButtonHeight = 73.5005248;
const _loginButtonGap = 18.0;
const _loginCheckboxSize = 14.0;
const _loginAgreementFontSize = 16.5;
const _loginBrandWidth = 266.0;
const _loginBrandHeight = 52.0;
const _loginTitleFontSize = 42.0;
const _loginBrandToTitleGap = 15.0;
const _loginTitleToAgreementGap = 23.0;
const _loginAgreementToActionsGap = 35.0;
const _loginActionFontSize = 21.0;
const _walletHeaderMuted = Color(0xFF989798);
const _walletHeaderLime = Color(0xFFA6DE00);
const _walletNavInactive = Color(0xFFC2C2C2);
// The wallet screen is rendered in the 800pt application canvas. These
// values are the fixed 800 / 595.28 conversion of the SVG artboard.
const _walletRuntimeRatio = 1.343906;
const _walletHeaderWalletWidth = 206.0;
const _walletHeaderNetworkGap = 60.0;
const _walletHeaderTextSize = 30.0;
const _walletAssetListHorizontalInset = 28.0;
const _walletActionSurface = Color(0xFFEFF0F1);
const _walletActionForeground = Color(0xFF040000);
const _walletActionRadius = 11.55;
const _walletActionHeight = 59.8;
const _walletActionColumnGap = 58.36;
const _walletActionRowGap = 32.2;
const _walletTabsTopGap = 90.8;
const _navLabels = ['钱包', '探索', 'DEX', '广场', '社交'];
const _navAssets = [
  'assets/icons/source_wallet.svg',
  'assets/icons/source_explore.svg',
  'assets/icons/source_dex.svg',
  'assets/icons/source_square.svg',
  'assets/icons/source_social.svg',
];

enum AcoScreen {
  walletHome,
  walletChains,
  walletSwitcher,
  assetDetail,
  backupMnemonic,
  exportPrivateKey,
  send,
  receive,
  scan,
  addTokenV1,
  addTokenV2,
  dexToken,
  dexSwap,
  browserDiscover,
  marketOverview,
  squareFeed,
  socialMessages,
  chatV1,
  chatV2,
  liveStream,
  voiceRoom,
  mining,
  profile,
  profileQr,
  profileEdit,
  profileTheme,
  profileLanguage,
  comingSoon,
  createLive,
}

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
  bool _hasAcceptedTerms = false;

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
      await _backgroundVideo.setLooping(true);
      await _backgroundVideo.setVolume(0);
      await _backgroundVideo.play();
      if (mounted) setState(() => _backgroundVideoReady = true);
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
  }

  @override
  void dispose() {
    _backgroundVideo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(widget.dark);
    if (_mode != _WalletSetupMode.welcome) {
      return _WalletSetupFlow(
        dark: widget.dark,
        mode: _mode,
        onBack: () => setState(() => _mode = _WalletSetupMode.welcome),
        onComplete: widget.onWalletReady,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_backgroundVideoReady)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _backgroundVideo.value.size.width,
              height: _backgroundVideo.value.size.height,
              child: VideoPlayer(_backgroundVideo),
            ),
          ),
        ColoredBox(
          color: (palette.dark ? const Color(0xFF282828) : palette.background)
              .withValues(alpha: .72),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (_, constraints) {
              // Scale every visual value directly from the SVG artboard.
              final scale = constraints.maxWidth / _loginArtboardWidth;
              final contentPadding = EdgeInsets.only(
                left: _loginContentLeftInset * scale,
                top: _loginContentTopInset * scale,
                right: _loginContentRightInset * scale,
              );
              return SingleChildScrollView(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: _loginArtboardHeight * scale,
                  child: Padding(
                    padding: contentPadding,
                    child: _WalletWelcomeContent(
                      palette: palette,
                      scale: scale,
                      hasAcceptedTerms: _hasAcceptedTerms,
                      onTermsChanged: (accepted) =>
                          setState(() => _hasAcceptedTerms = accepted),
                      onCreate: () =>
                          _startWalletSetup(_WalletSetupMode.create),
                      onImport: () =>
                          _startWalletSetup(_WalletSetupMode.import),
                    ),
                  ),
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
    required this.scale,
    required this.hasAcceptedTerms,
    required this.onTermsChanged,
    required this.onCreate,
    required this.onImport,
  });

  final AcoPalette palette;
  final double scale;
  final bool hasAcceptedTerms;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Image.asset(
        'assets/images/welcome-brand.png',
        width: _loginBrandWidth * scale,
        height: _loginBrandHeight * scale,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Aco Chat 品牌标识',
      ),
      SizedBox(height: _loginBrandToTitleGap * scale),
      Padding(
        padding: EdgeInsets.only(left: 8 * scale),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '创建新钱包或导入已有钱包\n开始使用',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: _loginTitleFontSize * scale,
              fontWeight: FontWeight.w400,
              height: 1.18,
            ),
          ),
        ),
      ),
      SizedBox(height: _loginTitleToAgreementGap * scale),
      Padding(
        padding: EdgeInsets.only(left: 8 * scale),
        child: _WalletWelcomeAgreement(
          palette: palette,
          scale: scale,
          selected: hasAcceptedTerms,
          onChanged: onTermsChanged,
        ),
      ),
      SizedBox(height: _loginAgreementToActionsGap * scale),
      Row(
        children: [
          Expanded(
            child: _WalletSetupButton(
              key: const Key('create-wallet-button'),
              label: '创建钱包',
              enabled: true,
              filled: true,
              palette: palette,
              backgroundColor: _loginAccent,
              borderColor: _loginAccent,
              height: _loginButtonHeight * scale,
              fontSize: _loginActionFontSize * scale,
              fontWeight: FontWeight.w700,
              onPressed: onCreate,
            ),
          ),
          SizedBox(width: _loginButtonGap * scale),
          Expanded(
            child: _WalletSetupButton(
              key: const Key('import-wallet-button'),
              label: '导入钱包',
              enabled: true,
              filled: false,
              palette: palette,
              backgroundColor: _loginSecondarySurface,
              borderColor: _loginSecondarySurface,
              height: _loginButtonHeight * scale,
              fontSize: _loginActionFontSize * scale,
              fontWeight: FontWeight.w700,
              onPressed: onImport,
            ),
          ),
        ],
      ),
    ],
  );
}

enum _WalletSetupMode { welcome, create, import }

class _WalletWelcomeAgreement extends StatelessWidget {
  const _WalletWelcomeAgreement({
    required this.palette,
    required this.scale,
    required this.selected,
    required this.onChanged,
  });

  final AcoPalette palette;
  final double scale;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Semantics(
        label: '同意用户协议和隐私政策',
        checked: selected,
        child: CupertinoButton(
          key: const Key('wallet-terms-checkbox'),
          padding: EdgeInsets.zero,
          minimumSize: Size(
            _loginCheckboxSize * scale,
            _loginCheckboxSize * scale,
          ),
          onPressed: () => onChanged(!selected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: _loginCheckboxSize * scale,
            height: _loginCheckboxSize * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _loginAccent : _transparent,
              border: Border.all(
                color: selected ? _loginAccent : palette.primaryText,
                width: scale,
              ),
            ),
            child: selected
                ? Icon(
                    CupertinoIcons.check_mark,
                    color: _black,
                    size: 14 * scale,
                  )
                : null,
          ),
        ),
      ),
      SizedBox(width: _loginCheckboxSize * scale),
      Expanded(
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              color: palette.primaryText,
              fontSize: _loginAgreementFontSize * scale,
              fontWeight: FontWeight.w400,
              height: 1.25,
            ),
            children: const [
              TextSpan(text: '我已阅读并同意 '),
              TextSpan(
                text: '《用户协议》',
                style: TextStyle(color: _loginAccent),
              ),
              TextSpan(text: ' 和 '),
              TextSpan(
                text: '《隐私政策》',
                style: TextStyle(color: _loginAccent),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _WalletSetupFlow extends StatefulWidget {
  const _WalletSetupFlow({
    required this.dark,
    required this.mode,
    required this.onBack,
    required this.onComplete,
  });

  final bool dark;
  final _WalletSetupMode mode;
  final VoidCallback onBack;
  final Future<void> Function(WalletIdentity, String) onComplete;

  @override
  State<_WalletSetupFlow> createState() => _WalletSetupFlowState();
}

class _WalletSetupFlowState extends State<_WalletSetupFlow> {
  final _walletSecurity = WalletSecurity();
  final _chainIdentityService = WalletChainIdentityService();
  final _secretStore = SecureWalletSecretStore();
  final _phraseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _step = 0;
  var _backedUp = false;
  var _isCompletingWalletSetup = false;
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
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-8, 0),
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
                label: _isCompletingWalletSetup ? '正在创建钱包...' : _continueLabel,
                enabled: _canContinue,
                loading: _isCompletingWalletSetup,
                filled: true,
                palette: palette,
                fontSize: AcoTypography.title,
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
    onChanged: (_) => setState(() {}),
    placeholder: '在此粘贴助记词',
    style: TextStyle(color: palette.primaryText),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
    ),
  );

  Widget _securityFields(AcoPalette palette) => Column(
    children: [
      CupertinoTextField(
        key: const Key('wallet-password-field'),
        controller: _passwordController,
        obscureText: true,
        onChanged: (_) => setState(() {}),
        placeholder: '设置钱包密码（至少 8 位）',
        style: TextStyle(color: palette.primaryText),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      const SizedBox(height: 12),
      CupertinoTextField(
        key: const Key('wallet-password-confirm-field'),
        controller: _confirmPasswordController,
        obscureText: true,
        onChanged: (_) => setState(() {}),
        placeholder: '再次输入钱包密码',
        style: TextStyle(color: palette.primaryText),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
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

  bool get _isSecurityStep => _step == _securityStep;

  int get _securityStep => _isCreating ? 3 : 1;

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
    if (_isSecurityStep) return '设置钱包密码，并使用指纹验证以完成操作。';
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
    setState(() => _isCompletingWalletSetup = true);

    // Render the loading state before starting platform authentication.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final authenticated = await BiometricAuthentication.authenticateOrSkip();
    if (!authenticated) {
      if (mounted) setState(() => _isCompletingWalletSetup = false);
      return;
    }

    await SensitiveScreenProtection.setEnabled(false);
    final mnemonic = _isCreating
        ? _createdMnemonic
        : _walletSecurity.normalizeMnemonic(_phraseController.text);
    final identity = WalletIdentity.fromMnemonic(mnemonic);
    await _walletSecurity.saveMnemonic(
      store: _secretStore,
      walletAddress: identity.address,
      mnemonic: mnemonic,
      password: _passwordController.text,
    );
    await _cacheNonEvmAddresses(mnemonic, identity);
    await widget.onComplete(identity, mnemonic);
  }

  Future<void> _cacheNonEvmAddresses(
    String mnemonic,
    WalletIdentity identity,
  ) => _chainIdentityService.cacheNonEvmAddresses(
    mnemonic: mnemonic,
    identity: identity,
  );

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
      backgroundColor ??
      (filled ? (palette.dark ? _lime : _black) : _transparent);

  Color get _borderColor =>
      borderColor ??
      (filled ? (palette.dark ? _lime : _black) : palette.mutedText);

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

class AcoDesignShell extends StatefulWidget {
  const AcoDesignShell({
    this.themeNotifier,
    this.onThemeChanged,
    this.walletIdentity,
    this.accountProfile,
    super.key,
  });

  /// Owned by [AcoApp] so the Cupertino and shadcn themes update together.
  final ValueNotifier<bool>? themeNotifier;
  final ValueChanged<bool>? onThemeChanged;
  final WalletIdentity? walletIdentity;
  final AccountProfile? accountProfile;

  @override
  State<AcoDesignShell> createState() => _AcoDesignShellState();
}

class _AcoDesignShellState extends State<AcoDesignShell> {
  late final ValueNotifier<bool> _isDark;
  late final bool _ownsThemeNotifier;
  int _selectedNav = 0;
  AcoScreen _rootScreen = AcoScreen.walletHome;
  final ValueNotifier<String> _displayName = ValueNotifier<String>('Marry');
  final ValueNotifier<String> _walletName = ValueNotifier<String>('Wallet1');
  final ValueNotifier<int> _selectedWalletChain = ValueNotifier<int>(0);
  TransferToken? _selectedTransferToken;
  int _liveListRevision = 0;
  String? _accountId = '1000000000000000';
  final ValueNotifier<String> _username = ValueNotifier<String>('aco');
  String _language = '简体中文';

  @override
  void initState() {
    super.initState();
    _ownsThemeNotifier = widget.themeNotifier == null;
    _isDark = widget.themeNotifier ?? ValueNotifier<bool>(true);
    _applyAccountProfile(widget.accountProfile);
    _loadWalletName();
  }

  Future<void> _loadWalletName() async {
    final identity = widget.walletIdentity;
    if (identity == null) return;
    final walletName = await WalletPreferences.walletName(identity);
    if (mounted && identity == widget.walletIdentity) {
      _walletName.value = walletName;
    }
  }

  Future<void> _saveWalletName(String name) async {
    final identity = widget.walletIdentity;
    if (identity == null) return;
    final savedName = await WalletPreferences.saveWalletName(identity, name);
    if (mounted && identity == widget.walletIdentity) {
      _walletName.value = savedName;
    }
  }

  void _applyAccountProfile(AccountProfile? profile) {
    if (profile == null) return;
    _accountId = profile.accountId;
    _displayName.value = profile.nickname;
    _username.value = profile.username;
  }

  @override
  void didUpdateWidget(covariant AcoDesignShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldProfile = oldWidget.accountProfile;
    final profile = widget.accountProfile;
    if (profile != null &&
        (oldProfile?.accountId != profile.accountId ||
            oldProfile?.nickname != profile.nickname ||
            oldProfile?.username != profile.username)) {
      _applyAccountProfile(profile);
    }
    if (oldWidget.walletIdentity != widget.walletIdentity) _loadWalletName();
  }

  @override
  void dispose() {
    if (_ownsThemeNotifier) _isDark.dispose();
    _displayName.dispose();
    _walletName.dispose();
    _username.dispose();
    _selectedWalletChain.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    final isDark = !_isDark.value;
    _isDark.value = isDark;
    widget.onThemeChanged?.call(isDark);
  }

  void _selectWalletChain(int index) {
    _selectedWalletChain.value = index;
  }

  void _sendToken(TransferToken token) {
    setState(() => _selectedTransferToken = token);
    _open(AcoScreen.send);
  }

  void _open(AcoScreen screen) {
    if (screen == AcoScreen.walletHome) {
      setState(() {
        _selectedNav = 0;
        _rootScreen = AcoScreen.walletHome;
      });
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final target = switch (screen) {
      AcoScreen.squareFeed || AcoScreen.createLive => AcoScreen.squareFeed,
      AcoScreen.send => AcoScreen.send,
      AcoScreen.receive => AcoScreen.receive,
      AcoScreen.walletChains => AcoScreen.walletChains,
      AcoScreen.walletSwitcher => AcoScreen.walletSwitcher,
      AcoScreen.assetDetail => AcoScreen.assetDetail,
      AcoScreen.backupMnemonic => AcoScreen.backupMnemonic,
      AcoScreen.exportPrivateKey => AcoScreen.exportPrivateKey,
      AcoScreen.scan => AcoScreen.scan,
      AcoScreen.profile => AcoScreen.profile,
      AcoScreen.profileQr => AcoScreen.profileQr,
      AcoScreen.profileEdit => AcoScreen.profileEdit,
      AcoScreen.profileTheme => AcoScreen.profileTheme,
      AcoScreen.profileLanguage => AcoScreen.profileLanguage,
      AcoScreen.addTokenV2 => AcoScreen.addTokenV2,
      AcoScreen.voiceRoom => AcoScreen.voiceRoom,
      _ => AcoScreen.comingSoon,
    };
    final destination = screen == AcoScreen.createLive
        ? AcoScreen.createLive
        : target;
    Navigator.of(context)
        .push<bool>(
          _AcoPageRoute<bool>(
            builder: (_) => _buildSecondaryScreen(destination),
          ),
        )
        .then((created) {
          if (screen == AcoScreen.createLive && created == true && mounted) {
            setState(() => _liveListRevision++);
          }
        });
  }

  Widget _buildSecondaryScreen(AcoScreen screen) => AnimatedBuilder(
    animation: Listenable.merge([
      _isDark,
      _displayName,
      _username,
      _walletName,
      _selectedWalletChain,
    ]),
    builder: (_, _) => AcoScreenPage(
      screen: screen,
      dark: _isDark.value,
      isRoot: false,
      onOpen: _open,
      onThemeToggle: _toggleTheme,
      walletIdentity: widget.walletIdentity,
      walletName: _walletName.value,
      onWalletNameChanged: _saveWalletName,
      walletChainIndex: _selectedWalletChain.value,
      onWalletChainSelected: _selectWalletChain,
      transferToken: _selectedTransferToken,
      onSendTokenSelected: _sendToken,
      accountId: _accountId,
      username: _username.value,
      displayName: _displayName.value,
      onDisplayNameChanged: (name) => _displayName.value = name,
      onUsernameChanged: (username) => _username.value = username,
      language: _language,
      liveListRevision: _liveListRevision,
      onLanguageChanged: (language) => setState(() => _language = language),
    ),
  );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _isDark,
    builder: (_, dark, _) {
      return CupertinoPageScaffold(
        backgroundColor: AcoPalette(dark).background,
        child: _AcoViewport(
          child: SafeArea(
            left: false,
            right: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _displayName,
                      _username,
                      _walletName,
                      _selectedWalletChain,
                    ]),
                    builder: (_, _) => AcoScreenPage(
                      screen: _rootScreen,
                      dark: dark,
                      isRoot: true,
                      onOpen: _open,
                      onThemeToggle: _toggleTheme,
                      walletIdentity: widget.walletIdentity,
                      walletName: _walletName.value,
                      onWalletNameChanged: _saveWalletName,
                      walletChainIndex: _selectedWalletChain.value,
                      onWalletChainSelected: _selectWalletChain,
                      transferToken: _selectedTransferToken,
                      onSendTokenSelected: _sendToken,
                      accountId: _accountId,
                      username: _username.value,
                      displayName: _displayName.value,
                      onDisplayNameChanged: (name) => _displayName.value = name,
                      onUsernameChanged: (username) =>
                          _username.value = username,
                      language: _language,
                      liveListRevision: _liveListRevision,
                      onLanguageChanged: (language) =>
                          setState(() => _language = language),
                    ),
                  ),
                ),
                AcoBottomNav(
                  selected: _selectedNav,
                  dark: dark,
                  onSelected: (index) {
                    const destinations = [
                      AcoScreen.walletHome,
                      AcoScreen.comingSoon,
                      AcoScreen.comingSoon,
                      AcoScreen.squareFeed,
                      AcoScreen.comingSoon,
                    ];
                    setState(() {
                      _selectedNav = index;
                      _rootScreen = destinations[index];
                      if (index == 3) _liveListRevision++;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AcoPageRoute<T> extends CupertinoPageRoute<T> {
  _AcoPageRoute({required super.builder});

  @override
  Color? get barrierColor => null;
}

class AcoPalette {
  const AcoPalette(this.dark);
  final bool dark;

  Color get background => dark ? const Color(0xFF262626) : _white;
  Color get surface => dark ? const Color(0xFF3A3A3A) : const Color(0xFFF4F4F4);
  Color get surfaceRaised =>
      dark ? const Color(0xFF222222) : const Color(0xFFEDEDED);
  Color get primaryText =>
      dark ? const Color(0xFFF7F7F7) : const Color(0xFF151515);
  Color get mutedText =>
      dark ? const Color(0xFF929292) : const Color(0xFF939393);
  Color get border => dark ? const Color(0xFF2D2D2D) : const Color(0xFFE2E2E2);
  Color get navInactive =>
      dark ? const Color(0xFF9E9E9E) : const Color(0xFFC4C4C4);
}

class AcoScreenPage extends StatelessWidget {
  const AcoScreenPage({
    required this.screen,
    required this.dark,
    required this.isRoot,
    required this.onOpen,
    required this.onThemeToggle,
    this.displayName,
    this.accountId,
    this.username,
    this.walletIdentity,
    this.walletSecretStore,
    this.walletName = 'Wallet1',
    this.onWalletNameChanged,
    this.walletChainIndex = 0,
    this.onWalletChainSelected,
    this.transferToken,
    this.onSendTokenSelected,
    this.onDisplayNameChanged,
    this.onUsernameChanged,
    this.language = '简体中文',
    this.liveListRevision = 0,
    this.onLanguageChanged,
    this.live,
    this.initialLives,
    super.key,
  });

  final AcoScreen screen;
  final bool dark;
  final bool isRoot;
  final ValueChanged<AcoScreen> onOpen;
  final VoidCallback onThemeToggle;
  final String? displayName;
  final String? accountId;
  final String? username;
  final WalletIdentity? walletIdentity;
  final WalletSecretStore? walletSecretStore;
  final String walletName;
  final Future<void> Function(String name)? onWalletNameChanged;
  final int walletChainIndex;
  final ValueChanged<int>? onWalletChainSelected;
  final TransferToken? transferToken;
  final ValueChanged<TransferToken>? onSendTokenSelected;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onUsernameChanged;
  final String language;
  final int liveListRevision;
  final ValueChanged<String>? onLanguageChanged;
  final LiveSession? live;
  final List<LiveSession>? initialLives;

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(dark);
    final currentDisplayName = displayName;
    final currentAccountId = accountId;
    final currentUsername = username;
    final page = switch (screen) {
      AcoScreen.walletHome => _WalletHome(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletName: walletName,
        selectedChain: _supportedWalletChains[walletChainIndex],
        onSendTokenSelected: onSendTokenSelected ?? (_) {},
      ),
      AcoScreen.walletChains => _WalletChains(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletName: walletName,
        selectedChain: walletChainIndex,
        onChainSelected: onWalletChainSelected ?? (_) {},
      ),
      AcoScreen.walletSwitcher => _WalletChains(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletName: walletName,
        selectedChain: walletChainIndex,
        onChainSelected: onWalletChainSelected ?? (_) {},
      ),
      AcoScreen.assetDetail => _AssetDetail(
        palette: palette,
        walletIdentity: walletIdentity,
        selectedChain: _supportedWalletChains[walletChainIndex],
        walletName: walletName,
        onWalletNameChanged: onWalletNameChanged,
        onOpen: onOpen,
      ),
      AcoScreen.backupMnemonic => _BackupMnemonicFlow(
        palette: palette,
        walletIdentity: walletIdentity,
        secretStore: walletSecretStore ?? SecureWalletSecretStore(),
      ),
      AcoScreen.exportPrivateKey => _BackupMnemonicFlow(
        palette: palette,
        walletIdentity: walletIdentity,
        secretStore: walletSecretStore ?? SecureWalletSecretStore(),
        exportType: _SensitiveExportType.privateKey,
      ),
      AcoScreen.send => _SendTransferPage(
        palette: palette,
        token:
            transferToken ??
            _transferTokensForChain(
              _supportedWalletChains[walletChainIndex],
            ).first,
      ),
      AcoScreen.receive => _ReceivePage(
        palette: palette,
        walletIdentity: walletIdentity,
        selectedChain: _supportedWalletChains[walletChainIndex],
      ),
      AcoScreen.scan => _ScanPage(palette: palette),
      AcoScreen.addTokenV1 => _AddTokenPage(palette: palette),
      AcoScreen.addTokenV2 => _AddTokenPage(palette: palette),
      AcoScreen.dexToken => _DexTokenPage(palette: palette, onOpen: onOpen),
      AcoScreen.dexSwap => _DexSwapPage(palette: palette),
      AcoScreen.browserDiscover => _BrowserDiscoverPage(
        palette: palette,
        onOpen: onOpen,
      ),
      AcoScreen.marketOverview => _MarketOverviewPage(palette: palette),
      AcoScreen.squareFeed => _SquareFeedPage(
        key: ValueKey('square-feed-$liveListRevision'),
        palette: palette,
        onOpen: onOpen,
        initialLives: initialLives,
      ),
      AcoScreen.socialMessages => _SocialMessagesPage(
        palette: palette,
        onOpen: onOpen,
      ),
      AcoScreen.chatV1 => _ChatPage(palette: palette, version: 1),
      AcoScreen.chatV2 => _ChatPage(palette: palette, version: 2),
      AcoScreen.liveStream => _LiveStreamPage(palette: palette, onOpen: onOpen),
      AcoScreen.voiceRoom => _VoiceRoomPage(palette: palette, live: live),
      AcoScreen.mining => _MiningPage(palette: palette),
      AcoScreen.profile =>
        currentDisplayName == null ||
                currentAccountId == null ||
                currentUsername == null
            ? _ProfileLoadingPage(palette: palette)
            : _ProfilePage(
                palette: palette,
                onOpen: onOpen,
                displayName: currentDisplayName,
                accountId: currentAccountId,
                username: currentUsername,
                onBack: isRoot ? null : () => Navigator.of(context).maybePop(),
              ),
      AcoScreen.profileEdit =>
        currentDisplayName == null ||
                currentAccountId == null ||
                currentUsername == null
            ? _ProfileLoadingPage(palette: palette)
            : _ProfileEditPage(
                palette: palette,
                initialName: currentDisplayName,
                initialUsername: currentUsername,
                accountId: currentAccountId,
                onDisplayNameChanged: onDisplayNameChanged,
                onUsernameChanged: onUsernameChanged,
              ),
      AcoScreen.profileQr =>
        currentDisplayName == null ||
                currentAccountId == null ||
                currentUsername == null
            ? _ProfileLoadingPage(palette: palette)
            : _ProfileQrPage(
                palette: palette,
                displayName: currentDisplayName,
                accountId: currentAccountId,
                username: currentUsername,
                onBack: () => Navigator.of(context).maybePop(),
              ),
      AcoScreen.profileTheme => _ThemeSettingsPage(
        palette: palette,
        dark: dark,
        onThemeToggle: onThemeToggle,
      ),
      AcoScreen.profileLanguage => _LanguageSettingsPage(
        palette: palette,
        initialLanguage: language,
        onLanguageChanged: onLanguageChanged,
      ),
      AcoScreen.comingSoon => _ComingSoonPage(palette: palette),
      AcoScreen.createLive => _CreateLivePage(palette: palette),
    };

    return SizedBox.expand(
      child: ColoredBox(
        color: palette.background,
        child: _AcoViewport(
          child: SafeArea(
            top: !isRoot,
            minimum: isRoot ? EdgeInsets.zero : const EdgeInsets.only(top: 24),
            left: false,
            right: false,
            bottom: false,
            child: page,
          ),
        ),
      ),
    );
  }
}

class _AcoViewport extends StatelessWidget {
  const _AcoViewport({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: child,
  );
}

class AcoBottomNav extends StatelessWidget {
  const AcoBottomNav({
    required this.selected,
    required this.dark,
    required this.onSelected,
    super.key,
  });

  final int selected;
  final bool dark;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) {
      final palette = AcoPalette(dark);
      const scale = _walletRuntimeRatio;
      return ColoredBox(
        color: dark ? const Color(0xFF000000) : palette.background,
        child: SizedBox(
          // Match the design artboard's bottom navigation baseline.
          height: 106 * scale,
          child: Transform.translate(
            offset: Offset(0, -7 * scale),
            child: Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: Row(
                children: List.generate(
                  _navLabels.length,
                  (index) => Expanded(
                    child: Semantics(
                      button: true,
                      selected: selected == index,
                      label: _navLabels[index],
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(44 * scale, 44 * scale),
                        onPressed: () => onSelected(index),
                        child: _NavItem(
                          index: index,
                          active: selected == index,
                          palette: palette,
                          scale: scale,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.active,
    required this.palette,
    this.scale = 1,
  });
  final int index;
  final bool active;
  final AcoPalette palette;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (palette.dark ? _walletHeaderLime : palette.primaryText)
        : (palette.dark ? _walletNavInactive : palette.navInactive);
    if (index == 2) {
      return SizedBox(
        width: 48 * scale,
        height: 76 * scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -8 * scale,
              left: -4 * scale,
              width: 55 * scale,
              height: 52 * scale,
              child: active && !palette.dark
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/source_dex_fill.svg',
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            _lime,
                            BlendMode.srcIn,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/source_dex_wordmark.svg',
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            palette.primaryText,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    )
                  : !active && !palette.dark
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/source_dex_inactive.svg',
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFE4E4E4),
                            BlendMode.srcIn,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/source_dex_wordmark.svg',
                          fit: BoxFit.contain,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFC4C4C4),
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    )
                  : SvgPicture.asset(
                      active
                          ? 'assets/icons/source_dex_active.svg'
                          : 'assets/icons/source_dex_inactive.svg',
                      fit: BoxFit.contain,
                    ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: 48 * scale,
      height: 76 * scale,
      child: Column(
        children: [
          SizedBox(
            width: 32 * scale,
            height: 32 * scale,
            child: SvgPicture.asset(
              _navAssets[index],
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 3 * scale),
          SizedBox(
            height: 26 * scale,
            child: Text(
              _navLabels[index],
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: AcoTypography.bodySmall * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AcoPageHeader extends StatelessWidget {
  const AcoPageHeader({
    required this.palette,
    this.title,
    this.onBack,
    this.right,
    this.titleFollowsBack = false,
    this.backButtonOffset = const Offset(-8, 0),
    super.key,
  });
  final AcoPalette palette;
  final String? title;
  final VoidCallback? onBack;
  final Widget? right;
  final bool titleFollowsBack;
  final Offset backButtonOffset;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: backButtonOffset,
              child: AcoIconButton(
                icon: CupertinoIcons.back,
                palette: palette,
                label: '返回',
                onPressed: onBack!,
              ),
            ),
          ),
        if (title != null)
          Align(
            alignment: titleFollowsBack
                ? Alignment.centerLeft
                : Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(left: titleFollowsBack ? 40 : 0),
              child: Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodyEmphasis,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (right != null)
          Align(alignment: Alignment.centerRight, child: right!),
      ],
    ),
  );
}

class AcoIconButton extends StatelessWidget {
  const AcoIconButton({
    required this.icon,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.size = 25,
    super.key,
  });
  final IconData icon;
  final AcoPalette palette;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    child: SizedBox(
      width: 44,
      height: 44,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: onPressed,
        child: Icon(icon, color: palette.primaryText, size: size),
      ),
    ),
  );
}

class AcoTopActions extends StatelessWidget {
  const AcoTopActions({
    required this.palette,
    required this.onOpen,
    this.scale = 1,
    super.key,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final double scale;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _AcoDesignActionButton(
        asset: 'assets/icons/source_scan.svg',
        palette: palette,
        scale: scale,
        label: '扫描二维码',
        onPressed: () => onOpen(AcoScreen.scan),
      ),
      SizedBox(width: 23 * scale),
      _AcoDesignActionButton(
        asset: 'assets/icons/source_person.svg',
        palette: palette,
        scale: scale,
        label: '账户',
        onPressed: () => onOpen(AcoScreen.profile),
      ),
    ],
  );
}

class _AcoDesignActionButton extends StatelessWidget {
  const _AcoDesignActionButton({
    required this.asset,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.scale = 1,
  });

  final String asset;
  final AcoPalette palette;
  final String label;
  final VoidCallback onPressed;
  final double scale;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size(44 * scale, 44 * scale),
      onPressed: onPressed,
      child: SvgPicture.asset(
        asset,
        // The SVG header icons are not square on the artboard: the scanner
        // mark is 27.9×34.3pt and the account mark is 25.4×28pt.
        width: (asset.contains('source_scan') ? 27.9 : 25.4) * scale,
        height: (asset.contains('source_scan') ? 34.3 : 28) * scale,
        colorFilter: ColorFilter.mode(
          palette.dark ? _white : palette.primaryText,
          BlendMode.srcIn,
        ),
      ),
    ),
  );
}

class AcoRootHeader extends StatelessWidget {
  const AcoRootHeader({
    required this.palette,
    required this.onOpen,
    this.title,
    this.trailing,
    this.onLeadingPressed,
    this.leadingButtonOffset = Offset.zero,
    this.scale = 1,
    super.key,
  });

  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String? title;
  final Widget? trailing;
  final VoidCallback? onLeadingPressed;
  final Offset leadingButtonOffset;
  final double scale;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46 * scale,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (onLeadingPressed != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: leadingButtonOffset,
              child: AcoIconButton(
                icon: CupertinoIcons.back,
                palette: palette,
                label: '返回',
                onPressed: onLeadingPressed!,
              ),
            ),
          ),
        if (title != null)
          Text(
            title!,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.title,
              fontWeight: FontWeight.w700,
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child:
              trailing ??
              AcoTopActions(palette: palette, onOpen: onOpen, scale: scale),
        ),
      ],
    ),
  );
}

class _TokenMark extends StatelessWidget {
  const _TokenMark();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.785398,
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF969DBE),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _NetworkGlyph extends StatelessWidget {
  const _NetworkGlyph({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/lucide/network.svg',
    width: 24,
    height: 24,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class AcoSurface extends StatelessWidget {
  const AcoSurface({
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.border = false,
    super.key,
  });
  final AcoPalette palette;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: border ? Border.all(color: palette.border) : null,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: shad.ShadCard(
      padding: padding,
      radius: BorderRadius.circular(radius),
      backgroundColor: palette.surface,
      child: child,
    ),
  );
}

class AcoLimeButton extends StatelessWidget {
  const AcoLimeButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.height,
    this.fontSize = AcoTypography.bodySmall,
    this.backgroundColor = _lime,
    this.fontWeight = FontWeight.w700,
    super.key,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;
  final double? height;
  final double fontSize;
  final Color backgroundColor;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height ?? (compact ? 36 : 42),
    child: shad.ShadButton(
      backgroundColor: backgroundColor,
      foregroundColor: _black,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _black, size: 17),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
          ),
        ],
      ),
    ),
  );
}

enum AcoSearchVariant { standard, squareComposer }

class AcoSearch extends StatelessWidget {
  const AcoSearch({
    required this.palette,
    required this.hint,
    this.onSubmit,
    this.action,
    this.height = 42,
    this.submitIcon = CupertinoIcons.arrow_right,
    this.variant = AcoSearchVariant.standard,
    super.key,
  });
  final AcoPalette palette;
  final String hint;
  final VoidCallback? onSubmit;
  final Widget? action;
  final double height;
  final IconData submitIcon;
  final AcoSearchVariant variant;

  @override
  Widget build(BuildContext context) {
    final isSquareComposer = variant == AcoSearchVariant.squareComposer;
    final submitWidth = isSquareComposer ? 56.0 : height;
    final borderColor = _borderColor(isSquareComposer);
    final iconColor = palette.dark
        ? (isSquareComposer ? const Color(0xFF191919) : const Color(0xFFF7F7F7))
        : palette.mutedText;
    final hintColor = palette.dark
        ? (isSquareComposer ? const Color(0xFFF2F2F2) : const Color(0xFF888888))
        : palette.mutedText;
    final submitChild = submitIcon == CupertinoIcons.add
        ? Center(
            child: SizedBox(
              width: isSquareComposer ? 20 : 32,
              height: isSquareComposer ? 20 : 32,
              child: Image.asset(
                palette.dark
                    ? 'assets/icons/design_plus_dark.png'
                    : 'assets/icons/design_plus_light.png',
                filterQuality: FilterQuality.high,
              ),
            ),
          )
        : Icon(submitIcon, color: _black, size: height > 48 ? 30 : 24);

    return Container(
      height: height,
      clipBehavior: isSquareComposer ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            CupertinoIcons.search,
            color: iconColor,
            size: isSquareComposer ? 16 : 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(color: hintColor, fontSize: AcoTypography.body),
            ),
          ),
          ?action,
          if (onSubmit != null)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size(submitWidth, height),
              onPressed: onSubmit,
              child: Container(
                key: isSquareComposer
                    ? const Key('square-search-submit')
                    : null,
                width: submitWidth,
                height: height,
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
                child: submitChild,
              ),
            ),
        ],
      ),
    );
  }

  Color _borderColor(bool isSquareComposer) {
    if (!palette.dark) return palette.border;
    return isSquareComposer ? const Color(0xFFD7D7D7) : const Color(0xFFC1C1C1);
  }
}

const _defaultAvatarAsset = 'assets/design_svg/source/images/img1.jpg';
const _liveRoomHostAvatarAsset = 'assets/design_svg/source/images/img3.jpg';
const _liveRoomListenerAvatarAsset = 'assets/design_svg/source/images/img5.jpg';

class AcoAvatar extends StatelessWidget {
  const AcoAvatar({
    this.large = false,
    this.size,
    this.assetPath = _defaultAvatarAsset,
    super.key,
  });
  final bool large;
  final double? size;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (large ? 76.0 : 42.0);
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: resolvedSize,
        height: resolvedSize,
        fit: BoxFit.cover,
        semanticLabel: '用户头像',
      ),
    );
  }
}

void _showNotice(BuildContext context, String title, String message) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => CupertinoActionSheet(
      title: Text(title),
      message: Text(message),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
    ),
  );
}

void showAcoAlertNotice(BuildContext context, String title, String message) {
  showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

class _WalletToken {
  const _WalletToken(this.symbol, this.title);

  final String symbol;
  final String title;
}

class _WalletChain {
  const _WalletChain({
    required this.asset,
    required this.label,
    required this.nativeToken,
    required this.network,
    this.backgroundColor,
    this.derivedAddressKey,
  });

  final String asset;
  final String label;
  final _WalletToken nativeToken;
  final WalletNetwork network;
  final Color? backgroundColor;
  final String? derivedAddressKey;
}

const _supportedWalletChains = [
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-ethereum.png',
    label: '以太坊',
    nativeToken: _WalletToken('ETH', 'Ethereum'),
    network: WalletNetwork.ethereum,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-bsc.png',
    label: 'BSC',
    nativeToken: _WalletToken('BNB', 'BNB'),
    network: WalletNetwork.bsc,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-polygon.png',
    label: 'Polygon',
    nativeToken: _WalletToken('POL', 'Polygon Ecosystem Token'),
    network: WalletNetwork.polygon,
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/tron.svg',
    label: 'Tron',
    nativeToken: _WalletToken('TRX', 'TRON'),
    network: WalletNetwork.tron,
    derivedAddressKey: 'tron',
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-solana.png',
    label: 'Solana',
    nativeToken: _WalletToken('SOL', 'Solana'),
    network: WalletNetwork.solana,
    derivedAddressKey: 'solana',
  ),
  _WalletChain(
    asset: 'assets/icons/crypto/domi/chains/network-base.png',
    label: 'Base',
    nativeToken: _WalletToken('ETH', 'Ethereum'),
    network: WalletNetwork.base,
    backgroundColor: Color(0xFF0052FF),
  ),
];

Future<String?> _addressForChain(
  WalletIdentity? identity,
  _WalletChain chain,
) async {
  if (identity == null || identity.address.isEmpty) return null;
  final derivedAddressKey = chain.derivedAddressKey;
  if (derivedAddressKey == null) return identity.address;
  return (await WalletPreferences.derivedAddresses(
    identity,
  ))[derivedAddressKey];
}

class TransferToken {
  const TransferToken({
    required this.symbol,
    required this.name,
    required this.chain,
    required this.iconAsset,
    required this.feeSymbol,
    this.availableAmount = '0',
  });

  final String symbol;
  final String name;
  final String chain;
  final String iconAsset;
  final String feeSymbol;
  final String availableAmount;
}

List<TransferToken> _transferTokensForChain(_WalletChain chain) {
  final nativeToken = TransferToken(
    symbol: chain.nativeToken.symbol,
    name: chain.nativeToken.title,
    chain: chain.label,
    feeSymbol: chain.nativeToken.symbol,
    iconAsset: switch (chain.network) {
      WalletNetwork.ethereum ||
      WalletNetwork.base => 'assets/icons/crypto/tokens/eth.svg',
      WalletNetwork.bsc => 'assets/icons/crypto/tokens/bnb.svg',
      WalletNetwork.polygon => 'assets/icons/crypto/tokens/matic.svg',
      WalletNetwork.tron => 'assets/icons/crypto/tokens/trx.svg',
      WalletNetwork.solana => 'assets/icons/crypto/tokens/sol.svg',
    },
  );
  return [
    nativeToken,
    TransferToken(
      symbol: 'USDT',
      name: 'Tether USD',
      chain: chain.label,
      iconAsset: 'assets/icons/crypto/domi/tokens/usdt.png',
      feeSymbol: chain.nativeToken.symbol,
    ),
  ];
}

class _TokenAvatar extends StatelessWidget {
  const _TokenAvatar({required this.token});

  final TransferToken token;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
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
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择转账代币',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.palette.primaryText,
                          fontSize: AcoTypography.titleLarge,
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
                        size: 23,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.palette.border),
                  ),
                  child: CupertinoTextField(
                    key: const Key('send-token-search'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    placeholder: '搜索代币名称或符号',
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        CupertinoIcons.search,
                        color: widget.palette.mutedText,
                        size: 21,
                      ),
                    ),
                    placeholderStyle: TextStyle(
                      color: widget.palette.mutedText,
                    ),
                    style: TextStyle(color: widget.palette.primaryText),
                    cursorColor: _lime,
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              onPressed: () => Navigator.of(context).pop(token),
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
                                            fontSize: AcoTypography.title,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          token.name,
                                          style: TextStyle(
                                            color: widget.palette.mutedText,
                                            fontSize: AcoTypography.bodySmall,
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
                                          fontSize: AcoTypography.bodyEmphasis,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '可用余额',
                                        style: TextStyle(
                                          color: widget.palette.mutedText,
                                          fontSize: AcoTypography.caption,
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
    _showNotice(context, '暂未发送', '链上签名和广播将在后续版本开放。');
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '转账',
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
                    placeholder: '输入或粘贴钱包地址',
                    placeholderStyle: TextStyle(
                      color: widget.palette.mutedText,
                    ),
                    style: TextStyle(color: widget.palette.primaryText),
                    cursorColor: _lime,
                    padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
                    decoration: const BoxDecoration(color: _transparent),
                    suffix: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(42, 42),
                      onPressed: () =>
                          _showNotice(context, '扫码', '请使用钱包首页的扫码功能。'),
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
                                fontSize: AcoTypography.title,
                              ),
                              style: TextStyle(
                                color: widget.palette.primaryText,
                                fontSize: AcoTypography.title,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: _lime,
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
                                  color: _lime.withValues(alpha: .75),
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Text(
                                '全部',
                                style: TextStyle(
                                  color: _lime,
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
                          color: _lime,
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
                                  fontSize: AcoTypography.bodyEmphasis,
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
                            fontWeight: FontWeight.w600,
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
                color: _canConfirm ? _lime : widget.palette.surfaceRaised,
                disabledColor: widget.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  '确认转账',
                  style: TextStyle(
                    color: _canConfirm ? _black : widget.palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
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
            fontSize: AcoTypography.title,
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

class _WalletHome extends StatefulWidget {
  const _WalletHome({
    required this.palette,
    required this.onOpen,
    required this.selectedChain,
    required this.onSendTokenSelected,
    required this.walletName,
    this.walletIdentity,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final _WalletChain selectedChain;
  final ValueChanged<TransferToken> onSendTokenSelected;
  final String walletName;
  final WalletIdentity? walletIdentity;

  @override
  State<_WalletHome> createState() => _WalletHomeState();
}

class _WalletHomeState extends State<_WalletHome> {
  late final WalletPortfolioService _portfolioService;
  late Future<List<WalletBalance>> _balancesFuture;
  late List<WalletBalance> _initialBalances;
  final Map<WalletNetwork, List<WalletBalance>> _balanceCache = {};
  final LayerLink _walletActionsLink = LayerLink();
  OverlayEntry? _walletActionsEntry;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _portfolioService = WalletPortfolioService();
    _initialBalances = _placeholderBalances();
    _balancesFuture = _loadAndCacheBalances(widget.selectedChain.network);
  }

  @override
  void didUpdateWidget(covariant _WalletHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedChain.network != widget.selectedChain.network ||
        oldWidget.walletIdentity != widget.walletIdentity) {
      _reloadBalances();
    }
  }

  Future<List<WalletBalance>> _loadBalances(WalletNetwork network) async {
    final identity = widget.walletIdentity;
    if (identity == null) return const [];
    final addresses = await WalletPreferences.derivedAddresses(identity);
    return _portfolioService.loadBalances(
      network: network,
      identity: identity,
      derivedAddresses: addresses,
    );
  }

  Future<List<WalletBalance>> _loadAndCacheBalances(
    WalletNetwork network,
  ) async {
    final balances = await _loadBalances(network);
    _balanceCache[network] = balances;
    return balances;
  }

  List<WalletBalance> _placeholderBalances() {
    final chain = widget.selectedChain;
    final identity = widget.walletIdentity;
    final decimals = switch (chain.network) {
      WalletNetwork.tron => 6,
      WalletNetwork.solana => 9,
      _ => 18,
    };
    final native = WalletBalance(
      chain: chain.label,
      symbol: chain.nativeToken.symbol,
      assetName: chain.nativeToken.title,
      isNative: true,
      address: identity?.address ?? '',
      decimals: decimals,
      balance: BigInt.zero,
    );
    return [
      native,
      WalletBalance(
        chain: chain.label,
        symbol: 'USDT',
        assetName: 'Tether USD',
        isNative: false,
        address: identity?.address ?? '',
        decimals: 6,
        balance: BigInt.zero,
      ),
    ];
  }

  void _reloadBalances() {
    final network = widget.selectedChain.network;
    final balancesFuture = _loadAndCacheBalances(network);
    setState(() {
      _balancesFuture = balancesFuture;
      _initialBalances = _balanceCache[network] ?? _placeholderBalances();
    });
  }

  Future<void> _showSendTokenPicker() async {
    final token = await showCupertinoModalPopup<TransferToken>(
      context: context,
      builder: (_) => _SendTokenPicker(
        palette: widget.palette,
        tokens: _transferTokensForChain(widget.selectedChain),
      ),
    );
    if (token != null && mounted) widget.onSendTokenSelected(token);
  }

  void _dismissWalletActions() {
    _walletActionsEntry?.remove();
    _walletActionsEntry = null;
  }

  @override
  void dispose() {
    _dismissWalletActions();
    _portfolioService.close();
    super.dispose();
  }

  void _showWalletActions() {
    if (_walletActionsEntry != null) {
      _dismissWalletActions();
      return;
    }

    _walletActionsEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissWalletActions,
            ),
          ),
          CompositedTransformFollower(
            link: _walletActionsLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, -7),
            child: Semantics(
              container: true,
              label: '钱包操作菜单',
              child: Container(
                width: 154,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.palette.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WalletMenuItem(
                      icon: CupertinoIcons.refresh,
                      label: '刷新列表',
                      palette: widget.palette,
                      onPressed: () {
                        _dismissWalletActions();
                        _reloadBalances();
                      },
                    ),
                    _WalletMenuItem(
                      icon: CupertinoIcons.add,
                      label: '添加代币',
                      palette: widget.palette,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_walletActionsEntry!);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) {
      // The wallet artboard intentionally uses light action cards on black.
      final actionSurface = _walletActionSurface;
      final actionForeground = _walletActionForeground;
      // The artboard has already been converted to the 800pt application
      // canvas; no runtime scaling is applied here.
      const scale = _walletRuntimeRatio;
      return ColoredBox(
        color: widget.palette.dark
            ? const Color(0xFF000000)
            : widget.palette.background,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                52 * scale,
                34 * scale,
                52 * scale,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AcoRootHeader(
                    palette: widget.palette,
                    onOpen: widget.onOpen,
                    scale: scale,
                  ),
                  // The 44pt control is vertically centered; 59pt places
                  // the wallet glyph itself at the SVG's y=144 boundary.
                  SizedBox(height: 59 * scale),
                  Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 10 * scale),
                        child: Semantics(
                          button: true,
                          label: '切换钱包',
                          child: SizedBox(
                            width: _walletHeaderWalletWidth * scale,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 44 * scale),
                              onPressed: () =>
                                  widget.onOpen(AcoScreen.walletSwitcher),
                              child: Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/wallet_selector.svg',
                                    width: 37.9206 * scale,
                                    height: 33.6409 * scale,
                                  ),
                                  SizedBox(width: 20 * scale),
                                  Flexible(
                                    child: Text(
                                      widget.walletName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _walletHeaderMuted,
                                        fontSize: _walletHeaderTextSize * scale,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 18 * scale),
                                  SvgPicture.asset(
                                    'assets/icons/wallet_selector_chevron.svg',
                                    width: 15.5 * scale,
                                    height: 13.42 * scale,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: _walletHeaderNetworkGap * scale),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: '切换网络',
                          child: GestureDetector(
                            key: const Key('wallet-network-selector'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onOpen(AcoScreen.walletChains),
                            child: Row(
                              children: [
                                Container(
                                  width: 20 * scale,
                                  height: 20 * scale,
                                  decoration: const BoxDecoration(
                                    color: _walletHeaderLime,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 17 * scale),
                                Flexible(
                                  child: Text(
                                    widget.selectedChain.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _walletHeaderMuted,
                                      fontSize: _walletHeaderTextSize * scale,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22 * scale),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'usd',
                        style: TextStyle(
                          color: widget.palette.mutedText,
                          fontSize: 20 * scale,
                        ),
                      ),
                      SizedBox(width: 14 * scale),
                      Text(
                        '0',
                        style: TextStyle(
                          color: widget.palette.primaryText,
                          fontSize: 64 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 43 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: '发送资产',
                          palette: widget.palette,
                          height: _walletActionHeight * scale,
                          fontSize: 20 * scale,
                          backgroundColor: _walletHeaderLime,
                          foregroundColor: _walletActionForeground,
                          radius: _walletActionRadius * scale,
                          fontWeight: FontWeight.w600,
                          onPressed: _showSendTokenPicker,
                        ),
                      ),
                      SizedBox(width: _walletActionColumnGap * scale),
                      Expanded(
                        child: _OutlineButton(
                          label: '接收资产',
                          icon: null,
                          palette: widget.palette,
                          height: _walletActionHeight * scale,
                          fontSize: 20 * scale,
                          backgroundColor: actionSurface,
                          foregroundColor: actionForeground,
                          radius: _walletActionRadius * scale,
                          fontWeight: FontWeight.w600,
                          onPressed: () => widget.onOpen(AcoScreen.receive),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _walletActionRowGap * scale),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: '闪兑',
                          icon: CupertinoIcons.bolt_fill,
                          palette: widget.palette,
                          height: _walletActionHeight * scale,
                          fontSize: 20 * scale,
                          leadingImageAsset:
                              'assets/icons/wallet_swap_action.png',
                          iconSize: 21.5 * scale,
                          iconGap: 10 * scale,
                          backgroundColor: actionSurface,
                          foregroundColor: actionForeground,
                          radius: _walletActionRadius * scale,
                          fontWeight: FontWeight.w600,
                          onPressed: null,
                        ),
                      ),
                      SizedBox(width: _walletActionColumnGap * scale),
                      Expanded(
                        child: _OutlineButton(
                          label: '扫码',
                          icon: CupertinoIcons.qrcode_viewfinder,
                          palette: widget.palette,
                          height: _walletActionHeight * scale,
                          fontSize: 20 * scale,
                          leadingAsset: 'assets/icons/source_scan.svg',
                          iconSize: 20 * scale,
                          iconGap: 10 * scale,
                          backgroundColor: actionSurface,
                          foregroundColor: actionForeground,
                          radius: _walletActionRadius * scale,
                          fontWeight: FontWeight.w600,
                          onPressed: () => widget.onOpen(AcoScreen.scan),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _walletTabsTopGap * scale),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 70.06 * scale,
                right: _walletAssetListHorizontalInset * scale,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SectionTabs(
                      palette: widget.palette,
                      scale: scale,
                      labels: const ['资产', 'NFT', '最近活动'],
                      selected: _selectedTab,
                      disabledIndexes: const {1, 2},
                      onChanged: (index) =>
                          setState(() => _selectedTab = index),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '添加代币',
                    child: CompositedTransformTarget(
                      link: _walletActionsLink,
                      child: Transform.translate(
                        offset: Offset(0, -6 * scale),
                        child: SizedBox(
                          width: 44 * scale,
                          height: 36 * scale,
                          child: CupertinoButton(
                            key: const Key('add-token-button'),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(44 * scale, 36 * scale),
                            onPressed: _showWalletActions,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: SvgPicture.asset(
                                'assets/icons/wallet_tabs_add.svg',
                                width: 25.22 * scale,
                                height: 25.22 * scale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<WalletBalance>>(
                key: ValueKey(widget.selectedChain.network),
                future: _balancesFuture,
                initialData: _initialBalances,
                builder: (context, snapshot) {
                  final balances = snapshot.data ?? const <WalletBalance>[];
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      51.42 * scale,
                      17 * scale,
                      _walletAssetListHorizontalInset * scale,
                      22 * scale,
                    ),
                    itemCount: balances.isEmpty ? 1 : balances.length,
                    itemBuilder: (context, index) {
                      if (balances.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.only(top: 24 * scale),
                          child: Text(
                            '地址派生中，请稍后刷新。',
                            style: TextStyle(color: widget.palette.mutedText),
                          ),
                        );
                      }
                      final balance = balances[index];
                      final amount = formatChainAmount(
                        balance.balance ?? BigInt.zero,
                        decimals: balance.decimals,
                      );
                      return _WalletAssetRow(
                        palette: widget.palette,
                        scale: scale,
                        symbol: balance.symbol,
                        title: balance.assetName,
                        amount: amount,
                        value: '≈0.00 USD',
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

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
    minimumSize: const Size.fromHeight(82),
    onPressed: onPressed,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.title,
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
    width: 28,
    height: 28,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(CupertinoIcons.chevron_right, color: color, size: 28),
        Transform.translate(
          offset: const Offset(-0.75, 0),
          child: Icon(CupertinoIcons.chevron_right, color: color, size: 28),
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
    height: 165,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: palette.dark ? palette.background : palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: child,
    ),
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
      height: 47,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: _lime,
        borderRadius: BorderRadius.circular(24),
        onPressed: onPressed,
        child: const Text(
          '删除钱包',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: AcoTypography.title,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _WalletMenuItem extends StatelessWidget {
  const _WalletMenuItem({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final AcoPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onPressed != null,
    enabled: onPressed != null,
    label: label,
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      minimumSize: const Size.fromHeight(42),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, color: palette.primaryText, size: 17),
          const SizedBox(width: 9),
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

class _WalletChains extends StatefulWidget {
  const _WalletChains({
    required this.palette,
    required this.onOpen,
    required this.selectedChain,
    required this.onChainSelected,
    required this.walletName,
    this.walletIdentity,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final int selectedChain;
  final ValueChanged<int> onChainSelected;
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
    if (oldWidget.selectedChain != widget.selectedChain) {
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

  Future<List<_WalletListItem>> _loadWallets([int? chainIndex]) async {
    final address = await _addressForChain(
      widget.walletIdentity,
      _supportedWalletChains[chainIndex ?? _selectedChain],
    );
    if (address == null || address.isEmpty) return const [];
    return [_WalletListItem(address: address)];
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '钱包详情',
    child: Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(104, 8, 20, 8),
              child: Row(
                children: [
                  Text(
                    _supportedWalletChains[_selectedChain].label,
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: AcoTypography.title,
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
                      onPressed: () =>
                          _showNotice(context, '添加钱包', '添加钱包功能即将开放。'),
                      child: const Icon(
                        CupertinoIcons.add_circled,
                        color: _lime,
                        size: 24,
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
                    return const Center(
                      child: CupertinoActivityIndicator(color: _lime),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 84),
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
                                  10,
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
                                    name: widget.walletName,
                                    address: wallet.address,
                                    current: true,
                                    onTap: () =>
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
          width: 84,
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
  const _WalletListItem({required this.address});

  final String address;
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
          height: 74,
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
                        backgroundColor: chain.backgroundColor,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(width: 5, height: 74, color: _lime),
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
      opacity: muted ? .76 : 1,
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
    required this.onTap,
  });
  final AcoPalette palette;
  final String name;
  final String address;
  final bool current;
  final VoidCallback onTap;

  String _displayAddress() {
    if (address.length <= 19) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 6)}';
  }

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: AspectRatio(
      aspectRatio: 3.35,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: current
              ? null
              : Border.all(color: palette.border.withValues(alpha: .6)),
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
                    fontSize: AcoTypography.titleLarge,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (current)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _lime,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '当前',
                      style: TextStyle(
                        color: _black,
                        fontSize: AcoTypography.bodySmall,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: palette.mutedText,
                  size: 14,
                ),
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
                      fontSize: AcoTypography.bodySmall,
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
                fontSize: AcoTypography.bodyEmphasis,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
            padding: const EdgeInsets.fromLTRB(28, 44, 28, 0),
            child: SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AcoIconButton(
                      icon: CupertinoIcons.back,
                      palette: widget.palette,
                      label: '返回',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Text(
                    '钱包详情',
                    style: TextStyle(
                      color: widget.palette.primaryText,
                      fontSize: AcoTypography.titleLarge,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(29, 48, 29, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.palette.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(37, 34, 34, 12),
                        child: Row(
                          children: [
                            KeyedSubtree(
                              key: const Key('wallet-detail-chain-logo'),
                              child: _WalletChainLogo(
                                asset: widget.selectedChain.asset,
                                backgroundColor:
                                    widget.selectedChain.backgroundColor,
                                size: 56,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Text(
                                widget.walletName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.palette.primaryText,
                                  fontSize: AcoTypography.titleLarge,
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
                                width: 24,
                                height: 22,
                                color: widget.palette.primaryText,
                                errorBuilder: (_, __, ___) => Icon(
                                  CupertinoIcons.pencil,
                                  color: widget.palette.primaryText,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(26, 25, 20, 28),
                        decoration: BoxDecoration(
                          color: widget.palette.dark
                              ? const Color(0xFF121212)
                              : widget.palette.surfaceRaised,
                          borderRadius: BorderRadius.circular(15),
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
                                    fontSize: AcoTypography.bodyEmphasis,
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
                                      size: 22,
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
                                      fontSize: AcoTypography.title,
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
                      Container(height: 1, color: widget.palette.border),
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
            minimum: const EdgeInsets.fromLTRB(67, 8, 67, 25),
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
    headerTopPadding: 36,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
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
              height: 56,
              child: CupertinoButton(
                key: const Key('backup-mnemonic-continue'),
                padding: EdgeInsets.zero,
                minimumSize: const Size.fromHeight(56),
                color: _lime,
                disabledColor: widget.palette.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                onPressed: _continue,
                child: Center(
                  child: Text(
                    _actionLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _black,
                      fontSize: AcoTypography.bodyEmphasis,
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
        height: 172,
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            CupertinoIcons.shield_lefthalf_fill,
            color: _lime,
            size: 64,
          ),
        ),
      ),
      const SizedBox(height: 30),
      Text(
        _isMnemonicExport ? '备份助记词，保护钱包安全' : '导出私钥，保护钱包安全',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.titleLarge,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _isMnemonicExport
            ? '助记词是恢复钱包的唯一凭证。请妥善备份，并确保仅由你自己保存。'
            : '私钥可直接控制钱包资产。请仅在安全环境下导出，并确保仅由你自己保存。',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.body,
          height: 1.55,
        ),
      ),
      const SizedBox(height: 24),
      _MnemonicNoticeCard(
        palette: palette,
        icon: CupertinoIcons.exclamationmark_circle,
        title: '重要提醒',
        message: _isMnemonicExport
            ? '任何人只要获取助记词，即可控制你的资产。'
            : '任何人只要获取私钥，即可控制你的资产。',
      ),
      const SizedBox(height: 32),
      Text(
        _isMnemonicExport ? '建议备份方式' : '安全提示',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: AcoTypography.titleLarge,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        _isMnemonicExport
            ? '使用笔和纸按顺序抄写\n保存到安全地点\n不要截屏、复制或通过网络传输'
            : '确认当前环境无人窥视\n导出后妥善保管\n不要通过网络传输或分享给他人',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.body,
          height: 1.7,
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
                  fontSize: AcoTypography.bodyEmphasis,
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
      padding: const EdgeInsets.fromLTRB(28, 84, 28, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.info_circle,
              color: palette.mutedText,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              networkNotice,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 288,
            height: 288,
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
                        size: 288,
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
                        width: 52,
                        height: 52,
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
        const SizedBox(height: 38),
        Text(
          '收款地址',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.titleLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              walletAddress ?? '钱包地址未就绪',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
          ),
        ),
        const SizedBox(height: 64),
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
        errorBuilder: (_, error, _) => ColoredBox(
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  AcoIconButton(
                    key: const Key('scan-back-button'),
                    icon: CupertinoIcons.back,
                    palette: widget.palette,
                    label: '返回',
                    onPressed: () => Navigator.of(context).maybePop(),
                    size: 26,
                  ),
                  Expanded(
                    child: Text(
                      '扫一扫',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.palette.primaryText,
                        fontSize: AcoTypography.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
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
      width: 72,
      child: Column(
        children: [
          Icon(icon, color: palette.mutedText, size: 32),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
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
            onSubmitted: (_) => onSubmit(),
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

class _DexTokenPage extends StatelessWidget {
  const _DexTokenPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(51, 20, 51, 24),
    children: [
      AcoRootHeader(palette: palette, onOpen: onOpen, title: 'DEX'),
      const SizedBox(height: 32),
      _SectionTabs(
        palette: palette,
        labels: const ['闪兑', '代币', '合约'],
        selected: 1,
        onChanged: (index) {
          if (index == 0) onOpen(AcoScreen.dexSwap);
        },
      ),
      const SizedBox(height: 38),
      Row(
        children: [
          const _TokenMark(),
          const SizedBox(width: 10),
          Text(
            'ETH',
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(CupertinoIcons.chevron_down, color: _lime, size: 15),
          const Spacer(),
          const Icon(CupertinoIcons.sparkles, color: _lime, size: 24),
          const SizedBox(width: 24),
          const _NetworkGlyph(color: _lime),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        '023sdS2..324d   4个月',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.caption,
        ),
      ),
      const SizedBox(height: 72),
      Row(
        children: [
          Text(
            'Today',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            '+2.34%',
            style: TextStyle(
              color: _lime,
              fontSize: AcoTypography.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'USD',
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '--',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: AcoTypography.balance,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '市值   \$4M',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '流动性   1.6M USDT',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '24h交易额   \$11.6M',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 104),
      _TimeRangeSelector(palette: palette),
      const SizedBox(height: 38),
      AcoLimeButton(
        label: '前往闪兑',
        icon: CupertinoIcons.arrow_right_arrow_left,
        onPressed: () => onOpen(AcoScreen.dexSwap),
      ),
    ],
  );
}

class _DexSwapPage extends StatefulWidget {
  const _DexSwapPage({required this.palette});
  final AcoPalette palette;
  @override
  State<_DexSwapPage> createState() => _DexSwapPageState();
}

class _DexSwapPageState extends State<_DexSwapPage> {
  bool ethFirst = true;
  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(43, 20, 28, 28),
      children: [
        AcoRootHeader(
          palette: palette,
          onOpen: (_) {},
          title: 'DEX',
          onLeadingPressed: () => Navigator.of(context).maybePop(),
          leadingButtonOffset: const Offset(-23, 0),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AcoIconButton(
                icon: CupertinoIcons.slider_horizontal_3,
                palette: palette,
                label: '筛选',
                onPressed: () {},
                size: 23,
              ),
              Text(
                '••',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodyEmphasis,
                ),
              ),
              const Icon(CupertinoIcons.sparkles, color: _lime, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 38),
        _SectionTabs(
          palette: palette,
          labels: const ['闪兑', '代币', '合约'],
          selected: 0,
        ),
        const SizedBox(height: 24),
        _SectionTabs(palette: palette, labels: const ['市价', '限价'], selected: 0),
        const SizedBox(height: 28),
        _SwapField(
          palette: palette,
          label: '兑换货币',
          symbol: ethFirst ? 'ETH' : 'USDT',
          value: '35.68',
        ),
        Center(
          child: AcoIconButton(
            icon: CupertinoIcons.arrow_down,
            palette: palette,
            label: '切换币种',
            onPressed: () => setState(() => ethFirst = !ethFirst),
            size: 22,
          ),
        ),
        _SwapField(
          palette: palette,
          label: '收到货币',
          symbol: ethFirst ? 'USDT' : 'ETH',
          value: '0.00',
        ),
        const SizedBox(height: 20),
        AcoLimeButton(
          label: '连接钱包',
          onPressed: () => _showNotice(context, '连接钱包', '请选择一个钱包继续交易。'),
        ),
        const SizedBox(height: 24),
        Text(
          '交易信息',
          style: TextStyle(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
            fontSize: AcoTypography.body,
          ),
        ),
        const SizedBox(height: 10),
        _InfoLine(palette: palette, label: '预计收到', value: '0.00 USDT'),
        _InfoLine(palette: palette, label: '滑点容差', value: '0.5%'),
      ],
    );
  }
}

class _BrowserDiscoverPage extends StatelessWidget {
  const _BrowserDiscoverPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
    children: [
      AcoPageHeader(
        palette: palette,
        title: '发现',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      const SizedBox(height: 20),
      AcoSearch(
        palette: palette,
        hint: '请输入网址或搜索',
        onSubmit: () => _showNotice(context, '浏览器', '正在打开搜索结果。'),
        height: 60,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.qrcode_viewfinder, color: palette.mutedText),
            const SizedBox(width: 14),
            _CountPill(palette: palette, label: '7'),
            const SizedBox(width: 4),
          ],
        ),
      ),
      const SizedBox(height: 18),
      AcoSurface(
        palette: palette,
        padding: EdgeInsets.zero,
        child: Container(
          height: 236,
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.compass,
              color: _lime.withValues(alpha: .8),
              size: 38,
            ),
          ),
        ),
      ),
      const SizedBox(height: 56),
      Row(
        children: [
          Expanded(
            child: _SectionTabs(
              palette: palette,
              labels: const ['热门', '探索', '我的'],
              selected: 0,
            ),
          ),
          Text(
            '更多',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: palette.mutedText,
            size: 18,
          ),
        ],
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 12,
        runSpacing: 16,
        children: [
          for (final app in const ['链上数据', 'NFT 市场', '交易工具', 'Aco 学院'])
            _DiscoverShortcut(
              palette: palette,
              label: app,
              onTap: () => onOpen(AcoScreen.marketOverview),
            ),
        ],
      ),
    ],
  );
}

class _MarketOverviewPage extends StatelessWidget {
  const _MarketOverviewPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(35, 70, 35, 24),
    children: [
      AcoSearch(
        palette: palette,
        hint: '请输入网址或搜索',
        onSubmit: () {},
        height: 60,
      ),
      const SizedBox(height: 34),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.chart_bar_alt_fill,
            label: '现货',
          ),
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.chart_pie_fill,
            label: '合约',
          ),
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.money_dollar_circle_fill,
            label: '股票',
          ),
          _MarketIcon(
            palette: palette,
            icon: CupertinoIcons.bolt_fill,
            label: '闪兑',
          ),
        ],
      ),
      const SizedBox(height: 54),
      _MarketTabs(palette: palette),
      const SizedBox(height: 28),
      _MarketRow(
        palette: palette,
        name: 'ALD',
        tag: 'DEX',
        price: '\$ 0.39827',
        change: '-0.63%',
      ),
      const SizedBox(height: 22),
      Center(
        child: Text(
          '查看更多  ›',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _SquareFeedPage extends StatefulWidget {
  const _SquareFeedPage({
    super.key,
    required this.palette,
    required this.onOpen,
    this.initialLives,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final List<LiveSession>? initialLives;

  @override
  State<_SquareFeedPage> createState() => _SquareFeedPageState();
}

class _SquareFeedPageState extends State<_SquareFeedPage> {
  final bool _showLive = true;
  final AccountApiClient _apiClient = AccountApiClient();
  late Future<List<LiveSession>> _lives;

  @override
  void initState() {
    super.initState();
    _lives = _loadLives();
  }

  Future<List<LiveSession>> _loadLives() async =>
      widget.initialLives ?? AccountSession(_apiClient).listLives();

  void _retryLoadingLives() {
    setState(() {
      _lives = _loadLives();
    });
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  void _openLiveRoom(LiveSession session) {
    if (session.status != 'live') {
      showAcoAlertNotice(context, '预约直播', '该直播尚未开始。');
      return;
    }
    Navigator.of(context)
        .push<bool>(
          _AcoPageRoute<bool>(
            builder: (_) => CupertinoPageScaffold(
              backgroundColor: widget.palette.background,
              child: SafeArea(
                bottom: false,
                child: ColoredBox(
                  color: widget.palette.background,
                  child: _VoiceRoomPage(palette: widget.palette, live: session),
                ),
              ),
            ),
          ),
        )
        .then((ended) {
          if (ended == true && mounted) {
            _retryLoadingLives();
          }
        });
  }

  void _editLive(LiveSession session) {
    Navigator.of(context)
        .push<bool>(
          _AcoPageRoute<bool>(
            builder: (_) => CupertinoPageScaffold(
              backgroundColor: widget.palette.background,
              child: SafeArea(
                bottom: false,
                child: ColoredBox(
                  color: widget.palette.background,
                  child: _CreateLivePage(
                    palette: widget.palette,
                    live: session,
                  ),
                ),
              ),
            ),
          ),
        )
        .then((updated) {
          if (updated == true && mounted) {
            _retryLoadingLives();
          }
        });
  }

  List<Widget> _buildLiveContent(AcoPalette palette) => [
    const SizedBox(height: 24),
    FutureBuilder<List<LiveSession>>(
      future: _lives,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (snapshot.hasError) {
          return _LiveListMessage(
            palette: palette,
            message: '直播列表加载失败，请检查网络后重试。',
            actionLabel: '重试',
            onPressed: _retryLoadingLives,
          );
        }
        final sessions = snapshot.data ?? const <LiveSession>[];
        if (sessions.isEmpty) {
          return _LiveListMessage(palette: palette, message: '暂无直播，去创建一场吧。');
        }
        return Column(
          children: [
            for (final session in sessions) ...[
              _LiveCard(
                palette: palette,
                session: session,
                onTap: () => _openLiveRoom(session),
                onEdit: session.canEdit && session.status == 'scheduled'
                    ? () => _editLive(session)
                    : null,
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final onOpen = widget.onOpen;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(35, 16, 35, 96),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: AcoTopActions(palette: palette, onOpen: onOpen),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const AcoAvatar(size: 42),
                const SizedBox(width: 16),
                Expanded(
                  child: AcoSearch(
                    palette: palette,
                    hint: '搜索帖文或消息',
                    height: 40,
                    variant: AcoSearchVariant.squareComposer,
                    submitIcon: CupertinoIcons.add,
                    onSubmit: () => _showNotice(context, '发布', '打开帖子编辑器。'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '推荐',
                  style: TextStyle(
                    color: _showLive ? palette.mutedText : palette.primaryText,
                    fontSize: AcoTypography.bodyEmphasis,
                    fontWeight: _showLive ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 40),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      '好友',
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: AcoTypography.bodyEmphasis,
                      ),
                    ),
                    const Positioned(
                      top: -10,
                      right: -24,
                      child: _GreenBadge(label: '77'),
                    ),
                  ],
                ),
                const SizedBox(width: 40),
                Text(
                  '直播',
                  style: TextStyle(
                    color: _showLive ? palette.primaryText : palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
                    fontWeight: _showLive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: palette.border),
            if (_showLive)
              ..._buildLiveContent(palette)
            else ...[
              const SizedBox(height: 32),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TopicChip(palette: palette, label: '买买买!!', width: 164),
                    const SizedBox(width: 10),
                    _TopicChip(
                      palette: palette,
                      label: 'ALD! V587!',
                      width: 184,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _PostCard(palette: palette),
            ],
          ],
        ),
        Positioned(
          right: 22,
          bottom: 22,
          child: Semantics(
            button: true,
            label: '创建直播',
            child: CupertinoButton(
              key: const Key('create-live-button'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(54, 54),
              onPressed: () => onOpen(AcoScreen.createLive),
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: _lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.add, color: _black, size: 30),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialMessagesPage extends StatelessWidget {
  const _SocialMessagesPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(35, 20, 35, 24),
    children: [
      AcoRootHeader(palette: palette, onOpen: onOpen),
      const SizedBox(height: 34),
      Row(
        children: [
          const AcoAvatar(size: 64),
          const SizedBox(width: 20),
          Expanded(
            child: AcoSearch(
              palette: palette,
              hint: '搜索帖文或消息',
              height: 60,
              submitIcon: CupertinoIcons.add,
              onSubmit: () => _showNotice(context, '搜索', '正在搜索消息。'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 52),
      for (final name in const ['克里斯蒂亚诺', 'Aco 社区', 'Builder'])
        _MessageRow(
          palette: palette,
          name: name,
          onTap: () =>
              onOpen(name == 'Builder' ? AcoScreen.chatV2 : AcoScreen.chatV1),
        ),
    ],
  );
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({required this.palette, required this.version});
  final AcoPalette palette;
  final int version;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '添加代币',
    child: Column(
      children: [
        const SizedBox(height: 30),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Bubble(
                palette: palette,
                text: version == 1
                    ? '我想看下怎么可以买呢，有点难度的，你说是不是'
                    : '我想看下怎么可以卖呢，交易在哪儿操作？',
                mine: true,
              ),
              const SizedBox(width: 12),
              const AcoAvatar(size: 48),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'A',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.displaySmall,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _Bubble(
                palette: palette,
                text: '等发你个教程具体看下操作，说也说不清楚还是图文比较好操作',
                mine: false,
              ),
            ],
          ),
        ),
        const Spacer(),
        AcoSearch(
          palette: palette,
          hint: '发送消息',
          height: 60,
          submitIcon: CupertinoIcons.arrow_up,
          onSubmit: () => _showNotice(context, '消息已发送', '已发送至对方。'),
        ),
      ],
    ),
  );
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.palette});
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: 'Coming Soon',
    showBack: false,
    child: Center(
      child: Text(
        'Coming Soon',
        style: TextStyle(
          color: palette.mutedText,
          fontSize: AcoTypography.displaySmall,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _CreateLivePage extends StatefulWidget {
  const _CreateLivePage({required this.palette, this.live});
  final AcoPalette palette;
  final LiveSession? live;

  @override
  State<_CreateLivePage> createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<_CreateLivePage> {
  static const _maxCoverSizeBytes = 5 * 1024 * 1024;

  final _titleController = TextEditingController();
  DateTime? _scheduledAt;
  Uint8List? _coverBytes;
  String? _joinPassword;
  bool _submitting = false;
  bool _coverChanged = false;

  bool get _isEditing => widget.live != null;

  @override
  void initState() {
    super.initState();
    final live = widget.live;
    if (live != null) {
      _titleController.text = live.title;
      _scheduledAt = live.scheduledAt;
      _joinPassword = live.access == 'password' ? '' : null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _titleController.text.trim().isNotEmpty &&
      (_coverBytes != null || widget.live?.coverUrl.isNotEmpty == true) &&
      (!_isEditing || _scheduledAt != null);

  Future<void> _confirm() async {
    if (!_canConfirm || _submitting) return;
    final title = _titleController.text.trim();
    final apiClient = AccountApiClient();
    setState(() => _submitting = true);
    try {
      final session = AccountSession(apiClient);
      if (widget.live case final live?) {
        await session.updateLive(
          liveId: live.id,
          title: title,
          coverUrl: live.coverUrl,
          coverBytes: _coverChanged ? _coverBytes : null,
          access: _joinPassword == null ? 'open' : 'password',
          joinPassword: _joinPassword?.isEmpty == true ? null : _joinPassword,
          scheduledAt: _scheduledAt,
        );
      } else if (_coverBytes case final coverBytes?) {
        await session.createLive(
          title: title,
          coverBytes: coverBytes,
          access: _joinPassword == null ? 'open' : 'password',
          joinPassword: _joinPassword,
          scheduledAt: _scheduledAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AccountApiException catch (error) {
      if (mounted) {
        _showNotice(context, _isEditing ? '保存失败' : '创建失败', error.message);
      }
    } catch (_) {
      if (mounted) {
        _showNotice(context, _isEditing ? '保存失败' : '创建失败', '请检查网络后重试。');
      }
    } finally {
      apiClient.close();
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _scheduleLabel {
    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) return '立即开播';
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '${scheduledAt.month}月${scheduledAt.day}日 $hour:$minute';
  }

  Future<void> _selectSchedule() async {
    final now = DateTime.now();
    var selected = _scheduledAt ?? now.add(const Duration(hours: 1));
    final palette = widget.palette;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: _lime,
        ),
        child: Container(
          height: 332,
          color: palette.surface,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: _isEditing
                            ? null
                            : () {
                                setState(() => _scheduledAt = null);
                                Navigator.of(sheetContext).pop();
                              },
                        child: Text(
                          '立即开播',
                          style: TextStyle(
                            color: _isEditing ? palette.mutedText : _lime,
                            fontSize: AcoTypography.bodySmall,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '选择开播时间',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () {
                          setState(() => _scheduledAt = selected);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(
                          '确定',
                          style: const TextStyle(
                            color: _lime,
                            fontSize: AcoTypography.body,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: palette.border),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    minimumDate: now,
                    initialDateTime: selected,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectCover() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > _maxCoverSizeBytes) {
      _showNotice(context, '图片过大', '请选择小于 5 MB 的直播封面。');
      return;
    }

    setState(() {
      _coverBytes = bytes;
      _coverChanged = true;
    });
  }

  String get _joinAccessLabel => _joinPassword == null ? '任何人直接加入' : '需要密码才能加入';

  Future<void> _selectJoinAccess() async {
    final palette = widget.palette;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: _lime,
        ),
        child: CupertinoActionSheet(
          title: const Text(
            '设置加入权限',
            style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop('open'),
              child: const Text(
                '任何人直接加入',
                style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(sheetContext).pop('password'),
              child: const Text(
                '需要密码才能加入',
                style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text(
              '取消',
              style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
            ),
          ),
        ),
      ),
    );

    if (choice == 'open') {
      setState(() => _joinPassword = null);
    } else if (choice == 'password') {
      await _setJoinPassword();
    }
  }

  Future<void> _setJoinPassword() async {
    final palette = widget.palette;
    var password = _joinPassword ?? '';
    final confirmedPassword = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: _lime,
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
            title: const Text('设置加入密码'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CupertinoTextField(
                autofocus: true,
                obscureText: true,
                maxLength: 20,
                onChanged: (value) => setDialogState(() => password = value),
                placeholder: '输入至少 4 位密码',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: password.trim().length >= 4
                    ? () => Navigator.of(dialogContext).pop(password.trim())
                    : null,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmedPassword != null) {
      setState(() => _joinPassword = confirmedPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final hasCover =
        _coverBytes != null || widget.live?.coverUrl.isNotEmpty == true;
    final canConfirm = _canConfirm && !_submitting;
    return _DetailScaffold(
      palette: palette,
      title: _isEditing ? '修改直播' : '创建直播',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              children: [
                Container(
                  height: 164,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _titleController,
                          maxLength: 60,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          onChanged: (_) => setState(() {}),
                          placeholder: '输入直播主题',
                          placeholderStyle: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.title,
                          ),
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.bodyEmphasis,
                          ),
                          decoration: null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_titleController.text.length}/60',
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _CreateLiveRow(
                  palette: palette,
                  title: '预约时间',
                  value: _scheduleLabel,
                  highlighted: true,
                  onTap: _selectSchedule,
                ),
                const SizedBox(height: 12),
                _CreateLiveRow(
                  palette: palette,
                  title: '谁能加入？',
                  subtitle: _joinAccessLabel,
                  onTap: _selectJoinAccess,
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _selectCover,
                  child: Container(
                    height: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        if (_coverBytes case final bytes?)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              bytes,
                              width: 54,
                              height: 52,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                            ),
                          )
                        else if (widget.live?.coverUrl case final coverUrl?)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _liveCoverUrl(coverUrl),
                              width: 54,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _LiveCoverThumbnailFallback(palette: palette),
                            ),
                          )
                        else
                          Container(
                            width: 54,
                            height: 52,
                            decoration: BoxDecoration(
                              color: palette.surfaceRaised,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              CupertinoIcons.photo,
                              color: palette.mutedText,
                              size: 26,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '*',
                                    style: TextStyle(
                                      color: _danger,
                                      fontSize: AcoTypography.bodyEmphasis,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    hasCover ? '更换封面' : '上传封面',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontSize: AcoTypography.bodyEmphasis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (hasCover)
                                Text(
                                  '已选择直播封面',
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: AcoTypography.bodySmall,
                                  ),
                                )
                              else
                                Text(
                                  '建议使用横向图片',
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: AcoTypography.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: palette.mutedText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: CupertinoButton(
                  key: const Key('confirm-create-live-button'),
                  padding: EdgeInsets.zero,
                  onPressed: canConfirm ? _confirm : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canConfirm ? _lime : palette.surfaceRaised,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _submitting
                        ? const CupertinoActivityIndicator(color: _black)
                        : Text(
                            _isEditing ? '保存' : '确认',
                            style: TextStyle(
                              color: canConfirm ? _black : palette.mutedText,
                              fontSize: AcoTypography.bodyEmphasis,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateLiveRow extends StatelessWidget {
  const _CreateLiveRow({
    required this.palette,
    required this.title,
    required this.onTap,
    this.value,
    this.subtitle,
    this.highlighted = false,
  });

  final AcoPalette palette;
  final String title;
  final String? value;
  final String? subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onTap,
    child: Container(
      height: subtitle == null ? 56 : 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.bodyEmphasis,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            Text(
              value!,
              style: TextStyle(
                color: highlighted ? _lime : palette.mutedText,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            CupertinoIcons.chevron_right,
            color: palette.mutedText,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

class _LiveStreamPage extends StatelessWidget {
  const _LiveStreamPage({required this.palette, required this.onOpen});
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '正在直播',
    right: AcoTopActions(palette: palette, onOpen: onOpen),
    child: _LiveListMessage(palette: palette, message: '请前往广场查看实时直播列表。'),
  );
}

class _VoiceRoomPage extends StatefulWidget {
  const _VoiceRoomPage({required this.palette, this.live});
  final AcoPalette palette;
  final LiveSession? live;

  @override
  State<_VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<_VoiceRoomPage> {
  bool _muted = false;
  bool _handRaised = false;
  bool _emojiPickerVisible = false;
  bool _sending = false;
  bool _roomLoading = false;
  bool _leaving = false;
  bool _allowPop = false;
  bool _handRaiseNoticeVisible = false;
  LiveRoom? _room;
  List<LiveMessage> _messages = const [];
  WebSocketChannel? _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _reconnectTimer;
  Timer? _handRaiseNoticeTimer;
  late final AccountApiClient _apiClient;
  late final AccountSession _accountSession;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_setLiveRoomWakelock(true));
    _apiClient = AccountApiClient();
    _accountSession = AccountSession(_apiClient);
    if (widget.live != null) {
      unawaited(_initializeRoom());
    }
  }

  Future<void> _initializeRoom() async {
    await _loadRoom();
    await _loadMessages();
    await _connectRealtime();
  }

  Future<void> _loadRoom({bool silent = false}) async {
    final live = widget.live;
    if (live == null) return;
    if (!silent && mounted) setState(() => _roomLoading = true);
    try {
      final room = await _accountSession.liveRoom(live.id);
      _applyRoomSnapshot(room);
    } on AccountApiException catch (error) {
      if (!silent && mounted) _showNotice(context, '无法进入直播间', error.message);
    } catch (_) {
      if (!silent && mounted) {
        _showNotice(context, '无法进入直播间', '请检查网络后重试。');
      }
    } finally {
      if (!silent && mounted) setState(() => _roomLoading = false);
    }
  }

  Future<void> _connectRealtime() async {
    final live = widget.live;
    if (live == null || !mounted || _leaving) return;
    try {
      await _loadRoom(silent: true);
      final ticket = await _accountSession.liveWebsocketTicket(live.id);
      final channel = WebSocketChannel.connect(
        _liveWebsocketUri(live.id, ticket),
      );
      await _eventSubscription?.cancel();
      await _eventChannel?.sink.close();
      _eventChannel = channel;
      _eventSubscription = channel.stream.listen(
        _handleRealtimeEvent,
        onError: (_) => _scheduleRealtimeReconnect(),
        onDone: _scheduleRealtimeReconnect,
      );
      _reconnectTimer?.cancel();
      await _loadMessages();
    } catch (_) {
      _scheduleRealtimeReconnect();
    }
  }

  Uri _liveWebsocketUri(int liveId, String ticket) {
    final apiBase = Uri.parse(const AppConfig().apiBaseUrl);
    final path = apiBase.path.replaceFirst(
      RegExp(r'/api/v1/?$'),
      '/api/v1/lives/$liveId/ws',
    );
    return apiBase.replace(
      scheme: apiBase.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: {'ticket': ticket},
    );
  }

  void _scheduleRealtimeReconnect() {
    if (!mounted || widget.live == null || _leaving) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_leaving) unawaited(_connectRealtime());
    });
  }

  void _handleRealtimeEvent(dynamic rawEvent) {
    if (rawEvent is! String) return;
    final decoded = jsonDecode(rawEvent);
    if (decoded is! Map<String, dynamic>) return;
    final event = decoded;
    switch (event['type'] as String?) {
      case 'room.snapshot':
        final roomJson = event['room'];
        if (roomJson is Map<String, dynamic>) {
          _applyRoomSnapshot(LiveRoom.fromJson(roomJson));
        }
      case 'chat.message':
        final messageJson = event['message'];
        if (messageJson is Map<String, dynamic>) {
          _appendMessages([LiveMessage.fromJson(messageJson)]);
        }
    }
  }

  void _applyRoomSnapshot(LiveRoom room) {
    if (!mounted) return;
    setState(() {
      _room = room;
      _muted = room.viewerMuted;
      _handRaised = room.raisedHands.any(
        (participant) => participant.userId == room.viewerUserId,
      );
      if (room.chatMuted && room.viewerRole != 'host') {
        _emojiPickerVisible = false;
      }
    });
  }

  Future<void> _raiseHand() async {
    final live = widget.live;
    if (live == null || _handRaised) return;
    try {
      await _accountSession.raiseLiveHand(live.id);
      if (!mounted) return;
      setState(() => _handRaised = true);
      _showHandRaiseNotice();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '举手失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '举手失败', '请检查网络后重试。');
    }
  }

  void _showHandRaiseNotice() {
    _handRaiseNoticeTimer?.cancel();
    setState(() => _handRaiseNoticeVisible = true);
    _handRaiseNoticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _handRaiseNoticeVisible = false);
    });
  }

  Future<void> _endLive() async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.endLive(live.id);
      _closeRoom(true);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '结束失败', error.message);
    }
  }

  Future<void> _confirmEndLive() async {
    final shouldEnd = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('结束直播'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('确定要结束这场直播吗？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('结束直播'),
          ),
        ],
      ),
    );
    if (shouldEnd == true && mounted) {
      await _endLive();
    }
  }

  Future<void> _setAudioMute(bool muted) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveAudioMute(live.id, muted);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '设置失败', '请检查网络后重试。');
    }
  }

  Future<void> _setChatMute(bool muted) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveChatMute(live.id, muted);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '设置失败', '请检查网络后重试。');
    }
  }

  void _showRaisedHandRequests() {
    final room = _room;
    if (room == null || room.raisedHands.isEmpty) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 320,
            maxHeight: math.min(280, MediaQuery.sizeOf(context).height * .42),
          ),
          child: CupertinoPopupSurface(
            child: _RaisedHandRequests(
              palette: widget.palette,
              users: room.raisedHands,
              onClose: () => Navigator.of(dialogContext).pop(),
              onApprove: (userId) {
                Navigator.of(dialogContext).pop();
                unawaited(_approveSpeaker(userId));
              },
              onReject: (userId) {
                Navigator.of(dialogContext).pop();
                unawaited(_rejectSpeakerRequest(userId));
              },
              maxHeight: 170,
            ),
          ),
        ),
      ),
    );
  }

  void _showHostActions() {
    final room = _room;
    final speakers = _room?.speakers ?? const <LiveParticipant>[];
    final hasSpeakers = speakers.isNotEmpty;
    final chatMuted = room?.chatMuted ?? false;
    final audioMuted = room?.audioMuted ?? false;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              unawaited(_setAudioMute(!audioMuted));
            },
            child: _hostActionLabel(audioMuted ? '解除全员静音' : '全员静音'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              unawaited(_setChatMute(!chatMuted));
            },
            child: _hostActionLabel(chatMuted ? '解除全员禁言' : '全员禁言'),
          ),
          if (hasSpeakers)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _showHostTransferPicker(speakers);
              },
              child: _hostActionLabel('转让主持人'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              unawaited(_endLive());
            },
            child: _hostActionLabel('结束直播'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: _hostActionLabel('取消'),
        ),
      ),
    );
  }

  Widget _hostActionLabel(String label) =>
      Text(label, style: const TextStyle(fontSize: AcoTypography.body));

  Future<void> _handleBack() async {
    if (_room?.viewerRole == 'host') {
      await _confirmEndLive();
      return;
    }
    if (_leaving) return;
    _leaving = true;
    final live = widget.live;
    if (live != null) {
      try {
        await _accountSession.leaveLive(live.id);
      } catch (_) {
        // The server can clean up stale presence if the connection is lost.
      }
    }
    _closeRoom();
  }

  void _closeRoom([bool? result]) {
    if (!mounted) return;
    setState(() {
      _allowPop = true;
      _leaving = true;
    });
    Navigator.of(context).pop(result);
  }

  void _showHostTransferPicker(List<LiveParticipant> speakers) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('转让主持人'),
        message: const Text('选择一位正在发言的成员成为新主持人。直播不会中断，你将成为普通成员。'),
        actions: speakers
            .map((speaker) => _transferHostAction(sheetContext, speaker))
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _transferHostAction(
    BuildContext sheetContext,
    LiveParticipant speaker,
  ) => CupertinoActionSheetAction(
    onPressed: () {
      Navigator.of(sheetContext).pop();
      unawaited(_transferHost(speaker));
    },
    child: Text(speaker.nickname),
  );

  Future<void> _transferHost(LiveParticipant speaker) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.transferLiveHost(live.id, speaker.userId);
      _closeRoom();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '转让失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '转让失败', '请检查网络后重试。');
    }
  }

  Future<void> _approveSpeaker(int userId) async {
    await _updateSpeaker(
      userId: userId,
      action: _accountSession.approveLiveSpeaker,
      failureTitle: '批准失败',
    );
  }

  Future<void> _removeSpeaker(int userId) async {
    await _updateSpeaker(
      userId: userId,
      action: _accountSession.removeLiveSpeaker,
      failureTitle: '移除失败',
    );
  }

  Future<void> _rejectSpeakerRequest(int userId) async {
    await _updateSpeaker(
      userId: userId,
      action: _accountSession.removeLiveSpeaker,
      failureTitle: '拒绝失败',
    );
  }

  Future<void> _updateSpeaker({
    required int userId,
    required Future<void> Function(int liveId, int userId) action,
    required String failureTitle,
  }) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await action(live.id, userId);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, failureTitle, error.message);
    }
  }

  @override
  void dispose() {
    unawaited(_setLiveRoomWakelock(false));
    _reconnectTimer?.cancel();
    _handRaiseNoticeTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_eventChannel?.sink.close());
    _apiClient.close();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() =>
      setState(() => _emojiPickerVisible = !_emojiPickerVisible);

  Future<void> _loadMessages() async {
    final live = widget.live;
    if (live == null) return;
    try {
      final messages = await _accountSession.listLiveMessages(
        live.id,
        after: _messages.isEmpty ? null : _messages.last.id,
      );
      if (!mounted || messages.isEmpty) return;
      _appendMessages(messages);
    } catch (_) {
      // WebSocket events cover new messages; history remains a best-effort fallback.
    }
  }

  Future<void> _sendMessage() async {
    final live = widget.live;
    final text = _messageController.text.trim();
    final isViewerChatMuted =
        _room?.chatMuted == true && _room?.viewerRole != 'host';
    if (live == null || text.isEmpty || _sending || isViewerChatMuted) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _accountSession.createLiveMessage(liveId: live.id, text: text);
      if (!mounted) return;
      _messageController.clear();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '发送失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '发送失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _appendMessages(Iterable<LiveMessage> incomingMessages) {
    final knownMessageIDs = _messages.map((message) => message.id).toSet();
    final newMessages = incomingMessages
        .where((message) => knownMessageIDs.add(message.id))
        .toList(growable: false);
    if (newMessages.isEmpty) return;
    setState(() => _messages = [..._messages, ...newMessages]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final live = widget.live;
    final room = _room;
    final viewerRole = room?.viewerRole;
    final isHost = viewerRole == 'host';
    final canSpeak = live == null || isHost || viewerRole == 'speaker';
    final audioMuted = room?.audioMuted == true && !isHost;
    final chatMuted = room?.chatMuted == true && !isHost;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: _DetailScaffold(
        palette: palette,
        title: live?.title.trim().isNotEmpty == true ? live!.title : '语音房',
        titleFollowsBack: true,
        headerTopPadding: 14,
        onBack: () => unawaited(_handleBack()),
        right: _LiveRoomHeaderActions(
          palette: palette,
          count: room?.participantCount,
          onMore: isHost ? _showHostActions : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: _emojiPickerVisible ? 368 : 76),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (!_emojiPickerVisible) ...[
                          if (room != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: _LiveRoomHostCard(
                                      palette: palette,
                                      host: room.host,
                                      active: room.hostActive,
                                    ),
                                  ),
                                  if (isHost && room.raisedHands.isNotEmpty)
                                    Positioned(
                                      top: 54,
                                      right: 14,
                                      child: _RaisedHandIndicator(
                                        palette: palette,
                                        count: room.raisedHands.length,
                                        onPressed: _showRaisedHandRequests,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (room.speakers.isNotEmpty)
                              _LiveRoomParticipantStage(
                                palette: palette,
                                speakers: room.speakers,
                              ),
                            if (room.listeners.isNotEmpty)
                              _LiveRoomListenerSection(
                                palette: palette,
                                listeners: room.listeners,
                              ),
                            _LiveRoomStatus(
                              palette: palette,
                              room: room,
                              onRemove: isHost ? _removeSpeaker : null,
                            ),
                          ] else if (_roomLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 48),
                              child: CupertinoActivityIndicator(),
                            ),
                        ],
                        const SizedBox(height: 14),
                        Expanded(
                          child: _RoomChatHistory(
                            palette: palette,
                            liveMessages: _messages,
                            hasLive: live != null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_handRaiseNoticeVisible)
              const Center(child: _LiveRoomInfoNotice()),
            Positioned(
              left: 0,
              right: 0,
              bottom: _emojiPickerVisible ? 292 : 0,
              child: _RoomBottomBar(
                palette: palette,
                muted: audioMuted || (room?.viewerMuted ?? _muted),
                canSpeak: canSpeak,
                audioMuted: audioMuted,
                handRaised: _handRaised,
                chatMuted: chatMuted,
                onMic: canSpeak && !audioMuted
                    ? () => setState(() => _muted = !_muted)
                    : null,
                onHand: room?.canRaiseHand == true ? _raiseHand : null,
                controller: _messageController,
                onEmojiPressed: _toggleEmojiPicker,
                onSubmitted: _sendMessage,
              ),
            ),
            if (_emojiPickerVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _RoomEmojiPicker(
                  palette: palette,
                  controller: _messageController,
                  onEmojiSelected: () =>
                      setState(() => _emojiPickerVisible = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _setLiveRoomWakelock(bool enabled) async {
  try {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  } on PlatformException {
    // Some targets (for example Flutter Web without a registered plugin)
    // do not provide the wakelock platform channel.
  } catch (_) {
    // Failing to keep the screen awake must not interrupt the live room.
  }
}

class _MiningPage extends StatelessWidget {
  const _MiningPage({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '挖矿',
    right: AcoIconButton(
      icon: CupertinoIcons.bell,
      palette: palette,
      label: '挖矿通知',
      onPressed: () {},
    ),
    child: ListView(
      children: [
        AcoSurface(
          palette: palette,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Text(
            '质押仅支持Donmi Chain，请在钱包中手动切换后继续。',
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.60,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.flame,
              label: '挖矿状态',
              value: '已激活',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.chart_bar,
              label: '年化收益率',
              value: '10%',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.creditcard,
              label: '已质押',
              value: '100DMT',
            ),
            _MiningTile(
              palette: palette,
              icon: CupertinoIcons.hand_raised,
              label: '待领取',
              value: '100DMT',
            ),
          ],
        ),
        const SizedBox(height: 22),
        AcoLimeButton(
          label: '领取收益',
          onPressed: () => _showNotice(context, '领取成功', '100DMT 已进入钱包。'),
        ),
      ],
    ),
  );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.palette,
    required this.onOpen,
    required this.displayName,
    required this.accountId,
    required this.username,
    this.onBack,
  });
  final AcoPalette palette;
  final ValueChanged<AcoScreen> onOpen;
  final String displayName;
  final String accountId;
  final String username;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
    children: [
      AcoPageHeader(
        palette: palette,
        onBack: onBack,
        right: AcoIconButton(
          icon: CupertinoIcons.qrcode_viewfinder,
          palette: palette,
          label: '个人二维码',
          onPressed: () => onOpen(AcoScreen.profileQr),
        ),
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          const AcoAvatar(size: 70),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.displaySmall,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  username.startsWith('@') ? username : '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodyEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'UID:${displayAccountId(accountId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: AcoTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          AcoIconButton(
            icon: CupertinoIcons.chevron_right,
            palette: palette,
            label: '编辑个人资料',
            size: 20,
            onPressed: () => onOpen(AcoScreen.profileEdit),
          ),
        ],
      ),
      const SizedBox(height: 44),
      _ProfileSection(
        palette: palette,
        title: '设置',
        actions: [
          _ProfileAction(
            palette: palette,
            icon: CupertinoIcons.flag,
            label: '主题模式',
            onPressed: () => onOpen(AcoScreen.profileTheme),
          ),
          _ProfileAction(
            palette: palette,
            icon: CupertinoIcons.globe,
            label: '语言',
            onPressed: () => onOpen(AcoScreen.profileLanguage),
          ),
        ],
      ),
    ],
  );
}

class _ProfileQrPage extends StatelessWidget {
  const _ProfileQrPage({
    required this.palette,
    required this.displayName,
    required this.accountId,
    required this.username,
    required this.onBack,
  });

  final AcoPalette palette;
  final String displayName;
  final String accountId;
  final String username;
  final VoidCallback onBack;

  String get _handle => username.startsWith('@') ? username : '@$username';

  String get _qrData =>
      'aco://profile/${Uri.encodeComponent(username.replaceFirst('@', ''))}?uid=${Uri.encodeComponent(accountId)}';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AcoPageHeader(palette: palette, title: '我的二维码', onBack: onBack),
        const SizedBox(height: 18),
        Row(
          children: [
            const AcoAvatar(size: 70),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.body,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'UID:${displayAccountId(accountId)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Center(
          child: Container(
            width: 286,
            height: 286,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _black.withValues(alpha: palette.dark ? .32 : .08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              backgroundColor: _white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _black,
              ),
              semanticsLabel: '个人二维码：$_handle',
            ),
          ),
        ),
        const Spacer(),
        Text(
          '扫一扫上面的二维码图案，加我为朋友。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
      ],
    ),
  );
}

class _ProfileLoadingPage extends StatelessWidget {
  const _ProfileLoadingPage({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AcoPageHeader(palette: palette),
      Expanded(
        child: Center(
          child: Icon(
            CupertinoIcons.person_crop_circle,
            color: palette.mutedText,
            size: 44,
          ),
        ),
      ),
    ],
  );
}

class _ProfileEditPage extends StatefulWidget {
  const _ProfileEditPage({
    required this.palette,
    required this.initialName,
    required this.initialUsername,
    required this.accountId,
    this.onDisplayNameChanged,
    this.onUsernameChanged,
  });

  final AcoPalette palette;
  final String initialName;
  final String initialUsername;
  final String accountId;
  final ValueChanged<String>? onDisplayNameChanged;
  final ValueChanged<String>? onUsernameChanged;

  @override
  State<_ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<_ProfileEditPage> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _usernameController = TextEditingController(
    text: widget.initialUsername,
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    if (name.isEmpty || username.isEmpty) return;
    setState(() => _saving = true);
    final client = AccountApiClient();
    try {
      final profile = await AccountSession(
        client,
      ).updateProfile(username: username, nickname: name);
      if (!mounted) return;
      widget.onDisplayNameChanged?.call(profile.nickname);
      widget.onUsernameChanged?.call(profile.username);
      Navigator.of(context).pop();
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '保存失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '保存失败', '请检查网络后重试。');
    } finally {
      client.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '编辑资料',
    titleFollowsBack: true,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Center(
          child: Column(
            children: [
              const AcoAvatar(size: 84),
              const SizedBox(height: 10),
              Text(
                '头像暂不支持修改',
                style: TextStyle(
                  color: widget.palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          '基本资料',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        AcoSurface(
          palette: widget.palette,
          radius: 20,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '昵称',
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                key: const Key('profile-name-input'),
                controller: _nameController,
                maxLength: 20,
                cursorColor: _lime,
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.body,
                ),
                decoration: BoxDecoration(
                  color: widget.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '用户名',
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                key: const Key('profile-username-input'),
                controller: _usernameController,
                maxLength: 20,
                cursorColor: _lime,
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.body,
                ),
                decoration: BoxDecoration(
                  color: widget.palette.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'UID',
                style: TextStyle(
                  color: widget.palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayAccountId(widget.accountId),
                style: TextStyle(
                  color: widget.palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AcoLimeButton(
          label: _saving ? '保存中...' : '保存修改',
          onPressed: _saving ? () {} : _save,
        ),
      ],
    ),
  );
}

class _ThemeSettingsPage extends StatelessWidget {
  const _ThemeSettingsPage({
    required this.palette,
    required this.dark,
    required this.onThemeToggle,
  });

  final AcoPalette palette;
  final bool dark;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: palette,
    title: '主题模式',
    titleFollowsBack: true,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Text(
          '外观偏好',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        AcoSurface(
          palette: palette,
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              _PreferenceOption(
                icon: CupertinoIcons.moon,
                title: '深色模式',
                subtitle: '适合低光环境',
                selected: dark,
                palette: palette,
                onPressed: dark ? null : onThemeToggle,
              ),
              Container(height: 1, color: palette.border),
              _PreferenceOption(
                icon: CupertinoIcons.sun_max,
                title: '浅色模式',
                subtitle: '清晰明亮的界面',
                selected: !dark,
                palette: palette,
                onPressed: dark ? onThemeToggle : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LanguageSettingsPage extends StatefulWidget {
  const _LanguageSettingsPage({
    required this.palette,
    required this.initialLanguage,
    this.onLanguageChanged,
  });

  final AcoPalette palette;
  final String initialLanguage;
  final ValueChanged<String>? onLanguageChanged;

  @override
  State<_LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<_LanguageSettingsPage> {
  late String _selectedLanguage = widget.initialLanguage;

  void _selectLanguage(String language) {
    setState(() => _selectedLanguage = language);
    widget.onLanguageChanged?.call(language);
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    palette: widget.palette,
    title: '语言',
    titleFollowsBack: true,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Text(
          '显示语言',
          style: TextStyle(
            color: widget.palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        AcoSurface(
          palette: widget.palette,
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              for (final language in const [
                ('简体中文', 'Chinese (Simplified)'),
                ('English', 'English (US)'),
              ]) ...[
                _PreferenceOption(
                  icon: CupertinoIcons.globe,
                  title: language.$1,
                  subtitle: language.$2,
                  selected: _selectedLanguage == language.$1,
                  enabled: language.$1 != 'English',
                  palette: widget.palette,
                  onPressed:
                      language.$1 == 'English' ||
                          _selectedLanguage == language.$1
                      ? null
                      : () => _selectLanguage(language.$1),
                ),
                if (language.$1 != 'English')
                  Container(height: 1, color: widget.palette.border),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _PreferenceOption extends StatelessWidget {
  const _PreferenceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.palette,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final AcoPalette palette;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: SizedBox(
      height: 64,
      child: Row(
        children: [
          Icon(
            icon,
            color: selected
                ? _lime
                : enabled
                ? palette.primaryText
                : palette.mutedText.withValues(alpha: .5),
            size: 21,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: enabled
                        ? palette.primaryText
                        : palette.mutedText.withValues(alpha: .5),
                    fontSize: AcoTypography.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: enabled
                        ? palette.mutedText
                        : palette.mutedText.withValues(alpha: .4),
                    fontSize: AcoTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(CupertinoIcons.check_mark_circled_solid, color: _lime),
        ],
      ),
    ),
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.palette,
    required this.title,
    required this.actions,
  });

  final AcoPalette palette;
  final String title;
  final List<_ProfileAction> actions;

  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.title,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: actions.length <= 2
              ? MainAxisAlignment.start
              : MainAxisAlignment.spaceBetween,
          children: [
            for (final action in actions) ...[
              action,
              if (actions.length == 2 && action != actions.last)
                const SizedBox(width: 64),
            ],
          ],
        ),
      ],
    ),
  );
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
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
      width: 68,
      child: Column(
        children: [
          Icon(icon, color: palette.primaryText, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
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

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.palette,
    required this.child,
    this.title,
    this.right,
    this.onBack,
    this.titleFollowsBack = false,
    this.showBack = true,
    this.headerTopPadding = 4,
  });
  final AcoPalette palette;
  final Widget child;
  final String? title;
  final Widget? right;
  final VoidCallback? onBack;
  final bool titleFollowsBack;
  final bool showBack;
  final double headerTopPadding;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, headerTopPadding, 28, 0),
        child: AcoPageHeader(
          palette: palette,
          title: title,
          right: right,
          titleFollowsBack: titleFollowsBack,
          backButtonOffset: Offset.zero,
          onBack: showBack
              ? onBack ?? () => Navigator.of(context).maybePop()
              : null,
        ),
      ),
      Expanded(child: child),
    ],
  );
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.palette,
    required this.onPressed,
    this.icon,
    this.height = 42,
    this.fontSize = AcoTypography.bodySmall,
    this.backgroundColor,
    this.foregroundColor,
    this.radius = 8,
    this.fontWeight = FontWeight.w600,
    this.leadingAsset,
    this.leadingImageAsset,
    this.iconSize = 16,
    this.iconGap = 6,
  });
  final String label;
  final IconData? icon;
  final AcoPalette palette;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double radius;
  final FontWeight fontWeight;
  final String? leadingAsset;
  final String? leadingImageAsset;
  final double iconSize;
  final double iconGap;
  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? palette.primaryText;
    final hasLeading =
        leadingAsset != null || leadingImageAsset != null || icon != null;
    return SizedBox(
      height: height,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? palette.surface,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingAsset != null)
                  SvgPicture.asset(
                    leadingAsset!,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
                  )
                else if (leadingImageAsset != null)
                  Image.asset(
                    leadingImageAsset!,
                    width: iconSize,
                    height: iconSize,
                  )
                else if (icon != null)
                  Icon(icon, color: foreground, size: iconSize),
                if (hasLeading) SizedBox(width: iconGap),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.palette,
    required this.labels,
    required this.selected,
    this.scale = 1,
    this.disabledIndexes = const {},
    this.onChanged,
  });
  final AcoPalette palette;
  final double scale;
  final List<String> labels;
  final int selected;
  final Set<int> disabledIndexes;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 32),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size(30 * scale, 42 * scale),
            onPressed: onChanged == null || disabledIndexes.contains(i)
                ? null
                : () => onChanged!(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 28.42 * scale,
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? const Color(0xFF212121)
                        : _transparent,
                    borderRadius: BorderRadius.circular(12.11 * scale),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: _walletHeaderMuted,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: (i == selected ? 20 : 24) * scale,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 7 * scale),
              ],
            ),
          ),
        ),
    ],
  );
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({required this.palette});
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (final range in const ['1H', '1D', '1W', '1M', '1Y', 'ALL'])
        Container(
          constraints: const BoxConstraints(minWidth: 36),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: range == '1D' ? palette.surfaceRaised : _transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            range,
            style: TextStyle(
              color: range == '1D' ? palette.primaryText : palette.mutedText,
              fontSize: AcoTypography.caption,
            ),
          ),
        ),
      Icon(
        CupertinoIcons.slider_horizontal_3,
        color: palette.mutedText,
        size: 21,
      ),
    ],
  );
}

class _WalletAssetRow extends StatelessWidget {
  const _WalletAssetRow({
    required this.palette,
    required this.scale,
    required this.symbol,
    required this.title,
    required this.amount,
    required this.value,
  });
  final AcoPalette palette;
  final double scale;
  final String symbol, title, amount, value;
  @override
  Widget build(BuildContext context) {
    final normalizedSymbol = symbol.toUpperCase();
    final iconAsset = normalizedSymbol == 'USDT'
        ? 'assets/icons/crypto/domi/tokens/usdt.png'
        : normalizedSymbol == 'IOST'
        ? null
        : 'assets/icons/crypto/tokens/${normalizedSymbol.toLowerCase()}.svg';

    return SizedBox(
      height: 97.18 * scale,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12 * scale),
              child: Row(
                children: [
                  SizedBox(
                    width: 42 * scale,
                    height: 42 * scale,
                    child: iconAsset == null
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: switch (normalizedSymbol) {
                                'IOST' => const Color(0xFFE0E0E0),
                                _ => const Color(0xFF2680D9),
                              },
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              normalizedSymbol.substring(0, 1),
                              style: const TextStyle(
                                color: _white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : iconAsset.endsWith('.png')
                        ? ClipOval(
                            child: Image.asset(iconAsset, fit: BoxFit.cover),
                          )
                        : SvgPicture.asset(iconAsset),
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          symbol,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: AcoTypography.body * scale,
                          ),
                        ),
                        SizedBox(height: 3 * scale),
                        Text(
                          title,
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.caption * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 112 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amount,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.body * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3 * scale),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.bodySmall * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 31 * scale,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: .75 * scale,
              child: const ColoredBox(color: Color(0xFF161616)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.palette,
    required this.label,
    this.size = 32,
  });
  final AcoPalette palette;
  final String label;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
    child: Text(
      label,
      style: TextStyle(
        color: _black,
        fontSize: size <= 24 ? 10 : AcoTypography.caption,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SwapField extends StatelessWidget {
  const _SwapField({
    required this.palette,
    required this.label,
    required this.symbol,
    required this.value,
  });
  final AcoPalette palette;
  final String label, symbol, value;
  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    border: true,
    radius: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: AcoTypography.headline,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                symbol,
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            const Spacer(),
            Text(
              '余额: 0.00',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Max',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.palette,
    required this.label,
    required this.value,
  });
  final AcoPalette palette;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _DiscoverShortcut extends StatelessWidget {
  const _DiscoverShortcut({
    required this.palette,
    required this.label,
    required this.onTap,
  });
  final AcoPalette palette;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final Color background;
    switch (label) {
      case '链上数据':
        background = const Color(0xFF3566D6);
        break;
      case 'NFT 市场':
        background = _black;
        break;
      case '交易工具':
        background = palette.surfaceRaised;
        break;
      default:
        background = const Color(0xFFEB2535);
    }

    return SizedBox(
      width: 108,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(CupertinoIcons.app_badge, color: _white),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketIcon extends StatelessWidget {
  const _MarketIcon({
    required this.palette,
    required this.icon,
    required this.label,
  });
  final AcoPalette palette;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.primaryText),
      ),
    ],
  );
}

class _MarketTabs extends StatelessWidget {
  const _MarketTabs({required this.palette});
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: palette.dark
              ? const Color(0xFFF0F0F0)
              : const Color(0xFF202020),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          '自选 ▼',
          style: TextStyle(
            color: _lime,
            fontSize: AcoTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 30),
      for (final label in const ['现货', '合约', 'DEX'])
        Padding(
          padding: const EdgeInsets.only(right: 30),
          child: Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: AcoTypography.body,
            ),
          ),
        ),
      const Spacer(),
      Icon(CupertinoIcons.chevron_right, color: palette.mutedText, size: 20),
    ],
  );
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.palette,
    required this.name,
    required this.tag,
    required this.price,
    required this.change,
  });
  final AcoPalette palette;
  final String name, tag, price, change;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: AcoTypography.body,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  color: _lime,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: _black,
                      fontSize: AcoTypography.caption,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '\$29.73万',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.body,
              ),
            ),
            Text(
              change,
              style: TextStyle(
                color: change.startsWith('-') ? _danger : _lime,
                fontSize: AcoTypography.bodySmall,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _GreenBadge extends StatelessWidget {
  const _GreenBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
    child: Text(
      label,
      style: const TextStyle(
        color: _black,
        fontSize: AcoTypography.caption,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.palette,
    required this.label,
    required this.width,
  });
  final AcoPalette palette;
  final String label;
  final double width;
  @override
  Widget build(BuildContext context) {
    final isAldTopic = label == 'ALD! V587!';
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(
          color: palette.dark ? const Color(0xFF4A4A4A) : palette.border,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          if (isAldTopic)
            ClipOval(
              child: Image.asset(
                'assets/design_svg/source/images/img5.jpg',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4A4A4A)),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.play_rectangle,
                color: _lime,
                size: 22,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _lime,
                fontSize: AcoTypography.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, right: 10),
            child: _SignalGlyph(),
          ),
        ],
      ),
    );
  }
}

class _SignalGlyph extends StatelessWidget {
  const _SignalGlyph();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final height in [10.0, 16.0, 12.0])
        Container(
          width: 6,
          height: height,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ],
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.palette});
  final AcoPalette palette;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/design_svg/source/images/img3.jpg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '素素姐',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.bodyEmphasis,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: _lime,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '7小时前',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '365天盈利榜第1名',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.bodySmall,
                ),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PostOptionDot(color: palette.primaryText),
                const SizedBox(width: 6),
                _PostOptionDot(color: palette.primaryText),
                const SizedBox(width: 8),
                const _PostOptionStar(),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        '是非成败转头空，青山依旧在，惯看秋月春风。\n'
        '一壶浊酒喜相逢，古今多少事，滚滚长江东逝\n'
        '水，浪花淘尽英雄。几度夕阳红。白发渔樵江渚\n'
        '上，都付笑谈中。\n'
        '滚滚长江东逝水，浪花淘尽英雄。是非成败转头\n'
        '空，青山依旧在，几度夕阳红。白发渔樵江渚\n'
        '上，惯看秋月春风。一壶浊酒喜相逢，古今多少\n'
        '事，都付笑谈中。',
        style: TextStyle(
          color: palette.primaryText,
          height: 1.5,
          fontSize: AcoTypography.bodySmall,
        ),
      ),
      const SizedBox(height: 24),
      Container(
        height: 273,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PostAction(
            icon: CupertinoIcons.chat_bubble,
            label: '63',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.arrow_2_squarepath,
            label: '1',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.heart,
            label: '88',
            palette: palette,
          ),
          _PostAction(
            icon: CupertinoIcons.chart_bar,
            label: '12.64k',
            palette: palette,
          ),
          _PostAction(icon: CupertinoIcons.share, label: '', palette: palette),
        ],
      ),
    ],
  );
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.palette,
  });
  final IconData icon;
  final String label;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: palette.primaryText, size: 22),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodyEmphasis,
          ),
        ),
      ],
    ],
  );
}

class _PostOptionDot extends StatelessWidget {
  const _PostOptionDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _PostOptionStar extends StatelessWidget {
  const _PostOptionStar();

  @override
  Widget build(BuildContext context) =>
      const Icon(CupertinoIcons.sparkles, color: _lime, size: 10);
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.palette,
    required this.name,
    required this.onTap,
  });
  final AcoPalette palette;
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 12),
    onPressed: onTap,
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '你好，股票账户已就位',
                style: TextStyle(
                  color: palette.mutedText,
                  fontSize: AcoTypography.caption,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _GreenBadge(label: '14'),
            const SizedBox(height: 5),
            Text(
              '2026-08-05',
              style: TextStyle(
                color: palette.mutedText,
                fontSize: AcoTypography.caption,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.palette,
    required this.text,
    required this.mine,
  });
  final AcoPalette palette;
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 390),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: mine ? _lime : palette.surfaceRaised,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: mine ? _black : palette.primaryText,
        height: 1.4,
        fontSize: AcoTypography.bodyEmphasis,
      ),
    ),
  );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.palette,
    required this.session,
    this.onTap,
    this.onEdit,
  });
  final AcoPalette palette;
  final LiveSession session;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  String? get _scheduledStartLabel {
    final scheduledAt = session.scheduledAt;
    if (session.status != 'scheduled' || scheduledAt == null) return null;
    final localTime = scheduledAt.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '开始时间 ${localTime.month}月${localTime.day}日 $hour:$minute';
  }

  bool get _isLive => session.status == 'live';

  String get _statusLabel {
    switch (session.status) {
      case 'live':
        return '直播中';
      case 'scheduled':
        return '预约中';
      case 'ended':
        return '已结束';
      default:
        return session.status;
    }
  }

  Color get _statusColor =>
      _isLive || session.status == 'scheduled' ? _lime : palette.mutedText;

  Color get _statusBackground => _statusColor.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    final scheduledStartLabel = _scheduledStartLabel;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              palette.dark
                  ? 'assets/icons/live_brand_dark.png'
                  : 'assets/icons/live_brand_light.png',
              width: 52,
              height: 52,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (session.status.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              color: _statusColor,
                              fontSize: AcoTypography.caption,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (scheduledStartLabel != null) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              scheduledStartLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primaryText,
                                fontSize: AcoTypography.caption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              AcoIconButton(
                icon: CupertinoIcons.pencil,
                palette: palette,
                label: '修改直播',
                size: 20,
                onPressed: onEdit!,
              ),
            ],
          ],
        ),
        if (session.coverUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              _liveCoverUrl(session.coverUrl),
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _LiveCoverPlaceholder(palette: palette),
            ),
          ),
        ],
      ],
    );
    return onTap == null
        ? content
        : CupertinoButton(
            padding: EdgeInsets.zero,
            pressedOpacity: 0.72,
            onPressed: onTap,
            child: content,
          );
  }
}

String _liveCoverUrl(String coverUrl) {
  if (Uri.tryParse(coverUrl)?.hasScheme ?? false) return coverUrl;
  final apiUri = Uri.parse(const AppConfig().apiBaseUrl);
  return apiUri.replace(path: coverUrl).toString();
}

class _LiveCoverPlaceholder extends StatelessWidget {
  const _LiveCoverPlaceholder({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 220,
    color: palette.surfaceRaised,
    alignment: Alignment.center,
    child: Icon(CupertinoIcons.photo, color: palette.mutedText, size: 30),
  );
}

class _LiveCoverThumbnailFallback extends StatelessWidget {
  const _LiveCoverThumbnailFallback({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 52,
    decoration: BoxDecoration(
      color: palette.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(CupertinoIcons.photo, color: palette.mutedText, size: 26),
  );
}

class _LiveListMessage extends StatelessWidget {
  const _LiveListMessage({
    required this.palette,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final AcoPalette palette;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        Icon(CupertinoIcons.video_camera, color: palette.mutedText, size: 32),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            onPressed: onPressed,
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class _LiveRoomHostCard extends StatelessWidget {
  const _LiveRoomHostCard({
    required this.palette,
    required this.host,
    required this.active,
  });

  final AcoPalette palette;
  final LiveParticipant host;
  final bool active;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Column(
      children: [
        _buildHostAvatar(),
        const SizedBox(height: 14),
        Text(
          host.nickname,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.title,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '主持人',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.body,
          ),
        ),
      ],
    ),
  );

  Widget _buildHostAvatar() => Stack(
    clipBehavior: Clip.none,
    children: [
      ColorFiltered(
        colorFilter: active
            ? const ColorFilter.mode(_transparent, BlendMode.dst)
            : const ColorFilter.matrix(<double>[
                .2126,
                .7152,
                .0722,
                0,
                0,
                .2126,
                .7152,
                .0722,
                0,
                0,
                .2126,
                .7152,
                .0722,
                0,
                0,
                0,
                0,
                0,
                .48,
                0,
              ]),
        child: AcoAvatar(size: 108, assetPath: _liveRoomHostAvatarAsset),
      ),
      Positioned(
        right: -3,
        bottom: -3,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? _lime : palette.mutedText,
            shape: BoxShape.circle,
            border: Border.all(color: palette.background, width: 3),
          ),
          child: Icon(
            active ? CupertinoIcons.mic_fill : CupertinoIcons.mic_slash,
            color: palette.background,
            size: 18,
          ),
        ),
      ),
    ],
  );
}

class _LiveRoomHeaderActions extends StatelessWidget {
  const _LiveRoomHeaderActions({
    required this.palette,
    required this.count,
    this.onMore,
  });

  final AcoPalette palette;
  final int? count;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: palette.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.person_2,
                size: 15,
                color: palette.primaryText,
              ),
              const SizedBox(width: 4),
              Text(
                count == null ? '—' : '$count 人',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: AcoTypography.bodySmall,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onMore != null)
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            minimumSize: const Size(44, 44),
            onPressed: onMore,
            child: Icon(
              CupertinoIcons.ellipsis,
              color: palette.primaryText,
              size: 22,
            ),
          ),
      ],
    );
  }
}

class _RaisedHandIndicator extends StatelessWidget {
  const _RaisedHandIndicator({
    required this.palette,
    required this.count,
    required this.onPressed,
  });

  final AcoPalette palette;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count 人申请发言',
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.dark ? const Color(0xE6292929) : palette.surfaceRaised,
          border: Border.all(color: _lime.withValues(alpha: .52)),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 11, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.hand_raised_fill,
                  color: _black,
                  size: 15,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: const TextStyle(
                  color: _lime,
                  fontSize: AcoTypography.bodySmall,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LiveRoomParticipantStage extends StatelessWidget {
  const _LiveRoomParticipantStage({
    required this.palette,
    required this.speakers,
  });

  final AcoPalette palette;
  final List<LiveParticipant> speakers;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 16,
      children: [
        for (final participant in speakers)
          _LiveRoomParticipantCard(palette: palette, participant: participant),
      ],
    ),
  );
}

class _LiveRoomListenerSection extends StatelessWidget {
  const _LiveRoomListenerSection({
    required this.palette,
    required this.listeners,
  });

  final AcoPalette palette;
  final List<LiveParticipant> listeners;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 22,
        runSpacing: 16,
        children: [
          for (final listener in listeners)
            _LiveRoomParticipantCard(palette: palette, participant: listener),
        ],
      ),
    ),
  );
}

class _LiveRoomParticipantCard extends StatelessWidget {
  const _LiveRoomParticipantCard({
    required this.palette,
    required this.participant,
  });

  final AcoPalette palette;
  final LiveParticipant participant;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 86,
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AcoAvatar(size: 58, assetPath: _liveRoomListenerAvatarAsset),
            if (participant.role != 'speaker' || participant.muted)
              Positioned(
                right: -2,
                bottom: -2,
                child: _MutedMicrophoneBadge(palette: palette),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          participant.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: AcoTypography.bodySmall,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          participant.role == 'speaker'
              ? (participant.muted ? '已静音' : '发言中')
              : '听众',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
      ],
    ),
  );
}

class _MutedMicrophoneBadge extends StatelessWidget {
  const _MutedMicrophoneBadge({required this.palette});

  final AcoPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 23,
    height: 23,
    decoration: BoxDecoration(
      color: palette.mutedText,
      shape: BoxShape.circle,
      border: Border.all(color: palette.background, width: 2),
    ),
    child: Icon(
      CupertinoIcons.mic_slash_fill,
      color: palette.background,
      size: 13,
    ),
  );
}

class _LiveRoomInfoNotice extends StatelessWidget {
  const _LiveRoomInfoNotice();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xE6000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '已举手，请等待主持人批准',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _white,
          fontSize: AcoTypography.bodySmall,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _LiveRoomStatus extends StatelessWidget {
  const _LiveRoomStatus({
    required this.palette,
    required this.room,
    this.onRemove,
  });

  final AcoPalette palette;
  final LiveRoom room;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ParticipantActions(
          users: room.speakers,
          action: onRemove,
          label: '停止 {name} 发言',
        ),
      ],
    ),
  );
}

class _RaisedHandRequests extends StatelessWidget {
  const _RaisedHandRequests({
    required this.palette,
    required this.users,
    required this.onClose,
    required this.onApprove,
    required this.onReject,
    this.maxHeight = 248,
  });

  final AcoPalette palette;
  final List<LiveParticipant> users;
  final VoidCallback onClose;
  final ValueChanged<int> onApprove;
  final ValueChanged<int> onReject;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF21F1F1F),
        border: Border.all(color: _white.withValues(alpha: .12)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.hand_raised_fill,
                    color: _black,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '申请发言',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: AcoTypography.bodySmall,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _lime.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${users.length}',
                    style: const TextStyle(
                      color: _lime,
                      fontSize: AcoTypography.caption,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.only(left: 8),
                  minimumSize: const Size(28, 28),
                  onPressed: onClose,
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: palette.mutedText,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: users.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: _white.withValues(alpha: .08)),
                itemBuilder: (context, index) => _RaisedHandRequestChip(
                  palette: palette,
                  user: users[index],
                  onApprove: onApprove,
                  onReject: onReject,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RaisedHandRequestChip extends StatelessWidget {
  const _RaisedHandRequestChip({
    required this.palette,
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final AcoPalette palette;
  final LiveParticipant user;
  final ValueChanged<int> onApprove;
  final ValueChanged<int> onReject;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        AcoAvatar(size: 32, assetPath: _liveRoomListenerAvatarAsset),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            user.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.bodySmall,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _RaisedHandAction(
          icon: CupertinoIcons.checkmark,
          label: '允许',
          color: _lime,
          onPressed: () => onApprove(user.userId),
        ),
        const SizedBox(width: 4),
        _RaisedHandAction(
          icon: CupertinoIcons.xmark,
          label: '拒绝',
          color: palette.mutedText,
          onPressed: () => onReject(user.userId),
        ),
      ],
    ),
  );
}

class _RaisedHandAction extends StatelessWidget {
  const _RaisedHandAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(30, 30),
    onPressed: onPressed,
    child: Semantics(
      button: true,
      label: label,
      child: Icon(icon, color: color, size: 17),
    ),
  );
}

class _ParticipantActions extends StatelessWidget {
  const _ParticipantActions({
    required this.users,
    required this.action,
    required this.label,
  });

  final List<LiveParticipant> users;
  final ValueChanged<int>? action;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (action == null || users.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: users
            .map(
              (user) => CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(32, 32),
                onPressed: () => action!(user.userId),
                child: Text(label.replaceFirst('{name}', user.nickname)),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _RoomMessage extends StatelessWidget {
  const _RoomMessage({
    required this.palette,
    required this.name,
    required this.text,
  });
  final AcoPalette palette;
  final String name;
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.dark ? const Color(0xFF3D3D3D) : palette.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$name:  $text',
        style: TextStyle(
          color: palette.dark ? _lime : palette.primaryText,
          fontSize: AcoTypography.bodySmall,
          height: 1.2,
        ),
      ),
    ),
  );
}

class _RoomChatHistory extends StatelessWidget {
  const _RoomChatHistory({
    required this.palette,
    required this.hasLive,
    this.liveMessages,
  });
  final AcoPalette palette;
  final bool hasLive;
  final List<LiveMessage>? liveMessages;

  @override
  Widget build(BuildContext context) {
    final roomMessages = liveMessages;
    if (roomMessages == null || roomMessages.isEmpty) {
      return Center(
        child: Text(
          hasLive ? '还没有弹幕，来说点什么吧。' : '请选择直播间后查看弹幕。',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.bodySmall,
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('room-chat-history'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      itemCount: roomMessages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _RoomMessage(
        palette: palette,
        name: roomMessages[index].nickname,
        text: roomMessages[index].text,
      ),
    );
  }
}

class _RoomEmojiPicker extends StatelessWidget {
  const _RoomEmojiPicker({
    required this.palette,
    required this.controller,
    required this.onEmojiSelected,
  });
  final AcoPalette palette;
  final TextEditingController controller;
  final VoidCallback onEmojiSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 292,
    child: emoji.EmojiPicker(
      textEditingController: controller,
      onEmojiSelected: (_, _) => onEmojiSelected(),
      config: emoji.Config(
        height: 292,
        checkPlatformCompatibility: false,
        emojiViewConfig: emoji.EmojiViewConfig(
          backgroundColor: palette.surfaceRaised,
          columns: 8,
          emojiSizeMax: 28,
          buttonMode: emoji.ButtonMode.CUPERTINO,
        ),
        categoryViewConfig: emoji.CategoryViewConfig(
          initCategory: emoji.Category.SMILEYS,
          backgroundColor: palette.surfaceRaised,
          indicatorColor: _lime,
          iconColor: palette.mutedText,
          iconColorSelected: _lime,
          backspaceColor: palette.primaryText,
          dividerColor: _transparent,
        ),
        bottomActionBarConfig: const emoji.BottomActionBarConfig(
          enabled: false,
        ),
      ),
    ),
  );
}

class _RoomComposer extends StatelessWidget {
  const _RoomComposer({
    required this.palette,
    required this.controller,
    required this.chatMuted,
    required this.onEmojiPressed,
    required this.onSubmitted,
  });
  final AcoPalette palette;
  final TextEditingController controller;
  final bool chatMuted;
  final VoidCallback onEmojiPressed;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: Container(
      decoration: BoxDecoration(
        color: chatMuted
            ? palette.surfaceRaised.withValues(alpha: 0.72)
            : palette.surfaceRaised,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: chatMuted ? null : onEmojiPressed,
              child: Icon(
                CupertinoIcons.smiley,
                color: chatMuted ? palette.mutedText : palette.primaryText,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              key: const Key('room-message-input'),
              maxLines: 1,
              controller: controller,
              enabled: !chatMuted,
              textInputAction: TextInputAction.send,
              cursorColor: _lime,
              padding: const EdgeInsets.only(right: 14),
              placeholder: chatMuted ? '全员禁言中' : '说点什么...',
              placeholderStyle: TextStyle(
                color: chatMuted ? palette.mutedText : palette.primaryText,
                fontSize: AcoTypography.bodySmall,
              ),
              style: TextStyle(
                color: chatMuted ? palette.mutedText : palette.primaryText,
                fontSize: AcoTypography.bodySmall,
              ),
              onSubmitted: (message) {
                if (!chatMuted && message.trim().isNotEmpty) onSubmitted();
              },
              decoration: const BoxDecoration(color: _transparent),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomBottomBar extends StatelessWidget {
  const _RoomBottomBar({
    required this.palette,
    required this.muted,
    required this.canSpeak,
    required this.audioMuted,
    required this.handRaised,
    required this.chatMuted,
    required this.onMic,
    required this.onHand,
    required this.controller,
    required this.onEmojiPressed,
    required this.onSubmitted,
  });
  final AcoPalette palette;
  final bool muted;
  final bool canSpeak;
  final bool audioMuted;
  final bool handRaised;
  final bool chatMuted;
  final VoidCallback? onMic;
  final VoidCallback? onHand;
  final TextEditingController controller;
  final VoidCallback onEmojiPressed;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final micColors = _micControlColors();
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: Row(
          children: [
            _RoomControl(
              icon: canSpeak && !muted
                  ? CupertinoIcons.mic
                  : CupertinoIcons.mic_slash,
              label: audioMuted
                  ? '全员静音中'
                  : canSpeak
                  ? (muted ? '取消静音' : '静音')
                  : '获准后可发言',
              background: micColors.background,
              foreground: micColors.foreground,
              onPressed: onMic,
              large: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RoomComposer(
                palette: palette,
                controller: controller,
                chatMuted: chatMuted,
                onEmojiPressed: onEmojiPressed,
                onSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 8),
            _RoomControl(
              icon: CupertinoIcons.hand_raised_fill,
              label: handRaised ? '已举手' : '举手',
              background: palette.surfaceRaised,
              foreground: palette.primaryText,
              onPressed: handRaised ? null : onHand,
              large: true,
            ),
          ],
        ),
      ),
    );
  }

  _RoomControlColors _micControlColors() {
    if (!canSpeak || audioMuted) {
      return _RoomControlColors(
        background: palette.surfaceRaised,
        foreground: palette.mutedText,
      );
    }
    if (!muted || palette.dark) {
      return const _RoomControlColors(background: _lime, foreground: _black);
    }
    return const _RoomControlColors(
      background: Color(0xFFF2F2F2),
      foreground: _danger,
    );
  }
}

class _RoomControlColors {
  const _RoomControlColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class _RoomControl extends StatelessWidget {
  const _RoomControl({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.large = false,
  });
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final bool large;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: SizedBox.square(
      dimension: 48,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        onPressed: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Center(
            child: Icon(icon, color: foreground, size: large ? 18 : 17),
          ),
        ),
      ),
    ),
  );
}

class _MiningTile extends StatelessWidget {
  const _MiningTile({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
  });
  final AcoPalette palette;
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => AcoSurface(
    palette: palette,
    radius: 24,
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.primaryText, size: 30),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: AcoTypography.headline,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
