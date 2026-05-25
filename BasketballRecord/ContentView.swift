import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            GameView()
                .tabItem {
                    Label("记分", systemImage: "sportscourt")
                }

            RosterView()
                .tabItem {
                    Label("配置", systemImage: "person.3.sequence")
                }

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var isShowingImport = false

    var body: some View {
        NavigationStack {
            List {
                if filteredGames.isEmpty {
                    ContentUnavailableView("还没有历史比赛", systemImage: "clock.badge.questionmark")
                }

                ForEach(monthGroups) { group in
                    DisclosureGroup {
                        ForEach(group.games) { game in
                            NavigationLink {
                                SavedGameDetailView(game: game)
                            } label: {
                                SavedGameRow(game: game)
                            }
                        }
                    } label: {
                        Text(group.title)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("比赛历史")
            .searchable(text: $searchText, prompt: "按球员搜索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingImport = true
                    } label: {
                        Label("导入", systemImage: "square.and.arrow.down.on.square")
                    }
                }
            }
            .sheet(isPresented: $isShowingImport) {
                ImportGameView()
            }
        }
    }

    private var filteredGames: [SavedGame] {
        let games = store.savedGames.sorted { $0.savedAt > $1.savedAt }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return games }
        return games.filter { game in
            game.playerNamesByID.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var monthGroups: [GameMonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredGames) { game in
            let components = calendar.dateComponents([.year, .month], from: game.savedAt)
            return GameMonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }
        return grouped.keys.sorted(by: >).map { key in
            GameMonthGroup(key: key, games: grouped[key, default: []].sorted { $0.savedAt > $1.savedAt })
        }
    }
}

private struct GameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: GameMonthKey, rhs: GameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

private struct GameMonthGroup: Identifiable {
    var key: GameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { "\(key.year)年 \(key.month)月" }
}

