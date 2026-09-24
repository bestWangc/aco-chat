import 'dart:convert';

import 'package:http/http.dart' as http;

/// Mayan Swift v2 routes into the user's HyperCore perpetual USDC balance.
/// Quotes are execution inputs and deliberately stay out of the UI.
class MayanHyperCoreDepositClient {
  MayanHyperCoreDepositClient({
    http.Client? client,
    Uri? priceUri,
    Uri? explorerUri,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _priceUri = priceUri ?? Uri.parse('https://price-api.mayan.finance/v3'),
       _explorerUri =
           explorerUri ?? Uri.parse('https://explorer-api.mayan.finance/v3');

  static const hyperCorePerpsUsdc =
      '0x0000000000000000000000000000000000000000';
  static const sdkVersion = '15_2_2';

  final http.Client _client;
  final bool _ownsClient;
  final Uri _priceUri;
  final Uri _explorerUri;

  Future<MayanHyperCoreDepositQuote> quote({
    required String amount,
    required String fromToken,
    required String fromChain,
    required String destinationAddress,
  }) async {
    final uri = _priceUri.replace(
      path: '${_priceUri.path}/quote',
      queryParameters: {
        'amountIn': amount,
        'fromToken': fromToken,
        'fromChain': fromChain,
        'toToken': hyperCorePerpsUsdc,
        'toChain': 'hypercore',
        'slippageBps': 'auto',
        'destinationAddress': destinationAddress,
        'swift': 'true',
        'mctp': 'false',
        'fastMctp': 'false',
        'wormhole': 'false',
        'sdkVersion': sdkVersion,
      },
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
      throw MayanHyperCoreDepositException(
        '$failure（${message ?? response.statusCode}）',
      );
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
