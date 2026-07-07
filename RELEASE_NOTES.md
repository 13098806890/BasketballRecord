# Release Notes

## 1.33 (2026-07-08)

### 新增

- **数据范围多选**：比赛详情页「数据范围」改为多选模式，可同时选中多个节次或全选/全不选，统计数据按所选节聚合。
- **比赛时长显示**：比赛详情比分下方显示实际比赛时长（排除暂停和节间休息）。
- **列表显示比赛起止时间**：比赛记录列表改为显示「开始时间 - 结束时间」格式。

### 改进

- **去调试输出**：移除 AI 分析 prompt/summary debug print 和统计重建 debug print。

## 1.32 (2026-07-04)

### 新增

- **文件拆分与 ViewModel 重构**：GameView、SavedGameDetailView、RosterView 等大文件拆分为独立子文件，GameView 核心状态提取到 GameViewModel。
- **AI prompt 多语言本地化**：新增 45 个 i18n key，所有 10 种语言 AI 提示词不再含硬编码中文。
- **手动结束节次确认**：时间/比分条件未满足时结束节次会弹出确认 alert。
- **统计系统安全性提升**：CoreData 存储改用 diff+upsert 避免全删全插风险，fatalError 改为 throw，关键路径添加错误日志。

### 修复

- putbackMade/putbackMissed 篮板改为前场篮板计法
- scoringCodes/pointMap 补齐 5 种投篮类型
- resolvedPlayerID 排序不一致导致匹配错人
- analyzer.analyze() 重复计算缓存
- putbackMissed 篮板统计一致性
- AnyView 改为 @ViewBuilder 提升性能
- 多语言 .strings 文件重复条目清理
- 自动保存修复、结束节次确认 alert
- **球队记分模式每节统计为 0**：GameView 中 team mode 的 `addEvent` 传入 `playerID: nil`，导致日志丢失球队 UUID，SavedGameAnalyzer 无法按节归类。修复：传入 teamID 代替 nil，Analyzer 增加 `game.resolvedTeamID(from:)` 文本反查兜底，`aggregateStats`/`fouls`/`score` 按节从 `periodAnalysis` 读取数据
- **导入 UUID 重映射遗漏**：`remappedSnapshot` 仅查 `playerIDMap`，团队 UUID 存于 `playerID` 的日志无法被 `teamIDMap` 重映射。修复：同时查 `teamIDMap` 和 `playerIDMap`，并将 `relatedPlayerID` 也加入重映射
- **AI prompt 中文硬编码全部 i18n**：scoringRunEvents() 中 20 处硬编码中文替换为 7 个新 i18n key（scoring_run / both_miss_streak / rebound_streak / miss_streak / assist_streak / and_one / lead_format），10 语言全覆盖。
- **连续得分合并到比分时间线**：scoringRunEvents() 改为返回带时间戳的结构化数据，所有连续得分/连续不中事件合并到统一时间线，移除独立「连续得分分析」section。
- **比分时间线加队名**：每个分差值都带主客队名。
- **AI 规则 req_16/17/18**：req_16（每次比分带队名）、req_17（非时间模式不提及具体时间点）、req_18（不按时间枚举得分，按连续得分和势头分组，每节 2-4 句）。
- **比赛模式感知解说**：AI 根据每节结束条件调整风格，比分/手动模式自动省略时间点。
- **AI prompt debug prints**：添加 [AI_PROMPT] 和 [AI_SUMMARY] 调试输出。

---

## 1.31 (2026-07-02)

### 新增

- **复合事件系统**：新增 `stat.assistTwoMade`（助攻2分）、`stat.assistThreeMade`（助攻3分）、`stat.stealTurnover`（抢断失误）三种复合 event code。语音识别"xx助攻xx得分"、"xx抢断xx"不再拆成两条独立日志，改为单条自包含的"主谓宾"事件（主语→playerID，宾语→relatedPlayerID）。`relatedAction` 属性自动映射宾语统计（得分者+2/+3分、失误者+1误）。
- **加时赛**：比赛进行中或结束后点击 "+" 可选"加时赛"，支持设置加时节数（1-10）、每节结束条件（时间/比分/手动）、每节时长/比分上限。加时节显示为 OT1、OT2（所有语言统一）。
- **AI 总结增强**：新增【比分变化时间线】数据节（按节分组，每条含时间、球员、得分、实时领先方）。SDK 输出模型切换为 DeepSeek Chat，支持 10 种语言 AI Prompt 本地化。`ScoringRunAnalysis` 按 `period_end` 事件划分节次。
- **ELO 天梯分按场次顺序对手真实积分计算**：每场比赛更新全部参赛球员的天梯分，后续比赛的对手强度基于真实赛后天梯分，不再使用初始 1500。
- **加时赛节次识别**：`SavedGame` 新增 `originalPeriodCount` 字段，加时节显示为 OT1/OT2 而非第5节/第6节。`periodDisplayName()` 方法统一所有显示位置。
- **球员生涯胜率**：生涯统计卡片新增胜率显示（Wins / Win Rate）。
- **过往比赛向后兼容**：恢复 `startedPeriodNumber`/`endedPeriodNumber`（消息文本检测节次）、`isScoringMessage` 等函数，旧比赛（无 eventCode）也能正确按节统计。`originalPeriodCount` decode 兼容旧数据。

### 重构

- **去除所有语言依赖的硬编码消息文本解析**：`StatAction.parseLog()`、`LoggedAction.parse(from:)`、`isScoring`、`startedPeriodNumber`/`endedPeriodNumber` 的 fallback 改为彻底基于 `eventCode`。`resolvedTeamID(from:)` 去掉 "主队/客队/zhudui/kedui" 硬编码关键词。`LoggedAction` 去除 `suffix`/`englishSuffix`/`suffixCandidates` 等全部语言相关的硬编码文本。
- **AI 提示词全量本地化**：全部 10 种语言的 AI prompt（任务描述、逐节分析说明、14 条额外要求等 39 个 key）基于中文版本翻译完毕，`ai_prompt_req_4~15` 补齐。
- **球员统计卡片可折叠**：本场数据/生涯数据/场均数据三个 Section 使用 `DisclosureGroup`，默认展开，可独立折叠。

### 修复

- **语音双事件得分日志被压制**：`onDualAction` 中得分方的 `eventMessage: ""` 导致 `applyRecordOperation` 不写日志，改为双事件各自独立写入。
- **每节上场时间页面不显示**：`PlayerProfileView.computeStatsGroup` 选节时改用 `playingTimeByPeriod()` 取值，不再硬编码为 0。去掉 `isFixedPeriodMode ? "--" :` 三元。
- **SavedGameAnalyzer 缺少 putbackMade 等 12 种事件**：补全 layup/midRange/paint/putback/dunk Made/Missed、offensiveRebound、defensiveRebound 等 `LoggedAction` 事件类型，每节得分与全场保持一致。
- **AI 连续不中 streaks 不重置**：`bothMissStreak` 得分后未重置，改为得分时触发输出后置零。
- **AI 比分变化时间线时间负数**：`game.savedAt` 作为时间基准导致所有事件为负值，改为使用首条事件时间戳。
- **按比分模式不显示时长**：`periodEndCondition == .byScore` 时隐藏"每节时长"输入。
- **两套独立枚举不同步**：`LoggedAction` 和 `StatAction` 统计逻辑不一致，引发每节得分偏差。`EventLogEditSheet` 新增 `showsAssistButton` 等过滤。

## 1.30 (2026-06-26)

### 新增

- 勋章系统：每场比赛自动评选得分王、MVP、打铁王、篮板王、助攻王、三分王、效率王、连续三分、失误王、盖帽王共 10 种勋章，球员生涯页和比赛详情页均可查看，勋章数量自动累计。
- 球队模式数据修复：补全 V2 传输格式中缺失的球队模式字段，上传下载不再丢失球队统计数据。
- 云分享照片分离：照片通过独立 API 上传下载，避免请求体超限。

### 优化

- 照片压缩：自动压缩到 200KB 以内。
- 按钮 i18n：button_retry 补充全部 10 种语言翻译。
- 加载性能：数据编译和图片压缩移至后台线程。
- 每节上场时间：从比赛日志推导球员每节上场时间，不再显示 --:--。
- 语音规则优化：修正法语 contre-attaque 错映射、德语 rein 歧义、俄语 4 个误匹配；补全德/法/俄 stealTargetRule；补充各语言缺失的 pause/turnover 关键词及本地化 undo/redo。

## 1.29 (2026-06-24)

### 新增

- **事件流编辑（Pro）**：比赛详情页新增编辑模式，可查看按节和分钟分组的事件流，左滑修改或删除事件。支持新增事件（精确时间/每节时间两种模式），自动重算统计数据、上场时间和正负值。事件行显示实际时间和节内时间。Pro 订阅功能。
- **Pro 订阅页更新**：新增事件编辑功能说明卡片。
- **云分享上传**：支持将球员/球队/比赛打包上传至云端生成分享链接，对方输入 UUID 即可导入。
- **云分享导入**：Import 页面新增 Cloud Share 模式，粘贴 UUID 从云端拉取数据。

