import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

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
      _endpoint = endpoint ?? Uri.parse(AppConfig.hyperliquidInfoUrl);

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
            asset: index,
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

  Future<List<HyperliquidCandle>> loadCandles({
    required String coin,
    required String interval,
    required int startTime,
    required int endTime,
  }) async {
    final payload = await _post({
      'type': 'candleSnapshot',
      'req': {
        'coin': coin,
        'interval': interval,
        'startTime': startTime,
        'endTime': endTime,
      },
    });
    if (payload is! List) {
      throw const FormatException('Hyperliquid 返回的K线数据无效');
    }
    return [
      for (final item in payload)
        if (item is Map) HyperliquidCandle.fromJson(item),
    ];
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

  Future<List<HyperliquidSpotBalance>> loadSpotBalances(String address) async {
    final payload = await _post({
      'type': 'spotClearinghouseState',
      'user': address,
    });
    if (payload is! Map) {
      throw const FormatException('Hyperliquid 返回的现货账户数据无效');
    }
    final balances = payload['balances'];
    if (balances is! List) return const [];
    return [
      for (final item in balances)
        if (item is Map) HyperliquidSpotBalance.fromJson(item),
    ];
  }

  Future<dynamic> postInfo(Map<String, dynamic> body) => _post(body);

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

class HyperliquidRealtimeClient {
  HyperliquidRealtimeClient({Uri? endpoint})
    : _endpoint = endpoint ?? Uri.parse(AppConfig.hyperliquidWebSocketUrl);

  static const _handshakeTimeout = Duration(seconds: 10);
  static const _heartbeatInterval = Duration(seconds: 30);

  final Uri _endpoint;
  final _updates = StreamController<HyperliquidRealtimeUpdate>();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _coin;
  String? _user;
  String? _candleInterval;
  bool _marketData = true;
  bool _includeTrades = false;
  int _generation = 0;
  int _reconnectAttempt = 0;
  bool _closed = false;
  bool _connecting = false;

  Stream<HyperliquidRealtimeUpdate> subscribe({
    required String coin,
    String? user,
    String? candleInterval,
    bool marketData = true,
    bool includeTrades = false,
  }) {
    _coin = coin;
    _user = user?.trim().isEmpty == true ? null : user?.trim();
    _candleInterval = candleInterval;
    _marketData = marketData;
    _includeTrades = includeTrades;
    unawaited(_connect());
    return _updates.stream;
  }

  Future<void> _connect() async {
    if (_closed || _connecting || _coin == null) return;
    _connecting = true;
    final generation = ++_generation;
    WebSocketChannel? pendingChannel;
    try {
      final channel = WebSocketChannel.connect(_endpoint);
      pendingChannel = channel;
      await channel.ready.timeout(_handshakeTimeout);
      if (_closed || generation != _generation) {
        await channel.sink.close();
        return;
      }
      await _subscription?.cancel();
      await _channel?.sink.close();
      _channel = channel;
      pendingChannel = null;
      _subscription = channel.stream.listen(
        (message) => _handleMessage(message),
        onError: (_) => _handleDisconnect(generation),
        onDone: () => _handleDisconnect(generation),
        cancelOnError: false,
      );
      _reconnectTimer?.cancel();
      _reconnectAttempt = 0;
      _sendSubscriptions();
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        _heartbeatInterval,
        (_) => channel.sink.add(jsonEncode({'method': 'ping'})),
      );
      _add(const HyperliquidRealtimeUpdate.connection(true));
    } catch (_) {
      await pendingChannel?.sink.close();
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _sendSubscriptions() {
    final coin = _coin;
    if (coin == null) return;
    if (_marketData) {
      _subscribe({'type': 'l2Book', 'coin': coin});
      _subscribe({'type': 'activeAssetCtx', 'coin': coin});
    }
    if (_includeTrades) _subscribe({'type': 'trades', 'coin': coin});
    final candleInterval = _candleInterval;
    if (candleInterval != null) {
      _subscribe({'type': 'candle', 'coin': coin, 'interval': candleInterval});
    }
    final user = _user;
    if (user != null) {
      _subscribe({'type': 'clearinghouseState', 'user': user});
      _subscribe({'type': 'openOrders', 'user': user});
    }
  }

  void _subscribe(Map<String, String> subscription) {
    _channel?.sink.add(
      jsonEncode({'method': 'subscribe', 'subscription': subscription}),
    );
  }

  void _handleMessage(dynamic message) {
    final update = parseHyperliquidRealtimeMessage(message);
    if (update != null) _add(update);
  }

  void _handleDisconnect(int generation) {
    if (_closed || generation != _generation) return;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer?.isActive == true) return;
    _add(const HyperliquidRealtimeUpdate.connection(false));
    final seconds = 1 << _reconnectAttempt.clamp(0, 5);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), _connect);
  }

  void _add(HyperliquidRealtimeUpdate update) {
    if (!_closed && !_updates.isClosed) _updates.add(update);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _updates.close();
  }
}

class HyperliquidRealtimeUpdate {
  const HyperliquidRealtimeUpdate({
    this.connected,
    this.orderBook,
    this.assetContext,
    this.account,
    this.openOrders,
    this.candle,
    this.trades,
  });

  const HyperliquidRealtimeUpdate.connection(bool value)
    : this(connected: value);

  final bool? connected;
  final HyperliquidOrderBook? orderBook;
  final HyperliquidAssetContext? assetContext;
  final HyperliquidAccountState? account;
  final List<HyperliquidOpenOrder>? openOrders;
  final HyperliquidCandle? candle;
  final List<HyperliquidTrade>? trades;
}

