# ANTFUN APK Hyperliquid 交易流程分析

> 分析对象：`ANTFUN_3.5.1_2026091702.apk`  
> 分析日期：2026-09-23  
> 分析方式：APK 静态解包、Flutter AOT 字符串分析、Rust Web3 动态库字符串与导出信息分析。

## 1. 结论摘要

该 APK 的永续合约功能由两层系统共同组成：

1. **Hyperliquid 官方交易层**
   - 读取行情、订单簿和账户状态。
   - 提交下单、撤单、修改杠杆等 Hyperliquid L1 Action。
   - 使用 Hyperliquid 官方 HTTP 和 WebSocket 接口。

2. **ANTFUN Perp 业务层**
   - 管理用户 Perp 账户、Agent Key、入金、提现和交易记录。
   - 提供 Unified Account、保险 Perp、Builder Fee 等封装能力。
   - 对应服务域名为 `https://perpapi.ant.fun`。

用户首次开通时需要使用主钱包完成若干授权签名。完成 Agent Key 授权后，后续每次下单仍然存在密码学签名，但通常改由 Agent Key 在本地自动完成，不再要求用户频繁弹窗确认。

## 2. APK 技术结构

该 APK 是 Flutter 应用，主要业务代码不在普通 Java/Kotlin DEX 中，而是编译在以下动态库：

- `lib/arm64-v8a/libapp.so`：Flutter/Dart AOT 业务逻辑。
- `lib/arm64-v8a/librust_lib_db_web3.so`：钱包、签名、EVM、Hyperliquid Action 编码等 Rust Web3 逻辑。

APK 中发现了以下 Dart 源文件路径信息：

```text
package:db_web3/pages/perp/trade/api/place_order/api.dart
package:db_web3/pages/perp/trade/api/hyperliquid_exchange_signer.dart
package:db_web3/pages/perp/trade/utils/hyperliquid_order_cloid.dart
package:db_web3/pages/perp/service/perp_clearinghouse_account_service.dart
package:db_web3/pages/unified_account_perp/service/unified_account_clearinghouse_service.dart
package:db_web3/pages/unified_account_perp/api/extra_agents/api.dart
package:db_web3/pages/unified_account_perp/api/exchange_rust_api/unified_account_exchange_rust_api.dart
```

Rust 动态库中发现：

```text
src/evm/hyperliquid.rs
src/evm/hyperliquid_user_signed.rs
src/api/perp_api.rs
```

这些信息表明应用内部包含原生的 Hyperliquid Action 构造、哈希和签名实现。

## 3. 服务与接口分层

### 3.1 Hyperliquid 官方接口

APK 中明确存在：

```text
https://api.hyperliquid.xyz
wss://api.hyperliquid.xyz/ws
https://app.hyperliquid.xyz/explorer/tx
/info
/exchange
```

大致用途如下：

| 接口 | 用途 |
| --- | --- |
| `/info` | 查询市场、账户、仓位、订单、成交等信息 |
| `/exchange` | 提交订单、撤单、杠杆调整和其他 L1 Action |
| WebSocket | 订阅盘口、成交、订单状态和账户状态变化 |

### 3.2 ANTFUN Perp 接口

APK 中发现：

```text
https://perpapi.ant.fun
/api/v1/account/info
/api/v1/account/ledger
/api/v1/account/transfers
/api/v1/account/agent-key/info
/api/v1/account/agent-key/register
/api/v1/trade/fills
/api/v1/trade/favorite/add
/api/v1/trade/favorite/list
/api/v1/trade/favorite/remove
/api/v1/trade/insurance
/api/v1/trade/builder-config
/api/v1/deposit/list
/api/v1/deposit/create
/api/v1/deposit/submit
/api/v1/deposit/status
/api/v1/withdraw/create
/api/v1/withdraw/status
```

ANTFUN 服务主要承担：

- Perp 账户初始化和状态管理。
- 入金、提现任务及其状态跟踪。
- Agent Key 注册和绑定。
- Builder Fee 配置。
- Unified Account/保险账户逻辑。
- 成交、账本、资金划转等业务记录。

## 4. 为什么需要资金划转

Hyperliquid 永续合约不能直接把用户普通钱包中的 USDC 余额当作交易保证金。

资金通常位于不同的余额域：

```text
普通 EVM 钱包余额
        │
        │ 链上转账、Bridge 或 Deposit
        ▼
Hyperliquid/ANTFUN 清算账户余额
        │
        │ 账户内部划转或统一账户处理
        ▼
Perp 可用保证金
        │
        ▼
开仓、挂单和维持仓位
```

