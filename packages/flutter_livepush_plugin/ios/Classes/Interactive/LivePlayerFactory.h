//
//  LivePlayerFactory.h
//  flutter_livepushInteractive_plugin
//
//  Created by ISS013602000846 on 2023/4/28.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface LivePlayerFactory : NSObject<FlutterStreamHandler, FlutterPlatformViewFactory>

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