HyperliquidRealtimeUpdate? parseHyperliquidRealtimeMessage(Object? message) {
  try {
    final decoded = message is String ? jsonDecode(message) : message;
    if (decoded is! Map) return null;
    final channel = '${decoded['channel'] ?? ''}';
    final data = decoded['data'];
    if (channel == 'l2Book' && data is Map) {
      return HyperliquidRealtimeUpdate(
        orderBook: HyperliquidOrderBook.fromJson(data),
      );
    }
    if (channel == 'activeAssetCtx' && data is Map) {
      final context = data['ctx'];
      if (context is Map) {
        return HyperliquidRealtimeUpdate(
          assetContext: HyperliquidAssetContext.fromJson(
            '${data['coin'] ?? ''}',
            context,
          ),
        );
      }
    }
    if (channel == 'clearinghouseState' && data is Map) {
      final state = data['clearinghouseState'] ?? data['state'] ?? data;
      if (state is Map) {
        return HyperliquidRealtimeUpdate(
          account: HyperliquidAccountState.fromJson(state),
        );
      }
    }
    if (channel == 'openOrders') {
      final orders = data is Map ? data['orders'] : data;
      if (orders is List) {
        return HyperliquidRealtimeUpdate(
          openOrders: [
            for (final order in orders)
              if (order is Map) HyperliquidOpenOrder.fromJson(order),
          ],
        );
      }
    }
    if (channel == 'candle' && data is Map) {
      return HyperliquidRealtimeUpdate(
        candle: HyperliquidCandle.fromJson(data),
      );
    }
    if (channel == 'trades' && data is List) {
      return HyperliquidRealtimeUpdate(
        trades: [
          for (final trade in data)
            if (trade is Map) HyperliquidTrade.fromJson(trade),
        ],
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}

class HyperliquidTrade {
  const HyperliquidTrade({
    required this.coin,
    required this.side,
    required this.price,
    required this.size,
    required this.timestamp,
    required this.tradeId,
  });

  final String coin;
  final String side;
  final double? price;
  final double? size;
  final int timestamp;
  final int tradeId;

  bool get isBuy => side == 'B';

  factory HyperliquidTrade.fromJson(Map raw) => HyperliquidTrade(
    coin: '${raw['coin'] ?? ''}',
    side: '${raw['side'] ?? ''}',
    price: _parseDouble(raw['px']),
    size: _parseDouble(raw['sz']),
    timestamp: _parseInt(raw['time']),
    tradeId: _parseInt(raw['tid']),
  );
}

class HyperliquidCandle {
  const HyperliquidCandle({
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
  });

  final int openTime;
  final int closeTime;
  final double open;
  final double close;
  final double high;
  final double low;
  final double volume;

  factory HyperliquidCandle.fromJson(Map raw) => HyperliquidCandle(
    openTime: _parseInt(raw['t']),
    closeTime: _parseInt(raw['T']),
    open: _parseDoubleOrZero(raw['o']),
    close: _parseDoubleOrZero(raw['c']),
    high: _parseDoubleOrZero(raw['h']),
    low: _parseDoubleOrZero(raw['l']),
    volume: _parseDoubleOrZero(raw['v']),
  );
}

class HyperliquidAssetContext {
  const HyperliquidAssetContext({
    required this.coin,
    required this.markPrice,
    required this.oraclePrice,
    required this.funding,
    required this.openInterest,
    required this.volume24h,
    required this.previousDayPrice,
  });

  final String coin;
  final double? markPrice;
  final double? oraclePrice;
  final double? funding;
  final double? openInterest;
  final double? volume24h;
  final double? previousDayPrice;

  factory HyperliquidAssetContext.fromJson(String coin, Map raw) =>
      HyperliquidAssetContext(
        coin: coin,
        markPrice: _parseDouble(raw['markPx']),
        oraclePrice: _parseDouble(raw['oraclePx']),
        funding: _parseDouble(raw['funding']),
        openInterest: _parseDouble(raw['openInterest']),
        volume24h: _parseDouble(raw['dayNtlVlm']),
        previousDayPrice: _parseDouble(raw['prevDayPx']),
      );
}

class HyperliquidMarket {
  const HyperliquidMarket({
    this.asset = 0,
    this.szDecimals = 8,
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

  final int asset;
  final int szDecimals;
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

  HyperliquidMarket withContext(HyperliquidAssetContext context) {
    if (context.coin != name) return this;
    return HyperliquidMarket(
      asset: asset,
      szDecimals: szDecimals,
      name: name,
      markPrice: context.markPrice,
      oraclePrice: context.oraclePrice,
      funding: context.funding,
      openInterest: context.openInterest,
      volume24h: context.volume24h,
      previousDayPrice: context.previousDayPrice,
      maxLeverage: maxLeverage,
      isDelisted: isDelisted,
    );
  }

  factory HyperliquidMarket.fromJson(Map raw, Map context, {int asset = 0}) {
    return HyperliquidMarket(
      asset: asset,
      szDecimals: _parseInt(raw['szDecimals']),
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

class HyperliquidSpotBalance {
  const HyperliquidSpotBalance({
    required this.coin,
    required this.total,
    required this.hold,
  });

  final String coin;
  final double total;
  final double hold;

  double get available => total - hold;

  factory HyperliquidSpotBalance.fromJson(Map raw) => HyperliquidSpotBalance(
    coin: '${raw['coin'] ?? ''}',
    total: _parseDoubleOrZero(raw['total']),
    hold: _parseDoubleOrZero(raw['hold']),
  );
}
