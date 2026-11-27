//
//  LivePusherEvent.m
//  livepush
//
//  Created by ISS013602000846 on 2023/2/20.
//

#import "LivePusherEvent.h"

#if __has_include("LiveBeautyFactory.h")
#import "LiveBeautyFactory.h"
#define LIVEBEAUTYFACTORY_ENABLE
#endif

@interface LivePusherEvent ()

@end

@implementation LivePusherEvent

#pragma mark -- AlivcLivePusherErrorDelegate
// SDK错误回调
- (void)onSDKError:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    NSString *errorCode = [NSString stringWithFormat:@"%ld", error.errorCode];
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onSDKError", LivePusherEventChannelDefErrorCode:errorCode, LivePusherEventChannelDefErrorDescription: error.errorDescription});
}

// 系统错误回调
- (void)onSystemError:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    NSString *errorCode = [NSString stringWithFormat:@"%ld", error.errorCode];
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onSystemError", LivePusherEventChannelDefErrorCode:errorCode, LivePusherEventChannelDefErrorDescription: error.errorDescription});
}

#pragma mark -- AlivcLivePusherInfoDelegate
// 开始预览回调
- (void)onPreviewStarted:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPreviewStarted"});
    
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onPreviewStarted:pusher];
    }
#endif
}

// 停止预览回调
- (void)onPreviewStoped:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPreviewStoped"});

#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onPreviewStoped:pusher];
    }
#endif
}

// 渲染第一帧回调
- (void)onFirstFramePreviewed:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onFirstFramePreviewed"});
}

// 推流开始回调
- (void)onPushStarted:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPushStarted"});
}

// 摄像头推流暂停回调
- (void)onPushPaused:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPushPaused"});
}

// 摄像头推流恢复回调
- (void)onPushResumed:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPushResumed"});
}

// 重新推流回调
- (void)onPushRestart:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPushRestart"});
}

// 推流停止回调
- (void)onPushStoped:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onPushStoped"});
}

- (void)onPushStatistics:(AlivcLivePusher *)pusher statsInfo:(AlivcLivePushStatsInfo*)statistics {
    
}

#pragma mark -- AlivcLivePusherNetworkDelegate
// 推流链接失败
- (void)onConnectFail:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    NSString *errorCode = [NSString stringWithFormat:@"%ld", error.errorCode];
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onConnectFail", LivePusherEventChannelDefErrorCode:errorCode, LivePusherEventChannelDefErrorDescription: error.errorDescription});
}

// 网络恢复
- (void)onConnectRecovery:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onConnectRecovery"});
}

// 连接被断开
- (void)onConnectionLost:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onConnectionLost"});
}

// 网络差回调
- (void)onNetworkPoor:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onNetworkPoor"});
}

// 重连失败回调
- (void)onReconnectError:(AlivcLivePusher *)pusher error:(AlivcLivePushError *)error {
    NSString *errorCode = [NSString stringWithFormat:@"%ld", error.errorCode];
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onReconnectError", LivePusherEventChannelDefErrorCode:errorCode, LivePusherEventChannelDefErrorDescription: error.errorDescription});
}

// 重连开始回调
- (void)onReconnectStart:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onReconnectStart"});
}

// 重连成功回调
- (void)onReconnectSuccess:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onReconnectSuccess"});
}

// 发送数据超时
- (void)onSendDataTimeout:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onSendDataTimeout"});
}

// 发送SEI Message 通知
- (void)onSendSeiMessage:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onSendSeiMessage"});
}

#pragma mark -- AlivcLivePusherCustomFilterDelegate
// 通知外置滤镜创建回调
- (void)onCreate:(AlivcLivePusher*)pusher context:(void*)context {
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onCreate:pusher context:context];
    }
#endif
}

// 通知外置滤镜处理回调
- (int)onProcess:(AlivcLivePusher *)pusher texture:(int)texture textureWidth:(int)width textureHeight:(int)height extra:(long)extra {
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        return [(LiveBeautyFactory *)self.beautyFactory onProcess:pusher texture:texture textureWidth:width textureHeight:height extra:extra];
    }
#endif
    return texture;
}

// 通知外置滤镜销毁回调
- (void)onDestory:(AlivcLivePusher*)pusher {
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onDestory:pusher];
    }
#endif
}

- (BOOL)onProcessVideoSampleBuffer:(AlivcLivePusher *)pusher sampleBuffer:(AlivcLiveVideoDataSample *)sampleBuffer
{
    BOOL result = NO;
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        result = [(LiveBeautyFactory *)self.beautyFactory onProcessVideoSampleBuffer:pusher sampleBuffer:sampleBuffer];
    }
