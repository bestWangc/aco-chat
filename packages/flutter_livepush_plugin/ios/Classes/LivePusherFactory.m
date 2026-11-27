//
//  LivePusherFactory.m
//  livepush
//
//  Created by ISS013602000846 on 2023/2/20.
//

#import "LivePusherFactory.h"
#import "LivePusherPreview.h"
#import "LivePusherEvent.h"
#import "LivePushConfigFactory.h"
#import "LivePusherTool.h"

#if __has_include(<AliVCSDK_Standard/AliVCSDK_Standard.h>)
#import <AliVCSDK_Standard/AliVCSDK_Standard.h>
 
#elif __has_include(<AliVCSDK_InteractiveLive/AliVCSDK_InteractiveLive.h>)
#import <AliVCSDK_InteractiveLive/AliVCSDK_InteractiveLive.h>
 
#elif __has_include(<AliVCSDK_BasicLive/AliVCSDK_BasicLive.h>)
#import <AliVCSDK_BasicLive/AliVCSDK_BasicLive.h>
 
#elif __has_include(<AliVCSDK_UGC/AliVCSDK_UGC.h>)
#import <AliVCSDK_UGC/AliVCSDK_UGC.h>
 
#endif

#if __has_include("LiveTranscodingConfigFactory.h")
#import "LiveTranscodingConfigFactory.h"
#define LIVETRANSCODINGFACTORY_ENABLE
#endif

#if __has_include("LiveBeautyFactory.h")
#import "LiveBeautyFactory.h"
#define LIVEBEAUTYFACTORY_ENABLE
#endif

@interface LivePusherFactory ()

@property (nonatomic, strong) FlutterMethodChannel *commonChannel;
@property (nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;
@property (nonatomic, strong) LivePushConfigFactory *configFactory;
@property (nonatomic, strong) AlivcLivePusher *livePusher;
@property (nonatomic, strong) FlutterEventSink eventSink;
@property (nonatomic, strong) LivePusherPreview *livePreview;
@property (nonatomic, strong) LivePusherEvent *event;
@property (nonatomic, strong) NSObject *transcodingConfigFactory;
@property (nonatomic, assign) BOOL beautyOn;
@property (nonatomic, strong) LiveBeautyFactory *beautyFactory;

@end

@implementation LivePusherFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if (self = [super init]) {
        _messenger = messenger;
        _commonChannel = [FlutterMethodChannel
                                         methodChannelWithName:LivePusherMethodName
                                         binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [_commonChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            __strong typeof(self) strongSelf = weakSelf;
            [LivePusherTool interfaceClass:strongSelf handleMethodCall:call result:result];
        }];
        
        FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:LivePusherEventName binaryMessenger:messenger];
        [eventChannel setStreamHandler:self];
    }
    return self;
}

#pragma mark - FlutterStreamHandler
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments eventSink:(FlutterEventSink)eventSink {
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    return nil;
}

#pragma mark -- FlutterPlatformViewFactory
- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args {
    self.livePreview = [[LivePusherPreview alloc] initWithFrameArguments:args binaryMessenger:_messenger];
    return self.livePreview;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (void)createConfig:(NSArray *)arr {
    FlutterResult result = arr[1];
    self.configFactory = [[LivePushConfigFactory alloc] initWithMessenger:_messenger];
    result(nil);
}

// 创建一个推流引擎实例
- (void)initLivePusher:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (!self.configFactory.config) {
        result(@(NO));
        return;
    }
    
    if (!self.livePusher) {
        self.livePusher = [[AlivcLivePusher alloc] initWithConfig:self.configFactory.config];
    }
    if (self.livePusher) {
        result(@(YES));
    } else {
        result(@(NO));
    }
}

// 设置推流错误监听回调
- (void)setErrorDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setErrorDelegate:self.event];
    }
    result(nil);
}

// 设置推流状态监听回调
- (void)setInfoDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setInfoDelegate:self.event];
    }
    result(nil);
}

// 设置推流网络监听回调
- (void)setNetworkDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setNetworkDelegate:self.event];
    }
    result(nil);
}

// 设置用户自定义滤镜回调
- (void)setCustomFilterDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setCustomFilterDelegate:self.event];
    }
    result(nil);
}

