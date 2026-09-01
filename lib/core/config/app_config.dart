class AppConfig {
  static const appVersion = String.fromEnvironment(
    'ACO_APP_VERSION',
    defaultValue: '1.0.34',
  );

  static const cloudflareApiBaseUrl = String.fromEnvironment(
    'ACO_API_BASE_URL',
    defaultValue: 'https://api.aco.chat/api/v1',
  );
  static const relayApiBaseUrl = String.fromEnvironment(
    'ACO_RELAY_API_BASE_URL',
    defaultValue: 'https://wvyyiw.aiuhz.com/api/v1',
  );
  static const websiteUrl = String.fromEnvironment(
    'ACO_WEBSITE_URL',
    defaultValue: 'https://aco.chat',
  );
  const AppConfig({this._apiBaseUrl});

  final String? _apiBaseUrl;

  static String? _selectedApiBaseUrl;

  static bool get isUsingRelayApiRoute =>
      _selectedApiBaseUrl == relayApiBaseUrl;

  static void usePrimaryApiRoute() {
    _selectedApiBaseUrl = cloudflareApiBaseUrl;
  }

  static void useRelayApiRoute() {
    if (relayApiBaseUrl.isNotEmpty) _selectedApiBaseUrl = relayApiBaseUrl;
  }

  String get apiBaseUrl => _apiBaseUrl ??
      _selectedApiBaseUrl ??
      cloudflareApiBaseUrl;

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
