import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AndroidChatBackgroundService {
  AndroidChatBackgroundService._();

  static const _channel = MethodChannel('aco/chat-background');
  static bool _appIsBackgrounded = false;

  static void updateAppLifecycle(AppLifecycleState state) {
    _appIsBackgrounded =
        state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }

  static Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid || !_appIsBackgrounded) return;
    await _channel.invokeMethod<void>('showMessage', {
      'title': title,
      'body': body,
    });
  }
}
