//
//  HJNativeAdViewPlugin.m
//  huijing_ads_plugin
//
//  Created by 胡兵 on 2024/6/8.
//

#import "HJNativeAdPlugin.h"
#import "HJNativeAdViewPlugin.h"
#import "HuijingAdsPlugin.h"
#import "HJUtil.h"
#import "HjPluginContant.h"
#import <HJOpenAdSDK/HJAdsOpen.h>


@interface HJNativeAdViewPlugin ()
@property (nonatomic, strong) UIView *contentView;
@end

@implementation HJNativeAdViewPlugin

- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(NSDictionary *)args{
    self = [super init];
    if (self) {

        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = UIColor.clearColor;
        _contentView.clipsToBounds = YES;
        
        NSString *uniqId = [args objectForKey:@"uniqId"];
        NSDictionary *nativeCustomViewConfig = [args objectForKey:@"nativeCustomViewConfig"];


        HJNativeAdPlugin * plugin = [HJNativeAdPlugin getPluginWithUniqId:uniqId];
        
        [plugin showAd:_contentView args:nativeCustomViewConfig];
        NSLog(@"HJNativeAdPlugin init...");
    }
    return self;
}

- (UIView*)view {
    return self.contentView;
}



@end
