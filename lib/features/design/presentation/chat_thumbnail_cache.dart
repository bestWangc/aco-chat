part of 'aco_design_shell.dart';

final class _ChatThumbnailCache {
  static const _retention = Duration(days: 30);
  static const _maxBytes = 100 * 1024 * 1024;
  static const _cleanupInterval = Duration(hours: 6);
  static const _directoryName = 'chat-thumbnails';
  static const _requestTimeout = Duration(seconds: 10);
  static Future<Directory>? _directoryFuture;
  static Future<void>? _cleanupFuture;
  static DateTime? _lastCleanup;
  static Timer? _cleanupTimer;
  static final Map<String, Future<File>> _inFlight = {};

  static Future<File> load(String url) {
    final pending = _inFlight[url];
    if (pending != null) return pending;
    final future = _load(url);
    _inFlight[url] = future;
    unawaited(
      future.then<void>(
        (_) => _inFlight.remove(url),
        onError: (Object error, StackTrace stackTrace) {
          _inFlight.remove(url);
        },
      ),
    );
    return future;
  }

  static Future<File> _load(String url) async {
    final directory = await _directory();
    _scheduleCleanup(directory);
    final file = File('${directory.path}/${_fileNameFor(url)}.jpg');
    if (await _isFresh(file)) {
      return file;
    }

    if (await file.exists()) await file.delete();
    final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw HttpException('缩略图下载失败: ${response.statusCode}');
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  static Future<Directory> _directory() =>
      _directoryFuture ??= _createDirectory();

  static Future<Directory> _createDirectory() async {
    final cacheDirectory = await getTemporaryDirectory();
    final directory = await Directory(
      '${cacheDirectory.path}/$_directoryName',
    ).create(recursive: true);
    _cleanupTimer ??= Timer.periodic(
      _cleanupInterval,
      (_) => _scheduleCleanup(directory),
    );
    return directory;
  }

  static void _scheduleCleanup(Directory directory) {
    final now = DateTime.now();
    if (_cleanupFuture != null ||
        (_lastCleanup != null &&
            now.difference(_lastCleanup!) < _cleanupInterval))
      return;
    _lastCleanup = now;
    _cleanupFuture = _removeExpired(directory)
        .catchError((error) {
          debugPrint('[Chat] thumbnail cache cleanup failed: $error');
        })
        .whenComplete(() => _cleanupFuture = null);
  }

  static Future<bool> _isFresh(File file) async {
    if (!await file.exists()) return false;
    final modified = await file.lastModified();
    return DateTime.now().difference(modified) <= _retention;
  }

  static Future<void> _removeExpired(Directory directory) async {
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
  }

  static String _fileNameFor(String url) {
    var hash = 0xcbf29ce484222325;
    for (final unit in url.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3 & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

class _CachedChatThumbnail extends StatefulWidget {
  const _CachedChatThumbnail({required this.url});

  final String url;

  @override
  State<_CachedChatThumbnail> createState() => _CachedChatThumbnailState();
}

class _CachedChatThumbnailState extends State<_CachedChatThumbnail> {
  late Future<File> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _ChatThumbnailCache.load(widget.url);
  }

  @override
  void didUpdateWidget(covariant _CachedChatThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    _thumbnail = _ChatThumbnailCache.load(widget.url);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<File>(
    future: _thumbnail,
    builder: (context, snapshot) {
      final file = snapshot.data;
      if (file != null) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) => const _ImageUnavailable(),
        );
      }
      if (snapshot.hasError) return const _ImageUnavailable();
      return const SizedBox(
        width: 64,
        height: 64,
        child: Center(child: CupertinoActivityIndicator()),
      );
    },
  );
}
