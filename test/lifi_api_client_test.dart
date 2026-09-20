import 'package:aco_chat/services/lifi_api_client.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('converts decimal amounts to LI.FI base units', () {
    expect(LifiApiClient.toBaseUnits('1,234.5', 6), '1234500000');
    expect(LifiApiClient.toBaseUnits('0.000001', 6), '1');
  });

  test('parses incomplete status responses safely', () {
    final status = LifiTransferStatus.fromJson({'status': 'PENDING'});
    expect(status.status, 'PENDING');
    expect(status.receivingTxHash, isNull);
  });

  test('parses quote when action and tool are strings', () {
    final quote = LifiQuote.fromJson({
      'action': 'swap',
      'tool': 'jumper',
      'estimate': {'toAmount': '100', 'toAmountMin': '99'},
    });
    expect(quote.fromAmount, '');
    expect(quote.tool, 'jumper');
  });

  test('shows nested LI.FI error reason', () async {
    final client = _ErrorClient();
    final api = LifiApiClient(
      client: client,
      baseUri: Uri.parse('https://li.quest/v1'),
    );
    await expectLater(
      api.quote(
        fromNetwork: WalletNetwork.ethereum,
        fromToken: 'ETH',
        toNetwork: WalletNetwork.ethereum,
        toToken: 'USDC',
        fromAmount: '1',
        fromDecimals: 18,
        fromAddress: '0xabc',
      ),
      throwsA(
        predicate<LifiException>(
          (error) => error.message.contains('insufficient liquidity'),
        ),
      ),
    );
  });

  test('includes the configured LI.FI fee in quote requests', () async {
    final client = _QuoteClient();
    final api = LifiApiClient(
      client: client,
      baseUri: Uri.parse('https://li.quest/v1'),
    );
    await api.quote(
      fromNetwork: WalletNetwork.ethereum,
      fromToken: 'ETH',
      toNetwork: WalletNetwork.ethereum,
      toToken: 'USDC',
      fromAmount: '1',
      fromDecimals: 18,
      fromAddress: '0xabc',
    );
    expect(client.uri?.queryParameters['fee'], '0.005');
    expect(client.uri?.queryParameters['integrator'], 'aco');
  });
}

class _ErrorClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = '{"error":{"message":"insufficient liquidity"}}';
    return http.StreamedResponse(
      Stream<List<int>>.value(body.codeUnits),
      400,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _QuoteClient extends http.BaseClient {
  Uri? uri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    uri = request.url;
    const body = '{"estimate":{"fromAmount":"1000000000000000000",'
        '"toAmount":"1","toAmountMin":"1"}}';
    return http.StreamedResponse(
      Stream<List<int>>.value(body.codeUnits),
      200,
      request: request,
    );
  }
}
