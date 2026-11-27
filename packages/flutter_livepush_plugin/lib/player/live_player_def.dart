///
/// Copyright © 2023 Alibaba Cloud. All rights reserved.
///
/// Author：keria
/// Date：2023/12/11
/// Email：runchen.brc@alibaba-inc.com
///
/// Reference：Explain the purpose of the current file

@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
typedef OnLivePlayerCallback = void Function();

@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
typedef OnLivePlayerError = void Function(
  AlivcLivePlayerError errorCode,
  String errorMessage,
);

/// 渲染模式
///
/// [auto] 自动模式
///
/// [stretch] 延伸模式
///
/// [fill] 填充模式
///
/// [crop] 裁剪模式

@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
enum AlivcLivePlayRenderMode {
  auto,
  stretch,
  fill,
  crop,
}

/// 视频旋转角度
///
/// [rotation_0] 视频旋转角度 - 0
///
/// [rotation_90] 视频旋转角度 - 90
///
/// [rotation_180] 视频旋转角度 - 180
///
/// [rotation_270] 视频旋转角度 - 270

@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
enum AlivcLivePlayRotationMode {
  rotation_0,
  rotation_90,
  rotation_180,
  rotation_270,
}

/// 互动模式拉流错误码
///
/// [streamNotFound] 播放URL指定的播放流不存在
///
/// [streamStopped] 播放URL指定的播放流已停止推流

@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
enum AlivcLivePlayerError {
  streamNotFound,
  streamStopped,
}


@Deprecated('No longer maintained. Interactive live streaming is discontinued.')
class AlivcLivePlayerErrorData {
  /// 枚举Index转为对应原生接口返回值
  ///
  /// [index] 枚举Index
  ///
  /// [returns] 原生接口返回值
  static int convertInterfaceValue(int index) {
    switch (index) {
      case 0:
        return 1;
      case 1:
        return 2;
    }
    return 1;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值

  @Deprecated('No longer maintained. Interactive live streaming is discontinued.')
  static AlivcLivePlayerError convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 1:
        return AlivcLivePlayerError.streamNotFound;
      case 2:
        return AlivcLivePlayerError.streamStopped;
    }
    return AlivcLivePlayerError.streamNotFound;
  }
}
