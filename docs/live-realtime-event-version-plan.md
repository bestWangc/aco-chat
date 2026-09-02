# 直播间实时事件独立版本方案

## 1. 目标与原则

本次协议升级采用破坏性变更，服务端和客户端同步发布，所有用户必须升级到新版本，不保留旧协议兼容逻辑。

核心原则：

1. 删除全局事件版本号。
2. 每个实时状态事件独立维护版本号。
3. 不同事件之间互不触发重拉、互不覆盖状态。
4. 普通聊天完全走 LiveKit Data，不进入房间事件系统。
5. 用户进入直播间不再生成自动欢迎消息。

## 2. 实时事件清单

| 事件 | 功能描述 | 接收范围 | 独立版本范围 |
| --- | --- | --- | --- |
| `room.snapshot` | 建连、重连或校准时返回完整房间状态 | 当前连接用户 | 不参与事件版本竞争；只携带各状态水位 |
| `room.participant_count` | 更新直播间当前在线人数 | 全员 | `participant_count` |
| `room.participant_joined` | 通知新用户进入，维护本地成员状态 | 全员 | `participant_members` |
| `room.participant_left` | 通知用户离开，移除成员或预览池用户 | 全员 | `participant_members` |
| `room.host_absent` | 主持人断线或暂时离开时更新主持人缺席状态 | 全员 | `host_presence` |
| `room.host_transferred` | 主持人转让后通知新的主持人和角色变化 | 全员，包括听众 | `host_transfer` |
| `room.speaker_invite` | 主持人邀请或取消邀请指定听众上麦 | 指定听众 | `speaker_invite:{user_id}` |
| `room.speaker_changed` | 上麦后更新全部 speakers 和固定听众预览池 | 全员 | `speakers` |
| `room.speaker_removed` | 下麦或移出 speakers，不重新挑选 listeners | 全员 | `speakers` |
| `room.participant_mute` | 更新指定用户的麦克风静音状态 | 全员 | `participant_mute:{user_id}` |
| `room.audio_mute` | 更新房间全局音频开关状态 | 全员 | `audio_mute` |
| `room.chat_mute` | 更新房间是否禁止聊天 | 全员 | `chat_mute` |
| `room.check_in_started` | 主持人发起签到，所有用户显示签到按钮和截止时间 | 全员 | `check_in:{check_in_id}:started` |
| `room.check_in` | 用户签到后更新主持人端签到人数和记录 | 仅主持人 | `check_in:{check_in_id}:result` |
| `room.raised_hand_count` | 更新主持人端举手人数 | 仅主持人 | `raised_hand_count` |
| `room.kicked` | 通知被踢用户退出当前直播间 | 被踢用户 | `kick:{user_id}` |
| `room.ended` | 通知直播结束；也可由快照中的 `live.status=ended` 表达 | 全员 | `room_lifecycle` |

`room.participant_joined` 当前 Flutter 已有解析，服务端需要补齐实际发送；如果决定不发送，则必须同时从客户端协议中删除，不能保留半成品。

## 2.1 邀请上麦与移至听众的事件边界

邀请上麦和移至听众不是同一个业务事件，不能复用同一个事件类型：

| 操作 | 事件 | 功能描述 | 接收范围 | 版本范围 |
| --- | --- | --- | --- | --- |
| 主持人邀请听众上麦 | `room.speaker_invite` | 只改变目标用户的待接受邀请状态，不改变其角色 | 指定听众 | `speaker_invite:{user_id}` |
| 听众接受邀请并上麦 | `room.speaker_changed` | 将目标用户从 listener 转为 speaker，并更新 speakers/预览池 | 全员 | `speakers` |
| 听众拒绝邀请 | `room.speaker_invite` | 清除目标用户的待接受邀请状态 | 指定听众 | `speaker_invite:{user_id}` |
| 主持人将 speaker 移至听众 | `room.speaker_removed` | 将目标用户从 speaker 转为 listener，不重新挑选固定 listeners | 全员 | `speakers` |
| speaker 主动下麦 | `room.speaker_removed` | 将目标用户从 speaker 转为 listener，不重新挑选固定 listeners | 全员 | `speakers` |