// 设置用户自定义人脸识别回调
- (void)setCustomDetectorDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setCustomDetectorDelegate:self.event];
    }
    result(nil);
}

// 设置背景音乐监听回调
- (void)setBGMDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setBGMDelegate:self.event];
    }
    result(nil);
}

// 设置音频裸数据回调
- (void)setAudioSampleDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self loadEvent];
        [self.livePusher setAudioSampleDelegate:self.event];
    }
    result(nil);
}

- (void)loadEvent {
    if (!self.event) {
        self.event = [[LivePusherEvent alloc] init];
        self.event.eventSink = self.eventSink;
    }
}

// 开始预览 同步接口
- (void)startPreview:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher && self.livePreview) {
        callback = [self.livePusher startPreview:self.livePreview.view];
    }
    result(@(callback));
}

// 开始预览 异步接口
- (void)startPreviewAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher && self.livePreview) {
        callback = [self.livePusher startPreviewAsync:self.livePreview.view];
    }
    result(@(callback));
}

// 开始推流 同步接口
- (void)startPushWithURL:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *pushURL = arr[2];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher startPushWithURL:pushURL];
    }
    result(@(callback));
}

// 开始推流 异步接口
- (void)startPushWithURLAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *pushURL = arr[2];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher startPushWithURLAsync:pushURL];
    }
    result(@(callback));
}

// 停止预览
- (void)stopPreview:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher stopPreview];
    }
    result(@(callback));
}

// 停止推流
- (void)stopPush:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher stopPush];
    }
    result(@(callback));
}

// 重新推流 同步接口
- (void)restartPush:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher restartPush];
    }
    result(@(callback));
}

// 重新推流 异步接口
- (void)restartPushAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher restartPushAsync];
    }
    result(@(callback));
}

// 暂停摄像头推流，如果pushCongfig 中设置了pauseImg图片，将推设置的静态图片
- (void)pause:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher pause];
    }
    result(@(callback));
}

// 恢复摄像头推流 同步接口
- (void)resume:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher resume];
    }
    result(@(callback));
}

// 恢复推流 异步接口
- (void)resumeAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher resumeAsync];
    }
    result(@(callback));
}

// 旋转摄像头
- (void)switchCamera:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher switchCamera];
    }
    result(@(callback));
}

// 重连 异步接口
- (void)reconnectPushAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher reconnectPushAsync];
    }
    result(@(callback));
}

// 重连 异步接口
- (void)reconnectPushAsyncWithPushURL:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *pushURL = arr[2];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher reconnectPushAsync:pushURL];
    }
    result(@(callback));
}

// 销毁推流
- (void)destroy:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePusher) {
        [self.livePusher destory];
        _livePusher = nil;
    }
    result(nil);
}

// 开始屏幕分享（该接口支持 iOS 11.0 及以上的 iPhone 和 iPad）。
- (void)startScreenCapture:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *appGroup = arr[2];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher startScreenCapture:appGroup];
        NSLog(@"[AcoScreenBroadcast] startScreenCapture appGroup=%@ mode=%ld result=%d",
              appGroup, (long)self.configFactory.config.livePushMode, callback);
    } else {
        NSLog(@"[AcoScreenBroadcast] startScreenCapture failed: pusher is not initialized");
    }
    result(@(callback));
}

// 设置自动对焦
- (void)setAutoFocus:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool autoFocus = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setAutoFocus:autoFocus];
    }
    result(@(callback));
}

// 对焦
- (void)focusCameraAtAdjustedPoint:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *content = arr[2];
    NSDictionary *point = content[@"point"];
    CGFloat pointX = [point[@"x"] floatValue];
    CGFloat pointY = [point[@"y"] floatValue];
    bool autoFocus = [content[@"autoFocus"] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher focusCameraAtAdjustedPoint:CGPointMake(pointX, pointY) autoFocus:autoFocus];
    }
    result(@(callback));
}

// 缩放
- (void)setZoom:(NSArray *)arr {
    FlutterResult result = arr[1];
    float zoom = [arr[2] floatValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setZoom:zoom];
    }
    result(@(callback));
}

