import 'dart:convert';

import 'package:aco_chat/services/wallet_chain_registry.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';
import 'package:aco_chat/services/wallet_token_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:on_chain/on_chain.dart'
    show SolAddress, Metadata, MetaDataKey, MetaDataData;

void main() {
  final endpoint = [Uri.parse('https://rpc.test')];

  test('reads EVM symbol and decimals from the contract', () async {
    const address = '0x0000000000000000000000000000000000000001';
    final reader = _reader((request) async {
      final body = jsonDecode(request.body) as Map;
      final selector = (body['params'] as List).first['data'];
      return _response({
        'result': selector == '0x95d89b41'
            ? '0x${utf8.encode('ALD').map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().padRight(64, '0')}'
            : '0x12',
      });
    });

    final metadata = await reader.load(
      network: WalletNetwork.bsc,
      address: address,
      endpoints: endpoint,
    );

    expect(metadata.symbol, 'ALD');
    expect(metadata.decimals, 18);
  });

  test('rejects an incomplete contract metadata response', () async {
    final reader = _reader((request) async => _response({'result': '0x'}));

    await expectLater(
      reader.load(
        network: WalletNetwork.bsc,
        address: '0x0000000000000000000000000000000000000001',
        endpoints: endpoint,
      ),
      throwsFormatException,
    );
  });

  test('reads TRON symbol and decimals with constant calls', () async {
    final address = WalletChainRegistry.tronUsdt.address;
    final reader = _reader((request) async {
      final body = jsonDecode(request.body) as Map;
      expect(body['contract_address'], address);
      expect(body['owner_address'], address);
      final selector = body['function_selector'];
      return _response({
        'constant_result': [selector == 'symbol()' ? _abiString('USDT') : '06'],
      });
    });

    final metadata = await reader.load(
      network: WalletNetwork.tron,
      address: address,
      endpoints: endpoint,
    );

    expect(metadata.symbol, 'USDT');
    expect(metadata.decimals, 6);
  });

  test('reads Solana symbol and decimals from mint metadata', () async {
    const mint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
    final encoded = base64Encode(
      Metadata(
        key: MetaDataKey.metadataV1,
        updateAuthority: SolAddress.defaultPubKey,
        mint: SolAddress(mint),
        data: MetaDataData(
          name: 'Test',
          symbol: 'TST',
          uri: '',
          sellerFeeBasisPoints: 0,
        ),
        primarySaleHappened: false,
        isMutable: true,
        editionNonce: null,
        tokenStandard: null,
        collection: null,
        uses: null,
        collectionDetails: null,
        programmableConfigRecord: null,
      ).toBytes(),
    );
    final reader = _reader((request) async {
      final body = jsonDecode(request.body) as Map;
      return _response(
        body['method'] == 'getTokenSupply'
            ? {
                'result': {
                  'value': {'decimals': 9},
                },
              }
            : {
                'result': {
                  'value': {
                    'data': [encoded, 'base64'],
                  },
                },
              },
      );
    });

    final metadata = await reader.load(
      network: WalletNetwork.solana,
      address: mint,
      endpoints: endpoint,
    );

    expect(metadata.symbol, 'TST');
    expect(metadata.decimals, 9);
  });
}

WalletTokenMetadataReader _reader(
  Future<http.Response> Function(http.Request) handler,
) => WalletTokenMetadataReader(
  WalletRpcClient(
    client: MockClient(handler),
    directoryBaseUri: Uri.parse('https://api.test'),
  ),
);

http.Response _response(Map<String, Object> body) =>
    http.Response(jsonEncode(body), 200);

String _abiString(String value) {
  final bytes = utf8.encode(value);
  return '${'20'.padLeft(64, '0')}${bytes.length.toRadixString(16).padLeft(64, '0')}${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join().padRight(64, '0')}';
}
