import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';
import 'package:flutter/foundation.dart';

import '../../../services/android_chat_background_service.dart';

import '../domain/chat_repository.dart';

/// OpenIM SDK 适配层。业务页面只依赖 [ChatRepository]。
final class OpenIMChatRepository implements ChatRepository {
  static bool _sdkInitialized = false;
  static String? _currentUserID;
  static String? get currentUserID => _currentUserID;
  static final ValueNotifier<int> friendRequestCountNotifier =
      ValueNotifier<int>(0);
  static final ValueNotifier<Message?> messageNotifier =
      ValueNotifier<Message?>(null);
  static final ValueNotifier<bool> messageUnreadNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<int> conversationRevision = ValueNotifier<int>(0);
  static final ValueNotifier<bool> conversationReady = ValueNotifier<bool>(
    false,
  );
  static Future<void> Function()? reconnectHandler;
  static String? _activeChatPeerUserID;
  static final Set<String> _locallyLeavingGroupIDs = <String>{};
  static final Set<String> _handledGroupRemovalIDs = <String>{};

  static void publishLocalMessage(Message message) {
    messageNotifier.value = message;
    conversationRevision.value++;
  }

  static bool isVoiceCallMessage(Message? message) =>
      message?.customElem?.extension == 'aco.voice_call';

  static bool isVoiceCallInvite(Message? message) {
    final payload = _voiceCallPayload(message);
    return payload?['type'] == 'aco.voice_call.invite';
  }

  static Map<String, dynamic>? _voiceCallPayload(Message? message) {
    final data = message?.customElem?.data;
    if (!isVoiceCallMessage(message) || data == null || data.isEmpty) {
      return null;
    }
    try {
      final payload = jsonDecode(data);
      return payload is Map<String, dynamic> ? payload : null;
    } catch (_) {
      return null;
    }
  }

  /// OpenIM stores ordinary and @ text in different element types. Keeping the
  /// lookup here prevents the chat page, conversation list and notification
  /// policy from drifting apart.
  static String? messageText(Message? message) {
    final plainText = message?.textElem?.content;
    if (plainText?.isNotEmpty == true) return plainText;
    final atText = message?.atTextElem?.text;
    return atText?.isNotEmpty == true ? atText : null;
  }

  static bool isMentioningCurrentUser(Message message) {
    final currentUserID = _currentUserID;
    if (currentUserID == null || message.sendID == currentUserID) return false;
    final atText = message.atTextElem;
    return atText?.isAtSelf == true ||
        atText?.atUserList?.contains(currentUserID) == true;
  }

  /// Only content a user can read or act on should create a chat reminder.
  /// Group membership and other OpenIM system events update the conversation,
  /// but should not surface as a social unread badge or system notification.
  static bool isNotifiableMessage(Message message) =>
      messageText(message) != null ||
      message.pictureElem != null ||
      message.soundElem != null ||
      isVoiceCallInvite(message);

  static bool shouldNotifyForMessage(Message message) {
    final currentUserID = _currentUserID;
    final senderID = message.sendID;
    if (currentUserID == null ||
        senderID == null ||
        senderID == currentUserID ||
        !isNotifiableMessage(message)) {
      return false;
    }
    return _messageConversationTarget(message) != _activeChatPeerUserID;
  }

  static String? _messageConversationTarget(Message message) {
    final groupID = message.groupID;
    return groupID?.isNotEmpty == true ? groupID : message.sendID;
  }

  static int visibleUnreadCount(ConversationInfo conversation) {
    if (conversation.unreadCount <= 0) return 0;
    final currentUserID = _currentUserID;
    final latestMessage = conversation.latestMsg;
    if (currentUserID == null || latestMessage == null) {
      return conversation.unreadCount;
    }
    final target = _conversationTarget(conversation);
    if (latestMessage.sendID == currentUserID ||
        !isNotifiableMessage(latestMessage) ||
        target == _activeChatPeerUserID) {
      return 0;
    }
    return conversation.unreadCount;
  }

  static String? _conversationTarget(ConversationInfo conversation) =>
      conversation.isGroupChat ? conversation.groupID : conversation.userID;

  static bool hasUnreadMessagesFromOthers(
    Iterable<ConversationInfo> conversations,
  ) =>
      conversations.any((conversation) => visibleUnreadCount(conversation) > 0);

  /// Keeps messages from the conversation currently on screen out of the
  /// global social-entry badge. The chat page still marks the conversation as
  /// read in OpenIM so this is only needed while that asynchronous update is
  /// in flight.
  static void beginActiveChat(String peerUserID) {
    _activeChatPeerUserID = peerUserID;
    unawaited(refreshMessageUnreadStatus());
  }

