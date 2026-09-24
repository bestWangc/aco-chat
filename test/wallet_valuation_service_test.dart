import 'dart:convert';

import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_valuation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('calculates USD value for native and token balances', () async {
    final client = _PriceClient();
    final service = WalletValuationService(
      client: client,
      baseUri: Uri.parse('https://api.aco.chat/api/v1'),
    );
    final balances = [
      WalletBalance(
        chain: 'BNB Smart Chain',
        symbol: 'BNB',
        assetName: 'BNB',
        isNative: true,
        address: '',
        decimals: 18,
        balance: BigInt.from(3) * BigInt.from(10).pow(15),
      ),
      WalletBalance(
        chain: 'BNB Smart Chain',
        symbol: 'USDT',
        assetName: 'Tether USD',
        isNative: false,
        address: '',
        decimals: 18,
        tokenAddress: '0x55d398326f99059fF775485246999027B3197955',
        balance: BigInt.from(2) * BigInt.from(10).pow(18),
      ),
    ];

    final values = await service.assetUsdValues(balances);

    expect(values[balances[0].id], closeTo(1.8, 0.000001));
    expect(values[balances[1].id], closeTo(2, 0.000001));
    expect(client.requestedUris.map((uri) => uri.path), [
      '/api/v1/dex/tokens/bsc/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      '/api/v1/dex/tokens/bsc/0x55d398326f99059fF775485246999027B3197955',
    ]);
    service.dispose();
  });
}

class _PriceClient extends http.BaseClient {
  final requestedUris = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUris.add(request.url);
    final token = request.url.pathSegments.last.toLowerCase();
    final price = token.startsWith('0xbb4c')
        ? '600'
        : token.startsWith('0x55d3')
        ? '1'
        : null;
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            price == null
                ? <Map<String, String>>[]
                : [
                    {'chainId': 'bsc', 'priceUsd': price},
                  ],
          ),
        ),
      ),
      200,
      request: request,
    );
  }
}
