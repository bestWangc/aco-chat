import 'dart:async';
import 'dart:collection';

import 'package:aco_chat/features/account/domain/account_models.dart';

/// Stores received chat messages and coalesces UI refresh notifications.
class LiveChatBuffer {
  LiveChatBuffer({required this.onChanged});

  static const maxMessageCount = 200;
  static const refreshInterval = Duration(milliseconds: 75);

  final void Function() onChanged;
  final Queue<LiveMessage> _messages = ListQueue<LiveMessage>();
  final Set<int> _knownMessageIds = <int>{};
  Timer? _refreshTimer;

  List<LiveMessage> get messages => _messages.toList(growable: false);

  void append(LiveMessage message) => appendAll([message]);

  void appendAll(Iterable<LiveMessage> incomingMessages) {
    var hasNewMessages = false;
    for (final message in incomingMessages) {
      if (!_knownMessageIds.add(message.id)) continue;
      _messages.addLast(message);
      hasNewMessages = true;
      while (_messages.length > maxMessageCount) {
        _knownMessageIds.remove(_messages.removeFirst().id);
      }
    }
    if (hasNewMessages) _scheduleRefresh();
  }

  void dispose() => _refreshTimer?.cancel();

  void _scheduleRefresh() {
    if (_refreshTimer != null) return;
    _refreshTimer = Timer(refreshInterval, () {
      _refreshTimer = null;
      onChanged();
    });
  }
}

enum LiveChatSendLimit {
  allowed,
  payloadTooLarge,
  sentTooRecently,
  rateLimited,
}

/// Enforces local bounds before a chat payload is published to LiveKit.
class LiveChatRateLimiter {
  static const maxMessageBytes = 512;
  static const minimumInterval = Duration(milliseconds: 250);
  static const rateWindow = Duration(seconds: 1);
  static const maxMessagesPerWindow = 20;

  DateTime? _lastSentAt;
  DateTime? _windowStartedAt;
  int _windowCount = 0;

  LiveChatSendLimit check(int payloadBytes, {DateTime? now}) {
    if (payloadBytes > maxMessageBytes) {
      return LiveChatSendLimit.payloadTooLarge;
    }
    final checkedAt = now ?? DateTime.now();
    if (_lastSentAt case final lastSentAt?
        when checkedAt.difference(lastSentAt) < minimumInterval) {
      return LiveChatSendLimit.sentTooRecently;
    }
    if (_windowStartedAt == null ||
        checkedAt.difference(_windowStartedAt!) >= rateWindow) {
      _windowStartedAt = checkedAt;
      _windowCount = 0;
    }
    if (_windowCount >= maxMessagesPerWindow) {
      return LiveChatSendLimit.rateLimited;
    }
    _lastSentAt = checkedAt;
    _windowCount++;
    return LiveChatSendLimit.allowed;
  }
}
