# TODO

> 分支: `main_free_pro` (基于 e6bcf89)  
> 本地有 14 个文件已修改，其中 9 个 Swift 改+增、10 个语言文件  
> ViewModels/GameViewModel.swift 已建立骨架但未完成

---

## 已完成

- [x] **高1 — putbackMissed 统计不一致**

  `LoggedAction.apply` 把 `.putbackMissed` 记入 `offensiveRebounds`（正确：补篮 miss 计前场板），而 `StatAction.apply` 原版记入 `rebounds`（错误）。  
  **方案**: 统一用 `StatAction.apply` 已修正—`.putbackMissed` → `stats.offensiveRebounds += 1`。  
  改动涉及: `StatAction.swift`（新 Models 版）

- [x] **高2 — scoringCodes / pointMap 缺少 5 种投篮类型**

  `SavedGameDetailView.scoringRunData()` 和 `scoreTimelineText()` 缺少 `layupMade/midRangeMade/paintMade/putbackMade/dunkMade`，导致这些得分事件在 AI prompt 的时间线里丢失。  
  **方案**: 集中到 `StatAction.scoringEventCodes` 和 `StatAction.pointMap` 两个静态属性，统一供给 `scoringRunData()/scoreTimelineText()`，不再硬编码 Set/Dict。  
  改动涉及: `StatAction.swift`, `SavedGameDetailView.swift`

- [x] **高3 — AppStore.save() 全删全插有数据丢失风险**

  原 `saveIfNeeded()` 中 `savedGames` 脏后执行 `deleteAllSavedGames()` 再循环 `upsertSavedGame`，中间 crash 则所有比赛丢失。  
  **方案**: 改为 diff+upsert 策略：  
  1. `CoreDataStore.fetchAllSavedGameIDs()` 获取现存的 ID 集合  
  2. `newIDs - existingIDs = toDelete`，只删除不存在的  
  3. 所有 game 逐条 upsert（insert or update）  
  4. 新增 `deleteSavedGame(id:)` + `fetchAllSavedGameIDs()` 方法  
  改动涉及: `AppStore.swift`, `CoreDataStore.swift`

- [x] **高4 — displayStatsByPlayerID O(N²) + print 刷屏**

  在 `SavedGameDetailView` 中，每行 player 的 `displayStatsByPlayerID[playerID]` 调用都会导致整个字典重新构建（每次访问 O(N)），频繁访问时触发 debug print。  
  **方案**: 移除了 `computed` 属性中的 print 语句；确保 `periodAnalysis` 是一次 `analyze()` 缓存后的结果，不再每行重新计算。同时 `playingTimeByPeriod()` 结果也缓存到 `cachedPlayingTimeByPeriod`，仅在 `onAppear` 初始化一次。  
  改动涉及: `SavedGameDetailView.swift`

- [x] **中5 — LoggedAction 和 StatAction 重复**

  两套枚举做同一件事（`SavedGameAnalyzer` 用 `LoggedAction`，`GameView` 用 `StatAction`），`apply(to:)` 逻辑不同步，新增事件类型需要改两处，`SavedGameAnalyzer` 的 fallback 解析路径还依赖硬编码中文/英文 suffix。  
  **方案**:  
  1. 将 `StatAction` 从 `Views/Game/StatAction.swift` 移至 `Models/StatAction.swift`  
  2. 给 `StatAction` 增加 `suffix`（中文）、`englishSuffix`（英文）、`suffixCandidates`（两者合并）属性  
  3. 删除 `LoggedAction` 全部代码  
  4. `SavedGameAnalyzer` 中所有 `LoggedAction` 引用替换为 `StatAction`  
  5. `relatedActionEventCode` 改为 `relatedAction`，直接返回 `StatAction?` 而非 `String`  
  改动涉及: `StatAction.swift`（R 到 Models）、`StatAction+UI.swift`（新增 UI 扩展）、`SavedGameAnalyzer.swift`

- [x] **中6 — AI prompt 硬编码中文**

  `summaryPrompt()` 里有大量中文硬编码（节次标题、数值校验提示、比分时间线等），非中文用户收到中文上下文，影响 LLM 输出质量。  
  **方案**: 全部替换为 `NSLocalizedString(...)`：  
  - `ai_prompt_and_one_format`（and-one 描述）  
  - `ai_prompt_default_section_title`（默认段落标题 "比赛总结"）  
  - 以及其他隐藏中文 label/格式串  
  改动涉及: `SavedGameDetailView.swift` + 10 个语言文件 × 45 个 key

