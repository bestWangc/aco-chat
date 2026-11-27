//
//  LivePusherEvent.h
//  livepush
//
//  Created by ISS013602000846 on 2023/2/20.
//

#import <Flutter/Flutter.h>
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

NS_ASSUME_NONNULL_BEGIN

@interface LivePusherEvent : NSObject<AlivcLivePusherErrorDelegate, AlivcLivePusherInfoDelegate, AlivcLivePusherNetworkDelegate, AlivcLivePusherCustomFilterDelegate, AlivcLivePusherCustomDetectorDelegate, AlivcLivePusherBGMDelegate, AlivcLivePusherAudioSampleDelegate, AlivcLivePusherSnapshotDelegate>

@property (nonatomic, copy) FlutterEventSink eventSink;

// snapshot
@property (nonatomic, copy) NSDictionary *snapshotSaveDir;

@property (nonatomic, strong) NSObject *beautyFactory;


@end

NS_ASSUME_NONNULL_END
