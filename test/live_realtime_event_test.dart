import 'dart:convert';

import 'package:aco_chat/features/live/domain/live_realtime_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses lightweight realtime events', () {
    expect(
      LiveRealtimeEventParser.parse(
        jsonEncode({
          'type': 'room.audio_mute',
          'audio_muted': {'muted': true},
        }),
      ),
      isA<LiveAudioMuteEvent>().having((event) => event.muted, 'muted', true),
    );
    expect(
      LiveRealtimeEventParser.parse(
        jsonEncode({'type': 'room.chat_mute', 'chat_muted': false}),
      ),
      isA<LiveChatMuteEvent>().having((event) => event.muted, 'muted', false),
    );
    expect(
      LiveRealtimeEventParser.parse(
        jsonEncode({'type': 'room.participant_count', 'participant_count': 3}),
      ),
      isA<LiveParticipantCountEvent>().having(
        (event) => event.count,
        'count',
        3,
      ),
    );
  });

  test('ignores malformed and unsupported realtime events', () {
    expect(LiveRealtimeEventParser.parse('{'), isNull);
    expect(
      LiveRealtimeEventParser.parse(jsonEncode({'type': 'unknown'})),
      isNull,
    );
    expect(LiveRealtimeEventParser.parse(42), isNull);
  });
}
