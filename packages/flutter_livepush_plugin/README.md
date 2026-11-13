# flutter_livepush_plugin

A Flutter plugin for live streaming, built on top of Alibaba Cloud's Live Push SDK, offering real-time audio/video push, custom encoding settings, and multi-platform support (Android & iOS).

## **一、简介**

[阿里云直播推流 SDK](https://help.aliyun.com/zh/live/developer-reference/push-sdk-overview)（ApsaraVideo Pusher SDK）是基于阿里云强大的内容分发网络和音视频实时通讯技术的直播客户端推流开发工具。它提供简单易用的开放接口、网络自适应的流畅体验、多节点低延迟优化以及功能强大的实时美颜等音视频直播技术服务。

[Flutter 推流 SDK](https://help.aliyun.com/zh/live/developer-reference/push-sdk-for-flutter) 基于 Android / iOS 的直播推流 SDK 封装，支持跨平台开发。以下是 Flutter 插件的调用流程和相关说明。详细接口调用请参考插件中的 Dart 文件。

## **二、功能特性**

* **基础直播**
  * 支持摄像头推流（RTMP 推流、RTS 推流）
  * 支持美颜功能

> **备注**：直播连麦方案已迁移至 **RTC + 旁路 CDN** 的新方案，原直播 SDK 的互动模式不再维护。
>
> * 如涉及直播连麦场景，建议使用新方案进行对接，以获得持续的功能支持与优化。
> * 基础直播相关能力不受影响，仍可继续正常使用。
> * 相关文档：[直播连麦](https://help.aliyun.com/zh/live/co-streaming-overview)，[ARTC 实时音视频](https://help.aliyun.com/zh/live/interactive-streaming-overview)

## **三、插件结构说明**

```
.
├── CHANGELOG.md # 版本更新说明
├── README.md # 项目文档
├── android # 安卓原生桥接层
├── example # 推流Flutter Demo层
├── ios # iOS原生桥接层
├── lib # 推流Flutter Dart层
│   ├── base
│   │   ├── live_base.dart # 推流基础接口
│   ├── beauty
│   │   └── live_beauty.dart # 美颜调用接口
│   ├── def
│   │   └── live_def.dart # 推流自定义参数&枚举
│   ├── player
│   │   ├── live_player.dart # 直播播放类（当前仅支持互动直播）
│   │   ├── live_player_config.dart # 直播播放配置类
│   │   └── live_player_def.dart # 直播播放自定义参数&枚举
│   ├── pusher
│   │   ├── live_push_config.dart # 直播推流配置类
│   │   ├── live_push_def.dart # 直播推流自定义参数&枚举
│   │   ├── live_pusher.dart # 直播推流接口，通过AlivcLivePusher类可以完成音视频的采集推流。
│   │   ├── live_pusher_preview.dart # 直播推流预览View
│   │   └── live_transcoding_config.dart # 互动直播，混流配置类
│   └── util
│       └── live_utils.dart # 工具类
├── pubspec.yaml # 依赖管理工具
```

## **四、快速集成**

### **1. 添加依赖**

您可以通过以下两种方式之一将 `flutter_livepush_plugin` 集成到您的 Flutter 项目中。

* **方法一：手动添加依赖**

在您的 `pubspec.yaml` 文件中，添加以下依赖项：

```yaml
dependencies:
  flutter_livepush_plugin: ^x.y.z
```

> **注意**：`x.y.z` 表示 `flutter_livepush_plugin` 的版本号。您可以在 [Pub.dev 官方页面](https://pub.dev/packages/flutter_livepush_plugin) 中查看最新稳定版本号，并将其替换为实际值（例如 `^7.0.0`）。

* **方法二：使用命令行工具**

如果您更倾向于使用命令行，可以直接运行以下命令来添加依赖：

```shell
flutter pub add flutter_livepush_plugin
```

该命令会自动更新您的 `pubspec.yaml` 文件。

无论您选择哪种方式，完成依赖添加后，请在终端中运行以下命令以安装依赖：

```shell
flutter pub get
```

通过上述步骤，`flutter_livepush_plugin` 就已成功集成到您的项目中，您可以开始使用它了！

### **2. 权限配置**
* **Android**

打开 `/android/app/src/main/AndroidManifest.xml` 文件,声明需要申请的权限。

```XML
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```
* **iOS**

需要在iOS工程中的 `Info.plist` 中加入对相机和麦克风的权限申请:
```XML
<key>NSCameraUsageDescription</key>
<string>授权摄像头权限才能正常视频通话</string>
<key>NSMicrophoneUsageDescription</key>
<string>授权麦克风权限才能正常语音通话</string>
```

### **3. License 配置**

为确保插件正常运行，请按照以下步骤完成 License 配置。**如未正确配置，插件将无法正常使用，并可能抛出授权异常**。

1. **获取 License 授权证书和 License Key**
   - 您需要分别获取音视频终端 SDK 的播放器 License 授权证书和 License Key。
   - 获取详细步骤请参考：[管理License](https://help.aliyun.com/zh/apsara-video-sdk/license-authorization-and-management)。
2. **Flutter 项目需分别配置 Android 和 iOS 平台**
   - Flutter 项目需要为 Android 和 iOS 平台单独配置 License。
   - 具体配置方法可参考 [推流 SDK License 集成指南](https://help.aliyun.com/zh/live/developer-reference/integrate-a-push-sdk-license)。
   - 示例工程配置方法请参考 `example` 示例工程。

更多初始化配置，请参考 `example` 示例工程。

## **五、功能使用**

### **1. 摄像头推流**

#### **1.1. 注册SDK**

```dart
/// 1.注册SDK
/// 注意：在调用注册SDK方法前，请完成工程License配置。
AlivcLiveBase.registerSDK();

/// 2.设置监听回调接口
AlivcLiveBase.setListener(AlivcLiveBaseListener(
  onLicenceCheck: (AlivcLiveLicenseCheckResultCode result, String reason) {
    if (result == AlivcLiveLicenseCheckResultCode.success) {
      /// 注册SDK成功
    }
  },
));

/// 3.使用[AlivcLiveBase]其它接口

/// 获取原生直播推流SDK版本号
String sdkVersion = await AlivcLiveBase.getSdkVersion();

/// 启用控制台日志打印
AlivcLiveBase.setConsoleEnable(true);
/// 设置log级别为Debug调试级别
AlivcLiveBase.setLogLevel(AlivcLivePushLogLevel.debug);

/// 每个分片最大大小，最终日志总体积是最大分片大小的5倍
const int saveLogMaxPartFileSizeInKB = 100 * 1024 * 1024;
/// 日志路径
String saveLogDir = "TODO";
/// 设置日志路径及日志分片大小
AlivcLiveBase.setLogPath(saveLogDir, saveLogMaxPartFileSizeInKB);
```

#### **1.2. 配置推流参数**
```dart
/// 1.创建[AlivcLivePusher]实例
AlivcLivePusher livePusher = AlivcLivePusher.init();
/// 2.创建Config，将将[AlivcLivePusherConfig]同[AlivcLivePusher]联系起来
livePusher.createConfig();
/// 3.创建[AlivcLivePusherConfig]实例
AlivcLivePusherConfig pusherConfig = AlivcLivePusherConfig.init();

/// 4.设置推流参数(根据使用场景，自定义设置)
/// 设置分辨率为540P
pusherConfig.setResolution(AlivcLivePushResolution.resolution_540P);
/// 设置视频采集帧率为20fps。建议用户使用20fps
pusherConfig.setFps(AlivcLivePushFPS.fps_20);
/// 打开码率自适应，默认为true
pusherConfig.setEnableAutoBitrate(true);
/// 设置关键帧间隔。关键帧间隔越大，延时越高。建议设置为1-2
pusherConfig.setVideoEncodeGop(AlivcLivePushVideoEncodeGOP.gop_2);
/// 设置重连时长为2s。单位为毫秒，设置不小于1秒，建议使用默认值即可。
pusherConfig.setConnectRetryInterval(2000);
/// 设置预览镜像为关闭
pusherConfig.setPreviewMirror(false);
/// 设置推流方向为竖屏
pusherConfig.setOrientation(AlivcLivePushOrientation.portrait);
/// 设置打开分辨率自适应
pusherConfig.setEnableAutoResolution(true);

/// 设置暂停图片
String pauseImagePath = "xxxx"; // xxxx为手机存放的图片路径
pusherConfig.setPauseImg(pauseImagePath);

/// 设置预览显示模式为保持视频比例
pusherConfig.setPreviewDisplayMode(AlivcPusherPreviewDisplayMode.preview_aspect_fit);
```

#### **1.3. 进行推流**
```dart
/// 1.创建推流引擎实例
livePusher.initLivePusher();

/// 2.注册推流听回调
/// 设置推流状态监听回调
livePusher.setInfoDelegate();
/// 设置推流错误监听回调
livePusher.setErrorDelegate();
/// 设置推流网络监听回调
livePusher.setNetworkDelegate();

/// 3.创建推流预览视图
var x = 0.0; // 自定义数值
var y = 0.0; // 自定义数值
var width = MediaQuery.of(context).size.width; // 自定义数值
var height = MediaQuery.of(context).size.height; // 自定义数值
AlivcPusherPreview pusherPreviewView = AlivcPusherPreview(
      onCreated: _onPusherPreviewCreated,
      viewType: AlivcPusherPreviewType.push, 
      x: x,
      y: y,
      width: width,
      height: height);
  return Container(
        color: Colors.black,
        width: width,
        height: height,
        child: pusherPreviewView);

// 视图创建回调
_onPusherPreviewCreated(id) {
    /// 4.开始预览
    livePusher.startPreview();
}

/// 开始预览调用之后执行下面的步骤

/// 5.开始推流。预览成功后才可以开始推流
String pushURL = "推流测试地址(rtmp://......)"; 
livePusher.startPushWithURL(pushURL);

/// 6.设置其他推流控制
/// 暂停摄像头推流。可以调用[setPauseImg]后调用[pause]接口，从摄像头推流切换成静态图片推流，音频推流继续。
livePusher.pause();
/// 从静态图片推流切换成摄像头推流，音频推流继续
livePusher.resume();
/// 推流状态下可调用停止推流，完成后推流停止
livePusher.stopPush();
/// 在预览状态下才可以调用停止预览，正在推流状态下，调用停止预览无效。预览停止后，预览画面定格在最后一帧
livePusher.stopPreview();
/// 推流状态下或者接收到所有Error相关回调状态下可调用重新推流，且Error状态下只可以调用此接口(或者[reconnectPushAsync]重连)或者调用[destory]销毁推流。完成后重新开始推流，重启[AlivcLivePusher]内部的一切资源，包括预览、推流等等restart
livePusher.restartPush();
/// 推流状态下或者接收到[setNetworkDelegate]相关的Error回调状态下可调用此接口, 且Error状态下只可以调用此接口(或者[restartPush]重新推流)或者调用[destory]销毁推流。完成后推流重连，重新链接推流
livePusher.reconnectPushAsync();
/// 销毁推流后，推流停止，预览停止，预览画面移除。[AlivcLivePusher]相关的一切资源销毁
livePusher.destory();
```

#### **1.4. 设置背景音乐**
```dart
/// 开始播放背景音乐
String musicPath = "xxxx"; // xxxx为手机存放的音乐资源路径
livePusher.startBGMWithMusicPathAsync(musicPath);
/// 停止播放背景音乐。若当前正在播放BGM，并且需要切换歌曲，只需要调用开始播放背景音乐接口即可，无需停止当前正在播放的背景音乐
livePusher.stopBGMAsync();
/// 暂停播放背景音乐，背景音乐开始播放后才可调用此接口
livePusher.pauseBGM();
/// 恢复播放背景音乐，背景音乐暂停状态下才可调用此接口
livePusher.resumeBGM();
/// 开启循环播放音乐
livePusher.setBGMLoop(true);
/// 设置降噪开关。打开降噪后，将对采集到的声音中非人声的部分进行过滤处理。可能存在对人声稍微抑制作用，建议让用户自由选择是否开启降噪功能，默认不使用
livePusher.setAudioDenoise(true);
/// 设置耳返开关。耳返功能主要应用于KTV场景。打开耳返后，插入耳机将在耳机中听到主播说话声音。关闭后，插入耳机无法听到人声。未插入耳机的情况下，耳返不起作用
livePusher.setBGMEarsBack(true);
/// 混音设置，设置背景音乐音量
livePusher.setBGMVolume(50); // 设置数值范围:[0 ~ 100]，默认:50
/// 混音设置，设置人声采集音量
livePusher.setCaptureVolume(50); // 设置数值范围:[0 ~ 100] 默认:50
/// 设置静音。静音后音乐声音和人声输入都会静音。要单独设置音乐或人声静音可以通过混音音量设置接口来调整
livePusher.setMute(true);
```

#### **1.5. 设置推流截图**
```dart
/// 调用截图
String dir = "xxxx"; // xxxx代表设置路径
if (Platform.isIOS) {
    /// dir设置要求：iOS系统下是指定存放相对的路径，会在系统沙盒路径下自动生成自定义的目录，设置为""时，则保存在系统沙盒路径下。
    /// dirTypeForIOS：可选设置。不设置默认是放在系统沙盒的[document]路径下。
    livePusher.snapshot(1, 0, dir, dirTypeForIOS: AlivcLiveSnapshotDirType.document);
} else {
    livePusher.snapshot(1, 0, dir);
}
/// 设置截图回调，需要在调用[snapshot]后调用
livePusher.setSnapshotDelegate();
```

#### **1.6. 摄像头相关操作**
```dart
/// 切换前后摄像头
livePusher.switchCamera();
/// 开启/关闭闪光灯，在前置摄像头时开启闪关灯无效
livePusher.setFlash(false);

/// 焦距调整，即可实现采集画面的缩放功能。传入参数为正数，则放大焦距，传入参数为负数则缩小焦距
double max = await livePusher.getMaxZoom();
livePusher.setZoom(min(1.0, max));

/// 手动对焦
/// [autoFocus]参数表示是否需要自动对焦，该参数仅对调用接口的该次对焦操作生效。后续是否自动对焦沿用上述自动聚焦接口设置值。
double pointX = 50.0; // 自定义
double pointY = 50.0; // 自定义
bool autoFocus = true;
livePusher.focusCameraAtAdjustedPoint(pointX, pointY, autoFocus);

/// 设置不打开自动对焦
livePusher.setAutoFocus(false);
/// 设置不打开预览镜像
livePusher.setPreviewMirror(false);
/// 设置不打开推流镜像
livePusher.setPushMirror(false);
```

### **2. 添加美颜**

Flutter 推流 SDK 提供插件化的美颜处理能力。如需使用美颜功能，请在 [SDK下载](https://help.aliyun.com/zh/live/developer-reference/sdk-download-and-release-notes) 中，下载源码压缩包，找到demo目录下plugins里面的`flutter_livepush_beauty_plugin` 插件，配合使用。**注意：美颜插件不单独发布。**

```dart
/// 1.初始化美颜对象
AlivcLiveBeautyManager beautyManager = AlivcLiveBeautyManager.init();
beautyManager.setupBeauty();
/// 2.打开美颜面板
beautyManager.showPanel();
/// 3.关闭美颜面板（安卓使用)
beautyManager.hidePanel();
/// 4.销毁美颜对象
beautyManager.destroyBeauty();
```

### **3. 注意事项**

- **API 对齐**：Flutter Plugin 的 Dart API 基于 Native SDK 的 API 封装实现，接口功能与 Native SDK 保持一致。
- **扩展支持**：如果 Flutter Plugin 的 Dart API 中未暴露您需要的 Native SDK 功能，目前我们已将源码提供出来，开发者可以自行添加，也可以通知给我们，我们会对遗漏的接口进行补充。

> **资源下载**：
>
> - **Plugin & Demo 下载包**：[SDK下载](https://help.aliyun.com/zh/live/developer-reference/sdk-download-and-release-notes)
> - **Demo 编译指南**：[Flutter 推流 Demo 编译](https://help.aliyun.com/zh/live/developer-reference/push-sdk-for-flutter-demo-compilation)

##  **六、直播播放接入指南**

如果您希望以高效的方式快速搭建直播间并实现视频播放功能，推荐使用 **[aliplayer_widget](https://pub.dev/packages/aliplayer_widget)**。

该方案基于 **[flutter_aliplayer](https://pub.dev/packages/flutter_aliplayer)** 构建，是一款**含 UI 集成**的 Flutter 播放组件，专为**快速接入与灵活定制**而设计。

在 `aliplayer_widget` 的示例工程中，已提供完整的直播播放功能示例。您可以通过参考示例代码，以低代码的方式快速完成集成，并实现直播间的核心播放功能。

> **⚠️ SDK 版本兼容说明**
>
> 当前 `flutter_livepush_plugin` 插件基于 **AliVCSDK_InteractiveLive（一体化 SDK）** 构建。
>
> 上述播放类 Flutter 插件（如 `aliplayer_widget`、`flutter_aliplayer`）默认基于 **播放器 SDK（独立 SDK）** 构建。在同一项目中同时集成推流与播放能力时，需特别注意 SDK 版本的兼容性。
>
> 为避免底层 SDK 冲突，建议播放插件使用对应的**一体化 SDK 版本**，版本示例如：`7.11.0-InteractiveLive`——避免混用一体化 SDK 与独立 SDK。
>
> 若 SDK 版本未正确匹配，可能导致**编译异常、运行时错误或功能不可用**。

## **七、文档指引**

* **Flutter 推流 SDK**
  * [官网文档](https://help.aliyun.com/zh/live/developer-reference/push-sdk-for-flutter)
  * [Pub 插件](https://pub.dev/packages/flutter_livepush_plugin)
* **Native SDK**
  * [推流 SDK](https://help.aliyun.com/zh/live/developer-reference/push-sdk)
  * [音视频终端 SDK](https://help.aliyun.com/zh/apsara-video-sdk/)
* **API DOC**
  * [Dart API DOC](https://pub.dev/documentation/flutter_livepush_plugin/latest/)
  * [Android API DOC](https://alivc-demo-cms.alicdn.com/versionProduct/doc/live_pusher/latest/Android/cn/index.html)
  * [iOS API DOC](https://alivc-demo-cms.alicdn.com/versionProduct/doc/live_pusher/latest/iOS/cn/index.html)
* **控制台**
  * [直播控制台](https://live.console.aliyun.com/)
  * [License控制台](https://live.console.aliyun.com/connect_microphone/demo#/sdks/license)

## **七、开发支持**

如果您在使用 Flutter 推流 SDK 有任何问题或建议，欢迎通过 [推流SDK异常自助排查](https://help.aliyun.com/zh/live/developer-reference/push-stream-sdk-exception-self-service-troubleshooting) 获取技术支持。
