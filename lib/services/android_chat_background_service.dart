import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';

class AndroidChatBackgroundService {
  AndroidChatBackgroundService._();

  static const _channel = MethodChannel('aco/chat-background');

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    await OpenIM.iMManager.setKeepConnectionsAliveWhenInBackground(
      enabled: true,
    );
    await _channel.invokeMethod<void>('start');
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('stop');
  }

  static Future<void> openBackgroundSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openBackgroundSettings');
  }

  static Future<void> showMessage({
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('showMessage', {
      'title': title,
      'body': body,
      'urgent': urgent,
    });
  }
}