APK 中发现以下提示和方法：

```text
Transfer funds to start perpetual trading
Please transfer funds to the contract first
must deposit before
getPerpExchangeErrMustDepositText
perpCreateDepositApi
perpSubmitDepositApi
perpGetDepositStatusApi
```

因此，资金划转的主要原因是：

1. **余额域隔离**：普通钱包余额与 Perp 清算账户余额不是同一份余额。
2. **保证金要求**：下单前必须让清算系统确认账户中存在可用抵押品。
3. **风险隔离**：永续合约需要单独计算可用余额、仓位价值、维持保证金和可提现余额。
4. **跨链或跨系统结算**：资金可能需要从外部 EVM 链进入 Hyperliquid HyperCore 或 ANTFUN 统一账户。

## 5. 首次开通流程

### 5.1 钱包连接与身份认证

用户连接或导入钱包后，应用会使用钱包地址作为账户身份。登录或绑定钱包可能需要签署一条认证消息。

这类签名仅用于证明用户控制该地址，不等同于实际下单。

### 5.2 查询 Perp 账户

应用调用：

```text
GET/POST https://perpapi.ant.fun/api/v1/account/info
```

APK 的账户模型包含：

```text
trade_wallet
agent_key
agent_address
agent_key_id
eoa_address
account_value
available_balance
withdrawable_balance
total_margin_used
```

应用据此判断：

- Perp 账户是否已经建立。
- Agent Key 是否存在且有效。
- 是否已经入金。
- 是否需要启用 Unified Account 模式。
- Builder Fee 是否已经授权。

### 5.3 注册 Agent Key

APK 中发现：

```text
signHyperliquidApproveAgent
sign_hyperliquid_approve_agent
perpRegisterAgentKeyApi
perp_get_agent_key_info_api
perp_register_agent_key_api
approveAgent
Agent key not registered
```

Agent Key 注册流程大致为：

```text
生成或取得 Agent Key
        │
        ▼
查询 Agent Key 是否已绑定
        │
        ├─ 已绑定且有效：直接继续
        │
        └─ 未绑定：主钱包签署 approveAgent
                         │
                         ▼
               向 Hyperliquid 提交授权
                         │
                         ▼
               向 ANTFUN 注册 Agent Key 信息
```

主钱包 EOA 是资产所有者；Agent Key 是获得有限交易权限的 API Wallet，用于后续自动签署订单类操作。

## 6. Builder Fee 授权

APK 中发现：

```text
signHyperliquidApproveBuilderFee
sign_hyperliquid_approve_builder_fee
approveBuilderFee
approveBuilderFeeApi
builder_address
builder_fee
maxFeeRate
builder fee has not been approved
Invalid builder fee
```

这说明 ANTFUN 可能以 Hyperliquid Builder 身份为用户构建或提交订单，并在订单中携带 Builder 地址和费用参数。

首次使用相关交易服务时，可能需要主钱包签署一次 `approveBuilderFee`，批准某个 Builder 地址可收取的最高费率。

完成授权后，后续订单可以直接带上 Builder 参数，一般不需要每次重新批准。

## 7. Unified Account 与账户抽象

APK 中发现：

```text
userSetAbstraction
agentSetAbstraction
signHyperliquidUserSetAbstraction
sign_hyperliquid_user_set_abstraction
buildAgentSetAbstractionAction
UnifiedAccountClearinghouseService
InsuredPerpsAccountMode
```

这表明应用支持账户抽象或统一账户模式。

可能涉及两种路径：

### 7.1 普通 Hyperliquid 账户

```text
用户主钱包
    │
    ├─ 授权 Agent Key
    ▼
Agent Key 签署 L1 Action
    │
    ▼
Hyperliquid /exchange
```

### 7.2 ANTFUN Unified Account

```text
用户钱包
    │
    ├─ Deposit 到清算账户
    ├─ 注册 Agent Key
    ├─ 设置 userSetAbstraction/agentSetAbstraction
    ▼
ANTFUN Unified Account 服务
    │
    ▼
Hyperliquid 或统一清算层执行
```

`userSetAbstraction` 通常应由用户主钱包签署；`agentSetAbstraction` 则可能在已经获得授权后由 Agent Key 执行。

## 8. 入金流程

APK 中发现了以下相关模型、状态和日志：

