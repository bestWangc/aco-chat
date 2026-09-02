import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';

import '../domain/chat_repository.dart';

/// OpenIM SDK 适配层。业务页面只依赖 [ChatRepository]。
final class OpenIMChatRepository implements ChatRepository {
  OpenIMChatRepository({OpenIM? sdk}) : _sdk = sdk ?? OpenIM.iMManager;

  final OpenIM _sdk;

  @override
  Future<void> initialize({
    required String apiAddr,
    required String wsAddr,
    required String dataDir,
  }) async {
    await _sdk.initSDK(
      apiAddr: apiAddr,
      wsAddr: wsAddr,
      dataDir: dataDir,
      // 6 is the SDK's test-level logging value; production should lower it.
      logLevel: 6,
      isLogStandardOutput: true,
    );
  }

  @override
  Future<void> login({required String userId, required String userSig}) {
    return _sdk.login(userID: userId, userSig: userSig);
  }

  @override
  Future<void> logout() => _sdk.logout();
}
