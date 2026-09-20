import 'package:aco_chat/services/lifi_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
