import 'dart:convert';

import 'package:aco_chat/services/bip39_service.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

/// Signs the JSON transaction format returned by a TRON full node/LI.FI.
class TronSigningService {
  const TronSigningService();

  String signSerializedTransaction({
    required String mnemonic,
    required String serializedTransaction,
  }) {
    final decoded = jsonDecode(serializedTransaction);
    if (decoded is! Map<String, dynamic> ||
        decoded['raw_data_hex'] is! String) {
      throw const FormatException('TRON 交易格式无效');
    }
    final transaction = Map<String, dynamic>.from(decoded);
    final rawHex = transaction['raw_data_hex'] as String;
    final raw = _hexBytes(rawHex);
    if (raw.isEmpty) throw const FormatException('TRON 原始交易为空');
    final key = Bip44.fromSeed(
      Bip39Service.mnemonicToSeed(mnemonic),
      Bip44Coins.tron,
    ).deriveDefaultPath.privateKey.raw;
    final signature = TronSigner.fromKeyBytes(
      key,
    ).sign(QuickCrypto.keccack256Hash(raw), hashMessage: false);
    final signatures =
        (transaction['signature'] as List?)?.whereType<String>().toList() ??
        <String>[];
    signatures.add(base64Encode(signature));
    transaction['signature'] = signatures;
    return jsonEncode(transaction);
  }

  static List<int> _hexBytes(String value) {
    final normalized = value.replaceFirst(RegExp('^0x'), '');
    if (normalized.isEmpty || normalized.length.isOdd) return const [];
    return List<int>.generate(
      normalized.length ~/ 2,
      (index) =>
          int.parse(normalized.substring(index * 2, index * 2 + 2), radix: 16),
    );
  }
}
