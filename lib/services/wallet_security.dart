import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'
    show compute, debugPrint, kDebugMode, kIsWeb;
import 'package:aco_chat/services/bip39_service.dart';

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
  static const _deviceVaultPrefix = 'wallet.device-vault.';
  static const _devicePasswordPrefix = 'wallet.device-password.';
  static const _saltLength = 32;
  static const _pbkdf2Iterations = 210000;
  static final _cipher = AesGcm.with256bits();

  final Random _random;

  String createMnemonic({int words = 12}) {
    switch (words) {
      case 12:
      case 24:
        break;
      default:
        throw const WalletSecurityException('助记词仅支持 12 或 24 个单词');
    }
    return Bip39Service.generateMnemonic(words: words);
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
        Bip39Service.validateMnemonic(normalized);
  }

  Future<void> saveMnemonic({
    required WalletSecretStore store,
    required String walletAddress,
    required String mnemonic,
    required String password,
  }) async {
    _validateWalletAddress(walletAddress);
    final legacyDevicePassword = await store.read(
      _devicePasswordKey(walletAddress),
    );
    final deviceVaultKey = _deviceVaultKey(walletAddress);
    final previousDeviceVault = await store.read(deviceVaultKey);
    final hadSeparateDeviceVault = previousDeviceVault != null;
    if (legacyDevicePassword != null && !hadSeparateDeviceVault) {
      // Preserve the legacy biometric unlock before replacing its shared vault.
      await saveMnemonicWithDeviceProtection(
        store: store,
        walletAddress: walletAddress,
        mnemonic: mnemonic,
      );
    }
    final key = _vaultKey(walletAddress);
    try {
      await _saveMnemonicRecord(
        store: store,
        key: key,
        mnemonic: mnemonic,
        password: password,
      );
    } catch (_) {
      if (legacyDevicePassword != null && !hadSeparateDeviceVault) {
        if (previousDeviceVault == null) {
          await store.delete(deviceVaultKey);
        } else {
          await store.write(deviceVaultKey, previousDeviceVault);
        }
      }
      rethrow;
    }
    if (legacyDevicePassword != null) {
      await store.delete(_devicePasswordKey(walletAddress));
    }
  }

  /// Adds a device-protected copy without replacing the password-protected
  /// vault, so either configured unlock method can recover the same mnemonic.
  Future<void> saveMnemonicWithDeviceProtection({
    required WalletSecretStore store,
    required String walletAddress,
    required String mnemonic,
  }) async {
    final devicePassword = base64UrlEncode(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    _validateWalletAddress(walletAddress);
    final encodedRecord = await _encryptMnemonicRecord(
      mnemonic: mnemonic,
      password: devicePassword,
    );
    final key = _deviceVaultKey(walletAddress);
    final previousRecord = await store.read(key);
    try {
      await store.write(
        key,
        jsonEncode({
          'format': 'aco-device-vault-v1',
          'password': devicePassword,
          'record': encodedRecord,
        }),
      );
      final savedMnemonic = await unlockMnemonicWithDeviceProtection(
        store: store,
        walletAddress: walletAddress,
      );
      if (savedMnemonic != normalizeMnemonic(mnemonic)) {
        throw const WalletSecurityException('设备保护数据写入校验失败');
      }
    } catch (_) {
      if (previousRecord == null) {
        await store.delete(key);
      } else {
        await store.write(key, previousRecord);
      }
      rethrow;
    }
  }

  Future<String> unlockMnemonic({
    required WalletSecretStore store,
    required String walletAddress,
    required String password,
  }) async {
    _validateWalletAddress(walletAddress);
    _validatePassword(password);
    return _unlockMnemonicFromKey(
      store: store,
      key: _vaultKey(walletAddress),
      password: password,
    );
  }

  Future<String> _unlockMnemonicFromKey({
    required WalletSecretStore store,
    required String key,
    required String password,
    String? encodedRecord,
    String passwordError = '钱包密码错误或安全数据已损坏',
  }) async {
    final encoded = encodedRecord ?? await store.read(key);
    if (encoded == null) {
      if (kDebugMode) debugPrint('[WalletVault] read key=$key record=missing');
      throw const WalletSecurityException('未找到该钱包的本地安全数据');
    }
    await _debugRecordFingerprint('read', key, encoded);
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
      throw WalletSecurityException(passwordError);
    } on FormatException {
      throw const WalletSecurityException('钱包安全数据已损坏');
    } on TypeError {
      throw const WalletSecurityException('钱包安全数据格式无效');
    }
  }

  Future<String> unlockMnemonicWithDeviceProtection({
    required WalletSecretStore store,
    required String walletAddress,
  }) async {
    _validateWalletAddress(walletAddress);
    final deviceVaultKey = _deviceVaultKey(walletAddress);
    final deviceVault = await store.read(deviceVaultKey);
    if (deviceVault != null) {
      try {
        final json = jsonDecode(deviceVault);
        if (json is Map<String, dynamic> &&
            json['format'] == 'aco-device-vault-v1') {
          final password = json['password'];
          final record = json['record'];
          if (password is! String || record is! String) {
            throw const WalletSecurityException('设备加密数据已损坏');
          }
          return _unlockMnemonicFromKey(
            store: store,
            key: deviceVaultKey,
            password: password,
            encodedRecord: record,
            passwordError: '设备加密数据与密钥不匹配或已损坏',
          );
        }
      } on FormatException {
        throw const WalletSecurityException('设备加密数据已损坏');
      }
    }
    final password = await store.read(_devicePasswordKey(walletAddress));
    if (password == null) throw const WalletSecurityException('未配置设备保护');
    return _unlockMnemonicFromKey(
      store: store,
      key: deviceVault == null ? _vaultKey(walletAddress) : deviceVaultKey,
      password: password,
      passwordError: '设备加密数据与密钥不匹配或已损坏',
    );
  }

  Future<bool> hasDeviceProtection({
    required WalletSecretStore store,
    required String walletAddress,
  }) async {
    final encoded = await store.read(_deviceVaultKey(walletAddress));
    if (_isCombinedDeviceVault(encoded)) return true;
    final devicePassword = await store.read(_devicePasswordKey(walletAddress));
    if (devicePassword == null) return false;
    if (encoded != null) return true;
    // Older device-protected wallets stored their device-encrypted record in
    // the password vault slot.
    return (await store.read(_vaultKey(walletAddress))) != null;
  }

  Future<bool> hasPasswordProtection({
    required WalletSecretStore store,
    required String walletAddress,
  }) async {
    final passwordVault = await store.read(_vaultKey(walletAddress));
    if (passwordVault == null) return false;
    final devicePassword = await store.read(_devicePasswordKey(walletAddress));
    if (devicePassword == null) return true;
    if (await store.read(_deviceVaultKey(walletAddress)) == null) return false;
    // During legacy migration, both the old shared vault and the new device
    // vault can exist briefly. Detect the old vault by its device password.
    try {
      await _unlockMnemonicFromKey(
        store: store,
        key: _vaultKey(walletAddress),
        password: devicePassword,
      );
      return false;
    } on WalletSecurityException {
      return true;
    }
  }

  Future<void> deleteMnemonic({
    required WalletSecretStore store,
    required String walletAddress,
  }) async {
    _validateWalletAddress(walletAddress);
    await Future.wait([
      store.delete(_vaultKey(walletAddress)),
      store.delete(_deviceVaultKey(walletAddress)),
      store.delete(_devicePasswordKey(walletAddress)),
    ]);
  }

  Future<void> _saveMnemonicRecord({
    required WalletSecretStore store,
    required String key,
    required String mnemonic,
    required String password,
  }) async {
    final encoded = await _encryptMnemonicRecord(
      mnemonic: mnemonic,
      password: password,
    );
    final previousRecord = await store.read(key);
    try {
      await store.write(key, encoded);
      await _debugRecordFingerprint('write', key, encoded);
      final savedMnemonic = await _unlockMnemonicFromKey(
        store: store,
        key: key,
        password: password,
      );
      if (savedMnemonic != normalizeMnemonic(mnemonic)) {
        throw const WalletSecurityException('钱包密码数据写入校验失败');
      }
    } catch (_) {
      if (previousRecord == null) {
        await store.delete(key);
      } else {
        await store.write(key, previousRecord);
      }
      rethrow;
    }
  }

  Future<String> _encryptMnemonicRecord({
    required String mnemonic,
    required String password,
  }) async {
    _validatePassword(password);
    final normalized = normalizeMnemonic(mnemonic);
    if (!isValidMnemonic(normalized)) {
      throw const WalletSecurityException('助记词无效');
    }
    final request = _VaultEncryptionRequest(
      mnemonic: normalized,
      password: password,
      salt: _randomBytes(_saltLength),
    );
    final record = kIsWeb
        ? await _encryptVault(request)
        : await compute(_encryptVault, request);
    return jsonEncode(record.toJson());
  }

  bool _isCombinedDeviceVault(String? encoded) {
    if (encoded == null) return false;
    try {
      return (jsonDecode(encoded) as Map<String, dynamic>)['format'] ==
          'aco-device-vault-v1';
    } on Object {
      return false;
    }
  }

  Future<void> _debugRecordFingerprint(
    String operation,
    String key,
    String encoded,
  ) async {
    if (!kDebugMode) return;
    final digest = await Sha256().hash(utf8.encode(encoded));
    final fingerprint = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    debugPrint('[WalletVault] $operation key=$key fingerprint=$fingerprint');
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

  String _deviceVaultKey(String walletAddress) =>
      '$_deviceVaultPrefix${walletAddress.toLowerCase()}';

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

Future<WalletVaultRecord> _encryptVault(_VaultEncryptionRequest request) async {
  final key =
      await Pbkdf2(
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
