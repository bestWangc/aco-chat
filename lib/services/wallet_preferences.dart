import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Returns every wallet saved on this device, with the active wallet first.
  /// The single-wallet key is retained for backwards compatibility.
  static Future<List<WalletIdentity>> walletIdentities({
    WalletIdentity? fallback,
  }) async {
    late SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
    } on TimeoutException {
      return fallback == null ? const [] : [fallback];
    }
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
    if (active != null) {
      identities.sort((a, b) {
        if (_sameAddress(a, active)) return -1;
        if (_sameAddress(b, active)) return 1;
        return 0;
      });
    }
    return identities;
  }

  static Future<void> saveWalletIdentity(WalletIdentity identity) async {
    final preferences = await SharedPreferences.getInstance();
    final identities = await walletIdentities();
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
