import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:http/http.dart' as http;

class TradeFeeConfigClient {
  TradeFeeConfigClient({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;

  Future<TradeFeeConfig> load({bool? testnet}) async {
    final network = (testnet ?? AppConfig.hyperliquidTestnet)
        ? 'testnet'
        : 'mainnet';
    final response = await _client
        .get(
          _baseUri.replace(
            path: '${_baseUri.path}/trade/builder-config',
            queryParameters: {'network': network},
          ),
          headers: const {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TradeFeeConfigException('交易费配置请求失败（${response.statusCode}）');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map) {
      throw const TradeFeeConfigException('交易费配置格式无效');
    }
    return TradeFeeConfig.fromJson(
      Map<String, dynamic>.from(
        (decoded['data'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class TradeFeeConfig {
  const TradeFeeConfig({required this.hyperliquid, required this.mayan});

  const TradeFeeConfig.empty()
    : hyperliquid = const HyperliquidBuilderFeeConfig.empty(),
      mayan = const MayanFeeConfig.empty();

  final HyperliquidBuilderFeeConfig hyperliquid;
  final MayanFeeConfig mayan;

  factory TradeFeeConfig.fromJson(Map<String, dynamic> json) {
    final hyperliquid = json['hyperliquid'];
    final mayan = json['mayan'];
    return TradeFeeConfig(
      hyperliquid: HyperliquidBuilderFeeConfig.fromJson(
        hyperliquid is Map
            ? Map<String, dynamic>.from(hyperliquid.cast<String, dynamic>())
            : const {},
      ),
      mayan: MayanFeeConfig.fromJson(
        mayan is Map
            ? Map<String, dynamic>.from(mayan.cast<String, dynamic>())
            : const {},
      ),
    );
  }
}

class HyperliquidBuilderFeeConfig {
  const HyperliquidBuilderFeeConfig({
    required this.enabled,
    required this.builderAddress,
    required this.feeTenthsBps,
    required this.maxFeeRate,
  });

  const HyperliquidBuilderFeeConfig.empty()
    : enabled = false,
      builderAddress = '',
      feeTenthsBps = 0,
      maxFeeRate = '0%';

  final bool enabled;
  final String builderAddress;
  final int feeTenthsBps;
  final String maxFeeRate;

  factory HyperliquidBuilderFeeConfig.fromJson(Map<String, dynamic> json) {
    return HyperliquidBuilderFeeConfig(
      enabled: json['enabled'] == true,
      builderAddress: '${json['builderAddress'] ?? ''}'.trim(),
      feeTenthsBps: _intValue(json['feeTenthsBps']),
      maxFeeRate: '${json['maxFeeRate'] ?? '0%'}',
    );
  }

  Map<String, dynamic>? get orderBuilder {
    if (!enabled || builderAddress.isEmpty || feeTenthsBps <= 0) return null;
    return {'b': builderAddress, 'f': feeTenthsBps};
  }
}

class MayanFeeConfig {
  const MayanFeeConfig({
    required this.enabled,
    required this.referrer,
    required this.referrerBps,
    required this.referrerAddresses,
  });

  const MayanFeeConfig.empty()
    : enabled = false,
      referrer = '',
      referrerBps = 0,
      referrerAddresses = const {};

  final bool enabled;
  final String referrer;
  final int referrerBps;
  final Map<String, String> referrerAddresses;

  factory MayanFeeConfig.fromJson(Map<String, dynamic> json) {
    final rawAddresses = json['referrerAddresses'];
    final addresses = <String, String>{};
    if (rawAddresses is Map) {
      for (final entry in rawAddresses.entries) {
        final value = '${entry.value}'.trim();
        if (value.isNotEmpty) addresses['${entry.key}'] = value;
      }
    }
    return MayanFeeConfig(
      enabled: json['enabled'] == true,
      referrer: '${json['referrer'] ?? ''}'.trim(),
      referrerBps: _intValue(json['referrerBps']),
      referrerAddresses: addresses,
    );
  }

  Map<String, dynamic>? get quoteOptions {
    if (!enabled ||
        referrer.isEmpty ||
        referrerBps <= 0 ||
        referrerAddresses.isEmpty) {
      return null;
    }
    return {'referrer': referrer, 'referrerBps': referrerBps};
  }

  Map<String, dynamic>? get buildOptions {
    if (!enabled || referrerAddresses.isEmpty) return null;
    return {'referrerAddresses': referrerAddresses};
  }
}

int _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

class TradeFeeConfigException implements Exception {
  const TradeFeeConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}
