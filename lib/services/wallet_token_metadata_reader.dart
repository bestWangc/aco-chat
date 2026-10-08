import 'dart:convert';

import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';
import 'package:on_chain/on_chain.dart'
    show
        TronAddress,
        SolAddress,
        MetaplexTokenMetaDataProgramUtils,
        Metadata,
        SPLTokenMetaDataAccount;

class WalletTokenMetadataReader {
  const WalletTokenMetadataReader(this.rpc);

  final WalletRpcClient rpc;

  static bool validAddress(WalletNetwork network, String address) {
    try {
      if (network == WalletNetwork.tron) {
        TronAddress(address);
      } else if (network == WalletNetwork.solana) {
        SolAddress(address);
      } else {
        return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<({String symbol, int decimals})> load({
    required WalletNetwork network,
    required String address,
    required List<Uri> endpoints,
    String? ownerAddress,
  }) async {
    if (!validAddress(network, address)) {
      throw const FormatException('无效的代币地址');
    }
    final (symbol, decimals) = switch (network) {
      WalletNetwork.tron => await _tronMetadata(
        endpoints,
        address,
        ownerAddress ?? address,
      ),
      WalletNetwork.solana => await _solanaMetadata(endpoints, address),
      _ => await _evmMetadata(endpoints, address),
    };
    final normalizedSymbol = symbol?.replaceAll('\u0000', '').trim();
    if (normalizedSymbol == null ||
        normalizedSymbol.isEmpty ||
        decimals == null ||
        decimals < 0 ||
        decimals > 36) {
      throw const FormatException('代币信息无效');
    }
    return (symbol: normalizedSymbol, decimals: decimals);
  }

  Future<(String?, int?)> _evmMetadata(
    List<Uri> endpoints,
    String address,
  ) async {
    Future<String?> call(String selector, int id) async {
      final body = await rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': id,
        'method': 'eth_call',
        'params': [
          {'to': address, 'data': selector},
          'latest',
        ],
      });
      return body['result'] as String?;
    }

    final symbol = await call('0x95d89b41', 1);
    final decimals = await call('0x313ce567', 2);
    return (_decodeAbiString(symbol), _decodeHexInt(decimals));
  }

  Future<(String?, int?)> _tronMetadata(
    List<Uri> endpoints,
    String address,
    String owner,
  ) async {
    Future<String?> call(String selector) async {
      final body = await rpc
          .postJsonPath(endpoints, 'wallet/triggerconstantcontract', {
            'owner_address': owner,
            'contract_address': address,
            'function_selector': selector,
            'visible': true,
          });
      final results = body['constant_result'];
      if (results is! List || results.isEmpty || results.first is! String) {
        return null;
      }
      final result = results.first as String;
      return result.startsWith('0x') ? result : '0x$result';
    }

    final symbol = await call('symbol()');
    final decimals = await call('decimals()');
    return (_decodeAbiString(symbol), _decodeHexInt(decimals));
  }

  Future<(String?, int?)> _solanaMetadata(
    List<Uri> endpoints,
    String mint,
  ) async {
    final supply = await rpc.postJson(endpoints, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'getTokenSupply',
      'params': [mint],
    });
    final decimals = (supply['result']?['value']?['decimals'] as num?)?.toInt();
    final metadataAddress = MetaplexTokenMetaDataProgramUtils.findMetadataPda(
      mint: SolAddress(mint),
    ).address;
    final account = await rpc.postJson(endpoints, {
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'getAccountInfo',
      'params': [
        metadataAddress.toString(),
        {'encoding': 'base64'},
      ],
    });
    final data = account['result']?['value']?['data'];
    final encoded = data is List && data.isNotEmpty ? data.first : null;
    String? symbol;
    if (encoded is String) {
      try {
        symbol = Metadata.fromBuffer(
          base64Decode(encoded),
        ).data.symbol.replaceAll('\u0000', '').trim();
      } catch (_) {
        // Token-2022 may store metadata on the mint instead.
      }
    }
    if (symbol == null || symbol.isEmpty) {
      final mintAccount = await rpc.postJson(endpoints, {
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'getAccountInfo',
        'params': [
          mint,
          {'encoding': 'base64'},
        ],
      });
      final mintData = mintAccount['result']?['value']?['data'];
      final mintEncoded = mintData is List && mintData.isNotEmpty
          ? mintData.first
          : null;
      if (mintEncoded is String) {
        final metadata = SPLTokenMetaDataAccount.fromAccountDataBytes(
          base64Decode(mintEncoded),
        );
        if (metadata.mint == SolAddress(mint)) symbol = metadata.symbol;
      }
    }
    return (symbol, decimals);
  }

  int? _decodeHexInt(String? value) => value == null || !value.startsWith('0x')
      ? null
      : int.tryParse(value.substring(2), radix: 16);

  String? _decodeAbiString(String? value) {
    if (value == null || !value.startsWith('0x')) return null;
    final hex = value.substring(2);
    if (hex.length == 64) {
      final bytes = [
        for (var i = 0; i < 64; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
      return utf8.decode(bytes.takeWhile((byte) => byte != 0).toList());
    }
    if (hex.length < 128) return null;
    final length = int.tryParse(hex.substring(64, 128), radix: 16);
    if (length == null || length <= 0 || hex.length < 128 + length * 2) {
      return null;
    }
    final bytes = <int>[];
    for (var i = 0; i < length; i++) {
      bytes.add(int.parse(hex.substring(128 + i * 2, 130 + i * 2), radix: 16));
    }
    return utf8.decode(bytes);
  }
}