- [x] **中7 — resolvedPlayerID 5 处重复且排序不一致**

  `SavedGameAnalyzer` 按名字长度降序排（正确），`SavedGameDetailView` 不排序（可能匹配错人）。  
  **方案**: 统一为 `SavedGameAnalyzer` 的排序方式，`SavedGameDetailView` 中的 `resolvedPlayerID` 也按名字长度降序匹配。  
  改动涉及: `SavedGameDetailView.swift`, `SavedGameAnalyzer.swift`

- [x] **中8 — analyzer.analyze() 在 summaryPrompt 里被调 2 次**

  `periodEventsText()` 和 `summaryPrompt()` 各调一次 `analyze()`，重复 CPU 计算。  
  **方案**: 将 `analyze()` 结果缓存到 `@State periodAnalysis`，在 `.task` 中执行一次；`periodEventsText()` 和 `summaryPrompt()` 都读缓存。  
  改动涉及: `SavedGameDetailView.swift`

- [x] **中9a — try? 静默吞错误（关键路径）**

  3 处 CoreData decode + 2 处文件读取用 `try?`，失败时比赛静默消失（收到空数据）或无日志。  
  **方案**: 全部改为 `do { ... } catch { print("[CoreData/Storage] ...") }`，decode 失败时打印具体错误 + key，让调试可追踪。  
  改动涉及: `AppStore.swift`, `CoreDataStore.swift`

- [x] **中9b — fatalError 在生产路径**

  `AIServiceProxy` 和 `CloudShareManager` 共 4 处 `fatalError`，URL 字符串硬编码非法时 app 崩溃。  
  **方案**: 将 `computed var` 返回 `URL?` + 调用处 `guard let ... else { throw .notConfigured }`。新增 `AIServiceProxyError.notConfigured` 错误 case。  
  改动涉及: `AIServiceProxy.swift`, `CloudShareManager.swift`

- [x] **中9c — AnyView 性能损耗**

  `SavedGameDetailView.aiSummaryContent` 用 `AnyView` 做条件分支，`AnyView` 会擦除具体类型导致 SwiftUI diffing 性能下降。  
  **方案**: 改用 `@ViewBuilder` 隐式分支。  
  改动涉及: `SavedGameDetailView.swift`

- [x] **i18n — 46 个新 key 写入 10 个语言文件**

  新增 `putbackMade/putbackMissed/dunkMade/dunkMissed` 等事件的 action label key，以及 AI prompt 本地化 key。  
  **方案**: 所有 10 个 `.lproj/Localizable.strings` 同步写入 45 个新 key，英文用原文、简体中文用中文翻译、其余 8 语种用英文占位（待专业翻译润色）。  
  改动涉及: `en.lproj`, `zh-Hans.lproj`, `de.lproj`, `es.lproj`, `fr.lproj`, `it.lproj`, `ja.lproj`, `ko.lproj`, `ru.lproj`, `zh-Hant-TW.lproj`

---

## 搁置

- [x] **低10+13 — GameViewModel 提取（待你在 Xcode 中操作）**

  **已准备**: `ViewModels/GameViewModel.swift`（40 行）— skeleton 已包含 `GameSnapshot` 封装 + undo/redo stack + `mutateSnapshot`
  
  ## 已完成 ✅

  **状态**: VM 骨架已完善，`GameView.swift` 已完成迁移。
  
  ### 已完成的改动
  - `@State private var snapshot` / `undoStack` / `redoStack` / `hasMigratedUndo` → 移除
  - `@StateObject private var gameVM = GameViewModel()` → 添加
  - `snapshot.` → `gameVM.snapshot.`（280 处替换）
  - `undoStack` → `gameVM.undoStack`（21 处）
  - `redoStack` → `gameVM.redoStack`（17 处）
  - `addEvent()` / `mutateSnapshot()` / `eventPeriodContext()` → 删除（移至 VM）
  - `GameViewModel.swift` 完善：`undo()` / `redo()` / `resetGame()` / `mutateSnapshot()` / `addEvent()` / `score(for:)` / `eventPeriodContext()`
  - undo/redo/wrap 保留 `liveManager.submitLiveOperation` 外包装
  
  ### 剩余
  - 用 Xcode build 验证，看有没有编译错误
  - 把 `self.currentGameRecordID` 的几个引用检查一下

