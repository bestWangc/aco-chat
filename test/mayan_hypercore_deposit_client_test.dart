import 'dart:convert';

import 'package:aco_chat/services/mayan_hypercore_deposit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Client extends http.BaseClient {
  _Client(this.response);

  final Object response;
  var calls = 0;
  Uri? requestUri;
  Map<String, dynamic>? requestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestUri = request.url;
    if (request is http.Request && request.body.isNotEmpty) {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
    }
    final body = response is List ? (response as List)[calls++] : response;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
    );
  }
}

void main() {
  test('only accepts a Swift v2 perps route into HyperCore', () async {
    final httpClient = _Client({
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
    });
    final client = MayanHyperCoreDepositClient(client: httpClient);

    final quote = await client.quote(
      amount: '10',
      fromToken: '0xaf88d065e77c8cc2239327c5edb3a432268e5831',
      fromChain: 'arbitrum',
      destinationAddress: '0x0000000000000000000000000000000000000001',
    );

    expect(quote.isPerpsSwiftRoute, isTrue);
    expect(quote.expectedAmountOut, '9.95');
    expect(httpClient.requestUri?.queryParameters['userAddr'], isNull);
    expect(httpClient.requestUri?.queryParameters['destAddr'], isNull);
    expect(
      httpClient.requestUri?.queryParameters['forwarderAddress'],
      MayanHyperCoreDepositClient.evmForwarder,
    );
    expect(
      httpClient.requestUri?.queryParameters['destinationAddress'],
      isNull,
    );
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

  test('builds an unsigned EVM transaction from a quote', () async {
    final client = MayanHyperCoreDepositClient(
      client: _Client({
        'success': true,
        'transaction': {
          'to': '0xforwarder',
          'data': '0x1234',
          'value': '0x0',
          'chainId': 42161,
        },
      }),
      txBuilderUri: Uri.parse('https://builder.test'),
    );
    const quote = MayanHyperCoreDepositQuote(
      type: 'SWIFT',
      swiftVersion: 'V2',
      toChain: 'hypercore',
      toTokenName: 'USDC (perps)',
      expectedAmountOut: '15',
      minReceived: '15',
      deadline: '1',
      raw: {'type': 'SWIFT'},
    );

    final transaction = await client.buildEvm(
      quote: quote,
      swapperAddress: '0x0000000000000000000000000000000000000001',
      destinationAddress: '0x0000000000000000000000000000000000000001',
      signerChainId: 42161,
    );

    expect(transaction['to'], '0xforwarder');
    expect(transaction['data'], '0x1234');
  });

  test('passes referrer fees into quote and build requests', () async {
    final client = _Client([
      {
        'quotes': [
          {
            'type': 'SWIFT',
            'swiftVersion': 'V2',
            'toChain': 'hypercore',
            'toToken': {'name': 'USDC (perps)'},
            'expectedAmountOut': '15',
            'minReceived': '15',
            'deadline64': '1',
          },
        ],
      },
      {
        'success': true,
        'transaction': {'to': '0xforwarder'},
      },
    ]);
    final mayan = MayanHyperCoreDepositClient(
      client: client,
      txBuilderUri: Uri.parse('https://builder.test'),
    );

    await mayan.quote(
      amount: '10',
      fromToken: '0xToken',
      fromChain: 'arbitrum',
      destinationAddress: '0xDestination',
      referrer: 'SolanaReferrer',
      referrerBps: 5,
    );
    expect(client.requestUri?.queryParameters['referrer'], 'SolanaReferrer');
    expect(client.requestUri?.queryParameters['referrerBps'], '5');

    const quote = MayanHyperCoreDepositQuote(
      type: 'SWIFT',
      swiftVersion: 'V2',
      toChain: 'hypercore',
      toTokenName: 'USDC (perps)',
      expectedAmountOut: '15',
      minReceived: '15',
      deadline: '1',
      raw: {'type': 'SWIFT'},
    );
    await mayan.buildEvm(
      quote: quote,
      swapperAddress: '0xSwapper',
      destinationAddress: '0xDestination',
      referrerAddresses: const {'evm': '0xFee'},
    );
    expect(client.requestBody?['params'], {
      'swapperAddress': '0xSwapper',
      'destinationAddress': '0xDestination',
      'referrerAddresses': {'evm': '0xFee'},
    });
  });
}
