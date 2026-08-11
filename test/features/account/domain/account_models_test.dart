import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the compact account ID unchanged', () {
    expect(displayAccountId('aco_abcde234567ab'), 'aco_abcde234567ab');
  });

  test('shortens legacy account IDs for display', () {
    expect(
      displayAccountId('aco_8aca72086c10c6bf5e22a6eadbf27adc'),
      'aco_8aca72086c10c',
    );
  });
}
