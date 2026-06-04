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
