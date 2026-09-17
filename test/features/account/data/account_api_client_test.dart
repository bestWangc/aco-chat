import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('removes a group member with the active access token', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    await client.removeGroupMember(
      groupID: 'group/id',
      memberAccountID: 'aco_member',
      token: 'signed-token',
    );

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/groups/group%2Fid/members/aco_member');
    expect(request.headers['authorization'], 'Bearer signed-token');
  });

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

  test(
    'restores an existing wallet account without a token or signature',
    () async {
      late Map<String, dynamic> requestBody;
      final client = AccountApiClient(
        baseUri: Uri.parse('https://api.aco.test/api/v1'),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/wallet-silent-login');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return response({
            'created': false,
            'access_token': 'silent-token',
            'refresh_token': 'unused-refresh-token',
            'user': {
              'account_id': 'aco_account',
              'username': 'aco_1234',
              'nickname': 'Aco 1234',
            },
          });
        }),
      );

      final result = await client.silentWalletLogin('0xabc');

      expect(requestBody, {'wallet_address': '0xabc'});
      expect(result.tokens.accessToken, 'silent-token');
    },
  );

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
              'can_edit': true,
              'can_export_check_ins': true,
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
    expect(request.headers['x-app-version'], AppConfig.appVersion);
    expect(lives.single.title, '真实直播主题');
    expect(lives.single.coverUrl, '/uploads/live-cover-9.jpg');
    expect(lives.single.status, 'live');
    expect(lives.single.canEdit, isTrue);
    expect(lives.single.canExportCheckIns, isTrue);
  });

  test('lists recommended square posts with author and image data', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        return response({
          'data': [
            {
              'id': 12,
              'content': '来自推荐接口的动态',
              'author': {
                'user_id': 7,
                'nickname': '素素姐',
                'avatar_url': '/uploads/avatar.jpg',
                'identity': 2,
                'staff_identity': 1,
              },
              'images': ['/uploads/post-image.jpg'],
              'reply_count': 63,
              'like_count': 88,
              'liked': true,
              'following': true,
              'created_at': '2026-09-17T07:30:00Z',
            },
          ],
        });
      }),
    );

    final posts = await client.listRecommendedPosts(token: 'signed-token');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/posts/recommended');
    expect(request.headers['authorization'], 'Bearer signed-token');
    expect(posts.single.content, '来自推荐接口的动态');
    expect(posts.single.authorId, 7);
    expect(posts.single.nickname, '素素姐');
    expect(posts.single.identity, 2);
    expect(posts.single.staffIdentity, 1);
    expect(posts.single.imageUrls, ['/uploads/post-image.jpg']);
    expect(posts.single.replyCount, 63);
    expect(posts.single.likeCount, 88);
    expect(posts.single.liked, isTrue);
    expect(posts.single.following, isTrue);
  });

  test('lists friends square posts with the active access token', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        return response({
          'data': [
            {
              'id': 13,
              'content': '来自好友的动态',
              'author': {'user_id': 8, 'nickname': '好友'},
              'images': [],
              'reply_count': 2,
              'like_count': 4,
              'liked': false,
              'following': false,
              'created_at': '2026-09-17T07:30:00Z',
            },
          ],
        });
      }),
    );

    final posts = await client.listFriendsPosts(token: 'signed-token');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/posts/friends');
    expect(request.headers['authorization'], 'Bearer signed-token');
    expect(posts.single.content, '来自好友的动态');
    expect(posts.single.authorId, 8);
  });

  test('likes posts and loads and creates replies', () async {
    final requests = <http.Request>[];
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return response({
            'data': [
              {
                'id': 3,
                'content': '回复内容',
                'author': {'nickname': '作者'},
                'created_at': '2026-09-17T07:30:00Z',
              },
            ],
          });
        }
        if (request.method == 'POST' && request.url.path.endsWith('/like')) {
          return response({'post_id': 12, 'liked': true, 'like_count': 89});
        }
        if (request.method == 'POST' && request.url.path.endsWith('/unlike')) {
          return response({'post_id': 12, 'liked': false, 'like_count': 88});
        }
        return response({
          'id': 3,
          'content': '新回复',
          'author': {'nickname': '作者'},
          'created_at': '2026-09-17T07:30:00Z',
        }, statusCode: 201);
      }),
    );

    final like = await client.likePost(postID: 12, token: 'signed-token');
    final replies = await client.listPostReplies(
      postID: 12,
      token: 'signed-token',
    );
    final reply = await client.createPostReply(
      postID: 12,
      content: '新回复',
      token: 'signed-token',
    );
    final unlike = await client.unlikePost(postID: 12, token: 'signed-token');

    expect(like.liked, isTrue);
    expect(like.likeCount, 89);
    expect(replies.single.content, '回复内容');
    expect(reply.content, '新回复');
    expect(unlike.liked, isFalse);
    expect(requests.map((request) => request.method), [
      'POST',
      'GET',
      'POST',
      'POST',
    ]);
    expect(requests[0].url.path, '/api/v1/posts/12/like');
    expect(requests[1].url.path, '/api/v1/posts/12/replies');
    expect(requests[2].url.path, '/api/v1/posts/12/replies');
    expect(requests[3].url.path, '/api/v1/posts/12/unlike');
    expect(jsonDecode(requests[2].body), {'content': '新回复'});
  });

  test('follows and unfollows post authors', () async {
    final requests = <http.Request>[];
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((request) async {
        requests.add(request);
        return response({
          'user_id': 7,
          'following': request.url.path.endsWith('/follow'),
        });
      }),
    );

    final followed = await client.followUser(userID: 7, token: 'signed-token');
    final unfollowed = await client.unfollowUser(
      userID: 7,
      token: 'signed-token',
    );

    expect(followed.userId, 7);
    expect(followed.following, isTrue);
    expect(unfollowed.following, isFalse);
    expect(requests.map((request) => request.method), ['POST', 'POST']);
    expect(requests[0].url.path, '/api/v1/users/7/follow');
    expect(requests[1].url.path, '/api/v1/users/7/unfollow');
  });

  test('updates a scheduled live session', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        expect(jsonDecode(value.body), {
          'title': '更新后的直播',
          'cover_url': '/uploads/live-cover-9.jpg',
          'access': 'open',
          'scheduled_at': '2026-08-12T13:00:00.000Z',
        });
        return response({
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

    final live = await client.updateLive(
      liveId: 9,
      title: '更新后的直播',
      coverUrl: '/uploads/live-cover-9.jpg',
      access: 'open',
      scheduledAt: DateTime.utc(2026, 8, 12, 13),
      token: 'signed-token',
    );

    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/v1/lives/9');
    expect(request.headers['authorization'], 'Bearer signed-token');
    expect(live.title, '更新后的直播');
    expect(live.canEdit, isTrue);
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