### 修复

- **无上场时间/零数据球员过滤**：生涯统计跳过上场时间为 0 且全部数据为 0 的比赛，不影响出场统计准确性。
- **比赛结束时自动结束当前节**：若节次仍在运行，先记录节结束事件再记录比赛结束。
- **新增事件节次错位**：使用每节时间新增事件时，正确设置事件所属节次，Analyzer 不再靠时间戳位置推断。
- **事件编辑 Pro 限制**：非 Pro 用户编辑按钮灰色+锁图标，点击弹出订阅页。
- **编辑历史审计轨迹**：每次新增/修改/删除事件均记录到 `GameSnapshot.editHistory`，NEW/EDITED/DELETED 标记持久化且随比赛保存。删除事件可左滑恢复，修改事件可左滑回到原始状态。
- **编辑历史 UT 覆盖**：新增 5 个单元测试覆盖新增、修改、删除、恢复、统计排除等核心流程，直接操作 `store` 验证数据层。
- **球员详情页事件流同步**：从比赛记录进入球员详情时，事件流标记（NEW/EDITED/DELETED）与编辑模式保持一致。
- **云分享 DeviceCheck 验证移除**：暂时跳过 Apple DeviceCheck 验证以恢复上传功能，后续版本再重新接入。
- **云分享支持球员照片**：上传时可选择是否包含球员照片，大于 500KB 自动压缩。
- **云分享上线**：现在可以将球队和比赛信息上传到云端生成分享链接，对方输入 UUID 即可一键导入球队和比赛数据，无需额外注册。支持含照片/不含照片两种导出模式。
- **云分享上传优化**：将元数据和照片拆分为独立请求，避免 "requesttoolarge" 错误；新增上传进度条（逐张照片状态）。
- **云分享 Upload New 按钮**：已上传的分享页面新增"重新上传"按钮，可清空旧分享并重新上传。
- **云分享导入修复**：比赛导入页支持解析 `CloudShareBundle` JSON 格式；剪贴板 UUID 自动填入并弹窗提示。
- **比赛详情页加载优化**：`SavedGameAnalyzer.analyze()` 改为 `.task` 异步计算，导航不再卡顿，加载期间显示指示器。
- **云分享 Upload New 清空持久化**：重新上传时同时清除 UserDefaults 旧 UUID，防止 .task 重跑误恢复。
- **国际化新增**：`cloudshare_clipboard_detected_uuid`、`cloudshare_include_photos`、`cloudshare_upload_new_button` 等 key 补齐 10 种语言。

## 1.28 (2026-06-23)

### 架构

- **VoiceRules JSON 化**：移除 10 个 `VoiceRules_*.swift` 文件，改为 `VoiceRulesData.swift` 内嵌 JSON + `Resources/VoiceRules/` 源文件双源；JSON 数据按语言独立管理，便于编辑和跨平台复用。
- **VoiceRules 重构为静态实例**：移除 `VoiceRulesData.embeddedJSON` 内嵌 JSON 方式，10 种语言各自独立为 `VoiceRules_{lang}.swift` 静态实例文件，编译期类型检查，改错语法直接报错。
- **AppStore 中度拆分**：`AppStore.swift`（1451→687 行）拆分为 `AppStore+Player.swift`、`AppStore+Team.swift`、`AppStore+Game.swift` 三个 extension 文件，按 Player/Team/Game 职责分离 CRUD、合并、导入导出逻辑。
- **GameView 提取 LiveCollaborationManager**：`GameView.swift`（3081→2731 行）中蓝牙直播协作状态和协议处理逻辑提取到独立的 `LiveCollaborationManager`（401 行），通过 `@StateObject` + 回调闭包与 GameView 通信。

### 代码质量

- **去除 `unique()` 重复定义**：LiveCollaborationManager 改用 `private static func deduped` 类方法，消除与 GameView 的 `unique()` 重复。

### 新增

- **补篮和扣篮动作**：新增 `putbackMade/Missed`（补篮命中/不中）和 `dunkMade/Missed`（扣篮命中/不中）两种统计动作。补篮为篮板+两分复合动作；扣篮独立计数。全部 10 种语言语音规则、教程任务（28-31）、语音示例均已支持。
- **语音撤销/重做**：新增语音命令 `undo`（撤销）和 `redo`（重做），10 种语言对应关键词（撤销/撤回/アンドゥ/실행취소等）。
- **蓝牙投篮细类传输**：`BluetoothLiveStatAction` 新增 `layupMade/Missed`、`midRangeMade/Missed`、`paintMade/Missed`、`dunkMade/Missed`，蓝牙协同不再丢失上篮/中投/篮下/扣篮的细类数据。
- **AI 连续投篮不中数据**：预设分析新增两队合计连续投篮不中次数（`both_miss_streak`），阈值 6 次；`missedCodes` 补全 `dunkMissed` 和 `putbackMissed`。
- **`PlayerStats` 新增扣篮计数**：`dunkMade`/`dunkAttempts` 字段，含 CodingKeys 和 decoder 兼容。

### 修复

- **蓝牙 `.undo` 撤销 dualAction 不完整**：`applyLiveOperationPayload(.undo)` 改为优先从 undoStack 快照恢复，确保复合操作（助攻+投篮、抢断+失误）的两次统计都能正确回退；无快照时 fallback 到 `revertLastAction()`。

- **`gameScore` 使用 `totalRebounds`**：O/D 篮板模式下 `gameScore` 未计入 `offensiveRebounds`/`defensiveRebounds`，导致 ELO 积分偏差，改用 `totalRebounds` 合计三个篮板字段。
- **蓝牙 participant dualAction 竞态**：复合语音指令（助攻+投篮、抢断+失误）在 participant 端发两个独立 operation 导致第二个因 version 不匹配被拒绝；合并为单一 `dualAction` operation，原子化发送。
- **VoiceRecognizer 10 处 force-unwrap**：`Range(...)!` 和 `Int(...)!` 改用 `guard let`，消除极端输入下的崩溃风险。
- **换人撤销移除文本猜测**：`relatedPlayerID` 在全部生产路径已确保传入，移除 `revertLastAction` 中基于消息子串的脆弱 fallback，缺失时直接返回 false。
- **`remapDictionary` 碰撞合并**：导入时字典 remapping 若发生 key 碰撞，根据值类型执行对应合并策略（PlayerStats 求和、Date 取 min、数值求和），静默覆盖不再发生。
- **participant 按钮反馈**：手动记分时 participant 设备也能获得震动和分数脉冲反馈（此前 `submitLiveOperation` 返回 false 跳过了反馈）。
- **force-unwrap 清理**：`FileManager.default.urls(...).first!` 提取为 `documentsDir` 属性统一管理；`scfChatURL` 改为 computed property + `guard`。
- **测试 `UUID(uuidString:)` 安全化**：动态构造 UUID 的 helper 函数改用 `guard let` + `fatalError`。
- **`preferredPlayerNumber` 跨调用泄漏**：`processText` 入口提前重置，不依赖 `preprocessEnglishText` 路径。
- **`GameLogFormatter` 单测覆盖**：新增 7 个测试覆盖 extractEventCode、normalizedMessage、isScoring、periodNumber 等核心方法。
- **`VoiceRulesData` JSON 有效性测试**：新增测试遍历 10 种语言内嵌 JSON，确保全部解析成功。
- **O/D 篮板模式展示修复**：球员展示页面的篮板数全面改用 `totalRebounds`（`rebounds + offensiveRebounds + defensiveRebounds`），O/D 模式下不再显示 0。球员卡片分割为篮板卡（总/前/后）和助攻/抢断/盖帽卡。生涯/场均累计补上 O/D 字段。
- **补篮语音变体增强**：简体/繁体中文新增 `"不来"` 关键词，ASR 将"补篮"识别为"不来"时也可匹配。
- **蓝牙协同按钮修复**：记分页蓝牙按钮去掉多余的 `.disabled` 条件，未连接设备时点击弹出提示引导用户去设置页连接。

## 1.27 (2026-06-23)

### 新增

- **AI 总结云服务**：接入腾讯云 SCF + App Store Server API，订阅用户可直接生成 AI 比赛总结，无需自行配置 DeepSeek Key。每场比赛限一次，每日限 10 场；配置自有 Key 可解锁无限次数。
- **AI 设置说明**：设置页新增规则说明，无 API Key 也可用。
- **订阅安全增强**：购买时传递 `appAccountToken`（UUID），通过 iCloud Key-Value 跨设备同步；SCF 验证 Apple 签名数据中的 token，防止 transactionId 滥用。

### 架构

