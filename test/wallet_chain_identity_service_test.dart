import 'package:aco_chat/services/wallet_chain_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about';

  test('derives first non-EVM public addresses', () {
    final addresses = WalletChainIdentityService.deriveNonEvmAddresses(
      mnemonic,
    );

    expect(addresses.keys, containsAll(['solana', 'tron']));
    expect(addresses.values, everyElement(isNotEmpty));
    expect(addresses, isNot(contains('bitcoin')));
    expect(addresses, isNot(contains('cosmos')));
    expect(addresses['tron'], startsWith('T'));
  });
}
