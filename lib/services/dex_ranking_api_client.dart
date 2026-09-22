import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DexRankingToken {
  const DexRankingToken({
    required this.symbol,
    required this.name,
    required this.chain,
    required this.address,
    required this.dex,
    required this.pool,
    required this.logoUri,
    required this.price,
    required this.change,
    required this.marketCap,
    required this.volume,
    required this.verified,
  });

  final String symbol;
  final String name;
  final String chain;
  final String address;
  final String dex;
  final String pool;
  final String logoUri;
  final String price;
  final String change;
  final String marketCap;
  final String volume;
  final bool verified;

  factory DexRankingToken.fromJson(Map<String, dynamic> json) {
    final base = _asMap(json['base']);
    return DexRankingToken(
      symbol: _value(
        base,
        json,
        'symbol',
        _value(base, json, 'sym', _value(base, json, 'token_symbol', '未知代币')),
      ),
      name: _value(base, json, 'name'),
      chain: _value(base, json, 'chain'),
      address: _value(base, json, 'addr', _value(base, json, 'address')),
      dex: _value(base, json, 'dex'),
      pool: _value(base, json, 'pool'),
      logoUri: '${base['icon'] ?? ''}'.trim(),
      price: _value(base, json, 'price', _value(base, json, 'price_usd')),
      change: _changeValue(base, json),
      verified: base['verified'] == true || json['verified'] == true,
      marketCap: _value(
        base,
        json,
        'market_cap',
        _value(base, json, 'marketCap'),
      ),
      volume: _value(
        base,
        json,
        'volume',
        _value(base, json, 'volume_24h', _value(base, json, 'vu')),
      ),
    );
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};
}

String _value(
  Map<String, dynamic> base,
  Map<String, dynamic> token,
  String key, [
  String fallback = '',
]) => '${base[key] ?? token[key] ?? fallback}';

String _changeValue(Map<String, dynamic> base, Map<String, dynamic> token) {
  final pcr = base['pcr'] ?? token['pcr'];
  final parsed = pcr == null ? null : double.tryParse('$pcr');
  if (parsed != null) {
    var percentage = (parsed * 100).toStringAsFixed(2);
    if (percentage.contains('.')) {
      percentage = percentage
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return '$percentage%';
  }
  return _value(
    base,
    token,
    'change',
    _value(base, token, 'price_change_percent'),
  );
}

class DexRankingApiClient {
  DexRankingApiClient({http.Client? httpClient, Uri? baseUri})
    : _client = httpClient ?? http.Client(),
      _configBaseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl);

  final http.Client _client;
  final Uri _configBaseUri;
  List<Uri>? _rankingUris;

  Future<List<DexRankingToken>> hotTokens({
    String chain = 'all',
    String interval = '5m',
  }) async {
    Object? lastError;
    for (final uri in await _resolveRankingUris()) {
      try {
        final request = {
          'type': 'binance_alpha',
          'chain': chain,
          'interval': interval,
        };
        debugPrint('[HotTokens] POST $uri params=$request');
        final response = await _client.post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(request),
        );
        debugPrint(
          '[HotTokens] response status=${response.statusCode} body=${response.body}',
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw http.ClientException('热门代币请求失败：${response.statusCode}');
        }
        final root = _jsonMap(response.body);
        if (root['status'] == 'error') {
          throw http.ClientException('${root['msg'] ?? '热门代币请求失败'}');
        }
        final data = root['data'];
        final items = data is Map<String, dynamic> ? data['list'] : null;
        if (items is List && items.isNotEmpty) {
          final first = items.first;
          final base = first is Map<String, dynamic> ? first['base'] : null;
          if (base is Map<String, dynamic>) {
            debugPrint(
              '[HotTokens] first item base.iconRaw=${jsonEncode(base['icon'])}',
            );
          }
        }
        final tokens = _tokensFromResponse(root);
        debugPrint('[HotTokens] parsed tokens=${tokens.length}');
        return tokens;
      } catch (error) {
        debugPrint('[HotTokens] request failed uri=$uri error=$error');
        lastError = error;
      }
    }
    throw lastError ?? http.ClientException('热门代币请求失败');
  }

  void close() => _client.close();

  Future<List<Uri>> _resolveRankingUris() async {
    if (_rankingUris != null) return _rankingUris!;
    try {
      final response = await _client.get(_apiUri('dex/ranking-endpoint'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final values = _jsonMap(response.body)['urls'];
        if (values is List) {
          final uris = values
              .whereType<String>()
              .map(Uri.tryParse)
              .whereType<Uri>()
              .where((uri) => uri.scheme == 'https' || uri.scheme == 'http')
              .toList(growable: false);
          if (uris.isNotEmpty) return _rankingUris = uris;
        }
      }
    } catch (_) {
      // Existing releases retain the last-known provider as an offline fallback.
    }
    return _rankingUris = defaultRankingURLs.map(Uri.parse).toList();
  }

  Uri _apiUri(String path) {
    final basePath = _configBaseUri.path.endsWith('/')
        ? _configBaseUri.path.substring(0, _configBaseUri.path.length - 1)
        : _configBaseUri.path;
    return _configBaseUri.replace(path: '$basePath/$path');
  }
}

Map<String, dynamic> _jsonMap(String body) {
  final decoded = jsonDecode(body);
  return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
}

List<DexRankingToken> _tokensFromResponse(Map<String, dynamic> response) {
  final data = response['data'];
  final items = switch (data) {
    List() => data,
    Map<String, dynamic>() => data['list'] ?? data['items'],
    _ => response['list'] ?? response['items'],
  };
  if (items is! List) return const [];
  return items
      .whereType<Map<String, dynamic>>()
      .where((item) => !_isAntfunToken(item))
      .map(DexRankingToken.fromJson)
      .where(
        (token) =>
            token.symbol.isNotEmpty &&
            token.symbol.trim().toLowerCase() != 'antfun',
      )
      .toList(growable: false);
}

bool _isAntfunToken(Map<String, dynamic> item) {
  final base = item['base'];
  final baseMap = base is Map<String, dynamic> ? base : const {};
  final sourceValues = [
    item['launchpad'],
    item['from_pool_launchpad'],
    item['platform'],
    item['source'],
    baseMap['launchpad'],
    baseMap['from_pool_launchpad'],
    baseMap['platform'],
    baseMap['source'],
  ];
  return sourceValues.any((value) {
    final normalized = '$value'.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return normalized.contains('antfun');
  });
}

const defaultRankingURLs = [
  'https://tapi1.ant.fun/api/v1/ranking/list',
  'https://tapi2.ant.fun/api/v1/ranking/list',
  'https://tapi3.ant.fun/api/v1/ranking/list',
  'https://tapi.antapi1.com/api/v1/ranking/list',
];
