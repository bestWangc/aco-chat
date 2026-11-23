part of 'aco_app_shell.dart';

final class _ChatMediaCache {
  static final Map<String, Future<ChatMediaStore>> _stores = {};

  static Future<File> load(
    String url, {
    required String kind,
    File? source,
    List<int>? bytes,
    String? originalUrl,
    String? accountID,
  }) async {
    final userID = accountID ?? OpenIMChatRepository.currentUserID;
    if (userID == null || userID.isEmpty) throw StateError('聊天账号未登录');
    final store = await (_stores[userID] ??= _createStore(userID));
    if (originalUrl != null && originalUrl.isNotEmpty) {
      final original = await store.find(
        _downloadUrl(originalUrl),
        kind: 'image',
      );
      if (original != null) return original;
    }
    return store.load(
      _downloadUrl(url),
      kind: kind,
      legacyUrl: url,
      source: source,
      bytes: bytes,
    );
  }

  static String _downloadUrl(String url) {
    final parsed = Uri.parse(url);
    final uri = parsed.hasScheme
        ? parsed
        : Uri.parse(const AppConfig().apiBaseUrl).resolveUri(parsed);
    return uri.scheme == 'http' && AppConfig.isOpenIMHost(uri.host)
        ? uri.replace(scheme: 'https').toString()
        : uri.toString();
  }

  static Future<ChatMediaStore> _createStore(String userID) async {
    final root = await getApplicationSupportDirectory();
    final account = base64Url.encode(utf8.encode(userID));
    return ChatMediaStore(
      directory: Directory('${root.path}/chat-media/$account'),
      legacyDirectory: await getTemporaryDirectory(),
    );
  }
}
