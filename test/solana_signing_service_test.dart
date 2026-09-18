import 'dart:convert';

import 'package:aco_chat/services/solana_signing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test(
    'derives a Solana address and signs raw messages with Ed25519',
    () async {
      const service = SolanaSigningService();

      expect(service.addressForMnemonic(mnemonic), isNotEmpty);
      final signature = await service.signMessage(
        mnemonic: mnemonic,
        message: 'Aco Solana DApp'.codeUnits,
      );

      expect(base64Decode(signature), hasLength(64));
    },
  );

  test('builds a signed System Program SOL transfer', () {
    const service = SolanaSigningService();

    final transaction = service.buildSignedNativeTransfer(
      mnemonic: mnemonic,
      recipient: '11111111111111111111111111111111',
      lamports: BigInt.from(1000),
      recentBlockhash: '11111111111111111111111111111111',
    );

    expect(base64Decode(transaction), isNotEmpty);
  });

  test('only signs a serialized standard SOL transfer from this wallet', () {
    const service = SolanaSigningService();
    final unsigned = service.buildSignedNativeTransfer(
      mnemonic: mnemonic,
      recipient: '11111111111111111111111111111111',
      lamports: BigInt.from(1000),
      recentBlockhash: '11111111111111111111111111111111',
    );

    final signed = service.signSerializedNativeTransfer(
      mnemonic: mnemonic,
      serializedTransaction: unsigned,
    );

    expect(signed.recipient, '11111111111111111111111111111111');
    expect(signed.lamports, BigInt.from(1000));
    expect(base64Decode(signed.signedTransaction), isNotEmpty);
  });
}
