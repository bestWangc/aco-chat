import 'dart:convert';

import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the server account currently associated with this device.
class AccountSession {
  AccountSession(this._apiClient, {AccountTokenStore? tokenStore})
    : _tokenStore = tokenStore ?? SecureAccountTokenStore();

  static const activeAccountKey = 'account.active';
  final AccountApiClient _apiClient;
  final AccountTokenStore _tokenStore;

  /// Finds the account for [walletAddress]. The server creates its profile
  /// when the address is first seen.
  Future<WalletLoginResult> signInForWallet({
    required String walletAddress,
    required String mnemonic,
  }) async {
    final challenge = await _apiClient.walletChallenge(walletAddress);
    final result = await _apiClient.walletLogin(
      walletAddress: walletAddress,
      proof: WalletIdentity.signLoginChallenge(
        mnemonic: mnemonic,
        challenge: challenge,
      ),
    );
    await _tokenStore.write(result.tokens);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      activeAccountKey,
      jsonEncode(result.user.toJson()),
    );
    return result;
  }

  /// Restores the server profile after silently rotating the refresh token.
  Future<AccountProfile?> restoreProfile() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    try {
      final refreshedTokens = await _apiClient.refreshAccessToken(
        tokens.refreshToken,
      );
      await _tokenStore.write(refreshedTokens);
      final profile = await _apiClient.currentProfile(
        token: refreshedTokens.accessToken,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        activeAccountKey,
        jsonEncode(profile.toJson()),
      );
      return profile;
    } on AccountApiException catch (error) {
      if (error.statusCode == 401) {
        await _tokenStore.clear();
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove(activeAccountKey);
      }
      return null;
    }
  }

  /// Links a further wallet address to the signed-in account.
  Future<WalletAddress> addWallet(String walletAddress) async {
    final profile = await activeProfile();
    if (profile == null) {
      throw StateError('No active account is available to add a wallet');
    }
    final token = await _requireToken();
    return _apiClient.addWallet(
      accountId: profile.accountId,
      walletAddress: walletAddress,
      token: token,
    );
  }

  Future<AccountProfile?> activeProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(activeAccountKey);
    if (value == null) return null;
    return AccountProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<String> _requireToken() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) throw StateError('No access token is available');
    return tokens.accessToken;
  }
}
