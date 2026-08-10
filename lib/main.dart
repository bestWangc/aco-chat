import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDark = await ThemePreferences.load();
  final walletConfigured = await WalletPreferences.load();
  if (walletConfigured) {
    await AccountSession.signInForWallet();
  }
  runApp(
    AcoApp(
      initialIsDark: isDark,
      onThemeChanged: ThemePreferences.save,
      initialWalletConfigured: walletConfigured,
      onWalletConfigured: WalletPreferences.save,
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

class WalletPreferences {
  const WalletPreferences._();

  static const configuredKey = 'wallet.configured';
  static const walletIdKey = 'wallet.localId';

  static Future<bool> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(configuredKey) ?? false;
  }

  static Future<void> save(bool configured) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(configuredKey, configured);
  }

  static Future<String> walletId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(walletIdKey);
    if (existing != null) return existing;
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await preferences.setString(walletIdKey, id);
    return id;
  }
}

class AccountProfile {
  const AccountProfile({
    required this.walletId,
    required this.username,
    required this.nickname,
  });

  final String walletId;
  final String username;
  final String nickname;

  Map<String, String> toJson() => {
    'walletId': walletId,
    'username': username,
    'nickname': nickname,
  };

  static AccountProfile fromJson(Map<String, dynamic> json) => AccountProfile(
    walletId: json['walletId'] as String,
    username: json['username'] as String,
    nickname: json['nickname'] as String,
  );
}

class AccountSession {
  const AccountSession._();

  static const _accountPrefix = 'account.wallet.';
  static const _activeAccountKey = 'account.active';

  /// Silently resumes the account tied to this wallet, or creates its defaults.
  static Future<AccountProfile> signInForWallet() async {
    final preferences = await SharedPreferences.getInstance();
    final walletId = await WalletPreferences.walletId();
    final accountKey = '$_accountPrefix$walletId';
    final stored = preferences.getString(accountKey);
    final profile = stored == null
        ? AccountProfile(
            walletId: walletId,
            username: 'aco_${walletId.substring(walletId.length - 6)}',
            nickname: 'Aco ${walletId.substring(walletId.length - 4)}',
          )
        : AccountProfile.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    if (stored == null) {
      await preferences.setString(accountKey, jsonEncode(profile.toJson()));
    }
    await preferences.setString(
      _activeAccountKey,
      jsonEncode(profile.toJson()),
    );
    return profile;
  }
}

class AcoApp extends StatefulWidget {
  const AcoApp({
    this.initialIsDark = true,
    this.onThemeChanged,
    this.initialWalletConfigured = true,
    this.onWalletConfigured,
    super.key,
  });

  final bool initialIsDark;
  final ValueChanged<bool>? onThemeChanged;
  final bool initialWalletConfigured;
  final ValueChanged<bool>? onWalletConfigured;

  @override
  State<AcoApp> createState() => _AcoAppState();
}

class _AcoAppState extends State<AcoApp> {
  late final ValueNotifier<bool> _isDark = ValueNotifier<bool>(
    widget.initialIsDark,
  );
  late bool _walletConfigured = widget.initialWalletConfigured;

  void _onThemeChanged(bool isDark) {
    widget.onThemeChanged?.call(isDark);
  }

  Future<void> _completeWalletSetup() async {
    await AccountSession.signInForWallet();
    setState(() => _walletConfigured = true);
    widget.onWalletConfigured?.call(true);
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
                fontFamily: 'PingFang',
                fontSize: AcoTypography.body,
              ),
            ),
          ),
          home: _walletConfigured
              ? AcoDesignShell(
                  themeNotifier: _isDark,
                  onThemeChanged: _onThemeChanged,
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
