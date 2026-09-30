import SwiftUI

struct PrototypeShell: View {
    @Binding var selectedTab: PrototypeTab
    let data = PrototypeMockData.current

    var body: some View {
        ZStack {
            PrototypeTokens.paper.ignoresSafeArea()
            Group {
                switch selectedTab {
                case .score:
                    UnchangedScoringSurface()
                case .history:
                    GameReviewPrototypeView(data: data)
                case .career:
                    CareerPrototypeView(data: data)
                case .settings:
                    RosterManagementPrototypeView(data: data)
                case .profile:
                    PlayerProfilePrototypeView(data: data)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrototypeBottomBar(selection: $selectedTab)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct PrototypeBottomBar: View {
    @Binding var selection: PrototypeTab

    var body: some View {
        HStack(spacing: 0) {
            PrototypeBottomItem(title: "记分", icon: "plus.circle", tab: .score, selection: $selection)
            PrototypeBottomItem(title: "历史", icon: "clock.arrow.circlepath", tab: .history, selection: $selection)
            PrototypeBottomItem(title: "生涯", icon: "chart.bar.xaxis", tab: .career, selection: $selection)
            PrototypeBottomItem(title: "设置", icon: "slider.horizontal.3", tab: .settings, selection: $selection)
        }
        .padding(.top, 9)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(PrototypeTokens.line).frame(height: 1) }
    }
}

struct PrototypeBottomItem: View {
    let title: String
    let icon: String
    let tab: PrototypeTab
    @Binding var selection: PrototypeTab

    var body: some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selection == tab ? PrototypeTokens.orange : PrototypeTokens.inkSoft)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let trailing: String

    var body: some View {
        HStack(alignment: .bottom) {
            PrototypeSectionTitle(eyebrow: eyebrow, title: title)
            Spacer()
            Text(trailing)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(PrototypeTokens.blue)
        }
    }
}

struct GameReviewPrototypeView: View {
    let data: PrototypeMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "HISTORY / 03", title: "看懂一场比赛", trailing: data.game.modifiedDate)
                PrototypeCard {
                    VStack(spacing: 14) {
                        HStack {
                            Text(data.game.homeTeamName).font(.system(size: 14, weight: .bold, design: .rounded))
                            Spacer()
                            Text(data.game.awayTeamName).font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(data.game.homeScore)").font(.system(size: 54, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                            Text("—").font(.system(size: 24, weight: .bold)).foregroundStyle(PrototypeTokens.orange)
                            Text("\(data.game.awayScore)").font(.system(size: 54, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                        }
                        HStack(spacing: 8) {
                            Text("已完成").foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 5).background(PrototypeTokens.orange).clipShape(Capsule())
                            Text("最终比分").foregroundStyle(PrototypeTokens.inkSoft)
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }
                HStack(spacing: 8) {
                    ReviewTab(title: "概览", active: true)
                    ReviewTab(title: "数据", active: false)
                    ReviewTab(title: "事件", active: false)
                    ReviewTab(title: "AI复盘", active: false)
                }
                PrototypeSectionTitle(eyebrow: "GAME SNAPSHOT", title: "一眼看清关键数据")
                HStack(spacing: 10) {
                    MetricTile(value: "58%", label: "投篮命中", tint: PrototypeTokens.paleBlue)
                    MetricTile(value: "12", label: "篮板", tint: Color.orange.opacity(0.12))
                    MetricTile(value: "7", label: "助攻", tint: PrototypeTokens.paleBlue)
                }
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最佳球员").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
                            Spacer()
                            Text("MVP").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.orange)
                        }
                        HStack(spacing: 12) {
                            AvatarBadge(number: data.homePlayer.number, color: PrototypeTokens.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(data.homePlayer.name).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                                Text("\(data.homeStats.points) 分 · \(data.homeStats.rebounds) 篮板 · \(data.homeStats.assists) 助攻").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
                            }
                        }
                    }
                }
                PrototypeSectionTitle(eyebrow: "PLAYER TABLE", title: "球员表现")
                PrototypeCard {
                    VStack(spacing: 0) {
                        PlayerRow(player: data.homePlayer, stats: data.homeStats, isHeader: true)
                        Divider().overlay(PrototypeTokens.line)
                        PlayerRow(player: data.awayPlayer, stats: data.awayStats, isHeader: false)
                        Divider().overlay(PrototypeTokens.line)
                        PlayerRow(player: data.players[2], stats: PrototypePlayerStats(twoMade: 1, twoAttempts: 2, threeMade: 0, threeAttempts: 0, rebounds: 3, assists: 0, fouls: 1, steals: 0, blocks: 1, turnovers: 0), isHeader: false)
                    }
                }
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI 复盘").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.orange)
                        Text(data.game.aiSummary).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.navy).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
}

