# BasketballRecord AI Agent Instructions

## i18n 规则
新增任何 UI 文本（包括 label、button、alert、picker、section header 等）时：
1. 在 en.lproj/Localizable.strings 添加英文 key
2. 在 zh-Hans.lproj/Localizable.strings 添加简体中文 key
3. **必须同时** 在 de、es、fr、it、ja、ko、ru、zh-Hant-TW 这 8 个 .lproj 文件添加同 key 并完成对应语言的翻译
4. 不要在硬编码字符串中使用非本地化文本，一律用 `LocalizedStringKey` 或 `NSLocalizedString`

## 工具使用规范
- 所有代码修改必须使用 `edit` 工具逐行处理
- Python 仅用于文本分析（如检查 i18n key 覆盖率），严禁用于修改代码
- 复杂的多步骤替换，分多次 `edit` 完成，每步之间要 build 验证
- 如果指令模糊或有问题，先问我确认清楚再执行

## 代码规范
- 用 4 空格缩进
- 不要添加注释
- 保持现有代码风格
- 新建比赛设置用 @AppStorage 持久化
- 字符串比较使用 eventCode 优先
- 所有可点击的 cell，tap action 必须绑定到整行区域（`.contentShape(Rectangle())`），不能只响应文字点击

## 分支与提交流程
项目有两个长期分支：

- **`main`** — App Store 发行版，不含任何 Pro 绕过代码
- **`main_free_pro`** — 个人自用，包含 `forcePro` 标志和 Pro 版 icon，不上架

### 规则
1. **未经用户明确要求，不得执行任何 `git commit`、`git merge`、`git push`、`git rebase` 操作。**
2. 修改代码前先确认目标分支，在正确的分支上改。
3. 如需跨分支同步改动，必须等待用户指定：
   - 哪些改动要同步到哪些分支
   - 同步方式（merge / cherry-pick / 重新改一遍）
4. `main_free_pro` 不应合入 `main`，反之亦然。如果需要让双向分支都有某段改动，用户会明确说。
5. 涉及 `PurchaseManager.swift` 和 `AppIcon.appiconset/AppIcon-1024.png` 的改动，默认只在当前分支生效，不会自动带到另一个分支。

## 自动同步到 pro 分支

每次在 `main` 上提交改动后，自动 cherry-pick 到 `main_free_pro` 分支并推送。

## 本会话已完成改动（2026-06-20）

### VoiceInstructionView 新增「Combined Commands」栏目
- 在 periodPause 和 shortcuts 之间新增 `combinedSection`，解释助攻+投篮/抢断+失误的复合指令用法
- 支持全部 10 种语言的本地化内容（zh-Hans/zh-Hant 含中文示例，ja/ko 含日韩示例，其余为英文示例）
- 新增 `voice_instruction_combined` 本地化 key 到全部 10 个 .strings 文件

### 前场篮板/后场篮板功能

**新增 StatAction 类型：** `offensiveRebound`、`defensiveRebound`（`StatAction.swift`）

**PlayerStats 新增属性：** `offensiveRebounds`、`defensiveRebounds`，`totalRebounds` 计算属性为三者之和（`Models.swift`）

**Bluetooth 支持：** `BluetoothLiveStatAction` 添加对应 case（`BluetoothProtocolModels.swift`）

**语音规则拆分：** 所有 10 种语言的 VoiceRules 中，`前场板/オフェンスリバウンド/offensive rebound` 等改为 `stat.offensiveRebound`，`后场板/ディフェンスリバウンド/defensive rebound` 等改为 `stat.defensiveRebound`

**球队数据展示调整（`TeamStatsView.swift`）：**
- 原「REB / BLK」行 → 显示「REB (总) / OREB (前场) / DREB (后场)」
- 原「AST / STL」行 → 并入 BLK，显示「AST / STL / BLK」
- 球员详情 tile 中 `stats_full_misc_format` 显示 `totalRebounds(off-def)`

**语音示例（`VoiceCommandExamples.swift`）：** 所有 10 种语言增加 `offensiveRebound`/`defensiveRebound` 的 statTypeNames 和 actionTemplates

