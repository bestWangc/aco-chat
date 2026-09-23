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
            {'name': 'BTC'},
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
}
