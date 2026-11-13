import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_livepush_plugin/util/live_utils.dart';
import 'package:flutter_livepush_plugin/player/live_player_def.dart';
@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
class AlivcLivePlayConfig {
  static const String _livePlayerConfigMethodName =
      "plugins.liveplayerconfig.method";

  static const MethodChannel _playConfigMethodChannel = MethodChannel(
    _livePlayerConfigMethodName,
  );

  /// 创建[AlivcLivePlayConfig]实例
  AlivcLivePlayConfig.init();

  /// 设置渲染模式
  ///
  /// [renderMode] 渲染模式
  Future<void> setRenderMode(AlivcLivePlayRenderMode renderMode) async {
    return _playConfigMethodChannel.invokeMethod(
      'setRenderMode',
      wrapArgs(arg: renderMode.index.toString()),
    );
  }

  /// 获取渲染模式
  ///
  /// [returns] 渲染模式 默认: [AlivcLivePlayRenderMode.auto]
  Future<AlivcLivePlayRenderMode> getRenderMode() async {
    String strV = await _playConfigMethodChannel.invokeMethod(
      'getRenderMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePlayRenderMode.values[intV];
  }

  /// 设置播放是否镜像
  ///
  /// [renderMode] 渲染模式
  Future<void> setMirror(bool mirror) async {
    return _playConfigMethodChannel.invokeMethod(
      'setMirror',
      wrapArgs(arg: boolToString(mirror)),
    );
  }

  /// 获取播放是否镜像
  ///
  /// [returns] 播放是否镜像 默认: false
  Future<bool> getMirror() async {
    String strV = await _playConfigMethodChannel.invokeMethod(
      'getMirror',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置旋转角度
  ///
  /// [rotationMode] 旋转角度
  Future<void> setRotationMode(AlivcLivePlayRotationMode rotationMode) async {
    return _playConfigMethodChannel.invokeMethod(
      'setRotationMode',
      wrapArgs(arg: rotationMode.index.toString()),
    );
  }

  /// 获取旋转角度
  ///
  /// [returns] 旋转角度 默认: [AlivcLivePlayRotationMode.rotation_0]
  Future<AlivcLivePlayRotationMode> getRotationMode() async {
    String strV = await _playConfigMethodChannel.invokeMethod(
      'getRotationMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePlayRotationMode.values[intV];
  }

  /// 播放是否全屏
  Future<void> setIsFullScreen(bool isFullScreen) async {
    return _playConfigMethodChannel.invokeMethod(
      'isFullScreen',
      wrapArgs(arg: boolToString(isFullScreen)),
    );
  }
}
