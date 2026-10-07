import 'dart:convert';
import 'dart:async';

import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:http/http.dart' as http;

/// Authenticates against the app's RPC directory and queries the returned
/// public endpoints with failover and a short timeout.
class WalletRpcClient {
  WalletRpcClient({
    required this.client,
    required this.directoryBaseUri,
    this.ownsClient = false,
  });

  // Public RPC nodes can take several seconds to answer during congestion.
  // Keep enough time for allowance checks and transaction broadcasts while
  // still failing promptly when an endpoint is unavailable.
  static const requestTimeout = Duration(seconds: 15);
  final http.Client client;
  final Uri directoryBaseUri;
  final bool ownsClient;
  int _endpointCursor = 0;

  Future<List<Uri>> loadEndpoints({
    required String network,
    required String accessToken,
  }) async {
    final response = await client
        .get(
          _directoryUri(network),
          headers: {'authorization': 'Bearer $accessToken'},
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'RPC directory request failed: ${response.statusCode}',
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['data'] is! List) {
      throw const FormatException('Invalid RPC directory response');
    }
    final endpoints = <Uri>[];
    for (final value in body['data'] as List) {
      if (value is! String) continue;
      final uri = Uri.tryParse(value);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        endpoints.add(uri);
      }
    }
    if (endpoints.isEmpty) {
      throw const FormatException('RPC directory did not return any endpoints');
    }
    return endpoints;
  }

  Future<Map<String, dynamic>> postJson(
    List<Uri> endpoints,
    Map<String, Object> request,
  ) async {
    if (endpoints.isEmpty) {
      throw const FormatException('RPC endpoint list is empty');
    }
    final start = _endpointCursor++ % endpoints.length;
    final orderedEndpoints = [
      ...endpoints.skip(start),
      ...endpoints.take(start),
    ];
    final result = Completer<Map<String, dynamic>>();
    var remaining = orderedEndpoints.length;
    Object? lastError;
    for (final uri in orderedEndpoints) {
      _postJsonToUri(uri, request)
          .then((value) {
            if (!result.isCompleted) result.complete(value);
          })
          .catchError((error) {
            lastError = error;
            remaining -= 1;
            if (remaining == 0 && !result.isCompleted) {
              result.completeError(
                HttpException('All wallet RPC endpoints failed: $lastError'),
              );
            }
          });
    }
    return result.future.timeout(requestTimeout);
  }

  Future<Map<String, dynamic>> postJsonTo(
    Uri endpoint,
    Map<String, Object> request,
  ) => _postJsonToUri(endpoint, request);

  Future<Map<String, dynamic>> postJsonPath(
    List<Uri> endpoints,
    String path,
    Map<String, Object> request,
  ) async {
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        final base = endpoint.path.replaceFirst(RegExp(r'/$'), '');
        final uri = endpoint.replace(path: '$base/$path');
        return await _postJsonToUri(uri, request);
      } catch (error) {
        lastError = error;
      }
    }
    throw HttpException('All wallet RPC endpoints failed: $lastError');
  }

  Future<Map<String, dynamic>> _postJsonToUri(
    Uri uri,
    Map<String, Object> request,
  ) async {
    final response = await client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(request),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('RPC request failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> || body['error'] != null) {
      throw const FormatException('Invalid RPC response');
    }
    return body;
  }

  Uri _directoryUri(String network) {
    final basePath = directoryBaseUri.path.endsWith('/')
        ? directoryBaseUri.path.substring(0, directoryBaseUri.path.length - 1)
        : directoryBaseUri.path;
    return directoryBaseUri.replace(path: '$basePath/wallets/rpc/$network');
  }

  void close() {
    if (ownsClient) client.close();
  }
}
