import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the numeric part of a compact legacy account ID', () {
    expect(displayAccountId('aco_abcde234567ab'), '234567');
  });

  test('shortens legacy account IDs for display', () {
    expect(
      displayAccountId('aco_8aca72086c10c6bf5e22a6eadbf27adc'),
      '872086106522627',
    );
  });

  test('parses a video-only square post', () {
    final post = SquarePost.fromJson({
      'id': 42,
      'content': '视频动态',
      'author': {'user_id': 7, 'nickname': '作者'},
      'images': <String>[],
      'video_url': '/uploads/post-video.mp4',
      'video_thumbnail_url': '/uploads/post-video-thumbnail.jpg',
      'video_duration_seconds': 15,
      'created_at': '2026-11-20T08:00:00Z',
    });

    expect(post.imageUrls, isEmpty);
    expect(post.videoUrl, '/uploads/post-video.mp4');
    expect(post.videoThumbnailUrl, '/uploads/post-video-thumbnail.jpg');
    expect(post.videoDurationSeconds, 15);
  });
}