本次实现必须直接使用独立广播事件，不能先继续发送 `room.snapshot` 再等待后续替换。两类操作可以复用同一套版本管理器和发送队列，但不能复用事件类型或版本范围：

- `room.speaker_invite` 只描述“邀请状态”；
- `room.speaker_changed` 描述“上麦后的角色和可见列表变化”；
- `room.speaker_removed` 描述“移至听众/下麦后的角色变化”；
- 邀请事件不能替代角色变更事件；
- 角色变更事件不能只发给目标用户，必须广播给所有相关连接。

实现要求：

- 邀请接口只发送目标用户的 `room.speaker_invite`；
- 接受邀请接口直接广播 `room.speaker_changed`；
- 移至听众和主动下麦直接广播 `room.speaker_removed`；
- 以上三个操作不得通过 `room.snapshot` 代替；
- 如果事件需要携带完整 speakers/预览池列表，可以在独立事件中携带 `room` 或专用列表字段，但事件 `type` 必须保持独立；
- 客户端收到独立事件后直接更新本地状态，不因角色变化自动请求 `/room`。

主持人转让时由同一个事务同时变更主持人身份和两名成员角色，并发送全员可见的
`room.host_transferred`。该事件必须携带最终的 `host_id` 及受影响成员角色；不得再额外发送
`room.speaker_changed` 来表达同一次转让，避免客户端重复应用和版本交叉。若转让导致预览列表变化，
在同一事务中另行生成一次 `room.speaker_changed`，其 payload 必须是最终完整 speakers/预览池列表，
两个事件各自使用自己的版本水位，客户端按事件类型分别应用。

## 3. 不属于房间事件的内容

普通聊天完全使用 LiveKit Data，当前 topic 为 `chat`：

```text
LiveKit Data -> 客户端接收 -> LiveChatBuffer -> UI
```

不维护房间事件版本，也不触发 `/room` 重拉。

用户进入直播间的自动欢迎消息彻底删除：

- 不创建欢迎消息；
- 不写入消息表；
- 不通过 WebSocket 广播；
- 不在客户端做欢迎消息特殊展示。

`room.chat_mute` 仍然保留，因为它是聊天权限控制事件，不是聊天内容。

## 4. 统一事件格式

删除 `event_version`，所有事件使用事件自身的 `version` 和 `version_scope`：

```json
{
  "type": "room.participant_count",
  "version": 42,
  "version_scope": "participant_count",
  "participant_count": 1500
}
```

签到开始必须携带签到实例 ID：

```json
{
  "type": "room.check_in_started",
  "version": 1,
  "version_scope": "check_in:128:started",
  "check_in_id": 128,
  "check_in": {
    "deadline": "2026-09-02T12:00:00Z"
  }
}
```

主持人签到统计也必须单独递增：

```json
{
  "type": "room.check_in",
  "version": 17,
  "version_scope": "check_in:128:result",
  "check_in_id": 128,
  "check_in": {
    "checked_in_count": 450,
    "user_id": 1008
  }
}
```

## 5. 快照版本水位

删除 `snapshot_version`，快照不再拥有自己的版本号，只返回各状态流的最新版本水位：

```json
{
  "type": "room.snapshot",
  "room": {},
  "versions": {
    "participant_count": 42,
    "participant_members": 27,
    "host_presence": 4,
    "host_transfer": 3,
    "speakers": 9,
    "participant_mute": {
      "1008": 12
    },
    "speaker_invite": {
      "1008": 3
    },
    "audio_mute": 5,
    "chat_mute": 2,
    "raised_hand_count": 11,
    "check_in": {
      "id": 128,
      "started": 1,
      "result": 17
    }
  }
}
```

客户端按字段合并：