```text
PerpDepositCreateResponse
PerpDepositPoll
UnifiedDepositExecutionStage
approve_tx_data
deposit_tx_data
submitted_tx_hash
deposit_id
Deposit order expired
Deposit successful
[PerpDeposit] order created: depositId=
[PerpDeposit] broadcast tx: chainId=
[PerpDeposit] tx_hash=
[PerpDeposit] submit attempt
```

综合得到的入金流程如下：

```text
用户选择入金资产、网络和金额
        │
        ▼
POST /api/v1/deposit/create
        │
        ▼
后端返回 deposit_id、目标地址和交易参数
        │
        ├─ 必要时先执行 Token Approve
        │
        ▼
本地钱包签署并广播链上 Deposit 交易
        │
        ▼
取得 tx_hash
        │
        ▼
POST /api/v1/deposit/submit
        │
        ▼
轮询 /api/v1/deposit/status
        │
        ▼
ANTFUN/Hyperliquid 完成确认和内部结算
        │
        ▼
Perp 可用保证金增加
```

### 8.1 入金时是否需要签名

需要。

链上 Token Approve、转账或 Deposit 交易必须使用用户钱包私钥签名。如果资产为原生币，可能只需要一笔转账；如果是 ERC-20，则可能先有 Approve，再有 Deposit。

入金并不是每次下单都需要执行。只要 Perp 账户内存在足够保证金，用户可以连续下单。

## 9. 下单参数构造

APK 中发现：

```text
PlacePerpOrderRequest
PlacePerpOrderWireRequest
PlacePerpOrderFill
placePerpOrderApi
placePerpOrdersApi
placePerpOrderRequestsApi
```

订单 Action 中可确认的字段包括：

```text
asset
isBuy
limitPx
sz
reduceOnly
orderType
triggerPx
tif
cloid
builder
orders
grouping
```

含义大致如下：

| 字段 | 含义 |
| --- | --- |
| `asset` | Hyperliquid 市场资产编号 |
| `isBuy` | 买入/做多方向，或卖出/做空方向 |
| `limitPx` | 限价；市价单通常使用可立即成交的保护价格 |
| `sz` | 下单数量 |
| `reduceOnly` | 是否仅减仓 |
| `orderType` | 限价、触发单、止盈止损等订单类型 |
| `triggerPx` | 止盈止损或条件单触发价 |
| `tif` | GTC、IOC、ALO 等有效期策略 |
| `cloid` | 客户端生成的订单唯一标识 |
| `builder` | Builder 地址及费用信息 |
| `grouping` | 普通订单或止盈止损组合关系 |

## 10. 订单签名方式

Rust 库中发现：

```text
sign_hyperliquid_l1_action_impl
sign_hyperliquid_l1_action_with_kind
hd_wallet_manager_api_sign_hyperliquid_l1_action
HyperliquidSignTransaction
Failed to encode action as msgpack
Invalid hyperliquid action json
Failed to serialize hyperliquid typed data
```

订单并不是把普通 JSON 用钱包 `personal_sign` 签一下，而是使用 Hyperliquid 的专用 L1 Action 签名流程：

```text
订单表单参数
    │
    ▼
构造 Hyperliquid order action
    │
    ▼
按照协议对 action 进行 MsgPack 编码
    │
    ▼
加入 nonce、vault/账户上下文等字段
    │
    ▼
计算 Hyperliquid Action Hash
    │
    ▼
构造 EIP-712 Agent Typed Data
    │
    ▼
Agent Key 执行 secp256k1 签名
    │
    ▼
得到 r、s、v 签名
```

Rust 库明确支持以下 Action：

```text
order
cancel
updateLeverage
setReferrer
agentSetAbstraction
```

并包含相应校验错误：

```text
order missing orders
cancel missing cancels
updateLeverage missing asset
updateLeverage missing isCross
updateLeverage missing leverage
setReferrer missing code
order invalid builder
```

## 11. 提交订单流程

完整流程可整理为：

```text
用户填写方向、价格、数量、杠杆等参数
        │
        ▼
前端执行最小金额、精度、价格和保证金校验
        │
        ▼
解析 Hyperliquid asset index
        │
        ▼
对价格与数量进行精度量化
        │
        ▼
生成 cloid
        │
        ▼
加载 ANTFUN Builder 配置
        │
        ▼
构造 order/orders Action
        │
        ▼
Agent Key 签署 Hyperliquid L1 Action
        │
        ▼
POST https://api.hyperliquid.xyz/exchange
        │
        ▼
解析 status/fill/oid/error
        │
        ▼
通过 WebSocket 和账户查询更新订单、成交及仓位
```

