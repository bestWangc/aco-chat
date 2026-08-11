import 'dart:convert';

import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the server account currently associated with this device.
class AccountSession {
  const AccountSession(this._apiClient);

  static const activeAccountKey = 'account.active';
  final AccountApiClient _apiClient;

  /// Finds the account for [walletAddress]. The server creates its profile
  /// when the address is first seen.
  Future<WalletLoginResult> signInForWallet({
    required String walletAddress,
  }) async {
    final result = await _apiClient.walletLogin(walletAddress: walletAddress);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      activeAccountKey,
      jsonEncode(result.user.toJson()),
    );
    return result;
  }

  /// Links a further wallet address to the signed-in account.
  Future<WalletAddress> addWallet(String walletAddress) async {
    final profile = await activeProfile();
    if (profile == null) {
      throw StateError('No active account is available to add a wallet');
    }
    return _apiClient.addWallet(
      accountId: profile.accountId,
      walletAddress: walletAddress,
    );
  }

  Future<AccountProfile?> activeProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(activeAccountKey);
    if (value == null) return null;
    return AccountProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }
}
