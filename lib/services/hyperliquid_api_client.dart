import 'dart:convert';

import 'package:http/http.dart' as http;

double? _parseDouble(Object? value) => double.tryParse('$value');

double _parseDoubleOrZero(Object? value) => _parseDouble(value) ?? 0;

int _parseInt(Object? value) => value is num ? value.toInt() : 0;

List<HyperliquidOrderBookLevel> _parseOrderBookSide(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) HyperliquidOrderBookLevel.fromJson(item),
  ];
}

List<HyperliquidPosition> _parsePositions(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map && item['position'] is Map)
        HyperliquidPosition.fromJson(item['position'] as Map),
  ];
}

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
    return (await loadAccountState(address)).positions;
  }

  Future<HyperliquidOrderBook> loadOrderBook(String coin) async {
    final payload = await _post({'type': 'l2Book', 'coin': coin});
    if (payload is! Map) {
      throw const FormatException('Hyperliquid 返回的盘口数据无效');
    }
    return HyperliquidOrderBook.fromJson(payload);
  }

  Future<HyperliquidAccountState> loadAccountState(String address) async {
    final payload = await _post({
      'type': 'clearinghouseState',
      'user': address,
    });
    if (payload is! Map) {
      throw const FormatException('Hyperliquid 返回的账户数据无效');
    }
    return HyperliquidAccountState.fromJson(payload);
  }

  Future<List<HyperliquidOpenOrder>> loadOpenOrders(String address) async {
    final payload = await _post({'type': 'openOrders', 'user': address});
    if (payload is! List) {
      throw const FormatException('Hyperliquid 返回的挂单数据无效');
    }
    return [
      for (final item in payload)
        if (item is Map) HyperliquidOpenOrder.fromJson(item),
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
    required this.previousDayPrice,
    required this.maxLeverage,
    required this.isDelisted,
  });

  final String name;
  final double? markPrice;
  final double? oraclePrice;
  final double? funding;
  final double? openInterest;
  final double? volume24h;
  final double? previousDayPrice;
  final int maxLeverage;
  final bool isDelisted;

  double? get openInterestNotional {
    if (openInterest == null || markPrice == null) return null;
    return openInterest! * markPrice!;
  }

  double? get changePercent {
    if (markPrice == null ||
        previousDayPrice == null ||
        previousDayPrice == 0) {
      return null;
    }
    return (markPrice! - previousDayPrice!) / previousDayPrice! * 100;
  }

  factory HyperliquidMarket.fromJson(Map raw, Map context) {
    return HyperliquidMarket(
      name: '${raw['name'] ?? ''}',
      markPrice: _parseDouble(context['markPx']),
      oraclePrice: _parseDouble(context['oraclePx']),
      funding: _parseDouble(context['funding']),
      openInterest: _parseDouble(context['openInterest']),
      volume24h: _parseDouble(context['dayNtlVlm']),
      previousDayPrice: _parseDouble(context['prevDayPx']),
      maxLeverage: _parseInt(raw['maxLeverage']),
      isDelisted: raw['isDelisted'] == true,
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

  factory HyperliquidPosition.fromJson(Map raw) => HyperliquidPosition(
    coin: '${raw['coin'] ?? ''}',
    size: _parseDouble(raw['szi']),
    entryPrice: _parseDouble(raw['entryPx']),
    unrealizedPnl: _parseDouble(raw['unrealizedPnl']),
    liquidationPrice: _parseDouble(raw['liquidationPx']),
  );
}

class HyperliquidOrderBook {
  const HyperliquidOrderBook({
    required this.coin,
    required this.timestamp,
    required this.bids,
    required this.asks,
  });

  final String coin;
  final int timestamp;
  final List<HyperliquidOrderBookLevel> bids;
  final List<HyperliquidOrderBookLevel> asks;

  factory HyperliquidOrderBook.fromJson(Map raw) {
    final levels = raw['levels'];
    final bids = levels is List && levels.isNotEmpty
        ? _parseOrderBookSide(levels[0])
        : const <HyperliquidOrderBookLevel>[];
    final asks = levels is List && levels.length > 1
        ? _parseOrderBookSide(levels[1])
        : const <HyperliquidOrderBookLevel>[];
    return HyperliquidOrderBook(
      coin: '${raw['coin'] ?? ''}',
      timestamp: _parseInt(raw['time']),
      bids: bids,
      asks: asks,
    );
  }
}

class HyperliquidOrderBookLevel {
  const HyperliquidOrderBookLevel({
    required this.price,
    required this.size,
    required this.orderCount,
  });

  final double? price;
  final double? size;
  final int orderCount;

  factory HyperliquidOrderBookLevel.fromJson(Map raw) =>
      HyperliquidOrderBookLevel(
        price: _parseDouble(raw['px']),
        size: _parseDouble(raw['sz']),
        orderCount: _parseInt(raw['n']),
      );
}

class HyperliquidAccountState {
  const HyperliquidAccountState({
    required this.accountValue,
    required this.withdrawable,
    required this.totalMarginUsed,
    required this.totalPositionValue,
    required this.positions,
  });

  final double accountValue;
  final double withdrawable;
  final double totalMarginUsed;
  final double totalPositionValue;
  final List<HyperliquidPosition> positions;

  double get totalUnrealizedPnl => positions.fold(
    0,
    (total, position) => total + (position.unrealizedPnl ?? 0),
  );

  factory HyperliquidAccountState.fromJson(Map raw) {
    final summary = raw['marginSummary'] is Map
        ? raw['marginSummary'] as Map
        : const {};
    return HyperliquidAccountState(
      accountValue: _parseDoubleOrZero(summary['accountValue']),
      withdrawable: _parseDoubleOrZero(raw['withdrawable']),
      totalMarginUsed: _parseDoubleOrZero(summary['totalMarginUsed']),
      totalPositionValue: _parseDoubleOrZero(summary['totalNtlPos']),
      positions: _parsePositions(raw['assetPositions']),
    );
  }
}

class HyperliquidOpenOrder {
  const HyperliquidOpenOrder({
    required this.coin,
    required this.price,
    required this.size,
    required this.isBuy,
    required this.orderId,
    required this.timestamp,
  });

  final String coin;
  final double? price;
  final double? size;
  final bool isBuy;
  final int orderId;
  final int timestamp;

  factory HyperliquidOpenOrder.fromJson(Map raw) => HyperliquidOpenOrder(
    coin: '${raw['coin'] ?? ''}',
    price: _parseDouble(raw['limitPx']),
    size: _parseDouble(raw['sz']),
    isBuy: raw['side'] == 'B',
    orderId: _parseInt(raw['oid']),
    timestamp: _parseInt(raw['timestamp']),
  );
}
