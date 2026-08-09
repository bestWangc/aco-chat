import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:aco_chat/main.dart';

Future<void> _openSquareTab(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('广场').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows live content inline by default on the square tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await _openSquareTab(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('正在直播'), findsNothing);
    expect(find.textContaining('美股凭什么依然能打'), findsOneWidget);
  });

  testWidgets('opens the voice room when a live card is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await _openSquareTab(tester);

    await tester.tap(find.textContaining('美股凭什么依然能打'));
    await tester.pumpAndSettle();

    expect(find.text('Jason'), findsOneWidget);
    expect(find.text('主持人'), findsOneWidget);
    expect(find.text('美股凭什么依然能打？...'), findsOneWidget);
    expect(find.text('16 人'), findsOneWidget);
    expect(find.text('全屏'), findsNothing);

    final composer = find.byKey(const Key('room-message-input'));
    expect(composer, findsOneWidget);
    expect(tester.getSize(composer).width, greaterThan(140));
    await tester.enterText(composer, '正在听');
    expect(find.text('正在听'), findsOneWidget);

    final micBounds = tester.getRect(find.bySemanticsLabel('静音'));
    final handBounds = tester.getRect(find.bySemanticsLabel('举手'));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(micBounds.left, greaterThanOrEqualTo(18));
    expect(screenWidth - handBounds.right, greaterThanOrEqualTo(18));

    final titleCenter = tester.getCenter(find.text('美股凭什么依然能打？...'));
    final backCenter = tester.getCenter(find.bySemanticsLabel('返回'));
    expect(titleCenter.dx, greaterThan(backCenter.dx));
    expect(titleCenter.dx, lessThan(screenWidth / 2));
  });

  testWidgets('opens the emoji library from the room composer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await _openSquareTab(tester);
    await tester.tap(find.textContaining('美股凭什么依然能打'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.smiley));
    await tester.pumpAndSettle();

    final picker = find.byType(emoji.EmojiPicker);
    expect(picker, findsOneWidget);

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final pickerBounds = tester.getRect(picker);
    expect(pickerBounds.left, greaterThanOrEqualTo(0));
    expect(pickerBounds.right, lessThanOrEqualTo(screenWidth));
  });

  testWidgets('opens the wallet from root navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet1'), findsOneWidget);
    expect(find.text('39800.00'), findsOneWidget);
    expect(
      tester.getRect(find.byIcon(CupertinoIcons.creditcard)).left,
      closeTo(28, 1),
    );

    final addTokenCenter = tester.getCenter(
      find.byKey(const Key('add-token-button')),
    );
    final assetTabCenter = tester.getCenter(find.text('资产'));
    expect(addTokenCenter.dy, closeTo(assetTabCenter.dy, 4));

    final swapButton = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('闪兑'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(swapButton.onPressed, isNull);
  });

  testWidgets('opens the wallet switcher from the wallet selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.bySemanticsLabel('切换钱包'));
    await tester.pumpAndSettle();

    expect(find.text('钱包详情'), findsOneWidget);
    expect(find.text('币安智能链'), findsOneWidget);
  });

  testWidgets('opens the profile page from the account action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    expect(find.bySemanticsLabel('功能菜单'), findsNothing);
    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();

    expect(find.text('Marry'), findsOneWidget);
    expect(find.bySemanticsLabel('返回'), findsOneWidget);
    expect(find.bySemanticsLabel('个人二维码'), findsOneWidget);
    expect(find.bySemanticsLabel('编辑个人资料'), findsOneWidget);
    expect(find.text('个人主页'), findsNothing);
    expect(find.text('主题模式'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('切换钱包'), 180);
    expect(find.text('切换钱包'), findsOneWidget);
    expect(find.text('节点质押'), findsNothing);
    expect(find.text('打赏记录'), findsNothing);
  });

  testWidgets('returns from the profile page', (WidgetTester tester) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();

    expect(find.text('Marry'), findsNothing);
    expect(find.text('Wallet1'), findsOneWidget);
  });

  testWidgets('opens the wallet switcher from the profile page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('切换钱包'), 180);
    await tester.tap(find.text('切换钱包'));
    await tester.pumpAndSettle();

    expect(find.text('钱包详情'), findsOneWidget);
    expect(find.text('币安智能链'), findsOneWidget);
    expect(find.text('BSC-1'), findsOneWidget);
  });

  testWidgets('edits the profile display name', (WidgetTester tester) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('编辑个人资料'));
    await tester.pumpAndSettle();
    expect(find.text('编辑资料'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-name-input')), 'Mina');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(find.text('Mina'), findsOneWidget);
  });

  testWidgets('opens dedicated theme and language settings pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    expect(find.text('外观偏好'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);
    expect(find.text('浅色模式'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    expect(find.text('显示语言'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('opens wallet action menu and navigates to add token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-token-button')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('钱包操作菜单'), findsOneWidget);
    expect(find.text('刷新列表'), findsOneWidget);
    expect(find.text('添加代币'), findsOneWidget);

    await tester.tap(find.text('刷新列表'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('钱包操作菜单'), findsNothing);

    await tester.tap(find.byKey(const Key('add-token-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加代币'));
    await tester.pumpAndSettle();
    expect(find.text('通过代币名称或合约进行搜索'), findsOneWidget);
  });

  testWidgets('navigates from send assets to coming soon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送资产'));
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsNWidgets(2));
    expect(find.bySemanticsLabel('返回'), findsNothing);
    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(barriers.last.color, isNull);
  });

  testWidgets('opens the receive page from the wallet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接收资产'));
    await tester.pumpAndSettle();

    expect(find.text('仅向该地址转入BSC/BEP20相关资产'), findsOneWidget);
    expect(find.text('收款地址'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('分享'), 120);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('设置数额'), findsOneWidget);
  });

  testWidgets('opens the scanner from the wallet', (WidgetTester tester) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('扫码'));
    await tester.pumpAndSettle();

    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.text('将二维码放入框内，即可自动扫描'), findsOneWidget);
    expect(find.text('闪光灯'), findsOneWidget);
    expect(find.text('相册'), findsNothing);
  });

  testWidgets('keeps explore, DEX, and social root navigation unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    for (final label in const ['探索', 'DEX', '社交']) {
      await tester.tap(find.bySemanticsLabel(label).first);
      await tester.pumpAndSettle();

      expect(find.text('Coming Soon'), findsNWidgets(2), reason: label);
    }
  });

  testWidgets('opens the create live page from the square action button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await _openSquareTab(tester);

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
    await _openSquareTab(tester);
    await tester.tap(find.byKey(const Key('create-live-button')));
    await tester.pumpAndSettle();

    expect(find.text('上传封面'), findsOneWidget);
    expect(find.text('链上行情'), findsNothing);
  });

  testWidgets('requires a cover before a live can be confirmed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await _openSquareTab(tester);
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
    await _openSquareTab(tester);
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
    await _openSquareTab(tester);
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
