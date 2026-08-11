import 'dart:convert';

import 'package:aco_chat/core/config/app_config.dart';
import 'package:aco_chat/features/account/domain/account_models.dart';
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
  }) async {
    final response = await _httpClient.post(
      _uri('auth/wallet-login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return WalletLoginResult.fromJson(_body(response));
  }

  Future<WalletAddress> addWallet({
    required String accountId,
    required String walletAddress,
  }) async {
    final response = await _httpClient.post(
      _uri('accounts/$accountId/wallets'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'wallet_address': walletAddress}),
    );
    return WalletAddress.fromJson(_body(response));
  }

  Future<List<WalletAddress>> listWallets(String accountId) async {
    final response = await _httpClient.get(_uri('accounts/$accountId/wallets'));
    final body = _body(response);
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(WalletAddress.fromJson)
        .toList(growable: false);
  }

  void close() => _httpClient.close();

  Uri _uri(String path) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath/$path');
  }

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
