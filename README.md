# BasketballRecord

`BasketballRecord` 是一个基于 SwiftUI 的 iOS 篮球比赛记录应用，面向日常训练、野球局和队内统计。已上架 App Store。

## 平台与环境

- iOS 17.6+
- Xcode 17+
- Swift 5

## 核心功能

- **语音记分**：按住麦克风按钮说话，自动识别球员、动作和得分（10 种语言，含拼音模糊匹配、Levenshtein 纠错、多音字支持）
- **球队模式**：按球队整体记分（不区分个人），支持语音识别球队名称
- **AI 比赛分析**：基于 DeepSeek API，生成比赛总结、MVP、高光时刻，支持保存为图片
- **记分页面**：快速记录 2 分/3 分/罚球、篮板、助攻、犯规；上篮/中投/篮下细分统计
- **球队与球员配置**：创建、编辑、删除，支持头像管理和 UUID 合并
- **比赛历史**：按年月分组展示，折叠球队统计
- **球员卡**：按月份选择统计范围，跨场次汇总
- **数据导入导出**：比赛/球队/球员的压缩编码导入导出
- **i18n**：10 种语言本地化
- **Core Data 存储**，自动兼容旧 UserDefaults 数据

## 项目结构

- `BasketballRecord/`：应用源代码（视图、状态、模型）
- `BasketballRecord.xcodeproj/`：Xcode 工程文件
- `BasketballRecordTests/`：单元测试（200+ 语音测试用例）

## 本地运行

1. 打开 Xcode：`BasketballRecord.xcodeproj`
2. 选择 Scheme：`BasketballRecord`
3. 选择模拟器或真机后运行。

## 版本

- 当前版本：`1.22`
- [版本日志](RELEASE_NOTES.md)

## 链接

- [宣传页面](https://13098806890.github.io/BasketballRecord/)
- [隐私政策](https://13098806890.github.io/BasketballRecord/appstore/privacy-policy.html)
- [支持页面](https://13098806890.github.io/BasketballRecord/appstore/support.html)
- [App Store](https://apps.apple.com/app/id6741163776)