- 人数只比较 `participant_count`；
- 成员只比较 `participant_members`；
- 主持人只比较 `host_transfer`；
- speakers 只比较 `speakers`；
- 指定成员静音只比较 `participant_mute[user_id]`，指定用户邀请只比较 `speaker_invite[user_id]`；
- 签到只比较对应 `check_in_id`；
- 低版本快照不能清除新签到按钮；
- 任意事件丢失都不能触发全局 `/room` 重拉。

快照合并必须是字段级的 compare-and-apply：对每个状态字段读取本地已处理版本 `L` 和快照水位 `S`，仅当 `S >= L` 时应用该字段，并把本地水位更新为 `S`；`S < L` 时丢弃该字段。快照开始请求后到响应前收到的实时事件，必须先进入事件处理队列；快照应用与事件应用在同一串行执行器中完成，避免“快照覆盖实时事件”的竞争。事件处理失败时不得推进对应水位，必须记录原始 payload 和解析错误。

## 6. 服务端改动

涉及文件：

- `internal/handler/live.go`
- `internal/handler/live_realtime.go`
- `internal/handler/live_room.go`

删除：

- `roomSnapshotVersions`；
- `nextRealtimeEventVersion`；
- `roomSnapshotVersion`；
- `event_version`；
- `snapshot_version`；
- 全局事件断档判断；
- 无版本广播逻辑。
- 已有或临时加入的 ACK/回执发送、接收、等待、重试和统计逻辑；房间事件协议不定义 ACK 字段或 ACK 事件。

新增按直播间隔离的事件版本管理，至少覆盖：

```go
type liveEventVersions struct {
    ParticipantCount   uint64
    ParticipantMembers uint64
    HostPresence       uint64
    HostTransfer       uint64
    Speakers           uint64
    AudioMute          uint64
    ChatMute           uint64
    RaisedHandCount    uint64
    CheckInStarted     map[uint64]uint64
    CheckInResult      map[uint64]uint64
    SpeakerInvite      map[uint64]uint64
    ParticipantMute    map[uint64]uint64
}
```

要求：

- 每个事件流独立、原子递增；
- 版本按 `live_id` 隔离；
- `check_in_started` 和 `check_in` 绑定 `check_in_id`；
- `participant_mute` 绑定 `user_id`；
- `speaker_invite` 绑定目标用户 ID；
- 直播结束后清理版本状态；
- 主持人转让使用独立的 `room.host_transferred`；
- 上麦使用 `room.speaker_changed`；
- 下麦使用 `room.speaker_removed`，不重新挑选 listeners；
- 删除入场欢迎消息的写库和广播；
- 日志记录事件类型、版本范围、版本号、接收人数、成功发送数、队列失败数。

### 6.1 版本分配、提交与发送顺序

- 状态变更、版本递增和待发送事件必须在同一数据库事务中写入持久化 outbox；事务回滚时版本和事件都不能对外可见。禁止只在内存中递增版本后再异步发送。
- 版本只保证同一 `live_id + version_scope` 内单调递增，不承诺不同事件流之间的全局顺序。
- 事务提交后再进入发送队列；发送失败不得回滚已提交业务状态，必须记录并由重连快照兜底。
- 同一事件流的队列按版本顺序发送；队列重试必须幂等，不能重复递增版本或重复写库。
- 广播接收者列表在发送任务入队时生成快照，连接随后断开只影响该连接，不阻塞其他连接。
- 单连接发送必须有有界队列、写超时和断开清理；慢连接被隔离，不能阻塞房间广播循环。

### 6.2 并发操作的裁决规则

同一房间的状态写操作按数据库事务提交顺序裁决；同一目标用户的互斥操作必须锁定该用户的房间成员行（或使用等价的乐观版本/CAS），失败时返回明确的 `409 state_conflict`，不得产生事件：