  static void endActiveChat(String peerUserID) {
    if (_activeChatPeerUserID == peerUserID) {
      _activeChatPeerUserID = null;
      unawaited(refreshMessageUnreadStatus());
    }
  }

  /// Suppress the local echo generated when the user deliberately exits a
  /// group. The same SDK callback represents removal by an administrator.
  static void beginLeavingGroup(String groupID) {
    _locallyLeavingGroupIDs.add(groupID);
  }

  static void cancelLeavingGroup(String groupID) {
    _locallyLeavingGroupIDs.remove(groupID);
  }

  /// The backend has already removed the membership, so refresh the visible
  /// conversation list immediately instead of waiting for OpenIM's callback.
  static void completeLeavingGroup() {
    conversationRevision.value++;
    unawaited(refreshMessageUnreadStatus());
  }

  /// Conversation selected from the list, consumed by the detail route.
  static ConversationInfo? pendingConversation;

  /// Search result selected from the social page, consumed once by chat.
  static Message? pendingSearchMessage;
  OpenIMChatRepository({IMManager? sdk}) : _sdk = sdk ?? OpenIM.iMManager;

  final IMManager _sdk;

  Future<List<ConversationInfo>> conversations() =>
      _sdk.conversationManager.getAllConversationList();

  @override
  Future<void> initialize({
    required String apiAddr,
    required String wsAddr,
    required String dataDir,
  }) async {
    if (!_sdkInitialized) {
      await _sdk.initSDK(
        platformID: Platform.isIOS ? IMPlatform.ios : IMPlatform.android,
        apiAddr: apiAddr,
        wsAddr: wsAddr,
        dataDir: dataDir,
        listener: OnConnectListener(
          onConnecting: () => developer.log('连接中', name: 'OpenIM.connection'),
          onConnectSuccess: () =>
              developer.log('连接成功', name: 'OpenIM.connection'),
          onConnectFailed: (code, message) => developer.log(
            '连接失败 code=$code message=$message',
            name: 'OpenIM.connection',
          ),
          onUserTokenExpired: _handleConnectionLost,
          onUserTokenInvalid: _handleConnectionLost,
          onKickedOffline: _handleConnectionLost,
        ),
        logLevel: 3,
        isLogStandardOutput: false,
      );
      _sdkInitialized = true;
      await _registerListeners();
    }
  }

  static void _handleConnectionLost() {
    conversationReady.value = false;
    developer.log('OpenIM 连接失效，准备重连', name: 'OpenIM.connection');
    final reconnect = reconnectHandler;
    if (reconnect != null) unawaited(reconnect());
  }

  @override
  Future<void> login({required String userId, required String userSig}) async {
    // Native SDK may finish initSDK before its database worker is ready.
    // Waiting briefly avoids the transient 10004 resource-initialization error
    // seen on iOS/Android during cold start.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await _sdk.login(userID: userId, token: userSig);
      _currentUserID = userId;
    } catch (error) {
      if (!error.toString().contains('10004')) rethrow;
      await Future<void>.delayed(const Duration(seconds: 1));
      await _sdk.login(userID: userId, token: userSig);
      _currentUserID = userId;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    await _registerListeners();
    await _refreshMessageUnreadStatus();
    conversationReady.value = true;
    // flutter_openim_sdk 3.8.3+hotfix.14 exposes setListenerForService in
    // Dart, but the Android plugin does not implement the corresponding
    // native method (the Java method is commented out). Calling it therefore
    // raises NoSuchMethodException on Android and can interrupt login setup.
    // Friendship events are delivered through setFriendshipListener, which is
    // implemented on both supported platforms, so keep a single canonical
    // event path here.
  }

  Future<void> _registerListeners() async {
    await _registerMessageListener();
    await _registerFriendshipListener();
    await _registerGroupListener();
  }

  Future<void> _registerMessageListener() async {
    try {
      await _sdk.messageManager.setAdvancedMsgListener(
        OnAdvancedMsgListener(
          onRecvNewMessage: _handleIncomingMessage,
          onRecvOfflineNewMessage: _handleIncomingMessage,
        ),
      );
    } catch (error) {
      // Some native SDKs only accept listener registration after login. The
      // post-login call retries without preventing the session from starting.
      developer.log('消息监听器注册失败: $error', name: 'OpenIM.message');
    }
  }

  Future<void> _registerFriendshipListener() async {
    try {
      await _sdk.friendshipManager.setFriendshipListener(
        OnFriendshipListener(
          onFriendApplicationAdded: (info) {
            // The SDK may echo an outgoing request to the sender. A badge is
            // only meaningful when the current user is the recipient.
            final currentUserID = _currentUserID;
            if (!_isIncomingFriendApplication(info, currentUserID)) {
              return;
            }
            friendRequestCountNotifier.value++;
            final name = info.fromNickname?.trim();
            unawaited(
              AndroidChatBackgroundService.showMessage(
                title: '新的朋友',
                body: name?.isNotEmpty == true ? '$name 请求添加你为好友' : '你收到一条好友申请',
              ),
            );
            developer.log(
              '收到好友申请: ${info.fromUserID}',
              name: 'OpenIM.friendship',
            );
          },
        ),
      );
      developer.log('好友监听器注册成功', name: 'OpenIM.friendship');
    } catch (error) {
      developer.log('好友监听器注册失败: $error', name: 'OpenIM.friendship');
    }
  }

