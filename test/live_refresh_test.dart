import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('allows the live list to refresh when pulled down', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AcoScreenPage(
          screen: AcoScreen.squareFeed,
          dark: true,
          isRoot: true,
          initialLives: const [],
          onOpen: (_) {},
          onThemeToggle: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final liveList = find.byType(CustomScrollView);
    expect(liveList, findsOneWidget);

    await tester.drag(liveList, const Offset(0, 180));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
