// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_session.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/features/legal/presentation/legal_document_page.dart';
import 'package:aco_chat/features/live/domain/live_chat_state.dart';
import 'package:aco_chat/features/live/domain/live_realtime_event.dart';
import 'package:aco_chat/features/live/domain/live_realtime_client.dart';
import 'package:aco_chat/shared/widgets/aco_page_header.dart';
import 'package:aco_chat/services/biometric_authentication.dart';
import 'package:aco_chat/services/sensitive_screen_protection.dart';
import 'package:aco_chat/services/wallet_security.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:aco_chat/services/wallet_valuation_service.dart';
import 'package:aco_chat/services/wallet_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:emoji_picker_flutter/locales/default_emoji_set_locale.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'aco_design_models.dart';
part 'live_room_widgets.dart';
part 'live_room_chat_widgets.dart';
part 'live_room_page.dart';
part 'live_room_livekit.dart';
part 'live_room_ui.dart';
part 'profile_pages.dart';
part 'square_content_widgets.dart';
part 'mining_page.dart';
part 'profile_settings_pages.dart';
part 'wallet_common_widgets.dart';
part 'explore_pages.dart';
part 'wallet_welcome_page.dart';
part 'wallet_setup_flow.dart';
part 'wallet_home_page.dart';
part 'wallet_send_page.dart';
part 'wallet_chains_page.dart';
part 'wallet_transfer_widgets.dart';
part 'wallet_detail_widgets.dart';
part 'wallet_detail_page.dart';
part 'wallet_chain_widgets.dart';
part 'wallet_backup_pages.dart';
part 'wallet_receive_pages.dart';
part 'dex_pages.dart';
part 'create_live_page.dart';
part 'design_shell_widgets.dart';

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
  final ValueNotifier<String> _avatarUrl = ValueNotifier<String>('');
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
    _avatarUrl.value = profile.avatarUrl;
  }

  @override
  void didUpdateWidget(covariant AcoDesignShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldProfile = oldWidget.accountProfile;
    final profile = widget.accountProfile;
    if (profile != null &&
        (oldProfile?.accountId != profile.accountId ||
            oldProfile?.nickname != profile.nickname ||
            oldProfile?.username != profile.username ||
            oldProfile?.avatarUrl != profile.avatarUrl)) {
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
    _avatarUrl.dispose();
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
      _avatarUrl,
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
      avatarUrl: _avatarUrl.value,
      displayName: _displayName.value,
      onDisplayNameChanged: (name) => _displayName.value = name,
      onUsernameChanged: (username) => _username.value = username,
      onAvatarUrlChanged: (avatarUrl) => _avatarUrl.value = avatarUrl,
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
                      _avatarUrl,
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
                      avatarUrl: _avatarUrl.value,
                      displayName: _displayName.value,
                      onDisplayNameChanged: (name) => _displayName.value = name,
                      onUsernameChanged: (username) =>
                          _username.value = username,
                      onAvatarUrlChanged: (avatarUrl) =>
                          _avatarUrl.value = avatarUrl,
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
