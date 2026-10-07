# Antfun 3.5.1 接口与流程

更新时间：2026-09-22  
分析对象：`ANTFUN_3.5.1_2026091702.apk`、ADB 日志、公开接口实测。

> **已确认**表示由 APK、ADB 日志或接口响应直接验证；**未确认**表示只发现路径/模型，尚未还原完整请求体。

## 1. 总体流程

```text
启动 App
  ├─ 读取/刷新 API 域名
  ├─ health 检查并选择可用域名
  ├─ 初始化 Rust/Web3、钱包数据库、Feed/聊天
  ├─ 加载 RPC、用户资料、钱包资产
  └─ 市场页：ranking/setup → ranking/list → 本地展示/排序

代币详情：token 信息 → K 线/成交/持有人 → Feed 实时更新
代币交易：获取报价 → 本地签名 → 链 RPC 广播 → 查询确认
```

## 2. API 域名与启动请求（已确认）

### 2.1 域名发现与健康检查

```http
GET https://togooss.oss-ap-southeast-1.aliyuncs.com/config/endpoints.json
GET https://tapi1.ant.fun/api/v1/health
```

API 域名：

```text
https://tapi1.ant.fun
https://tapi2.ant.fun
https://tapi3.ant.fun
https://tapi.antapi1.com
```

### 2.2 用户资料

```http
POST /api/feed/v1/profile/overview
Content-Type: application/json
```

```json
{"userId": "<user_id>"}
```

### 2.3 钱包 Token 列表

ADB 日志打印的参数字段：

```text
ts_ms, chain, chain_value, page=1, size=40, force_refresh=false, address
```

启动阶段出现的链值：`bsc`、`base`、`xlayer`、`eth`、`robinhood`、`SOL`、`TRON`。

### 2.4 Live WebSocket

```text
wss://tapi1.ant.fun/ws/live?token=<JWT>&platform=android
```

订阅：`live:list:live`、`live:list:scheduled`。

## 3. 市场榜单

市场页先从 `ranking/setup` 生成筛选项，再调用 `ranking/list`。

### 3.1 榜单配置

```http
POST https://tapi1.ant.fun/api/v1/ranking/setup
Content-Type: application/json
```

请求体：`{}`

| `type` | UI 标题 | `hidden` | `chains` | `intervals` |
|---|---|---:|---|---|
| `binance_alpha` | 热门 / Trending | `false` | `all`, `sol`, `bsc`, `eth` | `5m`, `1h`, `4h`, `24h` |
| `xstock` | 美股 / Stocks | `true` | `all`, `sol`, `bsc` | `24h` |
| `picks` | Meme | `false` | `all`, `sol`, `bsc`, `base` | `5m`, `1h`, `6h`, `24h` |
| `ant_alpha` | Alpha | `false` | `all`, `sol`, `bsc` | `24h` |

每项还包含 `categories`：`slug`、`title_en`、`title_zh`、`icon`。

### 3.2 榜单列表

```http
POST https://tapi1.ant.fun/api/v1/ranking/list
Content-Type: application/json
```

APK 确认的请求字段只有：

| 字段 | 含义 |
|---|---|
| `type` | 榜单类型 |
| `chain` | 链筛选 |
| `interval` | 统计时间窗口 |

“热门 / 全部 / 24h”：

```json
{
  "type": "binance_alpha",
  "chain": "all",
  "interval": "24h"
}
```

“Meme / Solana / 24h”：

```json
{
  "type": "picks",
  "chain": "sol",
  "interval": "24h"
}
```

### 3.3 响应结构

```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "chain": "all",
    "interval": "24h",
    "list": [
      {
				"ts": 1790003868,
				"follow": true,
				"vu": "28698453.710814",
				"bvu": "14691581.582715",
				"svu": "14006872.128099",
				"signal_vu": "",
				"price_usd": "1514.3597573460158",
				"pcr": "0.053",
				"tnx": "202400",
				"btnx": "106792",
				"stnx": "95608",
				"base": {
					"chain": "sol",
					"addr": "A7bdiYdS5GjqGFtxf17ppRHtDKPkkRqbKtR27dxvQXaS",
					"base": "A7bdiYdS5GjqGFtxf17ppRHtDKPkkRqbKtR27dxvQXaS",
					"sym": "ZEC",
					"name": "Zcash",
					"icon": "https://oss.antapi1.com/perps/icons/main/ZEC.png",
					"ct": 1760128263,
					"dex": "orca",
					"pool": "GTHKH8s82ZR8GTSFZ1dUu6wfdxhy59wpMShxzG5zjiPm",
					"sup": "100644.80633068",
					"market_cap": "152952592.93133913205412476",
					"pool_create": "EH7K5oUEL6pHkk6JTPfmD5RfTAKWVsfD7sU2qBuRNfwE",
					"quote_sym": "USDC",
					"launchpad": "orca",
					"from_pool_launchpad": "",
					"leverage": 0,
					"verified": true
				},
				"tvl_usd": ""
			}
    ]
  }
}
```

常用字段：`base.chain`、`base.addr`、`base.pool`、`base.dex`、`base.sym`、`base.market_cap`、`price_usd`、`vu`、`pcr`、`tnx`。

### 3.4 分页

APK 请求/响应模型没有发现：

```text
page, page_size, limit, offset, cursor, next_cursor, has_more, total
```

附加 `page/page_size` 或 `limit/offset` 后，服务端仍返回相同完整列表；实测 `binance_alpha + all + 24h` 返回约 90 条。因此当前是一次返回，页面滚动/排序属于客户端行为。

## 4. UI 筛选值

### 4.1 顶部分类

UI：

```text
自选、热门、Meme、主流、Alpha、Bingan
```

已确认映射：

