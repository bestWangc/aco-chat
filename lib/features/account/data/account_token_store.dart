import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AccountTokenStore {
  Future<AccountTokens?> read();
  Future<void> write(AccountTokens tokens);
  Future<void> clear();
}

class SecureAccountTokenStore implements AccountTokenStore {
  SecureAccountTokenStore({FlutterSecureStorage? storage, String? key})
    : _storage = storage ?? const FlutterSecureStorage(),
      _key = key ?? 'account.tokens.${const AppConfig().accountStorageScope}';

  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _key);

  @override
  Future<AccountTokens?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return AccountTokens.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AccountTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
}
