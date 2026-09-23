import 'dart:convert';

import 'package:http/http.dart' as http;

/// Read-only Hyperliquid market client.
///
/// Hyperliquid perpetuals are not ERC-20 pool swaps. Market metadata and
/// account state are served by the Hyperliquid API, while order submission
/// uses a separate EIP-712 signed exchange request.
class HyperliquidApiClient {
  HyperliquidApiClient({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _endpoint = endpoint ?? Uri.parse('https://api.hyperliquid.xyz/info');

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;

  Future<List<HyperliquidMarket>> loadMarkets() async {
    final payload = await _post({'type': 'metaAndAssetCtxs'});
    if (payload is! List || payload.length < 2 || payload[0] is! Map) {
      throw const FormatException('Hyperliquid 返回的市场数据无效');
    }
    final universe = (payload[0] as Map)['universe'];
    final contexts = payload[1] is List ? payload[1] as List : const [];
    if (universe is! List) {
      throw const FormatException('Hyperliquid 缺少合约列表');
    }
    return [
      for (var index = 0; index < universe.length; index++)
        if (universe[index] is Map)
          HyperliquidMarket.fromJson(
            universe[index] as Map,
            index < contexts.length && contexts[index] is Map
                ? contexts[index] as Map
                : const {},
          ),
    ];
  }

  Future<List<HyperliquidPosition>> loadPositions(String address) async {
    final payload = await _post({
      'type': 'clearinghouseState',
      'user': address,
    });
    if (payload is! Map) {
      throw const FormatException('Hyperliquid 返回的账户数据无效');
    }
    final positions = payload['assetPositions'];
    if (positions is! List) return const [];
    return [
      for (final item in positions)
        if (item is Map && item['position'] is Map)
          HyperliquidPosition.fromJson(item['position'] as Map),
    ];
  }

  Future<dynamic> _post(Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('Hyperliquid 请求失败（${response.statusCode}）');
    }
    return jsonDecode(response.body);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class HyperliquidMarket {
  const HyperliquidMarket({
    required this.name,
    required this.markPrice,
    required this.oraclePrice,
    required this.funding,
    required this.openInterest,
    required this.volume24h,
  });

  final String name;
  final double? markPrice;
  final double? oraclePrice;
  final double? funding;
  final double? openInterest;
  final double? volume24h;

  factory HyperliquidMarket.fromJson(Map raw, Map context) {
    double? number(Object? value) => double.tryParse('$value');
    return HyperliquidMarket(
      name: '${raw['name'] ?? ''}',
      markPrice: number(context['markPx']),
      oraclePrice: number(context['oraclePx']),
      funding: number(context['funding']),
      openInterest: number(context['openInterest']),
      volume24h: number(context['dayNtlVlm']),
    );
  }
}

class HyperliquidPosition {
  const HyperliquidPosition({
    required this.coin,
    required this.size,
    required this.entryPrice,
    required this.unrealizedPnl,
    required this.liquidationPrice,
  });

  final String coin;
  final double? size;
  final double? entryPrice;
  final double? unrealizedPnl;
  final double? liquidationPrice;

  factory HyperliquidPosition.fromJson(Map raw) {
    double? number(Object? value) => double.tryParse('$value');
    return HyperliquidPosition(
      coin: '${raw['coin'] ?? ''}',
      size: number(raw['szi']),
      entryPrice: number(raw['entryPx']),
      unrealizedPnl: number(raw['unrealizedPnl']),
      liquidationPrice: number(raw['liquidationPx']),
    );
  }
}
