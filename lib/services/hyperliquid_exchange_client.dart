import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/services/hyperliquid_signing.dart';
import 'package:http/http.dart' as http;

/// Signed Hyperliquid exchange actions. The caller is responsible for
/// unlocking the wallet only for the duration of the requested action.
class HyperliquidExchangeClient {
  HyperliquidExchangeClient({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _endpoint = endpoint ?? Uri.parse(AppConfig.hyperliquidExchangeUrl),
      _isMainnet = !AppConfig.hyperliquidTestnet;

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  final bool _isMainnet;

  Future<Map<String, dynamic>> approveAgent({
    required String masterPrivateKey,
    required String agentAddress,
    required String agentName,
  }) {
    final nonce = _now();
    final action = <String, dynamic>{
      'type': 'approveAgent',
      'agentAddress': agentAddress,
      'agentName': agentName,
      'nonce': nonce,
    };
    return _submitUserAction(
      privateKeyHex: masterPrivateKey,
      action: action,
      nonce: nonce,
      primaryType: 'HyperliquidTransaction:ApproveAgent',
      fields: HyperliquidSigner.approveAgentTypes,
    );
  }

  Future<Map<String, dynamic>> approveBuilderFee({
    required String masterPrivateKey,
    required String builderAddress,
    required String maxFeeRate,
  }) {
    final nonce = _now();
    final action = <String, dynamic>{
      'type': 'approveBuilderFee',
      'maxFeeRate': maxFeeRate,
      'builder': builderAddress,
      'nonce': nonce,
    };
    return _submitUserAction(
      privateKeyHex: masterPrivateKey,
      action: action,
      nonce: nonce,
      primaryType: 'HyperliquidTransaction:ApproveBuilderFee',
      fields: HyperliquidSigner.approveBuilderFeeTypes,
    );
  }

  Future<Map<String, dynamic>> placeOrder({
    required String agentPrivateKey,
    required Map<String, dynamic> action,
    int? expiresAfter,
  }) {
    final nonce = _now();
    final signature = HyperliquidSigner.signL1Action(
      privateKeyHex: agentPrivateKey,
      action: action,
      nonce: nonce,
      isMainnet: _isMainnet,
      expiresAfter: expiresAfter,
    );
    return _submit(action, nonce, signature, expiresAfter: expiresAfter);
  }

  Future<Map<String, dynamic>> cancelOrder({
    required String agentPrivateKey,
    required int asset,
    required int orderId,
  }) => placeOrder(
    agentPrivateKey: agentPrivateKey,
    action: HyperliquidSigner.cancelAction(asset: asset, orderId: orderId),
  );

  Future<Map<String, dynamic>> updateLeverage({
    required String agentPrivateKey,
    required int asset,
    required int leverage,
  }) => placeOrder(
    agentPrivateKey: agentPrivateKey,
    action: HyperliquidSigner.updateLeverageAction(
      asset: asset,
      leverage: leverage,
    ),
  );

  Future<Map<String, dynamic>> usdClassTransfer({
    required String masterPrivateKey,
    required String amount,
    required bool toPerp,
  }) {
    final nonce = _now();
    final action = <String, dynamic>{
      'type': 'usdClassTransfer',
      'amount': amount,
      'toPerp': toPerp,
      'nonce': nonce,
    };
    return _submitUserAction(
      privateKeyHex: masterPrivateKey,
      action: action,
      nonce: nonce,
      primaryType: 'HyperliquidTransaction:UsdClassTransfer',
      fields: HyperliquidSigner.usdClassTransferTypes,
    );
  }

  Future<Map<String, dynamic>> withdraw({
    required String masterPrivateKey,
    required String destination,
    required String amount,
  }) {
    final time = _now();
    final action = <String, dynamic>{
      'destination': destination,
      'amount': amount,
      'time': time,
      'type': 'withdraw3',
    };
    return _submitUserAction(
      privateKeyHex: masterPrivateKey,
      action: action,
      nonce: time,
      primaryType: 'HyperliquidTransaction:Withdraw',
      fields: HyperliquidSigner.withdrawTypes,
    );
  }

  Future<Map<String, dynamic>> _submitUserAction({
    required String privateKeyHex,
    required Map<String, dynamic> action,
    required int nonce,
    required String primaryType,
    required List<Map<String, String>> fields,
  }) {
    final signature = HyperliquidSigner.signUserAction(
      privateKeyHex: privateKeyHex,
      action: action,
      primaryType: primaryType,
      fields: fields,
      isMainnet: _isMainnet,
    );
    return _submit(_addUserFields(action), nonce, signature);
  }

  Future<Map<String, dynamic>> _submit(
    Map<String, dynamic> action,
    int nonce,
    HyperliquidSignature signature, {
    int? expiresAfter,
  }) async {
    final response = await _client
        .post(
          _endpoint,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'action': action,
            'nonce': nonce,
            'signature': signature.toJson(),
            'vaultAddress': null,
            'expiresAfter': expiresAfter,
          }),
        )
        .timeout(const Duration(seconds: 15));
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const HyperliquidExchangeException('Hyperliquid 返回数据无效');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HyperliquidExchangeException(_errorMessage(decoded));
    }
    if (decoded is! Map<String, dynamic>) {
      throw const HyperliquidExchangeException('Hyperliquid 返回数据无效');
    }
    final status = '${decoded['status'] ?? ''}';
    if (status == 'err' || decoded['error'] != null) {
      throw HyperliquidExchangeException(_errorMessage(decoded));
    }
    return decoded;
  }

  Map<String, dynamic> _addUserFields(Map<String, dynamic> action) => {
    ...action,
    'signatureChainId': '0x66eee',
    'hyperliquidChain': _isMainnet ? 'Mainnet' : 'Testnet',
  };

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  static String _errorMessage(dynamic decoded) {
    if (decoded is Map) {
      final response = decoded['response'];
      if (response is String && response.isNotEmpty) return response;
      final error = decoded['error'] ?? decoded['message'] ?? decoded['status'];
      if (error != null && '$error'.isNotEmpty) return '$error';
    }
    return 'Hyperliquid 交易提交失败';
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class HyperliquidExchangeException implements Exception {
  const HyperliquidExchangeException(this.message);

  final String message;

  @override
  String toString() => message;
}