- 邀请接受、邀请拒绝、主持人取消邀请：只有待邀请状态仍匹配时才允许变更；先提交者生效，后提交者收到冲突。
- 上麦、移至听众、主动下麦、踢人：只有当前角色匹配时才允许变更；重复请求幂等返回当前状态，不重复广播。
- 主持人转让：锁定房间主持人和目标成员，确保一个事务内完成原主持人、新主持人角色变更，并按既定事件顺序发送；并发转让只有一个成功。
- 签到发起：同一房间同一时刻只允许一个进行中的签到；重复发起返回已有签到或明确冲突，不重复发送 `room.check_in_started`。
- 签到提交：以 `(check_in_id, user_id)` 唯一约束保证幂等；重复提交不重复增加人数或发送统计事件。
- 成员进入、离开、踢出与预览池补位：在同一成员/预览池事务中完成，先确定最终列表再递增对应版本，禁止并发任务各自补位后互相覆盖。

### 6.3 事件发送与客户端处理的边界

- 服务端事件表示“已提交的事实”，发送流程不等待客户端反馈，也不因单个客户端异常而重发或阻塞全员事件。
- 客户端以 `(type, version_scope)` 作为去重键：版本小于等于本地水位的事件直接丢弃，版本更大才应用并推进水位。
- 事件 payload 必须自洽；列表类事件携带该事件所需的完整最终列表，避免客户端依赖多个事件的到达顺序。
- 事件版本已推进但发送失败时，不再补发旧事件；客户端通过建连/重连/周期快照按水位收敛。

### 6.4 可恢复状态与一次性通知

事件分为两类，避免把无法由快照恢复的一次性通知误当成持久状态：

- 可恢复状态：人数、成员、主持人、speakers/预览池、静音、禁言、举手计数、进行中的签到和直播生命周期。
  这些状态必须出现在 `room.snapshot` 及其版本水位中。
- 一次性通知：`room.kicked` 等只对当前连接有意义的通知。被踢用户即使漏收通知，后续任何
  `/room`、WSS ticket 或 join-token 请求也必须由服务端按成员状态拒绝，并返回明确的业务错误；不能
  依赖一次性事件保证安全性。

主持人缺席状态必须由服务端基于带租约/代次的 heartbeat 判断：旧 heartbeat 不能把新连接重新标记
为在线，恢复在线和再次缺席各自只在状态真正变化时递增 `host_presence`。

任何“提交成功但事件未发送”的故障都必须能通过快照恢复；任何“事件已发送但客户端未处理”的故障都
必须能通过客户端版本去重和后续快照收敛。

## 7. Flutter 改动

涉及文件：

- `lib/features/live/domain/live_realtime_event.dart`
- `lib/features/account/domain/account_models.dart`
- `lib/features/design/presentation/live_room_page.dart`
- `lib/features/design/presentation/live_room_livekit.dart`

删除：

- `_lastRealtimeEventVersion`；
- `_lastRoomSnapshotVersion`；
- 全局事件断档检测；
- `event_version` 解析；
- `snapshot_version` 解析；
- 因全局版本跳跃触发 `/room` 的逻辑；
- 自动欢迎消息展示逻辑。

新增：

```dart
final Map<String, int> _latestEventVersions = {};
```

版本键示例：

```text
participant_count
participant_members
host_presence
host_transfer
speakers
check_in:128:started
check_in:128:result
participant_mute:1008
speaker_invite:1008
```

客户端必须新增处理：

- 主持人转让；
- 上麦和下麦；
- 独立签到开始版本；
- 主持人签到人数版本；
- 快照按各状态版本水位合并；
- 低版本快照不得覆盖新签到、新主持人或新 speakers。

客户端同时删除所有 ACK 相关代码：不发送事件回执、不等待服务端回执、不因未收到回执而重发事件，
也不维护 ACK 超时、重试或统计状态。事件是否最终收敛只通过事件版本去重和建连/重连/周期快照校准保证。

## 8. 听众预览池规则

