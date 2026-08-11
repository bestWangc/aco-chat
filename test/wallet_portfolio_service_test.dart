import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('loads balances from each supported network', () async {
    final serviceClient = _RpcClient();
    final service = WalletPortfolioService(client: serviceClient);
    const identity = WalletIdentity(
      address: '0x0000000000000000000000000000000000000001',
    );

    final loads = await Future.wait([
      for (final network in WalletNetwork.values)
        service.loadBalances(
          network: network,
          identity: identity,
          derivedAddresses: const {
            'tron': 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
            'solana': 'GjJyeC1r2RgkuoCWMyPYkCWSGSGLcz266EaAkLA27AhL',
          },
        ),
    ]);
    final balances = loads.expand((balances) => balances).toList();

    expect(balances, hasLength(10));
    expect(balances.every((balance) => balance.isAvailable), isTrue);
    expect(balances.where((balance) => balance.symbol == 'BNB'), hasLength(1));
    expect(balances.where((balance) => balance.symbol == 'TRX'), hasLength(1));
    expect(balances.where((balance) => balance.symbol == 'SOL'), hasLength(1));
    final usdt = balances.where((balance) => balance.symbol == 'USDT').toList();
    expect(usdt, hasLength(4));
    expect(
      usdt
          .singleWhere((balance) => balance.chain == 'BNB Smart Chain')
          .decimals,
      18,
    );
    expect(
      usdt
          .where((balance) => balance.chain != 'BNB Smart Chain')
          .map((balance) => balance.decimals),
      everyElement(6),
    );
    expect(
      serviceClient.hosts,
      containsAll([
        'ethereum-rpc.publicnode.com',
        'bsc-rpc.publicnode.com',
        'polygon-bor-rpc.publicnode.com',
        'base-rpc.publicnode.com',
        'api.trongrid.io',
        'api.mainnet-beta.solana.com',
      ]),
    );
    expect(
      serviceClient.requestBodies['api.trongrid.io']?.single['address'],
      'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
    );
    expect(
      serviceClient
          .requestBodies['api.mainnet-beta.solana.com']
          ?.single['params'],
      contains('GjJyeC1r2RgkuoCWMyPYkCWSGSGLcz266EaAkLA27AhL'),
    );
    expect(
      serviceClient.requestBodies['polygon-bor-rpc.publicnode.com']?.map(
        _erc20ContractAddress,
      ),
      contains('0xc2132D05D31c914a87C6611C10748AEb04B58e8F'),
    );
    expect(
      serviceClient.requestBodies['base-rpc.publicnode.com']?.map(
        _erc20ContractAddress,
      ),
      contains('0xfde4c96c8593536e31f229ea8f37b2ada2699bb2'),
    );
  });

  test('uses zero when an RPC request fails', () async {
    final service = WalletPortfolioService(client: _FailingRpcClient());
    const identity = WalletIdentity(
      address: '0x0000000000000000000000000000000000000001',
    );

    final balances = await service.loadBalances(
      network: WalletNetwork.polygon,
      identity: identity,
      derivedAddresses: const {},
    );

    expect(balances, hasLength(2));
    expect(
      balances.map((balance) => balance.balance),
      everyElement(BigInt.zero),
    );
  });

  test('uses zero until a non-EVM address has been derived', () async {
    final service = WalletPortfolioService(client: _RpcClient());
    const identity = WalletIdentity(
      address: '0x0000000000000000000000000000000000000001',
    );

    final balances = await service.loadBalances(
      network: WalletNetwork.tron,
      identity: identity,
      derivedAddresses: const {},
    );

    expect(balances.single.symbol, 'TRX');
    expect(balances.single.balance, BigInt.zero);
  });
}

String? _erc20ContractAddress(Map body) {
  final params = body['params'];
  if (params is! List || params.isEmpty || params.first is! Map) return null;
  return (params.first as Map)['to'] as String?;
}

class _RpcClient extends http.BaseClient {
  final hosts = <String>[];
  final requestBodies = <String, List<Map>>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonDecode(await request.finalize().bytesToString()) as Map;
    hosts.add(request.url.host);
    requestBodies.putIfAbsent(request.url.host, () => []).add(body);
    final response = switch (request.url.host) {
      'api.trongrid.io' => {'balance': 3},
      'api.mainnet-beta.solana.com' => {
        'result': {'value': 2},
      },
      _ when body['method'] == 'eth_call' => {'result': '0x2'},
      _ => {'result': '0x1'},
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(response))),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FailingRpcClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(const []), 503);
}
