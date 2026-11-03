//
//  HJNativeViewFactory.h
//  huijing_ads_plugin
//
//  Created by 胡兵 on 2024/6/8.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>
#import "HJNativeAdPlugin.h"

@interface HJNativeViewFactory : NSObject<FlutterPlatformViewFactory>

@property (strong,nonatomic) NSObject<FlutterBinaryMessenger> *messenger;
@property (strong,nonatomic) NSDictionary *creationParams;

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

@end