struct PlayerProfilePrototypeView: View {
    let data: PrototypeMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "TEAM / 04", title: "把球队管理好", trailing: "球员档案")
                PrototypeCard {
                    HStack(spacing: 14) {
                        AvatarBadge(number: data.homePlayer.number, color: PrototypeTokens.blue)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(data.homePlayer.name).font(.system(size: 25, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                            Text("\(data.homePlayer.teamName) · \(data.homePlayer.position)").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
                            Text("NO. \(data.homePlayer.number)").font(.system(size: 11, weight: .black, design: .rounded)).tracking(1).foregroundStyle(PrototypeTokens.orange)
                        }
                        Spacer()
                    }
                }
                HStack(spacing: 8) {
                    ReviewTab(title: "基本信息", active: true)
                    ReviewTab(title: "赛季数据", active: false)
                    ReviewTab(title: "比赛记录", active: false)
                }
                PrototypeSectionTitle(eyebrow: "PLAYER CARD", title: "基本信息")
                PrototypeCard {
                    HStack(spacing: 0) {
                        InfoColumn(label: "身高", value: data.homePlayer.height)
                        InfoColumn(label: "体重", value: data.homePlayer.weight)
                        InfoColumn(label: "位置", value: data.homePlayer.position)
                    }
                }
                PrototypeSectionTitle(eyebrow: "SEASON", title: "本赛季表现")
                HStack(spacing: 10) {
                    MetricTile(value: "8.5", label: "场均得分", tint: PrototypeTokens.paleBlue)
                    MetricTile(value: "5.2", label: "场均篮板", tint: Color.orange.opacity(0.12))
                    MetricTile(value: "2.1", label: "场均助攻", tint: PrototypeTokens.paleBlue)
                }
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近比赛").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                            Spacer()
                            Text("查看全部").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.blue)
                        }
                        GameListRow(title: data.game.displayName, subtitle: data.game.modifiedDate, score: "9 — 5", result: "胜")
                        GameListRow(title: "湘北高中 vs 陵南高中", subtitle: "2026年9月17日", score: "12 — 10", result: "胜")
                    }
                }
                Button {} label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享球员档案")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(PrototypeTokens.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
}