  static bool _isIncomingFriendApplication(
    FriendApplicationInfo info,
    String? currentUserID,
  ) {
    if (currentUserID == null || info.fromUserID == currentUserID) {
      return false;
    }
    final recipientID = info.toUserID;
    return recipientID == null ||
        recipientID.isEmpty ||
        recipientID == currentUserID;
  }

  Future<void> _registerGroupListener() async {
    try {
      await _sdk.groupManager.setGroupListener(
        OnGroupListener(
          onJoinedGroupAdded: (_) => conversationRevision.value++,
          onJoinedGroupDeleted: (group) =>
              _handleGroupDeparture(group, '你已被移出群聊'),
          onGroupDismissed: (group) => _handleGroupDeparture(group, '群聊已解散'),
          onGroupInfoChanged: (_) => conversationRevision.value++,
          onGroupMemberAdded: (_) => conversationRevision.value++,
          onGroupMemberDeleted: (_) => conversationRevision.value++,
        ),
      );
    } catch (error) {
      developer.log('群事件监听器注册失败: $error', name: 'OpenIM.group');
    }
  }

  static void _handleIncomingMessage(Message message) {
    messageNotifier.value = message;
    if (shouldNotifyForMessage(message)) {
      messageUnreadNotifier.value = true;
      unawaited(
        AndroidChatBackgroundService.showMessage(
          title: message.senderNickname?.isNotEmpty == true
              ? message.senderNickname!
              : '新消息',
          body: _notificationPreview(message),
          urgent:
              isMentioningCurrentUser(message) || isVoiceCallInvite(message),
        ),
      );
    }
    conversationRevision.value++;
  }

  static void _handleGroupDeparture(GroupInfo group, String notice) {
    conversationRevision.value++;
    if (_locallyLeavingGroupIDs.remove(group.groupID)) return;
    _notifyGroupRemoval(group, notice);
  }

  static void _notifyGroupRemoval(GroupInfo group, String fallback) {
    // A dissolve may result in both group callbacks. Surface it once only.
    if (!_handledGroupRemovalIDs.add(group.groupID)) return;
    final groupName = group.groupName?.trim();
    unawaited(
      AndroidChatBackgroundService.showMessage(
        title: groupName?.isNotEmpty == true ? groupName! : '群聊通知',
        body: fallback,
      ),
    );
  }

  static String _notificationPreview(Message message) {
    final text = messageText(message);
    if (text != null) {
      return isMentioningCurrentUser(message) ? '[@你] $text' : text;
    }
    if (message.soundElem != null) return '[语音消息]';
    if (message.pictureElem != null) return '[图片]';
    if (isVoiceCallInvite(message)) return '[语音通话]';
    return '[新消息]';
  }

  Future<void> _refreshMessageUnreadStatus() async {
    try {
      final conversations = await _sdk.conversationManager
          .getAllConversationList();
      messageUnreadNotifier.value = hasUnreadMessagesFromOthers(conversations);
    } catch (error) {
      developer.log('未读消息状态加载失败: $error', name: 'OpenIM.message');
    }
  }

  static Future<void> refreshMessageUnreadStatus() async {
    final currentUserID = _currentUserID;
    if (currentUserID == null) return;
    try {
      final conversations = await OpenIM.iMManager.conversationManager
          .getAllConversationList();
      messageUnreadNotifier.value = hasUnreadMessagesFromOthers(conversations);
    } catch (error) {
      developer.log('未读消息状态刷新失败: $error', name: 'OpenIM.message');
    }
  }

  /// Entering the social tab is not the same as reading every conversation.
  /// Recalculate from OpenIM instead of clearing unrelated unread messages.
  static void markMessagesSeen() => unawaited(refreshMessageUnreadStatus());

  static void setFriendRequestCount(int count) {
    friendRequestCountNotifier.value = count < 0 ? 0 : count;
  }

  @override
  Future<void> logout() async {
    await _sdk.logout();
    _currentUserID = null;
    _activeChatPeerUserID = null;
    _locallyLeavingGroupIDs.clear();
    _handledGroupRemovalIDs.clear();
    friendRequestCountNotifier.value = 0;
    messageUnreadNotifier.value = false;
    conversationReady.value = false;
    _sdkInitialized = false;
  }
}
