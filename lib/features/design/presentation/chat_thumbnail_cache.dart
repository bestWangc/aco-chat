part of 'aco_design_shell.dart';

final class _ChatThumbnailCache {
  static const _retention = Duration(days: 30);
  static const _directoryName = 'chat-thumbnails';

  static Future<File> load(String url) async {
    final directory = await _directory();
    unawaited(_removeExpired(directory));
    final file = File('${directory.path}/${_fileNameFor(url)}.jpg');
    if (await _isFresh(file)) {
      await file.setLastModified(DateTime.now());
      return file;
    }

    if (await file.exists()) await file.delete();
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw HttpException('缩略图下载失败: ${response.statusCode}');
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  static Future<Directory> _directory() async {
    final cacheDirectory = await getTemporaryDirectory();
    return Directory(
      '${cacheDirectory.path}/$_directoryName',
    ).create(recursive: true);
  }

  static Future<bool> _isFresh(File file) async {
    if (!await file.exists()) return false;
    final modified = await file.lastModified();
    return DateTime.now().difference(modified) <= _retention;
  }

  static Future<void> _removeExpired(Directory directory) async {
    await for (final entity in directory.list()) {
      if (entity is! File || await _isFresh(entity)) continue;
      await entity.delete();
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
      if (file != null) return Image.file(file, fit: BoxFit.contain);
      if (snapshot.hasError) {
        return Image.network(widget.url, fit: BoxFit.contain);
      }
      return const SizedBox(
        width: 64,
        height: 64,
        child: Center(child: CupertinoActivityIndicator()),
      );
    },
  );
}
