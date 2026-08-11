import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletPreferences {
  static const configuredKey = 'wallet.configured';
  static const walletIdentityKey = 'wallet.identity';
  static const _derivedAddressesKeyPrefix = 'wallet.derived-addresses.';

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

  static Future<void> saveWalletIdentity(WalletIdentity identity) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      walletIdentityKey,
      jsonEncode(identity.toJson()),
    );
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
    if (preferences.getString(walletIdentityKey) != null) return;
    await preferences.remove('wallet.address');
    await preferences.remove(configuredKey);
  }

  static String _derivedAddressesKey(WalletIdentity identity) =>
      '$_derivedAddressesKeyPrefix${identity.address.toLowerCase()}';
}