// 获取支持的最大变焦值
- (void)getMaxZoom:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    float maxZoom = -1;
    if (self.livePusher) {
        maxZoom = [self.livePusher getMaxZoom];
    }
    result(@(maxZoom));
}

// 获取当前变焦值
- (void)getCurrentZoom:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    float currentZoom = -1;
    if (self.livePusher) {
        currentZoom = [self.livePusher getCurrentZoom];
    }
    result(@(currentZoom));
}

// 闪光灯开关
- (void)setFlash:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool flash = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setFlash:flash];
    }
    result(@(callback));
}

// 设置曝光度
- (void)setExposure:(NSArray *)arr {
    FlutterResult result = arr[1];
    float exposure = [arr[2] floatValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setExposure:exposure];
    }
    result(@(callback));
}

// 获取当前曝光度
- (void)getCurrentExposure:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    float currentExposure = -1;
    if (self.livePusher) {
        currentExposure = [self.livePusher getCurrentExposure];
    }
    result(@(currentExposure));
}

// 获取支持最小曝光度
- (void)getSupportedMinExposure:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    float supportedMinExposure = -1;
    if (self.livePusher) {
        supportedMinExposure = [self.livePusher getSupportedMinExposure];
    }
    result(@(supportedMinExposure));
}

// 获取支持最大曝光度
- (void)getSupportedMaxExposure:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    float supportedMaxExposure = -1;
    if (self.livePusher) {
        supportedMaxExposure = [self.livePusher getSupportedMaxExposure];
    }
    result(@(supportedMaxExposure));
}

// 推流镜像开关
- (void)setPushMirror_push:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool mirror = [arr[2] boolValue];
    
    if (self.livePusher) {
        [self.livePusher setPushMirror:mirror];
    }
    result(nil);
}

// 预览镜像开关
- (void)setPreviewMirror_push:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool mirror = [arr[2] boolValue];
    
    if (self.livePusher) {
        [self.livePusher setPreviewMirror:mirror];
    }
    result(nil);
}

// 静音推流
- (void)setMute:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool mute = [arr[2] boolValue];
    
    if (self.livePusher) {
        [self.livePusher setMute:mute];
    }
    result(nil);
}

// 设置推流模式
- (void)setQualityMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int qualityMode = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setQualityMode:qualityMode];
    }
    result(@(callback));
}

// 设置目标码率
- (void)setTargetVideoBitrate_push:(NSArray *)arr {
    FlutterResult result = arr[1];
    int targetBitrate = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setTargetVideoBitrate:targetBitrate];
    }
    result(@(callback));
}

// 设置最小码率
- (void)setMinVideoBitrate_push:(NSArray *)arr {
    FlutterResult result = arr[1];
    int minBitrate = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setMinVideoBitrate:minBitrate];
    }
    result(@(callback));
}

// 设置预览显示模式
- (void)setPreviewDisplayMode_push:(NSArray *)arr {
    FlutterResult result = arr[1];
    int displayMode = [arr[2] intValue];
    
    if (self.livePusher) {
        [self.livePusher setpreviewDisplayMode:displayMode];
    }
    result(nil);
}

// 设置推流分辨率，只在预览模式下生效，推流中不能设置
- (void)setResolution:(NSArray *)arr {
    FlutterResult result = arr[1];
    int resolution = [arr[2] intValue];
    
    if (self.livePusher) {
        [self.livePusher setResolution:resolution];
    }
    result(nil);
}

// 播放背景音乐
- (void)startBGMWithMusicPathAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *path = arr[2];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher startBGMWithMusicPathAsync:path];
    }
    result(@(callback));
}

// 停止播放背景音乐
- (void)stopBGMAsync:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher stopBGMAsync];
    }
    result(@(callback));
}

// 暂停播放背景音乐
- (void)pauseBGM:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher pauseBGM];
    }
    result(@(callback));
}

// 恢复播放背景音乐
- (void)resumeBGM:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher resumeBGM];
    }
    result(@(callback));
}

// 设置背景音乐是否循环播放
- (void)setBGMLoop:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool isLoop = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setBGMLoop:isLoop];
    }
    result(@(callback));
}

