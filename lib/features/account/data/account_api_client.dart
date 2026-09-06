import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _forceUpdateMessage = '当前版本过低，请更新后继续使用。';

class AccountApiException implements Exception {
  const AccountApiException(this.statusCode, String message)
    : message = statusCode == 426 ? _forceUpdateMessage : message;

  final int statusCode;
  final String message;

  String get _normalizedMessage => message.trim().toLowerCase();

  bool get isLiveKick {
    final normalized = _normalizedMessage;
    return normalized.contains('removed from this live') ||
        normalized.contains('kicked from this live');
  }

  bool get isLiveParticipantMissing =>
      _normalizedMessage.contains('participant is not in live room');

  /// User-facing copy for API errors. The API may return English or internal
  /// validation text; keep the raw [message] for logging and map it at the UI
  /// boundary so dialogs remain consistently Chinese.
  String get localizedMessage {
    final normalized = _normalizedMessage;
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
    if (normalized == 'invalid live password' ||
        normalized.contains('live password')) {
      return '会议密码错误，请重新输入。';
    }
    if (normalized.contains('live is not currently active')) {
      return '该会议当前未开始或已结束。';
    }
    if (normalized == 'avatar image is required') return '请选择头像图片。';
    if (normalized.contains('avatar image must be') &&
        normalized.contains('2 mb')) {
      return '头像图片不能超过 2 MB。';
    }
    if (normalized.contains('avatar image must be') &&
        normalized.contains('jpeg')) {
      return '头像仅支持 JPEG、PNG 或 WebP 格式。';
    }
    if (normalized.contains('cannot read avatar image')) {
      return '头像图片读取失败，请重新选择。';
    }
    if (normalized.contains('cannot save avatar image')) {
      return '头像保存失败，请稍后重试。';
    }
    if (normalized.contains('avatar uploads are not configured')) {
      return '头像上传服务未配置，请联系管理员。';
    }
    if (normalized.contains('cannot update profile')) {
      return '资料更新失败，请稍后重试。';
    }
    if (isLiveKick) {
      return '你已被移出会议，10分钟内不能再次进入。';
    }
    if (isLiveParticipantMissing) {
      return '你已离开会议，请重新进入。';
    }
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
  static String? lastRequest;
  static int? lastStatusCode;
  static String? lastResponseBody;
  static String? lastError;
  static int? lastRequestDurationMilliseconds;
  static String? lastServerTiming;

  static Future<String> runConnectionDiagnostics() async {
    final relayBaseUrl = AppConfig.relayApiBaseUrl;
    final reports = <Future<String>>[
      _runConnectionDiagnostic(
        '主 API',
        Uri.parse(AppConfig.cloudflareApiBaseUrl),
      ),
      relayBaseUrl.isEmpty
          ? Future.value('[国内中转]\n未配置')
          : _runConnectionDiagnostic('国内中转', Uri.parse(relayBaseUrl)),
    ];
    return (await Future.wait(reports)).join('\n\n');
  }

  static Future<String> _runConnectionDiagnostic(
    String routeName,
    Uri baseUri,
  ) async {
    final host = baseUri.host;
    final port = baseUri.hasPort
        ? baseUri.port
        : (baseUri.scheme == 'http' ? 80 : 443);
    final lines = <String>[
      '[$routeName]',
      '目标：${baseUri.scheme}://$host:$port',
    ];
    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 5));
      lines.add(
        'DNS：成功（${addresses.map((address) => address.address).join(', ')}）',
      );
    } on Object catch (error) {
      lines.add('DNS：失败（$error）');
      return lines.join('\n');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final healthUri = baseUri.replace(path: '/healthz', query: '');
    try {
      final request = await client
          .getUrl(healthUri)
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response.transform(utf8.decoder).join();
      lines.add('TLS/TCP：成功');
      lines.add('HTTP：${response.statusCode}');
      if (body.isNotEmpty) lines.add('响应：$body');
    } on HandshakeException catch (error) {
      lines.add('TLS：失败（$error）');
    } on TimeoutException catch (error) {
      lines.add('连接：超时（$error）');
    } on SocketException catch (error) {
      lines.add('TCP：失败（$error）');
    } on Object catch (error) {
      lines.add('连接：失败（$error）');
    } finally {
      client.close(force: true);
    }
    return lines.join('\n');
  }

  static const _clientHeaders = <String, String>{
    'content-type': 'application/json',
    'x-app-version': AppConfig.appVersion,
  };

  AccountApiClient({Uri? baseUri, http.Client? httpClient})
    : _baseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl),
      _httpClient = _RecordingClient(httpClient ?? http.Client()) {
    debugPrint('[API] base URL=$_baseUri appVersion=${AppConfig.appVersion}');
  }

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

  Future<OpenIMToken> openIMToken({
    required String token,
    required int platformId,
  }) async {
    final response = await _httpClient.get(
      _uri(
        'auth/openim-token',
      ).replace(queryParameters: {'platform_id': '$platformId'}),
      headers: _authorizedHeaders(token),
    );
    return OpenIMToken.fromJson(_body(response));
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

  Future<List<FriendContact>> listFriends({required String token}) async {
    final response = await _httpClient.get(
      _uri('friends'),
      headers: _authorizedHeaders(token),
    );
    final items = _body(response)['items'] as List<dynamic>? ?? const [];
    return items
        .cast<Map<String, dynamic>>()
        .map(FriendContact.fromJson)
        .toList(growable: false);
  }

  Future<List<FriendContact>> listFriendRequests({
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('friends/requests'),
      headers: _authorizedHeaders(token),
    );
    final items = _body(response)['items'] as List<dynamic>? ?? const [];
    return items
        .cast<Map<String, dynamic>>()
        .map(FriendContact.fromJson)
        .toList(growable: false);
  }

  Future<AccountProfile> profileByAccountId({
    required String accountId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('users/${Uri.encodeComponent(accountId)}'),
      headers: _authorizedHeaders(token),
    );
    return AccountProfile.fromJson(
      _body(response)['user'] as Map<String, dynamic>,
    );
  }

  Future<void> addFriend({
    required String accountId,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('friends'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'account_id': accountId}),
    );
    _body(response);
  }

  Future<void> acceptFriend({
    required String accountId,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('friends/${Uri.encodeComponent(accountId)}/accept'),
      headers: _authorizedHeaders(token),
    );
    _body(response);
  }

  Future<void> refuseFriend({
    required String accountId,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('friends/${Uri.encodeComponent(accountId)}/request'),
      headers: _authorizedHeaders(token),
    );
    if (response.statusCode != 204) _body(response);
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
    return _body(await _readResponse(response))['url'] as String;
  }

  Future<AccountProfile> uploadAvatar({
    required Uint8List bytes,
    required String token,
  }) async {
    final request = http.MultipartRequest('POST', _uri('uploads/avatars'))
      ..headers['x-app-version'] = AppConfig.appVersion
      ..headers['authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'avatar.jpg'),
      );
    final response = await _httpClient.send(request);
    return AccountProfile.fromJson(
      _body(await _readResponse(response))['user'] as Map<String, dynamic>,
    );
  }

  Future<http.Response> _readResponse(http.StreamedResponse response) async {
    final bytes = await response.stream.toBytes();
    return http.Response.bytes(
      bytes,
      response.statusCode,
      headers: response.headers,
      request: response.request,
      reasonPhrase: response.reasonPhrase,
    );
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
    bool resetRole = false,
  }) async {
    final response = await _httpClient.post(
      _uri('lives/$liveId/room'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({
        'join_password': joinPassword ?? '',
        'reset_role': resetRole,
      }),
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

  Future<LiveMembersPage> listLiveMembers({
    required int liveId,
    required int page,
    required String keyword,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('lives/$liveId/members').replace(
        queryParameters: {
          'page': '$page',
          'page_size': '20',
          'include_total': page == 1 ? 'true' : 'false',
          if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        },
      ),
      headers: _authorizedHeaders(token),
    );
    return LiveMembersPage.fromJson(_body(response));
  }

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

  Future<void> rejectAllRaisedLiveHands({
    required int liveId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/raised-hands/reject-all', token);

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

  Future<void> inviteLiveSpeaker({
    required int liveId,
    required int userId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/speakers/$userId/invite', token);

  Future<void> acceptLiveSpeakerInvite({
    required int liveId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/speaker-invite/accept', token);

  Future<void> declineLiveSpeakerInvite({
    required int liveId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/speaker-invite/decline', token);

  Future<void> removeLiveSpeaker({
    required int liveId,
    required int userId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/speakers/$userId/remove', token);

  Future<void> kickLiveMember({
    required int liveId,
    required int userId,
    required String token,
  }) => _postWithoutBody('lives/$liveId/members/$userId/kick', token);

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
    final diagnosticBody = _redactSensitiveData(response.body);
    lastRequest =
        '${response.request?.method ?? 'UNKNOWN'} ${response.request?.url ?? '<unknown URL>'}';
    lastStatusCode = response.statusCode;
    lastResponseBody = diagnosticBody;
    lastError = response.statusCode >= 400 ? diagnosticBody : null;
    lastServerTiming = response.headers['server-timing'];
    final serverTiming = lastServerTiming;
    debugPrint(
      '[API] ${response.request?.method ?? 'UNKNOWN'} '
      '${response.request?.url ?? '<unknown URL>'} '
      'status=${response.statusCode} '
      'duration=${lastRequestDurationMilliseconds ?? 0}ms '
      '${serverTiming == null ? '' : 'server_timing=[$serverTiming] '}'
      'body=$diagnosticBody',
    );
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

  String _redactSensitiveData(String body) {
    if (body.isEmpty) return body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        _redactMap(decoded);
        return jsonEncode(decoded);
      }
    } on FormatException {
      // Keep non-JSON response text unchanged for diagnostics.
    }
    return body;
  }

  void _redactMap(Map<String, dynamic> values) {
    const sensitiveKeys = {
      'access_token',
      'refresh_token',
      'token',
      'authorization',
      'password',
      'signature',
    };
    for (final entry in values.entries.toList()) {
      if (sensitiveKeys.contains(entry.key.toLowerCase())) {
        values[entry.key] = '[已隐藏]';
      } else if (entry.value is Map<String, dynamic>) {
        _redactMap(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        for (final item in entry.value as List<Object?>) {
          if (item is Map<String, dynamic>) _redactMap(item);
        }
      }
    }
  }
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    AccountApiClient.lastRequest = '${request.method} ${request.url}';
    AccountApiClient.lastStatusCode = null;
    AccountApiClient.lastResponseBody = null;
    AccountApiClient.lastError = null;
    AccountApiClient.lastRequestDurationMilliseconds = null;
    AccountApiClient.lastServerTiming = null;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _inner.send(request);
      stopwatch.stop();
      AccountApiClient.lastStatusCode = response.statusCode;
      AccountApiClient.lastRequestDurationMilliseconds =
          stopwatch.elapsedMilliseconds;
      return response;
    } on Object catch (error) {
      stopwatch.stop();
      final kind = _networkErrorKind(error);
      AccountApiClient.lastError = '$kind：$error';
      AccountApiClient.lastRequestDurationMilliseconds =
          stopwatch.elapsedMilliseconds;
      debugPrint(
        '[API] ${AccountApiClient.lastRequest} '
        'duration=${stopwatch.elapsedMilliseconds}ms error=$error',
      );
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  String _networkErrorKind(Object error) {
    final underlyingError = error is http.ClientException
        ? error.message
        : error.toString();
    final normalizedError = underlyingError.toLowerCase();
    if (error is HandshakeException || normalizedError.contains('handshake')) {
      return 'TLS 握手失败';
    }
    if (error is TimeoutException || normalizedError.contains('timed out')) {
      return '请求超时';
    }
    if (error is SocketException || error is http.ClientException) {
      return '网络连接失败';
    }
    return '网络请求失败';
  }
}