1. 当前 listener 总数少于 10 人：正常广播完整听众列表；新 listener 进入可以补足预览池。
2. 当前 listener 总数达到或超过 10 人：普通 listener 进入后不重新挑选预览池，只更新 `participant_count`。
3. 有人上麦：广播全部 speakers 加最多 10 名固定 listeners。
4. speakers 达到 10 人：不返回 listeners。
5. 预览池成员离开或被踢：广播移除，后端补位后返回完整可见列表。
6. 用户下麦：只更新 speakers，不重新挑选 listeners。
7. 已达到 10 人后，只有预览池成员离开/被踢导致空位时才补位并广播；不能因为普通 listener
   进入而主动替换现有预览成员。少于 10 名 listener 时，新进入者可以直接进入预览池并广播。

预览池是服务端维护的房间状态，不是客户端临时计算结果。加入、离开、踢出、上麦等并发操作必须
在同一房间锁/事务内读取并写回最终池；广播 payload 携带完整最终列表和 `speakers`，客户端按
`speakers` 版本整体替换，不能对列表做基于到达顺序的局部猜测。

## 8.1 客户端根据讲话状态调整预览顺序

当没有新成员上麦、服务端没有广播新的听众列表时，客户端使用 LiveKit 的
`ActiveSpeakersChangedEvent` 监听当前正在讲话的 speaker，并在本地调整可见列表顺序：

- 正在讲话的人放到当前可见列表最前面；
- 只调整当前已经在 speakers 或固定 listeners 列表中的成员顺序；
- 不因为讲话状态把预览池外的普通 listener 拉入列表；
- 不发送 WebSocket 广播；
- 不增加事件版本号；
- 不触发 `/room` 重拉；
- 讲话停止后恢复原有稳定顺序，避免列表不断抖动。

该功能只适用于能通过 LiveKit 音频轨道检测到的 speaker。普通 listener 没有发布音频，客户端无法判断其是否讲话，也不应据此改变预览池。

客户端实现要求：

1. 复用现有 `ActiveSpeakersChangedEvent` 监听，不新增服务端事件。
2. 仅当排序结果真正变化时调用 `setState`。
3. 对连续讲话事件做约 100--300ms 的节流或合并，避免高频重建 UI。
4. 最多处理当前可见的 10 个预览位置，保持计算量为 O(10)。
5. 组件销毁、LiveKit 重连和离开房间时清空讲话状态。

在 1500 人房间中，LiveKit 只向客户端提供本地需要的 active-speaker 状态，服务端不产生额外扇出，因此不会带来明显的服务器流量压力。客户端压力主要是少量列表排序和局部 UI 重建，按上述节流后可以忽略。

## 9. 数据库与签到要求

- 签到记录写入和 `checked_in_count` 更新保持在同一事务中；
- 数据库写失败必须记录 `live_id`、`user_id`、错误信息；
- 主持人专属 `room.check_in` 不得推进其他事件版本；
- 签到发起、签到提交、签到统计分别记录必要日志；
- 客户端收到 `room.check_in_started` 后立即显示按钮，不等待 `/room`；
- 旧快照不能覆盖已处理的实时签到状态。

## 10. WSS 建连与重连后的全量快照

用户进入房间并完成 WSS 连接后，客户端必须主动拉取一次全量房间快照，用于建立完整初始状态。WSS 断线重连成功后，也必须主动拉取一次全量快照，用于校准断线期间可能丢失的状态。

流程如下：

```text
进入房间
  -> WSS 连接成功
  -> 拉取一次全量 room.snapshot
  -> 保持接收实时事件，并按版本水位合并快照

WSS 断线
  -> 重连成功
  -> 拉取一次全量 room.snapshot
  -> 保持接收实时事件，并按各事件版本水位合并快照
```

要求：

