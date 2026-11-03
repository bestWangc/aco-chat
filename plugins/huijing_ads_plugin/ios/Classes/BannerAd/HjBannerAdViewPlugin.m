//
//  HjBannerAdViewPlugin.m
//  huijing_ads_plugin
//
//

#import "HuijingAdsPlugin.h"
#import "HjBannerAdViewPlugin.h"
#import "HjBannerAdPlugin.h"
#import "HjUtil.h"
#import "HjPluginContant.h"
#import <HJOpenAdSDK/HJAdsOpen.h>


@interface HjBannerAdViewPlugin ()
@property (nonatomic, strong) UIView *contentView;
@end

@implementation HjBannerAdViewPlugin

- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(NSDictionary *)args{
    self = [super init];
    if (self) {
        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = UIColor.clearColor;
        NSString *uniqId = [args objectForKey:@"uniqId"];
        HjBannerAdPlugin * plugin = [HjBannerAdPlugin getPluginWithUniqId:uniqId];

        [plugin showAd:_contentView];
        NSLog(@"HjBannerAdPlugin init...");
    }
    return self;
}

- (UIView*)view {
    return self.contentView;
}



@end
