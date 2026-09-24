import 'dart:convert';

import 'package:aco_chat/services/mayan_hypercore_deposit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Client extends http.BaseClient {
  _Client(this.response);

  final Map<String, dynamic> response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(response))),
        200,
      );
}

void main() {
  test('only accepts a Swift v2 perps route into HyperCore', () async {
    final client = MayanHyperCoreDepositClient(
      client: _Client({
        'quotes': [
          {
            'type': 'SWIFT',
            'swiftVersion': 'V2',
            'toChain': 'hypercore',
            'toToken': {'name': 'USDC (perps)'},
            'expectedAmountOut': '9.95',
            'minReceived': '9.9',
            'deadline64': '1735689600',
          },
        ],
      }),
    );

    final quote = await client.quote(
      amount: '10',
      fromToken: '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
      fromChain: 'arbitrum',
      destinationAddress: '0x0000000000000000000000000000000000000001',
    );

    expect(quote.isPerpsSwiftRoute, isTrue);
    expect(quote.expectedAmountOut, '9.95');
  });

  test('rejects a route that targets the spot balance', () async {
    final client = MayanHyperCoreDepositClient(
      client: _Client({
        'quotes': [
          {
            'type': 'SWIFT',
            'swiftVersion': 'V2',
            'toChain': 'hypercore',
            'toToken': {'name': 'USDC (spot)'},
            'deadline64': '1735689600',
          },
        ],
      }),
    );

    expect(
      () => client.quote(
        amount: '10',
        fromToken: '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
        fromChain: 'arbitrum',
        destinationAddress: '0x0000000000000000000000000000000000000001',
      ),
      throwsA(isA<MayanHyperCoreDepositException>()),
    );
  });
}
