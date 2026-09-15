import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:http/http.dart' as http;

class DappEntry {
  const DappEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    required this.url,
    required this.iconUrl,
  });

  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String url;
  final String iconUrl;

  factory DappEntry.fromJson(Map<String, dynamic> json) => DappEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    category: json['category'] as String? ?? '',
    subcategory: json['subcategory'] as String? ?? '',
    url: json['url'] as String? ?? '',
    iconUrl: json['icon_url'] as String? ?? '',
  );
}

class DappDirectoryService {
  DappDirectoryService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<DappEntry>> loadHot(String chain) async {
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
    final rawDapps = body['dapps'];
    if (rawDapps is! List) return const [];
    return rawDapps
        .whereType<Map<String, dynamic>>()
        .map(DappEntry.fromJson)
        .where((dapp) => dapp.id.isNotEmpty && dapp.name.isNotEmpty)
        .toList(growable: false);
  }
}
