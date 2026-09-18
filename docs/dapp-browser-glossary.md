# DApp 浏览器术语表

| 术语 | 含义 |
| --- | --- |
| DApp | 通过区块链账户连接、签名或发起交易的去中心化应用。 |
| Provider | 网页调用钱包能力的 JavaScript 接口；它不应接触私钥。 |
| EIP-1193 | EVM 钱包 Provider 标准，常见调用为 `eth_requestAccounts` 与 `eth_sendTransaction`。 |
| EIP-712 | EVM Typed Data 签名标准；签名内容应在原生确认页结构化展示。 |
| TronLink | TRON DApp 常用的钱包网页接口。 |
| Phantom Provider | Solana DApp 常用的钱包网页接口。 |
| Wallet Standard | Solana 钱包与应用发现、连接能力的通用标准。 |
| 会话授权 | 某个网页在当前浏览会话中获准读取指定账户地址；不等于获准签名。 |
| 交易解析 | 将待签名的原始交易转换为接收方、金额、合约调用、授权额度和网络费等可读信息。 |
| 域名绑定 | 将 DApp 的账户连接授权绑定至 URL 的 origin，不能只按页面标题或路径判断。 |