APK 中存在以下状态和提示：

```text
Creating order...
Order submitted
Order cancelled
Market orders must use immediate-or-cancel (IOC) time in force
Bracket order is missing the primary (entry) order
Order price is too far from oracle
No liquidity for this market order
reduce only order would increase
builder fee has not been approved
```

这些错误与 Hyperliquid `/exchange` 的订单校验和状态语义一致。

## 12. 市价单如何实现

Hyperliquid 的市价单本质上通常不是一个没有价格的订单，而是带有保护价格的 IOC 限价单。

APK 中明确存在：

```text
Market orders must use immediate-or-cancel (IOC) time in force
No liquidity for this market order
```

所以大致流程为：

1. 根据当前盘口或预言机价格计算可接受的滑点价格。
2. 设置 `limitPx` 为保护价格。
3. 设置 `tif` 为 IOC。
4. 提交后立即成交可成交部分。
5. 未成交部分立即取消。

## 13. 撤单、杠杆和止盈止损

### 13.1 撤单

撤单同样是 Hyperliquid L1 Action：

```text
cancel
cancels
oid
```

由 Agent Key 签名后提交到 `/exchange`，不需要主钱包再次确认。

### 13.2 杠杆调整

APK/Rust 库包含：

```text
updateLeverage
asset
isCross
leverage
```

修改全仓/逐仓和杠杆倍数时，也会构造并签署一个 L1 Action。

### 13.3 止盈止损

APK 中存在：

```text
triggerPx
take profit
stop loss
Bracket order is missing the primary (entry) order
```

止盈止损可能作为 Trigger Order 或 Bracket Order 提交，并通过 `grouping` 与主订单关联。

## 14. 用户是否需要频繁签名

### 14.1 会触发用户显式签名的操作

通常包括：

1. 钱包登录或绑定认证。
2. 首次注册 Agent Key 时签署 `approveAgent`。
3. 首次批准 Builder Fee 时签署 `approveBuilderFee`。
4. 首次启用 Unified Account 时签署 `userSetAbstraction`。
5. 入金时签署 ERC-20 Approve、转账或 Deposit 交易。
6. 提现过程中需要用户授权的链上或 User-Signed Action。
7. Agent Key 失效、过期、解绑或更换后重新授权。

### 14.2 通常不触发主钱包弹窗的操作

Agent Key 生效后，通常包括：

- 普通下单。
- 市价单和限价单。
- 撤单。
- 修改杠杆。
- 止盈止损订单。
- 仅减仓和平仓。

### 14.3 “不弹窗”不等于“没有签名”

每次下单、撤单或修改杠杆仍然必须产生有效签名。

区别是：

```text
首次授权前：主钱包 EOA 签名，用户需要感知和确认
首次授权后：Agent Key 签名，应用可自动完成
```

因此更准确的说法是：

> 用户不需要频繁使用主钱包签名，但每个交易 Action 仍由已授权的 Agent Key 进行密码学签名。

## 15. 提现流程

APK 中发现：

```text
perpCreateWithdrawApi
perpGetWithdrawStatusApi
PerpWithdrawCreateResponse
PerpWithdrawStatus
executePerpWithdrawFlow
withdraw_id
reject_reason
to_address
Withdrawal successful
Withdrawal failed
Withdrawal unavailable for 12 hours after changes
```

提现流程大致为：

```text
用户填写提现金额和目标地址
        │
        ▼
校验可提现余额、最低金额和安全限制
        │
        ▼
POST /api/v1/withdraw/create
        │
        ▼
获得 withdraw_id 和需要签署的数据
        │
        ▼
用户或 Agent Key 完成对应签名/链上提交
        │
        ▼
轮询 /api/v1/withdraw/status
        │
        ▼
Hyperliquid/ANTFUN 完成结算和链上转出
        │
        ▼
目标钱包收到资产
```

提现比下单更可能要求用户显式确认，因为提现涉及资产离开交易或清算账户。

## 16. 完整端到端流程

