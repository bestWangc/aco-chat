import 'dart:async';
import 'dart:convert';

import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:aco_chat/features/account/data/account_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records swaps initiated by this app. The server verifies the hash and owns
/// the final side/amount/status; the client only submits routing metadata.
class DexTradeService {
  DexTradeService({AccountApiClient? apiClient, AccountTokenStore? tokenStore})
    : _apiClient = apiClient ?? AccountApiClient(),
      _tokenStore = tokenStore ?? SecureAccountTokenStore(),
      _ownsApiClient = apiClient == null;

  final AccountApiClient _apiClient;
  final AccountTokenStore _tokenStore;
  final bool _ownsApiClient;

  Future<Map<String, dynamic>> record({
    required String network,
    required String wallet,
    required String dex,
    required String pool,
    required String txHash,
    String? baseToken,
    String? quoteToken,
  }) async {
    unawaited(flushPending());
    final suffixLength = txHash.length > 10 ? 10 : txHash.length;
    final suffix = txHash.substring(0, suffixLength);
    final clientId = '${DateTime.now().microsecondsSinceEpoch}-$suffix';
    return _recordWithClientId(
      clientId,
      network: network,
      wallet: wallet,
      dex: dex,
      pool: pool,
      txHash: txHash,
      baseToken: baseToken,
      quoteToken: quoteToken,
    );
  }

  Future<Map<String, dynamic>> _recordWithClientId(
    String clientId, {
    required String network,
    required String wallet,
    required String dex,
    required String pool,
    required String txHash,
    String? baseToken,
    String? quoteToken,
  }) async {
    final tokens = await _tokenStore.read();
    if (tokens == null) throw StateError('No access token is available');
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'client_id': clientId,
      'network': network,
      'wallet': wallet,
      'dex': dex,
      'pool': pool,
      'tx_hash': txHash,
      if (baseToken case final token?) 'base_token': token,
      if (quoteToken case final token?) 'quote_token': token,
    };
    final queue = prefs.getStringList(_queueKey) ?? <String>[];
    queue.removeWhere((item) => item.contains('"client_id":"$clientId"'));
    queue.add(jsonEncode(payload));
    await prefs.setStringList(_queueKey, queue);
    final result = await _apiClient.recordDexTrade(
      network: network,
      wallet: wallet,
      dex: dex,
      pool: pool,
      txHash: txHash,
      baseToken: baseToken,
      quoteToken: quoteToken,
      clientId: clientId,
      token: tokens.accessToken,
    );
    queue.removeWhere((item) => item.contains('"client_id":"$clientId"'));
    await prefs.setStringList(_queueKey, queue);
    return result;
  }

  static const _queueKey = 'dex_trade_outbox';

  Future<void> flushPending() async {
    final prefs = await SharedPreferences.getInstance();
    for (final encoded in prefs.getStringList(_queueKey) ?? const <String>[]) {
      final value = jsonDecode(encoded);
      if (value is! Map) continue;
      try {
        await _recordWithClientId(
          '${value['client_id']}',
          network: '${value['network']}',
          wallet: '${value['wallet']}',
          dex: '${value['dex']}',
          pool: '${value['pool']}',
          txHash: '${value['tx_hash']}',
          baseToken: value['base_token']?.toString(),
          quoteToken: value['quote_token']?.toString(),
        );
        final remaining = prefs.getStringList(_queueKey) ?? <String>[];
        remaining.remove(encoded);
        await prefs.setStringList(_queueKey, remaining);
      } catch (_) {}
    }
  }

  void close() {
    if (_ownsApiClient) _apiClient.close();
  }
}
