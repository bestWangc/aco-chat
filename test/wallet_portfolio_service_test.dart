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

    expect(balances, hasLength(13));
    expect(balances.every((balance) => balance.isAvailable), isTrue);
    expect(balances.where((balance) => balance.symbol == 'BNB'), hasLength(1));
    expect(balances.where((balance) => balance.symbol == 'TRX'), hasLength(1));
    expect(balances.where((balance) => balance.symbol == 'SOL'), hasLength(1));
    final usdt = balances.where((balance) => balance.symbol == 'USDT').toList();
    expect(usdt, hasLength(6));
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
        'solana-rpc.publicnode.com',
      ]),
    );
    expect(
      serviceClient.requestBodies['api.trongrid.io']?.map(
        (body) => body['address'],
      ),
      everyElement('TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH'),
    );
    final tronUSDT = balances.singleWhere(
      (balance) => balance.chain == 'TRON' && balance.symbol == 'USDT',
    );
    expect(tronUSDT.balance, BigInt.from(4));
    expect(tronUSDT.decimals, 6);
    expect(
      serviceClient.requestBodies['solana-rpc.publicnode.com']?.map(
        (body) => body['method'],
      ),
      containsAll(['getBalance', 'getTokenAccountsByOwner']),
    );
    expect(
      serviceClient.requestBodies['solana-rpc.publicnode.com']
          ?.where((body) => body['method'] == 'getTokenAccountsByOwner')
          .map((body) => body['params'].first),
      everyElement('GjJyeC1r2RgkuoCWMyPYkCWSGSGLcz266EaAkLA27AhL'),
    );
    final solanaUSDC = balances.singleWhere(
      (balance) => balance.symbol == 'USDC',
    );
    expect(solanaUSDC.balance, BigInt.from(3));
    expect(solanaUSDC.decimals, 6);
    final solanaUSDT = balances.singleWhere(
      (balance) => balance.chain == 'Solana' && balance.symbol == 'USDT',
    );
    expect(solanaUSDT.balance, BigInt.from(5));
    expect(solanaUSDT.decimals, 6);
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

    expect(balances.map((balance) => balance.symbol), ['TRX', 'USDT']);
    expect(
      balances.map((balance) => balance.balance),
      everyElement(BigInt.zero),
    );
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
      'api.trongrid.io' => {
        'balance': 3,
        'trc20': [
          {'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t': '4'},
        ],
      },
      'solana-rpc.publicnode.com' when body['method'] == 'getBalance' => {
        'result': {'value': 2},
      },
      'solana-rpc.publicnode.com'
          when body['method'] == 'getTokenAccountsByOwner' =>
        {
          'result': {
            'value':
                body['params'][1]['programId'] ==
                    'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'
                ? [
                    for (final token in const [
                      ('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', '3'),
                      ('Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', '5'),
                    ])
                      {
                        'account': {
                          'data': {
                            'parsed': {
                              'info': {
                                'mint': token.$1,
                                'tokenAmount': {
                                  'amount': token.$2,
                                  'decimals': 6,
                                },
                              },
                            },
                          },
                        },
                      },
                  ]
                : [],
          },
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
