class AppConfig {
  static const appVersion = String.fromEnvironment(
    'ACO_APP_VERSION',
    defaultValue: '1.0.27',
  );

  static const cloudflareApiBaseUrl = String.fromEnvironment(
    'ACO_API_BASE_URL',
    defaultValue: 'https://api.aco.chat/api/v1',
  );
  static const directApiBaseUrl = String.fromEnvironment(
    'ACO_DIRECT_API_BASE_URL',
  );
  static String? _selectedApiBaseUrl;

  const AppConfig({this._apiBaseUrl});

  final String? _apiBaseUrl;

  static bool get hasDirectApiRoute => directApiBaseUrl.isNotEmpty;

  static bool get isUsingDirectApiRoute =>
      _selectedApiBaseUrl == directApiBaseUrl && hasDirectApiRoute;

  static void preferDirectApiRoute() {
    if (hasDirectApiRoute) _selectedApiBaseUrl = directApiBaseUrl;
  }

  static void useCloudflareApiRoute() {
    _selectedApiBaseUrl = cloudflareApiBaseUrl;
  }

  String get apiBaseUrl =>
      _apiBaseUrl ?? _selectedApiBaseUrl ?? cloudflareApiBaseUrl;

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
