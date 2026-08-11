import 'package:aco_chat/services/wallet_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('derives the first Ethereum address', () {
    final identity = WalletIdentity.fromMnemonic(mnemonic);

    // BIP-44: m/44'/60'/0'/0/0.
    expect(identity.address, '0x9858effd232b4033e47d90003d41ec34ecaeda94');
    expect(WalletIdentity.fromMnemonic(mnemonic).toJson(), identity.toJson());
  });

  test('reads the previous Ethereum-only identity format', () {
    expect(WalletIdentity.fromJson({'evm': '0xabc'}).address, '0xabc');
  });
}
