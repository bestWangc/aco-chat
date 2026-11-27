import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_livepush_plugin/player/live_player_config.dart';
import 'package:flutter_livepush_plugin/player/live_player_def.dart';
import 'package:flutter_livepush_plugin/util/live_utils.dart';
@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
class AlivcLivePlayer {
  static const String _livePlayerMethodName = "plugins.liveplayer.method";
  static const String _livePlayerEventName = "plugins.liveplayer.event";

  static const String _method = "method";

  static const String _errorCode = "errorCode";
  static const String _errorMessage = "errorMessage";

  static const String _upQuality = "upQuality";
  static const String _downQuality = "downQuality";

  static const MethodChannel _livePlayerMethodChannel = MethodChannel(
    _livePlayerMethodName,
  );

  static const EventChannel _livePlayerEventChannel = EventChannel(
    _livePlayerEventName,
  );

  OnLivePlayerError? _onErrorListener;
  OnLivePlayerCallback? _onPlayStarted;
  OnLivePlayerCallback? _onPlayStopped;
  OnLivePlayerCallback? _onFirstVideoFrameDrawn;

  /// 创建[AlivcLivePlayer]实例
  AlivcLivePlayer.init() {
    _livePlayerEventChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onError,
        );
  }

  /// 绑定直播连麦播放参数配置
  ///
  /// 将[AlivcLivePlayConfig]同[AlivcLivePlayer]联系起来。
  Future<void> bindPlayConfig() async {
    return _livePlayerMethodChannel.invokeMethod(
      'bindPlayConfig',
      wrapArgs(),
    );
  }

  /// 初始化直播连麦播放引擎
  Future<void> initLivePlayer() async {
    return _livePlayerMethodChannel.invokeMethod(
      'initLivePlayer',
      wrapArgs(),
    );
  }

  /// 设置播放回调
  Future<void> setLivePlayerDelegate() async {
    return _livePlayerMethodChannel.invokeMethod(
      'setLivePlayerDelegate',
      wrapArgs(),
    );
  }

  /// 设置播放View
  Future<void> setPlayView() async {
    return _livePlayerMethodChannel.invokeMethod(
      'setPlayView',
      wrapArgs(),
    );
  }

  /// 开始播放音视频流
  Future<void> startPlayWithURL(String url) async {
    return _livePlayerMethodChannel.invokeMethod(
      'startPlayWithURL',
      wrapArgs(arg: url),
    );
  }

  /// 停止播放音视频流
  Future<void> stopPlay() async {
    return _livePlayerMethodChannel.invokeMethod(
      'stopPlay',
      wrapArgs(),
    );
  }

  /// 暂停播放音频流
  Future<void> pauseAudioPlaying() async {
    return _livePlayerMethodChannel.invokeMethod(
      'pauseAudioPlaying',
      wrapArgs(),
    );
  }

  /// 恢复播放音频流
  Future<void> resumeAudioPlaying() async {
    return _livePlayerMethodChannel.invokeMethod(
      'resumeAudioPlaying',
      wrapArgs(),
    );
  }

  /// 暂停播放视频流
  Future<void> pauseVideoPlaying() async {
    return _livePlayerMethodChannel.invokeMethod(
      'pauseVideoPlaying',
      wrapArgs(),
    );
  }

  /// 恢复播放视频流
  Future<void> resumeVideoPlaying() async {
    return _livePlayerMethodChannel.invokeMethod(
      'resumeVideoPlaying',
      wrapArgs(),
    );
  }

  /// 设置播放音量
  ///
  /// [volume] 播放音量，取值范围[0,400] 0：静音，<100：减小音量，>100：放大音量
  Future<void> setPlayoutVolume(int volume) async {
    return _livePlayerMethodChannel.invokeMethod(
      'resumeVideoPlaying',
      wrapArgs(arg: volume.toString()),
    );
  }

  /// 播放错误回调
  ///
  /// [onError] param [errorCode] 错误码
  ///
  /// [onError] param [errorMessage] 错误信息
  void setOnError(OnLivePlayerError onError) {
    _onErrorListener = onError;
  }

  /// 开始播放回调
  void setOnPlayStarted(OnLivePlayerCallback onPlayStarted) {
    _onPlayStarted = onPlayStarted;
  }

  /// 结束播放回调
  void setOnPlayStopped(OnLivePlayerCallback onPlayStopped) {
    _onPlayStopped = onPlayStopped;
  }

  /// 视频首帧渲染回调
  void setOnFirstVideoFrameDrawn(OnLivePlayerCallback onFirstVideoFrameDrawn) {
    _onFirstVideoFrameDrawn = onFirstVideoFrameDrawn;
  }

  // 统一回调接口
  void _onEvent(dynamic event) {
    String method = event[_method];
    switch (method) {
      case "onError":
        if (_onErrorListener != null) {
          int errorCodeIntV = int.parse(event[_errorCode]);
          String errorMessage = event[_errorMessage];
          _onErrorListener?.call(
            AlivcLivePlayerErrorData.convertEnumValue(errorCodeIntV),
            errorMessage,
          );
        }
        break;
      case "onPlayStarted":
        _onPlayStarted?.call();
        break;
      case "onPlayStopped":
        _onPlayStopped?.call();
        break;
      case "onFirstVideoFrameDrawn":
        _onFirstVideoFrameDrawn?.call();
        break;
    }
  }

  void _onError(dynamic error) {}
}