- 每次连接成功只拉取一次；
- 每次重连成功只拉取一次；
- 快照请求不能因为普通实时事件而循环触发；
- 快照必须携带各事件流的版本水位；
- 客户端按事件范围合并快照，不能用全局版本判断整份快照；
- 快照请求期间收到的实时事件必须保留，不能被返回较晚的旧快照覆盖；
- 重连校准不重新广播全员事件；
- 统一由客户端在 WSS 成功/重连成功后主动拉取快照；服务端不再额外自动补发同一份建连快照，避免一次连接产生两份全量快照；
- 建连和重连快照均不得触发欢迎消息或普通聊天事件。

为控制流量，快照只针对当前连接用户返回，不广播给房间其他用户。若快照请求失败，客户端应按现有重试退避策略重试，并保留当前本地状态，不因失败清空签到按钮或预览列表。

### 10.1 长连接期间的周期性快照校准

为了防止客户端长时间运行后因偶发丢事件、状态处理异常或 LiveKit/WebSocket 短暂异常而产生偏差，客户端在 WSS 长连接保持期间应增加低频周期性快照校准。

建议规则：

- 连接稳定后每 5 分钟校准一次；
- 每个客户端首次校准时间增加 0--60 秒随机抖动，避免同时请求；
- 只在直播间页面处于前台且 WSS 已连接时执行；
- 同一时间只允许一个快照请求，未完成时不重复发起；
- WSS 断线、重连成功、进入后台时暂停定时器；
- 重连成功后的快照不计入周期校准次数；
- 直播结束、离开房间或页面销毁时取消定时器；
- 周期校准失败采用退避重试，不立即连续请求。

周期校准的作用是兜底，不是实时驱动机制：

- 不替代 `room.check_in_started` 等实时事件；
- 不因为周期快照触发全员广播；
- 不因为任意事件版本跳跃而立即拉取；
- 快照仍必须按各事件版本水位合并；
- 低版本快照不能覆盖期间已处理的新签到、新主持人、新 speakers 或新人数。

1500 人同时在线时，5 分钟周期并加入抖动后，平均每秒约 5 个快照请求，远低于事件广播压力。若快照响应体较大，可进一步将周期调整为 10 分钟，或按服务端观测到的请求量动态调整。

## 11. 直播间 HTTP 动作（不属于实时事件）

以下接口是用户操作或数据查询，不直接使用事件版本，但成功后必须触发对应的独立状态事件：

| 接口动作 | 功能描述 | 成功后的状态同步 |
| --- | --- | --- |
| 创建/更新/结束直播 | 管理直播基本信息和生命周期 | 结束时发送 `room.ended` 或结束快照 |
| `GET/POST /room` | 加入直播并返回当前用户快照 | 进入后由客户端在 WSS 成功后再拉一次快照 |
| `POST /ws-ticket` | 获取 WebSocket 短期票据 | 不产生房间事件；需记录 429/409/超时 |
| `POST /join-token` | 获取 LiveKit 加入凭证和发布权限 | 不产生房间事件；权限以服务端角色为准 |
| `POST /leave` | 主动离开直播 | 更新人数；可见成员离开时更新成员/预览池 |
| `POST /raise-hand` | 听众举手或取消举手 | 更新主持人端 `room.raised_hand_count` |
| `GET /members` | 主持人查看完整成员列表 | 查询接口，不广播 |
| `GET /raised-hands` | 主持人查看举手详情 | 查询接口，不广播 |
| `POST /raised-hands/reject-all` | 主持人拒绝全部举手 | 更新举手计数事件 |
| `GET /host-transfer-candidates` | 获取可转让主持人的 speaker 列表 | 查询接口，不广播 |
| `POST /speakers/:id/approve` | 主持人批准听众上麦 | 发送 `room.speaker_changed` |
| `POST /speakers/:id/invite` | 主持人邀请听众上麦 | 仅目标用户发送 `room.speaker_invite` |
| `POST /speaker-invite/accept` | 听众接受上麦邀请 | 全员发送 `room.speaker_changed` |
| `POST /speaker-invite/decline` | 听众拒绝上麦邀请 | 仅目标用户更新邀请状态 |
| `POST /speakers/:id/remove` | 主持人将 speaker 移至听众 | 全员发送 `room.speaker_removed` |
| `POST /host/:id/transfer` | 转让主持人 | 全员发送 `room.host_transferred`，同步 speakers/角色状态 |
| `POST /mute-all` | 主持人全体静音/解除静音 | 发送对应音频或成员静音事件 |
| `POST /mute` | 当前主持人或 speaker 自己静音 | 发送 `room.participant_mute` |
| `POST /speakers/:id/mute` | 主持人控制指定 speaker 静音 | 发送 `room.participant_mute` |
| `POST /chat-mute` | 主持人开启/关闭全员禁言 | 发送 `room.chat_mute` |
| `POST /check-ins` | 主持人发起签到 | 全员发送 `room.check_in_started` |
| `POST /check-ins/current` | 当前用户提交签到 | 仅主持人发送 `room.check_in` |
| `GET /check-ins/export` | 导出签到记录 | 查询/导出接口，不广播 |
| `POST /heartbeat` | 主持人保活，避免直播被误判结束 | 更新主持人在线状态，必要时发送 `room.host_absent` |
| `POST /members/:id/kick` | 主持人踢出成员 | 被踢用户发送 `room.kicked`，可见成员变化发送成员事件 |

