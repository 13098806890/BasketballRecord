# Release Notes

## 1.21 (2026-06-12)

### 新增

- **语音记分加入 Pro 订阅**：记分页麦克风按钮、设置页语音入口现为 Pro 功能，非 Pro 用户点击弹出购买页面。
- **语音日志开关**：设置页新增「启用语音日志」开关，关闭后不再记录识别详细过程。
- **灌篮高手 Demo 数据**：初始样例数据替换为湘北/陵南 6 名球员（赤木晴子、樱木花道、流川枫、仙道、彩子、牧绅一），附带头像照片。10 种语言对应角色翻译。
- **订阅页可滚动**：特性说明区域改为 `ScrollView`，确保订阅按钮始终可见。
- **AI 分析优化**：按节次输出比赛分析，系统预计算个人/球队连续得分、连续篮板、连续助攻、连续投篮不中，直接供 AI 引用，避免 LLM 推算错误。
- **AI 分析可复制/保存为图片**：长按复制单节文本；「保存到相册」按钮将完整 AI 总结渲染为图片，尺寸适配屏幕宽度，保留 App 内格式与图标。
- **版本号 1.21**：`main` 1.21，`main_free_pro` 2.21。
- **App Store 元数据更新**：优化关键词（含语音记分/语音识别），所有语言 desc 标注 Pro 功能。

### 修复

- **代码审查修复**：修复 `Dictionary(uniqueKeysWithValues:)` 重复 ID 崩溃、`AIService` force-unwrap URL、`VoiceRecognizer` 回调线程安全、`revertLastAction` 中文硬编码解析、CoreData `NSBatchDeleteRequest` 上下文不一致等 20 项问题。
- **ASR 语音变体补全**：为 10 种语言补充 55 条语音变体匹配规则，ASR 测试 209 全通过。
- **比赛名称不持久化**：`CoreDataStore.fetchAllSavedGames()` 缺少 `displayName`，已补上。
- **AI 按钮非 Pro 无反应**：非 Pro 用户点击 AI 总结按钮弹出订阅购买页面。
- **语音录制前 0.5s 延迟**：音频引擎预热（`prepareEngine()`），节省 ~300ms。
- **音频降噪**：录音模式改为 `.measurement`，排除 `.default` 模式格式不兼容问题。
- **语音识别失败震动**：失败时 3 次中等震动反馈。
- **SettingsDocumentView 语言切换**：添加 `@Environment(\.locale)` 观察，切换语言后自动刷新内容。
- **Demo 照片加载路径修复**：`seedSampleData()` 从 Bundle 根目录加载球员头像。
- **蓝牙协议中文转 English**：4 处 `sendAuthoritativeSnapshot` reason 参数由中文改为英文。
- **SubstitutionView 切换 side 清空选择**：避免跨队换人。
- **5 个测试用例修复**：更新 `StatAction` 数量、删除无效 VoiceMatching 测试、本地化 LegacyUndo 消息。
- **订阅页 ProSubscriptionStoreView 改为 internal**：GameView 可直接调用购买页面。

### 优化

- **AI Prompt 优化**：系统角色加入结构化数据说明，移除不确定措辞，口语化输出。每节至少 5-8 句，MVP 和亮点分析更详尽。
- **记分页球员名自适应字号**：`minimumScaleFactor` 自动缩放，名字不再换行。
- **球员标签格式**：`X号` 改为 `NoX`，字号调小。

### 国际化

- 新增 `settings_voice_log_enable` / `settings_voice_log_enable_footer` 至全部 10 种语言。
- 新增 `pro_feature_voice_1` / `pro_feature_voice_2` 至全部 10 种语言。
- 新增 `button_save_to_photos` 至全部 10 种语言。
- 同步 AI prompt 翻译（`ai_system_role`、`ai_prompt_req_4~14` 等）至全部 10 种语言。
- 替换 `sample_player_1~4` 为 `demo_player_*` 灌篮高手角色名，全部 10 种语言。
- Demo 球队 `demo_team_shohoku` / `demo_team_ryonan` 全部 10 种语言。

## 1.20 (2026-06-11)

### 修复

- **自定义语音快捷指令不生效修复**：匹配逻辑从精确 `[text]` 字典查询改为 `contains` 遍历 key，先匹配成功则优先使用；球员号码/姓名从短语左侧残留文本提取，与现有投篮事件匹配模式一致。
- **语音日志不持久化修复**：`AppStore.load()` Core Data 路径下不再提前 `return`，改为同时读取 `StoreMeta` 中的 `voiceLog` 和 `customVoiceMappings` 恢复语音数据。

### 新增

- **语音快捷指令编辑**：指令列表行点按即可打开编辑 Sheet，支持修改短语或动作类型。修改短语时自动移除旧 key。
- **多音字姓氏语音匹配**：中文语音规则新增多音字姓氏覆盖映射（曾→zeng、单→shan、朴→piao、解→xie、区→ou、仇→qiu、盖→ge、查→zha 等 13 个常见姓氏）。球员名字匹配时自动补充替代拼音形式，提高 ASR 识别准确率。

### 国际化

- 新增 `voice_shortcuts_edit_title` key 至全部 10 种语言。

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
