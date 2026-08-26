const _shortAccountIdLength = 17;

String displayAccountId(String accountId) {
  final digitsOnly = accountId.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return accountId;
  if (digitsOnly.length <= _shortAccountIdLength) return digitsOnly;
  return digitsOnly.substring(0, _shortAccountIdLength);
}

class AccountProfile {
  const AccountProfile({
    required this.accountId,
    required this.username,
    required this.nickname,
  });

  final String accountId;
  final String username;
  final String nickname;

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    accountId: json['account_id'] as String,
    username: json['username'] as String,
    nickname: json['nickname'] as String,
  );

  Map<String, String> toJson() => {
    'account_id': accountId,
    'username': username,
    'nickname': nickname,
  };
}

class WalletAddress {
  const WalletAddress({required this.address, this.id, this.accountId});

  final int? id;
  final String? accountId;
  final String address;

  factory WalletAddress.fromJson(Map<String, dynamic> json) => WalletAddress(
    id: json['id'] as int?,
    accountId: json['account_id'] as String?,
    address: (json['wallet_address'] ?? json['address']) as String,
  );
}

class WalletLoginResult {
  const WalletLoginResult({
    required this.created,
    required this.tokens,
    required this.user,
  });

  final bool created;
  final AccountTokens tokens;
  final AccountProfile user;

  factory WalletLoginResult.fromJson(Map<String, dynamic> json) =>
      WalletLoginResult(
        created: json['created'] as bool,
        tokens: AccountTokens.fromJson(json),
        user: AccountProfile.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class AccountTokens {
  const AccountTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AccountTokens.fromJson(Map<String, dynamic> json) => AccountTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );

  Map<String, String> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };
}

class AccountRefreshResult {
  const AccountRefreshResult({required this.tokens, required this.user});

  final AccountTokens tokens;
  final AccountProfile user;

  factory AccountRefreshResult.fromJson(Map<String, dynamic> json) =>
      AccountRefreshResult(
        tokens: AccountTokens.fromJson(json),
        user: AccountProfile.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class LiveSession {
  const LiveSession({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.access,
    required this.status,
    required this.createdAt,
    this.canEdit = false,
    this.canExportCheckIns = false,
    this.scheduledAt,
  });

  final int id;
  final String title;
  final String coverUrl;
  final String access;
  final String status;
  final DateTime createdAt;
  final bool canEdit;
  final bool canExportCheckIns;
  final DateTime? scheduledAt;

  factory LiveSession.fromJson(Map<String, dynamic> json) => LiveSession(
    id: json['id'] as int,
    title: json['title'] as String,
    coverUrl: json['cover_url'] as String,
    access: json['access'] as String,
    status: json['status'] as String,
    canEdit: json['can_edit'] as bool? ?? false,
    canExportCheckIns: json['can_export_check_ins'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    scheduledAt: switch (json['scheduled_at'] as String?) {
      final value? when value.isNotEmpty => DateTime.parse(value),
      _ => null,
    },
  );
}

class LiveKitJoinInfo {
  const LiveKitJoinInfo({
    required this.url,
    required this.token,
    required this.roomName,
    required this.role,
    required this.canPublish,
    required this.canPublishData,
  });

  factory LiveKitJoinInfo.fromJson(Map<String, dynamic> json) =>
      LiveKitJoinInfo(
        url: json['url'] as String,
        token: json['token'] as String,
        roomName: json['room_name'] as String,
        role: json['role'] as String,
        canPublish: json['can_publish'] as bool? ?? false,
        canPublishData: json['can_publish_data'] as bool? ?? false,
      );

  final String url;
  final String token;
  final String roomName;
  final String role;
  final bool canPublish;
  final bool canPublishData;
}

class LiveMessage {
  const LiveMessage({
    required this.id,
    required this.nickname,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final String nickname;
  final String text;
  final DateTime createdAt;

  factory LiveMessage.fromJson(Map<String, dynamic> json) => LiveMessage(
    id: _messageId(json['id']),
    nickname: json['nickname'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

int _messageId(Object? value) {
  if (value is int) return value;
  return int.tryParse('$value') ?? 0;
}

class LiveParticipant {
  const LiveParticipant({
    required this.userId,
    required this.nickname,
    required this.role,
    required this.handRaised,
    required this.muted,
  });

  final int userId;
  final String nickname;
  final String role;
  final bool handRaised;
  final bool muted;

  factory LiveParticipant.fromJson(Map<String, dynamic> json) =>
      LiveParticipant(
        userId: json['user_id'] as int,
        nickname: json['nickname'] as String,
        role: json['role'] as String,
        handRaised: json['hand_raised'] as bool? ?? false,
        muted: json['muted'] as bool? ?? false,
      );
}

class LiveRoom {
  const LiveRoom({
    required this.live,
    required this.host,
    required this.hostActive,
    required this.viewerUserId,
    required this.viewerRole,
    required this.participantCount,
    required this.speakers,
    required this.listeners,
    this.raisedHandCount,
    required this.canRaiseHand,
    required this.viewerMuted,
    required this.chatMuted,
    required this.audioMuted,
    this.checkIn,
  });

  final LiveSession live;
  final LiveParticipant host;
  final bool hostActive;
  final int viewerUserId;
  final String viewerRole;
  final int participantCount;
  final List<LiveParticipant> speakers;
  final List<LiveParticipant> listeners;
  /// Present only in the host's room snapshot. The request details are loaded
  /// on demand from the dedicated moderation endpoint.
  final int? raisedHandCount;
  final bool canRaiseHand;
  final bool viewerMuted;
  final bool chatMuted;
  final bool audioMuted;
  final LiveCheckIn? checkIn;

  factory LiveRoom.fromJson(Map<String, dynamic> json) => LiveRoom(
    live: LiveSession.fromJson(json['live'] as Map<String, dynamic>),
    host: LiveParticipant.fromJson(json['host'] as Map<String, dynamic>),
    hostActive: json['host_active'] as bool? ?? false,
    viewerUserId: json['viewer_user_id'] as int? ?? 0,
    viewerRole: json['viewer_role'] as String,
    participantCount: json['participant_count'] as int,
    speakers: (json['speakers'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(LiveParticipant.fromJson)
        .toList(growable: false),
    listeners: (json['listeners'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LiveParticipant.fromJson)
        .toList(growable: false),
    raisedHandCount: (json['raised_hand_count'] as num?)?.toInt(),
    canRaiseHand: json['can_raise_hand'] as bool? ?? false,
    viewerMuted: json['viewer_muted'] as bool? ?? false,
    chatMuted: json['chat_muted'] as bool? ?? false,
    audioMuted: json['audio_muted'] as bool? ?? false,
    checkIn: switch (json['check_in']) {
      final Map<String, dynamic> value => LiveCheckIn.fromJson(value),
      _ => null,
    },
  );
}

class LiveCheckIn {
  const LiveCheckIn({
    required this.deadline,
    required this.checkedInCount,
    required this.viewerChecked,
  });
  final DateTime deadline;
  final int checkedInCount;
  final bool viewerChecked;
  factory LiveCheckIn.fromJson(Map<String, dynamic> json) => LiveCheckIn(
    deadline: DateTime.parse(json['deadline'] as String),
    checkedInCount: json['checked_in_count'] as int? ?? 0,
    viewerChecked: json['viewer_checked'] as bool? ?? false,
  );
}
