import 'package:flutter_test/flutter_test.dart';

import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';

void main() {
  test('formats dex market cap and volume with compact currency units', () {
    expect(
      formatDexCompactCurrency('307489697.646906288262719165'),
      '\$307.49M',
    );
    expect(formatDexCompactCurrency('54121.15441091'), '\$54.12K');
    expect(formatDexCompactCurrency('2500000000'), '\$2.5B');
    expect(formatDexCompactCurrency(''), '--');
  });

  test('formats dex prices without ellipsis', () {
    expect(formatDexPrice('0.00009185'), '\$0.0₃9185');
    expect(formatDexPrice('1514.359757'), '\$1514.36');
    expect(formatDexPrice('0.39827'), '\$0.39827');
    expect(formatDexPrice(''), '--');
  });

  test('formats kline prices with the same compact precision', () {
    expect(formatDexChartPrice(0.00004928), '0.0₃4928');
    expect(formatDexChartPrice(0.000004928), '0.0₄4928');
    expect(formatDexChartPrice(9.1600), '9.16');
  });
}