// 设置背景音乐耳返开关
- (void)setBGMEarsBack:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool isOpen = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setBGMEarsBack:isOpen];
    }
    result(@(callback));
}

// 设置降噪开关
- (void)setAudioDenoise:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool isOpen = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setAudioDenoise:isOpen];
    }
    result(@(callback));
}

// 开启智能降噪
- (void)startIntelligentDenoise:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher startIntelligentDenoise];
    }
    result(@(callback));
}

// 关闭智能降噪
- (void)stopIntelligentDenoise:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher stopIntelligentDenoise];
    }
    result(@(callback));
}

// 设置变声音效模式
- (void)setAudioEffectVoiceChangeMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int mode = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setAudioEffectVoiceChangeMode:mode];
    }
    result(@(callback));
}

// 设置混响音效模式
- (void)setAudioEffectReverbMode:(NSArray *)arr {
    FlutterResult result = arr[1];
    int mode = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setAudioEffectReverbMode:mode];
    }
    result(@(callback));
}

// 设置背景音乐混音 音乐音量
- (void)setBGMVolume:(NSArray *)arr {
    FlutterResult result = arr[1];
    int volume = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setBGMVolume:volume];
    }
    result(@(callback));
}

// 设置背景音乐混音 人声音量
- (void)setCaptureVolume:(NSArray *)arr {
    FlutterResult result = arr[1];
    int volume = [arr[2] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher setCaptureVolume:volume];
    }
    result(@(callback));
}

// 设置Message
- (void)sendMessage:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    NSString *message = params[@"message"];
    int count = [params[@"count"] intValue];
    int time = [params[@"time"] intValue];
    int isKeyFrame = [params[@"isKeyFrame"] intValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher sendMessage:message repeatCount:count delayTime:time KeyFrameOnly:isKeyFrame];
    }
    result(@(callback));
}

// 获取是否正在推流
- (void)isPushing:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    bool callback = NO;
    if (self.livePusher) {
        callback = [self.livePusher isPushing];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

// 获取当前推流URL
- (void)getPushURL:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    NSString *callback = @"";
    if (self.livePusher) {
        callback = [self.livePusher getPushURL];
    }
    result(callback);
}

// 获取当前推流状态
- (void)getLiveStatus:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    NSInteger callback = 0;
    if (self.livePusher) {
        callback = [self.livePusher getLiveStatus];
    }
    result([NSString stringWithFormat:@"%ld", callback]);
}

// 添加水印 最多支持3个水印
- (void)addWatermark:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    NSString *path = params[@"path"];
    CGFloat coordX = [params[@"coordX"] floatValue];
    CGFloat coordY = [params[@"coordY"] floatValue];
    CGFloat width = [params[@"width"] floatValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher addWatermarkWithPath:path watermarkCoordX:coordX watermarkCoordY:coordY watermarkWidth:width];
    }
    result(@(callback));
}

// 设置水印显示和隐藏
- (void)setWatermarkVisible:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool visable = [arr[2] boolValue];
    
    if (self.livePusher) {
        [self.livePusher setWatermarkVisible:visable];
    }
    result(nil);
}

// 添加动态贴纸,最多支持添加5个贴纸
- (void)addDynamicWaterMarkImageData:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    NSString *path = params[@"path"];
    float x = [params[@"x"] floatValue];
    float y = [params[@"y"] floatValue];
    float w = [params[@"w"] floatValue];
    float h = [params[@"h"] floatValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher addDynamicWaterMarkImageDataWithPath:path x:x y:y w:w h:h];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

// 删除动态贴纸
- (void)removeDynamicWaterMark:(NSArray *)arr {
    FlutterResult result = arr[1];
    int vid = [arr[2] intValue];
    
    if (self.livePusher) {
        [self.livePusher removeDynamicWaterMark:vid];
    }
    result(nil);
}

// 截图
- (void)snapshot:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    int count = [params[@"count"] intValue];
    int interval = [params[@"interval"] intValue];
    NSDictionary *saveDir = params[@"saveDir"];
    
    if (self.livePusher) {
        [self.livePusher snapshot:count interval:interval];
        self.event.snapshotSaveDir = saveDir;
    }
    result(nil);
}

