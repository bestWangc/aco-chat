# ADR 0001：多链 DApp 浏览器的连接边界

状态：实施中（EVM 原生资产转账已完成）
日期：2026-09-18

## 背景

探索页现有 DApp 目录数据，但点击入口尚未打开 DApp。Aco 钱包同时支持 EVM 系列链、TRON 和 Solana；DApp 网页并不存在一套通用的钱包接口。

## 决策

内置浏览器按协议族提供原生钱包桥接，私钥与助记词永不注入 WebView：

- EVM（Ethereum、BNB Smart Chain、Base，以及后续 Polygon、Arbitrum、Optimism）采用 EIP-1193 Provider；当前支持连接账户、读取链/账户、个人消息签名、原生资产转账，以及已登记 USDT/USDC 的标准转账和授权。Typed Data、未知合约调用与未知代币交易在完成可读解析前保持拒绝。
- TRON 提供 TronLink 兼容接口；实现账户连接、消息签名和交易签名/广播。
- Solana 提供 Phantom 兼容 Provider，并逐步接入 Solana Wallet Standard；当前实现连接、Ed25519 消息签名，以及受限的标准 SOL 转账签名。仅允许 Legacy 格式、单签名、单条 System Program transfer；V0 地址查找表、多指令、额外签名人和 SPL Token 交易在具备完整解析前保持拒绝。
- 每一个签名、交易、链切换、账户授权都必须由原生确认界面逐笔批准，网页仅收到结果或标准错误码。交易签名额外强制输入钱包密码，不允许使用生物识别替代。

## 分期

1. 浏览器基础：DApp 目录入口、地址输入、导航、受控外链、来源展示和会话隔离。
2. EVM：完整 EIP-1193 桥接与安全审批，是 Ethereum / BSC / Base 的共同实现。
3. Solana：Phantom / Wallet Standard 兼容桥接和原生交易解析。
4. TRON：TronLink 兼容桥接和原生交易解析。

未完成某协议族的交易解析与审批前，不向该协议族的网页暴露可签名 Provider；可以保留只读浏览。

## 后果

- EVM 多链复用同一套 Provider，但必须维护链 ID、RPC 和切换权限映射。
- TRON、Solana 需要新建链专属签名器；当前客户端仅有 EVM 原生转账签名，不能作为这两条链的 DApp 交易签名实现。
- WebView 与原生层之间传递的数据按请求 ID 配对，并限制 JSON 大小、调用频率及来源；导航后取消旧页面未完成请求。
- 交易确认页必须展示真实来源域名、目标合约/账户、资产变化、授权额度、网络费和风险提示。无法解码时必须拒绝，而不是显示为普通转账。无限额度授权必须单独提示风险。

## 依据

- EIP-1193 定义了 EVM Provider 的请求/事件模型。
- Phantom 浏览器 Provider 使用 `connect`、`signMessage`、`signTransaction`、`signAndSendTransaction` 等 Solana 钱包调用。
- TronLink 的网页集成依赖其注入的 TRON Provider，而非 EIP-1193。
