import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/services/wallet_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists wallet setup state and the ordered identities stored on device.
class WalletIdentityStore {
  static const configuredKey = 'wallet.configured';
  static const walletIdentityKey = 'wallet.identity';
  static const walletIdentitiesKey = 'wallet.identities';

  Future<bool> isConfigured() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(configuredKey) ?? false;
  }

  Future<void> saveConfigured(bool configured) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(configuredKey, configured);
  }

  Future<WalletIdentity?> activeIdentity() async {
    final preferences = await SharedPreferences.getInstance();
    return _readActiveIdentity(preferences);
  }

  Future<List<WalletIdentity>> identities({WalletIdentity? fallback}) async {
    final preferences = await _loadPreferences();
    if (preferences == null) return fallback == null ? const [] : [fallback];
    return _readIdentities(preferences);
  }

  Future<void> saveIdentity(WalletIdentity identity) async {
    final preferences = await SharedPreferences.getInstance();
    final identities = _readIdentities(preferences);
    final existingIndex = identities.indexWhere(
      (item) => sameAddress(item, identity),
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

  Future<void> removeLegacyPlaceholderData() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(walletIdentityKey) != null ||
        preferences.getString(walletIdentitiesKey) != null) {
      return;
    }
    await preferences.remove('wallet.address');
    await preferences.remove(configuredKey);
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

  static WalletIdentity? _readActiveIdentity(SharedPreferences preferences) {
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

  static List<WalletIdentity> _readIdentities(SharedPreferences preferences) {
    final identities = <WalletIdentity>[];
    final encoded = preferences.getString(walletIdentitiesKey);
    if (encoded != null) {
      try {
        final values = jsonDecode(encoded) as List<dynamic>;
        for (final value in values) {
          if (value is Map<String, dynamic>) {
            identities.add(WalletIdentity.fromJson(value));
          }
        }
      } on FormatException {
        // Fall through to the legacy active identity below.
      } on TypeError {
        // Fall through to the legacy active identity below.
      }
    }
    final active = _readActiveIdentity(preferences);
    if (active != null &&
        !identities.any((item) => sameAddress(item, active))) {
      identities.insert(0, active);
    }
    return identities;
  }

  static bool sameAddress(WalletIdentity left, WalletIdentity right) =>
      left.address.toLowerCase() == right.address.toLowerCase();
}
