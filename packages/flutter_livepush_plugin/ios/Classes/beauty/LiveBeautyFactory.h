//
//  LiveBeautyFactory.h
//  flutter_aliplayer
//
//  Created by ISS013602000846 on 2023/6/15.
//

#import <Flutter/Flutter.h>

#if __has_include(<AliVCSDK_Standard/AliVCSDK_Standard.h>)
#import <AliVCSDK_Standard/AliVCSDK_Standard.h>
 
#elif __has_include(<AliVCSDK_InteractiveLive/AliVCSDK_InteractiveLive.h>)
#import <AliVCSDK_InteractiveLive/AliVCSDK_InteractiveLive.h>
 
#elif __has_include(<AliVCSDK_BasicLive/AliVCSDK_BasicLive.h>)
#import <AliVCSDK_BasicLive/AliVCSDK_BasicLive.h>
 
#elif __has_include(<AliVCSDK_UGC/AliVCSDK_UGC.h>)
#import <AliVCSDK_UGC/AliVCSDK_UGC.h>
 
#endif

NS_ASSUME_NONNULL_BEGIN

@interface LiveBeautyFactory : NSObject

@property (nonatomic, assign) BOOL beautyOn;
@property (nonatomic, strong) AlivcLivePushConfig *pushConfig;
@property (nonatomic, strong) UIView *beautySuperView;

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

// 开始预览回调
- (void)onPreviewStarted:(AlivcLivePusher *)pusher;
// 停止预览回调
- (void)onPreviewStoped:(AlivcLivePusher *)pusher;
// 通知外置滤镜创建回调
- (void)onCreate:(AlivcLivePusher*)pusher context:(void*)context;
// 通知外置滤镜处理回调
- (int)onProcess:(AlivcLivePusher *)pusher texture:(int)texture textureWidth:(int)width textureHeight:(int)height extra:(long)extra;
// 通知外置滤镜销毁回调
- (void)onDestory:(AlivcLivePusher*)pusher;
- (BOOL)onProcessVideoSampleBuffer:(AlivcLivePusher *)pusher sampleBuffer:(AlivcLiveVideoDataSample *)sampleBuffer;
// 通知外置视频检测创建回调
- (void)onCreateDetector:(AlivcLivePusher *)pusher;
// 通知外置视频检测处理回调
- (void)onDetectorProcess:(AlivcLivePusher*)pusher data:(long)data w:(int)w h:(int)h rotation:(int)rotation format:(int)format extra:(long)extra;
// 通知外置视频检测销毁回调
- (void)onDestoryDetector:(AlivcLivePusher *)pusher;

@end

NS_ASSUME_NONNULL_END
