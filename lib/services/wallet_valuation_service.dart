import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:http/http.dart' as http;

class WalletValuationService {
  WalletValuationService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl),
      _ownsClient = client == null;

  final http.Client _client;
  final Uri _baseUri;
  final bool _ownsClient;

  Future<double?> totalUsd(List<WalletBalance> balances) async {
    final values = await assetUsdValues(balances);
    if (values.isEmpty) return null;
    return values.values.fold<double>(0, (total, value) => total + value);
  }

  Future<Map<String, double>> assetUsdValues(
    List<WalletBalance> balances,
  ) async {
    final candidates = balances.where((balance) {
      final amount = balance.balance;
      if (amount == null || amount == BigInt.zero) return false;
      final address = balance.tokenAddress ?? _wrappedNative(balance.chain);
      return address != null && _chainId(balance.chain) != null;
    }).toList();
    final prices = <String, Future<double?>>{};
    for (final balance in candidates) {
      final address = balance.tokenAddress ?? _wrappedNative(balance.chain)!;
      final key = '${balance.chain.toLowerCase()}:$address';
      prices.putIfAbsent(key, () => _priceUsd(balance.chain, address));
    }

    final values = <String, double>{};
    for (final balance in candidates) {
      final address = balance.tokenAddress ?? _wrappedNative(balance.chain)!;
      final key = '${balance.chain.toLowerCase()}:$address';
      final price = await prices[key]!;
      if (price != null) {
        values[balance.id] =
            _toDecimal(balance.balance!, balance.decimals) * price;
      }
    }
    return values;
  }

  Future<double?> _priceUsd(String chain, String token) async {
    try {
      final chainId = _chainId(chain);
      if (chainId == null) return null;
      final response = await _client
          .get(_apiUri('dex/tokens/$chainId/${Uri.encodeComponent(token)}'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      final pairs = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['pairs']
          : null;
      if (pairs is! List) return null;
      for (final item in pairs) {
        if (item is! Map<String, dynamic> || item['chainId'] != chainId) {
          continue;
        }
        final price = double.tryParse('${item['priceUsd']}');
        if (price != null && price.isFinite) return price;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Uri _apiUri(String path) {
    final basePath = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    return _baseUri.replace(path: '$basePath/$path');
  }

  String? _chainId(String chain) => switch (chain.toLowerCase()) {
    'ethereum' => 'ethereum',
    'bsc' || 'bnb smart chain' => 'bsc',
    'polygon' => 'polygon',
    'arbitrum one' => 'arbitrum',
    'arbitrum' => 'arbitrum',
    'optimism' => 'optimism',
    'base' => 'base',
    'tron' => 'tron',
    'solana' => 'solana',
    _ => null,
  };

  String? _wrappedNative(String chain) => switch (chain.toLowerCase()) {
    'ethereum' => '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    'bsc' || 'bnb smart chain' => '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    'polygon' => '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
    'arbitrum one' => '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
    'arbitrum' => '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
    'optimism' => '0x4200000000000000000000000000000000000006',
    'base' => '0x4200000000000000000000000000000000000006',
    'tron' => 'TNUC9Qb1rRpS5CbWa4C6uM7iKxR7Y4wP5M',
    'solana' => 'So11111111111111111111111111111111111111112',
    _ => null,
  };

  double _toDecimal(BigInt value, int decimals) {
    final text = value.toString().padLeft(decimals + 1, '0');
    final split = text.length - decimals;
    return double.tryParse(
          '${text.substring(0, split)}.${text.substring(split)}',
        ) ??
        0;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
