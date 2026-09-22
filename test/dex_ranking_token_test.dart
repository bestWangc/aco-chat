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

  test('filters tokens from the Antfun launchpad', () async {
    final api = DexRankingApiClient(
      httpClient: _RankingClient(),
      baseUri: Uri.parse('https://api.test'),
    );

    final tokens = await api.hotTokens();
    api.close();

    expect(tokens.map((token) => token.symbol), ['KEEP']);
  });
}

class _RankingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
