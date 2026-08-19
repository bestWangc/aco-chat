import 'dart:async';
import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_session.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDark = await ThemePreferences.load();
  await WalletPreferences.removeLegacyPlaceholderData();
  final identity = await WalletPreferences.walletIdentity();
  final walletConfigured = await WalletPreferences.load() && identity != null;
  final accountProfileFuture = walletConfigured
      ? WalletAccountAuthentication.signInSilently(identity.address)
      : null;
  runApp(
    AcoApp(
      initialIsDark: isDark,
      onThemeChanged: ThemePreferences.save,
      initialWalletConfigured: walletConfigured,
      initialWalletIdentity: identity,
      onWalletConfigured: WalletPreferences.save,
      accountProfileFuture: accountProfileFuture,
    ),
  );
}

class ThemePreferences {
  const ThemePreferences._();

  static const themeKey = 'theme.isDark';

  static Future<bool> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(themeKey) ?? true;
  }

  static Future<void> save(bool isDark) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(themeKey, isDark);
  }
}

class WalletAccountAuthentication {
  const WalletAccountAuthentication._();

  /// Restores the server account for [walletAddress] without showing a login UI.
  /// A network failure leaves the local wallet usable and is retried next launch.
  static Future<AccountProfile?> signInSilently(String walletAddress) async {
    final client = AccountApiClient();
    try {
      final session = AccountSession(client);
      return (await session.signInSilently(walletAddress)).user;
    } catch (_) {
      // A later launch will retry without preventing local wallet access.
      return null;
    } finally {
      client.close();
    }
  }
}

class AcoApp extends StatefulWidget {
  const AcoApp({
    this.initialIsDark = true,
    this.onThemeChanged,
    this.initialWalletConfigured = true,
    this.initialWalletIdentity,
    this.onWalletConfigured,
    this.accountProfileFuture,
    super.key,
  });

  final bool initialIsDark;
  final ValueChanged<bool>? onThemeChanged;
  final bool initialWalletConfigured;
  final WalletIdentity? initialWalletIdentity;
  final ValueChanged<bool>? onWalletConfigured;
  final Future<AccountProfile?>? accountProfileFuture;

  @override
  State<AcoApp> createState() => _AcoAppState();
}

class _AcoAppState extends State<AcoApp> {
  late final ValueNotifier<bool> _isDark = ValueNotifier<bool>(
    widget.initialIsDark,
  );
  late bool _walletConfigured = widget.initialWalletConfigured;
  late WalletIdentity? _walletIdentity = widget.initialWalletIdentity;
  AccountProfile? _accountProfile;
  Future<AccountProfile?>? _walletLoginFuture;

  @override
  void initState() {
    super.initState();
    _accountProfile = null;
    final profileFuture = widget.accountProfileFuture;
    _walletLoginFuture = profileFuture;
    if (profileFuture != null) {
      unawaited(_resolveAccountProfile(profileFuture));
    }
  }

  Future<void> _resolveAccountProfile(
    Future<AccountProfile?> profileFuture,
  ) async {
    final profile = await profileFuture;
    if (profile != null && mounted) {
      setState(() => _accountProfile = profile);
    }
  }

  void _onThemeChanged(bool isDark) {
    widget.onThemeChanged?.call(isDark);
  }

  Future<void> _completeWalletSetup(
    WalletIdentity identity,
    String mnemonic,
  ) async {
    await WalletPreferences.saveWalletIdentity(identity);
    AccountProfile? profile;
    try {
      profile = await _syncWalletAccount(
        identity,
        mnemonic,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      // Local wallet creation is independent from account synchronization.
      // Keep the wallet usable when the API is unavailable; silent login can
      // retry after the app has entered the wallet home.
    }
    final loginFuture = Future<AccountProfile?>.value(profile);
    setState(() {
      _walletConfigured = true;
      _walletIdentity = identity;
      _walletLoginFuture = loginFuture;
      _accountProfile = profile;
    });
    widget.onWalletConfigured?.call(true);
  }

  Future<AccountProfile> _syncWalletAccount(
    WalletIdentity identity,
    String mnemonic,
  ) async {
    final client = AccountApiClient();
    try {
      final session = AccountSession(client);
      // An added wallet must join the account that is already active on this
      // device. Logging it in as a new wallet here would create a separate
      // account, making the account impossible to recover from that wallet.
      final activeProfile = await session.activeProfile();
      if (activeProfile != null) {
        await session
            .addWallet(identity.address)
            .timeout(const Duration(seconds: 15));
        return activeProfile;
      } else {
        return (await session
                .signInForWallet(
                  walletAddress: identity.address,
                  mnemonic: mnemonic,
                )
                .timeout(const Duration(seconds: 15)))
            .user;
      }
    } finally {
      client.close();
    }
  }

  Future<void> _selectWallet(WalletIdentity identity) async {
    await WalletPreferences.saveWalletIdentity(identity);
    if (mounted) setState(() => _walletIdentity = identity);
  }

  @override
  void dispose() {
    _isDark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _isDark,
    builder: (_, isDark, _) {
      const accent = Color(0xFFA6FF00);
      return shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: isDark ? Brightness.dark : Brightness.light,
          colorScheme: isDark
              ? shad.ShadSlateColorScheme.dark()
              : shad.ShadSlateColorScheme.light(),
        ),
        appBuilder: (_) => CupertinoApp(
          title: 'Aco',
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: CupertinoThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primaryColor: accent,
            scaffoldBackgroundColor: isDark
                ? const Color(0xFF050505)
                : const Color(0xFFFFFFFF),
            textTheme: const CupertinoTextThemeData(
              textStyle: TextStyle(
                fontFamily: 'HarmonyOS Sans SC',
                fontSize: AcoTypography.body,
              ),
            ),
          ),
          home: _walletConfigured
              ? AcoDesignShell(
                  themeNotifier: _isDark,
                  onThemeChanged: _onThemeChanged,
                  onWalletReady: _completeWalletSetup,
                  onWalletSelected: _selectWallet,
                  accountProfile: _accountProfile,
                  walletLoginFuture: _walletLoginFuture,
                  walletIdentity: _walletIdentity,
                )
              : AcoWalletWelcomePage(
                  dark: isDark,
                  onWalletReady: _completeWalletSetup,
                ),
        ),
      );
    },
  );
}
