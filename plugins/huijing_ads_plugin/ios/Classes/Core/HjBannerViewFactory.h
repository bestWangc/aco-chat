//
//  HjBannerViewFactory.h
//  huijing_ads_plugin
//
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

@interface HjBannerViewFactory : NSObject<FlutterPlatformViewFactory>

@property (strong,nonatomic) NSObject<FlutterBinaryMessenger> *messenger;

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;
@end
