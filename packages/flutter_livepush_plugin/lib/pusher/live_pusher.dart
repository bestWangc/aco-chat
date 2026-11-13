import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'live_push_config.dart';
import 'live_push_def.dart';
import '../util/live_utils.dart';

class AlivcLivePusher {
  static const String _livePusherMethodName = "plugins.livepush.pusher.method";
  static const String _livePusherEventName = "plugins.livepush.pusher.event";

  static const String _livePusherMethod = "method";

  static const String _livePusherErrorCode = "errorCode";
  static const String _livePusherErrorDescription = "errorDescription";

  static const String _livePusherBGMProgress = "progress";
  static const String _livePusherBGMDuration = "duration";

  static const String _livePusherSnapshotSaveResult = "saveResult";
  static const String _livePusherSnapshotSaveDirType = "saveDirType";
  static const String _livePusherSnapshotSavePath = "savePath";

  static const MethodChannel _livePusherMethodChannel = MethodChannel(
    _livePusherMethodName,
  );
  static const EventChannel _livePusherEventChannel = EventChannel(
    _livePusherEventName,
  );

  OnLivePusherError? onSDKError;
  OnLivePusherError? onSystemError;
  OnLivePusherCallback? onPreviewStarted;
  OnLivePusherCallback? onPreviewStopped;
  OnLivePusherCallback? onFirstFramePreviewed;
  OnLivePusherCallback? onPushStarted;
  OnLivePusherCallback? onPushPaused;
  OnLivePusherCallback? onPushResumed;
  OnLivePusherCallback? onPushRestart;
  OnLivePusherCallback? onPushStopped;
  OnLivePusherError? onConnectFail;
  OnLivePusherCallback? onConnectRecovery;
  OnLivePusherCallback? onConnectionLost;
  OnLivePusherCallback? onNetworkPoor;
  OnLivePusherError? onReconnectError;
  OnLivePusherCallback? onReconnectStart;
  OnLivePusherCallback? onReconnectSuccess;
  OnLivePusherCallback? onSendDataTimeout;
  OnLivePusherCallback? onSendSeiMessage;
  OnLivePusherCallback? onBGMCompleted;
  OnLivePusherCallback? onBGMDownloadTimeout;
  OnLivePusherCallback? onBGMOpenFailed;
  OnLivePusherCallback? onBGMPaused;
  OnBGMProgress? onBGMProgress;
  OnLivePusherCallback? onBGMResumed;
  OnLivePusherCallback? onBGMStarted;
  OnLivePusherCallback? onBGMStopped;
  OnSnapshot? onSnapshot;

