import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

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
    required this.liquidity,
    required this.verified,
    required this.createdAt,
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
  final String liquidity;
  final bool verified;
  final DateTime? createdAt;

  DexRankingToken copyWith({
    String? symbol,
    String? name,
    String? chain,
    String? address,
    String? dex,
    String? pool,
    String? logoUri,
    String? price,
    String? change,
    String? marketCap,
    String? volume,
    String? liquidity,
    bool? verified,
    DateTime? createdAt,
  }) => DexRankingToken(
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    chain: chain ?? this.chain,
    address: address ?? this.address,
    dex: dex ?? this.dex,
    pool: pool ?? this.pool,
    logoUri: logoUri ?? this.logoUri,
    price: price ?? this.price,
    change: change ?? this.change,
    marketCap: marketCap ?? this.marketCap,
    volume: volume ?? this.volume,
    liquidity: liquidity ?? this.liquidity,
    verified: verified ?? this.verified,
    createdAt: createdAt ?? this.createdAt,
  );

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
      pool: _firstNonEmpty([
        base['pool'],
        json['pool'],
        base['pair_address'],
        json['pair_address'],
        base['pairAddress'],
        json['pairAddress'],
        base['pair'],
        json['pair'],
        base['pool_address'],
        json['pool_address'],
        base['poolAddress'],
        json['poolAddress'],
      ]),
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
      liquidity: _value(
        base,
        json,
        'liquidity',
        _value(base, json, 'tvl_usd', _value(base, json, 'tvl')),
      ),
      createdAt: _parseCreatedAt(base['ct'] ?? json['ct']),
    );
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};
}

class DexKline {
  const DexKline({
    required this.timestamp,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
  });

  final int timestamp;
  final double open;
  final double close;
  final double high;
  final double low;
  final double volume;

  factory DexKline.fromJson(Map<String, dynamic> json) => DexKline(
    timestamp: _parseTimestamp(json['ts']),
    open: _parseDouble(json['o']),
    close: _parseDouble(json['c']),
    high: _parseDouble(json['h']),
    low: _parseDouble(json['l']),
    volume: _parseDouble(json['vu']),
  );
}

class DexPriceUpdate {
  const DexPriceUpdate({required this.timestamp, required this.price});

  final int timestamp;
  final double price;

  factory DexPriceUpdate.fromJson(Map<String, dynamic> json) => DexPriceUpdate(
    timestamp: _parseTimestamp(json['ts']),
    price: _parseDouble(json['price']),
  );
}

