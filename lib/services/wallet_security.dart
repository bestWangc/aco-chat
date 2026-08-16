import 'dart:convert';
import 'dart:math';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;

/// Stores encrypted wallet material. Implementations must never expose the
/// underlying value to application logs or analytics.
abstract interface class WalletSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Platform-backed storage for encrypted wallet vault records.
class SecureWalletSecretStore implements WalletSecretStore {
  SecureWalletSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Test-friendly store. Do not use this implementation in production.
class InMemoryWalletSecretStore implements WalletSecretStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class WalletSecurityException implements Exception {
  const WalletSecurityException(this.message);

  final String message;

  @override
  String toString() => 'WalletSecurityException: $message';
}

/// An encrypted, versioned vault record suitable for secure local storage.
class WalletVaultRecord {
  const WalletVaultRecord({
    required this.version,
    required this.salt,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  factory WalletVaultRecord.fromJson(Map<String, dynamic> json) {
    try {
      return WalletVaultRecord(
        version: json['version'] as int,
        salt: base64Decode(json['salt'] as String),
        nonce: base64Decode(json['nonce'] as String),
        cipherText: base64Decode(json['cipherText'] as String),
        mac: base64Decode(json['mac'] as String),
      );
    } on FormatException catch (_) {
      throw const WalletSecurityException('钱包安全数据已损坏');
    } on TypeError catch (_) {
      throw const WalletSecurityException('钱包安全数据格式无效');
    }
  }

  final int version;
  final List<int> salt;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, dynamic> toJson() => {
    'version': version,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'cipherText': base64Encode(cipherText),
    'mac': base64Encode(mac),
  };
}

/// Local security primitives used by both wallet creation and import flows.
///
/// Mnemonics are BIP-39 compatible. They are encrypted with a 256-bit key
/// derived from the wallet password using PBKDF2-HMAC-SHA256, then written as
/// an AES-GCM authenticated vault record to [WalletSecretStore].
class WalletSecurity {
  WalletSecurity({Random? random}) : _random = random ?? Random.secure();

  static const _vaultPrefix = 'wallet.vault.';
  static const _devicePasswordPrefix = 'wallet.device-password.';
  static const _saltLength = 32;
  static const _pbkdf2Iterations = 210000;
  static final _cipher = AesGcm.with256bits();

  final Random _random;

  String createMnemonic({int words = 12}) {
    final strength = switch (words) {
      12 => 128,
      24 => 256,
      _ => throw const WalletSecurityException('助记词仅支持 12 或 24 个单词'),
    };
    return bip39.generateMnemonic(strength: strength);
  }

  String normalizeMnemonic(String mnemonic) => mnemonic
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .join(' ');

  bool isValidMnemonic(String mnemonic) {
    final normalized = normalizeMnemonic(mnemonic);
    final wordCount = normalized.split(' ').length;
    return (wordCount == 12 || wordCount == 24) &&
        bip39.validateMnemonic(normalized);
  }

  Future<void> saveMnemonic({
    required WalletSecretStore store,
    required String walletAddress,
    required String mnemonic,
    required String password,
  }) async {
    _validateWalletAddress(walletAddress);
    _validatePassword(password);
    final normalized = normalizeMnemonic(mnemonic);
    if (!isValidMnemonic(normalized)) {
      throw const WalletSecurityException('助记词无效');
    }
    final salt = _randomBytes(_saltLength);
    final request = _VaultEncryptionRequest(
      mnemonic: normalized,
      password: password,
      salt: salt,
    );
    final record = kIsWeb
        ? await _encryptVault(request)
        : await compute(_encryptVault, request);
    await store.write(_vaultKey(walletAddress), jsonEncode(record.toJson()));
  }

  /// Stores a wallet using a device-protected key when the user has already
  /// completed the account-level security setup.
  Future<void> saveMnemonicWithDeviceProtection({
    required WalletSecretStore store,
    required String walletAddress,
    required String mnemonic,
  }) async {
    final devicePassword = base64UrlEncode(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    await saveMnemonic(
      store: store,
      walletAddress: walletAddress,
      mnemonic: mnemonic,
      password: devicePassword,
    );
    await store.write(_devicePasswordKey(walletAddress), devicePassword);
  }

  Future<String> unlockMnemonic({
    required WalletSecretStore store,
    required String walletAddress,
    required String password,
  }) async {
    _validateWalletAddress(walletAddress);
    _validatePassword(password);
    final encoded = await store.read(_vaultKey(walletAddress));
    if (encoded == null) {
      throw const WalletSecurityException('未找到该钱包的本地安全数据');
    }
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final record = WalletVaultRecord.fromJson(json);
      if (record.version != 1) {
        throw const WalletSecurityException('不支持的钱包安全数据版本');
      }
      final key = await _deriveKey(password, record.salt);
      final clearText = await _cipher.decrypt(
        SecretBox(record.cipherText, nonce: record.nonce, mac: Mac(record.mac)),
        secretKey: key,
      );
      return utf8.decode(clearText);
    } on SecretBoxAuthenticationError {
      throw const WalletSecurityException('钱包密码错误或安全数据已损坏');
    } on FormatException {
      throw const WalletSecurityException('钱包安全数据已损坏');
    } on TypeError {
      throw const WalletSecurityException('钱包安全数据格式无效');
    }
  }

  Future<void> deleteMnemonic({
    required WalletSecretStore store,
    required String walletAddress,
  }) {
    _validateWalletAddress(walletAddress);
    return store.delete(_vaultKey(walletAddress));
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256), growable: false);

  String _vaultKey(String walletAddress) =>
      '$_vaultPrefix${walletAddress.toLowerCase()}';

  String _devicePasswordKey(String walletAddress) =>
      '$_devicePasswordPrefix${walletAddress.toLowerCase()}';

  void _validatePassword(String password) {
    if (password.length < 8) {
      throw const WalletSecurityException('钱包密码至少需要 8 位');
    }
  }

  void _validateWalletAddress(String walletAddress) {
    if (walletAddress.trim().isEmpty) {
      throw const WalletSecurityException('钱包地址不能为空');
    }
  }
}

class _VaultEncryptionRequest {
  const _VaultEncryptionRequest({
    required this.mnemonic,
    required this.password,
    required this.salt,
  });

  final String mnemonic;
  final String password;
  final List<int> salt;
}

Future<WalletVaultRecord> _encryptVault(
  _VaultEncryptionRequest request,
) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  ).deriveKey(
    secretKey: SecretKey(utf8.encode(request.password)),
    nonce: request.salt,
  );
  final secretBox = await AesGcm.with256bits().encrypt(
    utf8.encode(request.mnemonic),
    secretKey: key,
  );
  return WalletVaultRecord(
    version: 1,
    salt: request.salt,
    nonce: secretBox.nonce,
    cipherText: secretBox.cipherText,
    mac: secretBox.mac.bytes,
  );
}