  /// 创建[AlivcLivePusher]实例
  AlivcLivePusher.init() {
    _livePusherEventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onError,
        );
  }

  /// 创建直播推流参数配置
  ///
  /// 将[AlivcLivePushConfig]同[AlivcLivePusher]联系起来。
  Future<void> createConfig() async {
    return _livePusherMethodChannel.invokeMethod(
      'createConfig',
      wrapArgs(),
    );
  }

  /// 创建一个推流引擎实例
  ///
  /// 同一时间只会存在一个主推流引擎实例，需要在createConfig已经调用的情况下执行
  Future<void> initLivePusher() async {
    return _livePusherMethodChannel.invokeMethod(
      'initLivePusher',
      wrapArgs(),
    );
  }

  /// 设置推流错误监听回调
  Future<void> setErrorDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setErrorDelegate',
      wrapArgs(),
    );
  }

  /// 设置推流状态监听回调
  Future<void> setInfoDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setInfoDelegate',
      wrapArgs(),
    );
  }

  /// 设置推流网络监听回调
  Future<void> setNetworkDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setNetworkDelegate',
      wrapArgs(),
    );
  }

  /// 设置用户自定义滤镜回调
  Future<void> setCustomFilterDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setCustomFilterDelegate',
      wrapArgs(),
    );
  }

  /// 设置用户自定义人脸识别回调
  Future<void> setCustomDetectorDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setCustomDetectorDelegate',
      wrapArgs(),
    );
  }

  /// 设置背景音乐监听回调
  Future<void> setBGMDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setBGMDelegate',
      wrapArgs(),
    );
  }

  /// 开始预览 同步接口
  ///
  /// [isAnchor] 是否是主播，Android 端有效
  Future<void> startPreview({bool isAnchor = true}) async {
    return _livePusherMethodChannel.invokeMethod(
      'startPreview',
      wrapArgs(arg: isAnchor),
    );
  }

  /// 开始预览 异步接口
  Future<void> startPreviewAsync() async {
    return _livePusherMethodChannel.invokeMethod(
      'startPreviewAsync',
      wrapArgs(),
    );
  }

  /// 开始推流 同步接口
  ///
  /// [pushURL] 推流URL
  Future<void> startPushWithURL(String pushURL) async {
    return _livePusherMethodChannel.invokeMethod(
      'startPushWithURL',
      wrapArgs(arg: pushURL),
    );
  }

  /// 开始推流 异步接口
  ///
  /// [pushURL] 推流URL
  Future<void> startPushWithURLAsync(String pushURL) async {
    return _livePusherMethodChannel.invokeMethod(
      'startPushWithURLAsync',
      wrapArgs(arg: pushURL),
    );
  }

  /// 停止预览
  Future<void> stopPreview() async {
    return _livePusherMethodChannel.invokeMethod(
      'stopPreview',
      wrapArgs(),
    );
  }

  /// 停止推流
  Future<void> stopPush() async {
    return await _livePusherMethodChannel.invokeMethod(
      'stopPush',
      wrapArgs(),
    );
  }

  /// 重新推流 同步接口
  Future<void> restartPush() async {
    return _livePusherMethodChannel.invokeMethod(
      'restartPush',
      wrapArgs(),
    );
  }

  /// 重新推流 异步接口
  Future<void> restartPushAsync() async {
    return _livePusherMethodChannel.invokeMethod(
      'restartPushAsync',
      wrapArgs(),
    );
  }

  /// 暂停摄像头推流
  ///
  /// 如果[AlivcLivePushConfig]中设置了[pauseImg]图片，将推设置的静态图片
  Future<void> pause() async {
    return _livePusherMethodChannel.invokeMethod(
      'pause',
      wrapArgs(),
    );
  }

  /// 恢复摄像头推流 同步接口
  Future<void> resume() async {
    return _livePusherMethodChannel.invokeMethod(
      'resume',
      wrapArgs(),
    );
  }

  /// 恢复推流 异步接口
  Future<void> resumeAsync() async {
    return _livePusherMethodChannel.invokeMethod(
      'resumeAsync',
      wrapArgs(),
    );
  }

  /// 切换摄像头
  Future<void> switchCamera() async {
    return _livePusherMethodChannel.invokeMethod(
      'switchCamera',
      wrapArgs(),
    );
  }

  /// 重连 异步接口
  Future<void> reconnectPushAsync() async {
    return _livePusherMethodChannel.invokeMethod(
      'reconnectPushAsync',
      wrapArgs(),
    );
  }

  /// 推流URL的重连 异步接口
  ///
  /// [pushURL] 推流URL
  Future<void> reconnectPushAsyncWithPushURL(String pushURL) async {
    return _livePusherMethodChannel.invokeMethod(
      'reconnectPushAsyncWithPushURL',
      wrapArgs(arg: pushURL),
    );
  }

  /// 销毁推流引擎
  Future<void> destroy() async {
    return _livePusherMethodChannel.invokeMethod(
      'destroy',
      wrapArgs(),
    );
  }

  /// 设置自动对焦
  ///
  /// [autoFocus] true:自动对焦,false:手动对焦
  Future<void> setAutoFocus(bool autoFocus) async {
    return _livePusherMethodChannel.invokeMethod(
      'setAutoFocus',
      wrapArgs(arg: boolToString(autoFocus)),
    );
  }

  /// 对焦
  ///
  /// [pointX] 对焦的点坐标x轴
  ///
  /// [pointY] 对焦的点坐标y轴
  ///
  /// [autoFocus] 是否自动对焦
  Future<void> focusCameraAtAdjustedPoint(
      double pointX, double pointY, bool autoFocus) async {
    Map content = {
      "point": {
        "x": pointX.toString(),
        "y": pointY.toString(),
      },
      "autoFocus": boolToString(autoFocus),
    };
    return _livePusherMethodChannel.invokeMethod(
      'focusCameraAtAdjustedPoint',
      wrapArgs(arg: content),
    );
  }

  /// 缩放
  ///
  /// [zoom] 缩放值[0:MaxZoom]
  Future<void> setZoom(double zoom) async {
    return _livePusherMethodChannel.invokeMethod(
      'setZoom',
      wrapArgs(arg: zoom.toString()),
    );
  }

  /// 获取支持的最大变焦值
  ///
  /// [returns] 最大变焦值
  Future<double> getMaxZoom() async {
    return await _livePusherMethodChannel.invokeMethod(
      'getMaxZoom',
      wrapArgs(),
    );
  }

  /// 获取当前变焦值
  ///
  /// [returns] 当前变焦值
  Future<double> getCurrentZoom() async {
    return await _livePusherMethodChannel.invokeMethod(
      'getCurrentZoom',
      wrapArgs(),
    );
  }

  /// 闪光灯开关
  ///
  /// [flash] 是否打开闪光灯 true:打开 false:关闭
  Future<void> setFlash(bool flash) async {
    return _livePusherMethodChannel.invokeMethod(
      'setFlash',
      wrapArgs(arg: boolToString(flash)),
    );
  }

  /// 设置曝光度
  ///
  /// [exposure] 曝光度
  Future<void> setExposure(double exposure) async {
    return _livePusherMethodChannel.invokeMethod(
      'setExposure',
      wrapArgs(arg: exposure.toString()),
    );
  }

  /// 获取当前曝光度
  ///
  /// [returns] 当前曝光度
  Future<double> getCurrentExposure() async {
    return await _livePusherMethodChannel.invokeMethod(
      'getCurrentExposure',
      wrapArgs(),
    );
  }

  /// 获取支持最小曝光度
  ///
  /// [returns] 最小曝光度
  Future<double> getSupportedMinExposure() async {
    return await _livePusherMethodChannel.invokeMethod(
      'getSupportedMinExposure',
      wrapArgs(),
    );
  }

  /// 获取支持最大曝光度
  ///
  /// [returns] 最大曝光度
  Future<double> getSupportedMaxExposure() async {
    return await _livePusherMethodChannel.invokeMethod(
      'getSupportedMaxExposure',
      wrapArgs(),
    );
  }

  /// 推流镜像开关
  ///
  /// [mirror] 是否打开镜像 true:打开,false:关闭
  Future<void> setPushMirror(bool mirror) async {
    return _livePusherMethodChannel.invokeMethod(
      'setPushMirror_push',
      wrapArgs(arg: boolToString(mirror)),
    );
  }

  /// 预览镜像开关
  ///
  /// [mirror] 是否打开镜像 true:打开,false:关闭
  Future<void> setPreviewMirror(bool mirror) async {
    return _livePusherMethodChannel.invokeMethod(
      'setPreviewMirror_push',
      wrapArgs(arg: boolToString(mirror)),
    );
  }

  /// 静音推流
  ///
  /// [mute] 是否静音 true:静音,false:正常
  Future<void> setMute(bool mute) async {
    return _livePusherMethodChannel.invokeMethod(
      'setMute',
      wrapArgs(arg: boolToString(mute)),
    );
  }

  /// 设置推流模式
  ///
  /// [qualityMode] 推流模式
  ///
  /// [qualityMode] 选择[AlivcLivePushQualityMode.resolution_first]时，SDK内部会优先保障推流视频的清晰度;
  ///
  /// [qualityMode] 选择[AlivcLivePushQualityMode.fluency_first]时，SDK内部会优先保障推流视频的流畅度，此接口只支持这两种模式。设置后码率设置失效。
  Future<void> setQualityMode(AlivcLivePushQualityMode qualityMode) async {
    return _livePusherMethodChannel.invokeMethod(
      'setQualityMode',
      wrapArgs(arg: qualityMode.index.toString()),
    );
  }

  /// 设置目标码率
  ///
  /// [targetBitrate] 目标码率 [100  5000](Kbps)
  Future<void> setTargetVideoBitrate(int targetBitrate) async {
    return _livePusherMethodChannel.invokeMethod(
      'setTargetVideoBitrate_push',
      wrapArgs(arg: targetBitrate.toString()),
    );
  }

  /// 设置最小码率
  ///
  /// [minBitrate] 最小码率 [100  5000](Kbps)
  Future<void> setMinVideoBitrate(int minBitrate) async {
    return _livePusherMethodChannel.invokeMethod(
      'setMinVideoBitrate_push',
      wrapArgs(arg: minBitrate.toString()),
    );
  }

  /// 设置预览显示模式
  ///
  /// [displayMode] 预览显示模式
  Future<void> setPreviewDisplayMode(
      AlivcPusherPreviewDisplayMode displayMode) async {
    return _livePusherMethodChannel.invokeMethod(
      'setPreviewDisplayMode_push',
      wrapArgs(
        arg: displayMode.index.toString(),
      ),
    );
  }

  /// 设置推流分辨率
  ///
  /// [resolution] 推流分辨率
  ///
  /// 只在预览模式下生效，推流中不能设置
  Future<void> setResolution(AlivcLivePushResolution resolution) async {
    return _livePusherMethodChannel.invokeMethod(
      'setResolution',
      wrapArgs(arg: resolution.index.toString()),
    );
  }

  /// 播放背景音乐
  ///
  /// [path] 背景音乐路径
  Future<void> startBGMWithMusicPathAsync(String path) async {
    return _livePusherMethodChannel.invokeMethod(
      'startBGMWithMusicPathAsync',
      wrapArgs(arg: path),
    );
  }

  /// 停止播放背景音乐
  Future<void> stopBGMAsync() async {
    return _livePusherMethodChannel.invokeMethod(
      'stopBGMAsync',
      wrapArgs(),
    );
  }

  /// 暂停播放背景音乐
  Future<void> pauseBGM() async {
    return _livePusherMethodChannel.invokeMethod(
      'pauseBGM',
      wrapArgs(),
    );
  }

  /// 恢复播放背景音乐
  Future<void> resumeBGM() async {
    return _livePusherMethodChannel.invokeMethod(
      'resumeBGM',
      wrapArgs(),
    );
  }

  /// 设置背景音乐是否循环播放
  ///
  /// [isLoop] 是否循环 true:循环,false:不循环
  Future<void> setBGMLoop(bool isLoop) async {
    return _livePusherMethodChannel.invokeMethod(
      'setBGMLoop',
      wrapArgs(arg: boolToString(isLoop)),
    );
  }

  /// 设置背景音乐耳返开关
  ///
  /// [isOpen] 是否打开耳返 true:开启,false:关闭
  Future<void> setBGMEarsBack(bool isOpen) async {
    return _livePusherMethodChannel.invokeMethod(
      'setBGMEarsBack',
      wrapArgs(arg: boolToString(isOpen)),
    );
  }

  /// 设置降噪开关
  ///
  /// [isOpen] 是否打开降噪 true:开启,false:关闭 默认:true
  Future<void> setAudioDenoise(bool isOpen) async {
    return _livePusherMethodChannel.invokeMethod(
      'setAudioDenoise',
      wrapArgs(arg: boolToString(isOpen)),
    );
  }

  /// 设置变声音效模式
  ///
  /// [mode] 变声音效模式
  ///
  /// 推流前和推流过程中调用都生效
  Future<void> setAudioEffectVoiceChangeMode(
      AlivcLivePushAudioEffectVoiceChangeMode mode) async {
    return _livePusherMethodChannel.invokeMethod(
      'setAudioEffectVoiceChangeMode',
      wrapArgs(arg: mode.index.toString()),
    );
  }

  /// 设置混响音效模式
  ///
  /// [mode] 混响音效模式
  ///
  /// 推流前和推流过程中调用都生效
  Future<void> setAudioEffectReverbMode(
    AlivcLivePushAudioEffectReverbMode mode,
  ) async {
    return _livePusherMethodChannel.invokeMethod(
      'setAudioEffectReverbMode',
      wrapArgs(arg: mode.index.toString()),
    );
  }

  /// 设置背景音乐混音 音乐音量
  ///
  /// [volume] 音乐音量大小 范围:[0 ~ 100] 默认:50
  Future<void> setBGMVolume(int volume) async {
    return _livePusherMethodChannel.invokeMethod(
      'setBGMVolume',
      wrapArgs(arg: volume.toString()),
    );
  }

  /// 设置背景音乐混音 人声音量
  ///
  /// [volume] 人声音量大小 范围:[0 ~ 100] 默认:50
  Future<void> setCaptureVolume(int volume) async {
    return _livePusherMethodChannel.invokeMethod(
      'setCaptureVolume',
      wrapArgs(arg: volume.toString()),
    );
  }

  /// 设置自定义Message (SEI)
  ///
  /// [msg] 用户推流消息
  ///
  /// [count] 重复次数
  ///
  /// [time] 延时时间，单位毫秒
  ///
  /// [isKeyFrame] 是否只发关键帧
  Future<void> sendMessage(
    String message,
    int count,
    int time,
    int isKeyFrame,
  ) async {
    Map params = {
      "message": message,
      "count": count.toString(),
      "time": time.toString(),
      "isKeyFrame": isKeyFrame.toString(),
    };
    return _livePusherMethodChannel.invokeMethod(
      'sendMessage',
      wrapArgs(arg: params),
    );
  }

  /// 获取是否正在推流
  ///
  /// [returns] 是否正在推流 true:正在推流,false:未推流
  Future<bool> isPushing() async {
    String strV = await _livePusherMethodChannel.invokeMethod(
      'isPushing',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 获取当前推流URL
  ///
  /// [returns] 当前推流URL
  Future<String> getPushURL() async {
    return await _livePusherMethodChannel.invokeMethod(
      'getPushURL',
      wrapArgs(),
    );
  }

  /// 获取当前推流状态
  ///
  /// [returns] 推流状态
  Future<AlivcLivePushStatus> getLiveStatus() async {
    String strV = await _livePusherMethodChannel.invokeMethod(
      'getLiveStatus',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return AlivcLivePushStatus.values[intV];
  }

  /// 添加水印
  ///
  /// [path] 水印路径
  ///
  /// [coordX] 水印左上顶点x的相对坐标 [0,1]
  ///
  /// [coordY] 水印左上顶点y的相对坐标 [0,1]
  ///
  /// [width] 水印的相对宽度 (水印会根据水印图片实际大小和水印宽度等比缩放) (0,1]
  ///
  /// 最多支持3个水印
  Future<void> addWatermark(
      String path, double coordX, double coordY, double width) async {
    Map params = {
      "path": path,
      "coordX": coordX.toString(),
      "coordY": coordY.toString(),
      "width": width.toString(),
    };
    return _livePusherMethodChannel.invokeMethod(
      'addWatermark',
      wrapArgs(arg: params),
    );
  }

  /// 设置水印显示和隐藏
  ///
  /// [visible] true:显示水印,false:隐藏水印
  Future<void> setWatermarkVisible(bool visible) async {
    return _livePusherMethodChannel.invokeMethod(
      'setWatermarkVisible',
      wrapArgs(arg: boolToString(visible)),
    );
  }

  /// 添加动态贴纸
  ///
  /// [waterMarkDirPath] 贴纸图片sequence目录
  ///
  /// [x] 显示屏幕x位置（0~1.0f)
  ///
  /// [y] 显示屏幕y位置（0~1.0f)
  ///
  /// [w] 显示屏幕宽
  ///
  /// [h] 显示屏幕高
  ///
  /// [returns] 返回动态贴纸的id号，删除贴纸传此id
  ///
  /// 最多支持添加5个贴纸
  Future<int> addDynamicWaterMarkImageData(
    String waterMarkDirPath,
    double x,
    double y,
    double w,
    double h,
  ) async {
    Map params = {
      "path": waterMarkDirPath,
      "x": x.toString(),
      "y": y.toString(),
      "w": w.toString(),
      "h": h.toString(),
    };
    String strV = await _livePusherMethodChannel.invokeMethod(
      'addDynamicWaterMarkImageData',
      wrapArgs(arg: params),
    );
    return int.parse(strV);
  }

  /// 删除动态贴纸
  ///
  /// [vid] 贴纸id，调用后[addDynamicWaterMarkImageData]时返回
  Future<void> removeDynamicWaterMark(int vid) async {
    return _livePusherMethodChannel.invokeMethod(
      'removeDynamicWaterMark',
      wrapArgs(arg: vid.toString()),
    );
  }

  /// 截图
  ///
  /// [count] 截图次数
  ///
  /// [interval] 截图间隔
  ///
  /// [dir] 截图保存路径。Android系统下是全路径，iOS系统下是沙盒存放相对文件夹路径。如果需要监听截图回调[setSnapshotDelegate]，需要设置。
  ///
  /// [dirTypeForIOS] iOS系统下沙盒目录，可选。 默认:[AlivcLiveSnapshotDirType.document]。如果需要监听截图回调[setSnapshotDelegate]，iOS系统下可选设置。
  Future<void> snapshot(int count, int interval, String dir,
      {AlivcLiveSnapshotDirType? dirTypeForIOS}) async {
    Map params = {
      "count": count.toString(),
      "interval": interval.toString(),
    };

    if (Platform.isIOS) {
      params["saveDir"] = {
        "dirType": (dirTypeForIOS ?? AlivcLiveSnapshotDirType.document)
            .index
            .toString(),
        "dir": dir,
      };
    } else {
      params["saveDir"] = dir;
    }

    return _livePusherMethodChannel.invokeMethod(
      'snapshot',
      wrapArgs(arg: params),
    );
  }

  /// 设置截图监听回调
  ///
  /// 需要在调用[snapshot]后调用
  Future<void> setSnapshotDelegate() async {
    return _livePusherMethodChannel.invokeMethod(
      'setSnapshotDelegate',
      wrapArgs(),
    );
  }

  /// 发送自定义视频数据
  ///
  /// [data] 视频数据
  ///
  /// [width] 视频宽度
  ///
  /// [height] 视频高度
  ///
  /// [size] 数据大小
  ///
  /// [pts] 时间戳（单位微秒）
  ///
  /// [rotation] 旋转
  Future<void> sendVideoData(Uint8List data, int width, int height, int size,
      int pts, int rotation) async {
    Map params = {
      "data": data,
      "width": width.toString(),
      "height": height.toString(),
      "size": size.toString(),
      "pts": pts.toString(),
      "rotation": rotation.toString(),
    };
    return _livePusherMethodChannel.invokeMethod(
      'sendVideoData',
      wrapArgs(arg: params),
    );
  }

  /// 发送自定义音频数据
  ///
  /// [data] 音频数据
  ///
  /// [size] 数据大小
  ///
  /// [sampleRate] 采样率
  ///
  /// [channel] 声道数
  ///
  /// [pts] 时间戳（单位微秒）
  Future<void> sendPCMData(
      Uint8List data, int size, int sampleRate, int channel, int pts) async {
    Map params = {
      "data": data,
      "size": size,
      "sampleRate": sampleRate,
      "channel": channel,
      "pts": pts,
    };
    return _livePusherMethodChannel.invokeMethod(
      'sendPCMData',
      wrapArgs(arg: params),
    );
  }

  /// 绑定云端的混流（转码）参数
  ///
  /// 注:互动模式下特定接口
  ///
  /// 将[AlivcLiveTranscodingConfig]同[AlivcLivePusher]联系起来。
  Future<void> bindLiveMixTranscodingConfig() async {
    return _livePusherMethodChannel.invokeMethod(
      'bindLiveMixTranscodingConfig',
      wrapArgs(),
    );
  }

  /// 设置云端的混流（转码）参数
  ///
  /// 注:互动模式下特定接口
  ///
  /// 一个直播间中可能有不止一位主播，而且每个主播都有自己的画面和声音，但对于 CDN 观众来说，他们只需要一路直播流
  ///
  /// 所以您需要将多路音视频流混成一路标准的直播流，这就需要混流转码
  ///
  /// 在连麦场景下，需要将主播和连麦观众音视频流混成一路标准的直播流，供CDN观众观看
  ///
  /// 在PK场景下，需要将进行PK的多个主播的音视频流混成一路标准的直播流，供CDN观众观看
  ///
  /// [isNeed] 是否需要设置 若主播还在房间中但不再需要混流，请务必传入false进行取消，因为当发起混流后，云端混流模块就会开始工作，不及时取消混流可能会引起不必要的计费损失
  Future<void> setLiveMixTranscodingConfig(bool isNeed) async {
    return _livePusherMethodChannel.invokeMethod(
      'setLiveMixTranscodingConfig',
      wrapArgs(arg: boolToString(isNeed)),
    );
  }

  /// 关闭/打开视频
  ///
  /// 注:互动模式下特定接口
  ///
  /// [mute] true：表示不发送视频数据；false：表示恢复正常
  Future<void> muteLocalCamera(bool mute) async {
    return _livePusherMethodChannel.invokeMethod(
      'muteLocalCamera',
      wrapArgs(arg: boolToString(mute)),
    );
  }

  /// 设置音频输出为听筒还是扬声器
  ///
  /// 注:互动模式下特定接口
  ///
  /// [enable] true：扬声器模式(默认)；false：听筒模式
  Future<void> enableSpeakerphone(bool enable) async {
    return _livePusherMethodChannel.invokeMethod(
      'enableSpeakerphone',
      wrapArgs(arg: boolToString(enable)),
    );
  }

  /// 获取当前音频输出为听筒还是扬声器
  ///
  /// 注:互动模式下特定接口
  ///
  /// [enable] true：扬声器模式(默认)；false：听筒模式
  Future<bool> isEnableSpeakerphone() async {
    String strV = await _livePusherMethodChannel.invokeMethod(
      'isEnableSpeakerphone',
      wrapArgs(),
    );
    int intV = int.parse(strV);
    return intV == 1 ? true : false;
  }

  /// 使用美颜
  ///
  /// 必须同时集成[flutter_livepush_beauty_plugin]插件才可使用
  Future<void> useBeauty() async {
    return _livePusherMethodChannel.invokeMethod(
      'useBeauty',
      wrapArgs(),
    );
  }

  // 回调部分
  /// SDK错误回调
  ///
  /// 监听[setErrorDelegate]回调
  ///
  /// [onLivePusherError] param [errorCode] 错误码
  ///
  /// [onLivePusherError] param [errorDescription] 错误描述
  void setOnSDKError(OnLivePusherError onSDKError) {
    this.onSDKError = onSDKError;
  }

  /// 系统错误回调
  ///
  /// 监听[setErrorDelegate]回调
  ///
  /// [onSystemError] param [errorCode] 错误码
  ///
  /// [onSystemError] param [errorDescription] 错误描述
  void setOnSystemError(OnLivePusherError onSystemError) {
    this.onSystemError = onSystemError;
  }

  /// 开始预览回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPreviewStarted(OnLivePusherCallback onPreviewStarted) {
    this.onPreviewStarted = onPreviewStarted;
  }

  /// 停止预览回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPreviewStoped(OnLivePusherCallback onPreviewStoped) {
    this.onPreviewStopped = onPreviewStoped;
  }

  /// 渲染第一帧回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnFirstFramePreviewed(OnLivePusherCallback onFirstFramePreviewed) {
    this.onFirstFramePreviewed = onFirstFramePreviewed;
  }

  /// 推流开始回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPushStarted(OnLivePusherCallback onPushStarted) {
    this.onPushStarted = onPushStarted;
  }

  /// 摄像头推流暂停回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPushPaused(OnLivePusherCallback onPushPaused) {
    this.onPushPaused = onPushPaused;
  }

  /// 摄像头推流恢复回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPushResumed(OnLivePusherCallback onPushResumed) {
    this.onPushResumed = onPushResumed;
  }

  /// 重新推流回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPushRestart(OnLivePusherCallback onPushRestart) {
    this.onPushRestart = onPushRestart;
  }

  /// 推流停止回调
  ///
  /// 监听[setInfoDelegate]回调
  void setOnPushStoped(OnLivePusherCallback onPushStoped) {
    this.onPushStopped = onPushStoped;
  }

  /// 推流链接失败
  ///
  /// 监听[setNetworkDelegate]回调
  ///
  /// [onConnectFail] param [errorCode] 错误码
  ///
  /// [onConnectFail] param [errorDescription] 错误描述
  void setOnConnectFail(OnLivePusherError onConnectFail) {
    this.onConnectFail = onConnectFail;
  }

  /// 网络恢复
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnConnectRecovery(OnLivePusherCallback onConnectRecovery) {
    this.onConnectRecovery = onConnectRecovery;
  }

  /// 连接被断开
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnConnectionLost(OnLivePusherCallback onConnectionLost) {
    this.onConnectionLost = onConnectionLost;
  }

  /// 网络差回调
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnNetworkPoor(OnLivePusherCallback onNetworkPoor) {
    this.onNetworkPoor = onNetworkPoor;
  }

  /// 重连失败回调
  ///
  /// 监听[setNetworkDelegate]回调
  ///
  /// [onReconnectError] param [errorCode] 错误码
  ///
  /// [onReconnectError] param [errorDescription] 错误描述
  void setOnReconnectError(OnLivePusherError onReconnectError) {
    this.onReconnectError = onReconnectError;
  }

  /// 重连开始回调
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnReconnectStart(OnLivePusherCallback onReconnectStart) {
    this.onReconnectStart = onReconnectStart;
  }

  /// 重连成功回调
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnReconnectSuccess(OnLivePusherCallback onReconnectSuccess) {
    this.onReconnectSuccess = onReconnectSuccess;
  }

  /// 发送数据超时
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnSendDataTimeout(OnLivePusherCallback onSendDataTimeout) {
    this.onSendDataTimeout = onSendDataTimeout;
  }

  /// 发送SEI Message 通知
  ///
  /// 监听[setNetworkDelegate]回调
  void setOnSendSeiMessage(OnLivePusherCallback onSendSeiMessage) {
    this.onSendSeiMessage = onSendSeiMessage;
  }

  /// 背景音乐播放完毕
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMCompleted(OnLivePusherCallback onBGMCompleted) {
    this.onBGMCompleted = onBGMCompleted;
  }

  /// 背景音乐下载播放超时
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMDownloadTimeout(OnLivePusherCallback onBGMDownloadTimeout) {
    this.onBGMDownloadTimeout = onBGMDownloadTimeout;
  }

  /// 背景音乐开启失败
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMOpenFailed(OnLivePusherCallback onBGMOpenFailed) {
    this.onBGMOpenFailed = onBGMOpenFailed;
  }

  /// 背景音乐暂停播放
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMPaused(OnLivePusherCallback onBGMPaused) {
    this.onBGMPaused = onBGMPaused;
  }

  /// 背景音乐当前播放进度
  ///
  /// 监听[setBGMDelegate]回调
  ///
  /// [onBGMProgress] param [progress] 播放时长
  ///
  /// [onBGMProgress] param [duration] 总时长
  void setOnBGMProgress(OnBGMProgress onBGMProgress) {
    this.onBGMProgress = onBGMProgress;
  }

  /// 背景音乐恢复播放
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMResumed(OnLivePusherCallback onBGMResumed) {
    this.onBGMResumed = onBGMResumed;
  }

  /// 背景音乐开始播放
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMStarted(OnLivePusherCallback onBGMStarted) {
    this.onBGMStarted = onBGMStarted;
  }

  /// 背景音乐停止播放
  ///
  /// 监听[setBGMDelegate]回调
  void setOnBGMStoped(OnLivePusherCallback onBGMStoped) {
    this.onBGMStopped = onBGMStoped;
  }

  /// 截图回调
  ///
  /// [onSnapshot] param [saveResult] 是否保存成功 true:成功, false:失败
  ///
  /// [onSnapshot] param [savePath] 保存路径，Android系统下是全路径，iOS系统下是沙盒存放相对文件夹路径
  ///
  /// [onSnapshot] param [dirTypeForIOS] iOS系统下沙盒目录 default : AlivcLiveSnapshotDirType.document
  void setOnSnapshot(OnSnapshot onSnapshot) {
    this.onSnapshot = onSnapshot;
  }

  // 统一回调接口
  void _onEvent(dynamic event) {
    String method = event[_livePusherMethod];
    switch (method) {
      case "onSDKError":
        if (this.onSDKError != null) {
          int errorCode = int.parse(event[_livePusherErrorCode]);
          String errorDescription = event[_livePusherErrorDescription];
          this.onSDKError!(errorCode, errorDescription);
        }
        break;
      case "onSystemError":
        if (this.onSystemError != null) {
          int errorCode = int.parse(event[_livePusherErrorCode]);
          String errorDescription = event[_livePusherErrorDescription];
          this.onSystemError!(errorCode, errorDescription);
        }
        break;
      case "onPreviewStarted":
        if (this.onPreviewStarted != null) {
          this.onPreviewStarted?.call();
        }
        break;
      case "onPreviewStoped":
        if (this.onPreviewStopped != null) {
          this.onPreviewStopped?.call();
        }
        break;
      case "onFirstFramePreviewed":
        if (this.onFirstFramePreviewed != null) {
          this.onFirstFramePreviewed?.call();
        }
        break;
      case "onPushStarted":
        if (this.onPushStarted != null) {
          this.onPushStarted?.call();
        }
        break;
      case "onPushPaused":
        if (this.onPushPaused != null) {
          this.onPushPaused?.call();
        }
        break;
      case "onPushResumed":
        if (this.onPushResumed != null) {
          this.onPushResumed?.call();
        }
        break;
      case "onPushRestart":
        if (this.onPushRestart != null) {
          this.onPushRestart?.call();
        }
        break;
      case "onPushStoped":
        if (this.onPushStopped != null) {
          this.onPushStopped?.call();
        }
        break;
      case "onConnectFail":
        if (this.onConnectFail != null) {
          int errorCode = int.parse(event[_livePusherErrorCode]);
          String errorDescription = event[_livePusherErrorDescription];
          this.onConnectFail!(errorCode, errorDescription);
        }
        break;
      case "onConnectRecovery":
        if (this.onConnectRecovery != null) {
          this.onConnectRecovery?.call();
        }
        break;
      case "onConnectionLost":
        if (this.onConnectionLost != null) {
          this.onConnectionLost?.call();
        }
        break;
      case "onNetworkPoor":
        if (this.onNetworkPoor != null) {
          this.onNetworkPoor?.call();
        }
        break;
      case "onReconnectError":
        if (this.onReconnectError != null) {
          int errorCode = int.parse(event[_livePusherErrorCode]);
          String errorDescription = event[_livePusherErrorDescription];
          this.onReconnectError!(errorCode, errorDescription);
        }
        break;
      case "onReconnectStart":
        if (this.onReconnectStart != null) {
          this.onReconnectStart?.call();
        }
        break;
      case "onReconnectSuccess":
        if (this.onReconnectSuccess != null) {
          this.onReconnectSuccess?.call();
        }
        break;
      case "onSendDataTimeout":
        if (this.onSendDataTimeout != null) {
          this.onSendDataTimeout?.call();
        }
        break;
      case "onSendSeiMessage":
        if (this.onSendSeiMessage != null) {
          this.onSendSeiMessage?.call();
        }
        break;
      case "onBGMCompleted":
        if (this.onBGMCompleted != null) {
          this.onBGMCompleted?.call();
        }
        break;
      case "onBGMDownloadTimeout":
        if (this.onBGMDownloadTimeout != null) {
          this.onBGMDownloadTimeout?.call();
        }
        break;
      case "onBGMOpenFailed":
        if (this.onBGMOpenFailed != null) {
          this.onBGMOpenFailed?.call();
        }
        break;
      case "onBGMPaused":
        if (this.onBGMPaused != null) {
          this.onBGMPaused?.call();
        }
        break;
      case "onBGMProgress":
        if (this.onBGMProgress != null) {
          int progress = int.parse(event[_livePusherBGMProgress]);
          int duration = int.parse(event[_livePusherBGMDuration]);
          this.onBGMProgress?.call(progress, duration);
        }
        break;
      case "onBGMResumed":
        if (this.onBGMResumed != null) {
          this.onBGMResumed?.call();
        }
        break;
      case "onBGMStarted":
        if (this.onBGMStarted != null) {
          this.onBGMStarted?.call();
        }
        break;
      case "onBGMStoped":
        if (this.onBGMStopped != null) {
          this.onBGMStopped?.call();
        }
        break;
      case "onSnapshot":
        if (this.onSnapshot != null) {
          bool saveResult = intToBool(
            int.parse(event[_livePusherSnapshotSaveResult]),
          );
          dynamic savePath = event[_livePusherSnapshotSavePath];
          if (Platform.isIOS) {
            AlivcLiveSnapshotDirType dirType =
                AlivcLiveSnapshotDirType.document;
            int saveDirType = savePath[_livePusherSnapshotSaveDirType];
            if (saveDirType == 1) {
              dirType = AlivcLiveSnapshotDirType.library;
            }
            this.onSnapshot!(
              saveResult,
              savePath[_livePusherSnapshotSavePath],
              dirTypeForIOS: dirType,
            );
          } else {
            this.onSnapshot!(saveResult, savePath);
          }
        }
        break;
    }
  }

  // TODO keria.
  void _onError(dynamic error) {}
}