- **App Store Server API 集成**：SCF 通过 ES256 JWT 验证订阅 transactionId，Apple 签名数据不可伪造；同时验证 bundleId、productId、过期时间、退款状态、appAccountToken。
- **DeepSeek Key 零泄露**：Key 仅存在于 SCF 环境变量，App 经 SCF 代理调用 AI，用户无法直接获取 Key。
- **PurchaseManager 重构**：移除所有缓存兜底，订阅状态仅依赖 `Transaction.currentEntitlements`；`loadProducts` 添加 `isLoadingProducts` 防并发；去掉超时逻辑。
- **AIServiceProxy 简化**：移除缓存兜底，仅从 `currentEntitlements` 获取 transactionId；移除冗余的循环重试逻辑。
- **SCF 服务端限流**：每 transactionId 每天 10 次上限，每日自动清理计数；支持 `environment` 参数指定沙箱/生产环境。
- **代码结构优化**：`RosterView`（2200→1140 行）、`VoiceTutorialView`（1880→692 行）拆分为独立文件，提升可维护性。

### 修复

- **订阅状态刷新**：`checkSubscriptionStatus` 移除过期缓存兜底，仅以 `Transaction.currentEntitlements` 为准。
- **AI 按钮点击无响应**：修复非 Pro 用户按钮被禁用的问题；修复已有总结时视图不显示 alert 的问题。
- **订阅页面加载卡死**：`ProSubscriptionStoreView` 添加 `@ObservedObject` 监听产品加载完成自动刷新；不再重复调用 `loadProducts`。
- **语音指令页标题本地化**：`headerTitle`/`headerSubtitle` 从硬编码 switch 迁移至 `Localizable.strings`，10 种语言统一管理。
- **设置页拆分后引用完整**：确保 `localized()` 等模块级函数在拆分后文件正确可见。
- **`keepOriginalHintTaskIDs` 值对齐**：修复提取过程中数值不一致问题。
- **`appAccountToken` 初始化保护**：`NSUbiquitousKeyValueStore` 改为 `try?` 防止 crash，同时保留 iCloud 跨设备同步。
- **GameView 编译错误**：Swift 6.2 类型检查器限制，用 `AnyView` 包裹长链 alert 修饰器。
- **每日记录清理**：`ai_gen_records` 自动清理 7 天前记录，防止 UserDefaults 无限增长。

### 代码质量

- **存储层类型安全**：`safeWrite`/`safeRead` 移除 `game as! T` 强制向下转型，按独立路径 encode/trim，消除崩溃风险。
- **存储竞态修复**：引入 `saveGeneration` 计数器，防止被取消的 saveTask 在完成后错误清除 `dirtyKeys` 导致后续写入跳过 CoreData/game。
- **球员合并统计补全**：`mergedStats` 补充 `layupMade/Attempts`、`midRangeMade/Attempts`、`paintMade/Attempts`、`offensiveRebounds`、`defensiveRebounds` 共 10 个遗漏字段。
- **CoreData 状态同步**：`NSBatchDeleteRequest` 后追加 `context.refreshAllObjects()`，确保同一 context 中后续操作不读到过时对象。
- **CloudKit 临时文件清理**：`uploadGame` 中用 `defer` 确保上传完成后删除临时文件，防止 temp 目录无限增长。
- **PurchaseManager 初始化优化**：`init` 中 Task 先验证 `checkSubscriptionStatus` 再 `loadProducts`，减少 StoreKit 状态延迟；值未变时不触发 `@Published` 发布，避免 UI 无谓刷新；移除多余 `try?` 和废弃的 `synchronize()` 调用。
- **GameView 撤销节开始修复**：撤销 `event.period_start` 时正确关闭活跃 stints 和 match/period 计时，不再漏记上场时间。
- **GameSetupView 键盘收起**：`@FocusState` 替代 `UIApplication.shared.sendAction`，更 SwiftUI 化。

## 1.26 (2026-06-20)

### 新增

- **语音教程识别成功率**：completion 页面显示排除自由练习的识别成功率，90% 为通过线，已添加到全部 10 种语言。
- **语音匹配灵敏度设置**：设置页新增 Slider（0.3~1.0），用户可自定义 `nameSimilarity` 兜底匹配阈值，替代硬编码 0.6。
- **助攻+投篮双重语音事件**：语音识别支持「俊宏助攻老张两分」等复合指令，同队队友一次完成助攻+投篮记录，自动判断命中/未中，事件流显示完整描述（如「俊宏助攻老张两分命中」），10 种语言覆盖。
- **抢断+失误双重语音事件**：语音识别支持「老张抢断仔队」等复合指令，异队球员一次完成抢断+失误记录，10 种语言通过 `StealTargetRule` 配置提取目标球员（SVO 语言从右侧提取，SOV 语言从左侧粒子后提取）。
- **语音教程命令任务**：新增 4 个命令控制教学任务（开始一节、暂停、继续、结束一节），10 种语言完整的本地化提示。
- **语音教程助攻+投篮任务**：新增任务 20（助攻+投篮双重动作），10 种语言本地化引导。
- **前场篮板/后场篮板独立统计**：新增 `offensiveRebound` / `defensiveRebound` 两种统计类型，支持前/后场篮板分类记录；GameSetupView 新增 O/D 篮板模式切换开关。
- **复合指令语音说明**：VoiceInstructionView 新增「Combined Commands」栏目，演示助攻+投篮、抢断+失误两种复合指令用法，10 种语言本地化。
- **语音教程前场/后场篮板任务**：全部 10 种语言新增任务 26（前场板）和任务 27（后场板）。

### 改进

- **英文换人关键词新增**：添加 `quarter down`、`quarter end`；`force`/`forces` 作为犯规变体（ASR 常将 foul 识别为 force）。
- **letterPinyin 字母读音修正**：b→bi、e→yi、j→ji，更接近中文实际字母读音；`namePinyinVariants` 支持单字母名字生成 letterPinyin 变体。
- **拼音变体规则增加 m↔n 双向**：解决"妈田"(ma)与"那天"(na)首字母混淆匹配。
- **语音匹配阈值可配置**：Priority 3 nameSimilarity 兜底从硬编码 0.6 改为 `matchingThreshold` 属性，可通过设置页滑块调节。
- **语音规则新增结束节关键词**：简体/繁体中文「结束本节」「节结束」、英文「quarter done」、日文「クオーターエンド」、韩文「쿼터종결」、德文「viertel um」、西文「cuarto concluido」、法文「quart achevé」、意文「quarto concluso」、俄文「четверть завершена」，结束节命令直接映射到节次切换。
- **7 种语言补充统计指令模板**：日/韩/德/西/法/意/俄的 `VoiceCommandExamples` 指令模板现完整覆盖所有统计动作（助攻、盖帽、抢断、失误），解决教程提示为空的问题。
- **语音教程扩展至 27 个任务**：新增助攻+投篮双重动作任务（任务 20）、4 个命令控制任务（任务 21-24）及前场/后场篮板任务（任务 26-27）。
- **Fastfile API Key 解析优化**：新增 `resolve_api_key` 方法，按历史活跃顺序尝试多个已知 key_id/key_path，兜底扫描 `~/Downloads/AuthKey_*.p8`，适配不同开发环境。
- **清理过时文档**：移除 fastlane README 中已不存在的 `check_metadata` lane 说明。
- **双动事件合并为单条记录**：助攻+投篮事件不再产生两条记录，仅显示助攻行（含投篮描述），分数正常更新；抢断+失误同理仅显示抢断行，失误统计仍记录。
- **O/D 篮板模式下按钮布局调整**：抢断移至第四行，第一行变为助攻/前场篮板/后场篮板/盖帽；普通模式下 O/D 篮板关键词自动映射为普通篮板。
- **球队统计页面篮板数据拆分**：原 REB/BLK 行改为显示总篮板/前场板/后场板三列；原 AST/STL 行并入 BLK 显示助攻/抢断/盖帽；球员详情 tile 显示 `totalRebounds(off-def)` 格式。
- **TeamStatsView 宽度调整**：从 64 增至 80 以适应更多数据列。
- **中文投篮提示示例优化**：tutorial hint 中「老张两分进了」等 13 处改为「老张两分命中」，消除用户对匹配规则的困惑。
- **中文拼音变体增强**：新增「全场板」「全场篮板」及拼音变体；新增 `("ian", "uan")` 双向规则覆盖前(qian)↔全(quan)混淆场景。
- **默认 Tab 逻辑优化**：无球员/球队时默认切到球队管理页，否则默认显示计时器页；图标替换为 `dumbbell.fill`。

### 改进

- **多词关键词空格容错**：`findKeyword` 从精确字符串匹配改为正则表达式，ASR 输出无空格时（如 "infor"）也能匹配多词关键词（如 "in for"）。

### 修复

