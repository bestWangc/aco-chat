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