class DexKlineRealtimeClient {
  DexKlineRealtimeClient({Uri? baseUri})
    : _baseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl);

  final Uri _baseUri;
  WebSocketChannel? _channel;
  StreamController<DexPriceUpdate>? _updates;

  Stream<DexPriceUpdate> subscribe(
    DexRankingToken token, {
    required String interval,
  }) {
    final updates = StreamController<DexPriceUpdate>();
    _updates = updates;
    final channel = WebSocketChannel.connect(_webSocketUri());
    _channel = channel;
    channel.stream.listen(
      (message) {
        debugPrint('[DexKlineWS] received message=$message');
        try {
          final decoded = jsonDecode('$message');
          if (decoded is! Map<String, dynamic> || decoded['type'] != 'price') {
            return;
          }
          final update = DexPriceUpdate.fromJson(decoded);
          if (update.timestamp > 0 && update.price > 0) {
            updates.add(update);
          }
        } catch (error, stackTrace) {
          debugPrint('[DexKlineWS] invalid message error=$error');
          updates.addError(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[DexKlineWS] stream failed error=$error');
        if (!updates.isClosed) updates.addError(error, stackTrace);
      },
      onDone: () {
        if (!updates.isClosed) updates.close();
      },
      cancelOnError: false,
    );
    channel.sink.add(
      jsonEncode({
        'action': 'subscribe',
        'chain': token.chain,
        'pool': token.pool,
        'token': token.address,
        'interval': interval,
      }),
    );
    debugPrint(
      '[DexKlineWS] subscribe symbol=${token.symbol} '
      'chain=${token.chain} pool=${token.pool} interval=$interval',
    );
    return updates.stream;
  }

  Future<void> close() async {
    final updates = _updates;
    final channel = _channel;
    _updates = null;
    _channel = null;
    if (updates != null && !updates.isClosed) await updates.close();
    await channel?.sink.close();
  }

  Uri _webSocketUri() {
    final path = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(
      scheme: _baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '$path/dex/kline/ws',
      query: '',
      fragment: '',
    );
  }
}

DateTime? _parseCreatedAt(Object? value) {
  final timestamp = double.tryParse('$value');
  if (timestamp == null || !timestamp.isFinite || timestamp <= 0) return null;
  final milliseconds = timestamp >= 1e11
      ? timestamp.round()
      : (timestamp * 1000).round();
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

int _parseTimestamp(Object? value) {
  final parsed = double.tryParse('$value');
  if (parsed == null || !parsed.isFinite || parsed <= 0) return 0;
  return (parsed >= 1e11 ? parsed : parsed * 1000).round();
}

double _parseDouble(Object? value) {
  final parsed = double.tryParse('$value');
  return parsed != null && parsed.isFinite ? parsed : 0;
}

String _value(
  Map<String, dynamic> base,
  Map<String, dynamic> token,
  String key, [
  String fallback = '',
]) => '${base[key] ?? token[key] ?? fallback}';

String _firstNonEmpty(Iterable<Object?> values) {
  for (final value in values) {
    final normalized = '${value ?? ''}'.trim();
    if (normalized.isNotEmpty && normalized != 'null') return normalized;
  }
  return '';
}

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
    String type = 'binance_alpha',
    String chain = 'all',
    String interval = '5m',
  }) async {
    Object? lastError;
    for (final uri in await _resolveRankingUris()) {
      try {
        final request = {'type': type, 'chain': chain, 'interval': interval};
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
        if (tokens.isNotEmpty) {
          debugPrint(
            '[HotTokens] first parsed token symbol=${tokens.first.symbol} '
            'chain=${tokens.first.chain} pool=${tokens.first.pool}',
          );
        }
        return tokens;
      } catch (error) {
        debugPrint('[HotTokens] request failed uri=$uri error=$error');
        lastError = error;
      }
    }
    throw lastError ?? http.ClientException('热门代币请求失败');
  }

  Future<DexRankingToken?> dexScreenerTokenInfo(DexRankingToken token) async {
    if (token.pool.trim().isEmpty) {
      debugPrint(
        '[DexScreener] skip symbol=${token.symbol} '
        'chain=${token.chain} reason=missing pairId(pool)',
      );
      return null;
    }

    final chainId = _dexScreenerChainId(token.chain);
    final uri = _apiUri(
      'dex/pairs/$chainId/${Uri.encodeComponent(token.pool)}',
    );
    debugPrint('[DexScreener] GET $uri');
    final response = await _client.get(uri);
    debugPrint(
      '[DexScreener] response status=${response.statusCode} body=${response.body}',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('DexScreener 请求失败：${response.statusCode}');
    }

    final pairs = _jsonMap(response.body)['pairs'];
    if (pairs is! List) return null;
    final pairValues = pairs.whereType<Map<String, dynamic>>();
    final pair = pairValues.isEmpty ? null : pairValues.first;
    return pair == null ? null : _mergeDexScreenerPair(token, pair);
  }

  Future<List<DexKline>> klineHistory(
    DexRankingToken token, {
    required String interval,
  }) async {
    final request = {
      'chain': token.chain,
      'address': token.address,
      'pool': token.pool,
      'interval': interval,
    };
    Object? lastError;
    for (final uri in await _resolveKlineUris()) {
      try {
        debugPrint('[DexKline] POST $uri params=$request');
        final response = await _client.post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(request),
        );
        debugPrint(
          '[DexKline] response status=${response.statusCode} body=${response.body}',
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw http.ClientException('K 线请求失败：${response.statusCode}');
        }
        final root = _jsonMap(response.body);
        if (root['code'] != 0) {
          throw http.ClientException('${root['msg'] ?? 'K 线请求失败'}');
        }
        final data = root['data'];
        final items = data is Map<String, dynamic> ? data['list'] : null;
        if (items is! List) return const [];
        return items
            .whereType<Map<String, dynamic>>()
            .map(DexKline.fromJson)
            .where((item) => item.timestamp > 0 && item.close.isFinite)
            .toList(growable: false);
      } catch (error) {
        debugPrint('[DexKline] request failed uri=$uri error=$error');
        lastError = error;
      }
    }
    throw lastError ?? http.ClientException('K 线请求失败');
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

  Future<List<Uri>> _resolveKlineUris() async {
    final rankingUris = await _resolveRankingUris();
    return rankingUris
        .map(
          (uri) => uri.replace(
            path: uri.path.replaceFirst(
              RegExp(r'/ranking/list/?$'),
              '/kline/history',
            ),
          ),
        )
        .toList(growable: false);
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

DexRankingToken _mergeDexScreenerPair(
  DexRankingToken fallback,
  Map<String, dynamic> pair,
) {
  final base = DexRankingToken._asMap(pair['baseToken']);
  final info = DexRankingToken._asMap(pair['info']);
  final liquidity = DexRankingToken._asMap(pair['liquidity']);
  final priceChange = DexRankingToken._asMap(pair['priceChange']);
  final volume = DexRankingToken._asMap(pair['volume']);

  return fallback.copyWith(
    symbol: _nonEmptyString(base['symbol'], fallback.symbol),
    name: _nonEmptyString(base['name'], fallback.name),
    address: _nonEmptyString(base['address'], fallback.address),
    dex: _nonEmptyString(pair['dexId'], fallback.dex),
    pool: _nonEmptyString(pair['pairAddress'], fallback.pool),
    logoUri: _nonEmptyString(info['imageUrl'], fallback.logoUri),
    price: _nonEmptyString(pair['priceUsd'], fallback.price),
    change: _formatDexScreenerChange(
      priceChange['m5'] ?? priceChange['h24'],
      fallback.change,
    ),
    marketCap: _nonEmptyString(
      pair['marketCap'] ?? pair['fdv'],
      fallback.marketCap,
    ),
    volume: _nonEmptyString(volume['h24'], fallback.volume),
    liquidity: _nonEmptyString(liquidity['usd'], fallback.liquidity),
    createdAt: _parseCreatedAt(pair['pairCreatedAt']) ?? fallback.createdAt,
  );
}

String _dexScreenerChainId(String chain) => switch (chain.toLowerCase()) {
  'eth' || 'ethereum' => 'ethereum',
  'sol' || 'solana' => 'solana',
  'bsc' => 'bsc',
  _ => chain,
};

String _nonEmptyString(Object? value, String fallback) {
  final result = '${value ?? ''}'.trim();
  return result.isEmpty ? fallback : result;
}

String _formatDexScreenerChange(Object? value, String fallback) {
  final parsed = double.tryParse('$value');
  if (parsed == null || !parsed.isFinite) return fallback;
  final formatted = parsed.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return '${formatted.endsWith('.') ? formatted.substring(0, formatted.length - 1) : formatted}%';
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
