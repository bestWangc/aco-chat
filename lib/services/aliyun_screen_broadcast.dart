import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_livepush_plugin/base/live_base.dart';
import 'package:flutter_livepush_plugin/base/live_base_def.dart';
import 'package:flutter_livepush_plugin/pusher/live_push_config.dart';
import 'package:flutter_livepush_plugin/pusher/live_push_def.dart';
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
  bool _startCancelled = false;

  Future<void> start(
    String pushUrl, {
    Future<bool> Function()? requestIOSBroadcast,
  }) async {
    if (_nativeLiveDisabled) {
      throw UnsupportedError('此模拟器运行模式未加载直播推流原生 SDK');
    }
    if (_pusher != null) {
      debugPrint('Aliyun screen push: cleaning up stale pusher before restart');
      await stop();
      _startCancelled = false;
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('屏幕直播目前只支持 Android 和 iOS');
    }
    _startCancelled = false;

    await _ensureSdkRegistered();

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
      await config.setLivePushMode(AlivcLivePushMode.basic);
      await config.setVideoOnly(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await config.setExternMainStream(true);
      }
      debugPrint('Aliyun screen push: initializing native engine');
      await pusher.initLivePusher();
      debugPrint('Aliyun screen push: native engine initialized');
      _pusher = pusher;
      if (_startCancelled) throw StateError('屏幕共享已停止');
      final pushStarted = Completer<void>();
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
      pusher.setOnPushStarted(() {
        debugPrint('Aliyun screen push connected');
        if (!pushStarted.isCompleted) pushStarted.complete();
      });
      pusher.setOnConnectFail((code, description) {
        debugPrint(
          'Aliyun screen push connect failed: '
          'code=$code description=$description',
        );
        if (!pushStarted.isCompleted) {
          pushStarted.completeError(StateError('推流连接失败（$code）：$description'));
        }
      });
      debugPrint('Aliyun screen push: registering SDK callbacks');
      await pusher.setErrorDelegate();
      await pusher.setInfoDelegate();
      await pusher.setNetworkDelegate();
      debugPrint('Aliyun screen push: SDK callbacks registered');
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final captureResult = await _pusherChannel.invokeMethod<int>(
          'startScreenCapture',
          <String, Object>{'arg': appGroupId},
        );
        debugPrint(
          'Aliyun screen share: startScreenCapture result=$captureResult',
        );
        if (captureResult != 0) {
          throw StateError('iOS 屏幕采集初始化失败（$captureResult）');
        }
        if (requestIOSBroadcast == null || !await requestIOSBroadcast()) {
          throw StateError('已取消屏幕广播');
        }
      }
      if (_startCancelled) throw StateError('屏幕共享已停止');
      debugPrint(
        'Aliyun screen push starting: host=${Uri.tryParse(pushUrl)?.host}',
      );
      final pushStartedFuture = pushStarted.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('屏幕推流连接超时'),
      );
      await pusher.startPushWithURL(pushUrl);
      await pushStartedFuture;
    } on Object catch (error, stackTrace) {
      debugPrint('Aliyun screen push start failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await pusher.destroy();
      } finally {
        if (identical(_pusher, pusher)) _pusher = null;
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          await _androidCaptureChannel.invokeMethod<void>('stop');
        }
      }
      rethrow;
    }
  }

  static Future<void> _registerSdk() async {
    debugPrint('Aliyun screen push: registering SDK');
    final licenseChecked = Completer<void>();
    var licenseResult = AlivcLiveLicenseCheckResultCode.uninitialized;
    var licenseReason = '';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('Aliyun screen push: setting SDK license listener');
      await AlivcLiveBase.setListener(
        AlivcLiveBaseListener(
          onLicenceCheck: (result, reason) {
            debugPrint(
              'Aliyun screen push license: result=$result reason=$reason',
            );
            licenseResult = result;
            licenseReason = reason;
            if (!licenseChecked.isCompleted) licenseChecked.complete();
          },
        ),
      );
      debugPrint('Aliyun screen push: SDK license listener ready');
    }
    debugPrint('Aliyun screen push: calling registerSDK');
    final registered = await AlivcLiveBase.registerSDK();
    debugPrint('Aliyun screen push: SDK registration result=$registered');
    // Android's plugin completes registerSDK with null; iOS returns a bool.
    // Only an explicit false is a registration failure.
    if (registered == false) {
      throw StateError('阿里云直播 SDK 注册失败，请检查 iOS License 配置。');
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await licenseChecked.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      throw StateError('等待阿里云 iOS License 校验超时，请检查 SDK 注册和证书配置。');
    }
    if (licenseResult != AlivcLiveLicenseCheckResultCode.success) {
      throw StateError('iOS License 校验失败：$licenseReason');
    }
  }

  static Future<void> _ensureSdkRegistered() async {
    debugPrint('Aliyun screen push: waiting for SDK registration');
    final registration = _sdkRegistration ??= _registerSdk();
    try {
      await registration.timeout(const Duration(seconds: 15));
      debugPrint('Aliyun screen push: SDK registration ready');
    } on Object {
      if (identical(_sdkRegistration, registration)) _sdkRegistration = null;
      rethrow;
    }
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
    _startCancelled = true;
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
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 72,
            height: 72,
            child: UiKitView(
              viewType: 'aco/aliyun-broadcast-picker',
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            ),
          ),
        ),
        const SizedBox(height: 8),
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