- **语音识别测试全面重构**：移除 `findEvent` 静态方法，全部 209 个单元测试使用真实 `VoiceRecognizer.processText()` 匹配逻辑，确保测试覆盖生产代码。
- **测试辅助方法回调同步等待修复**：`assertCmd`/`assertMatch` 在回调同步触发时不再跳过 `wait(for:)`，消除 XCTest「未等待预期」错误，修复 7 个换人命令测试在真实匹配逻辑下的失败。
- **拼音变体交集空格不匹配**：`generatePinyinVariants` 对中文拼音输出"bo bo"（带空格）与拉丁名字"bobo"（无空格）无法交集，新增无空格变体解决"波波"→"bobo"匹配失败。
- **多音字"地"漏配**：CFStringTransform 将"地"转为"de"而非"di"，`multiPronunciations` 新增"地"→`["de", "di"]`，修复"A地"→"ad"匹配失败。
- **matchPlayerIDsDebug 未使用 threshold 变量**：删除 dead code，消除 Xcode warning。
- **教程 completion 页成功率计算修复**：排除自由练习任务后按实际尝试次数计算成功率。
- **双动事件日志不产生独立投篮/失误行**：`onDualAction` 第二个操作传入空 `eventMessage`，避免事件流出现重复记录。
- **中文语音封盖识别增强**：新增「风盖」/「風蓋」关键词；拼音回退扩展为支持统计事件的 `generatePinyinVariants` 双向变体匹配；移除纯同音词条目（概貌、主攻、强段、失物、兰板、风盖）——由拼音变体覆盖。
- **Form 单元格分隔线缺失**：「球员编辑」页面身高/体重行因 HStack 包裹 TextField 导致分隔线消失，改用 padding+overlay 方案保留原始 Form 层级结构。
- **语音教程提示示例关键字不匹配修复**：全部 10 种语言 tutorial 提示中的示例短语重新对照 VoiceRules 逐一修正，删除不存在的投篮/统计/命令/换人关键词，确保用户学到的说法在语音识别中真实可用。
- **新增教程提示正确性单元测试**：`testTutorialHintsUseValidKeywords` 遍历 2000+ 条提示示例，按 `shot`/`stat`/`cmd`/`sub`/`made`/`miss` 分类自动验证每个示例是否包含对应的 VoiceRules 关键字，防止后续新增 task 或修改提示时混入无效短语。
- **GameSnapshot Codable 修复**：自定义 `init(from:)` 缺失 `showsOffensiveDefensiveRebound` 解码字段，导致重启后 O/D 模式状态丢失。
- **restoreLatestGameIfNeeded 快照恢复**：补充 `voiceRecognizer.currentSnapshot = snapshot` 调用，确保语音识别器状态与恢复的比赛一致。
- **O/D 篮板模式关键词过滤**：VoiceRecognizer 在 O/D 模式下移除通用篮板条目，避免「篮板」作为「前场篮板」子串误匹配；普通模式下 O/D 关键词映射为通用篮板。
- **繁体中文 bonusMade 模板修正**：`"{name}加罰進了"` 改为 `"{name}加罰命中"`，与 shotExamples 保持一致。

## 1.25 (2026-06-19)

### 新增

- **语音免费开放**：语音功能不再需要 Pro 订阅，所有用户可免费使用。
- **语音语言选择器**：设置页新增 10 种语音语言独立选择，可与 App 语言不同。
- **语音教程**：新增 19 个语音教学任务，覆盖投篮/统计/换人/自由练习，10 种语言本地化引导。
- **身高/体重单位设置**：支持 cm/ft-in、kg/lbs 切换，默认跟随地区系统设定。
- **管理 Tab 顺序调整**：新建 → 球员 → 球队 → 比赛分组 → 球员分组。

### 改进

- **语音说明全面重构**：删除硬编码内容，改用 `VoiceCommandExamples` 模板驱动生成，10 种语言统一管理。
- **语音命令模板集中化**：新建 `VoiceCommandExamples.swift`，所有指令模板（投篮/统计/换人）统一维护，语音说明和教程同时引用。
- **7 种语言 `{oppTeam}` 占位符修复**：日/韩/德/西/法/意/俄规则中使用 `{team}` 替代 `{oppTeam}`，修复球队前缀使用错误。
- **中文指令模板修正**：两分/三分/罚球/上篮/中投改为「进了」；助攻改用「传出助攻」；失误改用「走步」；犯规改用「犯规了」；新增「{team}{number}号两分」变体展示球队前缀。
- **繁体中文术语修正**：改用「抄截」「蓋帽」「替換」「傳出助攻」等匹配语音规则的关键词。
- **英文语音识别增强**：`to`→`2`、`know`→`no`、`mr`→`miss` 词边界替换；`X2`/`X3` 数字编码拆分。
- **中文投篮示例补充**：中投、篮下示例重新加入语音说明页面。
- **i18n 补全**：新增语音说明 6 个 section key 至 10 种语言。
- **`voice_tutorial_score` 格式修复**：9 种非英语语言补全 `%d/%d` 格式化参数。
- **删除孤悬 key**：移除 9 个 `.lproj` 中未使用的 `voice_tutorial_hint_name_shot`。

### 修复

- **X2/X3 号码拆分导致英文模式球员号码误拆**：`preprocessEnglishText` 中 `text.isEmpty` 保护缺失，修复后仅纯数字场景触发编码拆分。
- **`showsVoiceButton` 默认开启**：新用户默认可见麦克风按钮。

## 1.24 (2026-06-19)

### 新增

- **UI 布局重构**：底部 Tab 重新排序为「管理」「记分」「生涯」「设置」；生涯页新增「比赛记录」作为第三个子标签页，历史记录不再占用独立 Tab。
- **管理主页**：新增「管理」Tab，集中管理球队分组、球员分组、球队列表、球员列表、新建条目。
- **筛选状态持久化**：生涯页球员分组筛选器现在也会保存到 UserDefaults，下次启动自动恢复（仅 Pro 用户）。
- **展开/折叠状态修复**：比赛记录按月份展开/折叠状态现在在异步加载完成后才从 UserDefaults 恢复，修复历史记录页面状态不持久的问题。

### 改进

- **数据管理入口迁移**：设置页「数据管理」章节整体移至新的「管理」Tab，设置页不再包含球队/球员/分组管理入口。
- **HistoryView 可嵌入**：`HistoryView` 新增 `embedInNavigation` 参数，支持不嵌套 `NavigationStack` 直接嵌入父视图。

## 1.23 (2026-06-17)

### 新增

- **ELO 天梯积分系统**：球员生涯页面新增 ELO 段位计算，基于比赛胜负、对手强度、个人 Game Score 贡献联动调整积分。支持按选中比赛范围实时计算。
- **段位系统**：积分对应青铜/白银/黄金/铂金/钻石/大师/最强王者段位，显示段位色徽章，10 种语言均已本地化。
- **ELO 历史与计算详情**：点击 ELO 徽章查看每场比赛积分变化，点进单场可查看完整公式推导（对手平均 ELO、预期得分率、GS 系数等）。
- **球员生涯分组筛选**：选择比赛分组后，球员列表仅显示该组比赛内上场的球员。
- **球员列表排序**：支持按总得分、场均得分、正负值、ELO 排序，支持升降序切换，右侧显示当前排序值。
- **宣传页面 i18n 更新**：10 种语言 landing page 全部上线，App Store 链接、推广页 footer 链接完善。

### 修复

- **GS 系数算法修正**：非对称处理胜负——打得好时赢多加输少扣，打得差时赢少加输多扣。负 GS 不再导致异常加分。
- **ELO 弹窗双闪修复**：天梯积分徽章点击后界面重复弹窗问题。

### 其他

- App 下载价格改为免费（Free），结合订阅内购模式。

### 改进

- **非 Pro 用户分组隔离**：设置页分组管理入口点击后弹出订阅页；球员/球队分组筛选器对非 Pro 用户完全隐藏，忽略已保存的筛选状态，显示全部数据。
- **球队统计零比赛不显示**：生涯页球队卡片在筛选后比赛数为 0 时不再展示，与球员行为保持一致。
- **球员管理页增加筛选**：球员编辑页面顶部工具栏新增球员分组筛选器。
- **语音设置入口开放**：设置页语音入口不再受 Pro 限制，所有用户可进入；内部"显示语音按钮"开关改为 Pro 控制，非 Pro 用户点击弹出订阅页。

### 移除

- **ELO 段位系统**：去除青铜/白银/黄金/铂金/钻石/大师/最强王者段位及对应颜色 UI，ELO 徽章改为 `.ultraThinMaterial` 样式。

## 1.22 (2026-06-14)

### 新增

- **英文语音全面优化**：重写英文语音识别流水线，统一球员匹配、进退状态检测、动作执行为单一入口 `resolvePlayer`。
- **球队数据对比优化**：篮板/盖帽、助攻/抢断、犯规/失误 拆分为独立行显示；每项数据独立比较，占优者以蓝色标出。
- **命中率精度提升**：球队数据和球员数据命中率改为显示小数点后 1 位。
- **球员摘要信息增强**：比赛记录球员 cell 新增正负值 (+/-) 和每次出手得分 (Points/Shot)。

### 架构

- **`VoiceRules` 新增高级匹配配置**：`useLevenshteinMatching`/`levenshteinThreshold`（编辑距离模糊匹配，英文启用）、`useAnchorMatching`/`anchorWords`（锚点词切分匹配，英文启用），各 10 种语言独立配置。
- **语音匹配流水线重构**：`processEnglishAnchorMatch` → `processAnchorMatch`，动态从 `anchorWords` 构建正则。
- **`bestMatch` 分母统一**：从 `(a+b)/2` 改为 `max(a,b)`，与 `nameSimilarity` 一致。
- **日志缓冲清理**：`logFlush` 后清空 `logText`/`logBuffer`，防会话污染。
- **`extractNumber` 精简**：直接调用 `extractAllNumbers().first`，消除重复正则。

