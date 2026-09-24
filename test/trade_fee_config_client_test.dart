import 'dart:convert';

import 'package:aco_chat/services/trade_fee_config_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _ConfigClient extends http.BaseClient {
  _ConfigClient(this.response);

  final Map<String, dynamic> response;
  Uri? requestUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestUri = request.url;
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('loads builder and Mayan fee configuration from the API', () async {
    final client = _ConfigClient({
      'data': {
        'hyperliquid': {
          'enabled': true,
          'builderAddress': '0xBuilder',
          'feeTenthsBps': 10,
          'maxFeeRate': '0.01%',
        },
        'mayan': {
          'enabled': true,
          'referrer': 'SolanaReferrer',
          'referrerBps': 5,
          'referrerAddresses': {'evm': '0xFee', 'solana': 'SolanaFee'},
        },
      },
    });
    final config = TradeFeeConfigClient(
      client: client,
      baseUri: Uri.parse('https://api.example/api/v1'),
    );

    final result = await config.load();

    expect(client.requestUri?.path, '/api/v1/trade/builder-config');
    expect(client.requestUri?.queryParameters['network'], 'mainnet');
    expect(result.hyperliquid.orderBuilder, {'b': '0xBuilder', 'f': 10});
    expect(result.hyperliquid.maxFeeRate, '0.01%');
    expect(result.mayan.quoteOptions, {
      'referrer': 'SolanaReferrer',
      'referrerBps': 5,
    });
    expect(result.mayan.buildOptions, {
      'referrerAddresses': {'evm': '0xFee', 'solana': 'SolanaFee'},
    });
  });

  test('treats disabled fee sections as absent transaction options', () {
    final config = TradeFeeConfig.fromJson({
      'hyperliquid': {'enabled': false},
      'mayan': {'enabled': false},
    });

    expect(config.hyperliquid.orderBuilder, isNull);
    expect(config.mayan.quoteOptions, isNull);
    expect(config.mayan.buildOptions, isNull);
  });
}
