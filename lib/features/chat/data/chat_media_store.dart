import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Downloaded chat attachments live with application data, until explicitly removed.
final class ChatMediaStore {
  ChatMediaStore({required this.directory, this.legacyDirectory, this.client});

  final Directory directory;
  final Directory? legacyDirectory;
  final http.Client? client;
  final Map<String, Future<File>> _inFlight = {};

  Future<File?> find(String url, {required String kind}) async {
    final file = _file(url, kind);
    return await _hasContent(file) ? file : null;
  }

  File _file(String url, String kind) {
    if (!RegExp(r'^[a-z]+$').hasMatch(kind)) {
      throw ArgumentError.value(kind, 'kind');
    }
    return File('${directory.path}/${_fileName(url)}_$kind${_extension(url)}');
  }

  Future<File> load(
    String url, {
    required String kind,
    String? legacyUrl,
    File? source,
    List<int>? bytes,
  }) {
    if (!RegExp(r'^[a-z]+$').hasMatch(kind)) {
      throw ArgumentError.value(kind, 'kind');
    }
    final key = '$kind:$url';
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _load(url, kind, legacyUrl ?? url, source, bytes);
    _inFlight[key] = future;
    unawaited(
      future.then<void>(
        (_) => _inFlight.remove(key),
        onError: (Object error, StackTrace stackTrace) {
          _inFlight.remove(key);
        },
      ),
    );
    return future;
  }

  Future<File> _load(
    String url,
    String kind,
    String legacyUrl,
    File? source,
    List<int>? bytes,
  ) async {
    await directory.create(recursive: true);
    final file = _file(url, kind);
    if (await _hasContent(file)) return file;
    final temporary = File('${file.path}.part');
    try {
      final legacyRoot = legacyDirectory;
      File? legacyFile;
      if (legacyRoot != null) {
        final name = _fileName(legacyUrl);
        if (kind == 'thumbnail') {
          legacyFile = File('${legacyRoot.path}/chat-thumbnails/$name.jpg');
        } else {
          legacyFile = File(
            '${legacyRoot.path}/chat-media/${name}_$kind${_extension(legacyUrl)}',
          );
        }
      }
      if (source != null && await _hasContent(source)) {
        await source.copy(temporary.path);
      } else if (bytes != null && bytes.isNotEmpty) {
        await temporary.writeAsBytes(bytes, flush: true);
      } else if (legacyFile != null && await _hasContent(legacyFile)) {
        await legacyFile.copy(temporary.path);
      } else {
        final downloadClient = client ?? http.Client();
        try {
          final response = await downloadClient
              .send(http.Request('GET', Uri.parse(url)))
              .timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) {
            throw HttpException('媒体下载失败: ${response.statusCode}');
          }
          await response.stream
              .timeout(const Duration(seconds: 20))
              .pipe(temporary.openWrite());
        } finally {
          if (client == null) downloadClient.close();
        }
      }
      if (!await _hasContent(temporary)) {
        throw const FileSystemException('媒体内容为空');
      }
      return await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static Future<bool> _hasContent(File file) async =>
      await file.exists() && await file.length() > 0;

  static String _fileName(String value) {
    var hash = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3 & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static String _extension(String url) {
    final name = (Uri.tryParse(url)?.path ?? '').split('/').last;
    return RegExp(r'\.[a-zA-Z0-9]{1,8}$').firstMatch(name)?.group(0) ?? '';
  }
}
