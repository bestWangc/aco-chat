import 'dart:convert';

import 'package:aco_chat/features/account/domain/account_models.dart';

sealed class LiveRealtimeEvent {
  const LiveRealtimeEvent({this.eventVersion = 0, this.versionScope = ''});
  final int eventVersion;
  final String versionScope;
}

final class LiveRoomSnapshotEvent extends LiveRealtimeEvent {
  const LiveRoomSnapshotEvent(
    this.room, {
    super.eventVersion,
    super.versionScope,
  });
  final LiveRoom room;
}

final class LiveAudioMuteEvent extends LiveRealtimeEvent {
  const LiveAudioMuteEvent(
    this.muted, {
    super.eventVersion,
    super.versionScope,
  });
  final bool muted;
}

final class LiveChatMuteEvent extends LiveRealtimeEvent {
  const LiveChatMuteEvent(this.muted, {super.eventVersion, super.versionScope});
  final bool muted;
}

final class LiveParticipantCountEvent extends LiveRealtimeEvent {
  const LiveParticipantCountEvent(
    this.count, {
    super.eventVersion,
    super.versionScope,
  });
  final int count;
}

final class LiveParticipantJoinedEvent extends LiveRealtimeEvent {
  const LiveParticipantJoinedEvent({
    required this.userId,
    required this.nickname,
    super.eventVersion,
    super.versionScope,
  });
  final int userId;
  final String nickname;
}

final class LiveParticipantLeftEvent extends LiveRealtimeEvent {
  const LiveParticipantLeftEvent({
    required this.userId,
    required this.speakers,
    required this.listeners,
    super.eventVersion,
    super.versionScope,
  });
  final int userId;
  final List<LiveParticipant> speakers;
  final List<LiveParticipant> listeners;
}

final class LiveCheckInEvent extends LiveRealtimeEvent {
  const LiveCheckInEvent({
    required this.checkInId,
    required this.deadline,
    required this.checkedInCount,
    required this.userId,
    super.eventVersion,
    super.versionScope,
  });
  final int checkInId;
  final DateTime deadline;
  final int checkedInCount;
  final int userId;
}

final class LiveCheckInStartedEvent extends LiveRealtimeEvent {
  const LiveCheckInStartedEvent(
    this.deadline, {
    required this.checkInId,
    super.eventVersion,
    super.versionScope,
  });
  final int checkInId;
  final DateTime deadline;
}

final class LiveRaisedHandCountEvent extends LiveRealtimeEvent {
  const LiveRaisedHandCountEvent(
    this.count, {
    super.eventVersion,
    super.versionScope,
  });
  final int count;
}

final class LiveParticipantMuteEvent extends LiveRealtimeEvent {
  const LiveParticipantMuteEvent({
    required this.userId,
    required this.muted,
    super.eventVersion,
    super.versionScope,
  });
  final int userId;
  final bool muted;
}

final class LiveKickedEvent extends LiveRealtimeEvent {
  const LiveKickedEvent({super.eventVersion, super.versionScope});
}

final class LiveEndedEvent extends LiveRealtimeEvent {
  const LiveEndedEvent({super.eventVersion, super.versionScope});
}

final class LiveHostAbsentEvent extends LiveRealtimeEvent {
  const LiveHostAbsentEvent(
    this.absent, {
    super.eventVersion,
    super.versionScope,
  });
  final bool absent;
}

final class LiveSpeakerInviteEvent extends LiveRealtimeEvent {
  const LiveSpeakerInviteEvent(
    this.invited, {
    this.userId = 0,
    super.eventVersion,
    super.versionScope,
  });
  final int userId;
  final bool invited;
}

final class LiveSpeakerListsChangedEvent extends LiveRealtimeEvent {
  const LiveSpeakerListsChangedEvent({
    required this.speakers,
    required this.listeners,
    required this.removed,
    super.eventVersion,
    super.versionScope,
  });
  final List<LiveParticipant> speakers;
  final List<LiveParticipant> listeners;
  final bool removed;
}

final class LiveHostTransferredEvent extends LiveRealtimeEvent {
  const LiveHostTransferredEvent({
    required this.hostId,
    required this.formerHostId,
    required this.viewerRole,
    this.host,
    super.eventVersion,
    super.versionScope,
  });
  final int hostId;
  final int formerHostId;
  final String viewerRole;
  final LiveParticipant? host;
}

