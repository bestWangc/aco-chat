# 阿里云录屏兼容补丁

适用于当前 `AliVCSDK_InteractiveLive:7.11.0`，通过 AGP ASM instrumentation
在 Debug、Profile、Release 构建中转换 SDK 类，不修改 Gradle 缓存中的 AAR。

- `com.alivc.component.screen.b`（ScreenPusher）取得 MediaProjection 后，
  立即用主线程 Handler 注册其已有的回调字段 `f`。
- `com.alivc.component.screen.b$a.onStop()` 调用已有的 `e()`，释放 VirtualDisplay。
- 未找到预期注入点，或 SDK 已经包含注册调用时，构建失败，要求重新检查补丁。

原 SDK 创建了回调但没有注册，Android 14+ 在 createVirtualDisplay 时会抛出
IllegalStateException，而 SDK 会吞掉该异常。

升级 SDK 必须重新检查以上混淆类、字段及方法；不能只沿用原来的混淆名称。
可用 `:app:transformDebugClassesWithAsm` 检查应用侧转换，
用 `:app:mergeExtDexDebug` 验证外部 SDK 的转换及 DEX 编译。

本次已检查转换后的 SDK 字节码，确认 registerCallback 注入成功，
并通过上述构建检查。用户已确认真机共享画面恢复。
停止后重新授权共享、系统停止录屏仍需回归验证。
