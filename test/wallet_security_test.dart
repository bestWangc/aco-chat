import 'dart:convert';

import 'package:aco_chat/services/wallet_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const password = 'correct horse battery staple';
  const address = '0x7bB41A13E1B0dBbC0eD318975984ebFBBf707A86';

  group('WalletSecurity', () {
    test('creates a valid BIP-39 mnemonic', () {
      final security = WalletSecurity();

      final mnemonic = security.createMnemonic();

      expect(mnemonic.split(' '), hasLength(12));
      expect(security.isValidMnemonic(mnemonic), isTrue);
    });

    test('normalizes and validates imported BIP-39 mnemonic', () {
      final security = WalletSecurity();
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';

      expect(security.isValidMnemonic('  $phrase  '), isTrue);
      expect(security.isValidMnemonic('$phrase invalid'), isFalse);
    });

    test(
      'encrypts a mnemonic at rest and unlocks it with its password',
      () async {
        final security = WalletSecurity();
        final store = InMemoryWalletSecretStore();
        const phrase =
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about';

        await security.saveMnemonic(
          store: store,
          walletAddress: address,
          mnemonic: phrase,
          password: password,
        );

        final encrypted = await store.read(
          'wallet.vault.${address.toLowerCase()}',
        );
        expect(encrypted, isNot(contains(phrase)));
        expect(jsonDecode(encrypted!)['version'], 1);
        await expectLater(
          security.unlockMnemonic(
            store: store,
            walletAddress: address,
            password: 'wrong-password',
          ),
          throwsA(isA<WalletSecurityException>()),
        );
        expect(
          await security.unlockMnemonic(
            store: store,
            walletAddress: address,
            password: password,
          ),
          phrase,
        );
      },
    );

    test('keeps password and device unlocks independently available', () async {
      final security = WalletSecurity();
      final store = InMemoryWalletSecretStore();
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';

      await security.saveMnemonic(
        store: store,
        walletAddress: address,
        mnemonic: phrase,
        password: password,
      );
      await security.saveMnemonicWithDeviceProtection(
        store: store,
        walletAddress: address,
        mnemonic: phrase,
      );

      expect(
        await security.hasDeviceProtection(
          store: store,
          walletAddress: address,
        ),
        isTrue,
      );
      expect(
        await security.hasPasswordProtection(
          store: store,
          walletAddress: address,
        ),
        isTrue,
      );
      expect(
        await security.unlockMnemonic(
          store: store,
          walletAddress: address,
          password: password,
        ),
        phrase,
      );
      expect(
        await security.unlockMnemonicWithDeviceProtection(
          store: store,
          walletAddress: address,
        ),
        phrase,
      );
    });

    test(
      'unlocks legacy device-protected vaults for mnemonic export',
      () async {
        final security = WalletSecurity();
        final store = InMemoryWalletSecretStore();
        const phrase =
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about';
        final vaultKey = 'wallet.vault.${address.toLowerCase()}';
        final deviceVaultKey = 'wallet.device-vault.${address.toLowerCase()}';

        await security.saveMnemonicWithDeviceProtection(
          store: store,
          walletAddress: address,
          mnemonic: phrase,
        );
        // Older app versions stored the device-encrypted vault in wallet.vault.
        await store.write(vaultKey, (await store.read(deviceVaultKey))!);
        await store.delete(deviceVaultKey);

        expect(
          await security.hasDeviceProtection(
            store: store,
            walletAddress: address,
          ),
          isTrue,
        );
        expect(
          await security.hasPasswordProtection(
            store: store,
            walletAddress: address,
          ),
          isFalse,
        );
        expect(
          await security.unlockMnemonicWithDeviceProtection(
            store: store,
            walletAddress: address,
          ),
          phrase,
        );
      },
    );

    test('rejects invalid phrases and short passwords', () async {
      final security = WalletSecurity();
      final store = InMemoryWalletSecretStore();

      await expectLater(
        security.saveMnemonic(
          store: store,
          walletAddress: address,
          mnemonic: 'not a valid mnemonic',
          password: password,
        ),
        throwsA(isA<WalletSecurityException>()),
      );
      await expectLater(
        security.saveMnemonic(
          store: store,
          walletAddress: address,
          mnemonic:
              'abandon abandon abandon abandon abandon abandon abandon abandon '
              'abandon abandon abandon about',
          password: 'short',
        ),
        throwsA(isA<WalletSecurityException>()),
      );
    });
  });
}
