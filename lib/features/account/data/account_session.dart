import 'dart:convert';
import 'dart:typed_data';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the server account currently associated with this device.
class AccountSession {
  AccountSession(this._apiClient, {AccountTokenStore? tokenStore})
    : _tokenStore = tokenStore ?? SecureAccountTokenStore();

  static String get activeAccountKey =>
      'account.active.${const AppConfig().accountStorageScope}';
  final AccountApiClient _apiClient;
  final AccountTokenStore _tokenStore;

  /// Finds the account for [walletAddress]. The server creates its profile
  /// when the address is first seen.
  Future<WalletLoginResult> signInForWallet({
    required String walletAddress,
    required String mnemonic,
  }) async {
    final challenge = await _apiClient.walletChallenge(walletAddress);
    final request = _WalletLoginProofRequest(
      mnemonic: mnemonic,
      challenge: challenge,
    );
    final proof = kIsWeb
        ? _signWalletLoginChallenge(request)
        : await compute(_signWalletLoginChallenge, request);
    final result = await _apiClient.walletLogin(
      walletAddress: walletAddress,
      proof: proof,
    );
    await _tokenStore.write(result.tokens);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      activeAccountKey,
      jsonEncode(result.user.toJson()),
    );
    return result;
  }

  /// Restores an existing wallet account without requiring an access token.
  Future<WalletLoginResult> signInSilently(String walletAddress) async {
    final result = await _apiClient.silentWalletLogin(walletAddress);
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
      final refreshed = await _apiClient.refreshAccessToken(
        tokens.refreshToken,
      );
      await _tokenStore.write(refreshed.tokens);
      final profile = refreshed.user;
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

  /// Lists lives when an account is available.
  ///
  /// The square/live feed is also reachable while the app is still restoring
  /// the wallet session. Treat that transient unauthenticated state as an
  /// empty feed instead of surfacing a programming-error StateError.
  Future<List<LiveSession>> listLives() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return const <LiveSession>[];
    return _apiClient.listLives(token: tokens.accessToken);
  }

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

  Future<LiveRoom> liveRoom(int liveId, {String? joinPassword}) async =>
      _apiClient.getLiveRoom(
        liveId: liveId,
        joinPassword: joinPassword,
        token: await _requireToken(),
      );

  Future<LiveKitJoinInfo> liveKitJoinInfo(
    int liveId, {
    String? joinPassword,
  }) async => _apiClient.getLiveKitJoinInfo(
    liveId: liveId,
    joinPassword: joinPassword,
    token: await _requireToken(),
  );

  Future<String> liveWebsocketTicket(int liveId) async => _apiClient
      .createLiveWebsocketTicket(liveId: liveId, token: await _requireToken());

  Future<void> leaveLive(int liveId) async =>
      _apiClient.leaveLive(liveId: liveId, token: await _requireToken());

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

  Future<void> transferLiveHost(int liveId, int userId) async =>
      _apiClient.transferLiveHost(
        liveId: liveId,
        userId: userId,
        token: await _requireToken(),
      );

  Future<void> endLive(int liveId) async =>
      _apiClient.endLive(liveId: liveId, token: await _requireToken());

  Future<void> setLiveAudioMute(int liveId, bool muted) async =>
      _apiClient.setLiveAudioMute(
        liveId: liveId,
        muted: muted,
        token: await _requireToken(),
      );

  Future<void> setLiveParticipantMute(int liveId, bool muted) async =>
      _apiClient.setLiveParticipantMute(
        liveId: liveId,
        muted: muted,
        token: await _requireToken(),
      );

  Future<void> setLiveSpeakerMute(int liveId, int userId, bool muted) async =>
      _apiClient.setLiveSpeakerMute(
        liveId: liveId,
        userId: userId,
        muted: muted,
        token: await _requireToken(),
      );

  Future<void> setLiveChatMute(int liveId, bool muted) async =>
      _apiClient.setLiveChatMute(
        liveId: liveId,
        muted: muted,
        token: await _requireToken(),
      );

  Future<void> startLiveCheckIn(int liveId, int durationSeconds) async =>
      _apiClient.startLiveCheckIn(
        liveId: liveId,
        durationSeconds: durationSeconds,
        token: await _requireToken(),
      );
  Future<void> confirmLiveCheckIn(int liveId) async => _apiClient
      .confirmLiveCheckIn(liveId: liveId, token: await _requireToken());

  Future<String> exportLiveCheckIns(int liveId) async => _apiClient
      .exportLiveCheckIns(liveId: liveId, token: await _requireToken());

  Future<String> _requireToken() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) throw StateError('No access token is available');
    return tokens.accessToken;
  }
}

class _WalletLoginProofRequest {
  const _WalletLoginProofRequest({
    required this.mnemonic,
    required this.challenge,
  });

  final String mnemonic;
  final String challenge;
}

WalletLoginProof _signWalletLoginChallenge(_WalletLoginProofRequest request) =>
    WalletIdentity.signLoginChallenge(
      mnemonic: request.mnemonic,
      challenge: request.challenge,
    );