- [x] **SavedGameDetailView.swift 拆分（2260 → 533 行）**

  **操作**: 分三步拆出了 3 个新文件：
  1. `AISummaryView.swift`（1169 行）— AI 总结展示、prompt 构建、AI 调用逻辑
  2. `ExportGameView.swift`（241 行）— 游戏导出（cloud/text/蓝牙）
  3. `GameEventLogEditorView.swift`（370 行）— 事件日志编辑（增/删/改/恢复）
  
  移除了 9 个 @State + 相关的 init/onAppear/alert/sheet

  原文件变化:
  - AI 总结部分: 2260 → 1114 行
  - Export 部分: 1114 → 873 行
  - 事件编辑部分: 873 → 533 行
  - **最终: 533 行**（仅剩 teamSummary/playerStatRow/homePlayer/awayPlayer/groupAssignment/helper 方法）
  
- [ ] **低10/2 — 统计表格拆分（剩余任务）**
  - 建议拆为 `Views/History/StatsTableView.swift`
  
- [ ] **低10/3 — 比分时间线拆分（剩余任务）**
  - 建议拆为 `Views/History/ScoreTimelineView.swift`  

- [x] **RosterView.swift 拆分（1838 → 340 行）**

  **状态**: ✅ 已完成  
  **操作**: 拆分为 9 个独立文件：
  | 新文件 | 行数 |
  |--------|------|
  | `TeamManagementView.swift` | 50 |
  | `PlayerManagementView.swift` | 62 |
  | `CreateRosterItemView.swift` | 50 |
  | `MergeRosterUUIDView.swift` | 34 |
  | `ExportTeamPackageView.swift` | 236 |
  | `ImportRosterPackageView.swift` | 578 |
  | `ExportPlayerPackageView.swift` | 242 |
  | `MergePlayerUUIDView.swift` | 95 |
  | `MergeTeamUUIDView.swift` | 95 |
  
  **剩余内容**: `RosterView` 主体 + `RosterActionIcon` + `rosterPlayerSubtitle`（已去掉 `private` 以便跨文件访问）  

- [x] **Models.swift 拆分（1505 → 1151 行）**

  **已提取 4 个新文件：**
  | 新文件 | 类型 |
  |------|------|
  | `Models/Player.swift` | `Player`, `PlayerGroup`, `Team`, `ExportPlayer`, `ExportTeam` |
  | `Models/BadgeType.swift` | `BadgeType`, `PlayerBadge` |
  | `Models/GameEnums.swift` | `PlayerGameRole`, `CareerStatSection`, `CareerStatItem`, `PeriodEndCondition` |
  | `Models/AnyCodingKey.swift` | `AnyCodingKey` |

  **剩余内容**: Export* 系列、Transfer* 系列、PlayerStats、GameLogEntry、GameSnapshot、SavedGame（互引用较多，需更小心拆分）

- [ ] **低10 — 其他大文件（待拆）**

  | 文件 | 行数 | 说明 |
  |------|------|------|
  | `BluetoothSyncManager.swift` | 1618 | 单个 class + 3 个 delegate extension，难拆 |
  | `VoiceRecognizer.swift` | 1465 | 单个 recognizer 类，含 VoiceLogEntry/VoiceCommand |
  | `TutorialDataProvider.swift` | 1318 | 静态教程数据，可拆|
  | `Models.swift` (其余) | 1151 | Export/Transfer/PlayerStats/GameSnapshot/SavedGame |

---

## ~~本地未提交的额外项~~

- [x] **opencode-changes.patch** — 已删除，不存在

- [x] **BasketballRecord/ViewModels/ 目录**

  项目使用 Xcode 16 的 `PBXFileSystemSynchronizedRootGroup`（`objectVersion = 77`），Xcode 自动从文件系统同步所有文件。`BasketballRecord/ViewModels/GameViewModel.swift` 已在 `BasketballRecord/` 目录下，自动参与编译，无需修改 pbxproj。

---

> 所有 9 个 Swift 文件改动 + 10 个语言文件改动均已 staged，`git diff --cached` 可见。  
> `ViewModels/GameViewModel.swift` 和 `opencode-changes.patch` 为 untracked。
