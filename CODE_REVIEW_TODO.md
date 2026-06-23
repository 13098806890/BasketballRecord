# Code Review TODO

## 分支信息

**当前工作分支**: `refactor`
**已推送**: 是 (`origin/refactor`)
**Commits** (自上而下):

| Hash | 内容 |
|------|------|
| `1af4f88` | docs: update CODE_REVIEW_TODO with detailed branch/commit status and implementation plans |
| `6d6be17` | VoiceRules JSON 数据模型 — 删除 10 个 VoiceRules_*.swift，改为 VoiceRulesData.swift 内嵌 JSON |
| `690f258` | build 版本号 28→29 |
| `f73ab7e` | refactor 分支创建（空基 commit） |
| `ee546d6` | 父 commit — safeWrite/safeRead、mergedStats、saveGeneration、CoreData refreshAllObjects、CloudKit defer、PurchaseManager 优化、GameView period_start revert、GameSetupView @FocusState、AIServiceProxy @MainActor |

**Branch 策略**:
- `refactor` 分支从 `main` 的 `ee546d6` 创建
- Items 1-5、8、9、15、17、18、21 的改动在 `ee546d6` + `refactor` 分支上
- Items 6、7 仅在 `refactor` 分支（AppStore 拆分 + LiveCollaborationManager 提取）
- Items 10、11、19 确认不处理
- `main` 分支保持原样（不含 JSON VoiceRules 等大型重构）
- `main_free_pro` 分支待后续同步
- 后续由用户决定是否合入 `main`

---

## ✅ 已完成

### ~~1. `AppStore.safeWrite` 中的强制类型转换~~ ✅ 已修复
- **文件**: `Services/AppStore.swift`
- **Branch**: `main` + `refactor`
- **问题**: `valueToEncode = game as! T` 当 `T` 不是 `SavedGame` 时直接崩溃
- **改动**: 
  - `safeWrite` 改为 `if key.hasPrefix("game_"), var game = value as? SavedGame` 组合条件，独立路径 encode/trim，无类型强转
  - `safeRead` 同理，先 decode 为 `SavedGame` 再 trim，`as? T` 作安全回退
  - 提取 `readRawData` 消除重复

### ~~2. CoreData NSBatchDeleteRequest 后 context 不一致~~ ✅ 已修复
- **文件**: `Services/CoreDataStore.swift:276-283`
- **Branch**: `main` + `refactor`
- **问题**: `deleteAll()` batch delete 后 context 未同步
- **改动**: 追加 `context.refreshAllObjects()`，确保同一 context 后续操作不读到过时对象

### ~~3. `mergedStats` 遗漏细分字段~~ ✅ 已修复
- **文件**: `Services/AppStore.swift:1297-1325`
- **Branch**: `main` + `refactor`
- **问题**: 球员合并未合并 layup/midRange/paint/O-D rebound 字段
- **改动**: 补充 `layupMade/Attempts`、`midRangeMade/Attempts`、`paintMade/Attempts`、`offensiveRebounds`、`defensiveRebounds`

### ~~4. CloudKit temp 文件无限增长~~ ✅ 已修复
- **文件**: `Services/CloudKitManager.swift:70-95`
- **Branch**: `main` + `refactor`
- **问题**: `writeTempFile` 不清理
- **改动**: `uploadGame` 中用 `defer { try? FileManager.default.removeItem(at: fileURL) }` 自动清理

### ~~5. PurchaseManager 的 `isPro` 异步闪屏~~ ✅ 已修复
- **文件**: `Services/PurchaseManager.swift:40-107`
- **Branch**: `main` + `refactor`
- **问题**: `checkSubscriptionStatus()` 在 `loadProducts()` 之后才执行
- **改动**: 
  - Task 内先 `checkSubscriptionStatus()` 再 `loadProducts()`
  - `if foundPro != isPro` 守卫避免冗余 `@Published` 发布

