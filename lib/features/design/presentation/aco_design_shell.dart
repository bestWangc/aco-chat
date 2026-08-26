import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_session.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/features/legal/presentation/legal_document_page.dart';
import 'package:aco_chat/shared/widgets/aco_page_header.dart';
import 'package:aco_chat/services/biometric_authentication.dart';
import 'package:aco_chat/services/sensitive_screen_protection.dart';
import 'package:aco_chat/services/wallet_security.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:aco_chat/services/wallet_valuation_service.dart';
import 'package:aco_chat/services/wallet_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'aco_design_models.dart';
part 'live_room_widgets.dart';
part 'live_room_chat_widgets.dart';
part 'mining_page.dart';
part 'profile_settings_pages.dart';
part 'wallet_common_widgets.dart';
part 'explore_pages.dart';
part 'wallet_welcome_page.dart';
part 'wallet_setup_flow.dart';
part 'wallet_home_page.dart';

// LiveKit's audio-session controls are experimental in the current SDK.
// ignore_for_file: experimental_member_use

const _lime = Color(0xFFA1FF00);
const _danger = Color(0xFFFF3B4E);
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _transparent = Color(0x00000000);
const _accentGreen = Color(0xFFA6DE00);

void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
// Leave a small amount of headroom while the system keyboard resizes the
// voice-room body. Some Android viewport sizes otherwise round the remaining
// height down by a physical pixel and overflow the room content.
const _roomBottomBarHeight = 82.0;
const _roomEmojiPickerHeight = 292.0;
// Colors and geometry are sampled from 设计图/钱包页-dark.svg.
const _loginSecondarySurface = Color(0xFF515151);
// 首页-dark.svg is a 595.28pt-wide artboard. These are its measurements
// converted once for the app's 400pt logical canvas, rather than scaled at
// runtime from the screen width.
const _welcomeContentInsetMin = 24.0;
const _welcomeContentInsetMax = 48.0;
const _welcomeDesignWidth = 400.0;
const _welcomeContentTop = 487.6092;
const _welcomeContentEstimatedHeight = 240.0;
const _welcomeContentBottomInset = 56.0;
const _welcomeButtonHeight = 48.0;
const _welcomeButtonGap = 12.4513;
const _welcomeCheckboxSize = 12.0;
const _welcomeCheckboxTopInset = 3.0;
const _welcomeAgreementFontSize = 13.0;
const _welcomeBrandWidth = 215.0;
const _welcomeBrandHeight = 42.0258;
const _welcomeTitleFontSize = 26.0;
const _welcomeBrandToTitleGap = 10.0793;
const _welcomeTitleToAgreementGap = 15.4549;
const _welcomeAgreementToActionsGap = 23.5184;
const _welcomeActionFontSize = 17.0;
const _walletHeaderMuted = Color(0xFF989798);
// Wallet artboard uses the same neon accent as the supplied design capture.
const _walletHeaderLime = _accentGreen;
const _walletNavInactive = Color(0xFFC2C2C2);
// Root pages already sit inside the shell's SafeArea. Keep only a compact
// visual breathing room below the status bar instead of duplicating it.
const _rootPageTopInset = 0.0;
const _walletHeaderWalletIconWidth = 36.0;
const _walletHeaderWalletIconHeight = 32.0;
const _walletHeaderWalletArrowWidth = 15.50;
const _walletHeaderWalletArrowHeight = 13.42;
const _walletChainRailWidth = 78.0;
const _walletChainRailItemHeight = 70.0;
const _walletChainRailIndicatorWidth = 4.0;
const _walletChainCardHorizontalPadding = 14.0;
const _walletCurrentCardColor = Color(0xFF171717);
const _walletInactiveCardBorderColor = Color(0xFF1C1C1C);
const _walletDetailDeleteColor = Color(0xFFEF476F);
const _walletDetailBorderColor = Color(0xFF111111);
const _walletHeaderNetworkWidth = 88.81;
const _walletActionSurface = Color(0xFFEFF0F1);
const _walletActionForeground = Color(0xFF040000);
const _navLabels = ['钱包', '探索', 'DEX', '广场', '社交'];
const _navAssets = [
  'assets/icons/source_wallet.png',
  'assets/icons/source_explore.png',
  'assets/icons/source_dex.svg',
  'assets/icons/source_square.png',
  'assets/icons/source_social.png',
];

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

class AcoDesignShell extends StatefulWidget {
  const AcoDesignShell({
    this.themeNotifier,
    this.onThemeChanged,
    this.onWalletReady,
    this.onWalletSelected,
    this.walletIdentity,
    this.accountProfile,
    this.walletLoginFuture,
    super.key,
  });

  /// Owned by [AcoApp] so the Cupertino and shadcn themes update together.
  final ValueNotifier<bool>? themeNotifier;
  final ValueChanged<bool>? onThemeChanged;
  final Future<void> Function(WalletIdentity, String)? onWalletReady;
  final Future<void> Function(WalletIdentity)? onWalletSelected;
  final WalletIdentity? walletIdentity;
  final AccountProfile? accountProfile;
  final Future<AccountProfile?>? walletLoginFuture;

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

