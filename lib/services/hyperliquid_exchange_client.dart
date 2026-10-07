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
    String? debugSignerAddress,
  }) {
    final nonce = _now();
    final signature = HyperliquidSigner.signL1Action(
      privateKeyHex: agentPrivateKey,
      action: action,
      nonce: nonce,
      isMainnet: _isMainnet,
      expiresAfter: expiresAfter,
    );
    return _submit(
      action,
      nonce,
      signature,
      expiresAfter: expiresAfter,
      debugSignerAddress: debugSignerAddress,
    );
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
    String? expectedSignerAddress,
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
      expectedSignerAddress: expectedSignerAddress,
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
    String? expectedSignerAddress,
  }) {
    final signature = HyperliquidSigner.signUserAction(
      privateKeyHex: privateKeyHex,
      action: action,
      primaryType: primaryType,
      fields: fields,
      isMainnet: _isMainnet,
    );
    return _submit(
      _addUserFields(action),
      nonce,
      signature,
      debugSignerAddress: HyperliquidSigner.addressFromPrivateKey(
        privateKeyHex,
      ),
      expectedSignerAddress: expectedSignerAddress,
    );
  }

  Future<Map<String, dynamic>> _submit(
    Map<String, dynamic> action,
    int nonce,
    HyperliquidSignature signature, {
    int? expiresAfter,
    String? debugSignerAddress,
    String? expectedSignerAddress,
  }) async {
    final payload = <String, dynamic>{
      'action': action,
      'nonce': nonce,
      'signature': signature.toJson(),
      'vaultAddress': null,
      'expiresAfter': expiresAfter,
    };
    final response = await _client
        .post(
          _endpoint,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const HyperliquidExchangeException('Hyperliquid 返回数据无效');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(decoded);
      throw HyperliquidExchangeException(message);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const HyperliquidExchangeException('Hyperliquid 返回数据无效');
    }
    final status = '${decoded['status'] ?? ''}';
    if (status == 'err' || decoded['error'] != null) {
      final message = _errorMessage(decoded);
      throw HyperliquidExchangeException(message);
    }
    final nestedError = _nestedError(decoded);
    if (nestedError != null) {
      throw HyperliquidExchangeException(nestedError);
    }
    return decoded;
  }

  String? _nestedError(Object? value) {
    if (value is Map) {
      final direct = value['error'];
      if (direct is String && direct.trim().isNotEmpty) return direct;
      for (final item in value.values) {
        final found = _nestedError(item);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final item in value) {
        final found = _nestedError(item);
        if (found != null) return found;
      }
    }
    return null;
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
  const HyperliquidExchangeException(this.rawMessage);

  final String rawMessage;

  bool get isUnifiedAccountActive => rawMessage.toLowerCase().contains(
    'action disabled when unified account is active',
  );

  /// Hyperliquid returns this onboarding error in English and appends the
  /// wallet address. Expose an actionable message to the UI without leaking
  /// request or response payloads.
  String get message {
    final normalized = rawMessage.toLowerCase();
    if (normalized.contains('action disabled when unified account is active')) {
      return '当前 Hyperliquid 账户已启用 Unified Account，Spot 与合约账户资金已统一，无需执行 Spot → 合约划转，可直接进行合约交易。';
    }
    if (normalized.contains('must deposit before performing actions')) {
      return 'Hyperliquid 测试网拒绝了账户划转。请确认主网存款、测试网 Faucet 和当前钱包使用的是同一个地址，并确认 Faucet 领取已完成。';
    }
    return rawMessage;
  }

  @override
  String toString() => message;
}