### 修复

- **"number X4" 误识别为号码而非 foul**：ASR 将 "number 5 foul" 听成 "number 54" 时，预处理拆分为 number 5 + foul。
- **意大利语 `"libbero"` 在 statEvents 中导致匹配无声失败**：移入 shotKeywords，恢复 made/missed 状态检测。
- **语音规则拆分为各语言独立文件**：`toPinyin`/`fuzzyPinyin`/`generatePinyinVariants`/`letterPinyin`/`namePinyinVariants` 从 `VoiceRecognizer` 移至 `VoiceRules` 实例方法，`fuzzyMap` 现在真正被使用。
- **"number X" 前缀误匹配**：`no X` 不再被当作号码前缀，仅 `number X` 和 `#X` 视为球员号码。
- **"three" 同时匹配号码 + 投篮类型**：`extractNumber` 改为仅搜索关键词左侧文本，避免 "Three" 既匹配 3PT 又匹配 3 号球员。
- **"no" 在关键词左侧时未识别为未中**：`resolvePlayer` 在右侧文本为空时自动扫描左侧文本中的 miss/made 指示词。
- **"free" 误映射为三分**：`("free", "stat.three")` → `("free", "stat.freeThrow")`。
- **"free through" ASR 变体未识别**：新增 `free through` / `free thru` / `fowl shot` / `faul shot` / `four shot` 等 shot keyword 变体。
- **"three free throw" 误匹配为 3PT**：新增 `("three free throw", "stat.freeThrow")` 优先于 `"three"` 匹配。
- **"Period two end" 误匹配为 2PT**：command events 移至 shot keywords 之前，`"end"` 优先匹配。
- **"know" 未作为 miss 状态**：`"know"` 加入 anchor 正则和 miss states。
- **"X02/X03" 数字组合未识别**：ASR 将 "no" 听成 "0" 时（如 "503"），预处理重写为 "number 5 no three"。
- **"X2/X3" 数字组合未识别**：纯数字文本（如 "23"）预处理重写为 "number 2 three"。
- **`extractNumber` 在拼音回退段未使用 `preferredPlayerNumber`**：拼音回退段优先使用 "number X" 提取的号码。

### 国际化

- 新增 voice_log_* 系列日志字符串至全部 10 种语言。
- 新增 `stats_rebound_block` / `stats_assist_steal` 统计标签键值至全部 10 种语言。

### 语音

- **rebound 识别增强**：新增 `rebounds` / `rebo` / `rebaund` / `ribaund` / `offensive rebound` / `defensive rebound`。

## 1.21 (2026-06-12)

### 新增

- **AI 分析优化**：按节次输出比赛分析，系统预计算个人/球队连续得分、连续篮板、连续助攻、连续投篮不中，直接供 AI 引用。
- **AI 分析可复制/保存为图片**：长按复制单节文本；「保存到相册」按钮将完整 AI 总结渲染为图片。
- **球队统计模式**：新建比赛时可为每支球队开启「按球队统计」，无需选择球员，所有数据记到球队名下。
- **语音支持球队模式**：说「主队两分命中」「客队犯规」「湘北篮板」等即可为球队记录数据，仅球队模式下生效。

### 修复

- **比赛名称不持久化**：`CoreDataStore.fetchAllSavedGames()` 缺少 `displayName`。
- **AI 按钮非 Pro 无反应**：非 Pro 用户点击弹出订阅购买页面。
- **语音录制前 0.5s 延迟**：音频引擎预热，节省 ~300ms。
- **音频降噪**：录音模式 `.measurement`，排除格式不兼容问题。
- **语音识别失败震动**：失败时 3 次震动反馈。
- **球队数据持久化**：`GameSnapshot` 显式 decoder 缺少 `teamStatsByID` 等新字段，导致重启后数据丢失。
- **球队模式语音不可用**：`@State` struct 属性修改不触发 `onChange`，`currentSnapshot` 始终拿不到球队模式 flag。
- **球员英文名 AD 匹配优化**：增加原始字母和空格分隔的拼音变体，修复 ASR 输出 "id" 时无法匹配的问题。
- **语音识别变体池系统**：`generatePinyinVariants` 生成双向模糊变体，通过 Set 交集匹配，大幅提升球队模式和多音字识别准确率。
- **VoiceRecognizer 内存泄漏修复**：Task/dispatch 闭包中 `[self]` 改为 `[weak self]`，消除约 10 处循环引用风险。提取 `showSuccessFeedback`/`showErrorWithFlash` 等辅助方法，消除 18 处 `Task.sleep` 重复代码。
- **AI 每节得分球队模式错位**：`summaryPrompt()` 中 `homeIDs` 未包含球队 UUID，导致球队统计模式的主队每节得分被归入客队。
- **AI 比分格式优化**：提示词中比分分隔符 `-` 改为 `：`，避免 AI 输出顺序颠倒；同步更新 `ai_prompt_score_label` 至全部 10 种语言。

### 国际化

- 新增 `button_save_to_photos` 至全部 10 种语言。
- 同步 AI prompt 翻译（`ai_system_role`、`ai_prompt_req_4~14` 等）至全部 10 种语言。
- 更新 `ai_prompt_score_label` 比分分隔符为 `：`，全部 10 种语言。

## 1.20 (2026-06-11)

### 修复

- **自定义语音快捷指令不生效修复**：匹配逻辑从精确 `[text]` 字典查询改为 `contains` 遍历 key，先匹配成功则优先使用；球员号码/姓名从短语左侧残留文本提取，与现有投篮事件匹配模式一致。
- **语音日志不持久化修复**：`AppStore.load()` Core Data 路径下不再提前 `return`，改为同时读取 `StoreMeta` 中的 `voiceLog` 和 `customVoiceMappings` 恢复语音数据。

### 新增

- **语音快捷指令编辑**：指令列表行点按即可打开编辑 Sheet，支持修改短语或动作类型。修改短语时自动移除旧 key。
- **多音字姓氏语音匹配**：中文语音规则新增多音字姓氏覆盖映射（曾→zeng、单→shan、朴→piao、解→xie、区→ou、仇→qiu、盖→ge、查→zha 等 13 个常见姓氏）。球员名字匹配时自动补充替代拼音形式，提高 ASR 识别准确率。
- **灌篮高手 Demo 数据**：初始样例数据替换为湘北/陵南 6 名球员，附带头像照片，10 种语言对应翻译。
- **语音记分加入 Pro 订阅**：记分页麦克风按钮、设置页语音入口现为 Pro 功能。
- **语音日志开关**：设置页新增「启用语音日志」开关。
- **订阅页可滚动**：特性说明区域改为 `ScrollView`。
- **App Store 元数据更新**：关键词、Pro 标注、What's New 全部 10 种语言。
- **记分页球员名自适应字号**：`minimumScaleFactor` 自动缩放，`X号` 改为 `NoX`。

### 国际化

- 新增 `voice_shortcuts_edit_title` key 至全部 10 种语言。
- 新增 `settings_voice_log_enable` / `settings_voice_log_enable_footer` 至全部 10 种语言。
- 新增 `pro_feature_voice_1` / `pro_feature_voice_2` 至全部 10 种语言。
- 替换 `sample_player_1~4` 为 `demo_player_*` 灌篮高手角色名，全部 10 种语言。
- Demo 球队 `demo_team_shohoku` / `demo_team_ryonan` 全部 10 种语言。

### 修复

- **代码审查修复**：修复 `Dictionary(uniqueKeysWithValues:)` 重复 ID 崩溃、`AIService` force-unwrap URL、`VoiceRecognizer` 回调线程安全、`revertLastAction` 中文硬编码解析、CoreData `NSBatchDeleteRequest` 上下文不一致等 20 项问题。
- **ASR 语音变体补全**：为 10 种语言补充 55 条语音变体匹配规则，ASR 测试 209 全通过。
- **SettingsDocumentView 语言切换**：添加 `@Environment(\.locale)` 观察，切换语言后自动刷新使用说明内容。
- **Demo 照片加载路径修复**：`seedSampleData()` 从 Bundle 根目录加载球员头像。
- **蓝牙协议中文转 English**：4 处 `sendAuthoritativeSnapshot` reason 参数由中文改为英文。
- **SubstitutionView 切换 side 清空选择**：避免跨队换人。
- **5 个测试用例修复**：更新 `StatAction` 数量、删除无效 VoiceMatching 测试、本地化 LegacyUndo 消息。
- **订阅页 ProSubscriptionStoreView 改为 internal**：GameView 可直接调用购买页面。

## 1.19 (2026-06-10)

### 修复

