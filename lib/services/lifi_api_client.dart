import 'dart:convert';
import 'dart:developer' as developer;

import 'package:aco_chat/services/wallet_chain_registry.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:http/http.dart' as http;

/// Minimal LI.FI REST client used by the in-app swap flow.
///
/// The quote response contains the complete transactionRequest for the first
/// step. Callers must still perform ERC-20 allowance checks and show the
/// transaction confirmation UI before signing or broadcasting it.
class LifiApiClient {
  LifiApiClient({http.Client? client, Uri? baseUri})
    : baseUri = baseUri ?? Uri.parse('https://li.quest/v1'),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final Uri baseUri;
  final bool _ownsClient;

  Future<LifiQuote> quote({
    required WalletNetwork fromNetwork,
    required String fromToken,
    required WalletNetwork toNetwork,
    required String toToken,
    required String fromAmount,
    required int fromDecimals,
    required String fromAddress,
    String? fromTokenAddress,
    String? toTokenAddress,
    double slippage = .02,
  }) async {
    final fromChain = chainId(fromNetwork);
    final toChain = chainId(toNetwork);
    final uri = baseUri.replace(
      path: '${baseUri.path}/quote',
      queryParameters: {
        'fromChain': '$fromChain',
        'toChain': '$toChain',
        'fromToken': fromTokenAddress ?? tokenAddress(fromNetwork, fromToken),
        'toToken': toTokenAddress ?? tokenAddress(toNetwork, toToken),
        'fromAmount': toBaseUnits(fromAmount, fromDecimals),
        'fromAddress': fromAddress,
        'slippage': slippage.toString(),
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(response);
      developer.log(
        'quote failed status=${response.statusCode} uri=$uri reason=$message',
        name: 'LI.FI',
      );
      throw LifiException('LI.FI 报价失败（${response.statusCode}）：$message');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const LifiException('LI.FI 返回数据格式无效');
    }
    return LifiQuote.fromJson(body);
  }

  Future<LifiTransferStatus> status({
    required String txHash,
    required WalletNetwork fromNetwork,
    required WalletNetwork toNetwork,
  }) async {
    final uri = baseUri.replace(
      path: '${baseUri.path}/status',
      queryParameters: {
        'txHash': txHash,
        'fromChain': '${chainId(fromNetwork)}',
        'toChain': '${chainId(toNetwork)}',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LifiException('LI.FI 状态查询失败（${response.statusCode}）');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const LifiException('LI.FI 状态数据格式无效');
    }
    return LifiTransferStatus.fromJson(body);
  }

  Future<List<LifiToken>> tokens(WalletNetwork network) async {
    final response = await _client
        .get(
          baseUri.replace(
            path: '${baseUri.path}/tokens',
            queryParameters: {'chains': '${chainId(network)}'},
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LifiException('LI.FI 代币列表获取失败（${response.statusCode}）');
    }
    final body = jsonDecode(response.body);
    final raw = body is Map<String, dynamic> ? body['tokens'] : body;
    final values = <dynamic>[];
    if (raw is Map) {
      for (final value in raw.values) {
        if (value is List) values.addAll(value);
      }
    } else if (raw is List) {
      values.addAll(raw);
    }
    return values
        .whereType<Map>()
        .map(LifiToken.fromJson)
        .where((token) => token.address.isNotEmpty && token.symbol.isNotEmpty)
        .toList();
  }

  static int chainId(WalletNetwork network) => switch (network) {
    WalletNetwork.ethereum => 1,
    WalletNetwork.bsc => 56,
    WalletNetwork.polygon => 137,
    WalletNetwork.arbitrum => 42161,
    WalletNetwork.optimism => 10,
    WalletNetwork.base => 8453,
    WalletNetwork.tron => 728126428,
    WalletNetwork.solana => 1151111081099710,
  };

  static String tokenAddress(WalletNetwork network, String symbol) {
    final normalized = symbol.toUpperCase();
    if (normalized == _nativeSymbol(network)) {
      return switch (network) {
        WalletNetwork.solana => '11111111111111111111111111111111',
        _ => '0x0000000000000000000000000000000000000000',
      };
    }
    if (network == WalletNetwork.tron) {
      return normalized == 'USDC'
          ? WalletChainRegistry.tronUsdc.address
          : WalletChainRegistry.tronUsdt.address;
    }
    if (network == WalletNetwork.solana) {
      return normalized == 'USDC'
          ? WalletChainRegistry.solanaUsdc.address
          : WalletChainRegistry.solanaUsdt.address;
    }
    final definition = WalletChainRegistry.chains[network];
    final token = normalized == 'USDC' ? definition?.usdc : definition?.usdt;
    if (token == null) {
      throw LifiException('$normalized 暂不支持在 ${network.name} 上兑换');
    }
    return token.address;
  }

  static String _nativeSymbol(WalletNetwork network) => switch (network) {
    WalletNetwork.ethereum ||
    WalletNetwork.base ||
    WalletNetwork.arbitrum ||
    WalletNetwork.optimism => 'ETH',
    WalletNetwork.bsc => 'BNB',
    WalletNetwork.polygon => 'POL',
    WalletNetwork.tron => 'TRX',
    WalletNetwork.solana => 'SOL',
  };

  static String toBaseUnits(String amount, int decimals) {
    final clean = amount.replaceAll(',', '').trim();
    final parts = clean.split('.');
    if (parts.length > 2 || parts.first.isEmpty) {
      throw const LifiException('兑换金额格式无效');
    }
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > decimals) {
      throw LifiException('兑换金额最多支持 $decimals 位小数');
    }
    final whole = BigInt.parse(parts.first);
    final fractionValue = BigInt.parse(
      fraction.padRight(decimals, '0').ifEmpty('0'),
    );
    return (whole * BigInt.from(10).pow(decimals) + fractionValue).toString();
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final message = _findErrorMessage(body);
      if (message != null) return message;
    } catch (_) {
      // Fall back to the status code when the response is not JSON.
    }
    final text = response.body.trim();
    return text.isEmpty
        ? '请稍后重试'
        : text.substring(0, text.length > 240 ? 240 : text.length);
  }

  static String? _findErrorMessage(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Map) {
      for (final key in [
        'message',
        'error',
        'description',
        'errorMessage',
        'statusMessage',
        'reason',
      ]) {
        final message = _findErrorMessage(value[key]);
        if (message != null) return message;
      }
      for (final item in value.values) {
        final message = _findErrorMessage(item);
        if (message != null) return message;
      }
    }
    if (value is Iterable) {
      for (final item in value) {
        final message = _findErrorMessage(item);
        if (message != null) return message;
      }
    }
    return null;
  }
}

