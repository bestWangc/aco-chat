import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

enum WalletNetwork { ethereum, bsc, polygon, tron, solana, base }

class WalletBalance {
  const WalletBalance({
    required this.chain,
    required this.symbol,
    required this.assetName,
    required this.isNative,
    required this.address,
    required this.decimals,
    this.balance,
    this.error,
  });

  final String chain;
  final String symbol;
  final String assetName;
  final bool isNative;
  final String address;
  final int decimals;
  final BigInt? balance;
  final Object? error;

  bool get isAvailable => balance != null;
}

/// Fetches native-token balances directly from public JSON-RPC nodes.
///
/// Token discovery and fiat valuation need an indexer or price feed, so this
/// intentionally reports only balances that are authoritative on-chain.
class WalletPortfolioService {
  WalletPortfolioService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _requestTimeout = Duration(seconds: 5);
  final http.Client _client;
  final bool _ownsClient;

  Future<List<WalletBalance>> loadBalances({
    required WalletNetwork network,
    required WalletIdentity identity,
    required Map<String, String> derivedAddresses,
  }) {
    final chain = _chains[network]!;
    if (chain.isEvm) {
      return Future.wait([
        _loadNativeBalance(chain, identity.address),
        if (chain.usdt != null) _loadUsdtBalance(chain, identity.address),
      ]);
    }
    final address = derivedAddresses[chain.addressKey];
    if (address == null) {
      return Future.value([
        WalletBalance(
          chain: chain.name,
          symbol: chain.symbol,
          assetName: chain.nativeAssetName,
          isNative: true,
          address: '',
          decimals: chain.decimals,
          balance: BigInt.zero,
        ),
      ]);
    }
    return Future.wait([_loadNonEvmBalance(chain, address)]);
  }

  Future<WalletBalance> _loadNativeBalance(_Chain chain, String address) =>
      _load(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: address,
        decimals: 18,
        request: () => _nativeBalance(chain, address),
      );

  Future<WalletBalance> _loadUsdtBalance(_Chain chain, String address) {
    final usdt = chain.usdt!;
    return _load(
      chain: chain.name,
      symbol: 'USDT',
      assetName: usdt.name,
      isNative: false,
      address: address,
      decimals: usdt.decimals,
      request: () async {
        final callData = '0x70a08231${address.substring(2).padLeft(64, '0')}';
        final body = await _postJson(chain.rpcUrl, {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'eth_call',
          'params': [
            {'to': usdt.address, 'data': callData},
            'latest',
          ],
        });
        return _hexBalance(body);
      },
    );
  }

