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

class LiveSession {
  const LiveSession({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.access,
    required this.status,
    required this.createdAt,
    this.scheduledAt,
  });

  final int id;
  final String title;
  final String coverUrl;
  final String access;
  final String status;
  final DateTime createdAt;
  final DateTime? scheduledAt;

  factory LiveSession.fromJson(Map<String, dynamic> json) => LiveSession(
    id: json['id'] as int,
    title: json['title'] as String,
    coverUrl: json['cover_url'] as String,
    access: json['access'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    scheduledAt: switch (json['scheduled_at'] as String?) {
      final value? when value.isNotEmpty => DateTime.parse(value),
      _ => null,
    },
  );
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
    id: json['id'] as int,
    nickname: json['nickname'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