- **暂停按钮无响应修复**：节结束时若比赛处于暂停状态，点击暂停按钮不再静默忽略，改为弹窗提示（与统计数据提示方式一致）。
- **语音节开始自动取消暂停**：第 X 节开始时（语音或按键），比赛自动取消暂停状态。

### 多语言语音规则扩展（Phase 2）

- 法文、俄文、意大利文、西班牙文、韩文 5 种语言的 `VoiceRules` 大幅扩充：
  - 投篮关键词新增常用口语（如法文 "panier" "couche"、西文 "tres puntos" "pintura"、韩文 "투포인트" "쓰리포인트" 等）
  - 命中/未中状态新增口语表达
  - 统计事件新增犯规、篮板细分、走步、违例等关键词
  - 换人/命令事件补充口语说法
- 英文、德文、日文 3 种语言同步补充未覆盖的口语关键词。
- 所有语言新增对应的单元测试覆盖。

### 语音识别架构重构

- `VoiceRecognizer` 改为 `VoiceRules` 驱动：`voiceShotTypes`/`voiceMadeStates`/`voiceMissedStates` 从 `let` 改为 `var`，支持语言切换时动态更新。
- 删除 `pinyinPatterns` 惰性属性（硬编码的中文特殊条目已迁移至 `VoiceRules`）。
- `nonShotEvents` 构建去掉去重逻辑，确保同义词（如"板"/"前场板"/"后场板"）均可匹配。
- 换人预检从 `currentRules.substitutionKeywords` 读取，不再硬编码 "换"/"替换"。
- `extractNumber` 支持多语言格式：CJK（号/番/번）、英文（number 5/#5）、纯数字（1-99）。
- 投篮事件新增拼音兜底匹配：中文关键词匹配失败后自动尝试模糊拼音匹配，修复 ASR 返回拼音（如 "zhang san fa lan ming zhong"）时罚篮/加罚无法识别的问题。
- `game_end` 命令从中文规则中移除（避免 ASR 将"第X节结束"误识别为"结束"触发整场比赛结束）。
- `commandEvents` 中 `event.game_end` 正确映射为 `.finishGame`（不再错误降级为 `.togglePause`）。

### 语音设置页重构

- 设置页新增「语音」入口，整合语音按钮开关、语音日志、快捷指令、语音说明于同一页面。
- 语音按钮默认关闭（需在设置中手动开启）。
- 语音快捷指令 UI 重写：按投篮/统计分组，使用 `StatAction` 本地化标签，新增图标和分组选择器。
- 新增「语音说明」页面，按语言（简体中文/繁体中文/英文/日文/韩文）展示图文并茂的使用指南，涵盖麦克风使用、支持指令、快捷指令、使用技巧等。
- 剩余 5 种语言（法/俄/意/西/韩）新增语音规则说明文档。

### 国际化补全

- 补全 8 种语言 5 个语音日志相关 key 的本地化翻译（此前为英文占位符）。
- 新增 12 个语音设置 key 至全部 10 种语言。
- 新增 `settings_voice_shortcuts` 至全部 10 种语言（此前缺失 8 种）。

- `VoiceRules_de.swift`、`_en.swift`、`_fr.swift`、`_it.swift`、`_ja.swift`、`_ko.swift`、`_ru.swift`、`_es.swift` 8 种语言新增口语同义词。
- 文档：全部 8 种非中文语言新增语音规则说明文档（`docs/VoiceRules/voice_rules_{en,ja,de,fr,ru,it,es,ko}.md`）。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.18 (2026-06-10)

### 多语言语音识别框架

- 新增 `VoiceRules` 协议和 10 种语言的独立规则文件：中文（简/繁）、英文、日文、韩文、德文、西班牙文、法文、意大利文、俄文。每种语言的文件独立存放，互不干扰。
- 根据 App 系统语言自动选择对应的语音规则和 ASR 识别语言。
- 新增 `VoiceShortcutSettingsView`：用户可自定义语音短码映射（说"2" → 两分命中），精确命中优先于自然语言匹配。
- `VoiceRulesTests` 23 个测试用例覆盖全部语言的 shot/made/missed/command 验证。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.17 (2026-06-10)

### 语音识别重大重构

- 重新设计匹配流程：先直接匹配 event 关键词（原文精确查找），再分词匹配主语（球员）和状态（命中/未中），不再依赖拼音滑窗评分。
- 换人逻辑重写：按关键词"替换/换"将文本分为主/宾语，分别匹配场上（被换下）和场下（替补），支持两种语序。
- 球员名字匹配只查关键词前后的文本，不查全文拼音，大幅减少误匹配。
- 号码匹配优先于名字匹配：文本中含"3号"等关键词时，先按号码精确查找。

### 新增

- 三色波浪语音动画（青/绿/淡粉），渐变粗细，全屏宽度。
- 语音日志持久化（随 StoreMeta 写入 UserDefaults/Core Data），右滑可删除，支持复制单条和全部。
- 每个匹配步骤的详细日志写入语音日志，方便调试。

### 代码重构

- 项目结构重组：文件迁移到 `Views/`、`Models/`、`Services/` 子目录。
- GameView.swift（4100→2866行）：拆分为 StatAction、CompactTeamRow、TeamStatsView、GameSetupView、SubstitutionViews、PastelButtonStyle、PlayerAvatarButton 共 8 个文件。
- ContentView.swift（2900→495行）：拆分为 CareerView、HistoryView、SavedGameDetailView、ImportGameView、PlayerGameDetailView 共 5 个文件。
- RosterView.swift（3100→2163行）：拆分为 PlayerProfileView。
- 所有跨文件引用调整为 `internal` 访问级别。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.16 (2026-06-09)

### 修复

- 语音统计操作与按键使用同一代码路径：语音回调改用 `submitLiveOperation`，确保与按钮一致的蓝牙同步、暂停/结束等状态检查。
- 语音号码替换（换人）支持号码匹配：`handleSubstitution` 先用 `extractNumber` 提取球衣号码，号码匹配失败再回退到姓名模糊匹配。
- `extractNumber` 支持 "hao" 拼音：正则 `(\d+)\s*(号|hao)`，处理 ASR 输出 "5hao" 代替 "5号" 的情况。
- 球员匹配只查残留拼音（动作模式之外的部分），消除 "老冯" 通过动作词 "fen" 产生误匹配的问题。
- 文本含 "号"/"hao" 但无数字时跳过姓名匹配，防止 "haoz三分没中" 中的 "hao" 被误认为球员名。
- 修复 `testASRIdMatchesPlayerAD` 和 `testActionWithoutPlayerDoesNotMatchFuzzyPlayer` 两个测试用例。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.15 (2026-06-08)

### 新增

- Dark Mode 全面适配
  - `GamePalette` 全部 14 种颜色改用 `UIColor` 动态 trait provider，记分页按钮区在暗色模式下显示更深色域。
  - 全局硬编码 `.foregroundStyle(.black)` 替换为 `.primary`，支持系统自动切换明暗色。
  - 全局卡面 `Color.white` / `.white.opacity()` 背景替换为 `Color(.secondarySystemBackground)` / `.regularMaterial`，暗色模式下显示柔和深色卡片。
  - `Color(red:green:blue:)` 硬编码背景色（Content 区背景、Player Detail 背景、Player Card 渐变、TransferUI 按钮）全部替换为 `UIColor` trait provider 或系统语义色（`.systemGroupedBackground` 等）。
- 着陆页重新设计
  - App Icon 替换篮球 emoji，渐变英雄区，语言选择器毛玻璃背景，卡片悬停微动效。
- nav_bluetooth_sync 国际化 key：补充至全部 10 种语言。
- CFBundleDisplayName 本地化：全部 10 种语言 InfoPlist.strings 添加原生 app 显示名称（简体/繁体中文、日文、韩文等）。

### 改进

- SubscriptionStoreView 策略按钮：新增 `.storeButton(.visible, for: .policies)`、`.subscriptionStoreControlStyle(.picker)`、`.subscriptionStoreButtonLabel(.multiline)`，满足 App Store 3.1.2 审核要求。
- AGENTS.md：新增分支与提交流程规范（main / main_free_pro 双分支策略，禁止自动 git 操作）。
- 比赛名称编辑后自动同步 iCloud：若该比赛已启用云存储，在 `onSubmit` 中自动调用 `CloudKitManager.shared.uploadGame()` 推送更新。

### 修复

- 本地游戏删除后重启恢复的 bug（此前于 1.13 标记为已修复的补充完善）。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.13 (2026-06-06)

### 修复

- 修复本地比赛删除后重启恢复的 bug
  - 根因：`CoreDataStore.save()` 只 upsert 当前内存中的比赛，从未清理 Core Data 中已删除的比赛实体。
  - 修复：在 `save()` 中 upsert 前先 `deleteAllSavedGames()` 清空旧数据，确保 Core Data 与内存状态一致。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.12 (2026-06-05)

### 亮点

- 订阅页重构：弃用自定义 `ProSubscribeView`，改用 `SubscriptionStoreView`（StoreKit），内嵌隐私政策与 EULA 链接。
- 设置页帮助/隐私文档中 DeepSeek 品牌引用全部泛化为 AI，覆盖 10 种语言。
- Web 链接页导航优化：`SFSafariViewController` 替换为 `WKWebView`，去掉外层 `NavigationStack`，消除重复导航按钮与返回按钮跳动问题。

