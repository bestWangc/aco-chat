import 'dart:convert';
import 'dart:typed_data';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

const _forceUpdateMessage = '当前版本过低，请更新后继续使用。';

class AccountApiException implements Exception {
  const AccountApiException(this.statusCode, String message)
    : message = statusCode == 426 ? _forceUpdateMessage : message;

  final int statusCode;
  final String message;

  /// User-facing copy for API errors. The API may return English or internal
  /// validation text; keep the raw [message] for logging and map it at the UI
  /// boundary so dialogs remain consistently Chinese.
  String get localizedMessage {
    final normalized = message.trim().toLowerCase();
    if (normalized == 'username is already taken' ||
        normalized == 'username already taken') {
      return '用户名已被占用，请换一个用户名。';
    }
    if (normalized.contains('username') &&
        (normalized.contains('taken') ||
            normalized.contains('already exists'))) {
      return '用户名已被占用，请换一个用户名。';
    }
    if (normalized.contains('nickname') && normalized.contains('already')) {
      return '昵称已被占用，请换一个昵称。';
    }
    if (normalized.contains('invalid username')) return '用户名格式不正确。';
    if (normalized.contains('unauthorized') || statusCode == 401) {
      return '登录状态已失效，请重新登录。';
    }
    if (statusCode == 403) return '没有权限执行此操作。';
    if (statusCode == 404) return '请求的内容不存在。';
    if (statusCode >= 500) return '服务器暂时不可用，请稍后重试。';
    return message.isEmpty ? '操作失败，请稍后重试。' : message;
  }

  @override
  String toString() => 'AccountApiException($statusCode): $message';
}

/// HTTP gateway for the account endpoints. Supply [baseUri] in development or
/// tests; the production default is [AppConfig.apiBaseUrl].
class AccountApiClient {
  static const _clientHeaders = <String, String>{
    'content-type': 'application/json',
    'x-app-version': AppConfig.appVersion,
  };

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
      headers: _clientHeaders,
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
      headers: _clientHeaders,
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return _body(response)['challenge'] as String;
  }

  Future<WalletLoginResult> silentWalletLogin(String walletAddress) async {
    final response = await _httpClient.post(
      _uri('auth/wallet-silent-login'),
      headers: _clientHeaders,
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return WalletLoginResult.fromJson(_body(response));
  }

  Future<AccountRefreshResult> refreshAccessToken(String refreshToken) async {
    final response = await _httpClient.post(
      _uri('auth/refresh'),
      headers: _clientHeaders,
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return AccountRefreshResult.fromJson(_body(response));
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
      ..headers['x-app-version'] = AppConfig.appVersion
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
    String? joinPassword,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/room'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'join_password': joinPassword ?? ''}),
    );
    return LiveRoom.fromJson(_body(response));
  }

  Future<LiveKitJoinInfo> getLiveKitJoinInfo({
    required int liveId,
    required String token,
    String? joinPassword,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/join-token'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'join_password': joinPassword ?? ''}),
    );
    return LiveKitJoinInfo.fromJson(_body(response));
  }

  Future<String> createLiveWebsocketTicket({
    required int liveId,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/ws-ticket'),
      headers: _authorizedHeaders(token),
    );
    return _body(response)['ticket'] as String;
  }

  Future<void> leaveLive({required int liveId, required String token}) =>
      _postWithoutBody('lives/$liveId/leave', token);

  Future<void> raiseLiveHand({required int liveId, required String token}) =>
      _postWithoutBody('lives/$liveId/raise-hand', token);

  Future<List<LiveParticipant>> listRaisedLiveHands({
    required int liveId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('lives/$liveId/raised-hands'),
      headers: _authorizedHeaders(token),
    );
    return (_body(response)['raised_hands'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LiveParticipant.fromJson)
        .toList(growable: false);
  }

  Future<List<LiveParticipant>> listLiveHostTransferCandidates({
    required int liveId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('lives/$liveId/host-transfer-candidates'),
      headers: _authorizedHeaders(token),
    );
    return (_body(response)['transfer_candidates'] as List<dynamic>? ??
            const [])
        .cast<Map<String, dynamic>>()
        .map(LiveParticipant.fromJson)
        .toList(growable: false);
  }

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

  /// Lightweight HTTP keep-alive sent by the host while presenting a live.
  /// Unlike the realtime WebSocket pong, it survives app suspension and
  /// flaky connections, so the server does not auto-end the live.
  Future<void> sendLiveHeartbeat({
    required int liveId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/heartbeat', token);

  Future<void> setLiveAudioMute({
    required int liveId,
    required bool muted,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/mute-all'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'muted': muted}),
    );
    _body(response);
  }

  Future<void> setLiveParticipantMute({
    required int liveId,
    required bool muted,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/mute'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'muted': muted}),
    );
    _body(response);
  }

  Future<void> setLiveSpeakerMute({
    required int liveId,
    required int userId,
    required bool muted,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/speakers/$userId/mute'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'muted': muted}),
    );
    _body(response);
  }

  Future<void> setLiveChatMute({
    required int liveId,
    required bool muted,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/chat-mute'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'muted': muted}),
    );
    _body(response);
  }

  Future<void> startLiveCheckIn({
    required int liveId,
    required int durationSeconds,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/check-ins'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'duration_seconds': durationSeconds}),
    );
    _body(response);
  }

  Future<void> confirmLiveCheckIn({
    required int liveId,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/check-ins/current'),
      headers: _authorizedHeaders(token),
    );
    _body(response);
  }

  Future<String> exportLiveCheckIns({
    required int liveId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('lives/$liveId/check-ins/export'),
      headers: _authorizedHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _body(response);
    }
    return response.body;
  }

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
    ..._clientHeaders,
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
