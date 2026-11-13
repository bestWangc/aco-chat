///
/// Copyright © 2023 Alibaba Cloud. All rights reserved.
///
/// Author：keria
/// Date：2023/12/11
/// Email：runchen.brc@alibaba-inc.com
///
/// Reference：Explain the purpose of the current file
///

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_livepush_plugin/base/live_base_def.dart';
import 'package:flutter_livepush_plugin/util/live_utils.dart';

class AlivcLiveBase {
  /// 当前 Plugin 的版本号
  static const String kFlutterVersion = '7.0.0';

  static const String _liveBaseMethodName = "plugins.livebase.method";
  static const String _liveBaseEventName = "plugins.livebase.event";
  static const String _liveBaseMethod = "method";

  static const String _licenceCheckResult = "result";
  static const String _licenceCheckReason = "reason";

  static const MethodChannel _liveBaseMethodChannel = MethodChannel(
    _liveBaseMethodName,
  );

  static const EventChannel _liveBaseEventChannel = EventChannel(
    _liveBaseEventName,
  );

  static AlivcLiveBaseListener? _onLiveBaseListener;

  /// 注册SDK
  ///
  /// 请在工程的[Info.plist]中增加[AlivcLicenseKey]和[AlivcLicenseFile]字段
  ///
  /// 在[AlivcLicenseKey]中填入您的[LicenseKey]
  ///
  /// 在[AlivcLicenseFile]中填入您的[LicenseFile]路径（相对于mainBundle）；例如您的[LicenseFile]为"license.crt"放到mainBundle下，就填入license.crt
  ///
  /// LicenseKey和LicenseFile的获取请参考文档：https://help.aliyun.com/zh/live/developer-reference/integrate-a-push-sdk-license/
  static Future<dynamic> registerSDK() async {
    _liveBaseEventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onError,
        );
    return _liveBaseMethodChannel.invokeMethod(
      'registerSDK',
    );
  }

  /// 设置监听回调接口
  ///
  /// [baseListener] param [result] 校验licence结果[AlivcLiveLicenseCheckResultCodeSuccess]成功，其他表示失败
  ///
  /// [baseListener] param [reason] 校验licence失败原因
  static void setListener(AlivcLiveBaseListener baseListener) {
    _onLiveBaseListener = baseListener;
    _liveBaseMethodChannel.invokeMethod(
      'setListener',
    );
  }

  /// 获取SDK版本号
  ///
  /// [returns] 版本号
  static Future<String> getSdkVersion() async {
    return await _liveBaseMethodChannel.invokeMethod(
      'getSdkVersion',
    );
  }

  /// 获取Flutter SDK版本号
  ///
  /// [returns] 版本号
  static String getFlutterSdkVersion() {
    return kFlutterVersion;
  }

  /// 设置Log级别
  ///
  /// [level] Log级别 默认:[AlivcLivePushLogLevel.error]
  static Future<void> setLogLevel(AlivcLivePushLogLevel level) async {
    return _liveBaseMethodChannel.invokeMethod(
      'setLogLevel',
      wrapArgs(arg: level.index.toString()),
    );
  }

  /// 启用或禁用控制台日志打印
  ///
  /// [enable] 指定是否启用 true:启用,false:禁用
  static Future<void> setConsoleEnable(bool enable) async {
    return _liveBaseMethodChannel.invokeMethod(
      'setConsoleEnable',
      wrapArgs(arg: boolToString(enable)),
    );
  }

  /// 设置Log路径
  ///
  /// [logPath] Log路径
  ///
  /// [maxPartFileSizeInKB] 每个分片最大大小。最终日志总体积是 5*最大分片大小
  static Future<void> setLogPath(
    String logPath,
    int maxPartFileSizeInKB,
  ) async {
    Map params = {
      "logPath": logPath,
      "maxPartFileSizeInKB": maxPartFileSizeInKB.toString(),
    };
    return _liveBaseMethodChannel.invokeMethod(
      'setLogPath',
      wrapArgs(arg: params),
    );
  }

  static void _onEvent(dynamic event) {
    String method = event[_liveBaseMethod];
    switch (method) {
      case "onLicenceCheck":
        if (_onLiveBaseListener != null &&
            _onLiveBaseListener?.onLicenceCheck != null) {
          int resultInt = int.parse(event[_licenceCheckResult]);
          String reason = event[_licenceCheckReason];
          _onLiveBaseListener?.onLicenceCheck?.call(
            AlivcLiveLicenseCheckResultCode.values[resultInt],
            reason,
          );
        }
        break;
    }
  }

  static void _onError(dynamic error) {}
}
