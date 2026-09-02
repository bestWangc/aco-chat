/// Aco 对聊天 SDK 的最小抽象，避免页面直接依赖 OpenIM 类型。
abstract interface class ChatRepository {
  Future<void> initialize({
    required String apiAddr,
    required String wsAddr,
    required String dataDir,
  });

  Future<void> login({required String userId, required String userSig});

  Future<void> logout();
}
