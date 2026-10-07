import 'dart:convert';

import 'package:aco_chat/services/tron_signing_service.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';
import 'package:on_chain/on_chain.dart';

class TronTransferResult {
  const TronTransferResult({required this.hash});
  final String hash;
}

class TronTransferService {
  const TronTransferService();

  Future<TronTransferResult> transferTrc20({
    required String mnemonic,
    required String from,
    required String to,
    required String contract,
    required BigInt amount,
    required String accessToken,
    required WalletRpcClient rpc,
  }) async {
    final endpoints = await rpc.loadEndpoints(
      network: WalletNetwork.tron.name,
      accessToken: accessToken,
    );
    final ownerHex = _hexAddress(from);
    final recipientHex = _hexAddress(to);
    final contractHex = _hexAddress(contract);
    final parameter =
        '${recipientHex.substring(2).padLeft(64, '0')}'
        '${amount.toRadixString(16).padLeft(64, '0')}';
    final simulation = await rpc
        .postJsonPath(endpoints, 'wallet/triggerconstantcontract', {
          'owner_address': ownerHex,
          'contract_address': contractHex,
          'function_selector': 'transfer(address,uint256)',
          'parameter': parameter,
          'visible': false,
        });
    final simulationResult = simulation['result'];
    if (simulationResult is Map && simulationResult['result'] == false) {
      throw const FormatException('TRON 合约无法执行转账');
    }
    final energy = (simulation['energy_used'] as num?)?.toInt() ?? 100000;
    final feeLimit = (energy * 420).clamp(1_000_000, 50_000_000);
    final built = await rpc
        .postJsonPath(endpoints, 'wallet/triggersmartcontract', {
          'owner_address': ownerHex,
          'contract_address': contractHex,
          'function_selector': 'transfer(address,uint256)',
          'parameter': parameter,
          'fee_limit': feeLimit,
          'visible': false,
        });
    final tx = built['transaction'];
    if (tx is! Map<String, dynamic>) {
      throw const FormatException('TRON 交易构造失败');
    }
    final signed = const TronSigningService().signSerializedTransaction(
      mnemonic: mnemonic,
      serializedTransaction: jsonEncode(tx),
    );
    final broadcast = await rpc.postJsonPath(
      endpoints,
      'wallet/broadcasttransaction',
      jsonDecode(signed) as Map<String, Object>,
    );
    if (broadcast['result'] != true) {
      throw FormatException('${broadcast['message'] ?? 'TRON 广播失败'}');
    }
    final hash = '${broadcast['txid'] ?? tx['txID'] ?? ''}';
    if (hash.isEmpty) throw const FormatException('TRON 未返回交易哈希');
    return TronTransferResult(hash: hash);
  }

  static String _hexAddress(String address) {
    final decoded = TronAddress(address).toHex();
    return decoded;
  }
}
