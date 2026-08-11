import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the numeric part of a compact legacy account ID', () {
    expect(displayAccountId('aco_abcde234567ab'), '234567');
  });

  test('shortens legacy account IDs for display', () {
    expect(
      displayAccountId('aco_8aca72086c10c6bf5e22a6eadbf27adc'),
      '872086106522627',
    );
  });
}
