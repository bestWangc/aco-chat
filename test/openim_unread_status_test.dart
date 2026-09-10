import 'package:aco_chat/features/chat/data/openim_chat_repository.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleared conversations do not keep the global unread badge', () {
    final clearedConversation = ConversationInfo(
      conversationID: 'sg_cleared',
      unreadCount: 1,
    );

    expect(OpenIMChatRepository.visibleUnreadCount(clearedConversation), 0);
    expect(
      OpenIMChatRepository.hasUnreadMessagesFromOthers([clearedConversation]),
      isFalse,
    );
  });

  test('hidden OpenIM conversations do not create a global badge', () {
    final visibleConversation = ConversationInfo(conversationID: 'si_visible');
    final hiddenConversation = ConversationInfo(
      conversationID: 'sg_left',
      unreadCount: 2,
      latestMsg: Message(sendID: 'imAdmin'),
    );

    OpenIMChatRepository.updateAuthorizedConversations([visibleConversation]);

    expect(
      OpenIMChatRepository.hasUnreadMessagesFromOthers([hiddenConversation]),
      isFalse,
    );
    expect(OpenIMChatRepository.messageUnreadNotifier.value, isFalse);
  });

  test('newly authorized conversations retain their unread status', () {
    final conversation = ConversationInfo(
      conversationID: 'sg_joined',
      unreadCount: 1,
      latestMsg: Message(
        sendID: 'member',
        textElem: TextElem(content: '你好'),
      ),
    );

    OpenIMChatRepository.updateAuthorizedConversations([conversation]);

    expect(OpenIMChatRepository.messageUnreadNotifier.value, isTrue);
  });

  test('unsupported latest messages do not create a global badge', () {
    final conversation = ConversationInfo(
      conversationID: 'sg_system',
      unreadCount: 1,
      latestMsg: Message(sendID: 'member'),
    );

    OpenIMChatRepository.updateAuthorizedConversations([conversation]);

    expect(OpenIMChatRepository.messageUnreadNotifier.value, isFalse);
  });
}
