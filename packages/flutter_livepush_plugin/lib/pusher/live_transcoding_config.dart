import 'dart:async';
import 'package:flutter/services.dart';
import 'live_push_def.dart';
import '../util/live_utils.dart';

class AlivcLiveTranscodingConfig {
  static const String _methodName = "plugins.livetranscodingconfig.method";

  static const MethodChannel _transcodingConfigMethodChannel = MethodChannel(
    _methodName,
  );

  /// 创建[AlivcLiveTranscodingConfig]实例
  AlivcLiveTranscodingConfig.init();

  /// 混合后画面的底色颜色
  ///
  /// [backgroundColor] 底色颜色 格式为十六进制数字，如0xRRGGBB
  Future<void> setBackgroundColor(int backgroundColor) async {
    return _transcodingConfigMethodChannel.invokeMethod(
      'setBackgroundColor',
      wrapArgs(arg: backgroundColor.toString()),
    );
  }

  /// 获取混合后画面的底色颜色
  ///
  /// [returns] 底色颜色 默认: 0x000000(黑色)
  Future<int> getBackgroundColor() async {
    String strV = await _transcodingConfigMethodChannel.invokeMethod(
      'getBackgroundColor',
      wrapArgs(),
    );
    return int.parse(strV);
  }

  /// 设置混合后视频画面裁剪模式
  ///
  /// [cropMode] 裁剪模式
  Future<void> setCropMode(AlivcLiveTranscodingCropMode cropMode) async {
    int cropModeIntV = AlivcLiveTranscodingCropModeData.convertInterfaceValue(
      cropMode.index,
    );
    return _transcodingConfigMethodChannel.invokeMethod(
      'setCropMode',
      wrapArgs(arg: cropModeIntV.toString()),
    );
  }

  /// 获取混合后视频画面裁剪模式
  ///
  /// [returns] 裁剪模式 默认: [AlivcLiveTranscodingCropMode.crop]
  Future<AlivcLiveTranscodingCropMode> getCropMode() async {
    String strV = await _transcodingConfigMethodChannel.invokeMethod(
      'getCropMode',
      wrapArgs(),
    );
    return AlivcLiveTranscodingCropModeData.convertEnumValue(int.parse(strV));
  }

  /// 添加云端混流（转码）中每一路子画面的位置信息
  ///
  /// [mixStreams] 位置信息数组
  Future<void> setMixStreams(List<AlivcLiveMixStream> mixStreams) async {
    return _transcodingConfigMethodChannel.invokeMethod(
      'setMixStreams',
      wrapArgs(arg: mixStreams.map((e) => e.convertToMap()).toList()),
    );
  }

  /// 获取云端混流（转码）中每一路子画面的位置信息
  ///
  /// [returns] 位置信息数组 格式:[{"userId":"<userId值>", "x":"<x值>", "y":"<y值>", "width":"<width值>", "height":"<height值>", "zOrder":"<zOrder>"}, ...] 默认是空的数组
  Future<List<AlivcLiveMixStream>> getMixStreams() async {
    List<Map> arrV = await _transcodingConfigMethodChannel.invokeMethod(
      'getMixStreams',
      wrapArgs(),
    );
    return arrV.map((e) => AlivcLiveMixStream.convertAt(e)).toList();
  }
}
