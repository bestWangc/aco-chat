import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:http/http.dart' as http;

class AccountApiException implements Exception {
  const AccountApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'AccountApiException($statusCode): $message';
}

/// HTTP gateway for the account endpoints. Supply [baseUri] in development or
/// tests; the production default is [AppConfig.apiBaseUrl].
class AccountApiClient {
  AccountApiClient({Uri? baseUri, http.Client? httpClient})
    : _baseUri = baseUri ?? Uri.parse(const AppConfig().apiBaseUrl),
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<WalletLoginResult> walletLogin({
    required String walletAddress,
    required WalletLoginProof proof,
  }) async {
    final response = await _httpClient.post(
      _uri('auth/wallet-login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'wallet_address': walletAddress,
        'challenge': proof.challenge,
        'public_key': proof.publicKey,
        'signature': proof.signature,
      }),
    );
    return WalletLoginResult.fromJson(_body(response));
  }

  Future<String> walletChallenge(String walletAddress) async {
    final response = await _httpClient.post(
      _uri('auth/wallet-challenge'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return _body(response)['challenge'] as String;
  }

  Future<AccountTokens> refreshAccessToken(String refreshToken) async {
    final response = await _httpClient.post(
      _uri('auth/refresh'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    return AccountTokens.fromJson(_body(response));
  }

  Future<WalletAddress> addWallet({
    required String accountId,
    required String walletAddress,
    required String token,
  }) async {
    final response = await _httpClient.post(
      _uri('accounts/$accountId/wallets'),
      headers: _authorizedHeaders(token),
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return WalletAddress.fromJson(_body(response));
  }

  Future<List<WalletAddress>> listWallets({
    required String accountId,
    required String token,
  }) async {
    final response = await _httpClient.get(
      _uri('accounts/$accountId/wallets'),
      headers: _authorizedHeaders(token),
    );
    final body = _body(response);
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WalletAddress.fromJson)
        .toList(growable: false);
  }

  Future<AccountProfile> currentProfile({required String token}) async {
    final response = await _httpClient.get(
      _uri('auth/me'),
      headers: _authorizedHeaders(token),
    );
    final body = _body(response);
    return AccountProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  void close() => _httpClient.close();

  Uri _uri(String path) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath/$path');
  }

  Map<String, String> _authorizedHeaders(String token) => {
    'content-type': 'application/json',
    'authorization': 'Bearer $token',
  };

  Map<String, dynamic> _body(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountApiException(
        response.statusCode,
        decoded['error'] as String? ?? 'account request failed',
      );
    }
    return decoded;
  }
}