```text
热门 -> type=binance_alpha
Meme -> type=picks
Alpha -> type=ant_alpha
```

`主流`、`Bingan` 没有出现在本次 setup 返回的 4 个公开 type 中。APK 虽有 `main`、`meme` 等字符串，但 `type=main` 会返回 `no ranking clazz found`，不能把 `main` 当作已确认的 ranking type。

### 4.2 链筛选

UI：

```text
全部      -> all
Robinhood -> robinhood
Solana    -> sol
BSC       -> bsc
```

APK native 链配置中的 Robinhood：

```text
chain code: robinhood
name: Robinhood Chain
rpc: https://rpc.mainnet.chain.robinhood.com
explorer: https://robinhoodchain.blockscout.com
```

Robinhood 通过字符串 chain code 区分，不是数字 chain ID。但 `ranking/setup` 当前没有把它列入 `binance_alpha.chains`，所以不能证明所有榜单类型都支持它。

### 4.3 本地排序

`市值`、`成交额`、`价格`、`涨跌幅`是前端展示/排序维度，不是已确认的 `ranking/list` 请求字段。

## 5. 代币详情与实时行情（路径已确认，body 未完整确认）

```text
POST /api/v1/token/info
POST /api/v1/token/states
POST /api/v1/token/details
POST /api/v1/kline/history
POST /api/v1/trades/list
POST /api/v1/token/top_traders
POST /api/v1/token/top100_holders
```

用途：基础信息、状态/行情、详情统计、历史 K 线、成交记录、交易者排行、Top 100 持有人。

APK 中存在 K 线 WebSocket 相关逻辑；具体订阅 body 尚未从 ADB 日志直接确认，不在本文把推测字段写成确定协议。

## 6. 代币搜索（APK 与接口实测）

### 6.1 关键词搜索

```http
POST https://tapi1.ant.fun/api/v1/search/
Content-Type: application/json
```

不带尾斜杠时服务端会返回 `307`，实际请求建议使用 `/api/v1/search/`。

必填字段由服务端校验错误直接确认：

| 字段 | 类型 | 说明 |
|---|---|---|
| `chain` | string | 链筛选，例如 `all`、`sol`、`bsc` |
| `term` | string | 搜索词，可为代币名称、符号或地址片段 |

请求示例：

```json
{
  "chain": "all",
  "term": "ZEC"
}
```

也可以按链搜索：

```json
{
  "chain": "sol",
  "term": "ZEC"
}
```

响应结构：

```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "pools": [
      {
        "id": "sol_orca_<pool>",
        "chain": "sol",
        "addr": "<pool_address>",
        "dex": "orca",
        "base_addr": "<token_address>",
        "base_sym": "ZEC",
        "quote_addr": "<quote_address>",
        "quote_sym": "USDC",
        "name": "Zcash",
        "tvl_usd": "...",
        "price_usd": "...",
        "market_value": "...",
        "market_code": "tokens"
      }
    ]
  }
}
```

搜索结果以池子为单位，不是单纯的代币列表。同一代币在不同 DEX/池子可能出现多条结果。代币地址使用 `base_addr`，池地址使用 `addr`，链使用 `chain`。

### 6.2 热门搜索/趋势池

APK native 字符串中还确认了：

```http
POST https://tapi1.ant.fun/api/v1/search/trending
Content-Type: application/json
```

必填字段：

```json
{
  "chain": "all"
}
```

该接口返回结构同样是 `data.pools`，但结果中的 `market_code` 可能为空，属于趋势池/热门池数据；`interval`、`limit` 等附加字段不是服务端必填字段。

### 6.3 与其他搜索的区别

```text
/api/v1/search/          关键词搜索：chain + term
/api/v1/search/trending  热门/趋势池：chain
/api/feed/v1/chat/search 聊天/频道搜索，不是代币搜索
```

## 7. Feed、钱包与 Perp

### 6.1 Feed

```text
/api/feed/v1/feed/list
/api/feed/v1/feed/list_by_token
/api/feed/v1/token/holders
```

数据类型包括：`TokenFeedData`、`TradeFeedData`、`PositionFeedData`、`ProfitFeedData`、`TweetFeedData`、`NewsFeedData`、`VideoFeedData`。

### 6.2 钱包资产

```text
/api/v1/wallet/tokens
/api/v1/wallet/asset/list
/api/v1/wallet/analytics
/api/v1/wallet/defi/positions
/api/feed/v1/position/spot/list
```

通常依赖登录 Token、钱包地址、设备信息或 Feed 会话。

### 6.3 Perp/合约

```text
/api/v1/account/info
/api/v1/account/ledger
/api/v1/trade/fills
/api/v1/position/list
/api/v1/account/transfers
HyperliquidHttpClient
HyperliquidWsManager
```

## 8. 交易流程

```text
获取报价 → 计算滑点 → 本地钱包签名 → Solana/EVM RPC 广播 → 查询交易状态
```

APK 中可见的交易能力/路径：

```text
sol_swap_quote_api
sol_swap_execute_api
eth_swap_quote_api
eth_swap_execute_api
/api/v1/dex/tx/preview
/api/v1/dex/transfer
/api/v1/dex/bridge/quote
/api/v1/dex/bridge/status
```

签名、私钥和最终广播保持在本地钱包/链 RPC 流程中；本文不保存凭证。

## 9. 权限与证据边界

已直接实测且无需登录：

```text
GET /api/v1/health
POST /api/v1/ranking/setup
POST /api/v1/ranking/list
```

通常需要登录或钱包信息：Feed、钱包资产、账户、仓位、成交、交易和用户 WebSocket 会话接口。

尚未确认完整参数：

```text
主流/Bingan 的最终后端接口
token/info、token/states、token/details
kline/history、trades/list、top_traders、top100_holders
ranking/list 的完整服务端排序规则
```
