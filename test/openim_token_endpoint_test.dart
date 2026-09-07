import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenIM token always uses the public TLS gateway', () {
    final token = OpenIMToken.fromJson({
      'user_id': 'account-1',
      'token': 'header.payload.signature',
      'api_addr': 'http://openim-server:10002',
      'ws_addr': 'ws://202.61.87.51:10001',
    });

    expect(token.apiAddr, 'https://im.aco.chat');
    expect(token.wsAddr, 'wss://im.aco.chat');
  });
}
