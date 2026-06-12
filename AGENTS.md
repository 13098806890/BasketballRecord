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

## 代码规范
- 用 4 空格缩进
- 不要添加注释
- 保持现有代码风格
- 新建比赛设置用 @AppStorage 持久化
- 字符串比较使用 eventCode 优先

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

## Release Notes 更新规则

1. **默认行为**：当我说"更新 release note"时，直接将当前版本的修改内容追加到当前版本的 section 中。
2. **新建版本**：只有当我说"把当前版本设置为 xx，更新 release note"时，才创建新的版本 section，并将新内容放入该版本。

## 版本号规则

`main_free_pro` 分支的大版本号（major version）始终比 `main` 分支大 1，小版本号保持一致。例如：
- `main` 为 1.20 → `main_free_pro` 为 **2.20**
- `main` 为 1.21 → `main_free_pro` 为 **2.21**

在修改 `CFBundleShortVersionString` 时务必同时更新两个分支并遵守此规则。
