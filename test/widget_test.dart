import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aco_chat/features/account/domain/account_models.dart';
import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:aco_chat/main.dart';
import 'package:aco_chat/services/wallet_identity.dart';
import 'package:aco_chat/services/wallet_preferences.dart';
import 'package:aco_chat/services/wallet_security.dart';

const _biometricChannel = MethodChannel('aco/biometric-authentication');
const _sensitiveScreenChannel = MethodChannel('aco/sensitive-screen');

Future<void> _openSquareTab(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('广场').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
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

  test('persists a wallet name per wallet address', () async {
    final identity = WalletIdentity(address: '0x1234567890abcdef');
    SharedPreferences.setMockInitialValues({});

    expect(await WalletPreferences.walletName(identity), 'Wallet1');
    await WalletPreferences.saveWalletName(identity, '主钱包');
    expect(await WalletPreferences.walletName(identity), '主钱包');
    await WalletPreferences.saveWalletName(identity, 'Wallet1234567890');
    expect(await WalletPreferences.walletName(identity), 'Wallet123456');
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

  testWidgets('opens the mnemonic backup password prompt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AcoScreenPage(
          screen: AcoScreen.backupMnemonic,
          dark: true,
          isRoot: false,
          onOpen: (_) {},
          onThemeToggle: () {},
          walletIdentity: const WalletIdentity(address: '0x1234'),
          walletSecretStore: InMemoryWalletSecretStore(),
        ),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _sensitiveScreenChannel,
          (_) async => <String, Object?>{},
        );

    expect(find.text('备份助记词，保护钱包安全'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-mnemonic-continue')));
    await tester.pump();
    expect(find.byKey(const Key('export-mnemonic-password')), findsOneWidget);
    expect(find.text('备份助记词，保护钱包安全'), findsOneWidget);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sensitiveScreenChannel, null);
  });

  testWidgets('opens the private-key export password prompt', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _sensitiveScreenChannel,
          (_) async => <String, Object?>{},
        );
    await tester.pumpWidget(
      CupertinoApp(
        home: AcoScreenPage(
          screen: AcoScreen.exportPrivateKey,
          dark: true,
          isRoot: false,
          onOpen: (_) {},
          onThemeToggle: () {},
          walletIdentity: const WalletIdentity(address: '0x1234'),
          walletSecretStore: InMemoryWalletSecretStore(),
        ),
      ),
    );

    expect(find.text('导出私钥，保护钱包安全'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-mnemonic-continue')));
    await tester.pump();
    expect(
      find.byKey(const Key('export-private-key-password')),
      findsOneWidget,
    );
    expect(find.text('导出私钥，保护钱包安全'), findsOneWidget);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sensitiveScreenChannel, null);
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
    final createButton = find.descendant(
      of: find.byKey(const Key('create-wallet-button')),
      matching: find.byType(CupertinoButton),
    );
    expect(tester.widget<CupertinoButton>(createButton).onPressed, isNotNull);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.text('请先同意用户协议和隐私政策'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wallet-terms-checkbox')));
    await tester.pump();
    await tester.tap(createButton);
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

  testWidgets('uses the login Figma button proportions', (tester) async {
    tester.view.physicalSize = const Size(793.701, 1186);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AcoApp(initialWalletConfigured: false));

    final createButtonSize = tester.getSize(
      find.byKey(const Key('create-wallet-button')),
    );
    expect(createButtonSize.width, closeTo(336.8, .2));
    expect(createButtonSize.height, 98);
    expect(
      tester.getTopLeft(find.byKey(const Key('import-wallet-button'))).dx -
          tester.getTopRight(find.byKey(const Key('create-wallet-button'))).dx,
      24,
    );
  });

  testWidgets('does not show mock live sessions on the square tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await _openSquareTab(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('正在直播'), findsNothing);
    expect(find.textContaining('美股凭什么依然能打'), findsNothing);
  });

  testWidgets('shows an empty live chat state without mock messages', (
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

    expect(find.text('请选择直播间后查看弹幕。'), findsOneWidget);
    expect(find.text('Mia:  大家晚上好！'), findsNothing);
  });

  testWidgets('uses the live title in the room header', (
    WidgetTester tester,
  ) async {
    final live = LiveSession(
      id: 7,
      title: '真实直播主题',
      coverUrl: '/uploads/live-cover-9.jpg',
      access: 'open',
      status: 'live',
      createdAt: DateTime(2026, 8, 12, 20),
    );

    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: shad.ShadSlateColorScheme.dark(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.voiceRoom,
            dark: true,
            isRoot: false,
            onOpen: (_) {},
            onThemeToggle: () {},
            live: live,
          ),
        ),
      ),
    );

    expect(find.text('真实直播主题'), findsWidgets);
    expect(find.text('语音房'), findsNothing);
  });

  testWidgets('shows scheduled live notice as a centered dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () => showAcoAlertNotice(context, '预约直播', '该直播尚未开始。'),
            child: const Text('预约直播'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('预约直播'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.text('该直播尚未开始。'), findsOneWidget);
  });

  testWidgets('shows an edit entry for editable scheduled lives', (
    WidgetTester tester,
  ) async {
    final live = LiveSession(
      id: 7,
      title: '明晚市场复盘',
      coverUrl: '/uploads/live-cover-7.jpg',
      access: 'open',
      status: 'scheduled',
      canEdit: true,
      scheduledAt: DateTime(2026, 8, 13, 20),
      createdAt: DateTime(2026, 8, 12, 20),
    );

    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: shad.ShadSlateColorScheme.dark(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.squareFeed,
            dark: true,
            isRoot: false,
            onOpen: (_) {},
            onThemeToggle: () {},
            initialLives: [live],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('修改直播'), findsOneWidget);
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

    expect(find.bySemanticsLabel('切换钱包'), findsOneWidget);
    expect(find.text(r'$'), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    expect(find.byKey(const Key('wallet-details-button')), findsNothing);

    final addTokenCenter = tester.getCenter(
      find.byKey(const Key('add-token-button')),
    );
    final assetTabCenter = tester.getCenter(find.text('资产'));
    expect(addTokenCenter.dy, closeTo(assetTabCenter.dy, 4));
    expect(
      find.byKey(const Key('wallet-tab-selection-indicator')),
      findsOneWidget,
    );

    final addTokenIcon = tester.widget<SvgPicture>(
      find.descendant(
        of: find.byKey(const Key('add-token-button')),
        matching: find.byType(SvgPicture),
      ),
    );
    expect(
      addTokenIcon.colorFilter,
      const ColorFilter.mode(Color(0xFFA6DE00), BlendMode.srcIn),
    );

    final swapButton = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('闪兑'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(swapButton.onPressed, isNull);

    for (final label in ['NFT', '最近活动']) {
      final tab = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(tab.onPressed, isNull, reason: '$label 暂未开放');
    }
  });

  testWidgets('uses a consistent 44 point back button on detail pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AcoScreenPage(
          screen: AcoScreen.receive,
          dark: true,
          isRoot: false,
          onOpen: (_) {},
          onThemeToggle: () {},
        ),
      ),
    );

    final backButton = find.bySemanticsLabel('返回');
    expect(tester.getSize(backButton), const Size(44, 44));
    expect(tester.getRect(backButton).left, closeTo(20, 1));
  });

  testWidgets('keeps wallet header controls visible for a long wallet name', (
    WidgetTester tester,
  ) async {
    const walletName = 'Wallet199999325152615123';
    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: shad.ShadSlateColorScheme.dark(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.walletHome,
            dark: true,
            isRoot: true,
            walletName: walletName,
            onOpen: (_) {},
            onThemeToggle: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(find.text(walletName));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(find.byKey(const Key('wallet-network-selector')), findsOneWidget);
    expect(find.text('Ethereum'), findsOneWidget);
    expect(find.byKey(const Key('wallet-details-button')), findsNothing);
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
    expect(label.style?.fontSize, 13);
    expect(label.style?.fontWeight, FontWeight.w400);
    final inactiveLabel = tester.widget<Text>(find.text('探索'));
    expect(inactiveLabel.style?.color, const Color(0xFFC4C4C4));
  });

  testWidgets('does not make wallet assets tappable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.pumpAndSettle();

    expect(find.text('地址派生中，请稍后刷新。'), findsOneWidget);
    expect(find.text('USDT'), findsNothing);
    expect(find.text('BTC'), findsNothing);
  });

  testWidgets('opens wallet list from the network selector', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.byKey(const Key('wallet-network-selector')));
    await tester.pumpAndSettle();

    expect(find.text('钱包列表'), findsOneWidget);
    expect(find.text('选择网络'), findsNothing);
    expect(find.text('Ethereum'), findsOneWidget);
    expect(find.text('以太坊'), findsNothing);
  });

  testWidgets('shows only supported chains in the wallet list', (
    WidgetTester tester,
  ) async {
    const address = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
    await tester.pumpWidget(
      const AcoApp(initialWalletIdentity: WalletIdentity(address: address)),
    );

    await tester.tap(find.byKey(const Key('wallet-network-selector')));
    await tester.pumpAndSettle();

    for (final chain in ['以太坊', 'BSC', 'Polygon', 'Tron', 'Solana', 'Base']) {
      expect(find.bySemanticsLabel('选择公链 $chain'), findsOneWidget);
    }
    expect(find.text('Avalanche'), findsNothing);
    expect(find.text('Bitcoin'), findsNothing);
    expect(find.text('Cosmos'), findsNothing);
    expect(find.byIcon(CupertinoIcons.chevron_right), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('ETH 0'), findsNothing);
    expect(find.text(r'$ 0.00'), findsNothing);

    final addressRect = tester.getRect(find.text('0x9858effd...aeda94'));
    final copyIconRect = tester.getRect(find.byIcon(CupertinoIcons.doc_on_doc));
    expect(copyIconRect.left, closeTo(addressRect.right + 4, 1));

    await tester.tap(find.text('Wallet1'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.bySemanticsLabel('返回')), const Size(44, 44));
    expect(tester.getRect(find.bySemanticsLabel('返回')).left, closeTo(28, 1));
    expect(find.byKey(const Key('wallet-detail-chain-logo')), findsOneWidget);
    expect(find.text('导出助记词'), findsOneWidget);
    expect(find.text('导出私钥'), findsOneWidget);
    expect(find.text('删除钱包'), findsOneWidget);
    expect(find.byKey(const Key('wallet-detail-copy-address')), findsOneWidget);
  });

  testWidgets('switches the wallet network from the chain rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.byKey(const Key('wallet-network-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('选择公链 BSC'));
    await tester.pumpAndSettle();

    expect(find.text('BSC'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();

    expect(find.text('BSC'), findsWidgets);
    expect(find.text('39800.00'), findsNothing);
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

  testWidgets('opens a personal QR code from the profile page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('个人二维码'));
    await tester.pumpAndSettle();

    expect(find.text('我的二维码'), findsOneWidget);
    expect(find.text('@aco'), findsOneWidget);
    expect(find.bySemanticsLabel('个人二维码：@aco'), findsOneWidget);
    expect(find.text('扫一扫上面的二维码图案，加我为朋友。'), findsOneWidget);
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

  testWidgets('requires an authenticated session to save profile changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());
    await tester.tap(find.bySemanticsLabel('账户'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('编辑个人资料'));
    await tester.pumpAndSettle();
    expect(find.text('编辑资料'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-name-input')), 'Mina');
    await tester.enterText(
      find.byKey(const Key('profile-username-input')),
      'mina_aco',
    );
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(find.text('编辑资料'), findsOneWidget);
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
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(
      find.byIcon(CupertinoIcons.check_mark_circled_solid),
      findsOneWidget,
    );
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

  testWidgets('opens wallet action menu and disables adding tokens', (
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
    final addTokenMenuItem = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('添加代币'),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(addTokenMenuItem.onPressed, isNull);
  });

  testWidgets('selects a token before opening the transfer page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送资产'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('send-token-picker')), findsOneWidget);
    expect(find.text('选择转账代币'), findsOneWidget);
    expect(find.byKey(const Key('send-token-ETH')), findsOneWidget);
    expect(find.byKey(const Key('send-token-USDT')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('send-token-search')),
      'ethereum',
    );
    await tester.pump();
    expect(find.byKey(const Key('send-token-ETH')), findsOneWidget);
    expect(find.byKey(const Key('send-token-USDT')), findsNothing);
    await tester.tap(find.byKey(const Key('send-token-ETH')));
    await tester.pumpAndSettle();

    expect(find.text('转账'), findsOneWidget);
    expect(find.text('收款地址'), findsOneWidget);
    expect(find.text('选择钱包'), findsNothing);
    expect(find.text('转账金额'), findsOneWidget);
    expect(find.text('网络费'), findsOneWidget);
    expect(find.text('0 ETH'), findsNWidgets(2));
    final confirmButton = find.byKey(const Key('transfer-confirm-button'));
    expect(tester.widget<CupertinoButton>(confirmButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('transfer-recipient-field')),
      '0x1234567890abcdef',
    );
    await tester.enterText(find.byKey(const Key('transfer-amount-field')), '1');
    await tester.pump();
    expect(tester.widget<CupertinoButton>(confirmButton).onPressed, isNull);
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

    expect(find.text('仅向该地址转入 Ethereum/ERC20 相关资产'), findsOneWidget);
    expect(find.text('收款地址'), findsOneWidget);
    expect(find.text(address), findsOneWidget);
    expect(find.bySemanticsLabel('收款二维码：$address'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('receive-qr-surface'))),
      const Size(288, 288),
    );
    await tester.scrollUntilVisible(find.text('分享'), 120);
    expect(find.text('分享'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('设置数额'), findsOneWidget);
  });

  testWidgets('uses derived addresses when receiving on Tron and Solana', (
    WidgetTester tester,
  ) async {
    const evmAddress = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
    const tronAddress = 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH';
    const solanaAddress = 'GjJyeC1r2RgkuoCWMyPYkCWSGSGLcz266EaAkLA27AhL';
    SharedPreferences.setMockInitialValues({
      'wallet.derived-addresses.$evmAddress':
          '{"tron":"$tronAddress","solana":"$solanaAddress"}',
    });
    await tester.pumpWidget(
      const AcoApp(initialWalletIdentity: WalletIdentity(address: evmAddress)),
    );

    for (final chain in [
      ('Tron', tronAddress, '仅向该地址转入 TRON/TRC20 相关资产'),
      ('Solana', solanaAddress, '仅向该地址转入 Solana 相关资产'),
    ]) {
      await tester.tap(find.byKey(const Key('wallet-network-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('选择公链 ${chain.$1}'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('接收资产'));
      await tester.pumpAndSettle();

      expect(find.text(chain.$3), findsOneWidget);
      expect(find.text(chain.$2), findsOneWidget);
      expect(find.text(evmAddress), findsNothing);
      expect(find.bySemanticsLabel('收款二维码：${chain.$2}'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('返回'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('opens the scanner from the wallet', (WidgetTester tester) async {
    await tester.pumpWidget(const AcoApp());

    await tester.tap(find.text('钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('扫码'));
    await tester.pumpAndSettle();

    expect(find.text('扫一扫'), findsOneWidget);
    expect(find.byKey(const Key('scan-back-button')), findsOneWidget);
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

  testWidgets('matches the square feed search button proportions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AcoScreenPage(
          screen: AcoScreen.squareFeed,
          dark: true,
          isRoot: true,
          onOpen: (_) {},
          onThemeToggle: () {},
        ),
      ),
    );

    final submit = find.byKey(const Key('square-search-submit'));
    expect(submit, findsOneWidget);
    expect(tester.getSize(submit), const Size(56, 38));

    final decoration =
        tester.widget<Container>(submit).decoration! as BoxDecoration;
    expect(decoration.borderRadius, isA<BorderRadius>());
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
