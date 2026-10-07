import 'dart:convert';

import 'package:http/http.dart' as http;

/// Mayan Swift v2 routes into the user's HyperCore perpetual USDC balance.
/// Quotes are execution inputs and deliberately stay out of the UI.
class MayanHyperCoreDepositClient {
  MayanHyperCoreDepositClient({
    http.Client? client,
    Uri? priceUri,
    Uri? explorerUri,
    Uri? txBuilderUri,
    this.apiKey,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _priceUri = priceUri ?? Uri.parse('https://price-api.mayan.finance/v3'),
       _explorerUri =
           explorerUri ?? Uri.parse('https://explorer-api.mayan.finance/v3'),
       _txBuilderUri =
           txBuilderUri ?? Uri.parse('https://tx-builder.mayan.finance');

  static const hyperCorePerpsUsdc =
      '0x0000000000000000000000000000000000000000';
  static const sdkVersion = '15_2_2';
  // Mayan's Forwarder is deployed at the same address on supported EVM
  // networks. Supplying it lets the quote service validate the route and
  // prevents the "Forwarder not accepted" response.
  static const evmForwarder = '0x337685fdaB40D39bd02028545a4FfA7D287cC3E2';

  final http.Client _client;
  final bool _ownsClient;
  final Uri _priceUri;
  final Uri _explorerUri;
  final Uri _txBuilderUri;
  final String? apiKey;

  Future<MayanHyperCoreDepositQuote> quote({
    required String amount,
    required String fromToken,
    required String fromChain,
    required String destinationAddress,
    int decimals = 6,
    String? referrer,
    int? referrerBps,
  }) async {
    final queryParameters = <String, String>{
      'amountIn': amount,
      'amountIn64': _toBaseUnits(amount, decimals),
      'fromToken': fromToken,
      'fromChain': fromChain,
      'toToken': hyperCorePerpsUsdc,
      'toChain': 'hypercore',
      'slippageBps': 'auto',
      // HyperCore destination addresses belong to the execution/build call.
      // Passing an address while fetching a Swift v2 quote makes Mayan treat
      // it as a forwarder and can result in "Forwarder not accepted".
      'swift': 'true',
      'mctp': 'false',
      'fastMctp': 'false',
      'wormhole': 'false',
      'forwarderAddress': evmForwarder,
      'sdkVersion': sdkVersion,
    };
    if (referrer != null && referrer.isNotEmpty) {
      queryParameters['referrer'] = referrer;
    }
    if (referrerBps != null && referrerBps > 0) {
      queryParameters['referrerBps'] = '$referrerBps';
    }
    final uri = _priceUri.replace(
      path: '${_priceUri.path}/quote',
      queryParameters: queryParameters,
    );
    final body = await _get(uri, 'Mayan 路由请求失败');
    final quotes = body['quotes'];
    if (quotes is! List) {
      throw const MayanHyperCoreDepositException('Mayan 返回数据无效');
    }
    for (final item in quotes) {
      if (item is Map) {
        final quote = MayanHyperCoreDepositQuote.fromJson(item);
        if (quote.isPerpsSwiftRoute) return quote;
      }
    }
    throw const MayanHyperCoreDepositException('当前资产暂不支持划转至合约账户');
  }

  Future<Map<String, dynamic>> buildEvm({
    required MayanHyperCoreDepositQuote quote,
    required String swapperAddress,
    required String destinationAddress,
    int? signerChainId,
    Map<String, dynamic>? referrerAddresses,
  }) async {
    final params = <String, dynamic>{
      'swapperAddress': swapperAddress,
      'destinationAddress': destinationAddress,
    };
    if (signerChainId != null) params['signerChainId'] = signerChainId;
    if (referrerAddresses != null && referrerAddresses.isNotEmpty) {
      params['referrerAddresses'] = referrerAddresses;
    }
    final body = await _postJson(
      _txBuilderUri.replace(path: '${_txBuilderUri.path}/build'),
      {'quote': quote.raw, 'params': params},
      'Mayan 交易构造失败',
    );
    final transaction = body['transaction'];
    if (transaction is! Map<String, dynamic>) {
      throw const MayanHyperCoreDepositException('Mayan 交易数据无效');
    }
    return transaction;
  }

  Future<MayanHyperCoreDepositQuote> withdrawalQuote({
    required String amount,
    required String toToken,
    required String toChain,
    required String destinationAddress,
    int decimals = 6,
    String? referrer,
    int? referrerBps,
  }) async {
    final queryParameters = <String, String>{
      'amountIn': amount,
      'amountIn64': _toBaseUnits(amount, decimals),
      'fromToken': hyperCorePerpsUsdc,
      'fromChain': 'hypercore',
      'toToken': toToken,
      'toChain': toChain,
      'slippageBps': 'auto',
      'swift': 'true',
      'gasless': 'true',
      'mctp': 'false',
      'fastMctp': 'false',
      'wormhole': 'false',
      'forwarderAddress': evmForwarder,
      'sdkVersion': sdkVersion,
    };
    if (referrer != null && referrer.isNotEmpty) {
      queryParameters['referrer'] = referrer;
    }
    if (referrerBps != null && referrerBps > 0) {
      queryParameters['referrerBps'] = '$referrerBps';
    }
    final uri = _priceUri.replace(
      path: '${_priceUri.path}/quote',
      queryParameters: queryParameters,
    );
    final body = await _get(uri, 'Mayan 提现路由请求失败');
    final quotes = body['quotes'];
    if (quotes is! List) {
      throw const MayanHyperCoreDepositException('Mayan 返回数据无效');
    }
    for (final item in quotes) {
      if (item is Map) {
        final quote = MayanHyperCoreDepositQuote.fromJson(item);
        if (quote.type == 'SWIFT' && quote.swiftVersion == 'V2') return quote;
      }
    }
    throw const MayanHyperCoreDepositException('当前网络暂不支持合约账户提现');
  }

  Future<Map<String, dynamic>> submitGasless({
    required Map<String, dynamic> transaction,
    required String signature,
  }) => _postJson(_txBuilderUri.replace(path: '${_txBuilderUri.path}/submit'), {
    'transaction': transaction,
    'signature': signature,
  }, 'Mayan 提现提交失败');

  Future<MayanDepositStatus> status(String transactionHash) async {
    final body = await _get(
      _explorerUri.replace(
        path: '${_explorerUri.path}/swap/trx/$transactionHash',
      ),
      'Mayan 状态查询失败',
    );
    return MayanDepositStatus.fromJson(body);
  }

  Future<Map<String, dynamic>> _get(Uri uri, String failure) async {
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['msg'] ?? decoded['message']
          : null;
      final detail =
          message ??
          (response.body.trim().isEmpty ? response.statusCode : response.body);
      throw MayanHyperCoreDepositException('$failure（$detail）');
    }
    if (decoded is! Map<String, dynamic>) {
      throw MayanHyperCoreDepositException('$failure（返回格式无效）');
    }
    if (decoded['code'] != null) {
      throw MayanHyperCoreDepositException(
        '$failure（${decoded['msg'] ?? decoded['code']}）',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> payload,
    String failure,
  ) async {
    final response = await _client
        .post(
          uri,
          headers: {
            'content-type': 'application/json',
            if (apiKey != null && apiKey!.trim().isNotEmpty)
              'x-api-key': apiKey!.trim(),
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['msg'] ?? decoded['message']
          : null;
      final detail =
          message ??
          (response.body.trim().isEmpty ? response.statusCode : response.body);
      throw MayanHyperCoreDepositException('$failure（$detail）');
    }
    if (decoded is! Map<String, dynamic> || decoded['success'] == false) {
      throw const MayanHyperCoreDepositException('Mayan 返回数据无效');
    }
    return decoded;
  }

  static String _toBaseUnits(String amount, int decimals) {
    final parts = amount.trim().split('.');
    final whole = BigInt.parse(parts.first);
    final fraction = parts.length > 1 ? parts[1] : '';
    if (fraction.length > decimals) {
      throw const MayanHyperCoreDepositException('金额精度无效');
    }
    final padded = fraction.padRight(decimals, '0');
    return (whole * BigInt.from(10).pow(decimals) +
            BigInt.parse(padded.isEmpty ? '0' : padded))
        .toString();
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class MayanHyperCoreDepositQuote {
  const MayanHyperCoreDepositQuote({
    required this.type,
    required this.swiftVersion,
    required this.toChain,
    required this.toTokenName,
    required this.expectedAmountOut,
    required this.minReceived,
    required this.deadline,
    required this.raw,
  });

  final String type;
  final String swiftVersion;
  final String toChain;
  final String toTokenName;
  final String expectedAmountOut;
  final String minReceived;
  final String deadline;
  final Map<String, dynamic> raw;

  bool get isPerpsSwiftRoute =>
      type == 'SWIFT' &&
      swiftVersion == 'V2' &&
      toChain == 'hypercore' &&
      toTokenName == 'USDC (perps)' &&
      deadline.isNotEmpty;

  factory MayanHyperCoreDepositQuote.fromJson(Map raw) {
    final toToken = raw['toToken'] is Map ? raw['toToken'] as Map : const {};
    return MayanHyperCoreDepositQuote(
      type: '${raw['type'] ?? ''}',
      swiftVersion: '${raw['swiftVersion'] ?? ''}',
      toChain: '${raw['toChain'] ?? ''}',
      toTokenName: '${toToken['name'] ?? ''}',
      expectedAmountOut: '${raw['expectedAmountOut'] ?? ''}',
      minReceived: '${raw['minReceived'] ?? ''}',
      deadline: '${raw['deadline64'] ?? ''}',
      raw: Map<String, dynamic>.from(raw),
    );
  }
}

class MayanDepositStatus {
  const MayanDepositStatus(this.value);

  final String value;

  bool get completed => value == 'COMPLETED';
  bool get terminalFailure => value == 'REFUNDED';

  factory MayanDepositStatus.fromJson(Map raw) =>
      MayanDepositStatus('${raw['clientStatus'] ?? 'INPROGRESS'}');
}

class MayanHyperCoreDepositException implements Exception {
  const MayanHyperCoreDepositException(this.message);

  final String message;

  @override
  String toString() => message;
}