  Future<void> _completeAddedWallet(
    WalletIdentity identity,
    String mnemonic,
  ) async {
    await widget.onWalletReady?.call(identity, mnemonic);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _selectWallet(WalletIdentity identity) async {
    await widget.onWalletSelected?.call(identity);
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
      AcoScreen.walletSetupCreate => AcoScreen.walletSetupCreate,
      AcoScreen.walletSetupImport => AcoScreen.walletSetupImport,
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
        .push<Object?>(
          _AcoPageRoute<Object?>(
            builder: (_) => _buildSecondaryScreen(destination),
          ),
        )
        .then((created) {
          if (screen != AcoScreen.createLive || !mounted) return;
          setState(() => _liveListRevision++);
          if (created is! LiveSession || created.status != 'live') return;
          Navigator.of(context).push<bool>(
            _AcoPageRoute<bool>(
              builder: (_) => CupertinoPageScaffold(
                backgroundColor: AcoPalette(_isDark.value).background,
                resizeToAvoidBottomInset: true,
                child: SafeArea(
                  bottom: false,
                  child: ColoredBox(
                    color: AcoPalette(_isDark.value).background,
                    child: _VoiceRoomPage(
                      palette: AcoPalette(_isDark.value),
                      live: created,
                    ),
                  ),
                ),
              ),
            ),
          );
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
      onWalletReady: _completeAddedWallet,
      onWalletSelected: _selectWallet,
      walletIdentity: widget.walletIdentity,
      walletName: _walletName.value,
      onWalletNameChanged: _saveWalletName,
      walletChainIndex: _selectedWalletChain.value,
      onWalletChainSelected: _selectWalletChain,
      transferToken: _selectedTransferToken,
      onSendTokenSelected: _sendToken,
      accountId: _accountId,
      walletLoginFuture: widget.walletLoginFuture,
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
        backgroundColor: dark && _rootScreen == AcoScreen.walletHome
            ? _black
            : AcoPalette(dark).background,
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
                      walletLoginFuture: widget.walletLoginFuture,
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

class AcoScreenPage extends StatelessWidget {
  const AcoScreenPage({
    required this.screen,
    required this.dark,
    required this.isRoot,
    required this.onOpen,
    required this.onThemeToggle,
    this.onWalletReady,
    this.onWalletSelected,
    this.displayName,
    this.accountId,
    this.walletLoginFuture,
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
  final Future<void> Function(WalletIdentity, String)? onWalletReady;
  final Future<void> Function(WalletIdentity)? onWalletSelected;
  final String? displayName;
  final String? accountId;
  final Future<AccountProfile?>? walletLoginFuture;
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
        walletLoginFuture: walletLoginFuture,
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
        onWalletSelected: onWalletSelected ?? (_) async {},
      ),
      AcoScreen.walletSwitcher => _WalletChains(
        palette: palette,
        onOpen: onOpen,
        walletIdentity: walletIdentity,
        walletName: walletName,
        selectedChain: walletChainIndex,
        onChainSelected: onWalletChainSelected ?? (_) {},
        onWalletSelected: onWalletSelected ?? (_) async {},
      ),
      AcoScreen.walletSetupCreate => _WalletSetupFlow(
        dark: dark,
        mode: _WalletSetupMode.create,
        requireSecuritySetup: false,
        onBack: () => Navigator.of(context).pop(),
        onComplete: onWalletReady ?? (_, _) async {},
      ),
      AcoScreen.walletSetupImport => _WalletSetupFlow(
        dark: dark,
        mode: _WalletSetupMode.import,
        requireSecuritySetup: false,
        onBack: () => Navigator.of(context).pop(),
        onComplete: onWalletReady ?? (_, _) async {},
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
        walletLoginFuture: walletLoginFuture,
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
      AcoScreen.createLive => _CreateLivePage(
        palette: palette,
        walletLoginFuture: walletLoginFuture,
      ),
    };

    return SizedBox.expand(
      child: ColoredBox(
        color: dark && screen == AcoScreen.walletHome
            ? _black
            : palette.background,
        child: _AcoViewport(
          child: SafeArea(
            top: !isRoot,
            minimum: EdgeInsets.zero,
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
    this.backgroundColor,
    super.key,
  });

  final int selected;
  final bool dark;
  final ValueChanged<int> onSelected;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = AcoPalette(dark);
    return ColoredBox(
      color:
          backgroundColor ??
          (dark ? const Color(0xFF000000) : palette.background),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: SizedBox(
          height: 58,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < _navLabels.length; index++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected == index,
                    label: _navLabels[index],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(index),
                      child: SizedBox.expand(
                        child: _FigmaNavItem(
                          index: index,
                          selected: selected == index,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FigmaNavItem extends StatelessWidget {
  const _FigmaNavItem({
    required this.index,
    required this.selected,
    required this.palette,
  });

  final int index;
  final bool selected;
  final AcoPalette palette;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (selected) {
      color = palette.dark ? _walletHeaderLime : palette.primaryText;
    } else {
      color = palette.dark ? _walletNavInactive : palette.navInactive;
    }
    if (index == 2) {
      return ExcludeSemantics(child: _DexBottomNavIcon(selected: selected));
    }
    // Normal navigation icons share one visual scale.
    final iconSize = switch (index) {
      0 => const Size(22, 18),
      1 => const Size(24, 21),
      3 => const Size(20, 19),
      4 => const Size(24, 20),
      _ => const Size(26, 24),
    };
    final icon = ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(_navAssets[index], fit: BoxFit.contain),
    );
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // All icons share the same bottom edge, then the label follows
          // immediately. This avoids SVG-specific offsets.
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: SizedBox(
                  width: iconSize.width,
                  height: iconSize.height,
                  child: icon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _navLabels[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DexBottomNavIcon extends StatelessWidget {
  const _DexBottomNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    // DEX is a two-part mark (wordmark + triangle), not an icon with a label.
    // Its visual bounds are intentionally taller and sit slightly higher than
    // the four regular navigation destinations.
    padding: const EdgeInsets.only(top: 8),
    child: SizedBox(
      width: 40,
      height: 38,
      child: Transform.translate(
        offset: const Offset(0, -16),
        child: Transform.scale(
          scale: .90,
          child: SvgPicture.asset(
            selected
                ? 'assets/icons/source_dex_active.svg'
                : 'assets/icons/source_dex_inactive.svg',
            fit: BoxFit.contain,
          ),
        ),
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
      SizedBox(width: 6 * scale),
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
        // Keep the original aspect ratios while reducing the visual weight;
        // the surrounding 44pt button remains the touch target.
        width: (asset.contains('source_scan') ? 22 : 22.5) * scale,
        height: (asset.contains('source_scan') ? 27 : 25) * scale,
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
    this.backgroundColor,
    this.minHeight,
    super.key,
  });
  final AcoPalette palette;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;
  final Color? backgroundColor;
  final double? minHeight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: minHeight == null
        ? null
        : BoxConstraints(minHeight: minHeight!),
    decoration: BoxDecoration(
      border: border ? Border.all(color: palette.border) : null,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: shad.ShadCard(
      padding: padding,
      radius: BorderRadius.circular(radius),
      backgroundColor: backgroundColor ?? palette.surface,
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
    this.showSubmit = false,
    super.key,
  });
  final AcoPalette palette;
  final String hint;
  final VoidCallback? onSubmit;
  final Widget? action;
  final double height;
  final IconData submitIcon;
  final AcoSearchVariant variant;
  final bool showSubmit;

  @override
  Widget build(BuildContext context) {
    final isSquareComposer = variant == AcoSearchVariant.squareComposer;
    final submitWidth = isSquareComposer ? 48.0 : height;
    final borderColor = _borderColor(isSquareComposer);
    var iconColor = palette.mutedText;
    var hintColor = palette.mutedText;
    if (palette.dark) {
      iconColor = isSquareComposer
          ? const Color(0xFF212121)
          : const Color(0xFFF7F7F7);
      hintColor = isSquareComposer
          ? const Color(0xFFF2F2F2)
          : const Color(0xFF888888);
    }
    final submitChild = _buildSubmitChild(isSquareComposer);

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
          if (isSquareComposer)
            SizedBox(
              width: 20,
              height: 16,
              child: Image.asset(
                'assets/icons/square_search.png',
                filterQuality: FilterQuality.high,
              ),
            )
          else
            Icon(CupertinoIcons.search, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: hintColor,
                fontSize: isSquareComposer
                    ? AcoTypography.caption
                    : AcoTypography.body,
              ),
            ),
          ),
          ?action,
          if (onSubmit != null || showSubmit)
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
                  color: isSquareComposer ? const Color(0xFFD7D7D7) : _lime,
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

  Widget _buildSubmitChild(bool isSquareComposer) {
    if (submitIcon != CupertinoIcons.add) {
      return Icon(submitIcon, color: _black, size: height > 48 ? 30 : 24);
    }

    if (isSquareComposer) {
      return Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: Image.asset(
            'assets/icons/square_search_add.png',
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }

    final plusAsset = palette.dark
        ? 'assets/icons/design_plus_dark.png'
        : 'assets/icons/design_plus_light.png';
    return Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: Image.asset(plusAsset, filterQuality: FilterQuality.high),
      ),
    );
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
    builder: (sheetContext) {
      final themeColor = CupertinoTheme.of(sheetContext).primaryColor;
      return CupertinoActionSheet(
        title: Text(
          title,
          style: TextStyle(
            fontSize: AcoTypography.bodyEmphasis,
            fontWeight: FontWeight.w700,
          ),
        ),
        message: Text(
          message,
          style: TextStyle(fontSize: AcoTypography.bodySmall),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(
              '知道了',
              style: TextStyle(
                color: themeColor,
                fontSize: AcoTypography.bodyEmphasis,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(
            '取消',
            style: TextStyle(
              color: themeColor,
              fontSize: AcoTypography.bodyEmphasis,
            ),
          ),
        ),
      );
    },
  );
}

void showAcoAlertNotice(BuildContext context, String title, String message) {
  showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) {
      final themeColor = CupertinoTheme.of(dialogContext).primaryColor;
      return CupertinoAlertDialog(
        title: Text(title, style: TextStyle(color: themeColor)),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message, style: TextStyle(color: themeColor)),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('知道了', style: TextStyle(color: themeColor)),
          ),
        ],
      );
    },
  );
}

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

class _CreateLivePage extends StatefulWidget {
  const _CreateLivePage({
    required this.palette,
    this.live,
    this.walletLoginFuture,
  });
  final AcoPalette palette;
  final LiveSession? live;
  final Future<AccountProfile?>? walletLoginFuture;

  @override
  State<_CreateLivePage> createState() => _CreateLivePageState();
}

class _CreateLivePageState extends State<_CreateLivePage> {
  // Covers are resized and JPEG-compressed by image_picker before upload. Keep
  // a smaller client-side limit so mobile users do not waste bandwidth on
  // unnecessarily large originals (the API still enforces its 5 MB limit).
  static const _maxCoverSizeBytes = 3 * 1024 * 1024;

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
    _dismissKeyboard();
    final title = _titleController.text.trim();
    final apiClient = AccountApiClient();
    LiveSession? createdLive;
    setState(() => _submitting = true);
    try {
      // Startup account restoration is asynchronous; wait for its token.
      await widget.walletLoginFuture;
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
        createdLive = await session.createLive(
          title: title,
          coverBytes: coverBytes,
          access: _joinPassword == null ? 'open' : 'password',
          joinPassword: _joinPassword,
          scheduledAt: _scheduledAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(createdLive ?? true);
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
    _dismissKeyboard();
    final now = DateTime.now();
    var selected = _scheduledAt ?? now.add(const Duration(hours: 1));
    final palette = widget.palette;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: palette.accent,
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
                            color: _isEditing
                                ? palette.mutedText
                                : palette.accent,
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
                          style: TextStyle(
                            color: palette.accent,
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
    _dismissKeyboard();
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 72,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > _maxCoverSizeBytes) {
      _showNotice(context, '图片过大', '请选择小于 3 MB 的直播封面。');
      return;
    }

    setState(() {
      _coverBytes = bytes;
      _coverChanged = true;
    });
  }

  String get _joinAccessLabel => _joinPassword == null ? '任何人直接加入' : '需要密码才能加入';

  Future<void> _selectJoinAccess() async {
    _dismissKeyboard();
    final palette = widget.palette;
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: palette.accent,
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
    _dismissKeyboard();
    final palette = widget.palette;
    var password = _joinPassword ?? '';
    final confirmedPassword = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: palette.accent,
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
                onSubmitted: (value) {
                  if (value.trim().length >= 4) {
                    Navigator.of(dialogContext).pop(value.trim());
                  }
                },
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
                  height: 156,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  decoration: BoxDecoration(
                    color: _createLiveCardColor(palette),
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
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _dismissKeyboard(),
                          onTapOutside: (_) => _dismissKeyboard(),
                          placeholder: '输入直播主题',
                          placeholderStyle: TextStyle(
                            color: palette.mutedText,
                            fontSize: AcoTypography.body,
                          ),
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: AcoTypography.body,
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
                            fontSize: AcoTypography.caption,
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
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _createLiveCardColor(palette),
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
                                      fontSize: AcoTypography.body,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    hasCover ? '更换封面' : '上传封面',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontSize: AcoTypography.body,
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
                                    fontSize: AcoTypography.caption,
                                  ),
                                )
                              else
                                Text(
                                  '建议使用横向图片',
                                  style: TextStyle(
                                    color: palette.mutedText,
                                    fontSize: AcoTypography.caption,
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
                height: 44,
                child: CupertinoButton(
                  key: const Key('confirm-create-live-button'),
                  padding: EdgeInsets.zero,
                  onPressed: canConfirm ? _confirm : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: canConfirm
                          ? palette.accent
                          : _createLiveCardColor(palette),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _submitting
                        ? const CupertinoActivityIndicator(color: _black)
                        : Text(
                            _isEditing ? '保存' : '确认',
                            style: TextStyle(
                              color: canConfirm ? _black : palette.mutedText,
                              fontSize: AcoTypography.body,
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

Color _createLiveCardColor(AcoPalette palette) =>
    palette.dark ? const Color(0xFF161616) : palette.surface;

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
      height: subtitle == null ? 52 : 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _createLiveCardColor(palette),
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
                    fontSize: AcoTypography.body,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: AcoTypography.caption,
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
                color: highlighted ? palette.accent : palette.mutedText,
                fontSize: AcoTypography.body,
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
  const _VoiceRoomPage({required this.palette, this.live, this.joinPassword});
  final AcoPalette palette;
  final LiveSession? live;
  final String? joinPassword;

  @override
  State<_VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<_VoiceRoomPage>
    with WidgetsBindingObserver {
  static const _maxLiveMessageCount = 200;
  static const _maxLiveMessageBytes = 512;
  static const _minLiveMessageInterval = Duration(milliseconds: 250);
  static const _liveMessageRateWindow = Duration(seconds: 1);
  static const _maxLiveMessagesPerWindow = 20;
  static const _liveMessageRefreshInterval = Duration(milliseconds: 75);
  static const _liveAudioBackgroundChannel = MethodChannel(
    'aco/live-audio-background',
  );
  static const _liveAudioRouteChannel = MethodChannel('aco/live-audio-route');
  static const _communicationAudioSession = AudioSessionOptions.communication(
    apple: AppleAudioSessionConfiguration(
      category: AppleAudioCategory.playAndRecord,
      categoryOptions: {
        AppleAudioCategoryOption.allowBluetooth,
        AppleAudioCategoryOption.allowBluetoothA2DP,
        AppleAudioCategoryOption.allowAirPlay,
        AppleAudioCategoryOption.defaultToSpeaker,
      },
      mode: AppleAudioMode.videoChat,
    ),
  );
  static const _iosAudioUnitRecoveryDelay = Duration(milliseconds: 1200);
  static const _liveKitReentryCooldown = Duration(seconds: 5);
  static const _liveKitFallbackUrl = 'wss://api.aco.chat';
  static final Map<int, DateTime> _liveKitLeftAtByLiveID = <int, DateTime>{};
  static const _voiceRoomAudioCaptureOptions = AudioCaptureOptions(
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    highPassFilter: false,
    voiceIsolation: true,
    typingNoiseDetection: true,
    // Keep the WebRTC capture and its echo-cancellation reference alive while
    // muted. Recreating the microphone track on every unmute makes the audio
    // processor re-converge and can briefly reintroduce feedback.
    stopAudioCaptureOnMute: false,
  );
  static Future<void>? _liveKitInitialization;

  bool _muted = false;
  bool _handRaised = false;
  bool _emojiPickerVisible = false;
  bool _sending = false;
  bool _roomLoading = false;
  bool _leaving = false;
  bool _allowPop = false;
  bool _closingRoom = false;
  bool _handRaiseNoticeVisible = false;
  bool _networkReconnecting = false;
  bool _reentryCoolingDown = false;
  bool _checkingIn = false;
  int _scrollToLatestSignal = 0;
  int _reentryCooldownSeconds = 0;
  LiveRoom? _room;
  final Queue<LiveMessage> _messages = ListQueue<LiveMessage>();
  final Set<int> _knownMessageIds = <int>{};
  final Set<int> _knownParticipantIds = <int>{};
  WebSocketChannel? _eventChannel;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _realtimeReconnectStopped = false;
  Timer? _handRaiseNoticeTimer;
  Timer? _checkInTimer;
  Timer? _messageRefreshTimer;
  Timer? _hostHeartbeatTimer;
  Room? _liveKitRoom;
  EventsListener<RoomEvent>? _liveKitEventListener;
  bool _liveKitConnecting = false;
  bool _liveKitReconnecting = false;
  bool _liveKitReconnectStopped = false;
  final Set<String> _liveKitSpeakingParticipantIds = <String>{};
  bool? _liveKitCanPublish;
  bool _liveKitPublishReady = false;
  String? _liveKitRole;
  bool _microphoneUpdating = false;
  bool _liveKitMicrophoneOperationInFlight = false;
  bool _liveKitPermissionReconnectInFlight = false;
  LocalAudioTrack? _listenerAudioWarmupTrack;
  bool? _localMuteOverride;
  DateTime? _lastMessageSentAt;
  DateTime? _messageRateWindowStartedAt;
  int _messageRateWindowCount = 0;
  late final AccountApiClient _apiClient;
  late final AccountSession _accountSession;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setLiveRoomWakelock(true));
    _apiClient = AccountApiClient();
    _accountSession = AccountSession(_apiClient);
    if (widget.live != null) {
      unawaited(_initializeRoom());
    }
  }

  Future<void> _initializeRoom() async {
    final live = widget.live;
    if (live == null) return;
    if (mounted) setState(() => _roomLoading = true);
    await _waitForLiveKitReentryCooldown(live.id);
    if (!mounted || _leaving) return;
    // Load the current role before requesting the LiveKit token. Connecting
    // both requests concurrently can issue a second token refresh as soon as
    // the room snapshot arrives, creating two joins for the same participant.
    await _loadRoom();
    await _connectLiveKit();
    // The auxiliary state stream is started in the background; chat itself is
    // handled by LiveKit data.
    unawaited(_connectRealtime(refreshRoom: false));
  }

  Future<void> _connectLiveKit({bool showError = true}) async {
    final live = widget.live;
    if (live == null || !mounted || _leaving || _liveKitConnecting) return;
    _liveKitConnecting = true;
    setState(() {});
    _liveKitReconnectStopped = false;
    Room? connectingRoom;
    String? liveKitUrl;
    try {
      await _ensureLiveKitInitialized();
      await _configureLiveKitMicrophoneMuteMode();
      debugPrint('LiveKit connect: requesting join info for live ${live.id}');
      final joinInfo = await _accountSession.liveKitJoinInfo(
        live.id,
        joinPassword: widget.joinPassword,
      );
      liveKitUrl = joinInfo.url;
      debugPrint(
        'LiveKit connect: join info received, url=$liveKitUrl '
        'role=${joinInfo.role} canPublish=${joinInfo.canPublish} '
        'canPublishData=${joinInfo.canPublishData}',
      );
      var room = _createLiveKitRoom();
      connectingRoom = room;
      final previousRoom = _liveKitRoom;
      _liveKitRoom = null;
      _liveKitPublishReady = false;
      _liveKitEventListener?.dispose();
      _liveKitEventListener = null;
      _liveKitSpeakingParticipantIds.clear();
      await _disconnectLiveKitRoomSafely(previousRoom);
      await _prepareLiveKitAudioSession();
      var preConnectListener = room.createListener()
        ..on<TrackSubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio subscribed before connect listener: '
              '${event.participant.identity}/${event.publication.sid}',
            );
            unawaited(
              _logRemoteAudioTrackStats(
                event.track as RemoteAudioTrack,
                event.publication.sid,
                event.publication.muted,
              ),
            );
          }
        })
        ..on<AudioPlaybackStatusChanged>((event) {
          if (event.isPlaying) {
            unawaited(_logLiveKitAudioRouteAfterSpeakerReset('audio-playback'));
          }
        });
      debugPrint('LiveKit connect: starting Room.connect ($liveKitUrl)');
      try {
        await room.connect(joinInfo.url, joinInfo.token);
      } catch (primaryError) {
        if (joinInfo.url == _liveKitFallbackUrl) rethrow;
        debugPrint(
          'LiveKit primary connect failed ($primaryError), '
          'retrying $_liveKitFallbackUrl',
        );
        await _disconnectLiveKitRoomSafely(room);
        room = _createLiveKitRoom();
        connectingRoom = room;
        liveKitUrl = _liveKitFallbackUrl;
        preConnectListener.dispose();
        preConnectListener = room.createListener()
          ..on<TrackSubscribedEvent>((event) {
            if (event.track is RemoteAudioTrack) {
              debugPrint(
                'LiveKit remote audio subscribed before connect listener: '
                '${event.participant.identity}/${event.publication.sid}',
              );
              unawaited(
                _logRemoteAudioTrackStats(
                  event.track as RemoteAudioTrack,
                  event.publication.sid,
                  event.publication.muted,
                ),
              );
            }
          })
          ..on<AudioPlaybackStatusChanged>((event) {
            if (event.isPlaying) {
              unawaited(
                _logLiveKitAudioRouteAfterSpeakerReset('audio-playback'),
              );
            }
          });
        await room.connect(_liveKitFallbackUrl, joinInfo.token);
      }
      preConnectListener.dispose();
      debugPrint('LiveKit connect: Room.connect completed');
      unawaited(_logLiveKitAudioRoute('room-connect-completed'));
      if (!mounted || _leaving) {
        await _disconnectLiveKitRoomSafely(room);
        return;
      }
      _liveKitRoom = room;
      _liveKitEventListener = room.createListener()
        ..on<DataReceivedEvent>(_handleLiveKitData)
        ..on<TrackSubscribedEvent>((event) {
          // Keep iOS output routing applied after the first remote audio track
          // creates/activates the native WebRTC audio engine.
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio subscribed: '
              '${event.participant.identity}/${event.publication.sid}',
            );
            unawaited(
              _logRemoteAudioTrackStats(
                event.track as RemoteAudioTrack,
                event.publication.sid,
                event.publication.muted,
              ),
            );
          }
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (event.track is RemoteAudioTrack) {
            debugPrint(
              'LiveKit remote audio unsubscribed: '
              '${event.participant.identity}/${event.publication.sid}',
            );
          }
        })
        ..on<TrackUnpublishedEvent>((event) {
          if (event.publication.kind == TrackType.AUDIO) {
            debugPrint(
              'LiveKit remote audio unpublished: '
              '${event.participant.identity}/${event.publication.sid}',
            );
          }
        })
        ..on<TrackSubscriptionExceptionEvent>((event) {
          debugPrint(
            'LiveKit remote track subscription failed: '
            'participant=${event.participant?.identity} sid=${event.sid} '
            'reason=${event.reason}',
          );
        })
        ..on<AudioPlaybackStatusChanged>((event) {
          debugPrint('LiveKit audio playback status: ${event.isPlaying}');
          if (event.isPlaying) {
            unawaited(_logLiveKitAudioRouteAfterSpeakerReset('audio-playback'));
          }
        })
        ..on<ActiveSpeakersChangedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _liveKitSpeakingParticipantIds
              ..clear()
              ..addAll(
                event.speakers.map((participant) => participant.identity),
              );
          });
        })
        ..on<RoomReconnectingEvent>((_) {
          _liveKitReconnecting = true;
          if (mounted) setState(() {});
        })
        ..on<RoomResumingEvent>((_) {
          _liveKitReconnecting = true;
          if (mounted) setState(() {});
        })
        ..on<RoomAttemptReconnectEvent>((event) {
          _liveKitReconnecting = true;
          if (mounted) setState(() {});
          // The SDK has its own retry loop. Stop it before it can turn into
          // an unbounded app-wide reconnect storm.
          if (event.attempt >= 3 && !_liveKitReconnectStopped) {
            _liveKitReconnectStopped = true;
            unawaited(_stopLiveKitAfterReconnectLimit(room));
          }
        })
        ..on<RoomReconnectedEvent>((_) {
          _liveKitReconnecting = false;
          if (mounted) setState(() {});
          final latestRoom = _room;
          if (latestRoom != null) {
            unawaited(_syncLiveKitPublishPermission(latestRoom));
          }
        })
        ..on<RoomDisconnectedEvent>((event) {
          _liveKitReconnecting = false;
          if (mounted) setState(() {});
          if (!_leaving && !_liveKitReconnectStopped && mounted) {
            _showNotice(context, '语音连接中断', '连接已停止自动重试，请重新进入直播间。');
          }
        });
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _liveAudioBackgroundChannel.invokeMethod<void>('start');
      }
      if (!joinInfo.canPublish) {
        await _startListenerAudioWarmup();
      } else {
        await _stopListenerAudioWarmup();
      }
      _liveKitCanPublish = joinInfo.canPublish;
      // The role in the newly issued token is authoritative. Using the
      // previous room snapshot here makes every later snapshot look like a
      // role change and can trigger an endless reconnect loop.
      _liveKitRole = joinInfo.role;
      var microphoneReady = false;
      if (joinInfo.canPublish) {
        final roomRole = _room?.viewerRole;
        final approvedSpeaker =
            joinInfo.role == 'speaker' && roomRole != 'speaker';
        if (approvedSpeaker && _localMuteOverride == null) {
          if (mounted) {
            setState(() => _muted = false);
          } else {
            _muted = false;
          }
        }
        microphoneReady = await _setLocalMicrophoneEnabledWithRecovery(!_muted);
        if (!microphoneReady && !_muted) {
          throw StateError('LiveKit did not create a local audio track');
        }
      }
      // A server role alone only means permission was granted. Do not let the
      // UI present this participant as connected until this client has both
      // joined LiveKit and successfully initialized its local audio track.
      _liveKitPublishReady = joinInfo.canPublish && (_muted || microphoneReady);
      debugPrint(
        'LiveKit audio engine after local publish: '
        '${AudioManager.instance.audioEngineState}',
      );
      await _setSpeakerOutputPreferred();
      // Approval can arrive while the old listener token is reconnecting. In
      // that race Room.connect succeeds, but the token is still receive-only;
      // recheck the latest snapshot after the connection lock is released so
      // we do not miss the speaker-token refresh.
      if (!joinInfo.canPublish) {
        final latestRoom = _room;
        if (latestRoom != null && _canPublishAudio(latestRoom)) {
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 300), () {
              if (mounted) unawaited(_syncLiveKitPublishPermission(latestRoom));
            }),
          );
        }
      }
    } catch (error, stackTrace) {
      // Keep the original connect/join failure visible. A disconnect can also
      // time out while unwinding a failed connection, and must not replace the
      // error that explains why Room.connect failed.
      debugPrint('LiveKit connect failed: $error');
      debugPrint('LiveKit URL: ${liveKitUrl ?? '<not received>'}');
      debugPrintStack(stackTrace: stackTrace);
      final room = connectingRoom;
      if (room != null) {
        if (identical(room, _liveKitRoom)) {
          _liveKitRoom = null;
        }
        _liveKitPublishReady = false;
        _liveKitEventListener?.dispose();
        _liveKitEventListener = null;
        _liveKitSpeakingParticipantIds.clear();
        unawaited(_disconnectLiveKitRoomSafely(room));
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        unawaited(_liveAudioBackgroundChannel.invokeMethod<void>('stop'));
      }
      if (mounted && showError) {
        _showNotice(context, '语音连接失败', '无法连接直播语音，请稍后重试。');
      }
    } finally {
      _liveKitConnecting = false;
      if (mounted) setState(() {});
    }
  }

  Room _createLiveKitRoom() {
    return Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: _voiceRoomAudioCaptureOptions,
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: true),
      ),
    );
  }

  Future<void> _disconnectLiveKitRoomSafely(Room? room) async {
    if (room == null) return;
    try {
      await room.disconnect().timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      debugPrint('LiveKit disconnect cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _stopLiveKitAfterReconnectLimit(Room room) async {
    if (!identical(room, _liveKitRoom)) return;
    await room.disconnect();
    if (identical(room, _liveKitRoom)) {
      _liveKitRoom = null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _liveAudioBackgroundChannel.invokeMethod<void>('stop');
    }
    if (mounted && !_leaving) {
      _showNotice(context, '语音连接中断', '网络不稳定，已停止自动重试，请重新进入直播间。');
    }
  }

  Future<void> _waitForLiveKitReentryCooldown(int liveID) async {
    final leftAt = _liveKitLeftAtByLiveID[liveID];
    if (leftAt == null) return;

    final remaining =
        _liveKitReentryCooldown - DateTime.now().difference(leftAt);
    if (remaining <= Duration.zero) {
      _liveKitLeftAtByLiveID.remove(liveID);
      return;
    }

    if (mounted) {
      setState(() {
        _reentryCoolingDown = true;
        _reentryCooldownSeconds = remaining.inSeconds.ceil();
      });
    }
    while (mounted) {
      final currentRemaining =
          _liveKitReentryCooldown - DateTime.now().difference(leftAt);
      if (currentRemaining <= Duration.zero) break;
      await Future<void>.delayed(
        currentRemaining > const Duration(seconds: 1)
            ? const Duration(seconds: 1)
            : currentRemaining,
      );
      if (mounted) {
        final updatedRemaining =
            _liveKitReentryCooldown - DateTime.now().difference(leftAt);
        setState(
          () => _reentryCooldownSeconds = updatedRemaining.inSeconds.ceil(),
        );
      }
    }
    _liveKitLeftAtByLiveID.remove(liveID);
    if (mounted) {
      setState(() {
        _reentryCoolingDown = false;
        _reentryCooldownSeconds = 0;
      });
    }
  }

  static Future<void> _ensureLiveKitInitialized() {
    return _liveKitInitialization ??= LiveKitClient.initialize(
      initialAudioSessionOptions: _communicationAudioSession,
    );
  }

  Future<void> _configureLiveKitMicrophoneMuteMode() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await AudioManager.instance.setMicrophoneMuteMode(
      MicrophoneMuteMode.inputMixer,
    );
  }

  Future<void> _prepareLiveKitAudioSession() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _setSpeakerOutputPreferred();
      return;
    }
    await AudioManager.instance.setAudioSessionOptions(
      // Keep iOS voice-room listeners on the communication session as well.
      // In this app, playback-only sessions can report a subscribed remote
      // track and an active playout engine while producing no audible output.
      _communicationAudioSession,
    );
    await AudioManager.instance.setEngineAvailability(
      AudioEngineAvailability.defaultAvailability,
    );
    await _setSpeakerOutputPreferred();
    debugPrint(
      'LiveKit audio engine before connect: '
      '${AudioManager.instance.audioEngineState}',
    );
    unawaited(_logLiveKitAudioRoute('before-connect'));
  }

  Future<void> _loadRoom({bool silent = false}) async {
    final live = widget.live;
    if (live == null) return;
    if (!silent && mounted) setState(() => _roomLoading = true);
    try {
      final room = await _accountSession.liveRoom(
        live.id,
        joinPassword: widget.joinPassword,
      );
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

  void _ensureHostHeartbeat(LiveRoom room) {
    if (room.viewerRole != 'host') {
      _hostHeartbeatTimer?.cancel();
      _hostHeartbeatTimer = null;
      return;
    }
    if (_hostHeartbeatTimer != null) return;
    _hostHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_sendHostHeartbeat()),
    );
    unawaited(_sendHostHeartbeat());
  }

  Future<void> _sendHostHeartbeat() async {
    final live = widget.live;
    if (live == null || _leaving) return;
    try {
      await _accountSession.keepLiveAlive(live.id);
    } catch (error) {
      // Heartbeat failures are transient and must not end the live locally.
      debugPrint('Live heartbeat failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _room?.viewerRole == 'host') {
      unawaited(_sendHostHeartbeat());
    }
  }

  Future<void> _connectRealtime({bool refreshRoom = true}) async {
    final live = widget.live;
    if (live == null || !mounted || _leaving) return;
    try {
      if (refreshRoom) await _loadRoom(silent: true);
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
      _reconnectAttempt = 0;
      _realtimeReconnectStopped = false;
      if (mounted) setState(() => _networkReconnecting = false);
    } on AccountApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 409) {
        _reconnectTimer?.cancel();
        if (mounted) setState(() => _networkReconnecting = false);
        return;
      }
      _scheduleRealtimeReconnect();
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
    if (!mounted ||
        widget.live == null ||
        _leaving ||
        _realtimeReconnectStopped) {
      return;
    }
    if (_reconnectAttempt >= 5) {
      _realtimeReconnectStopped = true;
      if (mounted) {
        setState(() => _networkReconnecting = false);
        _showNotice(context, '弹幕连接中断', '已停止自动重试，请重新进入直播间。');
      }
      return;
    }
    _reconnectTimer?.cancel();
    const retryDelays = [3, 6, 12, 30, 60];
    final delaySeconds = retryDelays[_reconnectAttempt];
    _reconnectAttempt++;
    setState(() => _networkReconnecting = true);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (mounted && !_leaving) unawaited(_connectRealtime());
    });
  }

  void _handleRealtimeEvent(dynamic rawEvent) {
    if (rawEvent is! String) return;
    try {
      final decoded = jsonDecode(rawEvent);
      if (decoded is! Map<String, dynamic>) return;
      final eventType = decoded['type'];
      if (eventType is! String) return;

      if (_networkReconnecting && mounted) {
        setState(() {
          _networkReconnecting = false;
          _reconnectAttempt = 0;
        });
      }

      switch (eventType) {
        case 'room.snapshot':
          final roomJson = decoded['room'];
          if (roomJson is Map<String, dynamic>) {
            _applyRoomSnapshot(LiveRoom.fromJson(roomJson));
          }
        case 'room.audio_mute':
          final audioMutedJson = decoded['audio_muted'];
          if (audioMutedJson is Map<String, dynamic>) {
            _applyAudioMute(audioMutedJson['muted'] as bool? ?? false);
          }
        case 'room.chat_mute':
          final chatMuted = decoded['chat_muted'];
          if (chatMuted is bool) {
            _applyChatMute(chatMuted);
          }
        case 'room.participant_count':
          final participantCount = decoded['participant_count'];
          if (participantCount is num) {
            _applyParticipantCount(participantCount.toInt());
          }
      }
    } on FormatException {
      debugPrint('Ignoring malformed live realtime event');
    } catch (error) {
      debugPrint('Ignoring invalid live realtime event: $error');
    }
  }

  void _applyParticipantCount(int participantCount) {
    final room = _room;
    if (room == null || !mounted) return;
    // Presence events can arrive late or out of order during reconnects. Do
    // not let an invalid server value render a negative audience count.
    final safeParticipantCount = participantCount < 0 ? 0 : participantCount;
    setState(() {
      _room = LiveRoom(
        live: room.live,
        host: room.host,
        hostActive: room.hostActive,
        viewerUserId: room.viewerUserId,
        viewerRole: room.viewerRole,
        participantCount: safeParticipantCount,
        speakers: room.speakers,
        listeners: room.listeners,
        raisedHands: room.raisedHands,
        canRaiseHand: room.canRaiseHand,
        viewerMuted: room.viewerMuted,
        chatMuted: room.chatMuted,
        audioMuted: room.audioMuted,
        checkIn: room.checkIn,
      );
    });
  }

  void _applyAudioMute(bool muted) {
    final room = _room;
    if (room == null || !mounted) return;
    final updatedRoom = LiveRoom(
      live: room.live,
      host: room.host,
      hostActive: room.hostActive,
      viewerUserId: room.viewerUserId,
      viewerRole: room.viewerRole,
      participantCount: room.participantCount,
      speakers: room.speakers
          .map(
            (speaker) => LiveParticipant(
              userId: speaker.userId,
              nickname: speaker.nickname,
              role: speaker.role,
              handRaised: speaker.handRaised,
              muted: muted,
            ),
          )
          .toList(growable: false),
      listeners: room.listeners,
      raisedHands: room.raisedHands,
      canRaiseHand: room.canRaiseHand,
      viewerMuted: room.viewerRole == 'speaker' ? muted : room.viewerMuted,
      chatMuted: room.chatMuted,
      audioMuted: muted,
      checkIn: room.checkIn,
    );
    setState(() {
      _room = updatedRoom;
      _muted = updatedRoom.viewerMuted;
    });
    _localMuteOverride = null;
    unawaited(_syncLiveKitPublishPermission(updatedRoom));
  }

  void _applyChatMute(bool muted) {
    final room = _room;
    if (room == null || !mounted) return;
    final updatedRoom = LiveRoom(
      live: room.live,
      host: room.host,
      hostActive: room.hostActive,
      viewerUserId: room.viewerUserId,
      viewerRole: room.viewerRole,
      participantCount: room.participantCount,
      speakers: room.speakers,
      listeners: room.listeners,
      raisedHands: room.raisedHands,
      canRaiseHand: room.canRaiseHand,
      viewerMuted: room.viewerMuted,
      chatMuted: muted,
      audioMuted: room.audioMuted,
      checkIn: room.checkIn,
    );
    setState(() => _room = updatedRoom);
    unawaited(_syncLiveKitPublishPermission(updatedRoom));
  }

  void _applyRoomSnapshot(LiveRoom room) {
    if (!mounted) return;
    if (room.live.status == 'ended') {
      _closeRoom(true);
      return;
    }
    final displayedRoom = room;
    _checkInTimer?.cancel();
    if (displayedRoom.checkIn != null) {
      _checkInTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (displayedRoom.checkIn!.deadline.isBefore(DateTime.now())) {
          _checkInTimer?.cancel();
          unawaited(_loadRoom(silent: true));
          return;
        }
        setState(() {});
      });
    }
    final participants = [
      displayedRoom.host,
      ...displayedRoom.speakers,
      ...displayedRoom.listeners,
    ];
    final participantIds = participants.map(
      (participant) => participant.userId,
    );
    final firstSnapshot = _knownParticipantIds.isEmpty;
    final newParticipants = firstSnapshot
        ? participants
              .where(
                (participant) =>
                    displayedRoom.viewerRole == 'listener' &&
                    participant.userId == displayedRoom.viewerUserId,
              )
              .toList(growable: false)
        : participants
              .where(
                (participant) =>
                    !_knownParticipantIds.contains(participant.userId),
              )
              .toList(growable: false);
    _knownParticipantIds
      ..clear()
      ..addAll(participantIds);
    if (newParticipants.isNotEmpty) {
      final timestamp = DateTime.now();
      _appendMessages(
        newParticipants.indexed.map(
          (entry) => LiveMessage(
            id: -timestamp.microsecondsSinceEpoch - entry.$1,
            nickname: '',
            text: '欢迎 ${entry.$2.nickname} 进入直播间',
            createdAt: timestamp,
          ),
        ),
      );
    }
    final localMuteOverride = _localMuteOverride;
    if (localMuteOverride != null && room.viewerMuted == localMuteOverride) {
      _localMuteOverride = null;
    }
    setState(() {
      _room = displayedRoom;
      // A realtime snapshot can arrive before the mute request completes.
      // Keep the user's latest local choice until the server echoes it back.
      _muted = localMuteOverride ?? displayedRoom.viewerMuted;
      _handRaised = room.raisedHands.any(
        (participant) => participant.userId == displayedRoom.viewerUserId,
      );
      if (displayedRoom.chatMuted && displayedRoom.viewerRole != 'host') {
        _emojiPickerVisible = false;
      }
    });
    unawaited(_syncLiveKitPublishPermission(displayedRoom));
    _ensureHostHeartbeat(displayedRoom);
  }

  Future<void> _syncLiveKitPublishPermission(LiveRoom room) async {
    // A stale listener snapshot can arrive after the server has promoted this
    // participant. Do not let it disable an already-publishable connection.
    if (_liveKitCanPublish == true &&
        _liveKitRole == 'speaker' &&
        room.viewerRole == 'listener') {
      return;
    }
    final canPublish = _canPublishAudio(room);
    if (_liveKitRoom == null || _liveKitConnecting || _liveKitReconnecting) {
      return;
    }
    if (canPublish && _liveKitCanPublish != true) {
      // A listener uses the media playback session. Promotion must reconnect
      // with a publishing token after switching to the communication session,
      // which recreates iOS's audio device instead of reusing a stopped one.
      if (_liveKitPermissionReconnectInFlight) return;
      _liveKitPermissionReconnectInFlight = true;
      try {
        await _connectLiveKit(showError: false);
      } finally {
        _liveKitPermissionReconnectInFlight = false;
      }
      return;
    }
    _liveKitCanPublish = canPublish;
    _liveKitRole = room.viewerRole;
    if (!canPublish) {
      _liveKitPublishReady = false;
      await _setLocalMicrophoneEnabled(false);
      return;
    }
    if (_liveKitMicrophoneOperationInFlight) return;
    try {
      _liveKitPublishReady = await _setLocalMicrophoneEnabledWithRecovery(
        !_muted,
      );
      await _setSpeakerOutputPreferred();
      if (mounted) setState(() {});
    } catch (error) {
      _liveKitPublishReady = false;
      // This synchronization is fire-and-forget from room state updates.
      // Surface the failure in logs without producing an unhandled exception;
      // an explicit microphone tap still reports its own failure to the UI.
      debugPrint('LiveKit permission microphone sync failed: $error');
    }
  }

  bool _canPublishAudio(LiveRoom room) {
    // Mute controls the track; the role controls publish permission.
    return room.viewerRole == 'host' || room.viewerRole == 'speaker';
  }

  Future<void> _raiseHand() async {
    final live = widget.live;
    if (live == null || _handRaised || _networkReconnecting) return;
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
      // The host action sheet is popped immediately before this method is
      // started. Wait until the room route is current before popping it, so a
      // fast API response cannot pop the still-closing sheet instead.
      while (mounted && !(ModalRoute.of(context)?.isCurrent ?? true)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted) return;
      await _accountSession.endLive(live.id);
      _closeRoom(true);
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '结束失败', error.message);
    }
  }

  Future<void> _confirmEndLive() async {
    _dismissKeyboard();
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
            textStyle: TextStyle(color: widget.palette.accent),
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
    if (!mounted) return;
    _dismissKeyboard();
    if (shouldEnd == true) {
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

  Future<void> _toggleMicrophone() async {
    final live = widget.live;
    if (live == null || _microphoneUpdating) return;
    final nextMuted = !_muted;
    _microphoneUpdating = true;
    _localMuteOverride = nextMuted;
    try {
      if (nextMuted) {
        await _setLocalMicrophoneEnabledWithRecovery(false);
        await _accountSession.setLiveParticipantMute(live.id, true);
      } else {
        await _accountSession.setLiveParticipantMute(live.id, false);
        await _setLocalMicrophoneEnabledWithRecovery(true);
      }
      if (mounted) setState(() => _muted = nextMuted);
      final room = _room;
      if (!nextMuted && room != null) {
        // Synchronize the UI snapshot with the local microphone state.
        unawaited(_syncLiveKitPublishPermission(room));
      }
    } on AccountApiException catch (error) {
      _localMuteOverride = null;
      await _restoreMicrophone(!nextMuted);
      if (!mounted) return;
      _showNotice(context, '设置麦克风失败', error.message);
    } catch (_) {
      _localMuteOverride = null;
      await _restoreMicrophone(!nextMuted);
      if (!mounted) return;
      _showNotice(context, '设置麦克风失败', '请检查网络后重试。');
    } finally {
      _microphoneUpdating = false;
    }
  }

  Future<void> _restoreMicrophone(bool muted) async {
    if (!mounted) return;
    setState(() => _muted = muted);
    await _setLocalMicrophoneEnabledWithRecovery(!muted);
  }

  Future<bool> _setLocalMicrophoneEnabledWithRecovery(bool enabled) async {
    if (_liveKitMicrophoneOperationInFlight) return false;
    _liveKitMicrophoneOperationInFlight = true;
    try {
      return await _setLocalMicrophoneEnabled(enabled);
    } catch (error) {
      debugPrint('LiveKit microphone toggle failed, retrying: $error');
      if (defaultTargetPlatform == TargetPlatform.iOS && enabled) {
        // A receive-only listener may still own mediaPlayback when permission
        // changes to speaker. Reconfigure the capture session before retrying;
        // otherwise WebRTC returns -9001 while applying the recorder settings.
        await AudioManager.instance.setAudioSessionOptions(
          _communicationAudioSession,
        );
        await AudioManager.instance.setEngineAvailability(
          AudioEngineAvailability.defaultAvailability,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return await _setLocalMicrophoneEnabled(enabled);
    } finally {
      _liveKitMicrophoneOperationInFlight = false;
    }
  }

  Future<bool> _setLocalMicrophoneEnabled(bool enabled) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (enabled) {
        // The communication session is configured once before Room.connect.
        // Reapplying it on every mute toggle can reset iOS's AudioUnit.
        await AudioManager.instance.setEngineAvailability(
          AudioEngineAvailability.defaultAvailability,
        );
      }
      await _setSpeakerOutputPreferred();
      if (enabled) {
        // WebRTC may reset the iOS route while the audio device starts.
        unawaited(
          Future<void>.delayed(_iosAudioUnitRecoveryDelay, () async {
            if (!mounted) return;
            await _setSpeakerOutputPreferred();
            debugPrint(
              'LiveKit iOS speaker route reapplied: '
              'preferred=${AudioManager.instance.isSpeakerOutputPreferred} '
              'forced=${AudioManager.instance.isSpeakerOutputForced} '
              'engine=${AudioManager.instance.audioEngineState}',
            );
            await _logLiveKitAudioRoute('after-microphone-enable-route-reset');
          }),
        );
      }
    }
    final participant = _liveKitRoom?.localParticipant;
    if (participant == null) return false;
    // Keep iOS WebRTC's AudioUnit alive across mute/unmute. LiveKit's
    // maintainers document that restarting the AudioUnit on the second
    // setMicrophoneEnabled(true) can briefly publish packets with zero audio.
    final publication = await participant.setMicrophoneEnabled(
      enabled,
      audioCaptureOptions: _voiceRoomAudioCaptureOptions,
    );
    final track = publication?.track;
    final effectiveRole = _liveKitRole ?? _room?.viewerRole ?? '<unknown>';
    debugPrint(
      'LiveKit local microphone ${enabled ? 'enabled' : 'disabled'}: '
      'role=$effectiveRole canPublish=$_liveKitCanPublish '
      'publication=${publication?.sid ?? '<none>'} '
      'muted=${publication?.muted} active=${track?.isActive} '
      'processing=ec:${_voiceRoomAudioCaptureOptions.echoCancellation},'
      'ns:${_voiceRoomAudioCaptureOptions.noiseSuppression},'
      'agc:${_voiceRoomAudioCaptureOptions.autoGainControl},'
      'isolation:${_voiceRoomAudioCaptureOptions.voiceIsolation} '
      'engine=${AudioManager.instance.audioEngineState}',
    );
    unawaited(
      _logLiveKitAudioRoute('microphone-${enabled ? 'enabled' : 'disabled'}'),
    );
    if (enabled && track is LocalAudioTrack) {
      debugPrint(
        'LiveKit audio engine after microphone enable: '
        '${AudioManager.instance.audioEngineState}',
      );
      final stats = await track.getSenderStats();
      debugPrint(
        'LiveKit local audio uplink: role=$effectiveRole '
        'bytes=${stats?.bytesSent} packets=${stats?.packetsSent} '
        'audioLevel=${stats?.audioSourceStats?.audioLevel} '
        'totalEnergy=${stats?.audioSourceStats?.totalAudioEnergy} '
        'trackActive=${track.isActive} publicationMuted=${publication?.muted}',
      );
      // The sender is attached asynchronously during SDP negotiation. A
      // first stats read can therefore be empty even though publication
      // succeeded; sample again after the native sender has had time to bind.
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (!mounted || !identical(track, publication?.track)) return;
          final delayedStats = await track.getSenderStats();
          debugPrint(
            'LiveKit local audio uplink delayed: role=$effectiveRole '
            'bytes=${delayedStats?.bytesSent} '
            'packets=${delayedStats?.packetsSent} '
            'audioLevel=${delayedStats?.audioSourceStats?.audioLevel} '
            'totalEnergy=${delayedStats?.audioSourceStats?.totalAudioEnergy} '
            'trackActive=${track.isActive} '
            'publicationMuted=${publication?.muted} '
            'engine=${AudioManager.instance.audioEngineState}',
          );
        }),
      );
    }
    return !enabled || track is LocalAudioTrack;
  }

  Future<void> _setSpeakerOutputPreferred() =>
      AudioManager.instance.setSpeakerOutputPreferred(true, force: true);

  Future<void> _startListenerAudioWarmup() async {
    if (defaultTargetPlatform != TargetPlatform.iOS ||
        _listenerAudioWarmupTrack != null) {
      return;
    }
    try {
      final track = await LocalAudioTrack.create(_voiceRoomAudioCaptureOptions);
      await track.start();
      _listenerAudioWarmupTrack = track;
      debugPrint(
        'LiveKit iOS listener audio warmup started: '
        'trackActive=${track.isActive} '
        'engine=${AudioManager.instance.audioEngineState}',
      );
    } catch (error) {
      debugPrint('LiveKit iOS listener audio warmup failed: $error');
    }
  }

  Future<void> _stopListenerAudioWarmup() async {
    final track = _listenerAudioWarmupTrack;
    _listenerAudioWarmupTrack = null;
    if (track == null) return;
    try {
      await track.stop();
      track.dispose();
      debugPrint('LiveKit iOS listener audio warmup stopped');
    } catch (error) {
      debugPrint('LiveKit iOS listener audio warmup cleanup failed: $error');
    }
  }

  Future<void> _logRemoteAudioTrackStats(
    RemoteAudioTrack track,
    String publicationSid,
    bool publicationMuted,
  ) async {
    Future<void> log(String sample) async {
      final stats = await track.getReceiverStats();
      debugPrint(
        'LiveKit remote audio downlink $sample: '
        'publication=$publicationSid '
        'trackActive=${track.isActive} '
        'publicationMuted=$publicationMuted '
        'packets=${stats?.packetsReceived} '
        'bytes=${stats?.bytesReceived} '
        'audioLevel=${stats?.audioSourceStats?.audioLevel} '
        'totalEnergy=${stats?.totalAudioEnergy}',
      );
      final receiver = track.receiver;
      if (receiver == null) return;
      final rawReports = await receiver.getStats();
      for (final report in rawReports.where(
        (report) => report.type == 'inbound-rtp' || report.type == 'track',
      )) {
        final values = report.values;
        debugPrint(
          'LiveKit remote audio raw stats $sample: '
          'publication=$publicationSid type=${report.type} '
          'enabled=${track.mediaStreamTrack.enabled} '
          'packetsReceived=${values['packetsReceived']} '
          'bytesReceived=${values['bytesReceived']} '
          'audioLevel=${values['audioLevel']} '
          'totalAudioEnergy=${values['totalAudioEnergy']} '
          'totalSamplesDuration=${values['totalSamplesDuration']}',
        );
      }
    }

    try {
      await log('immediate');
      await Future<void>.delayed(const Duration(seconds: 2));
      await log('delayed');
    } catch (error) {
      debugPrint(
        'LiveKit remote audio downlink stats failed: '
        'publication=$publicationSid error=$error',
      );
    }
  }

  Future<void> _logLiveKitAudioRoute(String reason) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final route = await _liveAudioRouteChannel.invokeMethod<Object?>(
        'routeInfo',
      );
      debugPrint('LiveKit iOS audio route: reason=$reason route=$route');
    } catch (error) {
      debugPrint(
        'LiveKit iOS audio route read failed: reason=$reason error=$error',
      );
    }
  }

  Future<void> _logLiveKitAudioRouteAfterSpeakerReset(String reason) async {
    await _setSpeakerOutputPreferred();
    await _logLiveKitAudioRoute(reason);
    debugPrint(
      'LiveKit audio engine after $reason: '
      '${AudioManager.instance.audioEngineState}',
    );
  }

  Future<void> _confirmSpeakerMute(LiveParticipant speaker) async {
    final shouldMute = !speaker.muted;
    final actionLabel = shouldMute ? '静音' : '解除静音';
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('$actionLabel ${speaker.nickname}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('是否要$actionLabel该用户？'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            textStyle: TextStyle(color: widget.palette.accent),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: shouldMute,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.setLiveSpeakerMute(
        live.id,
        speaker.userId,
        shouldMute,
      );
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '设置麦克风失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '设置麦克风失败', '请检查网络后重试。');
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

  void _showCheckInDurations() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text(
          '发起签到',
          style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
        ),
        message: const Text(
          '请选择签到时长，成员将在房间内看到签到提醒。',
          style: TextStyle(fontSize: AcoTypography.bodySmall),
        ),
        actions: [5, 10, 15, 30]
            .map(
              (minutes) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_startCheckIn(minutes * 60));
                },
                child: Text(
                  '$minutes 分钟',
                  style: const TextStyle(fontSize: AcoTypography.bodyEmphasis),
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text(
            '取消',
            style: TextStyle(fontSize: AcoTypography.bodyEmphasis),
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckIn(int durationSeconds) async {
    final live = widget.live;
    if (live == null) return;
    try {
      await _accountSession.startLiveCheckIn(live.id, durationSeconds);
      if (mounted) {
        showAcoAlertNotice(context, '签到已发起', '成员可在倒计时结束前完成签到。');
      }
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '发起失败', error.message);
    }
  }

  Future<void> _confirmCheckIn() async {
    final live = widget.live;
    if (live == null || _checkingIn || _room?.checkIn?.viewerChecked == true) {
      return;
    }
    if (mounted) setState(() => _checkingIn = true);
    try {
      await _accountSession.confirmLiveCheckIn(live.id);
      await _loadRoom(silent: true);
      if (mounted) _showNotice(context, '签到成功', '已完成本次直播签到。');
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '签到失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '签到失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _checkingIn = false);
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
              onRejectAll: () {
                Navigator.of(dialogContext).pop();
                unawaited(_rejectAllSpeakerRequests(room.raisedHands));
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
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: widget.palette.dark ? Brightness.dark : Brightness.light,
          primaryColor: widget.palette.accent,
        ),
        child: CupertinoActionSheet(
          actions: [
            if (room?.checkIn == null)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _showCheckInDurations();
                },
                child: _hostActionLabel('发起签到'),
              ),
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
                unawaited(_confirmEndLive());
              },
              child: _hostActionLabel('结束直播'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: _hostActionLabel('取消'),
          ),
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
    await _disconnectLiveKitForLeave();
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

  Future<void> _disconnectLiveKitForLeave() async {
    final liveID = widget.live?.id;
    if (liveID != null) {
      _liveKitLeftAtByLiveID[liveID] = DateTime.now();
    }
    final room = _liveKitRoom;
    _liveKitRoom = null;
    _liveKitEventListener?.dispose();
    _liveKitEventListener = null;
    await _stopListenerAudioWarmup();
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_liveAudioBackgroundChannel.invokeMethod<void>('stop'));
    }
    if (room == null) return;
    try {
      // Tell LiveKit immediately that this participant has left before the UI
      // permits another room join. Do not hold navigation indefinitely if the
      // network is already unavailable.
      await room.disconnect().timeout(const Duration(seconds: 2));
    } catch (_) {
      // A lost network cannot send Leave; the server's disconnect timeout
      // remains the fallback cleanup path.
    }
  }

  void _closeRoom([bool? result]) {
    if (!mounted || _closingRoom) return;
    _closingRoom = true;
    unawaited(_disconnectLiveKitForLeave());
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

  Future<void> _rejectSpeakerRequest(int userId) async {
    await _updateSpeaker(
      userId: userId,
      action: _accountSession.removeLiveSpeaker,
      failureTitle: '拒绝失败',
    );
  }

  Future<void> _rejectAllSpeakerRequests(List<LiveParticipant> users) async {
    for (final user in users) {
      await _rejectSpeakerRequest(user.userId);
    }
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
    _checkInTimer?.cancel();
    _hostHeartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _messageRefreshTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_eventChannel?.sink.close());
    unawaited(_disconnectLiveKitForLeave());
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(AudioManager.instance.deactivateAudioSession());
    }
    _apiClient.close();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() =>
      setState(() => _emojiPickerVisible = !_emojiPickerVisible);

  void _handleLiveKitData(DataReceivedEvent event) {
    if (event.topic != 'chat' || _room?.chatMuted == true) return;
    try {
      final payload = jsonDecode(utf8.decode(event.data));
      if (payload is! Map<String, dynamic>) return;
      final text = payload['text'];
      if (text is! String || text.trim().isEmpty || text.length > 300) return;
      final nickname = event.participant?.name.trim();
      _appendChatMessage(
        nickname: nickname == null || nickname.isEmpty ? '成员' : nickname,
        text: text,
      );
    } catch (_) {
      // Ignore malformed or non-chat data packets from other clients.
    }
  }

  Future<void> _sendMessage() async {
    final live = widget.live;
    final text = _messageController.text.trim();
    final isViewerChatMuted =
        _room?.chatMuted == true && _room?.viewerRole != 'host';
    if (live == null ||
        text.isEmpty ||
        _sending ||
        _networkReconnecting ||
        isViewerChatMuted) {
      return;
    }
    final payload = utf8.encode(jsonEncode({'text': text}));
    if (!_checkMessageSendLimits(payload.length)) return;
    setState(() => _sending = true);
    try {
      final room = _liveKitRoom;
      if (room == null) {
        throw StateError('LiveKit room is not connected');
      }
      await room.localParticipant?.publishData(
        payload,
        reliable: false,
        topic: 'chat',
      );
      _appendChatMessage(nickname: _localChatNickname, text: text);
      if (!mounted) return;
      setState(() {
        _messageController.clear();
        // Sending is an explicit request to return to the active conversation,
        // even when the viewer was reading older messages.
        _scrollToLatestSignal++;
      });
    } on AccountApiException catch (error) {
      if (mounted) _showNotice(context, '发送失败', error.message);
    } catch (_) {
      if (mounted) _showNotice(context, '发送失败', '请检查网络后重试。');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _checkMessageSendLimits(int payloadBytes) {
    if (payloadBytes > _maxLiveMessageBytes) {
      _showNotice(context, '发送失败', '弹幕内容过长，请控制在 512 字节以内。');
      return false;
    }

    final now = DateTime.now();
    final lastSentAt = _lastMessageSentAt;
    if (lastSentAt != null &&
        now.difference(lastSentAt) < _minLiveMessageInterval) {
      _showNotice(context, '发送太快', '请稍后再发送。');
      return false;
    }

    final windowStartedAt = _messageRateWindowStartedAt;
    if (windowStartedAt == null ||
        now.difference(windowStartedAt) >= _liveMessageRateWindow) {
      _messageRateWindowStartedAt = now;
      _messageRateWindowCount = 0;
    }
    if (_messageRateWindowCount >= _maxLiveMessagesPerWindow) {
      _showNotice(context, '发送太快', '房间弹幕较多，请稍后再试。');
      return false;
    }

    _lastMessageSentAt = now;
    _messageRateWindowCount++;
    return true;
  }

  String get _localChatNickname {
    final room = _room;
    if (room != null && room.host.userId == room.viewerUserId) {
      return room.host.nickname;
    }
    return '我';
  }

  void _appendChatMessage({required String nickname, required String text}) {
    final now = DateTime.now();
    _appendMessages([
      LiveMessage(
        id: -now.microsecondsSinceEpoch,
        nickname: nickname,
        text: text.trim(),
        createdAt: now,
      ),
    ]);
  }

  void _appendMessages(Iterable<LiveMessage> incomingMessages) {
    var hasNewMessages = false;
    for (final message in incomingMessages) {
      if (!_knownMessageIds.add(message.id)) continue;
      _messages.addLast(message);
      hasNewMessages = true;

      while (_messages.length > _maxLiveMessageCount) {
        final evictedMessage = _messages.removeFirst();
        _knownMessageIds.remove(evictedMessage.id);
      }
    }
    if (!hasNewMessages || !mounted) return;
    _scheduleMessageRefresh();
  }

  void _scheduleMessageRefresh() {
    if (_messageRefreshTimer != null) return;

    // Coalesce bursts of incoming chat messages into one rebuild. The queue is
    // updated immediately, while the UI is refreshed at most once per window.
    _messageRefreshTimer = Timer(_liveMessageRefreshInterval, () {
      _messageRefreshTimer = null;
      if (mounted) setState(() {});
    });
  }

  Widget? _buildRoomOverview({
    required AcoPalette palette,
    required LiveRoom? room,
    required bool isHost,
  }) {
    if (_emojiPickerVisible) return null;
    if (room != null) {
      return _LiveRoomOverview(
        palette: palette,
        room: room,
        isHost: isHost,
        // The initial room snapshot and the local LiveKit state can arrive in
        // either order. Treat either source reporting mute as authoritative so
        // a muted host avatar never falls back to the grey "not speaking"
        // treatment during entry or immediately after toggling.
        hostMuted: isHost ? (_muted || room.host.muted) : room.host.muted,
        checkingIn: _checkingIn,
        speakingParticipantIds: _liveKitSpeakingParticipantIds,
        onCheckIn: _confirmCheckIn,
        onShowRaisedHandRequests: _showRaisedHandRequests,
        onSpeakerTap: isHost ? _confirmSpeakerMute : null,
      );
    }
    if (_roomLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: CupertinoActivityIndicator(),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final live = widget.live;
    final room = _room;
    final serverViewerRole = room?.viewerRole;
    final isHost = serverViewerRole == 'host';
    // The room snapshot is only an authorization update. A listener becomes
    // a connected speaker in the UI only after the fresh LiveKit token has
    // connected and its local track has been initialized successfully.
    final audioMuted = !isHost && (room?.audioMuted ?? false);
    final canSpeak =
        live == null ||
        (_liveKitPublishReady && (isHost || serverViewerRole == 'speaker'));
    final canToggleMicrophone = canSpeak && !audioMuted;
    // A self-muted speaker becomes a listener and must raise their hand again.
    final chatMuted = room?.chatMuted == true && !isHost;
    // Do NOT add MediaQuery.viewInsetsOf: with adjustResize the window (and
    // this route) already sits above the keyboard, and CupertinoPageScaffold
    // zeroes viewInsets for the child. Adding the inset again would double
    // the keyboard height and leave a gap between the danmaku and the bar.
    final bottomOverlayInset =
        _roomBottomBarHeight +
        (_emojiPickerVisible ? _roomEmojiPickerHeight : 0);
    final roomOverview = _buildRoomOverview(
      palette: palette,
      room: room,
      isHost: isHost,
    );

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: _DetailScaffold(
        palette: palette,
        title: live?.title.trim().isNotEmpty == true ? live!.title : '语音房',
        titleFollowsBack: true,
        headerTopPadding: 0,
        headerRightPadding: 0,
        onBack: () => unawaited(_handleBack()),
        right: _LiveRoomHeaderActions(
          palette: palette,
          count: room?.participantCount,
          onMore: isHost ? _showHostActions : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomOverlayInset),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final overviewMaxHeight = math.max(
                      0.0,
                      constraints.maxHeight - 14,
                    );
                    return Column(
                      children: [
                        if (roomOverview != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: overviewMaxHeight,
                            ),
                            child: SingleChildScrollView(
                              primary: false,
                              child: roomOverview,
                            ),
                          ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _RoomChatHistory(
                            palette: palette,
                            liveMessages: _messages.toList(growable: false),
                            hasLive: live != null,
                            scrollToLatestSignal: _scrollToLatestSignal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_handRaiseNoticeVisible)
              const Center(child: _LiveRoomInfoNotice()),
            if (_liveKitConnecting || _liveKitReconnecting)
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CupertinoActivityIndicator(radius: 8),
                          const SizedBox(width: 8),
                          Text(
                            _liveKitConnecting ? '正在连接语音…' : '语音重连中…',
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 18,
              child: _LiveRoomNetworkStatusChip(
                palette: palette,
                reconnecting: _networkReconnecting,
              ),
            ),
            if (_networkReconnecting) const _LiveRoomNetworkNotice(),
            Positioned(
              left: 0,
              right: 0,
              bottom: _emojiPickerVisible ? _roomEmojiPickerHeight : 0,
              child: _RoomBottomBar(
                palette: palette,
                muted: _muted,
                canSpeak: canSpeak,
                audioMuted: audioMuted,
                showHandControl: !isHost,
                handRaised: _handRaised,
                chatMuted: chatMuted,
                onMic: canToggleMicrophone ? _toggleMicrophone : null,
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
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _reentryCoolingDown
                    ? ColoredBox(
                        key: const ValueKey('live-room-reentry-cooldown'),
                        color: Color(0xE6000000),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CupertinoActivityIndicator(radius: 14),
                              const SizedBox(height: 14),
                              Text(
                                '正在准备重新进入直播间',
                                style: TextStyle(
                                  color: _white,
                                  fontSize: AcoTypography.bodyEmphasis,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '请稍候 $_reentryCooldownSeconds 秒',
                                style: TextStyle(
                                  color: _white.withValues(alpha: .72),
                                  fontSize: AcoTypography.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
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
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
    children: [
      AcoPageHeader(
        palette: palette,
        onBack: onBack,
        backButtonOffset: const Offset(-16, 0),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: '编辑个人资料',
            child: GestureDetector(
              onTap: () => onOpen(AcoScreen.profileEdit),
              child: const AcoAvatar(size: 68),
            ),
          ),
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
                    fontSize: AcoTypography.titleLarge,
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
                    fontSize: AcoTypography.bodySmall,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'UID:${displayAccountId(accountId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.mutedText, fontSize: 10),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: _ProfileHeaderButton(
              iconAsset: 'assets/icons/profile_scan.png',
              palette: palette,
              label: '扫描二维码',
              onPressed: () => onOpen(AcoScreen.scan),
            ),
          ),
          const SizedBox(width: 2),
          Transform.translate(
            offset: const Offset(-12, -6),
            child: _ProfileHeaderButton(
              iconAsset: 'assets/icons/profile_qr_code.png',
              palette: palette,
              label: '个人二维码',
              filled: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 42),
      _ProfileSection(
        palette: palette,
        title: '设置',
        actions: [
          _ProfileAction(
            palette: palette,
            iconAsset: 'assets/icons/profile/theme.svg',
            label: '主题模式',
            onPressed: () => onOpen(AcoScreen.profileTheme),
          ),
          _ProfileAction(
            palette: palette,
            iconAsset: 'assets/icons/profile/language.svg',
            label: '语言',
            onPressed: () => onOpen(AcoScreen.profileLanguage),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Center(
        child: Text(
          '当前版本 v${AppConfig.appVersion}',
          style: TextStyle(
            color: palette.mutedText,
            fontSize: AcoTypography.caption,
          ),
        ),
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
        AcoPageHeader(
          palette: palette,
          title: '我的二维码',
          onBack: onBack,
          backButtonOffset: const Offset(-20, 0),
        ),
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
      if (mounted) _showNotice(context, '保存失败', error.localizedMessage);
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
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => _dismissKeyboard(),
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _dismissKeyboard(),
                onTapOutside: (_) => _dismissKeyboard(),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              palette.dark
                  ? 'assets/icons/live_brand_dark.png'
                  : 'assets/icons/live_brand_light.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 3,
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
                          if (session.canExportCheckIns) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '我的直播',
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: AcoTypography.caption,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (scheduledStartLabel != null) ...[
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                scheduledStartLabel,
                                maxLines: 2,
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
              height: 160,
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
