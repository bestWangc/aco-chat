import 'dart:convert';

import 'package:aco_chat/features/account/domain/account_models.dart';

sealed class LiveRealtimeEvent {
  const LiveRealtimeEvent();
}

final class LiveRoomSnapshotEvent extends LiveRealtimeEvent {
  const LiveRoomSnapshotEvent(this.room);
  final LiveRoom room;
}

final class LiveAudioMuteEvent extends LiveRealtimeEvent {
  const LiveAudioMuteEvent(this.muted);
  final bool muted;
}

final class LiveChatMuteEvent extends LiveRealtimeEvent {
  const LiveChatMuteEvent(this.muted);
  final bool muted;
}

final class LiveParticipantCountEvent extends LiveRealtimeEvent {
  const LiveParticipantCountEvent(this.count);
  final int count;
}

abstract final class LiveRealtimeEventParser {
  static LiveRealtimeEvent? parse(Object? rawEvent) {
    if (rawEvent is! String) return null;
    try {
      final decoded = jsonDecode(rawEvent);
      if (decoded is! Map<String, dynamic> || decoded['type'] is! String) {
        return null;
      }
      switch (decoded['type']) {
        case 'room.snapshot':
          final room = decoded['room'];
          return room is Map<String, dynamic>
              ? LiveRoomSnapshotEvent(LiveRoom.fromJson(room))
              : null;
        case 'room.audio_mute':
          final audioMuted = decoded['audio_muted'];
          return audioMuted is Map<String, dynamic>
              ? LiveAudioMuteEvent(audioMuted['muted'] as bool? ?? false)
              : null;
        case 'room.chat_mute':
          final muted = decoded['chat_muted'];
          return muted is bool ? LiveChatMuteEvent(muted) : null;
        case 'room.participant_count':
          final count = decoded['participant_count'];
          return count is num ? LiveParticipantCountEvent(count.toInt()) : null;
        default:
          return null;
      }
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
