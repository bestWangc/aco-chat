import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:aco_chat/main.dart';

void main() {
  testWidgets('shows live content inline by default on the square tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('正在直播'), findsNothing);
    expect(find.textContaining('美股凭什么依然能打'), findsOneWidget);
  });

  testWidgets('opens coming soon from non-square root navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsNWidgets(2));
  });

  testWidgets('opens the create live page from the square action button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.byKey(const Key('create-live-button')));
    await tester.pumpAndSettle();

    expect(find.text('创建直播'), findsOneWidget);
    expect(find.text('预约时间'), findsOneWidget);
    expect(find.text('上传封面'), findsOneWidget);
  });

  testWidgets('shows the live album cover upload control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.byKey(const Key('create-live-button')));
    await tester.pumpAndSettle();

    expect(find.text('上传封面'), findsOneWidget);
    expect(find.text('链上行情'), findsNothing);
  });

  testWidgets('requires a cover before a live can be confirmed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.byKey(const Key('create-live-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField).first, '今晚聊聊市场走势');
    await tester.pump();

    final confirm = tester.widget<CupertinoButton>(
      find.byKey(const Key('confirm-create-live-button')),
    );
    expect(find.text('*'), findsOneWidget);
    expect(confirm.onPressed, isNull);
  });

  testWidgets('configures password-protected live access', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.byKey(const Key('create-live-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('谁能加入？'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('需要密码才能加入'));
    await tester.pumpAndSettle();

    expect(find.text('设置加入密码'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsWidgets);
  });

  testWidgets('opens a date and time picker for the live schedule', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.byKey(const Key('create-live-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('预约时间'));
    await tester.pumpAndSettle();

    expect(find.text('选择开播时间'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
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
