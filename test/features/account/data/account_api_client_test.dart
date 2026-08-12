import 'dart:convert';

import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts a signed wallet login with the server contract', () async {
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((request) async {
        requestUri = request.url;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return response({
          'created': true,
          'access_token': 'signed-token',
          'refresh_token': 'refresh-token',
          'user': {
            'account_id': 'aco_account',
            'username': 'aco_1234',
            'nickname': 'Aco 1234',
          },
        });
      }),
    );

    final result = await client.walletLogin(
      walletAddress: '0xabc',
      proof: const WalletLoginProof(
        challenge: 'challenge',
        publicKey: 'public-key',
        signature: 'signature',
      ),
    );

    expect(requestUri.path, '/api/v1/auth/wallet-login');
    expect(requestBody, {
      'wallet_address': '0xabc',
      'challenge': 'challenge',
      'public_key': 'public-key',
      'signature': 'signature',
    });
    expect(result.created, isTrue);
    expect(result.tokens.accessToken, 'signed-token');
    expect(result.user.accountId, 'aco_account');
  });

  test('uses the account id to add and list wallet addresses', () async {
    final requests = <Uri>[];
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1/'),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        if (request.method == 'POST') {
          expect(request.headers['authorization'], 'Bearer signed-token');
          expect(jsonDecode(request.body), {'wallet_address': '0xdef'});
          return response({
            'id': 8,
            'account_id': 'aco_account',
            'wallet_address': '0xdef',
          }, statusCode: 201);
        }
        return response({
          'data': [
            {'id': 7, 'user_id': 1, 'address': '0xabc'},
            {'id': 8, 'user_id': 1, 'address': '0xdef'},
          ],
        });
      }),
    );

    final added = await client.addWallet(
      accountId: 'aco_account',
      walletAddress: '0xdef',
      token: 'signed-token',
    );
    final wallets = await client.listWallets(
      accountId: 'aco_account',
      token: 'signed-token',
    );

    expect(added.address, '0xdef');
    expect(wallets.map((wallet) => wallet.address), ['0xabc', '0xdef']);
    expect(requests.map((request) => request.path), [
      '/api/v1/accounts/aco_account/wallets',
      '/api/v1/accounts/aco_account/wallets',
    ]);
  });

  test('patches the current profile with the access token', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        return response({
          'user': {
            'account_id': 'aco_account',
            'username': 'aco_updated',
            'nickname': 'Aco Updated',
          },
        });
      }),
    );

    final profile = await client.updateProfile(
      username: 'aco_updated',
      nickname: 'Aco Updated',
      token: 'signed-token',
    );

    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/v1/auth/me');
    expect(request.headers['authorization'], 'Bearer signed-token');
    expect(jsonDecode(request.body), {
      'username': 'aco_updated',
      'nickname': 'Aco Updated',
    });
    expect(profile.nickname, 'Aco Updated');
  });

  test('lists live sessions with the active access token', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        return response({
          'data': [
            {
              'id': 9,
              'title': '真实直播主题',
              'cover_url': '/uploads/live-cover-9.jpg',
              'access': 'open',
              'status': 'live',
              'created_at': '2026-08-12T08:30:00Z',
            },
          ],
        });
      }),
    );

    final lives = await client.listLives(token: 'signed-token');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/lives');
    expect(request.headers['authorization'], 'Bearer signed-token');
    expect(lives.single.title, '真实直播主题');
    expect(lives.single.coverUrl, '/uploads/live-cover-9.jpg');
    expect(lives.single.status, 'live');
  });

  test('sends and incrementally loads live messages', () async {
    final requests = <http.Request>[];
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {'text': '大家好 👋'});
          return response({
            'id': 8,
            'nickname': 'Aco',
            'text': '大家好 👋',
            'created_at': '2026-08-12T08:30:00Z',
          }, statusCode: 201);
        }
        return response({
          'data': [
            {
              'id': 9,
              'nickname': 'Mia',
              'text': '欢迎',
              'created_at': '2026-08-12T08:31:00Z',
            },
          ],
        });
      }),
    );

    final created = await client.createLiveMessage(
      liveId: 7,
      text: '大家好 👋',
      token: 'signed-token',
    );
    final messages = await client.listLiveMessages(
      liveId: 7,
      after: created.id,
      token: 'signed-token',
    );

    expect(created.text, '大家好 👋');
    expect(messages.single.nickname, 'Mia');
    expect(requests.map((request) => request.url.path), [
      '/api/v1/lives/7/messages',
      '/api/v1/lives/7/messages',
    ]);
    expect(requests.last.url.queryParameters['after'], '8');
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer signed-token',
      ),
      isTrue,
    );
  });
}

http.Response response(Map<String, dynamic> body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