// 设置截图回调
- (void)setSnapshotDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    [self.livePusher setSnapshotDelegate:self.event];
    result(nil);
}

// 发送自定义视频数据
- (void)sendVideoData:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    FlutterStandardTypedData *data = params[@"data"];
    NSData *bytes = data.data;
    char *data_char = (char *)[bytes bytes];
    
    int width = [params[@"width"] intValue];
    int height = [params[@"height"] intValue];
    int size = [params[@"size"] intValue];
    
    NSString *ptsStr = params[@"pts"];
    long long pts = [ptsStr longLongValue];
    
    int rotation = [params[@"rotation"] intValue];
    
    if (self.livePusher) {
        [self.livePusher sendVideoData:data_char width:width height:height size:size pts:pts rotation:rotation];
    }
    
    result(nil);
}

// 发送自定义音频数据
- (void)sendPCMData:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    FlutterStandardTypedData *data = params[@"data"];
    NSData *bytes = data.data;
    char *data_char = (char *)[bytes bytes];
    
    int size = [params[@"size"] intValue];
    int sampleRate = [params[@"sampleRate"] intValue];
    int channel = [params[@"channel"] intValue];
    
    NSString *ptsStr = params[@"pts"];
    long long pts = [ptsStr longLongValue];
    
    if (self.livePusher) {
        [self.livePusher sendPCMData:data_char size:size sampleRate:sampleRate channel:channel pts:pts];
    }
    
    result(nil);
}

// 绑定云端的混流（转码）参数
- (void)bindLiveMixTranscodingConfig:(NSArray *)arr {
    FlutterResult result = arr[1];
#ifdef LIVETRANSCODINGFACTORY_ENABLE
    self.transcodingConfigFactory = [[LiveTranscodingConfigFactory alloc] initWithMessenger:_messenger];
#else
    NSLog(@"You want to call [bindLiveMixTranscodingConfig] method, must dependent on [AliVCSDK_InteractiveLive] SDK!");
#endif
    result(nil);
}

// 设置云端的混流（转码）参数
- (void)setLiveMixTranscodingConfig:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool isNeed = [arr[2] boolValue];
    
    int callback = -1;
#ifdef LIVETRANSCODINGFACTORY_ENABLE
    if (self.livePusher &&
        (self.transcodingConfigFactory && [self.transcodingConfigFactory isKindOfClass:[LiveTranscodingConfigFactory class]])) {
        if (isNeed) {
            callback = [self.livePusher setLiveMixTranscodingConfig:((LiveTranscodingConfigFactory *)self.transcodingConfigFactory).config];
        } else {
            callback = [self.livePusher setLiveMixTranscodingConfig:nil];
        }
    }
#else
    NSLog(@"You want to call [setLiveMixTranscodingConfig] method, must dependent on [AliVCSDK_InteractiveLive] SDK!");
#endif
    result([NSString stringWithFormat:@"%d", callback]);
}

// 关闭/打开视频
- (void)muteLocalCamera:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool mute = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        callback = [self.livePusher muteLocalCamera:mute];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

// 设置音频输出为听筒还是扬声器
- (void)enableSpeakerphone:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool enable = [arr[2] boolValue];
    
    int callback = -1;
    if (self.livePusher) {
        [self.livePusher enableSpeakerphone:enable];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

// 获取当前音频输出为听筒还是扬声器
- (void)isEnableSpeakerphone:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    bool callback = true;
    if (self.livePusher) {
        callback = [self.livePusher isEnableSpeakerphone];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

// 使用美颜
- (void)useBeauty:(NSArray *)arr {
    FlutterResult result = arr[1];
    
#ifdef LIVEBEAUTYFACTORY_ENABLE
    self.beautyFactory = [[LiveBeautyFactory alloc] initWithMessenger:self.messenger];
    self.beautyFactory.beautyOn = YES;
    self.beautyFactory.beautySuperView = [LivePusherTool getTopViewController].view.window;
    self.beautyFactory.pushConfig = self.configFactory.config;
    self.event.beautyFactory = self.beautyFactory;
#else
    NSLog(@"You want to call [useBeauty] method, must dependent on [flutter_livepush_beauty_plugin]!");
    
#endif
    result(nil);
}

@end
