import 'dart:convert';

import 'package:aco_chat/services/hyperliquid_exchange_client.dart';
import 'package:aco_chat/services/hyperliquid_signing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _ExchangeClient extends http.BaseClient {
  Map<String, dynamic>? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'status': 'ok'}))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('localizes the unified account transfer error', () {
    const error = HyperliquidExchangeException(
      'Action disabled when unified account is active',
    );

    expect(error.message, contains('无需执行 Spot → 合约划转'));
  });

  test('localizes the testnet onboarding deposit error', () {
    const error = HyperliquidExchangeException(
      'Must deposit before performing actions. User: 0x123',
    );

    expect(error.message, contains('主网存款、测试网 Faucet'));
    expect(error.toString(), error.message);
  });

  test('submits a signed order payload to the exchange endpoint', () async {
    final client = _ExchangeClient();
    final exchange = HyperliquidExchangeClient(
      client: client,
      endpoint: Uri.parse('https://example.test/exchange'),
    );

    await exchange.placeOrder(
      agentPrivateKey:
          '0x0123456789012345678901234567890123456789012345678901234567890123',
      action: {
        'type': 'order',
        'orders': [
          {
            'a': 1,
            'b': true,
            'p': '100',
            's': '1',
            'r': false,
            't': {
              'limit': {'tif': 'Gtc'},
            },
          },
        ],
        'grouping': 'na',
      },
    );

    final request = client.request!;
    expect(request['action'], isA<Map<String, dynamic>>());
    expect((request['action'] as Map)['type'], 'order');
    expect(request['signature'], isA<Map<String, dynamic>>());
    expect((request['signature'] as Map)['r'], startsWith('0x'));
    expect(request.containsKey('nonce'), isTrue);
  });

  test('submits a main-wallet builder fee approval', () async {
    final client = _ExchangeClient();
    final exchange = HyperliquidExchangeClient(
      client: client,
      endpoint: Uri.parse('https://example.test/exchange'),
    );

    await exchange.approveBuilderFee(
      masterPrivateKey:
          '0x0123456789012345678901234567890123456789012345678901234567890123',
      builderAddress: '0x0000000000000000000000000000000000000001',
      maxFeeRate: '0.01%',
    );

    final request = client.request!;
    final action = request['action'] as Map<String, dynamic>;
    expect(action['type'], 'approveBuilderFee');
    expect(action['builder'], '0x0000000000000000000000000000000000000001');
    expect(action['maxFeeRate'], '0.01%');
    expect(request['signature'], isA<Map<String, dynamic>>());
  });

  test('submits a signed Arbitrum withdrawal request', () async {
    const privateKey =
        '0x0123456789012345678901234567890123456789012345678901234567890123';
    final client = _ExchangeClient();
    final exchange = HyperliquidExchangeClient(
      client: client,
      endpoint: Uri.parse('https://example.test/exchange'),
    );

    await exchange.withdraw(
      masterPrivateKey: privateKey,
      destination: '0x0000000000000000000000000000000000000001',
      amount: '9',
      expectedSignerAddress: HyperliquidSigner.addressFromPrivateKey(
        privateKey,
      ),
    );

    final request = client.request!;
    final action = request['action'] as Map<String, dynamic>;
    expect(action['type'], 'withdraw3');
    expect(action['destination'], '0x0000000000000000000000000000000000000001');
    expect(action['amount'], '9');
    expect(action['time'], request['nonce']);
    expect(request['signature'], isA<Map<String, dynamic>>());
  });

  test('rejects a withdrawal signed by a different wallet', () async {
    final client = _ExchangeClient();
    final exchange = HyperliquidExchangeClient(
      client: client,
      endpoint: Uri.parse('https://example.test/exchange'),
    );

    await expectLater(
      exchange.withdraw(
        masterPrivateKey:
            '0x0123456789012345678901234567890123456789012345678901234567890123',
        destination: '0x0000000000000000000000000000000000000001',
        amount: '9',
        expectedSignerAddress: '0x0000000000000000000000000000000000000001',
      ),
      throwsA(isA<HyperliquidExchangeException>()),
    );
    expect(client.request, isNull);
  });
}
