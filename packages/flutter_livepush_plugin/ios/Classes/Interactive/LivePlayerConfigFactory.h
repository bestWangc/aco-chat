//
//  LivePlayerConfigFactory.h
//  flutter_livepushInteractive_plugin
//
//  Created by ISS013602000846 on 2023/4/28.
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

@interface LivePlayerConfigFactory : NSObject

@property (nonatomic, strong) AlivcLivePlayConfig *config;

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
