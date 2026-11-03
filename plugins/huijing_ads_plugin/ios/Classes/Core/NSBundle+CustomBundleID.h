#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (CustomBundleID)

/// 原始 Bundle Identifier (readonly)
@property (nonatomic, copy, readonly) NSString *originalBundleID;

/// 当前自定义 Bundle Identifier
@property (nonatomic, copy, nullable) NSString *customBundleID;

/**
 动态修改 Bundle Identifier
 
 @param bundleID 要设置的 Bundle Identifier，传 nil 恢复默认值
 @note 需在应用启动早期调用（如 didFinishLaunchingWithOptions 起始位置）
 */
- (void)custom_setBundleIdentifier:(NSString *_Nullable)bundleID;

@end

NS_ASSUME_NONNULL_END