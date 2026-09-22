import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:aco_chat/services/dex_ranking_api_client.dart';

void main() {
  test('converts pcr to a percentage string', () {
    final token = DexRankingToken.fromJson({
      'symbol': 'TEST',
      'pcr': '-0.0053',
    });

    expect(token.change, '-0.53%');
  });

  test('parses the verified flag from base metadata', () {
    final token = DexRankingToken.fromJson({
      'base': {'sym': 'TEST', 'verified': true},
    });

    expect(token.verified, isTrue);
  });

  test('parses tvl_usd as token liquidity', () {
    final token = DexRankingToken.fromJson({
      'base': {'sym': 'TEST', 'dex': 'orca'},
      'tvl_usd': '123456.78',
    });

    expect(token.liquidity, '123456.78');
    expect(token.dex, 'orca');
  });

  test('filters tokens from the Antfun launchpad', () async {
    final api = DexRankingApiClient(
      httpClient: _RankingClient(),
      baseUri: Uri.parse('https://api.test'),
    );

    final tokens = await api.hotTokens();
    api.close();

    expect(tokens.map((token) => token.symbol), ['KEEP']);
  });

  test('uses the selected ranking type and chain', () async {
    final client = _RankingClient();
    final api = DexRankingApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.test'),
    );

    await api.hotTokens(type: 'picks', chain: 'sol');
    api.close();

    final request = jsonDecode(client.lastRequestBody!) as Map<String, dynamic>;
    expect(request['type'], 'picks');
    expect(request['chain'], 'sol');
  });

  test('loads fresh token data from DexScreener', () async {
    final client = _DexScreenerClient();
    final api = DexRankingApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.test/api/v1'),
    );

    final token = await api.dexScreenerTokenInfo(
      DexRankingToken.fromJson({
        'base': {
          'chain': 'sol',
          'addr': 'old-address',
          'sym': 'OLD',
          'pool': 'pool-address',
        },
      }),
    );
    api.close();

    expect(
      client.lastRequestUri.toString(),
      contains('/api/v1/dex/pairs/solana/pool-address'),
    );
    expect(token?.symbol, 'NEW');
    expect(token?.price, '1.23');
    expect(token?.marketCap, '1234567');
    expect(token?.volume, '45678');
    expect(token?.liquidity, '987654');
    expect(token?.change, '0.25%');

    final bscToken = await api.dexScreenerTokenInfo(
      DexRankingToken.fromJson({
        'base': {'chain': 'bsc', 'pool': 'bsc-pool'},
      }),
    );
    expect(
      client.lastRequestUri.toString(),
      contains('/api/v1/dex/pairs/bsc/bsc-pool'),
    );
    expect(bscToken?.symbol, 'NEW');
  });

  test('loads K-line history with the token pool and interval', () async {
    final client = _KlineClient();
    final api = DexRankingApiClient(
      httpClient: client,
      baseUri: Uri.parse('https://api.test/api/v1'),
    );

    final candles = await api.klineHistory(
      DexRankingToken.fromJson({
        'base': {
          'chain': 'sol',
          'addr': 'token-address',
          'pool': 'pool-address',
        },
      }),
      interval: '5m',
    );
    api.close();

    final request = jsonDecode(client.lastRequestBody!) as Map<String, dynamic>;
    expect(request, {
      'chain': 'sol',
      'address': 'token-address',
      'pool': 'pool-address',
      'interval': '5m',
    });
    expect(candles, hasLength(2));
    expect(candles.first.timestamp, 2000);
    expect(candles.first.open, 2.0);
    expect(candles.last.close, 1.5);
  });
}

class _RankingClient extends http.BaseClient {
  String? lastRequestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST') {
      final chunks = await request.finalize().toList();
      lastRequestBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
    }
    final body = request.method == 'GET'
        ? '{"urls":["https://ranking.test/api"]}'
        : '{"data":{"list":['
              '{"base":{"sym":"KEEP","launchpad":"orca"}},'
              '{"base":{"sym":"DROP","launchpad":"ant.fun"}},'
              '{"base":{"sym":"ANTFUN"}},'
              '{"base":{"sym":"DROP2"},"from_pool_launchpad":"ANTFUN"}'
              ']}}';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _DexScreenerClient extends http.BaseClient {
  Uri? lastRequestUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequestUri = request.url;
    const body =
        '{"pairs":[{'
        '"dexId":"orca",'
        '"pairAddress":"pool-address",'
        '"baseToken":{"address":"new-address","name":"New","symbol":"NEW"},'
        '"priceUsd":"1.23",'
        '"priceChange":{"m5":0.25},'
        '"volume":{"h24":45678},'
        '"liquidity":{"usd":987654},'
        '"marketCap":1234567'
        '}]}';
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _KlineClient extends http.BaseClient {
  String? lastRequestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET') {
      return http.StreamedResponse(
        Stream<List<int>>.value(
          utf8.encode('{"urls":["https://ranking.test/api/v1/ranking/list"]}'),
        ),
        200,
        request: request,
        headers: const {'content-type': 'application/json'},
      );
    }
    final chunks = await request.finalize().toList();
    lastRequestBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(
          '{"code":0,"data":{"list":['
          '{"ts":2,"o":"2","c":"2.5","h":"3","l":"1.5","vu":"4"},'
          '{"ts":1,"o":"1","c":"1.5","h":"2","l":"0.5","vu":"3"}'
          ']}}',
        ),
      ),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
