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
      final deviceRecord =
          jsonDecode(
                (await store.read(
                  'wallet.device-vault.${address.toLowerCase()}',
                ))!,
              )
              as Map<String, dynamic>;
      expect(deviceRecord['format'], 'aco-device-vault-v1');
      expect(
        await store.read('wallet.device-password.${address.toLowerCase()}'),
        isNull,
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
        final deviceRecord =
            jsonDecode((await store.read(deviceVaultKey))!)
                as Map<String, dynamic>;
        // Older app versions stored the device-encrypted vault in wallet.vault.
        await store.write(vaultKey, deviceRecord['record'] as String);
        await store.write(
          'wallet.device-password.${address.toLowerCase()}',
          deviceRecord['password'] as String,
        );
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

    test('reports mismatched legacy device key and vault clearly', () async {
      final security = WalletSecurity();
      final store = InMemoryWalletSecretStore();
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      final deviceVaultKey = 'wallet.device-vault.${address.toLowerCase()}';
      final devicePasswordKey =
          'wallet.device-password.${address.toLowerCase()}';

      await security.saveMnemonicWithDeviceProtection(
        store: store,
        walletAddress: address,
        mnemonic: phrase,
      );
      final oldDeviceRecord =
          jsonDecode((await store.read(deviceVaultKey))!)
              as Map<String, dynamic>;
      await security.saveMnemonicWithDeviceProtection(
        store: store,
        walletAddress: address,
        mnemonic: phrase,
      );
      final newDeviceRecord =
          jsonDecode((await store.read(deviceVaultKey))!)
              as Map<String, dynamic>;
      await store.write(deviceVaultKey, newDeviceRecord['record'] as String);
      await store.write(
        devicePasswordKey,
        oldDeviceRecord['password'] as String,
      );

      await expectLater(
        security.unlockMnemonicWithDeviceProtection(
          store: store,
          walletAddress: address,
        ),
        throwsA(
          isA<WalletSecurityException>().having(
            (error) => error.message,
            'message',
            contains('设备加密数据与密钥不匹配'),
          ),
        ),
      );
    });

    test('adds password access to a legacy device-protected wallet', () async {
      final security = WalletSecurity();
      final store = InMemoryWalletSecretStore();
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      final deviceVaultKey = 'wallet.device-vault.${address.toLowerCase()}';

      await security.saveMnemonicWithDeviceProtection(
        store: store,
        walletAddress: address,
        mnemonic: phrase,
      );
      final deviceRecord =
          jsonDecode((await store.read(deviceVaultKey))!)
              as Map<String, dynamic>;
      final legacyVault = deviceRecord['record'] as String;
      await store.write('wallet.vault.${address.toLowerCase()}', legacyVault);
      await store.write(
        'wallet.device-password.${address.toLowerCase()}',
        deviceRecord['password'] as String,
      );
      await store.delete(deviceVaultKey);

      final unlocked = await security.unlockMnemonicWithDeviceProtection(
        store: store,
        walletAddress: address,
      );
      await security.saveMnemonic(
        store: store,
        walletAddress: address,
        mnemonic: unlocked,
        password: password,
      );
      await security.saveMnemonicWithDeviceProtection(
        store: store,
        walletAddress: address,
        mnemonic: unlocked,
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
      'migrates legacy device protection without losing either unlock',
      () async {
        final security = WalletSecurity();
        final store = InMemoryWalletSecretStore();
        const phrase =
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about';

        await security.saveMnemonicWithDeviceProtection(
          store: store,
          walletAddress: address,
          mnemonic: phrase,
        );
        final legacyDeviceVault =
            jsonDecode(
                  (await store.read(
                    'wallet.device-vault.${address.toLowerCase()}',
                  ))!,
                )
                as Map<String, dynamic>;
        await store.write(
          'wallet.vault.${address.toLowerCase()}',
          legacyDeviceVault['record'] as String,
        );
        await store.write(
          'wallet.device-password.${address.toLowerCase()}',
          legacyDeviceVault['password'] as String,
        );
        await store.delete('wallet.device-vault.${address.toLowerCase()}');

        await security.saveMnemonic(
          store: store,
          walletAddress: address,
          mnemonic: phrase,
          password: password,
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
        expect(
          await security.hasPasswordProtection(
            store: store,
            walletAddress: address,
          ),
          isTrue,
        );
      },
    );

    test(
      'restores legacy device unlock if password migration write fails',
      () async {
        final security = WalletSecurity();
        final store = _FailVaultWriteStore(
          'wallet.vault.${address.toLowerCase()}',
        );
        const phrase =
            'abandon abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon about';
        await security.saveMnemonicWithDeviceProtection(
          store: store,
          walletAddress: address,
          mnemonic: phrase,
        );
        final deviceRecord =
            jsonDecode(
                  (await store.read(
                    'wallet.device-vault.${address.toLowerCase()}',
                  ))!,
                )
                as Map<String, dynamic>;
        await store.write(
          'wallet.vault.${address.toLowerCase()}',
          deviceRecord['record'] as String,
        );
        await store.write(
          'wallet.device-password.${address.toLowerCase()}',
          deviceRecord['password'] as String,
        );
        await store.delete('wallet.device-vault.${address.toLowerCase()}');
        store.failNextVaultWrite = true;

        await expectLater(
          security.saveMnemonic(
            store: store,
            walletAddress: address,
            mnemonic: phrase,
            password: password,
          ),
          throwsStateError,
        );
        expect(
          await security.unlockMnemonicWithDeviceProtection(
            store: store,
            walletAddress: address,
          ),
          phrase,
        );
        expect(
          await security.hasPasswordProtection(
            store: store,
            walletAddress: address,
          ),
          isFalse,
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

class _FailVaultWriteStore extends InMemoryWalletSecretStore {
  _FailVaultWriteStore(this.failedKey);

  final String failedKey;
  bool failNextVaultWrite = false;

  @override
  Future<void> write(String key, String value) async {
    await super.write(key, value);
    if (key == failedKey && failNextVaultWrite) {
      failNextVaultWrite = false;
      throw StateError('simulated secure-store write failure');
    }
  }
}
