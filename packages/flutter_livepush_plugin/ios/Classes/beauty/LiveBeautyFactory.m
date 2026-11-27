//
//  LiveBeautyFactory.m
//  flutter_aliplayer
//
//  Created by ISS013602000846 on 2023/6/15.
//

#import "LiveBeautyFactory.h"
#import "LiveBeautyBgView.h"
#import "LivePusherTool.h"

#if __has_include("AlivcBeautyController.h")
#import "AlivcBeautyController.h"
#define LIVEBEAUTY_ENABLE
#endif

@interface LiveBeautyFactory ()

@property (nonatomic, strong) LiveBeautyBgView *bgView;

@end

@implementation LiveBeautyFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if (self = [super init]) {
        FlutterMethodChannel *commonChannel = [FlutterMethodChannel
                                         methodChannelWithName:LiveBeautyMethodName
                                         binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [commonChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            __strong typeof(self) strongSelf = weakSelf;
            [LivePusherTool interfaceClass:strongSelf handleMethodCall:call result:result];
        }];
    }
    return self;
}

#pragma mark -- flutter fuction
// 初始化美颜对象
- (void)setupBeauty:(NSArray *)arr {
    FlutterResult result = arr[1];
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn && self.beautySuperView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.bgView && self.bgView.superview) {
                [self.bgView removeFromSuperview];
            }
            
            self.bgView = [[LiveBeautyBgView alloc] initWithFrame:self.beautySuperView.bounds];
            self.bgView.userInteractionEnabled = YES;
            [self.beautySuperView addSubview:self.bgView];
            [[AlivcBeautyController sharedInstance] setupBeautyControllerUIWithView:self.bgView];
        });
    }
#else
    NSLog(@"You want to call [destroyBeauty] method, must dependent on [flutter_livepush_beauty_plugin]!");
#endif
    result(nil);
}

// 获取美颜SDK的版本
- (void)getQueenSDKVersion:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    NSString *callback = @"";
#ifdef LIVEBEAUTY_ENABLE
    callback = [AlivcBeautyController getQueenSDKVersion];
#else
    callback = @"";
    NSLog(@"You want to call [getQueenSDKVersion] method, must dependent on [flutter_livepush_beauty_plugin]!");
#endif
    result(callback);
}

// 打开美颜面板
- (void)showPanel:(NSArray *)arr {
    FlutterResult result = arr[1];
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn) {
        [[AlivcBeautyController sharedInstance] showPanel:YES];
    }
#else
    NSLog(@"You want to call [destroyBeauty] method, must dependent on [flutter_livepush_beauty_plugin]!");
#endif
    result(nil);
}

// 销毁释放美颜对象
- (void)destroyBeauty:(NSArray *)arr {
    FlutterResult result = arr[1];
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn) {
        [[AlivcBeautyController sharedInstance] destroyBeautyControllerUI];
    }
#else
    NSLog(@"You want to call [destroyBeauty] method, must dependent on [flutter_livepush_beauty_plugin]!");
#endif
    result(nil);
}

#pragma mark -- Live Pusher Delegate
// 开始预览回调
- (void)onPreviewStarted:(AlivcLivePusher *)pusher {
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn && !self.pushConfig.audioOnly) {
        BOOL processPixelBuffer = self.pushConfig.livePushMode ==  AlivcLivePushInteractiveMode;
        [[AlivcBeautyController sharedInstance] setupBeautyController:processPixelBuffer];
    }
#endif
}

// 停止预览回调
- (void)onPreviewStoped:(AlivcLivePusher *)pusher {
#ifdef LIVEBEAUTY_ENABLE
    BOOL isInteractiveMode = self.pushConfig.livePushMode ==  AlivcLivePushInteractiveMode;;
    if (self.beautyOn && !self.pushConfig.audioOnly && isInteractiveMode)
    {
        [[AlivcBeautyController sharedInstance] destroyBeautyController];
    }
#endif
}

// 通知外置滤镜创建回调
- (void)onCreate:(AlivcLivePusher*)pusher context:(void*)context {
    
}

// 通知外置滤镜处理回调
- (int)onProcess:(AlivcLivePusher *)pusher texture:(int)texture textureWidth:(int)width textureHeight:(int)height extra:(long)extra {
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn) {
        return [[AlivcBeautyController sharedInstance] processGLTextureWithTextureID:texture withWidth:width withHeight:height];
    }
#endif
    return texture;
}

// 通知外置滤镜销毁回调
- (void)onDestory:(AlivcLivePusher*)pusher {
#ifdef LIVEBEAUTY_ENABLE
    [[AlivcBeautyController sharedInstance] destroyBeautyController];
#endif
}

- (BOOL)onProcessVideoSampleBuffer:(AlivcLivePusher *)pusher sampleBuffer:(AlivcLiveVideoDataSample *)sampleBuffer {
    BOOL result = NO;
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn) {
        result = [[AlivcBeautyController sharedInstance] processPixelBuffer:sampleBuffer.pixelBuffer withPushOrientation:(AliLiveBeautyOrientation)self.pushConfig.orientation];
    }
#endif
    return result;
}

// 通知外置视频检测创建回调
- (void)onCreateDetector:(AlivcLivePusher *)pusher {
    
}

// 通知外置视频检测处理回调
- (void)onDetectorProcess:(AlivcLivePusher*)pusher data:(long)data w:(int)w h:(int)h rotation:(int)rotation format:(int)format extra:(long)extra {
#ifdef LIVEBEAUTY_ENABLE
    if (self.beautyOn) {
        [[AlivcBeautyController sharedInstance] detectVideoBuffer:data
                                                        withWidth:w
                                                       withHeight:h
                                                  withVideoFormat:(AliLiveBeautyVideoFormat)self.pushConfig.externVideoFormat
                                              withPushOrientation:(AliLiveBeautyOrientation)self.pushConfig.orientation];
    }
#endif
}

// 通知外置视频检测销毁回调
- (void)onDestoryDetector:(AlivcLivePusher *)pusher {
    
}

@end
