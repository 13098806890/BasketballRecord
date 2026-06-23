# Code Review TODO

## 🔴 严重风险（优先修复）

### ~~1. `AppStore.safeWrite` 中的强制类型转换~~ ✅ 已修复
- **文件**: `Services/AppStore.swift`
- **问题**: `valueToEncode = game as! T` 当 `T` 不是 `SavedGame` 时直接崩溃
- **改动**: 
  - `safeWrite` 对 `game_` 前缀的 key 走独立路径：先 `as? SavedGame` 安全拆包，trim 后重新 encode，不再强制转换 `T`
  - `safeRead` 同理，对 `game_` 前缀先 decode 为 `SavedGame` 再 trim，`as? T` 作为安全回退
  - 提取 `readRawData` 公用方法消除重复

### ~~2. CoreData NSBatchDeleteRequest 后 context 不一致~~ ✅ 已修复
- **文件**: `Services/CoreDataStore.swift:276-283`
- **问题**: `deleteAll()` 使用 `NSBatchDeleteRequest` 后需要在同一个 context 同步状态
- **改动**: 在 `NSManagedObjectContext.mergeChanges` 后追加 `context.refreshAllObjects()`，确保 context 完全同步

### ~~3. `mergedStats` 遗漏细分字段~~ ✅ 已修复
- **文件**: `Services/AppStore.swift:1297-1325`
- **问题**: 球员合并未合并 `layupMade/Attempts`、`midRangeMade/Attempts`、`paintMade/Attempts`、`offensiveRebounds`、`defensiveRebounds`
- **改动**: 补充全部 10 个遗漏字段的累加

### ~~4. CloudKit temp 文件无限增长~~ ✅ 已修复
- **文件**: `Services/CloudKitManager.swift:70-95`
- **问题**: `writeTempFile` 每次上传创建临时文件但不清理
- **改动**: `uploadGame` 中将文件创建提前到 `do` 块开头，用 `defer { try? FileManager.default.removeItem(at: fileURL) }` 确保方法退出时自动清理

### ~~5. PurchaseManager 的 `isPro` 异步闪屏~~ ✅ 已修复
- **文件**: `Services/PurchaseManager.swift:45-49`
- **问题**: `checkSubscriptionStatus()` 在 `loadProducts()` 之后才执行，延迟了 StoreKit 状态刷新
- **改动**: 
  - `init` 中 `Task` 改为先 `checkSubscriptionStatus()` 再 `loadProducts()`
  - `checkSubscriptionStatus` 内加 `if foundPro != isPro` 判断，值未变时不触发 `@Published` 发布，避免冗余 UI 刷新

## 🟡 代码质量与可维护性

### 6. `AppStore` 上帝类
- **文件**: `Services/AppStore.swift`（1433 行）
- **方案**: 拆分出 `PlayerManager`、`TeamManager`、`GameManager`

### 7. `GameView` 超大 View
- **文件**: `Views/Game/GameView.swift`（3017 行）
- **方案**: 将蓝牙协作状态机提取为 `LiveCollaborationManager`；将模拟器逻辑提取到单独服务

### 8. `VoiceRecognizer` 责任过重
- **文件**: `Models/VoiceRecognizer.swift`
- **方案**: 将 UI 状态（`flashColor`、`match`）移出，仅保留识别+匹配合成逻辑

### 9. VoiceRules 文件代码重复
- **文件**: `Models/VoiceRules_*.swift`
- **方案**: 改用 JSON/plist 配置文件

### 10. CoreData 实体通过代码手动创建
- **文件**: `Services/CoreDataStack.swift`
- **方案**: 使用 `.xcdatamodeld` 文件可视化定义模型

### 11. CoreDataStore 使用 KVC 访问属性
- **文件**: `Services/CoreDataStore.swift`
- **方案**: 使用 `@NSManaged` 属性包装或代码生成

## 🔵 业务逻辑风险

### 12. O/D 篮板模式切换时 `totalRebounds` 数据膨胀
- **文件**: `Models/Models.swift:745`
- **问题**: `rebounds + offensiveRebounds + defensiveRebounds`，模式切换后旧 `rebounds` 未清零

### 13. 蓝牙 dualAction 事件顺序的线程安全
- **文件**: `Views/Game/GameView.swift:311-316`
- **问题**: 两个 `submitLiveOperation` 对 `liveVersion` 的修改可能存在竞态

### 14. 撤销 `event.substitution` 的相关球员解析脆弱
- **文件**: `Views/Game/GameView.swift:2806-2833`
- **问题**: `relatedPlayerID` 为 nil 时从消息文本反解析，名字包含关系可能导致误匹配

### ~~15. `event.period_start` 撤销未恢复时间状态~~ ✅ 已修复
- **文件**: `Views/Game/GameView.swift:2836-2848`
- **问题**: 只重置了 `periodIsRunning`，未关闭活跃 stints/clocks
- **改动**: 撤销 `event.period_start` 时调用 `closeActiveStints`、`closeMatchClock`、`closePeriodClock`，并设置 `isPaused = false`

### 16. 自定义语音映射的球员号码误匹配
- **文件**: `Models/VoiceRecognizer.swift:804-827`
- **问题**: `extractNumber` 会提取"2分命中"中的 2 作为球员号码
- **状态**: ⏳ 待确认具体场景（当前 standalone 正则 `(?:^|\\s)(\\d+)(?:\\s|$)` 不匹配 "2分命中"）

## ⚪ 建议优化

### ~~17. 保存 debounce 500ms 可能丢失中间状态~~ ✅ 已修复
- **文件**: `Services/AppStore.swift:956-969`
- **问题**: 被取消的 saveTask 在 `save()` 完成后仍会清除 `dirtyKeys`，导致后续新 saveTask 认为无脏数据从而跳过 CoreData/game 写入
- **改动**: 引入 `saveGeneration` 计数器，`save()` 完成后校验 `saveGeneration` 未变才清除 `dirtyKeys`

### ~~18. Keyboard dismissal 使用 UIKit API~~ ✅ 已修复
- **文件**: `Views/Game/GameSetupView.swift:195-200`
- **方案**: 改用 `@FocusState` 管理 TextField 焦点，toolbar Done 按钮设为 `isInputFocused = false`

### ~~19. en.lproj 的 comment 包含中文~~ ✅ 无需处理
- **结论**: 经确认 `en.lproj/Localizable.strings` 中无中文 comment，中文仅出现在 `zh-Hans`/`zh-Hant-TW` 中，属正确行为

### 20. 核心业务逻辑缺少单元测试
- ELO 计算、球员合并、比赛自动结束、统计计算

### ~~21. PurchaseManager.appAccountToken 可能主线程阻塞~~ ✅ 已修复
- **文件**: `Services/PurchaseManager.swift:16-31`
- **问题**: `try? NSUbiquitousKeyValueStore.default`（多余 try）、`synchronize()`（已废弃）
- **改动**: 移除多余 `try?`，移除已废弃的 `synchronize()` 调用
