import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_identity_store.dart';
import 'package:aco_chat/services/wallet_metadata_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredWallet {
  const StoredWallet({required this.identity, required this.name});

  final WalletIdentity identity;
  final String name;
}

class WalletPreferences {
  static const walletNameMaxLength = WalletMetadataStore.walletNameMaxLength;
  static const configuredKey = WalletIdentityStore.configuredKey;
  static const walletIdentityKey = WalletIdentityStore.walletIdentityKey;
  static const walletIdentitiesKey = WalletIdentityStore.walletIdentitiesKey;
  static final _metadataStore = WalletMetadataStore();
  static final _identityStore = WalletIdentityStore();

  static Future<bool> load() => _identityStore.isConfigured();

  static Future<void> save(bool configured) =>
      _identityStore.saveConfigured(configured);

  static Future<WalletIdentity?> walletIdentity() =>
      _identityStore.activeIdentity();

  /// Returns every wallet saved on this device in its original order.
  /// The single-wallet key is retained for backwards compatibility.
  static Future<List<WalletIdentity>> walletIdentities({
    WalletIdentity? fallback,
  }) async {
    return _identityStore.identities(fallback: fallback);
  }

  /// Reads wallet identities and their saved display names from one preference
  /// snapshot, keeping list updates consistent while the active wallet changes.
  static Future<List<StoredWallet>> storedWallets({
    WalletIdentity? fallback,
  }) async {
    final identities = await _identityStore.identities(fallback: fallback);
    if (identities.isEmpty) return const [];
    final preferences = await SharedPreferences.getInstance();
    return List.generate(identities.length, (index) {
      final identity = identities[index];
      final name = preferences.getString(_walletNameKey(identity));
      return StoredWallet(
        identity: identity,
        name: _normalizeWalletName(name ?? 'Wallet${index + 1}'),
      );
    });
  }

  static Future<void> saveWalletIdentity(WalletIdentity identity) =>
      _identityStore.saveIdentity(identity);

  static Future<String> walletName(
    WalletIdentity identity, {
    String fallback = 'Wallet1',
  }) => _metadataStore.walletName(identity, fallback: fallback);

  static Future<String> saveWalletName(WalletIdentity identity, String name) =>
      _metadataStore.saveWalletName(identity, name);

  static Future<Map<String, String>> derivedAddresses(
    WalletIdentity identity,
  ) => _metadataStore.derivedAddresses(identity);

  static Future<void> saveDerivedAddresses(
    WalletIdentity identity,
    Map<String, String> addresses,
  ) => _metadataStore.saveDerivedAddresses(identity, addresses);

  static Future<void> removeLegacyPlaceholderData() =>
      _identityStore.removeLegacyPlaceholderData();

  static String _walletNameKey(WalletIdentity identity) =>
      'wallet.name.${identity.address.toLowerCase()}';

  static String _normalizeWalletName(String name) {
    return WalletMetadataStore.normalizeWalletName(name);
  }
}
