//
//  LivePusherTool.m
//  livepush
//
//  Created by ISS013602000846 on 2023/3/15.
//

#import "LivePusherTool.h"

NSString * const LiveBaseMethodName = @"plugins.livebase.method";
NSString * const LiveBaseEventName = @"plugins.livebase.event";
NSString * const LivePusherMethodName = @"plugins.livepush.pusher.method";
NSString * const LivePusherEventName = @"plugins.livepush.pusher.event";
NSString * const LivePusherPreviewName = @"plugins.livepush.preview";
NSString * const LivePusherConfigMethodName = @"plugins.livepush.pushConfig.method";
NSString * const LivePlayerMethodName = @"plugins.liveplayer.method";
NSString * const LivePlayerEventName = @"plugins.liveplayer.event";
NSString * const LivePlayerViewName = @"plugins.liveplayer.view";
NSString * const LivePlayerConfigMethodName = @"plugins.liveplayerconfig.method";
NSString * const LiveTranscodingConfigMethodName = @"plugins.livetranscodingconfig.method";
NSString * const LiveBeautyMethodName = @"plugins.livebeauty.method";

NSString * const LivePusherEventChannelDefMethod = @"method";
NSString * const LivePusherEventChannelDefLicenceCheckResult = @"result";
NSString * const LivePusherEventChannelDefLicenceCheckReason = @"reason";
NSString * const LivePusherEventChannelDefErrorCode = @"errorCode";
NSString * const LivePusherEventChannelDefErrorDescription = @"errorDescription";
NSString * const LivePusherEventChannelDefBGMProgress = @"progress";
NSString * const LivePusherEventChannelDefBGMDuration = @"duration";
NSString * const LivePusherEventChannelDefSnapShotSaveResult = @"saveResult";
NSString * const LivePusherEventChannelDefSnapShotSavePath = @"savePath";

NSString * const LivePlayerEventChannelDefMethod = @"method";
NSString * const LivePlayerEventChannelDefErrorCode = @"errorCode";
NSString * const LivePlayerEventChannelDefErrorMessage = @"errorMessage";
NSString * const LivePlayerEventChannelDefUpQuality = @"upQuality";
NSString * const LivePlayerEventChannelDefDownQuality = @"downQuality";
NSString * const LivePlayerEventChannelDefPlayerId = @"playerId";

@implementation LivePusherTool

+ (void)interfaceClass:(NSObject *)interfaceClass handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSObject* obj = [call arguments];
    if ([obj isKindOfClass:NSDictionary.class]) {
        NSDictionary *dic = (NSDictionary*)obj;
        NSObject *arguments= [dic objectForKey:@"arg"];
        [self interfaceClass:interfaceClass onMethodCall:call result:result arg:arguments?:@""];
    }else{
        [self interfaceClass:interfaceClass onMethodCall:call result:result arg:@""];
    }
}

+ (void)interfaceClass:(NSObject *)interfaceClass onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result arg:(NSObject*)arg{
    NSString* method = [call method];
    SEL methodSel=NSSelectorFromString([NSString stringWithFormat:@"%@:",method]);
    NSArray *arr = @[call,result,arg];
    if([interfaceClass respondsToSelector:methodSel]){
        IMP imp = [interfaceClass methodForSelector:methodSel];
        void (*func)(id, SEL, NSArray*) = (void *)imp;
        func(interfaceClass, methodSel, arr);
    }else{
        result(FlutterMethodNotImplemented);
    }
}

+ (NSString *)saveDir:(LivePusherSaveDirType)dirType dir:(NSString *)dir {
    NSString *baseDirPath = @"";
    if (dirType == LivePusherSaveDirTypeDocument) {
        baseDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    } else if (dirType == LivePusherSaveDirTypeLibrary) {
        baseDirPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    } else {
        baseDirPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    }
    
    if (dir.length == 0) {
        return baseDirPath;
    }
    
    baseDirPath = [baseDirPath stringByAppendingPathComponent:dir];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDir;
    NSError *error;
    if (![manager fileExistsAtPath:baseDirPath isDirectory:&isDir]) {
        BOOL success = [manager createDirectoryAtPath:baseDirPath withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success || error) {
            baseDirPath = @"";
            NSLog(@"文件保存地址创建失败");
        }
    }
    return baseDirPath;
}

+ (NSString *)randomString {
    CFUUIDRef puuid = CFUUIDCreate(nil);
    CFStringRef uuidString = CFUUIDCreateString(nil, puuid);
    NSString * result = (NSString *)CFBridgingRelease(CFStringCreateCopy(nil, uuidString));
    CFRelease(puuid);
    CFRelease(uuidString);
    return result;
}

+ (NSString *)getCurrentDateString {
    NSDate *currentDate = [NSDate date];//获取当前时间，日期
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"YYYY-MM-dd-hh-mm-ss-SS"];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    return dateString;
}

+ (UIImage *)getImageWithContent:(NSString *)imagePath {
    UIImage *image = nil;
    if (imagePath && imagePath.length > 0) {
        image = [UIImage imageWithContentsOfFile:imagePath];
    }
    return image;
}

+ (NSString *)getResourceSavePath:(LivePusherSaveDirType)dirType dir:(NSString *)dir {
    NSString *dirPath = @"";
    if (dirType == LivePusherSaveDirTypeDocument) {
        dirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    } else if (dirType == LivePusherSaveDirTypeLibrary) {
        dirPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    } else {
        dirPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    }
    dirPath = [dirPath stringByAppendingPathComponent:dir];
    return dirPath;
}

+ (UIViewController *)getTopViewController {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (window.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = UIApplication.sharedApplication.windows;
        for (UIWindow *tmp in windows) {
            if (tmp.windowLevel == UIWindowLevelNormal) {
                window = tmp;
                break;
            }
        }
    }
    NSAssert(window.windowLevel == UIWindowLevelNormal, @"Can not found showing window");
    
    UIViewController *topViewController = window.rootViewController;
    while (topViewController) {
        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        } else if ([topViewController isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)topViewController;
            topViewController = nav.visibleViewController;
        } else if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)topViewController;
            topViewController = tab.selectedViewController;
        } else {
            return topViewController;
        }
    }
    return nil;
}

@end