**本地化（全部 10 个 .strings）：**
- 新增 `action_offensive_rebound`、`action_defensive_rebound`
- 新增 `stats_rebound_detail`、`stats_assist_steal_block`
- 更新 `stats_full_misc_format`

### VoiceRecognizer 关键词过滤（2026-06-20 追加）

**问题：** O/D 篮板模式下，"前场篮板"等语音会先被通用关键词"篮板"匹配（中文"篮板"是"前场篮板"的子串），导致识别为 `stat.rebound` 而非 `stat.offensiveRebound`。经检查，全部 10 种语言的通用篮板词都包含在对应 O/D 篮板词中。

**方案（`VoiceRecognizer.swift`）：**
- 新增 `allStatEvents` / `allCommandEvents` 存储规则原始列表
- 新增 `rebuildNonShotEvents()`，根据 `snapshot.showsOffensiveDefensiveRebound` 过滤：
  - O/D 模式 → 移除 `stat.rebound` 条目（只保留 `stat.offensiveRebound`/`stat.defensiveRebound`）
  - 普通模式 → 移除 `stat.offensiveRebound`/`stat.defensiveRebound` 条目
- `currentSnapshot.didSet` 及新增 `setReboundFilterMode(_:)` 触发重建
- `VoiceTutorialView` 在 `selectTask()` 时根据任务 expectedAction 调用 `setReboundFilterMode`

### O/D 篮板模式布局调整

- **GameSetupView：** 新增 O/D 篮板 toggle，与常规篮板互斥
- **GameView：** O/D 模式下，steal 从第三行移到第四行，第一行变为 助攻/前场板/后场板/盖帽
- **默认 Tab：** 无球员/球队时默认切到球队管理页，否则切到计时器页；dumbbell.fill 替代 scalemass 图标

### VoiceRecognizer 普通模式 O/D 映射
- 普通模式下 O/D 篮板关键词不丢弃，改为映射为 `stat.rebound`
- `rebuildNonShotEvents()` 中 O/D 模式：移除 `stat.rebound`；普通模式：将 O/D 条目的 action 改为 `stat.rebound`

### GameSnapshot Codable 修复
- 自定义 `init(from:)` 中补充了 `showsOffensiveDefensiveRebound` 的 decode

### restoreLatestGameIfNeeded 修复
- 补充了 `voiceRecognizer.currentSnapshot = snapshot`

### 中文拼音变体增强
- 新增「全场板」「全场篮板」作为前场篮板变体
- 新增 `("ian", "uan")` 双向拼音替换规则（覆盖「前」↔「全」混淆）

### 全部 10 种语言 O/D 篮板关键词变体
- 每种语言在原有 O/D 篮板关键词基础上，补充了额外的正常音变/同义词/同音词/常见 ASR 变体
- 例如中文补充了「全场板」「全场篮板」等

### TeamStatsView 宽度调整
- 每列宽度从 64 调整为 80

### 中文 tutorial hint 移除「进了」
- Simplified 和 Traditional 中文共 13 处 hardcoded hint 中「进了」→「命中」
- Traditional Chinese 的 bonusMade action template `"{name}加罰進了"` → `"{name}加罰命中"`

### Tutorial 新增 O/D 篮板任务
- 全部 10 种语言的 tutorial 新增 taskDef(id:26, action:.offensiveRebound) 和 taskDef(id:27, action:.defensiveRebound)

## Release Notes 更新规则

1. **默认行为**：当我说"更新 release note"时，直接将当前版本的修改内容追加到当前版本的 section 中。
2. **新建版本**：只有当我说"把当前版本设置为 xx，更新 release note"时，才创建新的版本 section，并将新内容放入该版本。

## 版本号规则

`main_free_pro` 分支的大版本号（major version）始终比 `main` 分支大 1，小版本号保持一致。例如：
- `main` 为 1.20 → `main_free_pro` 为 **2.20**
- `main` 为 1.21 → `main_free_pro` 为 **2.21**

在修改 `CFBundleShortVersionString` 时务必同时更新两个分支并遵守此规则。
