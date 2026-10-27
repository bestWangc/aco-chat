import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:http/http.dart' as http;

class DappEntry {
  const DappEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    this.description,
    required this.url,
    required this.iconUrl,
    this.networks = const [],
  });

  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String? description;
  final String url;
  final String iconUrl;
  final List<String> networks;

  factory DappEntry.fromJson(Map<String, dynamic> json) => DappEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? '',
    subcategory: json['subcategory'] as String? ?? '',
    description: json['description'] as String?,
    url: json['url'] as String? ?? '',
    iconUrl: json['icon_url'] as String? ?? '',
    networks: _networksFromJson(json['networks']),
  );

  static List<String> _networksFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((network) => network.toLowerCase())
        .toList(growable: false);
  }
}

class DappDirectoryService {
  DappDirectoryService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _cacheTtl = Duration(minutes: 5);
  static final _cache = <String, _DappCacheEntry>{};
  static final _pending = <String, Future<_DappCacheEntry>>{};

  Future<List<DappEntry>> loadHot(String chain) async =>
      (await _loadDirectory(chain)).hotDapps;

  Future<List<DappEntry>> loadCommunity(String chain) async =>
      (await _loadDirectory(chain)).communityDapps;

  Future<_DappCacheEntry> _loadDirectory(String chain) async {
    final key = chain.trim().toLowerCase();
    final cached = _cache[key];
    if (cached != null) {
      final age = DateTime.now().difference(cached.createdAt);
      if (age < _cacheTtl) return cached;
    }
    final inFlight = _pending[key];
    if (inFlight != null) return inFlight;

    final request = _fetchHot(key);
    _pending[key] = request;
    try {
      final entry = await request;
      _cache[key] = entry;
      return entry;
    } finally {
      _pending.remove(key);
    }
  }

  Future<List<DappEntry>> loadEarnings(String chain) async {
    final base = const AppConfig().apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await _client.get(
      Uri.parse(
        '$base/dapps/hot',
      ).replace(queryParameters: {'chain': chain.trim().toLowerCase()}),
      headers: {'x-app-version': AppConfig.appVersion},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = body['earnings_dapps'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(DappEntry.fromJson)
        .toList(growable: false);
  }

  Future<_DappCacheEntry> _fetchHot(String chain) async {
    final base = const AppConfig().apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await _client
        .get(
          Uri.parse(
            '$base/dapps/hot',
          ).replace(queryParameters: {'chain': chain}),
          headers: {'x-app-version': AppConfig.appVersion},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('hot dapp request failed');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _DappCacheEntry(
      DateTime.now(),
      hotDapps: _parseDapps(body['dapps']),
      communityDapps: _parseDapps(body['community_dapps']),
    );
  }
}

List<DappEntry> _parseDapps(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(DappEntry.fromJson)
      .where((dapp) => dapp.id.isNotEmpty && dapp.name.isNotEmpty)
      .toList(growable: false);
}

class _DappCacheEntry {
  const _DappCacheEntry(
    this.createdAt, {
    required this.hotDapps,
    required this.communityDapps,
  });

  final DateTime createdAt;
  final List<DappEntry> hotDapps;
  final List<DappEntry> communityDapps;
}