struct CareerPrototypeView: View {
    let data: PrototypeMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "CAREER / 05", title: "从记录到成长", trailing: "生涯数据")
                PrototypeCard {
                    HStack(spacing: 14) {
                        AvatarBadge(number: data.homePlayer.number, color: PrototypeTokens.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.homePlayer.name).font(.system(size: 23, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                            Text("\(data.homePlayer.teamName) · 生涯档案").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
                        }
                        Spacer()
                    }
                }
                PrototypeSectionTitle(eyebrow: "CAREER TOTALS", title: "累计表现")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(value: "24", label: "出场", tint: PrototypeTokens.paleBlue)
                    MetricTile(value: "203", label: "得分", tint: Color.orange.opacity(0.12))
                    MetricTile(value: "126", label: "篮板", tint: PrototypeTokens.paleBlue)
                    MetricTile(value: "58", label: "助攻", tint: PrototypeTokens.paleBlue)
                    MetricTile(value: "19", label: "抢断", tint: Color.orange.opacity(0.12))
                    MetricTile(value: "11", label: "盖帽", tint: PrototypeTokens.paleBlue)
                }
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("场均数据").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                        HStack(spacing: 12) {
                            StatPill(value: "8.5", label: "得分")
                            StatPill(value: "5.2", label: "篮板")
                            StatPill(value: "2.4", label: "助攻")
                            StatPill(value: "48%", label: "命中")
                        }
                    }
                }
                PrototypeCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles").foregroundStyle(PrototypeTokens.orange).font(.system(size: 20, weight: .bold))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AI 成长摘要").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.orange)
                            Text("你的篮板稳定性持续提升。下一阶段可以专注于减少失误，并提高弱侧无球移动的参与度。").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                        }
                    }
                }
                HStack(spacing: 10) {
                    ActionTile(icon: "icloud.and.arrow.up", title: "同步数据")
                    ActionTile(icon: "arrow.down.doc", title: "导出报告")
                }
                PrototypeSectionTitle(eyebrow: "RECENT GAMES", title: "最近比赛")
                PrototypeCard {
                    VStack(spacing: 0) {
                        GameListRow(title: data.game.displayName, subtitle: data.game.modifiedDate, score: "9 — 5", result: "胜")
                        Divider().overlay(PrototypeTokens.line)
                        GameListRow(title: "湘北高中 vs 陵南高中", subtitle: "2026年9月17日", score: "12 — 10", result: "胜")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
}

struct RosterManagementPrototypeView: View {
    let data: PrototypeMockData

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(eyebrow: "SETTINGS / 04", title: "把球队管理好", trailing: "数据管理")
                PrototypeCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("我的数据").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                            Text("保留现有球员、球队和比赛结构").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "archivebox.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(PrototypeTokens.orange)
                    }
                }
                PrototypeSectionTitle(eyebrow: "COLLECTIONS", title: "快速访问")
                ManagementRow(icon: "person.3.fill", title: "球员", value: "\(data.players.count) 位", tint: PrototypeTokens.blue)
                ManagementRow(icon: "shield.fill", title: "球队", value: "\(data.teams.count) 支", tint: PrototypeTokens.orange)
                ManagementRow(icon: "rectangle.stack.fill", title: "比赛组", value: "0 组", tint: PrototypeTokens.blue)
                ManagementRow(icon: "person.2.fill", title: "球员组", value: "0 组", tint: PrototypeTokens.orange)
                PrototypeSectionTitle(eyebrow: "RECENT", title: "最近保存")
                PrototypeCard {
                    GameListRow(title: data.game.displayName, subtitle: data.game.modifiedDate, score: "9 — 5", result: "已保存")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
}

struct UnchangedScoringSurface: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle").font(.system(size: 42, weight: .bold)).foregroundStyle(PrototypeTokens.orange)
            Text("记分页保持不变").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
            Text("本原型不实现、不修改记分操作").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct ReviewTab: View {
    let title: String
    let active: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(active ? .white : PrototypeTokens.inkSoft)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(active ? PrototypeTokens.navy : Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? .clear : PrototypeTokens.line, lineWidth: 1))
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value).font(.system(size: 23, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AvatarBadge: View {
    let number: String
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.16))
            Text(number).font(.system(size: 25, weight: .black, design: .rounded)).foregroundStyle(color)
        }
        .frame(width: 68, height: 68)
    }
}

struct PlayerRow: View {
    let player: PrototypePlayer
    let stats: PrototypePlayerStats
    let isHeader: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(player.name).font(.system(size: 13, weight: isHeader ? .bold : .medium, design: .rounded)).foregroundStyle(PrototypeTokens.navy).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(stats.points)").font(.system(size: 13, weight: .bold, design: .rounded)).frame(width: 34)
            Text("\(stats.rebounds)").font(.system(size: 13, weight: .medium, design: .rounded)).frame(width: 34)
            Text("\(stats.assists)").font(.system(size: 13, weight: .medium, design: .rounded)).frame(width: 34)
        }
        .padding(.vertical, 11)
    }
}

struct InfoColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GameListRow: View {
    let title: String
    let subtitle: String
    let score: String
    let result: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                Text(subtitle).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(score).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
                Text(result).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.orange)
            }
        }
        .padding(.vertical, 9)
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActionTile: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(PrototypeTokens.blue)
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
            Spacer()
        }
        .padding(13)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PrototypeTokens.line, lineWidth: 1))
    }
}

struct ManagementRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(tint).frame(width: 36, height: 36).background(tint.opacity(0.13)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.navy)
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(PrototypeTokens.inkSoft)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(PrototypeTokens.inkSoft)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypeTokens.line, lineWidth: 1))
    }
}
