import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WalletHotToken {
  const WalletHotToken({
    required this.symbol,
    required this.name,
    required this.address,
    required this.decimals,
  });

  final String symbol;
  final String name;
  final String address;
  final int decimals;

  factory WalletHotToken.fromJson(Map<String, dynamic> json) => WalletHotToken(
    symbol: json['symbol'] as String? ?? '',
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    decimals: (json['decimals'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'address': address,
    'decimals': decimals,
  };
}

class WalletHotTokenService {
  WalletHotTokenService({http.Client? client})
    : _client = client ?? http.Client();

  static const _cachePrefix = 'wallet.hot-tokens.v2.';
  final http.Client _client;

  Future<List<WalletHotToken>> load(String chain) async {
    final preferences = await SharedPreferences.getInstance();
    final cacheKey = '$_cachePrefix$chain.${_today()}';
    final cached = preferences.getString(cacheKey);
    if (cached != null) {
      debugPrint('[WalletHotTokens] cache hit chain=$chain key=$cacheKey');
      return _decode(cached);
    }

    try {
      final tokens = await _request(chain);
      await preferences.setString(
        cacheKey,
        jsonEncode(tokens.map((token) => token.toJson()).toList()),
      );
      return tokens;
    } catch (error) {
      // The hot-token area is optional; an unavailable API is an empty list.
      debugPrint('[WalletHotTokens] request failed chain=$chain error=$error');
      return const [];
    }
  }

  Future<List<WalletHotToken>> _request(String chain) async {
    final base = const AppConfig().apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$base/wallet/tokens/hot',
    ).replace(queryParameters: {'chain': chain});
    debugPrint(
      '[WalletHotTokens] GET $uri params={chain: $chain} headers={x-app-version: ${AppConfig.appVersion}}',
    );
    final response = await _client
        .get(uri, headers: {'x-app-version': AppConfig.appVersion})
        .timeout(const Duration(seconds: 10));
    debugPrint(
      '[WalletHotTokens] response status=${response.statusCode} body=${response.body}',
    );
    if (response.statusCode != 200) {
      throw StateError('hot token request failed');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawTokens = body['tokens'];
    if (rawTokens is! List) return const [];
    final tokens = rawTokens
        .whereType<Map<String, dynamic>>()
        .map(WalletHotToken.fromJson)
        .where((token) => token.symbol.isNotEmpty)
        .toList(growable: false);
    debugPrint('[WalletHotTokens] parsed tokens=${tokens.length}');
    return tokens;
  }

  List<WalletHotToken> _decode(String encoded) {
    try {
      final value = jsonDecode(encoded);
      if (value is! List) return const [];
      return value
          .whereType<Map<String, dynamic>>()
          .map(WalletHotToken.fromJson)
          .where((token) => token.symbol.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
