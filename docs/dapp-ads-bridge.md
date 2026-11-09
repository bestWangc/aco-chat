# DApp 广告桥接

App 内的 DApp WebView 为 HTTPS 页面提供 `window.acoAds`。DApp 传当前连接的钱包地址；App 会与当前钱包核对，通过后才继续：

```js
await window.acoAds.showInterstitial({ walletAddress: connectedWalletAddress });
```

App 监听广告 SDK 的曝光事件；广告持续展示 5 秒后，App 上报一次 `dappId`、`walletAddress` 和广告类型到业务 API。API 根据 `dappId` 调用 DApp 的服务端回调。DApp 不传内部用户 ID、DApp ID 或广告位 ID。

广告上报接口要求 App 有有效的 ACO 登录令牌，并按账号和 IP 限流。令牌保存在 App 安全存储中，由原生 App 请求时附带，不会暴露给 DApp 网页。未登录或没有当前钱包地址时，App 不会上报观看事件。

DApp 回调请求的 JSON 格式为：

```json
{
  "eventId": "唯一事件 ID",
  "walletAddress": "用户钱包地址",
  "timestamp": 1730000000,
  "signature": "HMAC-SHA256 小写十六进制摘要"
}
```

API 与 DApp/Farm API 使用同一个服务端密钥 `ACO_ADS_CALLBACK_SECRET`。签名串为
`timestamp.eventId.normalizedWalletAddress.completed`，签名算法是 HMAC-SHA256，签名值为小写十六进制，放在 JSON 的 `signature` 字段中。EVM 格式地址（`0x` 加 40 位十六进制）签名时转小写，Solana 等大小写敏感地址按原值签名；回调 JSON 始终保留原始钱包地址。
DApp 服务端应校验签名、限制时间戳偏差，并按 `eventId` 幂等处理。每个有效事件代表一次观看完成。

这是 App 对 SDK 曝光事件的上报，不是广告平台的服务端账单核验。登录校验和限流可阻止匿名请求；具备有效 App 登录令牌的恶意客户端仍可能伪造曝光上报。若奖励有实际价值，应接入广告平台服务端核验或 App Attest / Play Integrity 等完整性校验，并由 DApp 按事件 ID 幂等发奖。

## 运行时配置

广告 SDK 的 App ID 和广告位 ID 放在 API 服务端的私有 `.env` 中，通过
`ADS_CONFIG_JSON` 配置。服务端只向 App 返回请求平台、包名/Bundle ID 和 DApp 对应的配置：

```dotenv
ADS_CONFIG_JSON='[{"platform":"android","applicationId":"com.kzparty.chat.aca.cac","appId":"246332","dappIds":["*"],"fullScreenInterstitial":"1968196657032792"},{"platform":"ios","applicationId":"com.meimeidacios.app","appId":"213751","dappIds":["*"],"fullScreenInterstitial":"1813907069045001"}]'
```

Android 和 iOS 分别使用各自的 Bundle ID、SDK App ID 和全屏广告位；`dappIds` 为 `*` 表示
对 App 内全部 DApp 开放。广告配置接口会根据 `platform` 返回对应记录，例如：
`GET /api/v1/ads/config?platform=android&application_id=com.kzparty.chat.aca.cac&dapp_id=<DApp ID>`；
App 按平台分别请求配置并在内存中缓存一分钟。Android 正式包名为
`com.kzparty.chat.aca.cac`，SDK App ID 为 `246332`，全屏广告位为 `1968196657032792`；
iOS Bundle ID 为 `com.meimeidacios.app`，SDK App ID 为 `213751`，全屏广告位为
`1813907069045001`。更新服务端 `.env` 并重启 API 后，App 会读取新配置，无需重新发布安装包。

DApp 域名直接取自 API 源码中的 DApp 目录（`internal/handler/dapps.go`），再固定拼接 `/api/ads_call`；App 请求不能指定回调域名或 URL。只有该目录登记过的 DApp 才能收到回调。API 和 DApp/Farm API 的 HMAC 密钥使用同一个值，保存在两端的私有环境配置中，不放入 APK 或源码：

```dotenv
ACO_ADS_CALLBACK_SECRET=替换为至少32字符的随机密钥
```

App 的上报接口为 `POST /api/v1/ads/impressions`。API 校验 DApp、包名和广告位配置后，将事件同步转发到该 DApp 的回调 URL；DApp 未配置时返回错误，回调暂时失败时 App 会重试一次。

App 包名属于安装包身份，仍需在构建时设置。测试 Android 包使用：

```sh
ORG_GRADLE_PROJECT_acoApplicationId=com.kzparty.chat.aca.cac flutter build apk
```

默认 Android 包名仍是 `com.aco.aco_chat`，正式 Android 构建需设置上面的 Gradle 属性。
广告 App ID 和广告位 ID 不通过 `--dart-define` 传入，
APK 中没有这些固定配置；SDK 运行时仍会收到它们，因此它们是客户端标识，不是秘密凭证。

桥接只允许 App 内 WebView 的主页面从最初打开的 HTTPS 源站调用；网页不能自行传广告位 ID。
`showInterstitial` 当前映射到全屏插屏位；`showRewarded` 暂无启用的测试广告位。其余测试位暂不启用：开屏 `9178873326955476`、普通插屏 `7921135964545941`、激励视频 `5870225444210928`、信息流 `4714663972050724`、Banner `7677974859977385`。启用前需将广告 SDK 的数据处理方式纳入隐私披露与适用的用户同意流程。
