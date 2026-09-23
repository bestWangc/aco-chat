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
}
