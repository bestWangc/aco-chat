import 'dart:async';
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

  /// Conversation selected from the list, consumed by the detail route.
  static ConversationInfo? pendingConversation;
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
            if (currentUserID == null ||
                info.fromUserID == currentUserID ||
                (info.toUserID != null &&
                    info.toUserID!.isNotEmpty &&
                    info.toUserID != currentUserID)) {
              return;
            }
            friendRequestCountNotifier.value++;
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

  static void _handleIncomingMessage(Message message) {
    messageNotifier.value = message;
    if (message.sendID != _currentUserID) {
      messageUnreadNotifier.value = true;
      unawaited(
        AndroidChatBackgroundService.showMessage(
          title: message.senderNickname?.isNotEmpty == true
              ? message.senderNickname!
              : '新消息',
          body: _notificationPreview(message),
        ),
      );
    }
    conversationRevision.value++;
  }

  static String _notificationPreview(Message message) {
    final text = message.textElem?.content;
    if (text?.isNotEmpty == true) return text!;
    if (message.soundElem != null) return '[语音消息]';
    if (message.pictureElem != null) return '[图片]';
    if (message.customElem != null) return '[语音通话邀请]';
    return '[新消息]';
  }

  Future<void> _refreshMessageUnreadStatus() async {
    try {
      final conversations = await _sdk.conversationManager
          .getAllConversationList();
      messageUnreadNotifier.value = conversations.any(
        (conversation) => conversation.unreadCount > 0,
      );
    } catch (error) {
      developer.log('未读消息状态加载失败: $error', name: 'OpenIM.message');
    }
  }

  static void markMessagesSeen() => messageUnreadNotifier.value = false;

  static void setFriendRequestCount(int count) {
    friendRequestCountNotifier.value = count < 0 ? 0 : count;
  }

  @override
  Future<void> logout() async {
    await _sdk.logout();
    _currentUserID = null;
    friendRequestCountNotifier.value = 0;
    messageUnreadNotifier.value = false;
    conversationReady.value = false;
    _sdkInitialized = false;
  }
}
