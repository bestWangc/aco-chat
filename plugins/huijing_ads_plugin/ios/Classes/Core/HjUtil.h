//
//  HjUtil.h
//  huijing_ads_plugin
//
//

#import <Foundation/Foundation.h>

@class WindMillAdRequest;

@interface HjUtil : NSObject

+ (WindMillAdRequest *)getAdRequestWithItem:(NSDictionary *)item;

+ (UIViewController *)getCurrentController;

@end
