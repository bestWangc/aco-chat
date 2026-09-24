import 'dart:convert';

import 'package:aco_chat/services/hyperliquid_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _HyperliquidTestClient extends http.BaseClient {
  _HyperliquidTestClient(this.responses);

  final List<Object> responses;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonDecode(await request.finalize().bytesToString());
    final response = responses[calls++];
    expect(body, isA<Map<String, dynamic>>());
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('parses Hyperliquid market metadata and contexts', () async {
    final client = _HyperliquidTestClient([
      [
        {
          'universe': [
            {'name': 'BTC', 'szDecimals': 3},
          ],
        },
        [
          {
            'markPx': '65000.5',
            'oraclePx': '64999.9',
            'funding': '0.0001',
            'openInterest': '100',
            'dayNtlVlm': '2000000',
          },
        ],
      ],
    ]);
    final api = HyperliquidApiClient(client: client);

    final markets = await api.loadMarkets();

    expect(markets, hasLength(1));
    expect(markets.single.name, 'BTC');
    expect(markets.single.asset, 0);
    expect(markets.single.szDecimals, 3);
    expect(markets.single.markPrice, 65000.5);
    expect(markets.single.funding, 0.0001);
    expect(client.calls, 1);
  });

  test(
    'parses clearinghouse positions and tolerates missing liquidation price',
    () async {
      final client = _HyperliquidTestClient([
        {
          'assetPositions': [
            {
              'position': {
                'coin': 'ETH',
                'szi': '-2.5',
                'entryPx': '3000',
                'unrealizedPnl': '12.5',
              },
            },
          ],
        },
      ]);
      final api = HyperliquidApiClient(client: client);

      final positions = await api.loadPositions('0xabc');

      expect(positions.single.coin, 'ETH');
      expect(positions.single.size, -2.5);
      expect(positions.single.liquidationPrice, isNull);
    },
  );

  test('parses order book bids and asks', () async {
    final client = _HyperliquidTestClient([
      {
        'coin': 'ETH',
        'time': 123456,
        'levels': [
          [
            {'px': '2748.0', 'sz': '1.84', 'n': 3},
          ],
          [
            {'px': '2748.1', 'sz': '2.5', 'n': 4},
          ],
        ],
      },
    ]);
    final api = HyperliquidApiClient(client: client);

    final book = await api.loadOrderBook('ETH');

    expect(book.coin, 'ETH');
    expect(book.timestamp, 123456);
    expect(book.bids.single.price, 2748);
    expect(book.asks.single.size, 2.5);
    expect(book.asks.single.orderCount, 4);
  });

  test('parses Hyperliquid candle snapshots', () async {
    final client = _HyperliquidTestClient([
      [
        {
          't': 1681923600000,
          'T': 1681924499999,
          'o': '29295.0',
          'c': '29258.0',
          'h': '29309.0',
          'l': '29250.0',
          'v': '0.98639',
        },
      ],
    ]);
    final api = HyperliquidApiClient(client: client);

    final candles = await api.loadCandles(
      coin: 'BTC',
      interval: '15m',
      startTime: 1681923600000,
      endTime: 1681924499999,
    );

    expect(candles.single.openTime, 1681923600000);
    expect(candles.single.close, 29258);
    expect(candles.single.volume, 0.98639);
  });

  test('parses account summary and open orders', () async {
    final client = _HyperliquidTestClient([
      {
        'marginSummary': {
          'accountValue': '120.5',
          'totalMarginUsed': '20',
          'totalNtlPos': '80',
        },
        'withdrawable': '100.5',
        'assetPositions': [],
      },
      [
        {
          'coin': 'ETH',
          'side': 'B',
          'limitPx': '2700',
          'sz': '0.5',
          'oid': 42,
          'timestamp': 123456,
        },
      ],
    ]);
    final api = HyperliquidApiClient(client: client);

    final account = await api.loadAccountState('0xabc');
    final orders = await api.loadOpenOrders('0xabc');

    expect(account.accountValue, 120.5);
    expect(account.withdrawable, 100.5);
    expect(account.totalMarginUsed, 20);
    expect(account.totalPositionValue, 80);
    expect(account.totalUnrealizedPnl, 0);
    expect(orders.single.coin, 'ETH');
    expect(orders.single.isBuy, isTrue);
    expect(orders.single.orderId, 42);
  });

  test('parses Hyperliquid spot balances', () async {
    final client = _HyperliquidTestClient([
      {
        'balances': [
          {'coin': 'USDC', 'total': '25.5', 'hold': '2.5'},
        ],
      },
    ]);
    final api = HyperliquidApiClient(client: client);

    final balances = await api.loadSpotBalances('0xabc');

    expect(balances.single.coin, 'USDC');
    expect(balances.single.total, 25.5);
    expect(balances.single.available, 23);
  });

  test('parses Hyperliquid websocket market updates', () {
    final bookUpdate = parseHyperliquidRealtimeMessage(
      jsonEncode({
        'channel': 'l2Book',
        'data': {
          'coin': 'ETH',
          'time': 123456,
          'levels': [
            [
              {'px': '2748.0', 'sz': '1.84', 'n': 3},
            ],
            [
              {'px': '2748.1', 'sz': '2.5', 'n': 4},
            ],
          ],
        },
      }),
    );
    final contextUpdate = parseHyperliquidRealtimeMessage({
      'channel': 'activeAssetCtx',
      'data': {
        'coin': 'ETH',
        'ctx': {'markPx': '2748.05', 'funding': '0.0001', 'prevDayPx': '2700'},
      },
    });

    expect(bookUpdate?.orderBook?.coin, 'ETH');
    expect(bookUpdate?.orderBook?.asks.single.price, 2748.1);
    expect(contextUpdate?.assetContext?.markPrice, 2748.05);
    expect(contextUpdate?.assetContext?.funding, 0.0001);
  });

  test('parses Hyperliquid websocket account updates', () {
    final accountUpdate = parseHyperliquidRealtimeMessage({
      'channel': 'clearinghouseState',
      'data': {
        'user': '0xabc',
        'marginSummary': {
          'accountValue': '120.5',
          'totalMarginUsed': '20',
          'totalNtlPos': '80',
        },
        'withdrawable': '100.5',
        'assetPositions': [],
      },
    });
    final ordersUpdate = parseHyperliquidRealtimeMessage({
      'channel': 'openOrders',
      'data': {
        'user': '0xabc',
        'dex': '',
        'orders': [
          {
            'coin': 'ETH',
            'side': 'B',
            'limitPx': '2700',
            'sz': '0.5',
            'oid': 42,
            'timestamp': 123456,
          },
        ],
      },
    });

    expect(accountUpdate?.account?.withdrawable, 100.5);
    expect(ordersUpdate?.openOrders?.single.orderId, 42);
  });

  test('parses Hyperliquid websocket candle updates', () {
    final update = parseHyperliquidRealtimeMessage({
      'channel': 'candle',
      'data': {
        't': 1681923600000,
        'T': 1681924499999,
        'o': '29295.0',
        'c': '29258.0',
        'h': '29309.0',
        'l': '29250.0',
        'v': '0.98639',
      },
    });

    expect(update?.candle?.open, 29295);
    expect(update?.candle?.high, 29309);
  });

  test('parses Hyperliquid websocket trades', () {
    final update = parseHyperliquidRealtimeMessage({
      'channel': 'trades',
      'data': [
        {
          'coin': 'ETH',
          'side': 'B',
          'px': '2748.1',
          'sz': '0.25',
          'time': 123456,
          'tid': 42,
        },
      ],
    });

    expect(update?.trades?.single.coin, 'ETH');
    expect(update?.trades?.single.isBuy, isTrue);
    expect(update?.trades?.single.price, 2748.1);
    expect(update?.trades?.single.size, 0.25);
    expect(update?.trades?.single.tradeId, 42);
  });
}
