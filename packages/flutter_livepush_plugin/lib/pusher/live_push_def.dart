typedef OnLivePusherCallback = void Function();
typedef OnLivePusherError = void Function(
  int errorCode,
  String errorDescription,
);
typedef OnLivePusherNetworkError = void Function(
  int errorCode,
  String errorDescription,
);
typedef OnBGMProgress = void Function(int progress, int duration);
typedef OnSnapshot = void Function(
  bool saveResult,
  String savePath, {
  AlivcLiveSnapshotDirType? dirTypeForIOS,
});

/// 直播SDK推流模式
///
/// [basic] 基础模式，默认模式，常规的RTMP推流、RTS推流，不支持连麦、PK等实时互动，如果一场直播没有互动需求，建议使用该模式
///
/// [interactive] 支持连麦、PK等实时互动，如果一场直播有互动需求，建议使用该模式
enum AlivcLivePushMode {
  basic,
  @Deprecated(
      'No longer maintained. Interactive live streaming is discontinued.')
  interactive,
}

/// 分辨率
///
/// [resolution_180P] 180P
///
/// [resolution_240P] 240P
///
/// [resolution_360P] 360P
///
/// [resolution_480P] 480P
///
/// [resolution_540P] 540P
///
/// [resolution_720P] 720P
///
/// [resolution_1080P] 1080P
enum AlivcLivePushResolution {
  resolution_180P,
  resolution_240P,
  resolution_360P,
  resolution_480P,
  resolution_540P,
  resolution_720P,
  resolution_1080P
}

/// 视频帧率
enum AlivcLivePushFPS {
  fps_8,
  fps_10,
  fps_12,
  fps_15,
  fps_20,
  fps_25,
  fps_30,
}

class FPSData {
  static Map<AlivcLivePushFPS, String> fpsItems = {
    AlivcLivePushFPS.fps_8: "8",
    AlivcLivePushFPS.fps_10: "10",
    AlivcLivePushFPS.fps_12: "12",
    AlivcLivePushFPS.fps_15: "15",
    AlivcLivePushFPS.fps_20: "20",
    AlivcLivePushFPS.fps_25: "25",
    AlivcLivePushFPS.fps_30: "30",
  };

  /// 枚举Index转为对应原生接口返回值
  ///
  /// [index] 枚举Index
  ///
  /// [returns] 原生接口返回值
  static int convertInterfaceValue(int index) {
    switch (index) {
      case 0:
        return 8;
      case 1:
        return 10;
      case 2:
        return 12;
      case 3:
        return 15;
      case 4:
        return 20;
      case 5:
        return 25;
      case 6:
        return 30;
    }
    return 20;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值
  static AlivcLivePushFPS convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 8:
        return AlivcLivePushFPS.fps_8;
      case 10:
        return AlivcLivePushFPS.fps_10;
      case 12:
        return AlivcLivePushFPS.fps_12;
      case 15:
        return AlivcLivePushFPS.fps_15;
      case 20:
        return AlivcLivePushFPS.fps_20;
      case 25:
        return AlivcLivePushFPS.fps_25;
      case 30:
        return AlivcLivePushFPS.fps_30;
    }
    return AlivcLivePushFPS.fps_20;
  }
}

/// 推流模式
///
/// [resolution_first] 清晰度优先模式
///
/// [fluency_first] 流畅度优先模式
///
/// [custom] 自定义模式
enum AlivcLivePushQualityMode {
  resolution_first,
  fluency_first,
  custom,
}

/// 关键帧间隔
enum AlivcLivePushVideoEncodeGOP {
  gop_1,
  gop_2,
  gop_3,
  gop_4,
  gop_5,
}

