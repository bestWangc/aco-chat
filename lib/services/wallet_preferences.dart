import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletPreferences {
  static const configuredKey = 'wallet.configured';
  static const walletIdentityKey = 'wallet.identity';

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

  static Future<void> removeLegacyPlaceholderData() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(walletIdentityKey) != null) return;
    await preferences.remove('wallet.address');
    await preferences.remove(configuredKey);
  }
}
