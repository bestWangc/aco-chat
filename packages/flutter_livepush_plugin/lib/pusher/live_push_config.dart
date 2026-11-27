import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'live_push_def.dart';
import '../util/live_utils.dart';

class AlivcLivePushConfig {
  static const String _livePushConfigMethodName =
      "plugins.livepush.pushConfig.method";

  static const MethodChannel _livePusherConfigMC = MethodChannel(
    _livePushConfigMethodName,
  );

  /// 创建[AlivcLivePushConfig]实例
  AlivcLivePushConfig.init();

  /// 设置直播SDK推流模式
  ///
  /// [livePushMode] 直播SDK推流模式
  ///
  /// 基础模式不支持连麦、PK等实时互动需求，常规的RTMP推流、RTS推流使用次模式即可
  ///
  /// 互动模式，支持连麦、PK等实时互动，如果一场直播有互动需求，建议使用该模式
  Future<void> setLivePushMode(AlivcLivePushMode livePushMode) async {
    return _livePusherConfigMC.invokeMethod(
      'setLivePushMode',
      wrapArgs(arg: livePushMode.index.toString()),
    );
  }

  /// 获取直播SDK推流模式
  ///
  /// [returns] 直播SDK推流模式 默认: [AlivcLivePushMode.basic]
  Future<AlivcLivePushMode> getLivePushMode() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getLivePushMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushMode.values[intV];
  }

  /// 设置分辨率
  ///
  /// [resolution] 分辨率
  Future<void> setResolution(AlivcLivePushResolution resolution) async {
    return _livePusherConfigMC.invokeMethod(
      'setResolution',
      wrapArgs(arg: resolution.index.toString()),
    );
  }

  /// 获取分辨率
  ///
  /// [returns] 分辨率 默认: [AlivcLivePushResolution.resolution_540P]
  Future<AlivcLivePushResolution> getResolution() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getResolution',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushResolution.values[intV];
  }

  /// 设置码率自适应
  ///
  /// [enableAutoBitrate] 是否打开码率自适应
  Future<void> setEnableAutoBitrate(bool enableAutoBitrate) async {
    return _livePusherConfigMC.invokeMethod(
      'setEnableAutoBitrate',
      wrapArgs(arg: boolToString(enableAutoBitrate)),
    );
  }

  /// 获取码率自适应
  ///
  /// [returns] 是否打开码率自适应 默认: true
  Future<bool> getEnableAutoBitrate() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getEnableAutoBitrate',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置分辨率自适应
  ///
  /// [enableAutoResolution] 是否打开分辨率自适应 (动态分辨率)
  ///
  /// [qualityMode]在[AlivcLivePushQualityMode.custom]模式下，分辨率自适应无效
  Future<void> setEnableAutoResolution(bool enableAutoResolution) async {
    return _livePusherConfigMC.invokeMethod(
      'setEnableAutoResolution',
      wrapArgs(arg: boolToString(enableAutoResolution)),
    );
  }

  /// 获取分辨率自适应
  ///
  /// [returns] 是否打开分辨率自适应 默认: false
  Future<bool> getEnableAutoResolution() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getEnableAutoResolution',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置码率模式
  ///
  /// [enableAutoResolution] 是否打开分辨率自适应 (动态分辨率)
  ///
  /// 选择[AlivcLivePushQualityMode.resolution_first]模式时，SDK内部会优先保障推流视频的清晰度;
  ///
  /// 选择[AlivcLivePushQualityMode.fluency_first]模式时，SDK内部会优先保障推流视频的流畅度。
  ///
  /// 以上两种模式下，所有码率与帧率的设置均不生效，SDK会根据您设置的分辨率做出默认设置。
  ///
  /// 选择[AlivcLivePushQualityMode.custom]模式时，SDK会根据您自定义设置的帧率与码率进行推流。
  Future<void> setQualityMode(AlivcLivePushQualityMode qualityMode) async {
    return _livePusherConfigMC.invokeMethod(
      'setQualityMode',
      wrapArgs(arg: qualityMode.index.toString()),
    );
  }

  /// 获取码率模式
  ///
  /// [returns] 码率模式 默认: [AlivcLivePushQualityMode.resolution_first]
  Future<AlivcLivePushQualityMode> getQualityMode() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getQualityMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushQualityMode.values[intV];
  }

  /// 设置目标视频编码码率
  ///
  /// [targetVideoBitrate] 目标视频编码码率
  ///
  /// 范围 : [100,5000], 单位 : Kbps
  Future<void> setTargetVideoBitrate(int targetVideoBitrate) async {
    return _livePusherConfigMC.invokeMethod(
      'setTargetVideoBitrate',
      wrapArgs(arg: targetVideoBitrate.toString()),
    );
  }

  /// 获取目标视频编码码率
  ///
  /// [returns] 目标视频编码码率 默认:800
  Future<int> getTargetVideoBitrate() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getTargetVideoBitrate',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV;
  }

  /// 设置最小视频编码码率
  ///
  /// [minVideoBitrate] 最小视频编码码率
  ///
  /// 范围 : [100,5000], 单位 : Kbps
  Future<void> setMinVideoBitrate(int minVideoBitrate) async {
    return _livePusherConfigMC.invokeMethod(
      'setMinVideoBitrate',
      wrapArgs(arg: minVideoBitrate.toString()),
    );
  }

  /// 获取最小视频编码码率
  ///
  /// [returns] 最小视频编码码率 默认:200
  Future<int> getMinVideoBitrate() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getMinVideoBitrate',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV;
  }

  /// 设置初始视频编码码率
  ///
  /// [initialVideoBitrate] 初始视频编码码率
  ///
  /// 范围 : [100,5000], 单位 : Kbps
  Future<void> setInitialVideoBitrate(int initialVideoBitrate) async {
    return _livePusherConfigMC.invokeMethod(
      'setInitialVideoBitrate',
      wrapArgs(arg: initialVideoBitrate.toString()),
    );
  }

  /// 获取初始视频编码码率
  ///
  /// [returns] 初始视频编码码率 默认:800
  Future<int> getInitialVideoBitrate() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getInitialVideoBitrate',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV;
  }

  /// 设置音频编码码率
  ///
  /// [audioBitrate] 音频编码码率
  ///
  /// 范围 : [10,1000], 单位 : Kbps
  Future<void> setAudioBitrate(int audioBitrate) async {
    return _livePusherConfigMC.invokeMethod(
      'setAudioBitrate',
      wrapArgs(arg: audioBitrate.toString()),
    );
  }

  /// 获取音频编码码率
  ///
  /// [returns] 音频编码码率 默认:64
  Future<int> getAudioBitrate() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioBitrate',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV;
  }

  /// 设置音频采样率
  ///
  /// [audioSampleRate] 音频采样率
  Future<void> setAudioSampleRate(
      AlivcLivePushAudioSampleRate audioSampleRate) async {
    int audioSampleRateIntV = AudioSampleRateData.convertInterfaceValue(
      audioSampleRate.index,
    );
    return _livePusherConfigMC.invokeMethod(
      'setAudioSampleRate',
      wrapArgs(arg: audioSampleRateIntV.toString()),
    );
  }

  /// 获取音频采样率
  ///
  /// [returns] 音频采样率 默认:[AlivcLivePushAudioSampleRate.audio_sample_rate_48]
  Future<AlivcLivePushAudioSampleRate> getAudioSampleRate() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioSampleRate',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AudioSampleRateData.convertEnumValue(intV);
  }

  /// 设置视频采集帧率
  ///
  /// [fps] 视频采集帧率
  ///
  /// Frames per Second
  Future<void> setFps(AlivcLivePushFPS fps) async {
    int fpsIntV = FPSData.convertInterfaceValue(fps.index);
    return _livePusherConfigMC.invokeMethod(
      'setFps',
      wrapArgs(arg: fpsIntV.toString()),
    );
  }

  /// 获取视频采集帧率
  ///
  /// [returns] 视频采集帧率 默认:[AlivcLivePushFPS.fps_20]
  Future<AlivcLivePushFPS> getFps() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getFps',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return FPSData.convertEnumValue(intV);
  }

  /// 设置最小视频采集帧率
  ///
  /// [minFps] 最小视频采集帧率
  ///
  /// 不可大于 视频采集帧率fps
  Future<void> setMinFps(AlivcLivePushFPS minFps) async {
    int fpsIntV = FPSData.convertInterfaceValue(minFps.index);
    return _livePusherConfigMC.invokeMethod(
      'setMinFps',
      wrapArgs(arg: fpsIntV.toString()),
    );
  }

  /// 获取最小视频采集帧率
  ///
  /// [returns] 最小视频采集帧率 默认:[AlivcLivePushFPS.fps_8]
  Future<AlivcLivePushFPS> getMinFPS() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getMinFPS',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return FPSData.convertEnumValue(intV);
  }

  /// 设置关键帧间隔
  ///
  /// [videoEncodeGop] 关键帧间隔
  Future<void> setVideoEncodeGop(
      AlivcLivePushVideoEncodeGOP videoEncodeGop) async {
    int videoEncodeGopIntV =
        VideoEncodeGOPData.convertInterfaceValue(videoEncodeGop.index);
    return _livePusherConfigMC.invokeMethod(
      'setVideoEncodeGop',
      wrapArgs(arg: videoEncodeGopIntV.toString()),
    );
  }

  /// 获取关键帧间隔
  ///
  /// [returns] AlivcLivePushVideoEncodeGOP 关键帧间隔 默认:[AlivcLivePushVideoEncodeGOP.gop_2]
  Future<AlivcLivePushVideoEncodeGOP> getVideoEncodeGop() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getVideoEncodeGop',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return VideoEncodeGOPData.convertEnumValue(intV);
  }

  /// 设置音频编码格式
  ///
  /// [audioEncoderProfile] 音频编码格式
  Future<void> setAudioEncoderProfile(
      AlivcLivePushAudioEncoderProfile audioEncoderProfile) async {
    int audioEncoderProfileIntV = AudioEncoderProfileData.convertInterfaceValue(
        audioEncoderProfile.index);
    return _livePusherConfigMC.invokeMethod(
      'setAudioEncoderProfile',
      wrapArgs(arg: audioEncoderProfileIntV.toString()),
    );
  }

  /// 获取音频编码格式
  ///
  /// [returns] 音频编码格式 默认:[AlivcLivePushAudioEncoderProfile.AAC_LC]
  Future<AlivcLivePushAudioEncoderProfile> getAudioEncoderProfile() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioEncoderProfile',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AudioEncoderProfileData.convertEnumValue(intV);
  }

  /// 设置声道数
  ///
  /// [audioChannel] 声道数
  Future<void> setAudioChannel(AlivcLivePushAudioChannel audioChannel) async {
    int audioChannelIntV =
        AudioChannelData.convertInterfaceValue(audioChannel.index);
    return _livePusherConfigMC.invokeMethod(
      'setAudioChannel',
      wrapArgs(arg: audioChannelIntV.toString()),
    );
  }

  /// 获取声道数
  ///
  /// [returns] 声道数 默认:[AlivcLivePushAudioChannel.audio_channel_one]
  Future<AlivcLivePushAudioChannel> getAudioChannel() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioChannel',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AudioChannelData.convertEnumValue(intV);
  }

  /// 设置是否纯音频推流
  ///
  /// [audioOnly] 是否纯音频推流
  Future<void> setAudioOnly(bool audioOnly) async {
    return _livePusherConfigMC.invokeMethod(
      'setAudioOnly',
      wrapArgs(arg: boolToString(audioOnly)),
    );
  }

  /// 获取是否纯音频推流
  ///
  /// [returns] 是否纯音频推流 默认: false
  Future<bool> getAudioOnly() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioOnly',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置是否纯视频推流
  ///
  /// [videoOnly] 是否纯视频推流
  ///
  /// 只有RTMP推流才支持纯视频推流，当前RTC不支持纯视频推流
  Future<void> setVideoOnly(bool videoOnly) async {
    return _livePusherConfigMC.invokeMethod(
      'setVideoOnly',
      wrapArgs(arg: boolToString(videoOnly)),
    );
  }

  /// 获取是否纯视频推流
  ///
  /// [returns] 是否纯视频推流 默认: false
  Future<bool> getVideoOnly() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getVideoOnly',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置音频编码模式
  ///
  /// [audioEncoderMode] 音频编码模式
  Future<void> setAudioEncoderMode(
      AlivcLivePushAudioEncoderMode audioEncoderMode) async {
    return _livePusherConfigMC.invokeMethod(
      'setAudioEncoderMode',
      wrapArgs(arg: audioEncoderMode.index.toString()),
    );
  }

  /// 获取音频编码模式
  ///
  /// [returns] 音频编码模式 默认:[AlivcLivePushAudioEncoderMode.soft]
  Future<AlivcLivePushAudioEncoderMode> getAudioEncoderMode() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioEncoderMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushAudioEncoderMode.values[intV];
  }

  /// 设置视频编码模式
  ///
  /// [videoEncoderMode] 视频编码模式
  Future<void> setVideoEncoderMode(
      AlivcLivePushVideoEncoderMode videoEncoderMode) async {
    return _livePusherConfigMC.invokeMethod(
      'setVideoEncoderMode',
      wrapArgs(arg: videoEncoderMode.index.toString()),
    );
  }

  /// 获取视频编码模式
  ///
  /// [returns] 视频编码模式 默认: [AlivcLivePushAudioEncoderMode.hard]
  Future<AlivcLivePushVideoEncoderMode> getVideoEncoderMode() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getVideoEncoderMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushVideoEncoderMode.values[intV];
  }

  /// 设置视频硬编码方式
  ///
  /// [videoHardEncoderCodec] 视频硬编码方式
  ///
  /// 当视频编码模式[videoEncoderMode]设置为[AlivcLivePushAudioEncoderMode.hard]可选设置
  Future<void> setVideoHardEncoderCodec(
      AlivcLivePushVideoEncoderModeHardCodec videoHardEncoderCodec) async {
    return _livePusherConfigMC.invokeMethod(
      'setVideoHardEncoderCodec',
      wrapArgs(arg: videoHardEncoderCodec.index.toString()),
    );
  }

  /// 获取视频硬编码方式
  ///
  /// [returns] 视频硬编码方式 默认:[AlivcLivePushAudioEncoderMode.h264]
  Future<AlivcLivePushVideoEncoderModeHardCodec>
      getVideoHardEncoderCodec() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getVideoHardEncoderCodec',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushVideoEncoderModeHardCodec.values[intV];
  }

  /// 设置视频硬编模式下是否开启B帧
  ///
  /// [openBFrame] 是否开启B帧
  Future<void> setOpenBFrame(bool openBFrame) async {
    return _livePusherConfigMC.invokeMethod(
      'setOpenBFrame',
      wrapArgs(arg: boolToString(openBFrame)),
    );
  }

  /// 获取视频硬编模式下是否开启B帧
  ///
  /// [returns] 是否开启B帧 默认:false
  Future<bool> getOpenBFrame() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getOpenBFrame',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置推流方向
  ///
  /// [orientation] 推流方向
  Future<void> setOrientation(AlivcLivePushOrientation orientation) async {
    return _livePusherConfigMC.invokeMethod(
      'setOrientation',
      wrapArgs(arg: orientation.index.toString()),
    );
  }

  /// 获取推流方向
  ///
  /// [returns] 推流方向 默认:[AlivcLivePushOrientation.portrait]
  Future<AlivcLivePushOrientation> getOrientation() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getOrientation',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushOrientation.values[intV];
  }

  /// 设置预览显示模式
  ///
  /// [previewDisplayMode] 预览显示模式
  Future<void> setPreviewDisplayMode(
      AlivcPusherPreviewDisplayMode previewDisplayMode) async {
    return _livePusherConfigMC.invokeMethod(
      'setPreviewDisplayMode',
      wrapArgs(arg: previewDisplayMode.index.toString()),
    );
  }

  /// 获取预览显示模式
  ///
  /// [returns] 预览显示模式 默认:[AlivcPusherPreviewDisplayMode.preview_aspect_fit]
  Future<AlivcPusherPreviewDisplayMode> getPreviewDisplayMode() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getPreviewDisplayMode',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcPusherPreviewDisplayMode.values[intV];
  }

  /// 设置重连时长
  ///
  /// [connectRetryInterval] 重连时长
  ///
  /// 范围 : [0,10000], 单位 : ms
  Future<void> setConnectRetryInterval(double connectRetryInterval) async {
    return _livePusherConfigMC.invokeMethod(
      'setConnectRetryInterval',
      wrapArgs(arg: connectRetryInterval.toString()),
    );
  }

  /// 获取重连时长
  ///
  /// [returns] 重连时长 默认: 1000
  Future<double> getConnectRetryInterval() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getConnectRetryInterval',
      wrapArgs(),
    );
    double doubleV = double.parse(strV);
    return doubleV;
  }

  /// 设置重连次数
  ///
  /// [connectRetryCount] 重连次数
  ///
  /// 范围 : (0,100]
  Future<void> setConnectRetryCount(int connectRetryCount) async {
    return _livePusherConfigMC.invokeMethod(
      'setConnectRetryCount',
      wrapArgs(arg: connectRetryCount.toString()),
    );
  }

  /// 获取重连次数
  ///
  /// [returns] 重连次数 默认: 5
  Future<int> getConnectRetryCount() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getConnectRetryCount',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV;
  }

  /// 设置推流镜像
  ///
  /// [pushMirror] 是否开启推流镜像
  Future<void> setPushMirror(bool pushMirror) async {
    return _livePusherConfigMC.invokeMethod(
      'setPushMirror',
      wrapArgs(arg: boolToString(pushMirror)),
    );
  }

  /// 获取推流镜像
  ///
  /// [returns] 是否开启推流镜像 默认: false
  Future<bool> getPushMirror() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getPushMirror',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置预览镜像
  ///
  /// [previewMirror] 是否开启预览镜像
  Future<void> setPreviewMirror(bool previewMirror) async {
    return _livePusherConfigMC.invokeMethod(
      'setPreviewMirror',
      wrapArgs(arg: boolToString(previewMirror)),
    );
  }

  /// 获取预览镜像
  ///
  /// [returns] 是否开启预览镜像 默认: false
  Future<bool> getPreviewMirror() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getPreviewMirror',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置摄像头类型
  ///
  /// [cameraType] 摄像头类型
  Future<void> setCameraType(AlivcLivePushCameraType cameraType) async {
    return _livePusherConfigMC.invokeMethod(
      'setCameraType',
      wrapArgs(arg: cameraType.index.toString()),
    );
  }

  /// 获取摄像头类型
  ///
  /// [returns] 摄像头类型 默认:[AlivcLivePushCameraType.front]
  Future<AlivcLivePushCameraType> getCameraType() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getCameraType',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushCameraType.values[intV];
  }

  /// 设置自动聚焦
  ///
  /// [autoFocus] 是否自动聚焦
  Future<void> setAutoFocus(bool autoFocus) async {
    return _livePusherConfigMC.invokeMethod(
      'setAutoFocus',
      wrapArgs(arg: boolToString(autoFocus)),
    );
  }

  /// 获取自动聚焦
  ///
  /// [returns] 是否自动聚焦 默认: true
  Future<bool> getAutoFocus() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAutoFocus',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 设置暂停推流图片
  ///
  /// [imgPath] 图片保存在安卓手机或iOS沙盒全路径字符串
  Future<void> setPauseImg(String imgPath) async {
    return _livePusherConfigMC.invokeMethod(
      'setPauseImg',
      wrapArgs(arg: imgPath),
    );
  }

  /// 设置码率低图片
  ///
  /// [imgPath] 图片保存在安卓手机或iOS沙盒全路径字符串
  Future<dynamic> setNetworkPoorImg(String imgPath) async {
    return _livePusherConfigMC.invokeMethod(
      'setNetworkPoorImg',
      wrapArgs(arg: imgPath),
    );
  }

  /// 设置外部自定义音频数据
  ///
  /// [externAudioFormat] 外部自定义音频数据
  Future<void> setExternAudioFormat(
      AlivcLivePushAudioFormat externAudioFormat) async {
    int externAudioFormatIntV = AudioFormatData.convertInterfaceValue(
      externAudioFormat.index,
    );
    return _livePusherConfigMC.invokeMethod(
      'setExternAudioFormat',
      wrapArgs(arg: externAudioFormatIntV.toString()),
    );
  }

  /// 获取外部自定义音频数据
  ///
  /// return 外部自定义音频数据 默认:[AlivcLivePushAudioFormat.Unknown]
  Future<AlivcLivePushAudioFormat> getExternAudioFormat() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getExternAudioFormat',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AudioFormatData.convertEnumValue(intV);
  }

  /// 设置外部自定义视频数据
  ///
  /// [externVideoFormat] 外部自定义视频数据
  Future<void> setExternVideoFormat(
      AlivcLivePushVideoFormat externVideoFormat) async {
    int externVideoFormatIntV = VideoFormatData.convertInterfaceValue(
      externVideoFormat.index,
    );
    return _livePusherConfigMC.invokeMethod(
      'setExternVideoFormat',
      wrapArgs(arg: externVideoFormatIntV.toString()),
    );
  }

  /// 获取外部自定义视频数据
  ///
  /// [returns] 外部自定义视频数据 默认:[AlivcLivePushVideoFormat.Unknown]
  Future<AlivcLivePushVideoFormat> getExternVideoFormat() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getExternVideoFormat',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return VideoFormatData.convertEnumValue(intV);
  }

  /// 设置音频应用场景
  ///
  /// [audioScene] 音频应用场景
  Future<void> setAudioScene(AlivcLivePusherAudioScenario audioScene) async {
    int audioSceneIntV = AudioScenarioData.convertInterfaceValue(
      audioScene.index,
    );
    return _livePusherConfigMC.invokeMethod(
      'setAudioScene',
      wrapArgs(arg: audioSceneIntV.toString()),
    );
  }

  /// 获取音频应用场景
  ///
  /// [returns] 音频应用场景 默认:[AlivcLivePusherAudioScenario.defaultMode]
  Future<AlivcLivePusherAudioScenario> getAudioScene() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getAudioScene',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AudioScenarioData.convertEnumValue(intV);
  }

  // 是否外部自定义数据推流
  ///
  /// [externMainStream] 是否外部自定义数据推流
  Future<void> setExternMainStream(bool externMainStream) async {
    return _livePusherConfigMC.invokeMethod(
      'setExternMainStream',
      wrapArgs(arg: boolToString(externMainStream)),
    );
  }

  /// 获取是否外部自定义数据推流
  ///
  /// [returns] 是否外部自定义数据推流 默认: false
  Future<bool> getExternMainStream() async {
    String strV = await _livePusherConfigMC.invokeMethod(
      'getExternMainStream',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 获取推流宽高具体数值
  ///
  /// [returns] 推流宽高
  Future<Size> getPushResolution() async {
    Map mapV = await _livePusherConfigMC.invokeMethod(
      'getPushResolution',
      wrapArgs(),
    );
    double width = double.parse(mapV["width"]);
    double height = double.parse(mapV["height"]);
    return Size(width, height);
  }
}