  Future<BigInt> _nativeBalance(_Chain chain, String address) async {
    final body = await _postJson(chain.rpcUrl, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'eth_getBalance',
      'params': [address, 'latest'],
    });
    return _hexBalance(body);
  }

  Future<WalletBalance> _loadNonEvmBalance(_Chain chain, String address) =>
      _load(
        chain: chain.name,
        symbol: chain.symbol,
        assetName: chain.nativeAssetName,
        isNative: true,
        address: address,
        decimals: chain.decimals,
        request: () => switch (chain.network) {
          WalletNetwork.tron => _tronBalance(chain, address),
          WalletNetwork.solana => _solanaBalance(chain, address),
          _ => throw StateError('Unsupported non-EVM network'),
        },
      );

  Future<BigInt> _tronBalance(_Chain chain, String address) async {
    final body = await _postJson(chain.rpcUrl, {
      'address': address,
      'visible': true,
    });
    return BigInt.from((body['balance'] as num?) ?? 0);
  }

  Future<BigInt> _solanaBalance(_Chain chain, String address) async {
    final body = await _postJson(chain.rpcUrl, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'getBalance',
      'params': [address],
    });
    final result = body['result'];
    if (result is! Map || result['value'] is! num) {
      throw const FormatException('Missing RPC result');
    }
    return BigInt.from(result['value'] as num);
  }

  static const _chains = <WalletNetwork, _Chain>{
    WalletNetwork.ethereum: _Chain.evm(
      WalletNetwork.ethereum,
      'Ethereum',
      'ETH',
      'Ethereum',
      'https://ethereum-rpc.publicnode.com',
      _Token('0xdAC17F958D2ee523a2206206994597C13D831ec7', 6, 'Tether USD'),
    ),
    WalletNetwork.bsc: _Chain.evm(
      WalletNetwork.bsc,
      'BNB Smart Chain',
      'BNB',
      'BNB',
      'https://bsc-rpc.publicnode.com',
      _Token('0x55d398326f99059fF775485246999027B3197955', 18, 'Tether USD'),
    ),
    WalletNetwork.polygon: _Chain.evm(
      WalletNetwork.polygon,
      'Polygon',
      'POL',
      'Polygon Ecosystem Token',
      'https://polygon-bor-rpc.publicnode.com',
      _Token('0xc2132D05D31c914a87C6611C10748AEb04B58e8F', 6, 'Tether USD'),
    ),
    WalletNetwork.base: _Chain.evm(
      WalletNetwork.base,
      'Base',
      'ETH',
      'Ethereum',
      'https://base-rpc.publicnode.com',
      _Token('0xfde4c96c8593536e31f229ea8f37b2ada2699bb2', 6, 'Tether USD'),
    ),
    WalletNetwork.tron: _Chain.nonEvm(
      WalletNetwork.tron,
      'TRON',
      'TRX',
      'TRON',
      'https://api.trongrid.io/wallet/getaccount',
      'tron',
      6,
    ),
    WalletNetwork.solana: _Chain.nonEvm(
      WalletNetwork.solana,
      'Solana',
      'SOL',
      'Solana',
      'https://api.mainnet-beta.solana.com',
      'solana',
      9,
    ),
  };

  BigInt _hexBalance(Map<String, dynamic> body) {
    final result = body['result'];
    if (result == '0x') return BigInt.zero;
    if (result is! String || !result.startsWith('0x')) {
      throw const FormatException('Missing RPC result');
    }
    return BigInt.parse(result.substring(2), radix: 16);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<WalletBalance> _load({
    required String chain,
    required String symbol,
    required String assetName,
    required bool isNative,
    required String address,
    required int decimals,
    required Future<BigInt> Function() request,
  }) async {
    try {
      return WalletBalance(
        chain: chain,
        symbol: symbol,
        assetName: assetName,
        isNative: isNative,
        address: address,
        decimals: decimals,
        balance: await request(),
      );
    } catch (error) {
      return WalletBalance(
        chain: chain,
        symbol: symbol,
        assetName: assetName,
        isNative: isNative,
        address: address,
        decimals: decimals,
        balance: BigInt.zero,
        error: error,
      );
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, Object> request,
  ) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('RPC request failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['error'] != null) {
      throw const FormatException('Invalid RPC response');
    }
    return body;
  }
}

class _Chain {
  const _Chain.evm(
    this.network,
    this.name,
    this.symbol,
    this.nativeAssetName,
    this.rpcUrl,
    this.usdt,
  ) : addressKey = null,
      decimals = 18;

  const _Chain.nonEvm(
    this.network,
    this.name,
    this.symbol,
    this.nativeAssetName,
    this.rpcUrl,
    this.addressKey,
    this.decimals,
  ) : usdt = null;

  final String name;
  final String symbol;
  final String nativeAssetName;
  final String rpcUrl;
  final _Token? usdt;
  final WalletNetwork network;
  final String? addressKey;
  final int decimals;

  bool get isEvm => addressKey == null;
}

class _Token {
  const _Token(this.address, this.decimals, this.name);

  final String address;
  final int decimals;
  final String name;
}

String formatChainAmount(BigInt amount, {required int decimals}) {
  final whole = amount ~/ BigInt.from(10).pow(decimals);
  final fraction = (amount % BigInt.from(10).pow(decimals))
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final visibleFraction = fraction.length > 6
      ? fraction.substring(0, 6)
      : fraction;
  return fraction.isEmpty ? whole.toString() : '$whole.$visibleFraction';
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
}