接口错误必须区分认证失败、权限失败、资源不存在、状态冲突、数据库错误和限流错误，不能统一转换为普通 `failed`。

## 12. LiveKit 媒体与连接状态

以下状态由 LiveKit SDK 负责，不使用房间 WebSocket 事件版本：

- `ActiveSpeakersChangedEvent`：本地调整讲话者排序；
- 房间连接、重连、恢复和断开事件：更新客户端连接 UI，并触发一次全量快照校准；
- 音轨订阅、取消订阅、发布和取消发布：处理音频播放和权限变化；
- LiveKit Data topic=`chat`：普通聊天消息，不进入房间事件版本。

服务端的 `room.audio_mute`、`room.participant_mute` 只负责业务权限和房间状态；LiveKit 的实际发布权限和音频轨道状态仍以 LiveKit 连接状态为准。

## 13. 测试清单

必须验证：

1. 人数事件丢失不触发签到 `/room` 重拉。
2. 人数高频变化不影响签到按钮。
3. 主持人签到人数只更新主持人端。
4. 主持人转让所有听众都能收到。
5. 主持人转让不广播全量快照。
6. 上麦更新 speakers 和预览池。
7. 下麦不重新选择 listeners。
8. 预览池成员离开后正确补位。
9. 旧快照不能覆盖新签到。
10. 多轮签到不会互相覆盖。
11. 重连快照能按各事件版本恢复状态。
12. 1500 个连接同时接收时，各版本流仍单调递增。
13. 队列满、发送失败、连接断开、客户端解析失败都有日志。
14. 普通聊天完全不经过房间事件系统。
15. 用户进入直播间不会产生欢迎消息。

## 14. 发布要求

这是破坏性协议升级：

- 服务端和客户端必须同步发布；
- 所有用户必须升级到新版本；
- 不保留旧字段兼容逻辑；
- 不发布 ACK/回执协议；客户端和服务端残留的 ACK 代码必须在上线前删除；
- 发布前确认旧版本用户已被阻止进入或强制更新；
- 发布后重点观察签到事件发送成功率、队列失败、客户端解析失败、签到按钮展示率、`/room` 请求量、WebSocket 重连和 429 数量。

最终目标：每个事件只维护自己的版本、只更新自己的状态、只校验自己的新旧，任何事件都不能影响其他事件。

## 15. 对其他直播间功能的影响

本次不是只替换版本字段，还会影响进入/重连、角色变更、预览池、签到、成员管理和静音控制等功能。以下功能必须同步修改：

