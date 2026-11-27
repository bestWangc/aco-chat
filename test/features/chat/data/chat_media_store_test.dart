import 'dart:async';
import 'dart:io';

import 'package:aco_chat/features/chat/data/chat_media_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('chat-media-'),
  );
  tearDown(() async => root.delete(recursive: true));

  test('keeps downloaded media across restarts and beyond 30 days', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response.bytes([1, 2, 3], 200);
    });
    addTearDown(client.close);
    final store = ChatMediaStore(directory: root, client: client);
    final file = await store.load('https://media.test/a.mp4', kind: 'video');
    await file.setLastModified(DateTime(2020));
    final reopened = ChatMediaStore(directory: root, client: client);
    final saved = await reopened.load(
      'https://media.test/a.mp4',
      kind: 'video',
    );
    expect(await saved.readAsBytes(), [1, 2, 3]);
    expect(saved.path, file.path);
    expect(requests, 1);
    expect(
      (await reopened.find('https://media.test/a.mp4', kind: 'video'))?.path,
      file.path,
    );
    expect(
      await reopened.find('https://media.test/missing.jpg', kind: 'image'),
      isNull,
    );
  });

  test(
    'copies old temporary media and thumbnails without needing the server',
    () async {
      final legacy = Directory('${root.path}/temporary');
      final media = File(
        '${legacy.path}/chat-media/7d5b007ac3322071_video.mp4',
      );
      await media.parent.create(recursive: true);
      await media.writeAsBytes([4, 5]);
      final thumbnail = File(
        '${legacy.path}/chat-thumbnails/7d5b007ac3322071.jpg',
      );
      await thumbnail.parent.create(recursive: true);
      await thumbnail.writeAsBytes([6]);
      final client = MockClient((_) async => throw StateError('offline'));
      addTearDown(client.close);
      final store = ChatMediaStore(
        directory: Directory('${root.path}/persistent'),
        legacyDirectory: legacy,
        client: client,
      );
      final saved = await store.load('https://media.test/1.mp4', kind: 'video');
      expect(await saved.readAsBytes(), [4, 5]);
      final savedThumbnail = await store.load(
        'https://media.test/1.mp4',
        kind: 'thumbnail',
      );
      expect(await savedThumbnail.readAsBytes(), [6]);
      expect(await media.exists(), isTrue);
    },
  );

  test('coalesces simultaneous requests', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = MockClient((_) {
      requests++;
      return response.future;
    });
    addTearDown(client.close);
    final store = ChatMediaStore(directory: root, client: client);
    final first = store.load('https://media.test/a.mp4', kind: 'video');
    final second = store.load('https://media.test/a.mp4', kind: 'video');
    expect(identical(first, second), isTrue);
    response.complete(http.Response.bytes([1], 200));
    final results = await Future.wait([first, second]);
    expect(results[0].path, results[1].path);
    expect(requests, 1);
  });

  test('does not reuse failed or empty downloads and permits retry', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response.bytes(requests == 1 ? [] : [7], 200);
    });
    addTearDown(client.close);
    final store = ChatMediaStore(directory: root, client: client);
    await expectLater(
      store.load('https://media.test/a.mp4', kind: 'video'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await root.list().toList(), isEmpty);
    final file = await store.load('https://media.test/a.mp4', kind: 'video');
    expect(await file.readAsBytes(), [7]);
    expect(requests, 2);
  });

  test(
    'preserves outgoing local attachments without a network request',
    () async {
      final source = File('${root.path}/recording.mp3');
      await source.writeAsBytes([8, 9]);
      final client = MockClient((_) async => throw StateError('offline'));
      addTearDown(client.close);
      final store = ChatMediaStore(
        directory: Directory('${root.path}/saved'),
        client: client,
      );
      final file = await store.load(
        'https://media.test/a.mp3',
        kind: 'audio',
        source: source,
      );
      await source.delete();
      expect(await file.readAsBytes(), [8, 9]);
      final image = await store.load(
        'https://media.test/a.jpg',
        kind: 'image',
        bytes: [10],
      );
      expect(await image.readAsBytes(), [10]);
    },
  );

  test('account directories do not share files or inflight requests', () async {
    var requests = 0;
    final client = MockClient(
      (_) async => http.Response.bytes([++requests], 200),
    );
    addTearDown(client.close);
    final firstAccount = ChatMediaStore(
      directory: Directory('${root.path}/first'),
      client: client,
    );
    final secondAccount = ChatMediaStore(
      directory: Directory('${root.path}/second'),
      client: client,
    );
    final first = await firstAccount.load(
      'https://media.test/a.mp4',
      kind: 'video',
    );
    final second = await secondAccount.load(
      'https://media.test/a.mp4',
      kind: 'video',
    );
    expect(first.path, isNot(second.path));
    expect(await first.readAsBytes(), [1]);
    expect(await second.readAsBytes(), [2]);
  });
  test(
    'removes interrupted downloads and retries from the beginning',
    () async {
      var requests = 0;
      Stream<List<int>> interrupted() async* {
        yield [1];
        throw const SocketException('connection lost');
      }

      final client = MockClient.streaming((_, _) async {
        requests++;
        return http.StreamedResponse(
          requests == 1 ? interrupted() : Stream.value([2, 3]),
          200,
        );
      });
      addTearDown(client.close);
      final store = ChatMediaStore(directory: root, client: client);
      await expectLater(
        store.load('https://media.test/a.mp4', kind: 'video'),
        throwsA(isA<SocketException>()),
      );
      expect(await root.list().toList(), isEmpty);
      final file = await store.load('https://media.test/a.mp4', kind: 'video');
      expect(await file.readAsBytes(), [2, 3]);
    },
  );
}
