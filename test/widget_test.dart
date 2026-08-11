import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:aco_chat/main.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_preferences.dart';

const _biometricChannel = MethodChannel('aco/biometric-authentication');

Future<void> _openSquareTab(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('广场').first);
  await tester.pumpAndSettle();
}

void main() {
  test('persists the selected theme preference', () async {
    SharedPreferences.setMockInitialValues({ThemePreferences.themeKey: false});

    expect(await ThemePreferences.load(), isFalse);
    await ThemePreferences.save(true);
    expect(await ThemePreferences.load(), isTrue);
  });

  test('persists whether a wallet has been configured', () async {
    SharedPreferences.setMockInitialValues({
      WalletPreferences.configuredKey: false,
    });

    expect(await WalletPreferences.load(), isFalse);
    await WalletPreferences.save(true);
    expect(await WalletPreferences.load(), isTrue);
  });

  test('removes legacy placeholder wallet data', () async {
    SharedPreferences.setMockInitialValues({
      'wallet.address': 'aco_123456',
      WalletPreferences.configuredKey: true,
    });

    await WalletPreferences.removeLegacyPlaceholderData();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('wallet.address'), isNull);
    expect(await WalletPreferences.load(), isFalse);
  });

  testWidgets('shows wallet setup before the first wallet is configured', (
    WidgetTester tester,
  ) async {
    var walletConfigured = false;
    await tester.pumpWidget(
      AcoApp(
        initialWalletConfigured: false,
        onWalletConfigured: (_) => walletConfigured = true,
      ),
    );

    expect(find.bySemanticsLabel('Aco Chat 品牌标识'), findsOneWidget);
    expect(find.text('创建新钱包或导入已有钱包\n开始使用'), findsOneWidget);
    expect(find.text('创建钱包'), findsOneWidget);
    expect(find.text('导入钱包'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('create-wallet-button')),
      160,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('create-wallet-button')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('备份助记词'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-confirmation')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('continue-create-wallet-button')));
    await tester.pumpAndSettle();
    expect(find.text('验证助记词'), findsOneWidget);
    final verificationPrompt = tester
        .widget<Text>(find.textContaining('请按顺序选择：'))
        .data!;
    final verificationIndexes = RegExp(
      r'第 (\d+) 个',
    ).allMatches(verificationPrompt).map((match) => int.parse(match.group(1)!));
    final indexes = verificationIndexes.toList();
    for (final index in indexes.reversed) {
      await tester.tap(find.byKey(Key('mnemonic-word-${index - 1}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('continue-create-wallet-button')));
    await tester.pumpAndSettle();
    expect(find.text('助记词顺序不正确，请重新选择。'), findsOneWidget);
    expect(find.byKey(const Key('wallet-password-field')), findsNothing);

    for (final index in indexes) {
      await tester.tap(find.byKey(Key('mnemonic-word-${index - 1}')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('continue-create-wallet-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-password-field')), findsOneWidget);
    expect(find.byKey(const Key('wallet-biometric-button')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('wallet-password-field')),
      'secure123',
    );
    await tester.enterText(
      find.byKey(const Key('wallet-password-confirm-field')),
      'secure123',
    );
    await tester.pump();
    var biometricPrompted = false;
    final biometricResponse = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_biometricChannel, (call) async {
          biometricPrompted = call.method == 'authenticate';
          return biometricResponse.future;
        });
    await tester.tap(find.byKey(const Key('continue-create-wallet-button')));
    await tester.pump();
    expect(biometricPrompted, isTrue);
    expect(find.text('正在创建钱包...'), findsOneWidget);
    biometricResponse.complete(false);
    await tester.pump();
    expect(find.byKey(const Key('wallet-password-field')), findsOneWidget);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_biometricChannel, null);
    expect(walletConfigured, isFalse);
  });

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

  testWidgets('uses readable room chat text in light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.light,
          colorScheme: shad.ShadSlateColorScheme.light(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.voiceRoom,
            dark: false,
            isRoot: false,
            onOpen: (_) {},
            onThemeToggle: () {},
          ),
        ),
      ),
    );

    final message = tester.widget<Text>(find.text('Mia:  大家晚上好！'));
    expect(message.style?.color, const Color(0xFF151515));
    await tester.scrollUntilVisible(
      find.text('欢迎 Sophia 进入直播间'),
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('room-chat-history')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('欢迎 Sophia 进入直播间'), findsOneWidget);
  });

  testWidgets('uses the muted microphone treatment in light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.light,
          colorScheme: shad.ShadSlateColorScheme.light(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.voiceRoom,
            dark: false,
            isRoot: false,
            onOpen: (_) {},
            onThemeToggle: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('静音'));
    await tester.pump();

    final microphone = tester.widget<Icon>(
      find.byIcon(CupertinoIcons.mic_slash),
    );
    expect(microphone.color, const Color(0xFFFF3B4E));
  });

  testWidgets('opens the wallet from root navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();

    expect(find.text('Wallet1'), findsOneWidget);
    expect(find.text('usd'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
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

  testWidgets('uses dark active bottom navigation in light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AcoBottomNav(selected: 0, dark: false, onSelected: (_) {}),
      ),
    );

    final label = tester.widget<Text>(find.text('钱包'));
    expect(label.style?.color, const Color(0xFF151515));
    final inactiveLabel = tester.widget<Text>(find.text('探索'));
    expect(inactiveLabel.style?.color, const Color(0xFFC4C4C4));
  });

  testWidgets('does not make wallet assets tappable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    expect(
      find.ancestor(
        of: find.text('ETH'),
        matching: find.byType(CupertinoButton),
      ),
      findsNothing,
    );
    expect(find.text('USDT'), findsOneWidget);
    expect(find.text('BTC'), findsNothing);
  });

  testWidgets('opens wallet list from the network selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('以太坊'));
    await tester.pumpAndSettle();

    expect(find.text('钱包列表'), findsOneWidget);
    expect(find.text('选择网络'), findsNothing);
  });

  testWidgets('shows only supported chains in the wallet list', (
    WidgetTester tester,
  ) async {
    const address = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
    await tester.pumpWidget(
      const AcoApp(initialWalletIdentity: WalletIdentity(address: address)),
    );

    await tester.tap(find.text('以太坊'));
    await tester.pumpAndSettle();

    for (final chain in ['以太坊', 'BSC', 'Polygon', 'Tron', 'Solana', 'Base']) {
      expect(find.bySemanticsLabel('选择公链 $chain'), findsOneWidget);
    }
    expect(find.text('Avalanche'), findsNothing);
    expect(find.text('Bitcoin'), findsNothing);
    expect(find.text('Cosmos'), findsNothing);
    expect(find.text('当前'), findsNothing);
    expect(find.byIcon(CupertinoIcons.chevron_right), findsNothing);
    expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);
    expect(find.text('ETH 0'), findsNothing);
    expect(find.text(r'$ 0.00'), findsOneWidget);

    final addressRect = tester.getRect(find.text('0x9858effd...aeda94'));
    final copyIconRect = tester.getRect(find.byIcon(CupertinoIcons.doc_on_doc));
    expect(copyIconRect.left, closeTo(addressRect.right + 5, 1));
  });

  testWidgets('switches the wallet network from the chain rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('以太坊'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('选择公链 BSC'));
    await tester.pumpAndSettle();

    expect(find.text('BSC'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();

    expect(find.text('BSC'), findsOneWidget);
    expect(find.text('BNB'), findsOneWidget);
    expect(find.text('ETH'), findsNothing);
  });

  testWidgets('opens wallet list from the wallet dropdown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.bySemanticsLabel('切换钱包'));
    await tester.pumpAndSettle();

    expect(find.text('钱包列表'), findsOneWidget);
    expect(find.text('暂无钱包'), findsOneWidget);
    expect(find.text('BSC-1'), findsNothing);
    expect(find.text('TASDFSk...FAGSGS2324t'), findsNothing);
    expect(find.text('\$ 7,123,456,789,778.00'), findsNothing);
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
    expect(find.text('切换钱包'), findsNothing);
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

  testWidgets('applies light mode to the app theme and current screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('浅色模式'));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(AcoScreenPage));
    expect(CupertinoTheme.of(context).brightness, Brightness.light);
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

  testWidgets('shows a notice when sending assets is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送资产'));
    await tester.pumpAndSettle();

    expect(find.text('发送资产'), findsNWidgets(2));
    expect(find.text('发送功能即将开放。'), findsOneWidget);
  });

  testWidgets('opens the receive page from the wallet', (
    WidgetTester tester,
  ) async {
    const address = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
    await tester.pumpWidget(
      const AcoApp(initialWalletIdentity: WalletIdentity(address: address)),
    );

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接收资产'));
    await tester.pumpAndSettle();

    expect(find.text('仅向该地址转入BSC/BEP20相关资产'), findsOneWidget);
    expect(find.text('收款地址'), findsOneWidget);
    expect(find.text(address), findsOneWidget);
    expect(find.bySemanticsLabel('收款二维码：$address'), findsOneWidget);
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

  testWidgets('uses light controls on the scanner in light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.light,
          colorScheme: shad.ShadSlateColorScheme.light(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.scan,
            dark: false,
            isRoot: false,
            onOpen: (_) {},
            onThemeToggle: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('扫一扫'));
    expect(title.style?.color, const Color(0xFF151515));

    final scanFrame = tester.widget<Container>(
      find.byKey(const ValueKey('scan-frame')),
    );
    final decoration = scanFrame.decoration! as BoxDecoration;
    expect(decoration.border, isA<Border>());
    expect((decoration.border! as Border).top.color, const Color(0xFF151515));
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