```text
┌──────────────────────────────┐
│ 1. 用户连接或导入 EVM 钱包    │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 2. 钱包签名登录/绑定 ANTFUN   │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 3. 查询 Perp 账户和 Agent Key │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 4. 主钱包签署 approveAgent    │
│    并注册 Agent Key           │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 5. 可选：approveBuilderFee    │
│    可选：userSetAbstraction   │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 6. 创建入金订单               │
│    /api/v1/deposit/create     │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 7. 用户签署并广播链上交易      │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 8. 提交 tx hash 并等待结算     │
│    Perp 可用保证金到账         │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 9. 用户填写订单参数            │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 10. 构造 Hyperliquid Action   │
│     MsgPack + Action Hash     │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 11. Agent Key 自动签名         │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 12. POST /exchange            │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 13. WS/HTTP 更新订单和仓位     │
└──────────────┬───────────────┘
               ▼
┌──────────────────────────────┐
│ 14. 后续下单由 Agent Key 签名  │
│     一般不再弹主钱包确认       │
└──────────────────────────────┘
```

## 17. 安全模型与需要关注的问题

### 17.1 Agent Key 的保存位置

APK 能确认应用具有 Agent Key 签名能力，但仅凭静态字符串还不能完全确认 Agent 私钥最终存储在：

- Android Keystore/本地加密数据库；
- 应用钱包的 HD Wallet 存储层；
- 由主私钥确定性派生；
- 或其他受保护的本地结构。

这是后续动态分析最值得确认的一项。

### 17.2 Agent Key 权限范围

应确认 Agent Key 是否只能交易，不能直接提现；以及 ANTFUN 是否对其增加了额外的服务端限制。

理想权限模型应为：

- 可以下单和撤单。
- 可以调整交易参数。
- 不能导出主钱包私钥。
- 不能任意把资产提到攻击者地址。
- 可以由主钱包撤销或替换。

### 17.3 Builder Fee

需要关注 `/api/v1/trade/builder-config` 返回的：

- Builder 地址。
- Maker/Taker Fee。
- `maxFeeRate`。
- 配置变更时是否要求用户重新授权。

### 17.4 入金目标地址和交易数据

由于 Deposit 的目标地址和交易数据可能由 ANTFUN 后端返回，正式审计时应确认：

- 客户端是否校验目标合约地址。
- 是否校验 Chain ID。
- 是否校验 Token 地址和金额。
- 是否限制无限额度 Approve。
- 后端返回的数据是否可能导致任意调用。

## 18. 静态分析结论与推断边界

### 18.1 APK 中直接确认的事实

- 应用直接包含 Hyperliquid 官方 API 和 WebSocket 地址。
- 应用包含 `/info` 与 `/exchange` 调用路径。
- 应用包含 Hyperliquid Action 的 MsgPack 编码和签名逻辑。
- 应用支持 order、cancel、updateLeverage、setReferrer 等 Action。
- 应用支持 `approveAgent`、`approveBuilderFee` 和 abstraction 相关签名。
- 应用使用 `perpapi.ant.fun` 管理账户、入金、提现、Agent Key 和 Builder 配置。
- 入金采用创建订单、广播链上交易、提交交易哈希和轮询状态的多阶段流程。
- 后续订单可以通过 Agent Key 签名。

### 18.2 根据协议与命名推断的部分

- Unified Account 的具体资金托管和清算主体。
- Agent 私钥的具体生成和持久化方式。
- 某些账户模式下订单是否先经过 ANTFUN 后端再转发。
- 提现究竟由主钱包、Agent Key 还是独立 User-Signed Action 完成。
- ANTFUN Builder Fee 的实际费率和启用条件。

如需进一步确认上述内容，需要进行动态抓包、Hook 或运行时日志分析。

## 19. 最终回答

### 为什么要资金划转？

因为普通钱包余额与 Hyperliquid/ANTFUN Perp 清算账户的保证金余额相互隔离。只有完成 Deposit 和内部结算后，资产才会变成可以开仓的 Perp 保证金。

### 订单如何提交？

应用根据用户输入构造 Hyperliquid Order Action，将其按协议进行 MsgPack 编码和哈希，用 Agent Key 生成 EIP-712/L1 Action 签名，然后提交到 Hyperliquid `/exchange`，再通过 WebSocket 和查询接口更新订单、成交和仓位状态。

### 用户是否需要频繁签名？

通常不需要频繁使用主钱包确认。首次注册 Agent Key、批准 Builder Fee、启用账户抽象、入金和提现时可能需要用户显式签名。Agent Key 授权完成后，每笔订单仍有签名，但通常由 Agent Key 自动完成。

### ANTFUN 后端在流程中做什么？

ANTFUN 后端负责 Perp 账户、Agent Key 注册、Builder 配置、入金/提现状态、账本、成交记录和 Unified Account 等业务；核心 Hyperliquid 订单 Action 则由客户端构造和签名，并通过 Hyperliquid 官方接口提交。

