import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_livepush_plugin/base/live_base.dart';
import 'package:flutter_livepush_plugin/base/live_base_def.dart';
import 'package:flutter_livepush_plugin/pusher/live_push_config.dart';
import 'package:flutter_livepush_plugin/pusher/live_pusher.dart';

/// Owns the Aliyun RTMP pusher used for screen broadcasts.
///
/// LiveKit continues to carry room audio and chat. Aliyun carries the screen
/// video as a conventional live stream for viewers.
class AliyunScreenBroadcast {
  static const _nativeLiveDisabled = bool.fromEnvironment(
    'ACO_SKIP_NATIVE_LIVE',
  );
  static const _androidCaptureChannel = MethodChannel(
    'aco/aliyun-screen-capture',
  );
  static const _pusherChannel = MethodChannel('plugins.livepush.pusher.method');
  static const appGroupId = 'group.com.meimeidacios.app';
  static Future<void>? _sdkRegistration;

  AlivcLivePusher? _pusher;

  Future<void> start(
    String pushUrl, {
    Future<bool> Function()? requestIOSBroadcast,
  }) async {
    if (_nativeLiveDisabled) {
      throw UnsupportedError('此模拟器运行模式未加载直播推流原生 SDK');
    }
    if (_pusher != null) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('屏幕直播目前只支持 Android 和 iOS');
    }

    await (_sdkRegistration ??= _registerSdk());

    if (defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('Aliyun screen share: requesting Android capture permission');
      final allowed = await _androidCaptureChannel.invokeMethod<bool>(
        'request',
      );
      debugPrint('Aliyun screen share: Android capture allowed=$allowed');
      if (allowed != true) throw StateError('未获得屏幕录制权限');
    }

    final pusher = AlivcLivePusher.init();
    try {
      debugPrint('Aliyun screen push: creating config');
      await pusher.createConfig();
      final config = AlivcLivePushConfig.init();
      await config.setVideoOnly(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await config.setExternMainStream(true);
      }
      debugPrint('Aliyun screen push: initializing native engine');
      await pusher.initLivePusher();
      debugPrint('Aliyun screen push: native engine initialized');
      pusher.setOnSDKError(
        (code, description) => debugPrint(
          'Aliyun screen push SDK error: code=$code description=$description',
        ),
      );
      pusher.setOnSystemError(
        (code, description) => debugPrint(
          'Aliyun screen push system error: code=$code description=$description',
        ),
      );
      pusher.setOnPushStarted(() => debugPrint('Aliyun screen push connected'));
      pusher.setOnConnectFail(
        (code, description) => debugPrint(
          'Aliyun screen push connect failed: code=$code description=$description',
        ),
      );
      debugPrint('Aliyun screen push: registering SDK callbacks');
      await pusher.setErrorDelegate();
      await pusher.setInfoDelegate();
      await pusher.setNetworkDelegate();
      debugPrint('Aliyun screen push: SDK callbacks registered');
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _pusherChannel.invokeMethod<int>(
          'startScreenCapture',
          <String, Object>{'arg': appGroupId},
        );
        if (requestIOSBroadcast == null || !await requestIOSBroadcast()) {
          throw StateError('已取消屏幕广播');
        }
      }
      debugPrint(
        'Aliyun screen push starting: host=${Uri.tryParse(pushUrl)?.host}',
      );
      await pusher.startPushWithURL(pushUrl);
      _pusher = pusher;
    } on Object catch (error, stackTrace) {
      debugPrint('Aliyun screen push start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await pusher.destroy();
      } finally {
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          await _androidCaptureChannel.invokeMethod<void>('stop');
        }
      }
      rethrow;
    }
  }

  static Future<void> _registerSdk() async {
    AlivcLiveBase.setListener(
      AlivcLiveBaseListener(
        onLicenceCheck: (result, reason) => debugPrint(
          'Aliyun screen push license: result=$result reason=$reason',
        ),
      ),
    );
    await AlivcLiveBase.registerSDK();
  }

  static Future<bool> requestIOSBroadcast(BuildContext context) async =>
      await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => const _AliyunBroadcastPickerDialog(),
      ) ??
      false;

  static Future<bool> isIOSBroadcasting() async {
    if (_nativeLiveDisabled) return false;
    return await _androidCaptureChannel.invokeMethod<bool>('isBroadcasting') ??
        false;
  }

  Future<void> stop() async {
    if (_nativeLiveDisabled) return;
    final pusher = _pusher;
    _pusher = null;
    try {
      if (pusher != null) {
        try {
          await pusher.stopPush();
        } finally {
          await pusher.destroy();
        }
      }
    } finally {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await _androidCaptureChannel.invokeMethod<void>('stop');
      }
    }
  }
}

class _AliyunBroadcastPickerDialog extends StatefulWidget {
  const _AliyunBroadcastPickerDialog();

  @override
  State<_AliyunBroadcastPickerDialog> createState() =>
      _AliyunBroadcastPickerDialogState();
}

class _AliyunBroadcastPickerDialogState
    extends State<_AliyunBroadcastPickerDialog> {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _checkStarted());
  }

  Future<void> _checkStarted() async {
    if (_checking) return;
    _checking = true;
    try {
      final started = await const MethodChannel(
        'aco/aliyun-screen-capture',
      ).invokeMethod<bool>('isBroadcasting');
      if (started == true && mounted) Navigator.of(context).pop(true);
    } on Object {
      // Keep the picker open; the system extension may take a moment to start.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: const Text('开始屏幕共享'),
    content: Column(
      children: [
        const SizedBox(height: 12),
        const Text('点下方系统按钮，选择“开始直播”。'),
        const SizedBox(height: 14),
        SizedBox(
          width: 52,
          height: 52,
          child: UiKitView(viewType: 'aco/aliyun-broadcast-picker'),
        ),
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
    ],
  );
}
