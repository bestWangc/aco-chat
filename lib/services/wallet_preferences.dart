import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredWallet {
  const StoredWallet({required this.identity, required this.name});

  final WalletIdentity identity;
  final String name;
}

class WalletPreferences {
  static const walletNameMaxLength = 12;
  static const configuredKey = 'wallet.configured';
  static const walletIdentityKey = 'wallet.identity';
  static const walletIdentitiesKey = 'wallet.identities';
  static const _derivedAddressesKeyPrefix = 'wallet.derived-addresses.';
  static const _walletNameKeyPrefix = 'wallet.name.';

  static Future<bool> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(configuredKey) ?? false;
  }

  static Future<void> save(bool configured) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(configuredKey, configured);
  }

  static Future<WalletIdentity?> walletIdentity() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(walletIdentityKey);
    if (encoded == null) return null;
    try {
      return WalletIdentity.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Returns every wallet saved on this device in its original order.
  /// The single-wallet key is retained for backwards compatibility.
  static Future<List<WalletIdentity>> walletIdentities({
    WalletIdentity? fallback,
  }) async {
    final preferences = await _loadPreferences();
    if (preferences == null) return fallback == null ? const [] : [fallback];
    return _readWalletIdentities(preferences);
  }

  /// Reads wallet identities and their saved display names from one preference
  /// snapshot, keeping list updates consistent while the active wallet changes.
  static Future<List<StoredWallet>> storedWallets({
    WalletIdentity? fallback,
  }) async {
    final preferences = await _loadPreferences();
    if (preferences == null) {
      if (fallback == null) return const [];
      return [StoredWallet(identity: fallback, name: 'Wallet1')];
    }
    final identities = _readWalletIdentities(preferences);
    return List.generate(identities.length, (index) {
      final identity = identities[index];
      final name = preferences.getString(_walletNameKey(identity));
      return StoredWallet(
        identity: identity,
        name: _normalizeWalletName(name ?? 'Wallet${index + 1}'),
      );
    });
  }

  static Future<SharedPreferences?> _loadPreferences() async {
    try {
      return await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      return null;
    }
  }

  static List<WalletIdentity> _readWalletIdentities(
    SharedPreferences preferences,
  ) {
    final encoded = preferences.getString(walletIdentitiesKey);
    WalletIdentity? current;
    final currentEncoded = preferences.getString(walletIdentityKey);
    if (currentEncoded != null) {
      try {
        current = WalletIdentity.fromJson(
          jsonDecode(currentEncoded) as Map<String, dynamic>,
        );
      } on FormatException {
        // Ignore malformed legacy data.
      } on TypeError {
        // Ignore malformed legacy data.
      }
    }
    final identities = <WalletIdentity>[];
    if (encoded != null) {
      try {
        final values = jsonDecode(encoded) as List<dynamic>;
        for (final value in values) {
          if (value is Map<String, dynamic>) {
            identities.add(WalletIdentity.fromJson(value));
          }
        }
      } on FormatException {
        // Fall through to the legacy identity below.
      } on TypeError {
        // Fall through to the legacy identity below.
      }
    }
    final active = current;
    if (active != null &&
        !identities.any((item) => _sameAddress(item, active))) {
      identities.insert(0, active);
    }
    return identities;
  }

  static Future<void> saveWalletIdentity(WalletIdentity identity) async {
    final preferences = await SharedPreferences.getInstance();
    final identities = _readWalletIdentities(preferences);
    final existingIndex = identities.indexWhere(
      (item) => _sameAddress(item, identity),
    );
    if (existingIndex >= 0) {
      identities[existingIndex] = identity;
    } else {
      identities.add(identity);
    }
    await preferences.setString(
      walletIdentitiesKey,
      jsonEncode(identities.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      walletIdentityKey,
      jsonEncode(identity.toJson()),
    );
  }

  static Future<String> walletName(
    WalletIdentity identity, {
    String fallback = 'Wallet1',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return _normalizeWalletName(
      preferences.getString(_walletNameKey(identity)) ?? fallback,
    );
  }

  static Future<String> saveWalletName(
    WalletIdentity identity,
    String name,
  ) async {
    final normalizedName = _normalizeWalletName(name);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_walletNameKey(identity), normalizedName);
    return normalizedName;
  }

  static Future<Map<String, String>> derivedAddresses(
    WalletIdentity identity,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_derivedAddressesKey(identity));
    if (encoded == null) return const {};
    try {
      return (jsonDecode(encoded) as Map<String, dynamic>).map(
        (chain, address) => MapEntry(chain, address as String),
      );
    } on FormatException {
      return const {};
    } on TypeError {
      return const {};
    }
  }

  static Future<void> saveDerivedAddresses(
    WalletIdentity identity,
    Map<String, String> addresses,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _derivedAddressesKey(identity),
      jsonEncode(addresses),
    );
  }

  static Future<void> removeLegacyPlaceholderData() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(walletIdentityKey) != null ||
        preferences.getString(walletIdentitiesKey) != null) {
      return;
    }
    await preferences.remove('wallet.address');
    await preferences.remove(configuredKey);
  }

  static bool _sameAddress(WalletIdentity left, WalletIdentity right) =>
      left.address.toLowerCase() == right.address.toLowerCase();

  static String _derivedAddressesKey(WalletIdentity identity) =>
      '$_derivedAddressesKeyPrefix${identity.address.toLowerCase()}';

  static String _walletNameKey(WalletIdentity identity) =>
      '$_walletNameKeyPrefix${identity.address.toLowerCase()}';

  static String _normalizeWalletName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Wallet1';
    if (trimmed.length <= walletNameMaxLength) return trimmed;
    return trimmed.substring(0, walletNameMaxLength);
  }
}
