import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const appVersion = String.fromEnvironment(
    'ACO_APP_VERSION',
    defaultValue: '1.0.58',
  );

  static const cloudflareApiBaseUrl = String.fromEnvironment(
    'ACO_API_BASE_URL',
    defaultValue: 'https://api.aco.chat/api/v1',
  );
  static const relayApiBaseUrl = String.fromEnvironment(
    'ACO_RELAY_API_BASE_URL',
    defaultValue: 'https://wyyiw.qxctf.com/api/v1',
  );
  static const websiteUrl = String.fromEnvironment(
    'ACO_WEBSITE_URL',
    defaultValue: 'https://aco.chat',
  );
  static const _apiConfigPreferenceKey = 'app.apiBaseUrl';
  static const _imDomainPreferenceKey = 'app.imDomain';
  static const _legacyImDomain = 'im.aco.chat';
  static const imDomain = String.fromEnvironment(
    'ACO_IM_DOMAIN',
    defaultValue: _legacyImDomain,
  );
  static const hyperliquidTestnet = bool.fromEnvironment(
    'ACO_HYPERLIQUID_TESTNET',
  );

  static String get hyperliquidApiBaseUrl => hyperliquidTestnet
      ? 'https://api.hyperliquid-testnet.xyz'
      : 'https://api.hyperliquid.xyz';

  static String get hyperliquidInfoUrl => '$hyperliquidApiBaseUrl/info';

  static String get hyperliquidExchangeUrl => '$hyperliquidApiBaseUrl/exchange';

  static String get hyperliquidWebSocketUrl => hyperliquidTestnet
      ? 'wss://api.hyperliquid-testnet.xyz/ws'
      : 'wss://api.hyperliquid.xyz/ws';

  const AppConfig({this._apiBaseUrl});

  final String? _apiBaseUrl;

  static String? _selectedApiBaseUrl;
  static String? _primaryApiBaseUrl;
  static String _selectedImDomain = imDomain;

  static String get openIMApiAddress => 'https://$_selectedImDomain';
  static String get openIMWebSocketAddress => 'wss://$_selectedImDomain';
  static bool isOpenIMHost(String host) =>
      host == _selectedImDomain || host == _legacyImDomain;

  /// Loads the last known API endpoint, then refreshes it from the website.
  /// The bundled endpoint remains available if both storage and network fail.
  static Future<void> initialize({http.Client? client}) async {
    final preferences = await SharedPreferences.getInstance();
    final cachedBaseUrl = _validatedApiBaseUrl(
      preferences.getString(_apiConfigPreferenceKey),
    );
    _primaryApiBaseUrl = cachedBaseUrl ?? cloudflareApiBaseUrl;
    _selectedApiBaseUrl = _primaryApiBaseUrl;
    _selectedImDomain =
        _validatedDomain(preferences.getString(_imDomainPreferenceKey)) ??
        imDomain;

    final ownsClient = client == null;
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(
            Uri.parse(websiteUrl).resolve('api-config.json'),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final baseUrl = _apiBaseUrlFromDomain(decoded['apiDomain'] as String?);
      if (baseUrl != null) {
        _primaryApiBaseUrl = baseUrl;
        _selectedApiBaseUrl = baseUrl;
        await preferences.setString(_apiConfigPreferenceKey, baseUrl);
      }
      final chatDomain = _validatedDomain(decoded['imDomain'] as String?);
      if (chatDomain != null) {
        _selectedImDomain = chatDomain;
        await preferences.setString(_imDomainPreferenceKey, chatDomain);
      }
    } on Object {
      // Keep the cached or bundled endpoint when the website is unavailable.
    } finally {
      if (ownsClient) requestClient.close();
    }
  }

  static String? _validatedApiBaseUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !uri.path.endsWith('/api/v1')) {
      return null;
    }
    return uri
        .replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''))
        .toString();
  }

  static String? _apiBaseUrlFromDomain(String? value) {
    final domain = _validatedDomain(value);
    return domain == null ? null : 'https://$domain/api/v1';
  }

  static String? _validatedDomain(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final domain = value.trim();
    if (domain.contains('://') ||
        domain.contains('/') ||
        domain.contains('@') ||
        domain.contains('?') ||
        domain.contains('#')) {
      return null;
    }
    final uri = Uri.tryParse('https://$domain');
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.host != domain) {
      return null;
    }
    return uri.host;
  }

  static String get primaryApiBaseUrl =>
      _primaryApiBaseUrl ?? cloudflareApiBaseUrl;

  static bool get isUsingRelayApiRoute =>
      _selectedApiBaseUrl == relayApiBaseUrl;

  static void usePrimaryApiRoute() {
    _selectedApiBaseUrl = primaryApiBaseUrl;
  }

  static void useRelayApiRoute() {
    if (relayApiBaseUrl.isNotEmpty) _selectedApiBaseUrl = relayApiBaseUrl;
  }

  String get apiBaseUrl =>
      _apiBaseUrl ?? _selectedApiBaseUrl ?? primaryApiBaseUrl;

  /// Keeps credentials for local debug servers separate from production.
  String get accountStorageScope {
    final uri = Uri.parse(_apiBaseUrl ?? cloudflareApiBaseUrl);
    final port = uri.hasPort ? '_${uri.port}' : '';
    return '${uri.scheme}_${uri.host}$port'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_]'),
      '_',
    );
  }
}
