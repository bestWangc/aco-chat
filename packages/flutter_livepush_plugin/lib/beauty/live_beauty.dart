import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';

/// 美颜管理
///
/// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用，所有方法需要在[AlivcLivePusher][useBeauty]方法后面调用
class AlivcLiveBeautyManager {
  static const String _liveBeautyMethodName = "plugins.livebeauty.method";

  static const MethodChannel _liveBeautyMethodChannel = MethodChannel(
    _liveBeautyMethodName,
  );

  /// 创建[AlivcLiveBeautyManager]实例
  AlivcLiveBeautyManager.init();

  /// 获取集成的美颜SDK的版本号
  ///
  /// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用，
  static Future<String> getQueenSDKVersion() async {
    return await _liveBeautyMethodChannel.invokeMethod(
      'getQueenSDKVersion',
    );
  }

  /// 初始化美颜对象
  ///
  /// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用，建议在[AlivcLivePusher][startPreview]方法后面调用
  Future<void> setupBeauty() async {
    return _liveBeautyMethodChannel.invokeMethod(
      'setupBeauty',
    );
  }

  /// 打开美颜面板
  ///
  /// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用
  Future<void> showPanel() async {
    return _liveBeautyMethodChannel.invokeMethod(
      'showPanel',
    );
  }

  /// 隐藏美颜面板
  ///
  /// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用。Android调用
  Future<void> hidePanel() async {
    if (Platform.isAndroid) {
      return _liveBeautyMethodChannel.invokeMethod(
        'hidePanel',
      );
    }
  }

  /// 销毁释放美颜对象
  ///
  /// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用，建议在[AlivcLivePusher][destroy]方法后面调用
  Future<void> destroyBeauty() async {
    return _liveBeautyMethodChannel.invokeMethod(
      'destroyBeauty',
    );
  }
}
