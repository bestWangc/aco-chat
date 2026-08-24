class AppConfig {
  static const appVersion = String.fromEnvironment(
    'ACO_APP_VERSION',
    defaultValue: '1.0.20',
  );

  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment(
      'ACO_API_BASE_URL',
      defaultValue: 'https://api.aco.chat/api/v1',
    ),
  });

  final String apiBaseUrl;

  /// Keeps credentials for local debug servers separate from production.
  String get accountStorageScope {
    final uri = Uri.parse(apiBaseUrl);
    final port = uri.hasPort ? '_${uri.port}' : '';
    return '${uri.scheme}_${uri.host}$port'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_]'),
      '_',
    );
  }
}