class VideoEncodeGOPData {
  /// 枚举Index转为对应原生接口返回值
  ///
  /// [index] 枚举Index
  ///
  /// [returns] 原生接口返回值
  static int convertInterfaceValue(int index) {
    int intV = 2;
    switch (index) {
      case 0:
        intV = 1;
        break;
      case 1:
        intV = 2;
        break;
      case 2:
        intV = 3;
        break;
      case 3:
        intV = 4;
        break;
      case 4:
        intV = 5;
        break;
    }
    return intV;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值
  static AlivcLivePushVideoEncodeGOP convertEnumValue(int interfaceValue) {
    AlivcLivePushVideoEncodeGOP enumV = AlivcLivePushVideoEncodeGOP.gop_2;
    switch (interfaceValue) {
      case 1:
        enumV = AlivcLivePushVideoEncodeGOP.gop_1;
        break;
      case 2:
        enumV = AlivcLivePushVideoEncodeGOP.gop_2;
        break;
      case 3:
        enumV = AlivcLivePushVideoEncodeGOP.gop_3;
        break;
      case 4:
        enumV = AlivcLivePushVideoEncodeGOP.gop_4;
        break;
      case 5:
        enumV = AlivcLivePushVideoEncodeGOP.gop_5;
        break;
    }
    return enumV;
  }
}

/// 视频硬编码方式
///
/// [h264] 使用H264硬编码
///
/// [h265] 使用H265硬编码
enum AlivcLivePushVideoEncoderModeHardCodec {
  h264,
  h265,
}

/// 推流模式
///
/// [video_and_audio] 音视频
///
/// [audio_only] 纯音频
///
/// [video_only] 纯视频
enum AlivcLivePushStreamMode {
  video_and_audio,
  audio_only,
  video_only,
}

/// 推流屏幕方向
///
/// [portrait] 竖屏推流
///
/// [landscape_home_left] 横屏Left方向
///
/// [landscape_home_right] 横屏Right方向
enum AlivcLivePushOrientation {
  portrait,
  landscape_home_left,
  landscape_home_right,
}

/// 预览显示模式
///
/// [preview_scale_fill] 铺满窗口，视频比例和窗口比例不一致时预览会有变形
///
/// [preview_aspect_fit] 保持视频比例，视频比例和窗口比例不一致时有黑边
///
/// [preview_aspect_fill] 剪切视频以适配窗口比例，视频比例和窗口比例不一致时会裁剪视频
enum AlivcPusherPreviewDisplayMode {
  preview_scale_fill,
  preview_aspect_fit,
  preview_aspect_fill,
}

/// 音频编码格式
enum AlivcLivePushAudioEncoderProfile {
  AAC_LC,
  HE_AAC,
  HE_AAC_V2,
  AAC_LD,
}

class AudioEncoderProfileData {
  static Map<AlivcLivePushAudioEncoderProfile, String> items = {
    AlivcLivePushAudioEncoderProfile.AAC_LC: "AAC_LC",
    AlivcLivePushAudioEncoderProfile.HE_AAC: "HE_AAC",
    AlivcLivePushAudioEncoderProfile.HE_AAC_V2: "HE_AAC_V2",
    AlivcLivePushAudioEncoderProfile.AAC_LD: "AAC_LD",
  };

  /// 枚举Index转为对应原生接口返回值
  ///
  /// [index] 枚举Index
  ///
  /// [returns] 原生接口返回值
  static int convertInterfaceValue(int index) {
    switch (index) {
      case 0:
        return 2;
      case 1:
        return 5;
      case 2:
        return 29;
      case 3:
        return 23;
    }
    return 2;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值
  static AlivcLivePushAudioEncoderProfile convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 2:
        return AlivcLivePushAudioEncoderProfile.AAC_LC;
      case 5:
        return AlivcLivePushAudioEncoderProfile.HE_AAC;
      case 29:
        return AlivcLivePushAudioEncoderProfile.HE_AAC_V2;
      case 23:
        return AlivcLivePushAudioEncoderProfile.AAC_LD;
    }
    return AlivcLivePushAudioEncoderProfile.AAC_LC;
  }
}

/// 声道数
///
/// [audio_channel_one] 单声道
///
/// [audio_channel_two] 双声道
enum AlivcLivePushAudioChannel {
  audio_channel_one,
  audio_channel_two,
}

class AudioChannelData {
  static Map<AlivcLivePushAudioChannel, String> items = {
    AlivcLivePushAudioChannel.audio_channel_one: "单声道",
    AlivcLivePushAudioChannel.audio_channel_two: "双声道",
  };

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
  static AlivcLivePushAudioChannel convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 1:
        return AlivcLivePushAudioChannel.audio_channel_one;
      case 2:
        return AlivcLivePushAudioChannel.audio_channel_two;
    }
    return AlivcLivePushAudioChannel.audio_channel_one;
  }
}

/// 音频采样率
///
/// [audio_sample_rate_16] 16000Hz
///
/// [audio_sample_rate_32] 32000Hz
///
/// [audio_sample_rate_44] 44100Hz
///
/// [audio_sample_rate_48] 48000Hz
enum AlivcLivePushAudioSampleRate {
  audio_sample_rate_16,
  audio_sample_rate_32,
  audio_sample_rate_44,
  audio_sample_rate_48,
}

