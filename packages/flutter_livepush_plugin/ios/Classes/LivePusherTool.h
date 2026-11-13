//
//  LivePusherTool.h
//  livepush
//
//  Created by ISS013602000846 on 2023/3/15.
//

#import <UIKit/UIKit.h>
#import <Flutter/Flutter.h>

extern NSString * const LiveBaseMethodName;
extern NSString * const LiveBaseEventName;
extern NSString * const LivePusherMethodName;
extern NSString * const LivePusherEventName;
extern NSString * const LivePusherPreviewName;
extern NSString * const LivePusherConfigMethodName;
extern NSString * const LivePlayerMethodName;
extern NSString * const LivePlayerEventName;
extern NSString * const LivePlayerViewName;
extern NSString * const LivePlayerConfigMethodName;
extern NSString * const LiveTranscodingConfigMethodName;
extern NSString * const LiveBeautyMethodName;

extern NSString * const LivePusherEventChannelDefMethod;
extern NSString * const LivePusherEventChannelDefLicenceCheckResult;
extern NSString * const LivePusherEventChannelDefLicenceCheckReason;
extern NSString * const LivePusherEventChannelDefErrorCode;
extern NSString * const LivePusherEventChannelDefErrorDescription;
extern NSString * const LivePusherEventChannelDefBGMProgress;
extern NSString * const LivePusherEventChannelDefBGMDuration;
extern NSString * const LivePusherEventChannelDefSnapShotSaveResult;
extern NSString * const LivePusherEventChannelDefSnapShotSavePath;

extern NSString * const LivePlayerEventChannelDefMethod;
extern NSString * const LivePlayerEventChannelDefErrorCode;
extern NSString * const LivePlayerEventChannelDefErrorMessage;
extern NSString * const LivePlayerEventChannelDefUpQuality;
extern NSString * const LivePlayerEventChannelDefDownQuality;
extern NSString * const LivePlayerEventChannelDefPlayerId;

typedef NS_ENUM(NSInteger, LivePusherSaveDirType) {
    // NSDocumentDirectory
    LivePusherSaveDirTypeDocument = 0,
    // NSLibraryDirectory
    LivePusherSaveDirTypeLibrary,
    // NSCachesDirectory
    LivePusherSaveDirTypeCaches,
};

NS_ASSUME_NONNULL_BEGIN

@interface LivePusherTool : NSObject

+ (void)interfaceClass:(NSObject *)interfaceClass handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result;
+ (NSString *)saveDir:(LivePusherSaveDirType)dirType dir:(NSString *)dir;
+ (NSString *)getResourceSavePath:(LivePusherSaveDirType)dirType dir:(NSString *)dir;
+ (NSString *)randomString;
+ (NSString *)getCurrentDateString;
+ (UIImage *)getImageWithContent:(NSString *)imageName;
+ (UIViewController *)getTopViewController;

@end

NS_ASSUME_NONNULL_END
