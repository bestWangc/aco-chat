//
//  HJNativeAdPlugin.h
//  Pods
//
//  Created by 胡兵 on 2024/6/8.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface HJNativeAdPlugin : NSObject<FlutterPlugin>
+ (HJNativeAdPlugin *)getPluginWithUniqId:(NSString *)uniqId;
- (void)showAd:(UIView *)adContainer args:(NSDictionary *)args;

@end