class LifiQuote {
  const LifiQuote({
    required this.fromAmount,
    required this.toAmount,
    required this.toAmountMin,
    required this.tool,
    required this.transactionRequest,
    this.priceImpact,
    this.fee,
  });

  final String fromAmount;
  final String toAmount;
  final String toAmountMin;
  final String tool;
  final Map<String, dynamic>? transactionRequest;
  final String? priceImpact;
  final String? fee;

  factory LifiQuote.fromJson(Map<String, dynamic> json) {
    final estimate = json['estimate'] as Map<String, dynamic>? ?? const {};
    final action = json['action'];
    final actionMap = action is Map ? action : const <String, dynamic>{};
    final tool = json['tool'];
    final toolName = tool is Map ? tool['name'] : tool;
    return LifiQuote(
      fromAmount: '${estimate['fromAmount'] ?? actionMap['fromAmount'] ?? ''}',
      toAmount: '${estimate['toAmount'] ?? ''}',
      toAmountMin: '${estimate['toAmountMin'] ?? ''}',
      tool: '${toolName ?? 'LI.FI'}',
      transactionRequest: json['transactionRequest'] is Map<String, dynamic>
          ? json['transactionRequest'] as Map<String, dynamic>
          : null,
      priceImpact: _optionalString(estimate['priceImpact']),
      fee: _feeSummary(estimate),
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static String? _feeSummary(Map<String, dynamic> estimate) {
    final feeCosts = estimate['feeCosts'];
    if (feeCosts is! List || feeCosts.isEmpty) return null;
    final values = feeCosts
        .whereType<Map>()
        .map((fee) {
          final usd = _optionalString(fee['amountUSD']);
          if (usd != null) return '\$$usd';
          final amount = _optionalString(fee['amount']);
          final token = _optionalString(
            fee['token'] is Map
                ? (fee['token'] as Map)['symbol']
                : fee['token'],
          );
          if (amount == null) return null;
          return token == null ? amount : '$amount $token';
        })
        .whereType<String>()
        .toList();
    return values.isEmpty ? null : values.join(' + ');
  }
}

class LifiToken {
  const LifiToken({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.logoUri,
  });
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final String? logoUri;

  factory LifiToken.fromJson(Map value) => LifiToken(
    address: '${value['address'] ?? ''}',
    symbol: '${value['symbol'] ?? ''}',
    name: '${value['name'] ?? value['symbol'] ?? ''}',
    decimals: value['decimals'] is num
        ? (value['decimals'] as num).toInt()
        : 18,
    logoUri: switch (value['logoURI'] ?? value['logoUrl'] ?? value['logo']) {
      final String logo when logo.isNotEmpty => logo,
      _ => null,
    },
  );
}

class LifiTransferStatus {
  const LifiTransferStatus({
    required this.status,
    this.substatus,
    this.receivingTxHash,
  });
  final String status;
  final String? substatus;
  final String? receivingTxHash;

  factory LifiTransferStatus.fromJson(Map<String, dynamic> json) {
    final receiving = json['receiving'];
    final receivingMap = receiving is Map<String, dynamic> ? receiving : null;
    return LifiTransferStatus(
      status: '${json['status'] ?? 'UNKNOWN'}',
      substatus: json['substatus'] as String?,
      receivingTxHash: receivingMap?['txHash'] as String?,
    );
  }
}

class LifiException implements Exception {
  const LifiException(this.message);
  final String message;
  @override
  String toString() => message;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
