import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

class WalletBalance {
  const WalletBalance({
    required this.chain,
    required this.symbol,
    required this.isNative,
    required this.address,
    required this.decimals,
    this.balance,
    this.error,
  });

  final String chain;
  final String symbol;
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

  static const _requestTimeout = Duration(seconds: 12);
  final http.Client _client;
  final bool _ownsClient;

  Future<List<WalletBalance>> loadDefaultBalances(WalletIdentity identity) =>
      Future.wait([
        for (final chain in _chains) ...[
          _loadNativeBalance(chain, identity.address),
          _loadUsdtBalance(chain, identity.address),
        ],
      ]);

  Future<WalletBalance> _loadNativeBalance(_Chain chain, String address) =>
      _load(
        chain: chain.name,
        symbol: chain.symbol,
        isNative: true,
        address: address,
        decimals: 18,
        request: () => _nativeBalance(chain, address),
      );

  Future<WalletBalance> _loadUsdtBalance(_Chain chain, String address) => _load(
    chain: chain.name,
    symbol: 'USDT',
    isNative: false,
    address: address,
    decimals: 6,
    request: () async {
      final callData = '0x70a08231${address.substring(2).padLeft(64, '0')}';
      final body = await _postJson(chain.rpcUrl, {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'eth_call',
        'params': [
          {'to': chain.usdt, 'data': callData},
          'latest',
        ],
      });
      return _hexBalance(body);
    },
  );

  Future<BigInt> _nativeBalance(_Chain chain, String address) async {
    final body = await _postJson(chain.rpcUrl, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'eth_getBalance',
      'params': [address, 'latest'],
    });
    return _hexBalance(body);
  }

  static const _chains = [
    _Chain(
      'Ethereum',
      'ETH',
      'https://ethereum-rpc.publicnode.com',
      '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    ),
  ];

  BigInt _hexBalance(Map<String, dynamic> body) {
    final result = body['result'];
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
    required bool isNative,
    required String address,
    required int decimals,
    required Future<BigInt> Function() request,
  }) async {
    try {
      return WalletBalance(
        chain: chain,
        symbol: symbol,
        isNative: isNative,
        address: address,
        decimals: decimals,
        balance: await request(),
      );
    } catch (error) {
      return WalletBalance(
        chain: chain,
        symbol: symbol,
        isNative: isNative,
        address: address,
        decimals: decimals,
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
  const _Chain(this.name, this.symbol, this.rpcUrl, this.usdt);
  final String name, symbol, rpcUrl, usdt;
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
