//
//  LivePlayerFactory.m
//  flutter_livepushInteractive_plugin
//
//  Created by ISS013602000846 on 2023/4/28.
//

#import "LivePlayerFactory.h"
#import "LivePusherTool.h"
#import "LivePusherPreview.h"
#import "LivePlayerConfigFactory.h"

#if __has_include(<AliVCSDK_Standard/AliVCSDK_Standard.h>)
#import <AliVCSDK_Standard/AliVCSDK_Standard.h>
 
#elif __has_include(<AliVCSDK_InteractiveLive/AliVCSDK_InteractiveLive.h>)
#import <AliVCSDK_InteractiveLive/AliVCSDK_InteractiveLive.h>
 
#elif __has_include(<AliVCSDK_BasicLive/AliVCSDK_BasicLive.h>)
#import <AliVCSDK_BasicLive/AliVCSDK_BasicLive.h>
 
#elif __has_include(<AliVCSDK_UGC/AliVCSDK_UGC.h>)
#import <AliVCSDK_UGC/AliVCSDK_UGC.h>
 
#endif

@interface LivePlayerFactory ()<FlutterStreamHandler, FlutterPlatformViewFactory, AliLivePlayerDelegate>

@property (nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;
@property (nonatomic, strong) FlutterEventSink eventSink;
@property (nonatomic, strong) AlivcLivePlayer *livePlayer;
@property (nonatomic, strong) LivePusherPreview *livePlayerView;
@property (nonatomic, strong) LivePlayerConfigFactory *livePlayConfigFactory;

@end

@implementation LivePlayerFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if (self = [super init]) {
        _messenger = messenger;
        FlutterMethodChannel *commonChannel = [FlutterMethodChannel
                                         methodChannelWithName:LivePlayerMethodName
                                         binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [commonChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            __strong typeof(self) strongSelf = weakSelf;
            [LivePusherTool interfaceClass:strongSelf handleMethodCall:call result:result];
        }];
        
        FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:LivePlayerEventName binaryMessenger:messenger];
        [eventChannel setStreamHandler:self];
    }
    return self;
}

#pragma mark -- FlutterPlatformViewFactory
- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args {
    self.livePlayerView = [[LivePusherPreview alloc] initWithFrameArguments:args binaryMessenger:_messenger];
    return self.livePlayerView;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

#pragma mark - FlutterStreamHandler
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)eventSink{
    self.eventSink = eventSink;
    return nil;
}
 
- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    return nil;
}

// 初始化直播连麦播放引擎
- (void)initLivePlayer:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (!self.livePlayer) {
        self.livePlayer = [[AlivcLivePlayer alloc] init];
    }
    
    result(nil);
}

// 绑定直播连麦播放参数配置
- (void)bindPlayConfig:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    self.livePlayConfigFactory = [[LivePlayerConfigFactory alloc] initWithMessenger:_messenger];
    result(nil);
}

// 设置播放回调 {@link AliLivePlayerDelegate}
- (void)setLivePlayerDelegate:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePlayer) {
        [self.livePlayer setLivePlayerDelegate:self];
    }
    result(nil);
}

// 设置播放View
- (void)setPlayView:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    BOOL callback = NO;
    if (!self.livePlayer || !self.livePlayerView || !self.livePlayConfigFactory) {
        callback = NO;
    } else {
        callback = [self.livePlayer setPlayView:self.livePlayerView.view
                           playCofig:self.livePlayConfigFactory.config];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

// 开始播放音视频流
- (void)startPlayWithURL:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *url = arr[2];
    
    if (self.livePlayer) {
        [self.livePlayer startPlayWithURL:url];
    }
    result(nil);
}

// 停止播放音视频流
- (void)stopPlay:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePlayer) {
        [self.livePlayer stopPlay];
    }
    result(nil);
}

// 暂停播放音频流
- (void)pauseAudioPlaying:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePlayer) {
        [self.livePlayer pauseAudioPlaying];
    }
    result(nil);
}

// 恢复播放音频流
- (void)resumeAudioPlaying:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePlayer) {
        [self.livePlayer resumeAudioPlaying];
    }
    result(nil);
}

// 暂停播放视频流
- (void)pauseVideoPlaying:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePlayer) {
        [self.livePlayer pauseVideoPlaying];
    }
    result(nil);
}

// 恢复播放视频流
- (void)resumeVideoPlaying:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    if (self.livePlayer) {
        [self.livePlayer resumeVideoPlaying];
    }
    result(nil);
}

// 设置播放音量
- (void)setPlayoutVolume:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSInteger volume = [arr[2] integerValue];
    
    int callback = -1;
    if (self.livePlayer) {
        callback = [self.livePlayer setPlayoutVolume:volume];
    }
    result([NSString stringWithFormat:@"%d", callback]);
}

#pragma mark -- AliLivePlayerDelegate
// 播放错误回调
- (void)onError:(AlivcLivePlayer *)player code:(AlivcLivePlayerError)code message:(NSString *)msg {
    NSString *errorCode = [NSString stringWithFormat:@"%ld", code];
    self.eventSink(@{LivePlayerEventChannelDefMethod:@"onError", LivePlayerEventChannelDefErrorCode: errorCode, LivePlayerEventChannelDefErrorMessage: msg});
}

// 开始播放回调
- (void)onPlayStarted:(AlivcLivePlayer *)player {
    self.eventSink(@{LivePlayerEventChannelDefMethod:@"onPlayStarted"});
}

// 结束播放回调
- (void)onPlayStopped:(AlivcLivePlayer *)player {
    self.eventSink(@{LivePlayerEventChannelDefMethod:@"onPlayStopped"});
}

// 视频首帧渲染回调
- (void)onFirstVideoFrameDrawn:(AlivcLivePlayer*)player {
    self.eventSink(@{LivePlayerEventChannelDefMethod:@"onFirstVideoFrameDrawn"});
}

@end
