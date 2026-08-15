import 'dart:convert';

import 'package:aco_chat/services/wallet_portfolio_service.dart';
import 'package:http/http.dart' as http;

class WalletValuationService {
  WalletValuationService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static final _endpoint = Uri.parse(
    'https://api.dexscreener.com/latest/dex/tokens/',
  );
  final http.Client _client;
  final bool _ownsClient;

  Future<double?> totalUsd(List<WalletBalance> balances) async {
    var total = 0.0;
    var hasQuote = false;
    for (final balance in balances) {
      final amount = balance.balance;
      if (amount == null || amount == BigInt.zero) continue;
      final address = balance.tokenAddress ?? _wrappedNative(balance.chain);
      if (address == null) continue;
      final price = await _priceUsd(balance.chain, address);
      if (price == null) continue;
      total += _toDecimal(amount, balance.decimals) * price;
      hasQuote = true;
    }
    return hasQuote ? total : null;
  }

  Future<double?> _priceUsd(String chain, String token) async {
    try {
      final response = await _client
          .get(_endpoint.resolve(token))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final pairs =
          (jsonDecode(response.body) as Map<String, dynamic>)['pairs'];
      if (pairs is! List) return null;
      final chainId = _chainId(chain);
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

  String? _chainId(String chain) => switch (chain.toLowerCase()) {
    'ethereum' => 'ethereum',
    'bsc' => 'bsc',
    'polygon' => 'polygon',
    'base' => 'base',
    'tron' => 'tron',
    'solana' => 'solana',
    _ => null,
  };

  String? _wrappedNative(String chain) => switch (chain.toLowerCase()) {
    'ethereum' => '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    'bsc' => '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    'polygon' => '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
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
