import 'dart:convert';
import 'dart:typed_data';

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

  /// Updates the server profile and keeps the local active profile in sync.
  Future<AccountProfile> updateProfile({
    required String username,
    required String nickname,
  }) async {
    final profile = await _apiClient.updateProfile(
      username: username,
      nickname: nickname,
      token: await _requireToken(),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(activeAccountKey, jsonEncode(profile.toJson()));
    return profile;
  }

  Future<AccountProfile?> activeProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(activeAccountKey);
    if (value == null) return null;
    return AccountProfile.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<List<LiveSession>> listLives() async =>
      _apiClient.listLives(token: await _requireToken());

  Future<LiveSession> createLive({
    required String title,
    required Uint8List coverBytes,
    required String access,
    String? joinPassword,
    DateTime? scheduledAt,
  }) async {
    final token = await _requireToken();
    final coverUrl = await _apiClient.uploadLiveCover(
      bytes: coverBytes,
      token: token,
    );
    return _apiClient.createLive(
      title: title,
      coverUrl: coverUrl,
      access: access,
      joinPassword: joinPassword,
      scheduledAt: scheduledAt,
      token: token,
    );
  }

  Future<LiveSession> updateLive({
    required int liveId,
    required String title,
    required String coverUrl,
    Uint8List? coverBytes,
    required String access,
    String? joinPassword,
    DateTime? scheduledAt,
  }) async {
    final token = await _requireToken();
    final resolvedCoverUrl = coverBytes == null
        ? coverUrl
        : await _apiClient.uploadLiveCover(bytes: coverBytes, token: token);
    return _apiClient.updateLive(
      liveId: liveId,
      title: title,
      coverUrl: resolvedCoverUrl,
      access: access,
      joinPassword: joinPassword,
      scheduledAt: scheduledAt,
      token: token,
    );
  }

  Future<List<LiveMessage>> listLiveMessages(int liveId, {int? after}) async =>
      _apiClient.listLiveMessages(
        liveId: liveId,
        after: after,
        token: await _requireToken(),
      );

  Future<LiveMessage> createLiveMessage({
    required int liveId,
    required String text,
  }) async => _apiClient.createLiveMessage(
    liveId: liveId,
    text: text,
    token: await _requireToken(),
  );

  Future<LiveRoom> liveRoom(int liveId) async =>
      _apiClient.getLiveRoom(liveId: liveId, token: await _requireToken());

  Future<void> raiseLiveHand(int liveId) async =>
      _apiClient.raiseLiveHand(liveId: liveId, token: await _requireToken());

  Future<void> approveLiveSpeaker(int liveId, int userId) async =>
      _apiClient.approveLiveSpeaker(
        liveId: liveId,
        userId: userId,
        token: await _requireToken(),
      );

  Future<void> removeLiveSpeaker(int liveId, int userId) async =>
      _apiClient.removeLiveSpeaker(
        liveId: liveId,
        userId: userId,
        token: await _requireToken(),
      );

  Future<void> endLive(int liveId) async =>
      _apiClient.endLive(liveId: liveId, token: await _requireToken());

  Future<String> _requireToken() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) throw StateError('No access token is available');
    return tokens.accessToken;
  }
}
