import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists display-only wallet metadata separately from wallet identities.
class WalletMetadataStore {
  static const walletNameMaxLength = 12;
  static const _derivedAddressesKeyPrefix = 'wallet.derived-addresses.';
  static const _walletNameKeyPrefix = 'wallet.name.';

  Future<String> walletName(
    WalletIdentity identity, {
    String fallback = 'Wallet1',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return normalizeWalletName(
      preferences.getString(_walletNameKey(identity)) ?? fallback,
    );
  }

  Future<String> saveWalletName(WalletIdentity identity, String name) async {
    final normalizedName = normalizeWalletName(name);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_walletNameKey(identity), normalizedName);
    return normalizedName;
  }

  Future<Map<String, String>> derivedAddresses(WalletIdentity identity) async {
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

  Future<void> saveDerivedAddresses(
    WalletIdentity identity,
    Map<String, String> addresses,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _derivedAddressesKey(identity),
      jsonEncode(addresses),
    );
  }

  static String normalizeWalletName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Wallet1';
    if (trimmed.length <= walletNameMaxLength) return trimmed;
    return trimmed.substring(0, walletNameMaxLength);
  }

  static String _derivedAddressesKey(WalletIdentity identity) =>
      '$_derivedAddressesKeyPrefix${identity.address.toLowerCase()}';

  static String _walletNameKey(WalletIdentity identity) =>
      '$_walletNameKeyPrefix${identity.address.toLowerCase()}';
}
