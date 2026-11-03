//
//  HJNativeAdViewPlugin.h
//  huijing_ads_plugin
//
//  Created by 胡兵 on 2024/6/8.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface HJNativeAdViewPlugin : NSObject<FlutterPlatformView>


- (instancetype)initWithFrame:(CGRect)frame
                    arguments:(NSDictionary *)args;

    

@end
