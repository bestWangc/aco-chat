import 'package:flutter_test/flutter_test.dart';

import 'package:aco_chat/main.dart';

void main() {
  testWidgets('opens the live page from the square tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    expect(find.text('推荐'), findsOneWidget);
    await tester.tap(find.text('直播'));
    await tester.pumpAndSettle();

    expect(find.text('正在直播'), findsOneWidget);
    expect(find.textContaining('美股凭什么依然能打'), findsNWidgets(2));
  });
}