| 功能 | 是否受影响 | 需要修改 |
| --- | --- | --- |
| 进入直播间 | 是 | WSS 成功后主动拉一次全量快照，不能只在建连前拉 `/room` |
| WSS 重连 | 是 | 重连成功后主动拉一次全量快照 |
| 服务端建连补快照 | 是 | 删除自动 `enqueueRealtimeSnapshot`，避免和客户端主动快照重复 |
| 主持人转让 | 是 | 使用独立 `room.host_transferred`，不依赖完整快照推断 |
| 邀请上麦 | 是 | 只向目标用户发送 `room.speaker_invite` |
| 接受邀请上麦 | 是 | 广播 `room.speaker_changed`，不能只广播快照 |
| 移至听众/主动下麦 | 是 | 广播 `room.speaker_removed`，不重新挑选预览池 |
| 预览池成员离开/被踢 | 是 | 继续补位，但使用独立成员/预览状态事件 |
| 人数变化 | 是 | 只更新 `room.participant_count`，不触发其他事件重拉 |
| 签到开始 | 是 | 使用独立 `check_in:{id}:started` 版本 |
| 主持人签到人数 | 是 | 使用独立 `check_in:{id}:result` 版本，仅发主持人 |
| 签到按钮显示 | 是 | 由 `room.check_in_started` 直接驱动，不等待快照 |
| 静音/禁言 | 是 | 各自独立版本，不能影响签到或成员快照 |
| 举手审核 | 是 | `raised_hand_count` 独立版本；审批上麦后发送 `speaker_changed` |
| 踢人 | 是 | 被踢用户收 `room.kicked`，其他用户只收成员/预览变化 |
| 主持人缺席 | 是 | `host_presence` 独立版本 |
| 讲话排序 | 是 | 仅客户端根据 LiveKit active speaker 调整顺序，不产生服务端事件 |
| 自动欢迎消息 | 是 | 完全删除写库、广播和客户端展示 |

### 15.1 进入和重连流程调整

当前客户端如果采用“先拉 `/room`、再连接 WSS”的流程，需要调整为：

```text
进入直播间
  -> 建立 WSS
  -> WSS 连接成功
  -> 拉一次全量 /room 快照
  -> 持续接收实时事件并按版本水位合并

WSS 断线
  -> 重连成功
  -> 拉一次全量 /room 快照
  -> 持续接收实时事件并按版本水位合并
```

服务端不能同时在 WSS 建连时自动发送一份快照、客户端又主动拉一份快照，否则一次连接会产生两份全量快照。统一由客户端在 WSS 成功和重连成功后主动拉取。

当前 `Room` 接口会记录一次参与者进入。重连校准不能重复增加人数或重复执行进入副作用。实现时应满足以下任一方案：

- 首次进入使用现有 `Room` 接口，建连/重连使用只读快照接口；
- 继续使用 `Room` 接口，但已存在参与者时不得重复计数、改变角色或触发进入广播。

### 15.2 明确不受影响的功能

以下功能业务语义不变：

- 直播创建、编辑、列表和封面；
- 直播密码校验；
- WebSocket ticket 认证机制本身；
- LiveKit join-token 生成及权限判断；
- 普通聊天发送、接收、缓存和聊天 UI；
- 签到导出；
- 主持人 heartbeat；
- 账号、钱包及其他非直播功能。

虽然业务语义不变，但 WebSocket ticket、join-token、heartbeat 的错误日志必须保留，重点区分 `429`、`409`、超时、认证失败、权限失败和数据库错误。

### 15.3 联动验收要求

上线前必须验证：

1. 首次 WSS 成功只产生一次客户端快照校准。
2. 每次重连成功只产生一次客户端快照校准。
3. 重连快照不会重复计数或改变用户角色。
4. 接受邀请、移至听众和下麦均使用独立事件，不再发送通用快照替代。
5. 主持人转让后原主持人、新主持人和所有听众的角色一致。
6. 普通聊天仍完全走 LiveKit Data。
7. 用户进入不会创建欢迎消息或产生消息广播。