### ~~8. `VoiceRecognizer` 责任过重~~ ✅ 已修复
- **文件**: `Models/VoiceRecognizer.swift`、`Views/Game/GameView.swift`、`Views/VoiceTutorialView.swift`
- **Branch**: `main` + `refactor`
- **问题**: VoiceRecognizer 持有 `@Published var match/flashColor/errorMessage` UI 状态
- **改动**:
  - VoiceRecognizer 移除 `match`、`flashColor`、`errorMessage` 三个 `@Published` 属性
  - 新增 `onFlash`、`onError`、`onClear` 三个回调闭包
  - GameView 用自己 `@State` 管理 voiceMatch/voiceFlashColor/voiceErrorMessage
  - VoiceTutorialView 同理用自己 `@State`
  - 清除逻辑（clearVoiceFlashAfterDelay/clearVoiceMatchAfterDelay/clearVoiceErrorAfterDelay）移到 GameView
  - VoiceRecognizer 的 `showSuccessFeedback`/`showDualSuccessFeedback`/`showErrorWithFlash`/`showError` 不再设置 UI 属性，改调回调

### ~~9. VoiceRules 文件代码重复~~ ✅ 已修复
- **文件**: 删除 `Models/VoiceRules_en/zh/zh_Hant/ja/ko/de/es/fr/it/ru.swift`（10 个文件）
- **新增**: `Models/VoiceRulesData.swift`
- **Branch**: `refactor` 分支（`main` 无此改动）
- **问题**: 10 个语言文件内容结构完全一致，仅有数据不同
- **改动**:
  - `VoiceRulesData`：`Decodable` 结构体，字段对应 VoiceRules 构造参数
  - 10 个语言 JSON 数据以内嵌字符串（Swift 双引号转义）存储在 `VoiceRulesData.embeddedJSON` 字典中
  - `VoiceRulesData.load(language:)` 按语言标识符（zh-Hans/en/ja 等）加载对应 JSON
  - `VoiceRules(data:)` 从 `VoiceRulesData` 构造 VoiceRules 实例
  - `VoiceRules` 静态属性（.chinese/.english 等）改为调用 `fromJSON(language:)`
  - JSON 源文件保留在 `Resources/VoiceRules/*.json` 作为可编辑的数据源
  - **关键点**: 内嵌 JSON 解决了无需 Xcode 项目文件操作即可在运行时加载的问题

### ~~15. `event.period_start` 撤销未恢复时间状态~~ ✅ 已修复
- **文件**: `Views/Game/GameView.swift:2836-2843`
- **Branch**: `main` + `refactor`
- **问题**: 撤销 period_start 时未关闭活跃 stints/clocks
- **改动**: 调用 `closeActiveStints`、`closeMatchClock`、`closePeriodClock`，设置 `isPaused = false`

### ~~17. 保存 debounce 500ms 可能丢失中间状态~~ ✅ 已修复
- **文件**: `Services/AppStore.swift:959-975`
- **Branch**: `main` + `refactor`
- **问题**: 被取消的 saveTask 仍会清除 `dirtyKeys`
- **改动**: 引入 `saveGeneration` 计数器，只在当前 generation 未过期时清除 `dirtyKeys`

### ~~18. Keyboard dismissal 使用 UIKit API~~ ✅ 已修复
- **文件**: `Views/Game/GameSetupView.swift:195-201`
- **Branch**: `main` + `refactor`
- **改动**: `@FocusState` 替代 `UIApplication.shared.sendAction`

### ~~19. en.lproj 的 comment 包含中文~~ ✅ 无需处理
- **结论**: en.lproj 无中文 comment，已确认

### ~~21. PurchaseManager.appAccountToken 可能主线程阻塞~~ ✅ 已修复
- **文件**: `Services/PurchaseManager.swift:16-29`
- **Branch**: `main` + `refactor`
- **改动**: 移除 `try? NSUbiquitousKeyValueStore.default`、移除 `synchronize()`

