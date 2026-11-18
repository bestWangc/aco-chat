import 'package:flutter/material.dart';
import 'package:flutter_chen_kchart/k_chart.dart';
import 'package:flutter_test/flutter_test.dart';

List<KLineEntity> _candles(List<double> prices) => [
  for (var i = 0; i < prices.length; i++)
    KLineEntity.fromCustom(
      open: prices[i],
      close: prices[i],
      high: prices[i] + 1,
      low: prices[i] - 1,
      vol: 100,
      time: 1700000000000 + i * 60000,
    ),
];

void main() {
  test('EMA seeds with the first close and applies exponential weighting', () {
    final data = _candles([10, 20, 30]);
    DataUtil.calcEMA(data, [1, 3, 5]);
    expect(data.first.emaValueList, [10, 10, 10]);
    expect(data[1].emaValueList![0], 20);
    expect(data[1].emaValueList![1], 15);
    expect(data[1].emaValueList![2], closeTo(40 / 3, 1e-10));
    expect(data.last.emaValueList![0], 30);
    expect(data.last.emaValueList![1], 22.5);
    expect(data.last.emaValueList![2], closeTo(170 / 9, 1e-10));
  });

  test('recalculation replaces values without accumulating live updates', () {
    final data = _candles([10, 20, 30]);
    DataUtil.calculate(data);
    final original = List<double>.of(data.last.emaValueList!);
    DataUtil.calculate(data);
    expect(data.last.emaValueList, original);
    data.last.close = 40;
    DataUtil.calculate(data);
    final fresh = _candles([10, 20, 40]);
    DataUtil.calculate(fresh);
    expect(data.last.emaValueList, fresh.last.emaValueList);
    expect(data.first.emaValueList, [10, 10]);
    expect(data.last.emaValueList, hasLength(2));
    expect(data[1].emaValueList![0], closeTo(10 + 20 / 13, 1e-10));
    expect(data[1].emaValueList![1], closeTo(10 + 20 / 27, 1e-10));
    expect(data.last.maValueList, hasLength(3));
  });

  test('EMA handles empty data and rejects invalid periods', () {
    expect(() => DataUtil.calcEMA([], [5, 10, 20]), returnsNormally);
    expect(() => DataUtil.calcEMA(_candles([10]), [0]), throwsArgumentError);
    expect(() => DataUtil.calcEMA(_candles([10]), [-1]), throwsArgumentError);
  });

  testWidgets('chart paints EMA and switches back to MA and BOLL', (
    tester,
  ) async {
    final data = _candles([for (var i = 0; i < 60; i++) 200 - i * 2]);
    DataUtil.calculate(data);
    for (final state in [MainState.EMA, MainState.MA, MainState.BOLL]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 400,
              child: KChartWidget(
                data,
                isTrendLine: false,
                mainState: state,
                secondaryState: SecondaryState.NONE,
                volHidden: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (state == MainState.EMA) {
        final chart = tester.widget<CustomPaint>(
          find.byWidgetPredicate(
            (widget) => widget is CustomPaint && widget.painter is ChartPainter,
          ),
        );
        final painter = chart.painter! as ChartPainter;
        for (var i = painter.mStartIndex; i <= painter.mStopIndex; i++) {
          for (final value in data[i].emaValueList!) {
            expect(painter.mMainMaxValue, greaterThanOrEqualTo(value));
            expect(painter.mMainMinValue, lessThanOrEqualTo(value));
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
