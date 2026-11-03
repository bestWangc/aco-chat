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
  "timestamp": 1730000000,
  "eventId": "唯一事件 ID",
  "walletAddress": "用户钱包地址",
  "status": "completed"
}
```

API 与 DApp/Farm API 使用同一个服务端密钥 `ACO_ADS_CALLBACK_SECRET`。签名串为
`timestamp.eventId.callbackDomain.normalizedWalletAddress.completed`，签名算法是 HMAC-SHA256，签名值为小写十六进制，放在 `X-Aco-Ads-Signature: sha256=<hex>`；时间戳也放在 `X-Aco-Ads-Timestamp`。`callbackDomain` 是 API 实际请求的目标域名（小写、不含 scheme 和 path），接收方用自己的域名参与验签，避免同一签名被重放到另一个 DApp。EVM 格式地址（`0x` 加 40 位十六进制）签名时转小写，Solana 等大小写敏感地址按原值签名；回调 JSON 始终保留原始钱包地址。
DApp 服务端应校验签名、限制时间戳偏差，并按 `eventId` 幂等处理。每个有效事件代表一次观看完成。

这是 App 对 SDK 曝光事件的上报，不是广告平台的服务端账单核验。登录校验和限流可阻止匿名请求；具备有效 App 登录令牌的恶意客户端仍可能伪造曝光上报。若奖励有实际价值，应接入广告平台服务端核验或 App Attest / Play Integrity 等完整性校验，并由 DApp 按事件 ID 幂等发奖。

## 运行时配置

广告 SDK 的 App ID 和广告位 ID 放在 API 服务端的私有 `.env` 中，通过
`ADS_CONFIG_JSON` 配置。服务端只向 App 返回请求平台、包名/Bundle ID 和 DApp 对应的配置：

```dotenv
ADS_CONFIG_JSON='[{"platform":"android","applicationId":"com.klkl99.cn.cs","appId":"174334","dappIds":["*"],"fullScreenInterstitial":"6610418752764618"}]'
```

当前测试启用全屏插屏；`dappIds` 为 `*` 表示对 App 内全部 DApp 开放。广告配置接口为
`GET /api/v1/ads/config?platform=android&application_id=com.klkl99.cn.cs&dapp_id=<DApp ID>`；
App 在内存中缓存一分钟；更新服务端 `.env` 并重启 API 后，App 会读取新配置，无需重新发布
APK。测试包名不会产生收益，正式上线时替换为商务提供的正式广告位 ID。

DApp 域名直接取自 API 源码中的 DApp 目录（`internal/handler/dapps.go`），再固定拼接 `/api/ads_call`；App 请求不能指定回调域名或 URL。只有该目录登记过的 DApp 才能收到回调。API 和 DApp/Farm API 的 HMAC 密钥使用同一个值，保存在两端的私有环境配置中，不放入 APK 或源码：

```dotenv
ACO_ADS_CALLBACK_SECRET=替换为至少32字符的随机密钥
```

App 的上报接口为 `POST /api/v1/ads/impressions`。API 校验 DApp、包名和广告位配置后，将事件同步转发到该 DApp 的回调 URL；DApp 未配置时返回错误，回调暂时失败时 App 会重试一次。

App 包名属于安装包身份，仍需在构建时设置。测试 Android 包使用：

```sh
ORG_GRADLE_PROJECT_acoApplicationId=com.klkl99.cn.cs flutter build apk
```

默认包名仍是 `com.aco.aco_chat`。广告 App ID 和广告位 ID 不通过 `--dart-define` 传入，
APK 中没有这些固定配置；SDK 运行时仍会收到它们，因此它们是客户端标识，不是秘密凭证。

桥接只允许 App 内 WebView 的主页面从最初打开的 HTTPS 源站调用；网页不能自行传广告位 ID。
`showInterstitial` 当前映射到全屏插屏位；`showRewarded` 暂无启用的测试广告位。其余测试位暂不启用：开屏 `9178873326955476`、普通插屏 `7921135964545941`、激励视频 `5870225444210928`、信息流 `4714663972050724`、Banner `7677974859977385`。启用前需将广告 SDK 的数据处理方式纳入隐私披露与适用的用户同意流程。