### ~~6. `AppStore` 中度拆分~~ ✅ 已修复
- **Branch**: `refactor` 分支（不涉及 `main`）
- **文件**: `Services/AppStore.swift`（1451→687 行）、`Services/AppStore+Player.swift`（新增 262 行）、`Services/AppStore+Team.swift`（新增 183 行）、`Services/AppStore+Game.swift`（新增 343 行）
- **问题**: `AppStore.swift` 单一文件 ~1430 行，职责过重
- **改动**:
  - 创建三个 extension 文件，按 Player/Team/Game 拆分 CRUD、合并、导入导出方法
  - `AppStore.swift` 保留: `@Published` 属性、`init`/`load`/`save`、`safeWrite`/`safeRead`、`scheduleSave`、`dirtyKeys`/`suppressSave`、GameGroup/PlayerGroup 管理、CloudKit 同步、career stat 可见性
  - `AppStore+Player.swift` 移入: `player(for:)`、`addPlayer`、`updatePlayer`、`deletePlayers`、`upsertPlayers`、`mergePlayer`、`importPlayerPackage`、`exportPlayerBase64` + 全部 merge 私有辅助方法
  - `AppStore+Team.swift` 移入: `team(for:)`、`addTeam`、`updateTeam`、`deleteTeams`、`upsertTeams`、`mergeTeam`、`importTeamPackage`、`exportTeamBase64`、`exportTeam(id:...)` + 合并私有辅助方法
  - `AppStore+Game.swift` 移入: `saveGame`、`autoSaveGame`、`latestUnfinishedGame`、`exportGameBase64`、`deleteSavedGames`、`upsertSavedGames`、`importGamePackage`、`previewGameImportDisposition`、`decodeGamePackage` + 全部 remapping/import 私有辅助方法
  - 关键约束处理：`private` 跨文件不可见 → 将 `photoFile`/`photosDir`/`saveDeletedCloudGameIDs`/`deletedCloudGameIDs` 改为 internal（移除 `private`），其余私有辅助方法随调用方迁移到各自 extension 文件

### ~~7. `GameView` 提取 LiveCollaborationManager~~ ✅ 已修复
- **Branch**: `refactor` 分支（不涉及 `main`）
- **文件**: `Views/Game/GameView.swift`（3081→2731 行）、`Services/LiveCollaborationManager.swift`（新增 401 行）
- **问题**: `GameView.swift` ~3000 行，蓝牙直播协作状态和协议处理高度耦合
- **改动**:
  - 新建 `LiveCollaborationManager: ObservableObject`，持有所有直播状态属性和协议方法
  - GameView 以 `@StateObject private var liveManager` 持有实例
  - `onAppear` 中设置回调闭包：`onBuildStatePayload`、`onApplyOperation`、`onStateChanged`、`onAlert`
  - 移除 GameView 中 ~12 个 `@State` 属性和 ~17 个私有方法（约 350 行）
  - `applyResetGameOperation`/`startNewGame` 改为调用 `liveManager.resetSession()`
  - `collaborationStatus`、`.onChange` 处理器等全部转发到 `liveManager`

---

## 🔵 业务逻辑风险（待评估）

### 12. O/D 篮板模式切换时 `totalRebounds` 数据膨胀
- **文件**: `Models/Models.swift:745`
- **问题**: `rebounds + offensiveRebounds + defensiveRebounds`，模式切换后旧 `rebounds` 未清零

### 13. 蓝牙 dualAction 事件顺序的线程安全
- **文件**: `Views/Game/GameView.swift:311-316`
- **问题**: 两个 `submitLiveOperation` 对 `liveVersion` 的修改可能存在竞态

### 14. 撤销 `event.substitution` 的相关球员解析脆弱
- **文件**: `Views/Game/GameView.swift:2806-2833`
- **问题**: `relatedPlayerID` 为 nil 时从消息文本反解析，名字包含关系可能导致误匹配

### 16. 自定义语音映射的球员号码误匹配
- **文件**: `Models/VoiceRecognizer.swift:804-827`
- **问题**: `extractNumber` 是否会从"2分命中"中提取 2 作为球员号码
- **状态**: ⏳ 待用户确认具体场景（当前 standalone 正则 `(?:^|\\s)(\\d+)(?:\\s|$)` 不匹配 "2分命中"）

---

## ⚪ 建议优化（待评估）

### 20. 核心业务逻辑缺少单元测试
- ELO 计算、球员合并、比赛自动结束、统计计算