abstract final class LiveRealtimeEventParser {
  static LiveRealtimeEvent? parse(Object? rawEvent) {
    if (rawEvent is! String) return null;
    try {
      final decoded = jsonDecode(rawEvent);
      if (decoded is! Map<String, dynamic> || decoded['type'] is! String) {
        return null;
      }
      final eventVersion = (decoded['version'] as num?)?.toInt() ?? 0;
      final versionScope = decoded['version_scope'] as String? ?? '';
      switch (decoded['type']) {
        case 'room.snapshot':
          final room = decoded['room'];
          return room is Map<String, dynamic>
              ? LiveRoomSnapshotEvent(
                  LiveRoom.fromJson(room),
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
        case 'room.audio_mute':
          final audioMuted = decoded['audio_muted'];
          return audioMuted is Map<String, dynamic>
              ? LiveAudioMuteEvent(
                  audioMuted['muted'] as bool? ?? false,
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
        case 'room.chat_mute':
          final muted = decoded['chat_muted'];
          return muted is bool
              ? LiveChatMuteEvent(
                  muted,
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
        case 'room.host_absent':
          final absent = decoded['host_absent'];
          return absent is bool
              ? LiveHostAbsentEvent(
                  absent,
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
        case 'room.participant_count':
          final count = decoded['participant_count'];
          return count is num
              ? LiveParticipantCountEvent(
                  count.toInt(),
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
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
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
        case 'room.participant_left':
          final participant = decoded['participant'];
          if (participant is! Map<String, dynamic> ||
              participant['user_id'] is! num) {
            return null;
          }
          List<LiveParticipant> decodeList(Object? value) =>
              (value is List ? value : const <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .map(LiveParticipant.fromJson)
                  .toList(growable: false);
          return LiveParticipantLeftEvent(
            userId: (participant['user_id'] as num).toInt(),
            speakers: decodeList(decoded['speakers']),
            listeners: decodeList(decoded['listeners']),
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
        case 'room.check_in':
          final checkIn = decoded['check_in'];
          if (checkIn is! Map<String, dynamic>) return null;
          final deadline = checkIn['deadline'];
          final count = checkIn['checked_in_count'];
          final userId = checkIn['user_id'];
          final checkInId = checkIn['check_in_id'];
          if (deadline is! String ||
              count is! num ||
              userId is! num ||
              checkInId is! num) {
            return null;
          }
          return LiveCheckInEvent(
            checkInId: checkInId.toInt(),
            deadline: DateTime.parse(deadline),
            checkedInCount: count.toInt(),
            userId: userId.toInt(),
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
        case 'room.check_in_started':
          final checkIn = decoded['check_in'];
          final deadline = checkIn is Map<String, dynamic>
              ? checkIn['deadline']
              : null;
          final checkInId = checkIn is Map<String, dynamic>
              ? checkIn['check_in_id']
              : null;
          return deadline is String && checkInId is num
              ? LiveCheckInStartedEvent(
                  DateTime.parse(deadline),
                  checkInId: checkInId.toInt(),
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
        case 'room.raised_hand_count':
          final count = decoded['raised_hand_count'];
          return count is num
              ? LiveRaisedHandCountEvent(
                  count.toInt(),
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
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
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
        case 'room.kicked':
          return LiveKickedEvent(
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
        case 'room.ended':
          return LiveEndedEvent(
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
        case 'room.speaker_invite':
          final invited = decoded['speaker_invite'];
          if (invited is Map<String, dynamic> && invited['invited'] is bool) {
            return LiveSpeakerInviteEvent(
              invited['invited'] as bool,
              userId: (invited['user_id'] as num?)?.toInt() ?? 0,
              eventVersion: eventVersion,
              versionScope: versionScope,
            );
          }
          return invited is bool
              ? LiveSpeakerInviteEvent(
                  invited,
                  eventVersion: eventVersion,
                  versionScope: versionScope,
                )
              : null;
        case 'room.speaker_changed':
        case 'room.speaker_removed':
          final speakers = decoded['speakers'];
          final listeners = decoded['listeners'];
          if (speakers != null && speakers is! List) return null;
          if (listeners != null && listeners is! List) return null;
          LiveParticipant decodeParticipant(Object? value) =>
              value is Map<String, dynamic>
              ? LiveParticipant.fromJson(value)
              : throw const FormatException();
          try {
            return LiveSpeakerListsChangedEvent(
              speakers: (speakers as List<dynamic>? ?? const <dynamic>[])
                  .map(decodeParticipant)
                  .toList(growable: false),
              listeners: (listeners as List<dynamic>? ?? const <dynamic>[])
                  .map(decodeParticipant)
                  .toList(growable: false),
              removed: decoded['type'] == 'room.speaker_removed',
              eventVersion: eventVersion,
              versionScope: versionScope,
            );
          } on FormatException {
            return null;
          }
        case 'room.host_transferred':
          final transfer = decoded['host_transferred'];
          if (transfer is! Map<String, dynamic> ||
              transfer['host_id'] is! num ||
              transfer['former_host_id'] is! num ||
              transfer['viewer_role'] is! String) {
            return null;
          }
          return LiveHostTransferredEvent(
            hostId: (transfer['host_id'] as num).toInt(),
            formerHostId: (transfer['former_host_id'] as num).toInt(),
            viewerRole: transfer['viewer_role'] as String,
            host: transfer['host'] is Map<String, dynamic>
                ? LiveParticipant.fromJson(
                    transfer['host'] as Map<String, dynamic>,
                  )
                : null,
            eventVersion: eventVersion,
            versionScope: versionScope,
          );
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
