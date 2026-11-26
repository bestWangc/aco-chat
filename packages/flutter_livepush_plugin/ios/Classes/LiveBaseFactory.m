//
//  LiveBaseFactory.m
//  flutter_livepush_plugin
//
//  Created by ISS013602000846 on 2023/4/10.
//

#import "LiveBaseFactory.h"
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

@interface LiveBaseFactory ()<FlutterStreamHandler, AlivcLiveBaseObserver>

@property (nonatomic, copy) FlutterEventSink eventSink;

@end

@implementation LiveBaseFactory

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:LiveBaseMethodName
                                     binaryMessenger:[registrar messenger]];
    LiveBaseFactory* instance = [[LiveBaseFactory alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName:LiveBaseEventName binaryMessenger:[registrar messenger]];
    [eventChannel setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    [LivePusherTool interfaceClass:self handleMethodCall:call result:result];
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

// 获取SDK版本号
- (void)getSdkVersion:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSString *sdkVersion = [AlivcLiveBase getSDKVersion];
    result(sdkVersion);
}

// 设置监听回调接口
- (void)setObserver:(NSArray *)arr {
    FlutterResult result = arr[1];
    [AlivcLiveBase setObserver:self];
    result(nil);
}

// 设置Log级别
- (void)setLogLevel:(NSArray *)arr {
    FlutterResult result = arr[1];
    AlivcLivePushLogLevel level = [arr[2] intValue];
    [AlivcLiveBase setLogLevel:level];
    result(nil);
}

// 启用或禁用控制台日志打印
- (void)setConsoleEnable:(NSArray *)arr {
    FlutterResult result = arr[1];
    bool enabled = [arr[2] boolValue];
    [AlivcLiveBase setConsoleEnable:enabled];
    result(nil);
}

// 设置Log路径
- (void)setLogPath:(NSArray *)arr {
    FlutterResult result = arr[1];
    NSDictionary *params = arr[2];
    NSString *logPath = params[@"logPath"];
    int maxPartFileSizeInKB = [params[@"maxPartFileSizeInKB"] intValue];
    [AlivcLiveBase setLogPath:logPath maxPartFileSizeInKB:maxPartFileSizeInKB];
    result(nil);
}

// 注册SDK
- (void)registerSDK:(NSArray *)arr {
    FlutterResult result = arr[1];
    
    BOOL success = NO;
    success = [AlivcLiveBase registerSDK];
    result(@(success));
}

#pragma mark -- AlivcLiveBaseObserver
// SDK Licence 校验接口回调
- (void)onLicenceCheck:(AlivcLiveLicenseCheckResultCode)result Reason:(NSString *)reason {
    NSString *resultCode = [NSString stringWithFormat:@"%ld", result];
    FlutterEventSink eventSink = self.eventSink;
    if (eventSink) {
        NSDictionary *event = @{
            LivePusherEventChannelDefMethod: @"onLicenceCheck",
            LivePusherEventChannelDefLicenceCheckResult: resultCode,
            LivePusherEventChannelDefLicenceCheckReason: reason ?: @"",
        };
        dispatch_async(dispatch_get_main_queue(), ^{
            eventSink(event);
        });
    }
}

@end
