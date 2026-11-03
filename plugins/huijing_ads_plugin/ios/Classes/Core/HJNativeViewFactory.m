//
//  HJNativeViewFactory.m
//  huijing_ads_plugin
//
//  Created by 胡兵 on 2024/6/8.
//

#import "HJNativeViewFactory.h"
#import "HJNativeAdViewPlugin.h"


@interface HJNativeViewFactory ()
@end

@implementation HJNativeViewFactory

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(NSDictionary *)args {
    NSLog(@"createWithFrame - %@", NSStringFromCGRect(frame));
    NSLog(@"createWithViewId - %lld", viewId);
    NSLog(@"createWithArgs - %@", args);
    
    return [[HJNativeAdViewPlugin alloc] initWithFrame:frame arguments:args];

 
    return nil;
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    self = [super init];
    if (self) {
        _messenger = messenger;
    }
    return self;
}

@end
