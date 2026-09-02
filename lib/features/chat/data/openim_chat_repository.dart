import 'dart:io';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';

import '../domain/chat_repository.dart';

/// OpenIM SDK 适配层。业务页面只依赖 [ChatRepository]。
final class OpenIMChatRepository implements ChatRepository {
  OpenIMChatRepository({IMManager? sdk}) : _sdk = sdk ?? OpenIM.iMManager;

  final IMManager _sdk;

  @override
  Future<void> initialize({
    required String apiAddr,
    required String wsAddr,
    required String dataDir,
  }) async {
    await _sdk.initSDK(
      platformID: Platform.isIOS ? IMPlatform.ios : IMPlatform.android,
      apiAddr: apiAddr,
      wsAddr: wsAddr,
      dataDir: dataDir,
      listener: OnConnectListener(),
      logLevel: 6,
      isLogStandardOutput: true,
    );
  }

  @override
  Future<void> login({required String userId, required String userSig}) async {
    await _sdk.login(userID: userId, token: userSig);
  }

  @override
  Future<void> logout() => _sdk.logout();
}