#endif
    return result;
}

#pragma mark - AlivcLivePusherCustomDetectorDelegate
// 通知外置视频检测创建回调
- (void)onCreateDetector:(AlivcLivePusher *)pusher {
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onCreateDetector:pusher];
    }
#endif
}

// 通知外置视频检测处理回调
- (long)onDetectorProcess:(AlivcLivePusher*)pusher data:(long)data w:(int)w h:(int)h rotation:(int)rotation format:(int)format extra:(long)extra {
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onDetectorProcess:pusher data:data w:w h:h rotation:rotation format:format extra:extra];
    }
#endif
    return data;
}

/**
 通知外置视频检测销毁回调
 */
- (void)onDestoryDetector:(AlivcLivePusher *)pusher {
#ifdef LIVEBEAUTYFACTORY_ENABLE
    if (self.beautyFactory && [self.beautyFactory isKindOfClass:[LiveBeautyFactory class]]) {
        [(LiveBeautyFactory *)self.beautyFactory onDestoryDetector:pusher];
    }
#endif
}

#pragma mark -- AlivcLivePusherBGMDelegate
// 背景音乐播放完毕
- (void)onCompleted:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMCompleted"});
}

// 背景音乐下载播放超时
- (void)onDownloadTimeout:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMDownloadTimeout"});
}

// 背景音乐开启失败
- (void)onOpenFailed:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMOpenFailed"});
}

// 背景音乐暂停播放
- (void)onPaused:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMPaused"});
}

// 背景音乐当前播放进度
- (void)onProgress:(AlivcLivePusher *)pusher progress:(long)progress duration:(long)duration {
    NSString *progressStr = [NSString stringWithFormat:@"%ld", progress];
    NSString *durationStr = [NSString stringWithFormat:@"%ld", duration];
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMProgress", LivePusherEventChannelDefBGMProgress:progressStr, LivePusherEventChannelDefBGMDuration:durationStr});
}

// 背景音乐恢复播放
- (void)onResumed:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMResumed"});
}

// 背景音乐开始播放
- (void)onStarted:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMStarted"});
}

// 背景音乐停止播放
- (void)onStoped:(AlivcLivePusher *)pusher {
    self.eventSink(@{LivePusherEventChannelDefMethod:@"onBGMStoped"});
}

#pragma mark -- AlivcLivePusherSnapshotDelegate
// 截图回调
- (void)onSnapshot:(AlivcLivePusher *)pusher image:(UIImage *)image {
    LivePusherSaveDirType dirType = [self.snapshotSaveDir[@"dirType"] intValue];
    NSString *dir = self.snapshotSaveDir[@"dir"];
    NSString *saveFullPath = [LivePusherTool saveDir:dirType dir:dir];
    NSString *callbackSavePath = dir;
    BOOL saveResult = NO;
    if (image && saveFullPath && saveFullPath.length > 0) {
        if (UIImagePNGRepresentation(image) == nil){
            
            NSString *fileName = [NSString stringWithFormat:@"snapshot-%@.jpg", [LivePusherTool getCurrentDateString]];
            saveFullPath = [saveFullPath stringByAppendingPathComponent:fileName];
            callbackSavePath = [callbackSavePath stringByAppendingPathComponent:fileName];
            NSData *jpgData = UIImageJPEGRepresentation(image, 1);
            if (jpgData) {
                [jpgData writeToFile:saveFullPath atomically:YES];
                saveResult = YES;
            } else {
                saveResult = NO;
                saveFullPath = @"";
                callbackSavePath = @"";
            }
        } else {
            NSString *fileName = [NSString stringWithFormat:@"snapshot-%@.png", [LivePusherTool getCurrentDateString]];
            saveFullPath = [saveFullPath stringByAppendingPathComponent:fileName];
            callbackSavePath = [callbackSavePath stringByAppendingPathComponent:fileName];
            NSData *pngData = UIImagePNGRepresentation(image);
            if (pngData) {
                [pngData writeToFile:saveFullPath atomically:YES];
                saveResult = YES;
            } else {
                saveResult = NO;
                saveFullPath = @"";
                callbackSavePath = @"";
            }
        }
        
        NSDictionary *savePath = @{@"saveDirType":@(dirType), @"savePath":callbackSavePath};
        NSString *saveResultStr = [NSString stringWithFormat:@"%d", saveResult];
        self.eventSink(@{LivePusherEventChannelDefMethod:@"onSnapshot", LivePusherEventChannelDefSnapShotSaveResult:saveResultStr, LivePusherEventChannelDefSnapShotSavePath:savePath});
    }
}

@end
