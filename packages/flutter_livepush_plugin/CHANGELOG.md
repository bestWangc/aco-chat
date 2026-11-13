## 7.0.0

### **主要更新**

- **升级 Native SDK**
  - 将 `AliVCSDK_InteractiveLive` 升级至版本 **7.0.0**，提供更稳定的推流功能与性能优化。
- **Flutter SDK 兼容性改进**
  - 解决了插件 Demo 工程在 Flutter 3.0 中的兼容性问题。
  - 增加了对 Flutter SDK 版本的适配区间，目前支持 **2.8.0 至 3.22.2**。
  - **重要调整**：剔除了 `fish_redux` 库
    - `fish_redux` 对插件的兼容性范围造成了限制，导致在高版本 Flutter 中出现适配问题。
    - 为提升插件的广泛兼容性，将 `example` 工程的所有页面架构迁移至 `redux`，彻底移除了对 `fish_redux` 的依赖。
- **依赖库优化**
  - 移除了多个兼容性较差的第三方依赖库（如扫码库等），进一步减少潜在的冲突和冗余，确保插件在更多环境下的兼容性。

### **美颜插件更新**

- 更新美颜插件的内核 SDK 至最新版本 **6.8.1-official-pro**，提供更优质的美颜效果和性能表现。

## 6.7.0

* 1.更新 Native SDK 版本为 AliVCSDK_InteractiveLive:6.7.0
* 2.解决与推流插件 flutter_aliplayer 冲突问题，使用一体化SDK（AliVCSDK_InteractiveLive）代替独立SDK（AlivcLivePusher）

## 2.1.0+1

* 1.修复已知问题

## 2.1.0

* 1.新增直播连麦功能
* 2.支持美颜解决方案
* 3.更新 Native SDK 版本为 AlivcLivePusher_Interactive:6.1.0

## 1.0.0

* 1.新增摄像头推流功能
* 2.更新 Native SDK 版本为 AlivcLivePusher:4.5.1