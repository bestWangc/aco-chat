import 'dart:convert';

import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_session.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryTokenStore implements AccountTokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AccountTokens?> read() async => value == null
      ? null
      : AccountTokens(accessToken: value!, refreshToken: 'refresh-token');

  @override
  Future<void> write(AccountTokens tokens) async => value = tokens.accessToken;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores the login token and restores the profile with it', () async {
    final tokenStore = _InMemoryTokenStore();
    var requestedProfile = false;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('wallet-challenge')) {
          return _response({'challenge': 'challenge'});
        }
        if (request.url.path.endsWith('wallet-login')) {
          return _response({
            'created': true,
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'user': {
              'account_id': '1000000000000001',
              'username': 'aco_1000000000000001',
              'nickname': 'Aco 000001',
            },
          });
        }
        if (request.url.path.endsWith('refresh')) {
          expect(jsonDecode(request.body), {'refresh_token': 'refresh-token'});
          return _response({
            'access_token': 'rotated-access-token',
            'refresh_token': 'rotated-refresh-token',
          });
        }
        requestedProfile = true;
        expect(request.headers['authorization'], 'Bearer rotated-access-token');
        return _response({
          'user': {
            'account_id': '1000000000000001',
            'username': 'aco_1000000000000001',
            'nickname': 'Aco Updated',
          },
        });
      }),
    );
    final session = AccountSession(client, tokenStore: tokenStore);

    await session.signInForWallet(
      walletAddress: '0xabc',
      mnemonic:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    );
    final profile = await session.restoreProfile();

    expect(tokenStore.value, 'rotated-access-token');
    expect(requestedProfile, isTrue);
    expect(profile?.nickname, 'Aco Updated');
  });

  test('clears tokens when silent refresh is rejected', () async {
    final tokenStore = _InMemoryTokenStore()..value = 'expired-access-token';
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient(
        (_) async => http.Response('{"error":"refresh token is invalid"}', 401),
      ),
    );

    final profile = await AccountSession(
      client,
      tokenStore: tokenStore,
    ).restoreProfile();

    expect(profile, isNull);
    expect(tokenStore.value, isNull);
  });

  test('updates and persists the active profile', () async {
    final tokenStore = _InMemoryTokenStore()..value = 'access-token';
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.headers['authorization'], 'Bearer access-token');
        expect(jsonDecode(request.body), {
          'username': 'aco_updated',
          'nickname': 'Aco Updated',
        });
        return _response({
          'user': {
            'account_id': '1000000000000001',
            'username': 'aco_updated',
            'nickname': 'Aco Updated',
          },
        });
      }),
    );
    final session = AccountSession(client, tokenStore: tokenStore);

    final profile = await session.updateProfile(
      username: 'aco_updated',
      nickname: 'Aco Updated',
    );

    expect(profile.username, 'aco_updated');
    expect((await session.activeProfile())?.nickname, 'Aco Updated');
  });

  test(
    'updates a live session without re-uploading an unchanged cover',
    () async {
      final tokenStore = _InMemoryTokenStore()..value = 'access-token';
      final requests = <http.Request>[];
      final client = AccountApiClient(
        baseUri: Uri.parse('https://api.aco.test/api/v1'),
        httpClient: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/lives/9');
          expect(jsonDecode(request.body), {
            'title': '更新后的直播',
            'cover_url': '/uploads/live-cover-9.jpg',
            'access': 'open',
            'scheduled_at': '2026-08-12T13:00:00.000Z',
          });
          return _response({
            'id': 9,
            'title': '更新后的直播',
            'cover_url': '/uploads/live-cover-9.jpg',
            'access': 'open',
            'status': 'scheduled',
            'can_edit': true,
            'scheduled_at': '2026-08-12T13:00:00Z',
            'created_at': '2026-08-12T08:30:00Z',
          });
        }),
      );

      final live = await AccountSession(client, tokenStore: tokenStore)
          .updateLive(
            liveId: 9,
            title: '更新后的直播',
            coverUrl: '/uploads/live-cover-9.jpg',
            access: 'open',
            scheduledAt: DateTime.utc(2026, 8, 12, 13),
          );

      expect(live.canEdit, isTrue);
      expect(requests, hasLength(1));
    },
  );
}

http.Response _response(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