private struct SavedGameRow: View {
    var game: SavedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(scoreLine)
                    .font(.headline.monospacedDigit())
            }

            HStack {
                Text(Self.dateFormatter.string(from: game.savedAt))
                Spacer()
                Text("事件 \(game.snapshot.logs.count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        "\(game.homeTeamName) vs \(game.awayTeamName)"
    }

    private var scoreLine: String {
        "\(score(for: game.snapshot.homeTeamID)) - \(score(for: game.snapshot.awayTeamID))"
    }

    private func score(for teamID: UUID?) -> Int {
        playerIDs(for: teamID).reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct SavedGameDetailView: View {
    @EnvironmentObject private var store: AppStore
    var game: SavedGame
    @State private var exportText: String?
    @State private var isShowingExport = false

    var body: some View {
        List {
            Section {
                HStack {
                    teamSummary(.home)
                    Spacer()
                    Text("VS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    teamSummary(.away)
                }
            }

            Section("球员数据") {
                ForEach(allPlayerIDs, id: \.self) { playerID in
                    let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
                    NavigationLink {
                        PlayerGameDetailView(game: game, playerID: playerID)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(game.playerNamesByID[playerID] ?? "未知球员")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(stats.points)分")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                            Text("时间 \(GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0]))  投篮 \(stats.made)/\(stats.attempts)  罚球 \(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  板 \(stats.rebounds)  助 \(stats.assists)  犯 \(stats.fouls)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("AI 比赛总结") {
                Button {
                } label: {
                    Label("生成比赛总结", systemImage: "sparkles")
                }
                .disabled(true)
                Text("等待 DeepSeek API Key 后启用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("事件") {
                ForEach(game.snapshot.logs.reversed()) { entry in
                    Text("\(GameView.timeFormatter.string(from: entry.timestamp))  \(entry.message)")
                        .font(.footnote.monospacedDigit())
                }
            }
        }
        .navigationTitle("比赛详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportText = store.exportGameBase64(game)
                    isShowingExport = exportText != nil
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShowingExport) {
            ExportGameView(base64: exportText ?? "")
        }
    }

    private var allPlayerIDs: [UUID] {
        game.homePlayerIDs + game.awayPlayerIDs
    }

    private func teamSummary(_ side: TeamSide) -> some View {
        let teamID = side == .home ? game.snapshot.homeTeamID : game.snapshot.awayTeamID
        let teamName = side == .home ? game.homeTeamName : game.awayTeamName
        return VStack(spacing: 4) {
            Text(teamName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(score(for: teamID))")
                .font(.largeTitle.monospacedDigit().weight(.bold))
            Text("犯规 \(fouls(for: teamID))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
    }

    private func score(for teamID: UUID?) -> Int {
        playerIDs(for: teamID).reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func fouls(for teamID: UUID?) -> Int {
        playerIDs(for: teamID).reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].fouls
        }
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }
}

private struct ExportGameView: View {
    @Environment(\.dismiss) private var dismiss
    var base64: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Base64 比赛记录") {
                    TextEditor(text: .constant(base64))
                        .font(.caption.monospaced())
                        .frame(minHeight: 220)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = base64
                    } label: {
                        Label("复制编码", systemImage: "doc.on.doc")
                    }

                    ShareLink(item: base64) {
                        Label("分享编码", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("导出比赛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct ImportGameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var base64 = ""
    @State private var package: ExportedGamePackage?
    @State private var playerMapping: [UUID: UUID] = [:]
    @State private var teamMapping: [UUID: UUID] = [:]
    @State private var message: String?
    @State private var isShowingMissingRosterAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴 Base64") {
                    TextEditor(text: $base64)
                        .font(.caption.monospaced())
                        .frame(minHeight: 150)
                    Button("解析比赛记录") { decode() }
                }

                if let package {
                    Section("球队匹配") {
                        ForEach(package.teams) { team in
                            Picker(team.name, selection: binding(forTeam: team.id)) {
                                Text("作为新球队导入").tag(UUID?.none)
                                ForEach(store.teams) { localTeam in
                                    Text(localTeam.name).tag(Optional(localTeam.id))
                                }
                            }
                        }
                    }

                    Section("球员匹配") {
                        ForEach(package.players) { player in
                            Picker(player.name, selection: binding(forPlayer: player.id)) {
                                Text("作为新球员导入").tag(UUID?.none)
                                ForEach(store.players) { localPlayer in
                                    Text(localPlayer.name).tag(Optional(localPlayer.id))
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            store.importGamePackage(package, playerMapping: playerMapping, teamMapping: teamMapping)
                            dismiss()
                        } label: {
                            Label("导入比赛", systemImage: "checkmark.circle")
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("导入比赛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("发现新的球队或球员", isPresented: $isShowingMissingRosterAlert) {
                Button("继续匹配") { }
            } message: {
                Text("导入包里包含本机没有的球队或球员。未手动匹配的项目会按原 UUID 新建，照片不会导入。")
            }
        }
    }

    private func decode() {
        guard let decoded = store.decodeGamePackage(from: base64) else {
            package = nil
            message = "编码无法解析，请确认粘贴的是完整 Base64 比赛记录。"
            return
        }
        package = decoded
        playerMapping = [:]
        teamMapping = [:]
        for player in decoded.players {
            if store.players.contains(where: { $0.id == player.id }) {
                playerMapping[player.id] = player.id
            } else if let sameName = store.players.first(where: { $0.name == player.name }) {
                playerMapping[player.id] = sameName.id
            }
        }
        for team in decoded.teams {
            if store.teams.contains(where: { $0.id == team.id }) {
                teamMapping[team.id] = team.id
            } else if let sameName = store.teams.first(where: { $0.name == team.name }) {
                teamMapping[team.id] = sameName.id
            }
        }
        message = "已解析到 \(decoded.teams.count) 支球队、\(decoded.players.count) 名球员。没有匹配的项目会作为新资料导入，照片不会导入。"
        isShowingMissingRosterAlert = decoded.players.contains { playerMapping[$0.id] == nil } || decoded.teams.contains { teamMapping[$0.id] == nil }
    }

    private func binding(forPlayer id: UUID) -> Binding<UUID?> {
        Binding(
            get: { playerMapping[id] },
            set: { playerMapping[id] = $0 }
        )
    }

    private func binding(forTeam id: UUID) -> Binding<UUID?> {
        Binding(
            get: { teamMapping[id] },
            set: { teamMapping[id] = $0 }
        )
    }
}

private struct PlayerGameDetailView: View {
    var game: SavedGame
    var playerID: UUID

    private var stats: PlayerStats {
        game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(playerName)
                        .font(.headline)
                    Spacer()
                    Text("\(stats.points)分")
                        .font(.title2.monospacedDigit().weight(.bold))
                }
                statLine("上场时间", GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0]))
            }

            Section("投篮") {
                statLine("投篮", "\(stats.made)/\(stats.attempts)")
                statLine("命中率", percent(stats.fieldGoalRate))
                statLine("2分", "\(stats.twoMade)/\(stats.twoAttempts)")
                statLine("2分率", percent(stats.twoPointRate))
                statLine("3分", "\(stats.threeMade)/\(stats.threeAttempts)")
                statLine("3分率", percent(stats.threePointRate))
            }

            Section("罚篮") {
                statLine("罚篮", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)")
                statLine("命中率", percent(stats.freeThrowRate))
                statLine("加罚", "\(stats.bonusFreeThrowMade)/\(stats.bonusFreeThrowAttempts)")
            }

            Section("其他") {
                statLine("篮板 / 助攻 / 犯规", "\(stats.rebounds) / \(stats.assists) / \(stats.fouls)")
            }

            Section("高阶") {
                statLine("正负值", plusMinusText)
                statLine("eFG / TS", "\(percent(stats.effectiveFieldGoalRate)) / \(percent(stats.trueShootingRate))")
                statLine("每次出手得分", String(format: "%.2f", stats.pointsPerShot))
            }
        }
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var playerName: String {
        game.playerNamesByID[playerID] ?? "未知球员"
    }

    private func statLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var plusMinusText: String {
        let value = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
        return value > 0 ? "+\(value)" : "\(value)"
    }
}
