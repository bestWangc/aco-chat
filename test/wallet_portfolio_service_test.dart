import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('loads the default ETH and USDT balances', () async {
    final service = WalletPortfolioService(client: _RpcClient());
    const identity = WalletIdentity(
      address: '0x0000000000000000000000000000000000000001',
    );

    final balances = await service.loadDefaultBalances(identity);

    expect(balances, hasLength(2));
    expect(balances.every((balance) => balance.isAvailable), isTrue);
    expect(balances.first.symbol, 'ETH');
    expect(balances.first.balance, BigInt.one);
    expect(balances.where((balance) => balance.symbol == 'USDT'), hasLength(1));
  });
}

class _RpcClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonDecode(await request.finalize().bytesToString()) as Map;
    final response = body['method'] == 'eth_call'
        ? {'result': '0x2'}
        : {'result': '0x1'};
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
