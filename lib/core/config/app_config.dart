import 'package:shared_preferences/shared_preferences.dart';

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
    defaultValue: 'https://api-direct.aco.chat/api/v1',
  );
  static const _apiRouteCacheKey = 'network.api_route';
  static const _apiRouteCacheUpdatedAtKey = 'network.api_route_updated_at';
  static const _apiRouteCacheLifetime = Duration(hours: 12);
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

  static Future<void> restoreCachedApiRoute() async {
    final preferences = await SharedPreferences.getInstance();
    final cachedRoute = preferences.getString(_apiRouteCacheKey);
    final cachedAt = preferences.getInt(_apiRouteCacheUpdatedAtKey);
    final cacheIsFresh =
        cachedAt != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(cachedAt),
            ) <
            _apiRouteCacheLifetime;
    if (cacheIsFresh && _isSupportedApiRoute(cachedRoute)) {
      _selectedApiBaseUrl = cachedRoute;
      return;
    }
    preferDirectApiRoute();
  }

  static Future<void> cacheSelectedApiRoute() async {
    final selectedRoute = _selectedApiBaseUrl ?? cloudflareApiBaseUrl;
    if (!_isSupportedApiRoute(selectedRoute)) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_apiRouteCacheKey, selectedRoute);
    await preferences.setInt(
      _apiRouteCacheUpdatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static bool _isSupportedApiRoute(String? route) =>
      route == cloudflareApiBaseUrl ||
      (hasDirectApiRoute && route == directApiBaseUrl);

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