class AudioSampleRateData {
  static Map<AlivcLivePushAudioSampleRate, String> items = {
    AlivcLivePushAudioSampleRate.audio_sample_rate_16: "16",
    AlivcLivePushAudioSampleRate.audio_sample_rate_32: "32",
    AlivcLivePushAudioSampleRate.audio_sample_rate_44: "44",
    AlivcLivePushAudioSampleRate.audio_sample_rate_48: "48",
  };

  /// 枚举Index转为对应原生接口返回值
  ///
  /// [index] 枚举Index
  ///
  /// [returns] 原生接口返回值
  static int convertInterfaceValue(int index) {
    switch (index) {
      case 0:
        return 16000;
      case 1:
        return 32000;
      case 2:
        return 44100;
      case 3:
        return 48000;
    }
    return 3;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值
  static AlivcLivePushAudioSampleRate convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 16000:
        return AlivcLivePushAudioSampleRate.audio_sample_rate_16;
      case 32000:
        return AlivcLivePushAudioSampleRate.audio_sample_rate_32;
      case 44100:
        return AlivcLivePushAudioSampleRate.audio_sample_rate_44;
      case 48000:
        return AlivcLivePushAudioSampleRate.audio_sample_rate_48;
    }
    return AlivcLivePushAudioSampleRate.audio_sample_rate_48;
  }
}

/// 音频编码模式
///
/// [hard] 硬编码
///
/// [soft] 软编码
enum AlivcLivePushAudioEncoderMode {
  hard,
  soft,
}

/// 视频编码模式
///
/// [hard] 硬编码
///
/// [soft] 软编码
enum AlivcLivePushVideoEncoderMode {
  hard,
  soft,
}

/// 摄像头方向
///
/// [back] 后置摄像头
///
/// [front] 前置摄像头
enum AlivcLivePushCameraType {
  back,
  front,
}

/// 外部音频数据
enum AlivcLivePushAudioFormat {
  Unknown,
  U8,
  S16,
  S32,
  F32,
  U8P,
  S16P,
  S32P,
  F32P,
}

class AudioFormatData {
  static int convertInterfaceValue(int index) {
    if (index >= 0 && index <= 8) {
      return index - 1;
    }
    return -1;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值
  static AlivcLivePushAudioFormat convertEnumValue(int interfaceValue) {
    int index = 0;
    if (interfaceValue >= -1 && interfaceValue <= 7) {
      index = interfaceValue + 1;
    }
    return AlivcLivePushAudioFormat.values[index];
  }
}

/// 外部视频数据
enum AlivcLivePushVideoFormat {
  Unknown,
  BGR,
  RGB,
  ARGB,
  BGRA,
  RGBA,
  YUV420P,
  YUVYV12,
  YUVNV21,
  YUVNV12,
  YUVJ420P,
  YUVJ420SP,
  YUVJ444P,
  YUV444P,
}

class VideoFormatData {
  /// 枚举Index转为对应原生接口返回值
  ///
  /// [index] 枚举Index
  ///
  /// [returns] 原生接口返回值
  static int convertInterfaceValue(int index) {
    if (index >= 0 && index <= 13) {
      return index - 1;
    }
    return -1;
  }

  static AlivcLivePushVideoFormat convertEnumValue(int interfaceValue) {
    int index = 0;
    if (interfaceValue >= -1 && interfaceValue <= 12) {
      index = interfaceValue + 1;
    }
    return AlivcLivePushVideoFormat.values[index];
  }
}

/// 音频应用场景
///
/// [defaultMode] 默认场景，一般的直播场景推荐使用
///
/// [mediaMode] 媒体场景，保真人声与音乐音质等 推荐使用
///
/// [musicMode] 音乐场景，高保真音乐音质，乐器教学等对音乐音质有要求的场景推荐使用
enum AlivcLivePusherAudioScenario {
  defaultMode,
  mediaMode,
  musicMode,
}

class AudioScenarioData {
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
      case 2:
        return 3;
    }
    return 1;
  }

  /// 原生接口返回值转为对应枚举值
  ///
  /// [interfaceValue] 原生接口返回值
  ///
  /// [returns] 枚举值
  static AlivcLivePusherAudioScenario convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 1:
        return AlivcLivePusherAudioScenario.defaultMode;
      case 2:
        return AlivcLivePusherAudioScenario.mediaMode;
      case 3:
        return AlivcLivePusherAudioScenario.musicMode;
    }
    return AlivcLivePusherAudioScenario.defaultMode;
  }
}