### 新增与改进

- 订阅页重构
  - 使用 Apple `SubscriptionStoreView` 替代手工构建的 `ProSubscribeView`，支持月度/年度订阅系统默认样式。
  - 移除重复的关闭按钮（StoreKit 自带 dismiss）。
  - 配置 Privacy Policy 与 Terms of Service 可点击链接，EULA 指向 Apple 标准条款（`stdeula`）。
- 本地化品牌泛化
  - 设置页帮助、隐私文档中提及 DeepSeek 的全部文本改为通用 "AI" 指代，覆盖 10 种语言。
  - UI 提示文案（API Key 配置、连接测试、错误提示等）同步泛化。
- Web 链接页修复
  - `SFSafariViewController` → `WKWebView`，避免内建 Done 按钮与导航栏返回按钮重复。
  - 移除 `NavigationStack` 外层包裹，`.subscriptionStorePolicyDestination` 以 Sheet 呈现，返回按钮不再跳动。
- 团队统计对比样式修正
  - 主队数据改为 `.bold` + `.black`，客队数据改为常规字重 + `.secondary`，使对比更直观。
- SettingsFeatureSection / SettingsFeatureItem ID 修复
  - ID 从字符串（标题/描述）改为 `UUID().uuidString`，消除列表 `ForEach` 重复 ID 警告。
- `localized()` → `LocalizedStringKey()` 迁移
  - SettingsFeatureSection 和 SettingsFeatureItem 全部改为 `LocalizedStringKey`，支持 SwiftUI 动态本地化。
- GitHub Pages 上线
  - 启用 GitHub Pages（`main` 分支 `/docs` 目录），托管隐私政策、使用条款、支持页、营销 landing page。
  - 隐私政策 URL 迁移至 `13098806890.github.io/BasketballRecord/appstore/privacy-policy.html`。
  - EULA 指向 Apple 标准条款 `stdeula`。
  - 新增 `docs/index.html` 营销 landing page，包含功能展示与各文档链接。
- 文档 URL 统一
  - 所有 HTML 文档（privacy-policy、terms-of-use、support）中内链更新为 GitHub Pages 域名。
  - 隐私政策中的支持链接、支持页中的反馈链接均已对齐。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.11 (2026-06-03)

### 亮点

- 记分页改版：按钮布局优化、UI 细节打磨、事件日志修复。
- 订阅页交互改进、设置页 Pro 入口。
- 全面 i18n 修复与短文本适配。

### 新增与改进

- 记分页按钮重排
  - 投篮按钮区 icon 与文字间距缩小（Label → HStack spacing 3）。
  - 犯规/盖帽按钮顺序互换。
  - 重置比赛移到 toolbar 左侧 icon（缩小尺寸），结束比赛移至同一位置。
  - Undo/Redo 改用 PastelActionButtonStyle（轻灰），高度/圆角与其他按钮一致。
  - 换人→浅蓝、新增到场→更浅蓝，避免颜色过重。
- 布局适配
  - `gameLayout` 包裹 ScrollView，支持 iPhone 横屏滚动。
  - 事件日志 `List` 改为 `LazyVStack`，解决 ScrollView 嵌套空白问题。
  - 左侧队名/比分/犯规区域宽度压缩（`fixedSize` + `maxWidth: 48`），右侧头像区可多显示球员。
  - CompactTeamRow 恢复淡蓝底色（`GamePalette.surface`）。
- 订阅与设置
  - 新增关闭按钮、毛玻璃特性卡片、蓝色订阅按钮样式。
  - 设置页移除"生涯展示选项"，新增"升级到 Pro"入口。
  - AI 设置按钮改为灰色禁用样式（非 Pro 时），与其他 Pro 锁定入口统一。
- 比赛数据入口下移至操作按钮下方。
- i18n
  - 缩短各语言投篮按钮文本（如 "Miss"、日语 FT 等），防止按钮截断。
  - 新增 `pro_best_value` key 至全部 10 种语言。
- 其他
  - 恢复订阅成功后自动关闭购买页。
- 国际化修复
  - 修复西班牙语 `stats_record_shooting_format` 和 `stats_record_misc_format` 格式字符串为 `"%d"`（仅一个占位符）导致的崩溃。
  - 修复日语 `period_context_with_time_format` 缺少 `%@` 时间参数导致显示异常。
  - 修复意大利语 `stats_record_misc_format` 缺少 `TO %d`（失误统计缺失）。
  - 修复德语/法语/意大利语/俄语 `progress_sending_to_format` format specifier 数量与调用不匹配。
  - 修复 7 种语言 45 处 `\\n` 误用为 `\n`（硬编码换行符），解决换行显示问题。
  - `ContentView.swift` 硬编码中文字符串 `"未知球员"` 改为 `NSLocalizedString("unknown_player", ...)`。
  - `ContentView.swift` 硬编码 `"VS"` 改为 `LocalizedStringKey("label_vs")`，新增至全部 10 种语言。
- 数据与稳定性
  - 修复 `GameSnapshot.wasBluetoothCollaborated` 未解码导致蓝牙协同游戏过滤恒为空的 bug。
  - 修复替换撤销（revertLastAction）依赖中文分隔符 `" 替换 "` 的硬编码，改为语言无关的球员名匹配。
  - 修复 `project.pbxproj` Debug 配置缺少 `INFOPLIST_FILE` 和 `SWIFT_VERSION` 导致 CLI 构建失败。
  - 移除遗留的 `DeepSeekKeychain.swift` 和 `DeepSeekService.swift`（已迁移至 `AIKeychain`）。
- 新增撤销操作多语言测试 `GameUndoMultilingualTests.swift`（16 个测试用例）。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.10 (2026-06-03)

### 亮点

- 比赛新增 displayName（自定义名称），所有列表统一显示。
- 球员卡片全面重构：比赛详情 → 本场数据；生涯页面 → 生涯汇总 + 场均（复用相同卡片格式）。
- iCloud 存储修复：改用 ID 逐条拉取代替全局查询，解决 "not marked queryable" 错误。
- Undo 重构：去掉快照持久化，改为 action-based revert，彻底解决 20MB 存储问题。
- 照片存储分离：从 UserDefaults 迁移到独立文件，避免 4MB 上限。

### 新增与改进

- 比赛自定义名称
	- `SavedGame.displayName` 字段，比赛详情页可编辑。
	- 所有列表（历史、iCloud、分组编辑）统一使用 `displayTitle`。
- 球员卡片重构
	- 从比赛详情点球员：只显示本场数据（得分/时间、篮板/助攻/抢断/盖帽、犯规/失误、投篮等）。
	- 从生涯点球员：显示生涯数据（出场、总得分/时间、投篮等）+ 场均（复用相同卡片格式）。
	- 数据范围选择器移到了统计卡片上方。
- iCloud 存储
	- `fetchGames(ids:)` 替代 `fetchAllGames()`，避免 CKQuery 索引问题。
	- 支持查看"仅云端"比赛并下载到本地。
	- 本地删除不影响云端。
- Undo 重写
	- 移除 `undoSnapshots`/`previousSnapshot` 持久化。
	- `revertLastAction()` 直接反转最后一条操作，支持统计、换人、节次、晚到撤销。
	- 快照仅用于内存 fallback，最多 30 个。
- 存储优化
	- 每场比赛存为独立 UserDefaults key（`game_{uuid}`），避免 4MB 上限。
	- 球员照片存为独立文件（`Documents/player_photos/{uuid}.jpg`）。
	- 旧数据自动迁移到新格式。
- Pro 订阅
	- `PurchaseManager` 支持 `com.doxie.basketball.pro.monthly` 和 `com.doxie.basketball.pro.yearly`。
	- 点击 Pro 功能弹出购买页，订阅成功后自动关闭。
- 其他
	- 修复比赛详情页球员数据不显示的 bug（`if fixedGame == nil` 大括号范围错误）。
	- 修复 `CKAccountStatus.temporarilyUnavailable` 未处理。
	- 修复 `label_starter`/`label_bench` 等缺失的 i18n key。
	- 补充 10 种语言的完整 i18n。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.09 (2026-06-03)

### 亮点

- 新增 Pro 订阅系统（月度/年度），球队分组、蓝牙协同、iCloud 存储、AI 总结为 Pro 功能。
- 比赛支持多分组，一场比赛可同时归属多个分组。
- 新增 iCloud 云存储，可选择比赛同步到云端。
- 新增比赛锁定功能，锁定后不可删除。
- 新增每节自动结束条件（按时间/按比分）。
- 支持多 AI Provider（DeepSeek / OpenAI / Anthropic），可选模型。
- 蓝牙传输进度修复：发送方不再提前显示 100%。
- 蓝牙新增照片传输开关。

### 新增与改进

