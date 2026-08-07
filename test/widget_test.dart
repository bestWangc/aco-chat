import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
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

  testWidgets('builds every current design screen without exceptions', (
    WidgetTester tester,
  ) async {
    for (final dark in [true, false]) {
      for (final screen in AcoScreen.values) {
        await tester.pumpWidget(
          shad.ShadApp.custom(
            theme: shad.ShadThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              colorScheme: dark
                  ? shad.ShadSlateColorScheme.dark()
                  : shad.ShadSlateColorScheme.light(),
            ),
            appBuilder: (_) => CupertinoApp(
              home: AcoScreenPage(
                screen: screen,
                dark: dark,
                isRoot: false,
                onOpen: (_) {},
                onThemeToggle: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${dark ? 'dark' : 'light'} ${screen.name}',
        );
      }
    }
  });
}