/// 变声音效模式
///
/// [OFF] 关闭变声音效
///
/// [OLD_MAN] 老人
///
/// [BABYBOY] 男孩
///
/// [BABYGILR] 女孩
///
/// [ROBOT] 机器人
///
/// [DAIMO] 大魔王
///
/// [KTV] KTV
///
/// [ECHO] 回声
///
/// [MAX] 占位符
enum AlivcLivePushAudioEffectVoiceChangeMode {
  OFF,
  OLD_MAN,
  BABYBOY,
  BABYGILR,
  ROBOT,
  DAIMO,
  KTV,
  ECHO,
  MAX,
}

/// 音效混响模式
///
/// [Off] 关闭混响
///
/// [Vocal_I] 人声I
///
/// [Vocal_II] 人声II
///
/// [Bathroom] 澡堂
///
/// [Small_Room_Bright] 明亮小房间
///
/// [Small_Room_Dark] 黑暗小房间
///
/// [Medium_Room] 中等房间
///
/// [Large_Room] 大房间
///
/// [Church_Hall] 教堂走廊
///
/// [Mode_Max] 占位符
enum AlivcLivePushAudioEffectReverbMode {
  Off,
  Vocal_I,
  Vocal_II,
  Bathroom,
  Small_Room_Bright,
  Small_Room_Dark,
  Medium_Room,
  Large_Room,
  Church_Hall,
  Mode_Max,
}

/// 推流状态
///
/// [idle] 空闲
///
/// [initialized] 初始化成功
///
/// [previewing] 打开预览中
///
/// [previewed] 正在预览
///
/// [pushing] 推流连接中
///
/// [pushed] 正在推流
///
/// [stoping] 停止推流中
///
/// [pausing] 暂停推流中
///
/// [paused] 暂停推流
///
/// [resuming] 恢复推流中
///
/// [restarting] 重启推流中
///
/// [error] 错误状态
enum AlivcLivePushStatus {
  idle,
  initialized,
  previewing,
  previewed,
  pushing,
  pushed,
  stoping,
  pausing,
  paused,
  resuming,
  restarting,
  error,
}

/// iOS截图存储沙盒目录类型
///
/// [document] Document
///
/// [library] Library
enum AlivcLiveSnapshotDirType {
  document,
  library,
}

/// 云端混流（转码）裁剪模式
///
/// [crop] 剪裁
///
/// [fill] 填充
enum AlivcLiveTranscodingCropMode {
  crop,
  fill,
}

class AlivcLiveTranscodingCropModeData {
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
  static AlivcLiveTranscodingCropMode convertEnumValue(int interfaceValue) {
    switch (interfaceValue) {
      case 1:
        return AlivcLiveTranscodingCropMode.crop;
      case 2:
        return AlivcLiveTranscodingCropMode.fill;
    }
    return AlivcLiveTranscodingCropMode.crop;
  }
}

class AlivcLiveMixStream {
  /// 参与混流的 userId
  ///
  /// 备注：和推拉地址中userId字端相同
  String userId = "";

  /// 图层位置 x 坐标（绝对像素值）
  int x = 0;

  /// 图层位置 y 坐标（绝对像素值）
  int y = 0;

  /// 图层宽度（绝对像素值）
  int width = 0;

  /// 图层高度（绝对像素值）
  int height = 0;

  /// 图层层次（1 - 15）不可重复
  int zOrder = 1;

  Map convertToMap() {
    return {
      "userId": userId,
      "x": x.toString(),
      "y": y.toString(),
      "width": width.toString(),
      "height": height.toString(),
      "zOrder": zOrder.toString(),
    };
  }

  static AlivcLiveMixStream convertAt(Map mixStreamM) {
    AlivcLiveMixStream mixStream = AlivcLiveMixStream();
    if (mixStreamM.keys.contains("userId")) {
      mixStream.userId = mixStreamM["userId"];
    }
    if (mixStreamM.keys.contains("x")) {
      mixStream.x = int.parse(mixStreamM["x"]);
    }
    if (mixStreamM.keys.contains("y")) {
      mixStream.y = int.parse(mixStreamM["y"]);
    }
    if (mixStreamM.keys.contains("width")) {
      mixStream.width = int.parse(mixStreamM["width"]);
    }
    if (mixStreamM.keys.contains("height")) {
      mixStream.height = int.parse(mixStreamM["height"]);
    }
    if (mixStreamM.keys.contains("zOrder")) {
      mixStream.zOrder = int.parse(mixStreamM["zOrder"]);
    }

    return mixStream;
  }
}