- 订阅与 Pro
	- 新增 `PurchaseManager`（StoreKit2），支持 `com.doxie.basketball.pro.monthly` 和 `com.doxie.basketball.pro.yearly`。
	- 点击球队分组、蓝牙协同、AI 总结、iCloud 等 Pro 功能时弹出购买页。
- 多分组
	- `SavedGame.groupID: UUID?` → `groupIDs: [UUID]`，旧数据自动兼容迁移。
	- `GameGroupPicker` 支持多选勾选状态显示。
- iCloud 存储
	- 设置页 iCloud 存储入口（Pro 可见），可逐场切换云端/本地。
	- 使用 `NSUbiquitousKeyValueStore` 跨设备同步。
- 比赛锁定
	- `SavedGame.isLocked` 字段，历史列表左滑锁定/解锁，锁定行隐藏删除按钮。
- 每节自动结束
	- 新增 `PeriodEndCondition`（按时间 / 按比分），新建比赛时可设置。
	- 时间到或比分达上限时自动结束节次，弹出 Alert + 震动。
	- 设置值通过 `@AppStorage` 持久化。
- AI 多 Provider
	- 新增 `AIService` + `AIKeychain`，支持 DeepSeek / OpenAI / Anthropic。
	- 设置页可切换 Provider 和模型，API Key 按 Provider 分别存储。
- 蓝牙传输
	- 进度修复：`fractionCompleted` 在确认前 cap 为 0.99，不再提前 100%。
	- 新增照片传输开关（`label_include_photos_in_sync`）。
- UI 优化
	- 新建比赛键盘增加 "完成" 收起按钮。
	- 蓝牙同步进度弹窗由 Alert 改为 Sheet，进度实时更新。
- 删除
	- 移除显示模拟比赛按钮设置及对应代码。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.08 (2026-06-02)

### 亮点

- 新增"比赛分组"功能，支持创建/管理分组并按分组筛选历史与生涯数据。
- 全面国际化重构，所有文本改为本地化加载，支持 10 种语言。
- 蓝牙协同时间戳修复，确保多设备记分事件时间一致。
- Event 存储架构重构：`eventCode` 独立存储，不再依赖本地化文本。

### 新增与改进

- 比赛分组
	- 新增分组管理页面，支持创建、编辑、删除分组。
	- 历史列表、球员卡、球员详情页均支持按分组筛选。
	- 比赛详情页支持直接分配分组。
	- 分组数据仅本地保存，蓝牙同步/导入导出自动剥离分组信息。
- 国际化（i18n）
	- 所有硬编码中文替换为 `NSLocalizedString`，支持中/英/日/韩/德/西/法/意/俄/繁体中文。
	- 导出编码关键词本地化，同时保留旧版关键词的向后兼容解析。
	- AI 分析提示词支持多语言。
- 蓝牙协同
	- `.record` 操作新增 `at: Date` 时间戳，host 和 participant 使用相同时间记录事件。
	- 分组数据在传输时自动剥离，接收方保留本地分组设置。
- Event 架构
	- `GameLogEntry` 新增独立 `eventCode` 字段，不再嵌入 `message`。
	- 分析/评分判断优先使用 `eventCode`，向后兼容旧记录。
- 体验优化
	- 录制定位动画改为 Timer 驱动，消除 `repeatForever` 布局抖动。
	- 记分操作触觉反馈提升为 `.heavy`，得分操作双次震动。
	- 事件日志不再展示在比赛详情页和 AI 提示词中。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.06 (2026-05-29)

### 亮点

- 新增“分段导入导出”功能，支持球队/球员数据多段编码分享与批量导入，提升跨平台和长文本传输体验。
- 新增蓝牙同步相关功能，支持通过蓝牙在设备间同步球员数据。
- 球员详情页支持“分节”数据统计和事件回放，细化单场多节表现分析。

### 新增与改进

- 分段导入导出
	- 支持导出为多段编码，导入时自动识别分段、批次 ID、分段校验与自动填充。
	- 导入导出 UI 优化，分段数量可调，分段复制与粘贴体验提升。
- 蓝牙同步
	- 新增蓝牙相关模块，球员导出页支持蓝牙发送，实时显示连接与传输进度。
- 球员统计
	- 球员详情页可选择分节查看数据与事件流水，支持事件回放。
- 体验优化
	- 导入导出流程自动识别剪贴板内容类型，自动切换导入模式。
	- 复制、分享、分段等操作均有即时 UI 反馈。
	- 导入导出 UI 组件抽象，提升一致性和可用性。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.03 (2026-05-27)

### 亮点

- 补齐出场统计口径：比赛记录保留全队名单，生涯统计仅计算真实出场球员。
- 导入导出编码继续优化，保持短编码分享与自动识别体验。

### 新增与改进

- 出场与统计
- 比赛记录中保存主客队完整名单（含未上场球员）。
- 新增统一出场判定逻辑，按首发/上场时间/有效数据判断“是否出场”。
- 生涯场次、首发/替补统计改为仅计算真实出场，未上场球员不计入场均。

- 导入导出与设置
- 比赛/球队/球员分享统一为压缩编码，降低分享文本长度。
- 导入页支持进入后自动检测剪贴板并自动粘贴解析。
- 设置新增“是否显示模拟比赛按钮”开关，可按需隐藏入口。

- 记分页面顶部
- 顶部信息条精简为“左侧比赛时长 + 右侧节次”，移除队名对阵文本。
- 比赛时长显示加大、加粗并改为黑色，提升实时可读性。

### 兼容性

- iOS 17.6+
- Xcode 17+

## 1.02 (2026-05-27)

### 亮点

- 新增 AI 比赛分析能力，支持保存结果与结构化展示。
- 记分页与比赛详情持续优化，提升一致性与可读性。

### 新增与改进

- AI 比赛分析
- 新增 DeepSeek API Key 设置、连通性测试与 Keychain 安全存储。
- AI 总结支持生成并持久化保存到比赛记录。
- AI 总结改为图标 + 文本卡片样式展示，MVP 支持奖杯与球员头像。
- AI 结果展示增加文本清洗，移除 Markdown 标记与多余符号。

- 记分与比赛流程
- 记分页顶部新增比赛时长展示（按开始/暂停/节次结束/继续累计）。
- 比赛时长显示位置优化为主客队同一行，使用时钟图标展示。
- 结束比赛按钮补充确认弹窗，模拟比赛与历史加载补充 loading 反馈。

- 设置与说明
- 设置页新增常亮开关（可持久化保存并实时生效）。
- 新增并重构使用说明、隐私说明、数据与备份页面（图标化结构）。
- 设置页图标风格统一，减少高饱和颜色干扰。

- 历史与视觉
- 比赛详情球队统计卡片样式与全局统一，支持无背景样式。
- AI 分析主题色调整为蓝色系。

- 数据导入导出
- 复制反馈与导入解析状态优化。
- 导入页可识别剪贴板可解析内容并优化交互提示。

## v1.01 (2026-05-26)

### 亮点

- 持续优化记分、配置与导入导出的交互可用性与视觉一致性。

### 新增与改进

- 记分页面
- 新比赛前增加“当前比赛未结束”确认弹窗，支持“结束当前比赛 / 取消”。
- 统计按钮在“未开始节次/已结束”状态下给出明确提示。
- 撤回栈支持随未完成比赛持久化与重载恢复。
- 顶部动作图标语义优化（存到历史、结束比赛）。

- 配置与图标统一
- 导入/导出图标统一：导入使用 `tray.and.arrow.down.fill`，导出使用 `tray.and.arrow.up.fill`。
- 球员编辑与导出入口改为统一视觉风格的圆形操作图标。
- 导出页“复制编码/分享编码”按钮改为统一的浅蓝应用风格。

- 导入导出体验
- 比赛导入与配置导入输入框固定高度，避免粘贴长文本后拉伸。
- 导入页解析流程增加稳定反馈并修复解析按钮点击不生效问题。
- 保留滚动收起键盘能力，减少录入干扰。

## v1.0 (2026-05-26)

### 亮点

- 完成首个正式版本发布。
- 形成从记分、配置、历史到导入导出的完整闭环。

### 新增与改进

- 记分体验
- 选中球员头像更大、更清晰。
- 未选中球员采用 80% 透明度，减少视觉干扰。
- 命中类操作按钮调整为浅绿色。
- 犯规按钮调整为浅红色。

- 配置页
- 优化合并球员/合并球队/新建球队/导入相关图标语义。
- 导入入口整合为单入口“导入数据”，避免重复入口。
- 新增导入类型切换（球队/球员）。

- 历史与球员统计
- 比赛详情按球队拆分球员列表。
- 新增可折叠球队统计区（与记分页风格一致）。
- 球员卡改为从比赛记录中选比赛统计，支持按月与全选操作。

- 导入导出交互
- 导入页新增解析结果展示框。
- 导入解析过程增加 loading 状态。
- 解析时按钮禁用，避免重复触发。
- 导入时在解析按钮点击后自动收起键盘。
- 导出复制操作增加“已复制”即时反馈。

### 兼容性

- iOS 17.6+
- Xcode 17+
