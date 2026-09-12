part of 'aco_design_shell.dart';

final class _ChatMediaCache {
  static const _retention = Duration(days: 30);
  static const _maxBytes = 300 * 1024 * 1024;
  static const _cleanupInterval = Duration(hours: 6);
  static Future<Directory>? _directoryFuture;
  static Future<void>? _cleanupFuture;
  static DateTime? _lastCleanup;
  static Timer? _cleanupTimer;
  static final Map<String, Future<File>> _inFlight = {};

  static Future<File> load(String url, {required String kind}) {
    final key = '$kind:$url';
    return _inFlight[key] ??= _load(key, url, kind);
  }

  static Future<File> _load(String key, String url, String kind) async {
    try {
      final directory = await _directory();
      _scheduleCleanup(directory);
      final file = File('${directory.path}/${_fileName(url)}_$kind');
      if (await _isFresh(file)) return file;
      final response = await http
          .get(Uri.parse(_httpsUrl(url)))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty)
        throw HttpException('媒体下载失败: ${response.statusCode}');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } finally {
      _inFlight.remove(key);
    }
  }

  static Future<Directory> _directory() =>
      _directoryFuture ??= getTemporaryDirectory().then((root) async {
        final directory = await Directory(
          '${root.path}/chat-media',
        ).create(recursive: true);
        _cleanupTimer ??= Timer.periodic(
          _cleanupInterval,
          (_) => _scheduleCleanup(directory),
        );
        return directory;
      });
  static Future<bool> _isFresh(File file) async =>
      await file.exists() &&
      DateTime.now().difference(await file.lastModified()) <= _retention;
  static Future<void> _cleanup(Directory directory) async {
    try {
      final files = <File>[];
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        if (await _isFresh(entity)) {
          files.add(entity);
        } else {
          await entity.delete();
        }
      }
      var total = 0;
      final sizes = <File, int>{};
      for (final file in files) {
        final size = await file.length();
        sizes[file] = size;
        total += size;
      }
      if (total > _maxBytes) {
        files.sort(
          (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
        );
        for (final file in files) {
          if (total <= _maxBytes) break;
          await file.delete();
          total -= sizes[file] ?? 0;
        }
      }
    } catch (error) {
      debugPrint('[Chat] media cache cleanup failed: $error');
    }
  }

  static void _scheduleCleanup(Directory directory) {
    final now = DateTime.now();
    if (_cleanupFuture != null ||
        (_lastCleanup != null &&
            now.difference(_lastCleanup!) < _cleanupInterval))
      return;
    _lastCleanup = now;
    _cleanupFuture = _cleanup(
      directory,
    ).whenComplete(() => _cleanupFuture = null);
  }

  static String _httpsUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'http' && uri.host == 'im.aco.chat'
        ? uri.replace(scheme: 'https').toString()
        : url;
  }

  static String _fileName(String value) {
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3 & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
