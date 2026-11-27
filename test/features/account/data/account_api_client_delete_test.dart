import 'package:aco_chat/features/account/data/account_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('deletes a scheduled live session', () async {
    late http.Request request;
    final client = AccountApiClient(
      baseUri: Uri.parse('https://api.aco.test/api/v1'),
      httpClient: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    await client.deleteLive(liveId: 9, token: 'signed-token');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/lives/9/delete');
    expect(request.headers['authorization'], 'Bearer signed-token');
  });
}
