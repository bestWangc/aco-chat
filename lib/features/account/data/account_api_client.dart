import 'dart:convert';
import 'dart:typed_data';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

class AccountApiException implements Exception {
  const AccountApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'AccountApiException($statusCode): $message';
}

/// HTTP gateway for the account endpoints. Supply [baseUri] in development or
/// tests; the production default is [AppConfig.apiBaseUrl].
class AccountApiClient {
  AccountApiClient({Uri? baseUri, http.Client? httpClient})
    : _baseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl),
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<WalletLoginResult> walletLogin({
    required String walletAddress,
    required WalletLoginProof proof,
  }) async {
    final response = await _httpClient.post(
      _uri('auth/wallet-login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'wallet_address': walletAddress,
        'challenge': proof.challenge,
        'public_key': proof.publicKey,
        'signature': proof.signature,
      }),
    );
    return WalletLoginResult.fromJson(_body(response));
  }

  Future<String> walletChallenge(String walletAddress) async {
    final response = await _httpClient.post(
      _uri('auth/wallet-challenge'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return _body(response)['challenge'] as String;
  }

  Future<AccountTokens> refreshAccessToken(String refreshToken) async {
    final response = await _httpClient.post(
      _uri('auth/refresh'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return AccountTokens.fromJson(_body(response));
  }

  Future<WalletAddress> addWallet({
    required String accountId,
    required String walletAddress,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('accounts/$accountId/wallets'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return WalletAddress.fromJson(_body(response));
  }

  Future<List<WalletAddress>> listWallets({
    required String accountId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('accounts/$accountId/wallets'),
      headers: _authorizedHeaders(token),
    );
    final body = _body(response);
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WalletAddress.fromJson)
        .toList(growable: false);
  }

  Future<AccountProfile> currentProfile({required String token}) async {
    final response = await _httpClient.get(
      _uri('auth/me'),
      headers: _authorizedHeaders(token),
    );
    final body = _body(response);
    return AccountProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<AccountProfile> updateProfile({
    required String username,
    required String nickname,
    required String token,
  }) async {
    final response = await _httpClient.patch(
      _uri('auth/me'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'username': username, 'nickname': nickname}),
    );
    final body = _body(response);
    return AccountProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<List<LiveSession>> listLives({required String token}) async {
    final response = await _httpClient.get(
      _uri('lives'),
      headers: _authorizedHeaders(token),
    );
    final body = _body(response);
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(LiveSession.fromJson)
        .toList(growable: false);
  }

  /// Uploads a selected cover before creating the live session. The API
  /// validates the image format and returns its server-hosted path.
  Future<String> uploadLiveCover({
    required Uint8List bytes,
    required String token,
  }) async {
    final request = http.MultipartRequest('POST', _uri('uploads/live-covers'))
      ..headers['authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'live-cover.jpg'),
      );
    final response = await _httpClient.send(request);
    final body = await response.stream.bytesToString();
    return _body(http.Response(body, response.statusCode))['url'] as String;
  }

  Future<LiveSession> createLive({
    required String title,
    required String coverUrl,
    required String access,
    required String token,
    String? joinPassword,
    DateTime? scheduledAt,
  }) async {
    final body = _livePayload(
      title: title,
      coverUrl: coverUrl,
      access: access,
      joinPassword: joinPassword,
      scheduledAt: scheduledAt,
    );
    final response = await _httpClient.post(
      _uri('lives'),
      headers: _authorizedHeaders(token),
      body: jsonEncode(body),
    );
    return LiveSession.fromJson(_body(response));
  }

  Future<LiveSession> updateLive({
    required int liveId,
    required String title,
    required String coverUrl,
    required String access,
    required String token,
    String? joinPassword,
    DateTime? scheduledAt,
  }) async {
    final body = _livePayload(
      title: title,
      coverUrl: coverUrl,
      access: access,
      joinPassword: joinPassword,
      scheduledAt: scheduledAt,
    );
    final response = await _httpClient.patch(
      _uri('lives/$liveId'),
      headers: _authorizedHeaders(token),
      body: jsonEncode(body),
    );
    return LiveSession.fromJson(_body(response));
  }

  Future<List<LiveMessage>> listLiveMessages({
    required int liveId,
    required String token,
    int? after,
  }) async {
    final response = await _httpClient.get(
      _uri(
        'lives/$liveId/messages',
      ).replace(queryParameters: {if (after != null) 'after': '$after'}),
      headers: _authorizedHeaders(token),
    );
    final body = _body(response);
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(LiveMessage.fromJson)
        .toList(growable: false);
  }

  Future<LiveMessage> createLiveMessage({
    required int liveId,
    required String text,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/messages'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'text': text}),
    );
    return LiveMessage.fromJson(_body(response));
  }

  Future<LiveRoom> getLiveRoom({
    required int liveId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('lives/$liveId/room'),
      headers: _authorizedHeaders(token),
    );
    return LiveRoom.fromJson(_body(response));
  }

  Future<void> raiseLiveHand({required int liveId, required String token}) =>
      _postWithoutBody('lives/$liveId/raise-hand', token);

  Future<void> approveLiveSpeaker({
    required int liveId,
    required int userId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/speakers/$userId/approve', token);

  Future<void> removeLiveSpeaker({
    required int liveId,
    required int userId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/speakers/$userId/remove', token);

  Future<void> transferLiveHost({
    required int liveId,
    required int userId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/host/$userId/transfer', token);

  Future<void> endLive({required int liveId, required String token}) =>
      _postWithoutBody('lives/$liveId/end', token);

  Future<void> muteAllLiveSpeakers({
    required int liveId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/mute-all', token);

  Future<void> _postWithoutBody(String path, String token) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _authorizedHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _body(response);
    }
  }

  void close() => _httpClient.close();

  Uri _uri(String path) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath/$path');
  }

  Map<String, String> _authorizedHeaders(String token) => {
    'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  Map<String, Object?> _livePayload({
    required String title,
    required String coverUrl,
    required String access,
    String? joinPassword,
    DateTime? scheduledAt,
  }) {
    final body = <String, Object?>{
      'title': title,
      'cover_url': coverUrl,
      'access': access,
    };
    if (joinPassword != null) body['join_password'] = joinPassword;
    if (scheduledAt != null) {
      body['scheduled_at'] = scheduledAt.toUtc().toIso8601String();
    }
    return body;
  }

  Map<String, dynamic> _body(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountApiException(
        response.statusCode,
        decoded['error'] as String? ?? 'account request failed',
      );
    }
    return decoded;
  }
}
