# BasketballRecord

`BasketballRecord` 是一个基于 SwiftUI 的 iOS 篮球比赛记录应用，面向日常训练、野球局和队内统计。

## 平台与环境

- iOS 17.6+
- Xcode 17+
- Swift 5

## 核心功能

- 记分页面
- 支持两队比赛快速选择与记录。
- 选中球员头像高亮放大，未选中球员以 80% 透明度显示。
- 快速记录 2 分/3 分命中与不中、罚球、加罚、篮板、助攻、犯规。
- 命中按钮使用浅绿色风格，犯规按钮使用浅红色风格，强化操作辨识度。

- 球队与球员配置
- 创建、编辑、删除球队与球员。
- 支持合并球员 UUID、合并球队 UUID。
- 支持球员头像管理。

- 比赛历史
- 比赛按年月分组展示。
- 比赛详情按球队分开展示球员数据。
- 提供可折叠球队统计区，包含球队总览数据。

- AI 比赛分析
- 支持配置 DeepSeek API Key（连通性测试 + Keychain 存储）。
- 生成比赛总结、MVP 与高亮时刻，并保存到比赛记录。
- AI 分析结果使用图标化卡片展示，支持文本清洗与纯文本渲染。

- 球员卡
- 支持从比赛历史中选择统计范围。
- 提供按月分组、全选/全清、按月全选等操作。

- 数据导入导出
- 支持比赛、球队、球员的 Base64 导入导出。
- 配置页统一为单入口“导入数据”，并可选择导入类型（球队/球员）。
- 导入页支持解析结果预览、解析中 loading、解析按钮禁用态。
- 复制按钮提供“已复制”反馈，导入解析时自动收起键盘。

## 项目结构

- `BasketballRecord/`：应用源代码（视图、状态、模型）。
- `BasketballRecord.xcodeproj/`：Xcode 工程文件。
- `BasketballRecordTests/`：单元测试。

## 本地运行

1. 打开 Xcode：`BasketballRecord.xcodeproj`
2. 选择 Scheme：`BasketballRecord`
3. 选择模拟器或真机后运行。

## 版本

- 当前版本：`1.02`

## Release Notes

- 版本日志：`RELEASE_NOTES.md`

## App Store 上架文档

- 上架说明入口：`docs/appstore/README.md`
- 隐私政策：`docs/appstore/privacy-policy.md`
- 支持页面：`docs/appstore/support.md`
- 使用条款：`docs/appstore/terms-of-use.md`
- 元数据草案：`docs/appstore/app-store-metadata.md`
- 审核备注模板：`docs/appstore/review-notes.md`
