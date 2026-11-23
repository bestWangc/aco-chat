import 'dart:convert';

import 'package:aco_chat/features/chat/data/openim_chat_repository.dart';
import 'package:aco_chat/app/presentation/aco_app_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_openim_sdk');
  final deletedIDs = <String>[];
  var failSecondMessage = false;

  setUp(() {
    deletedIDs.clear();
    failSecondMessage = false;
    OpenIMChatRepository.conversationReady.value = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getOneConversation':
              return jsonEncode({
                'conversationID': 'sg_test',
                'unreadCount': 0,
                'groupID': 'test',
              });
            case 'getAdvancedHistoryMessageList':
              return jsonEncode({
                'isEnd': true,
                'messageList': [
                  for (var i = 1; i <= 3; i++)
                    {
                      'clientMsgID': 'message-$i',
                      'sendID': 'friend',
                      'groupID': 'test',
                      'contentType': 101,
                      'sendTime': 1700000000 + i,
                      'textElem': {'content': '消息$i'},
                    },
                ],
              });
            case 'getGroupMemberList':
            case 'getGroupsInfo':
              return '[]';
            case 'deleteMessageFromLocalStorage':
              final arguments = call.arguments as Map;
              expect(arguments['conversationID'], 'sg_test');
              final id = arguments['clientMsgID'] as String;
              if (failSecondMessage && id == 'message-2') {
                throw PlatformException(code: 'delete_failed');
              }
              deletedIDs.add(id);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    OpenIMChatRepository.conversationReady.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openSelection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      shad.ShadApp.custom(
        theme: shad.ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: shad.ShadSlateColorScheme.dark(),
        ),
        appBuilder: (_) => CupertinoApp(
          home: AcoScreenPage(
            screen: AcoScreen.chatV1,
            dark: true,
            isRoot: true,
            chatGroupID: 'test',
            chatConversationID: 'sg_test',
            chatName: '测试群聊',
            onOpen: (_) {},
            onThemeToggle: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('消息1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择聊天记录'));
    await tester.pumpAndSettle();
  }

  testWidgets('deletes only selected messages after confirmation', (
    tester,
  ) async {
    await openSelection(tester);
    await tester.tap(find.byKey(const ValueKey('select-message-message-1')));
    await tester.tap(find.byKey(const ValueKey('select-message-message-2')));
    await tester.pump();
    await tester.tap(find.text('删除（2）'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(deletedIDs, isEmpty);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
    await tester.pumpAndSettle();
    expect(find.text('消息1'), findsOneWidget);
    await tester.tap(find.text('删除（2）'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
    await tester.pumpAndSettle();
    expect(deletedIDs, ['message-1', 'message-2']);
    expect(find.text('消息1'), findsNothing);
    expect(find.text('消息2'), findsNothing);
    expect(find.text('消息3'), findsOneWidget);
    expect(find.text('已选择 0 条'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps failed messages selected for retry', (tester) async {
    failSecondMessage = true;
    await openSelection(tester);
    await tester.tap(find.byKey(const ValueKey('select-message-message-1')));
    await tester.tap(find.byKey(const ValueKey('select-message-message-2')));
    await tester.pump();
    await tester.tap(find.text('删除（2）'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
    await tester.pumpAndSettle();
    expect(deletedIDs, ['message-1']);
    expect(find.text('消息1'), findsNothing);
    expect(find.text('消息2'), findsOneWidget);
    expect(find.text('消息3'), findsOneWidget);
    expect(find.text('已选择 1 条'), findsOneWidget);
    expect(find.text('部分消息删除失败'), findsOneWidget);
    await tester.tap(find.byType(CupertinoActionSheetAction).first);
    await tester.pumpAndSettle();
    failSecondMessage = false;
    await tester.tap(find.text('删除（1）'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
    await tester.pumpAndSettle();
    expect(deletedIDs, ['message-1', 'message-2']);
    expect(find.text('消息2'), findsNothing);
    expect(find.text('消息3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
