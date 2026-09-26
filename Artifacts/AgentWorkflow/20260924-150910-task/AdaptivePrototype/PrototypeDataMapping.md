# 独立原型数据映射

原型不引用产品 target，只复制现有模型的字段语义，使用 mock 数据验证布局。这样可以先 review UI，再决定是否把视图迁回产品代码。

| 原产品语义 | 原型字段 | 使用位置 |
| --- | --- | --- |
| Player.id / name / height / weight / number / position | PrototypePlayer | 球员档案、球员行、成长页身份卡 |
| Player.teamName 关联 Team.name | PrototypePlayer.teamName | 球员档案身份卡 |
| PlayerStats.twoMade / twoAttempts / threeMade / threeAttempts | PrototypePlayerStats | 得分、命中率、球员表现 |
| PlayerStats.rebounds / assists / fouls / steals / blocks / turnovers | PrototypePlayerStats | 球员表和累计数据语义 |
| SavedGame.displayName / team names / score | PrototypeSavedGame | 比赛详情、最近比赛、最近保存 |
| SavedGame.aiSummary | PrototypeSavedGame.aiSummary | AI 复盘 |
| SavedGame.modifiedDate | PrototypeSavedGame.modifiedDate | 页面日期和比赛列表 |
| SavedGame.playerNamesByID | PrototypeSavedGame.playerNamesByID | 保留球员 ID 到展示名的关系 |
| GameLogEntry.timestamp / message / eventCode / period / elapsedSeconds | PrototypeGameLog | 事件数据 mock，当前页面预留 |
| Team 集合、Player 集合、PlayerGroup / GameGroup 计数 | PrototypeMockData.teams / players 与管理页计数 | 数据管理 |

原型刻意不实现记分操作。`UnchangedScoringSurface` 只作为导航占位，验收范围不包含记分页，也不会修改产品 `BasketballRecord/Views/Game/`。
