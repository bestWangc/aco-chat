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

final class LiveParticipantJoinedEvent extends LiveRealtimeEvent {
  const LiveParticipantJoinedEvent({
    required this.userId,
    required this.nickname,
  });
  final int userId;
  final String nickname;
}

final class LiveCheckInEvent extends LiveRealtimeEvent {
  const LiveCheckInEvent({
    required this.deadline,
    required this.checkedInCount,
    required this.userId,
  });
  final DateTime deadline;
  final int checkedInCount;
  final int userId;
}

final class LiveRaisedHandCountEvent extends LiveRealtimeEvent {
  const LiveRaisedHandCountEvent(this.count);
  final int count;
}

final class LiveParticipantMuteEvent extends LiveRealtimeEvent {
  const LiveParticipantMuteEvent({required this.userId, required this.muted});
  final int userId;
  final bool muted;
}

final class LiveKickedEvent extends LiveRealtimeEvent {
  const LiveKickedEvent();
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
        case 'room.participant_joined':
          final participant = decoded['participant'];
          if (participant is! Map<String, dynamic>) return null;
          final nickname = participant['nickname'];
          if (nickname is! String || nickname.trim().isEmpty) return null;
          final userId = participant['user_id'];
          if (userId is! num) return null;
          return LiveParticipantJoinedEvent(
            userId: userId.toInt(),
            nickname: nickname.trim(),
          );
        case 'room.check_in':
          final checkIn = decoded['check_in'];
          if (checkIn is! Map<String, dynamic>) return null;
          final deadline = checkIn['deadline'];
          final count = checkIn['checked_in_count'];
          final userId = checkIn['user_id'];
          if (deadline is! String || count is! num || userId is! num) {
            return null;
          }
          return LiveCheckInEvent(
            deadline: DateTime.parse(deadline),
            checkedInCount: count.toInt(),
            userId: userId.toInt(),
          );
        case 'room.raised_hand_count':
          final count = decoded['raised_hand_count'];
          return count is num ? LiveRaisedHandCountEvent(count.toInt()) : null;
        case 'room.participant_mute':
          final mute = decoded['participant_mute'];
          if (mute is! Map<String, dynamic> ||
              mute['user_id'] is! num ||
              mute['muted'] is! bool) {
            return null;
          }
          return LiveParticipantMuteEvent(
            userId: (mute['user_id'] as num).toInt(),
            muted: mute['muted'] as bool,
          );
        case 'room.kicked':
          return const LiveKickedEvent();
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
