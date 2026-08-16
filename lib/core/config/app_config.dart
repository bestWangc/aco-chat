class AppConfig {
  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment(
      'ACO_API_BASE_URL',
      defaultValue: 'http://192.168.31.31:8082/api/v1',
    ),
  });

  final String apiBaseUrl;
}
