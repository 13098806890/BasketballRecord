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
    @State private var isShowingDelete = false

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingDelete = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }

                    Button {
                        isShowingImport = true
                    } label: {
                        Label("导入", systemImage: TransferSymbol.importData)
                    }
                }
            }
            .sheet(isPresented: $isShowingDelete) {
                DeleteSavedGamesView()
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

private struct DeleteSavedGamesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if orderedGames.isEmpty {
                    ContentUnavailableView("还没有历史比赛", systemImage: "clock.badge.questionmark")
                }

                ForEach(orderedGames) { game in
                    Button {
                        toggle(game.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(game.id) ? .red : .secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(game.homeTeamName) vs \(game.awayTeamName)")
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(scoreLine(for: game))
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                }

                                Text(Self.dateFormatter.string(from: game.savedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("删除比赛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("删除(\(selectedIDs.count))") {
                        isShowingDeleteConfirmation = true
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .alert("确认删除选中比赛？", isPresented: $isShowingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    store.deleteSavedGames(ids: selectedIDs)
                    selectedIDs.removeAll()
                    if store.savedGames.isEmpty {
                        dismiss()
                    }
                }
            } message: {
                Text("删除后无法恢复。")
            }
        }
    }

    private var orderedGames: [SavedGame] {
        store.savedGames.sorted { $0.savedAt > $1.savedAt }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        "\(score(for: game.snapshot.homeTeamID, in: game)) - \(score(for: game.snapshot.awayTeamID, in: game))"
    }

    private func score(for teamID: UUID?, in game: SavedGame) -> Int {
        let ids = teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
        return ids.reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
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

            Section {
                TeamStatsDisclosureView(
                    homeName: game.homeTeamName,
                    awayName: game.awayTeamName,
                    homeStats: aggregateStats(for: game.snapshot.homeTeamID),
                    awayStats: aggregateStats(for: game.snapshot.awayTeamID),
                    homeFouls: fouls(for: game.snapshot.homeTeamID),
                    awayFouls: fouls(for: game.snapshot.awayTeamID)
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            Section("\(game.homeTeamName) 球员数据") {
                ForEach(game.homePlayerIDs, id: \.self) { playerID in
                    playerStatRow(for: playerID)
                }
            }

            Section("\(game.awayTeamName) 球员数据") {
                ForEach(game.awayPlayerIDs, id: \.self) { playerID in
                    playerStatRow(for: playerID)
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
                    isShowingExport = true
                } label: {
                    Label("导出", systemImage: TransferSymbol.exportData)
                }
            }
        }
        .sheet(isPresented: $isShowingExport) {
            ExportGameView(game: game)
        }
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

    private func playerStatRow(for playerID: UUID) -> some View {
        let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]

        return NavigationLink {
            if store.player(for: playerID) != nil {
                PlayerProfileView(playerID: playerID, fixedGame: game)
            } else {
                PlayerGameDetailView(game: game, playerID: playerID)
            }
        } label: {
            HStack(spacing: 10) {
                playerAvatar(for: playerID)

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

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        playerIDs(for: teamID).reduce(PlayerStats()) { partial, playerID in
            var total = partial
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            total.twoMade += stats.twoMade
            total.twoAttempts += stats.twoAttempts
            total.threeMade += stats.threeMade
            total.threeAttempts += stats.threeAttempts
            total.bonusFreeThrowMade += stats.bonusFreeThrowMade
            total.bonusFreeThrowAttempts += stats.bonusFreeThrowAttempts
            total.freeThrowMade += stats.freeThrowMade
            total.freeThrowAttempts += stats.freeThrowAttempts
            total.rebounds += stats.rebounds
            total.assists += stats.assists
            total.fouls += stats.fouls
            return total
        }
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    @ViewBuilder
    private func playerAvatar(for playerID: UUID) -> some View {
        if let player = store.player(for: playerID) {
            PlayerAvatarView(player: player, size: 36)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String((game.playerNamesByID[playerID] ?? "?").prefix(2)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }
}

private struct ExportGameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var game: SavedGame

    @State private var base64 = ""
    @State private var isGenerating = true
    @State private var copyButtonTitle = "复制编码"

    var body: some View {
        NavigationStack {
            Form {
                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在生成 Base64 编码…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if base64.isEmpty {
                    Section {
                        Text("编码生成失败，请重试。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Base64 比赛记录") {
                        TextEditor(text: .constant(base64))
                            .font(.caption.monospaced())
                            .frame(minHeight: 220)
                    }

                    Section {
                        Button {
                            UIPasteboard.general.string = base64
                            showCopyFeedback()
                        } label: {
                            Label(copyButtonTitle, systemImage: copyButtonTitle == "复制编码" ? "doc.on.doc" : "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())

                        ShareLink(item: base64) {
                            Label("分享编码", systemImage: TransferSymbol.exportData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
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
            .task(id: game.id) {
                await generateBase64()
            }
        }
    }

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        await Task.yield()
        base64 = store.exportGameBase64(game) ?? ""
        isGenerating = false
    }

    private func showCopyFeedback() {
        copyButtonTitle = "已复制"
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copyButtonTitle = "复制编码"
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
    @State private var parseResultText: String?
    @State private var parseSucceeded = false
    @State private var isShowingMissingRosterAlert = false
    @State private var isParsing = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴 Base64") {
                    TextEditor(text: $base64)
                        .font(.caption.monospaced())
                        .frame(height: 112)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                    Button("解析比赛记录") {
                        isInputFocused = false
                        Task {
                            await decode()
                        }
                    }
                    .disabled(base64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)

                    if isParsing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("解析中…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parseResultText {
                    Section("解析结果") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(parseResultText)
                                .font(.footnote.monospaced())
                                .foregroundStyle(parseSucceeded ? Color.primary : Color.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    }
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
                            Label("导入比赛", systemImage: TransferSymbol.importData)
                        }
                    }
                }

            }
            .scrollDismissesKeyboard(.immediately)
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

    private func decode() async {
        isParsing = true
        package = nil
        parseSucceeded = false
        parseResultText = nil
        await Task.yield()
        defer { isParsing = false }

        guard let decoded = store.decodeGamePackage(from: base64) else {
            package = nil
            parseSucceeded = false
            parseResultText = "解析失败\n类型: 比赛\n请确认粘贴的是完整 Base64 比赛记录。"
            return
        }
        package = decoded
        playerMapping = [:]
        teamMapping = [:]
        for player in decoded.players {
            if store.players.contains(where: { $0.id == player.id }) {
                playerMapping[player.id] = player.id
            }
        }
        for team in decoded.teams {
            if store.teams.contains(where: { $0.id == team.id }) {
                teamMapping[team.id] = team.id
            }
        }
        parseSucceeded = true
        parseResultText = """
        解析成功
        类型: 比赛
        球队数量: \(decoded.teams.count)
        球员数量: \(decoded.players.count)
        未匹配项会按原 UUID 新建，照片不会导入。
        """
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
