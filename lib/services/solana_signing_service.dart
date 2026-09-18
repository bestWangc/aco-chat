import 'dart:convert';

import 'package:aco_chat/services/bip39_service.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:on_chain/solana/solana.dart';

/// Derives and signs with the first Solana account without exposing its key to
/// a DApp. Solana signs raw message bytes using Ed25519, not EIP-191.
class SolanaSigningService {
  const SolanaSigningService();

  Future<String> signMessage({
    required String mnemonic,
    required List<int> message,
  }) async {
    final account = _account(mnemonic);
    final keyPair = await Ed25519().newKeyPairFromSeed(account.privateKey.raw);
    final signature = await Ed25519().sign(message, keyPair: keyPair);
    return base64Encode(signature.bytes);
  }

  String addressForMnemonic(String mnemonic) =>
      _account(mnemonic).publicKey.toAddress;

  /// Builds and signs a standard System Program SOL transfer. The caller must
  /// obtain a fresh [recentBlockhash] from the active Solana RPC endpoint.
  String buildSignedNativeTransfer({
    required String mnemonic,
    required String recipient,
    required BigInt lamports,
    required String recentBlockhash,
  }) {
    if (lamports <= BigInt.zero) {
      throw ArgumentError.value(lamports, 'lamports', '必须大于零');
    }
    final privateKey = SolanaPrivateKey.fromSeed(
      _account(mnemonic).privateKey.raw,
    );
    final sender = privateKey.publicKey().toAddress();
    final transaction = SolanaTransaction(
      payerKey: sender,
      recentBlockhash: SolAddress(recentBlockhash),
      instructions: [
        SystemProgram.transfer(
          from: sender,
          to: SolAddress(recipient),
          layout: SystemTransferLayout(lamports: lamports),
        ),
      ],
    );
    transaction.sign([privateKey]);
    return base64Encode(transaction.serialize(verifySignatures: true));
  }

  /// Signs a DApp-provided legacy transaction only when it is exactly one
  /// System Program transfer from this wallet. Versioned transactions, lookup
  /// tables, additional instructions and additional required signers are
  /// deliberately refused until each can be presented safely in the UI.
  SolanaNativeTransfer signSerializedNativeTransfer({
    required String mnemonic,
    required String serializedTransaction,
  }) {
    final preview = inspectSerializedNativeTransfer(
      serializedTransaction: serializedTransaction,
      signerAddress: addressForMnemonic(mnemonic),
    );
    final transaction = SolanaTransaction.deserialize(
      base64Decode(serializedTransaction),
    );
    final privateKey = SolanaPrivateKey.fromSeed(
      _account(mnemonic).privateKey.raw,
    );
    transaction.sign([privateKey]);
    return SolanaNativeTransfer(
      recipient: preview.recipient,
      lamports: preview.lamports,
      signedTransaction: base64Encode(
        transaction.serialize(verifySignatures: true),
      ),
    );
  }

  SolanaNativeTransfer inspectSerializedNativeTransfer({
    required String serializedTransaction,
    required String signerAddress,
  }) {
    final transaction = SolanaTransaction.deserialize(
      base64Decode(serializedTransaction),
    );
    final message = transaction.message;
    if (message.version != TransactionType.legacy ||
        message.header.numRequiredSignatures != 1 ||
        message.compiledInstructions.length != 1) {
      throw const FormatException('仅支持单签名的标准 SOL 转账');
    }
    final instruction = message.compiledInstructions.single;
    if (instruction.programIdIndex >= message.accountKeys.length ||
        message.accountKeys[instruction.programIdIndex].address !=
            SystemProgramConst.programId.address ||
        instruction.accounts.length != 2 ||
        instruction.data.length != 12) {
      throw const FormatException('仅支持标准 System Program 转账');
    }
    final senderIndex = instruction.accounts[0];
    final recipientIndex = instruction.accounts[1];
    if (senderIndex >= message.accountKeys.length ||
        recipientIndex >= message.accountKeys.length ||
        message.accountKeys.first.address != signerAddress ||
        message.accountKeys[senderIndex].address != signerAddress ||
        !_isSystemTransfer(instruction.data)) {
      throw const FormatException('转账账户或指令无效');
    }
    final lamports = _littleEndianU64(instruction.data.sublist(4));
    if (lamports <= BigInt.zero) throw const FormatException('转账金额无效');
    return SolanaNativeTransfer(
      recipient: message.accountKeys[recipientIndex].address,
      lamports: lamports,
      signedTransaction: '',
    );
  }

  Bip44 _account(String mnemonic) => Bip44.fromSeed(
    Bip39Service.mnemonicToSeed(mnemonic),
    Bip44Coins.solana,
  ).deriveDefaultPath;
}

class SolanaNativeTransfer {
  const SolanaNativeTransfer({
    required this.recipient,
    required this.lamports,
    required this.signedTransaction,
  });

  final String recipient;
  final BigInt lamports;
  final String signedTransaction;
}

bool _isSystemTransfer(List<int> data) =>
    data[0] == 2 && data[1] == 0 && data[2] == 0 && data[3] == 0;

BigInt _littleEndianU64(List<int> bytes) {
  var value = BigInt.zero;
  for (var index = 0; index < bytes.length; index++) {
    value |= BigInt.from(bytes[index]) << (8 * index);
  }
  return value;
}
