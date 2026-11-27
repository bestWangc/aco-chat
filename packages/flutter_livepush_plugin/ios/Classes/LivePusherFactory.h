//
//  LivePusherFactory.h
//  livepush
//
//  Created by ISS013602000846 on 2023/2/20.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface LivePusherFactory : NSObject<FlutterStreamHandler, FlutterPlatformViewFactory>

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
