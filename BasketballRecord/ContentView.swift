import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            GameView()
                .tabItem {
                    Label("记分", systemImage: "sportscourt")
                }

            HistoryView()
                .tabItem {
                    Label("比赛记录", systemImage: "clock.arrow.circlepath")
                }

            CareerView()
                .tabItem {
                    Label("生涯", systemImage: "trophy")
                }

            RosterView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}

private enum CareerBoardKind: String, CaseIterable, Identifiable {
    case team = "球队"
    case player = "球员"

    var id: String { rawValue }
}

struct CareerView: View {
    @State private var boardKind: CareerBoardKind = .team

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("生涯", selection: $boardKind) {
                    ForEach(CareerBoardKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if boardKind == .team {
                    TeamCareerBoardView()
                } else {
                    PlayerCareerBoardView()
                }
            }
            .navigationTitle("生涯")
        }
    }
}

private struct TeamCareerBoardView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if summaries.isEmpty {
                    ContentUnavailableView("还没有球队数据", systemImage: "person.3.sequence")
                        .padding(.top, 80)
                }

                ForEach(summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(summary.teamName)
                                .font(.headline)
                            Spacer()
                            Text("\(summary.wins)-\(summary.losses)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            teamTile("场次", "\(summary.games)")
                            teamTile("胜率", summary.winRateText)
                            teamTile("净胜", summary.diffText)
                        }

                        HStack(spacing: 8) {
                            teamTile("场均得分", summary.avgForText)
                            teamTile("场均失分", summary.avgAgainstText)
                            teamTile("总得失", "\(summary.pointsFor)-\(summary.pointsAgainst)")
                        }
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.99))
    }

    private var summaries: [TeamCareerSummary] {
        store.teams.map { team in
            var games = 0
            var wins = 0
            var losses = 0
            var pointsFor = 0
            var pointsAgainst = 0

            for game in store.savedGames {
                if game.snapshot.homeTeamID == team.id {
                    let home = score(for: .home, in: game)
                    let away = score(for: .away, in: game)
                    games += 1
                    pointsFor += home
                    pointsAgainst += away
                    if home > away { wins += 1 } else if home < away { losses += 1 }
                } else if game.snapshot.awayTeamID == team.id {
                    let home = score(for: .home, in: game)
                    let away = score(for: .away, in: game)
                    games += 1
                    pointsFor += away
                    pointsAgainst += home
                    if away > home { wins += 1 } else if away < home { losses += 1 }
                }
            }

            return TeamCareerSummary(
                id: team.id,
                teamName: team.name,
                games: games,
                wins: wins,
                losses: losses,
                pointsFor: pointsFor,
                pointsAgainst: pointsAgainst
            )
        }
        .sorted {
            if $0.games == 0 && $1.games > 0 { return false }
            if $1.games == 0 && $0.games > 0 { return true }
            if $0.winRate == $1.winRate { return $0.games > $1.games }
            return $0.winRate > $1.winRate
        }
    }

    private func score(for side: TeamSide, in game: SavedGame) -> Int {
        let ids = side == .home ? game.homePlayerIDs : game.awayPlayerIDs
        return ids.reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func teamTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(red: 0.95, green: 0.97, blue: 1.00), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PlayerCareerBoardView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            if summaries.isEmpty {
                ContentUnavailableView("还没有球员数据", systemImage: "person.crop.circle.badge.questionmark")
            }

            ForEach(summaries) { summary in
                NavigationLink {
                    PlayerProfileView(playerID: summary.id)
                } label: {
                    HStack(spacing: 10) {
                        if let player = store.player(for: summary.id) {
                            PlayerAvatarView(player: player, size: 40)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(summary.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(summary.totalPoints)分")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                            Text("比赛 \(summary.games) 场  场均 \(summary.avgPointsText)分 / \(summary.avgReboundsText)板 / \(summary.avgAssistsText)助  时间 \(summary.avgMinutesText)分")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var summaries: [PlayerCareerSummary] {
        store.players.map { player in
            var games = 0
            var total = PlayerStats()
            var totalSeconds: TimeInterval = 0

            for game in store.savedGames {
                guard game.didParticipate(player.id) else { continue }

                games += 1
                let stats = game.snapshot.statsByPlayerID[player.id, default: PlayerStats()]
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
                totalSeconds += game.snapshot.playingSecondsByPlayerID[player.id, default: 0]
            }

            return PlayerCareerSummary(
                id: player.id,
                name: player.name,
                games: games,
                totalPoints: total.points,
                totalRebounds: total.rebounds,
                totalAssists: total.assists,
                totalSeconds: totalSeconds
            )
        }
        .sorted {
            if $0.games == 0 && $1.games > 0 { return false }
            if $1.games == 0 && $0.games > 0 { return true }
            if $0.avgPoints == $1.avgPoints { return $0.totalPoints > $1.totalPoints }
            return $0.avgPoints > $1.avgPoints
        }
    }
}

private struct TeamCareerSummary: Identifiable {
    var id: UUID
    var teamName: String
    var games: Int
    var wins: Int
    var losses: Int
    var pointsFor: Int
    var pointsAgainst: Int

    var winRate: Double {
        guard games > 0 else { return 0 }
        return Double(wins) / Double(games)
    }

    var winRateText: String { "\(Int((winRate * 100).rounded()))%" }
    var diffText: String {
        let diff = pointsFor - pointsAgainst
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    var avgForText: String {
        guard games > 0 else { return "0.0" }
        return String(format: "%.1f", Double(pointsFor) / Double(games))
    }

    var avgAgainstText: String {
        guard games > 0 else { return "0.0" }
        return String(format: "%.1f", Double(pointsAgainst) / Double(games))
    }
}

private struct PlayerCareerSummary: Identifiable {
    var id: UUID
    var name: String
    var games: Int
    var totalPoints: Int
    var totalRebounds: Int
    var totalAssists: Int
    var totalSeconds: TimeInterval

    var avgPoints: Double { games > 0 ? Double(totalPoints) / Double(games) : 0 }
    var avgPointsText: String { String(format: "%.1f", avgPoints) }
    var avgReboundsText: String { String(format: "%.1f", games > 0 ? Double(totalRebounds) / Double(games) : 0) }
    var avgAssistsText: String { String(format: "%.1f", games > 0 ? Double(totalAssists) / Double(games) : 0) }
    var avgMinutesText: String { String(format: "%.1f", games > 0 ? totalSeconds / 60 / Double(games) : 0) }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var isShowingImport = false
    @State private var isShowingDelete = false
    @State private var displayedGames: [SavedGame] = []
    @State private var isLoadingGames = true
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isLoadingGames {
                    HStack(spacing: 10) {
                        Spacer()
                        ProgressView()
                        Text("正在加载比赛记录...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                } else if filteredGames.isEmpty {
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteGame(id: game.id)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Text(group.title)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("比赛记录")
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
            .onAppear {
                loadGamesAsync()
            }
            .onChange(of: store.savedGames) { _, _ in
                loadGamesAsync()
            }
        }
    }

    private var filteredGames: [SavedGame] {
        let games = displayedGames
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

    private func deleteGame(id: UUID) {
        store.deleteSavedGames(ids: Set([id]))
    }

    private func loadGamesAsync() {
        let currentGames = store.savedGames
        loadTask?.cancel()
        isLoadingGames = true

        loadTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            let sortedGames = currentGames.sorted { $0.savedAt > $1.savedAt }
            await MainActor.run {
                displayedGames = sortedGames
                isLoadingGames = false
            }
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
    @State private var isGeneratingAISummary = false
    @State private var aiSummary = ""
    @State private var aiSummaryError: String?

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
                    awayFouls: fouls(for: game.snapshot.awayTeamID),
                    style: .record
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
                    generateAISummary()
                } label: {
                    HStack(spacing: 8) {
                        if isGeneratingAISummary {
                            ProgressView()
                        }
                        Label(isGeneratingAISummary ? "生成中..." : "生成比赛总结", systemImage: "sparkles")
                    }
                }
                .disabled(isGeneratingAISummary || deepSeekAPIKey == nil)

                if let aiSummaryError {
                    Text(aiSummaryError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if aiSummary.isEmpty {
                    Text(deepSeekAPIKey == nil ? "等待 DeepSeek API Key 后启用。" : "将生成：比赛总结、MVP 评选与高亮时刻。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    aiSummaryStyledView
                }
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
        .onAppear {
            if aiSummary.isEmpty, let savedSummary = game.aiSummary, !savedSummary.isEmpty {
                let normalizedSummary = normalizeAISummary(savedSummary)
                aiSummary = normalizedSummary
                if normalizedSummary != savedSummary {
                    store.updateAISummary(normalizedSummary, for: game.id)
                }
            }
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
                        if let role = game.role(of: playerID) {
                            Text(role.title)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
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

    private var deepSeekAPIKey: String? {
        guard let key = DeepSeekKeychain.shared.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    private var aiSummaryStyledView: some View {
        let sections = aiSummarySections

        return Group {
            if sections.isEmpty {
                Text(stripMarkdownDecorations(from: normalizeAISummary(aiSummary)))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        let isMVP = isMVPSection(section.title)
                        let mvpID = isMVP ? mvpPlayerID(in: section.items.joined(separator: " ")) : nil

                        VStack(alignment: .leading, spacing: 12) {
                            if isMVP {
                                HStack(spacing: 8) {
                                    Image(systemName: "trophy.fill")
                                        .font(.headline)
                                        .foregroundStyle(Color.yellow)

                                    Text(stripMarkdownDecorations(from: section.title))
                                        .font(.headline)
                                        .foregroundStyle(aiSummaryAccentColor)

                                    Spacer(minLength: 0)

                                    if let mvpID {
                                        mvpPlayerAvatar(for: mvpID)
                                    }
                                }
                            } else {
                                Label(stripMarkdownDecorations(from: section.title), systemImage: iconForSummarySection(section.title))
                                    .font(.headline)
                                    .foregroundStyle(aiSummaryAccentColor)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                                    let cleanedItem = stripMarkdownDecorations(from: item)

                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: iconForSummaryItem(sectionTitle: section.title, item: item, index: index))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(aiSummaryAccentColor)
                                            .frame(width: 14, height: 14)
                                            .padding(.top, 2)

                                        Text(cleanedItem)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(aiSummaryAccentColor.opacity(0.14), lineWidth: 1)
                        )
                    }
                }
                .textSelection(.enabled)
            }
        }
    }

    private var aiSummarySections: [AISummarySection] {
        parseAISummarySections(from: normalizeAISummary(aiSummary))
    }

    private var aiSummaryAccentColor: Color {
        Color(red: 0.22, green: 0.52, blue: 0.90)
    }

    private func generateAISummary() {
        guard let apiKey = deepSeekAPIKey else {
            aiSummaryError = "请先在设置里配置并保存 DeepSeek API Key。"
            return
        }

        let prompt = summaryPrompt()
        isGeneratingAISummary = true
        aiSummaryError = nil

        Task {
            do {
                let summary = try await DeepSeekService.shared.generateSummary(prompt: prompt, apiKey: apiKey)
                let normalizedSummary = normalizeAISummary(summary)
                await MainActor.run {
                    aiSummary = normalizedSummary
                    store.updateAISummary(normalizedSummary, for: game.id)
                    isGeneratingAISummary = false
                }
            } catch {
                await MainActor.run {
                    aiSummaryError = (error as? LocalizedError)?.errorDescription ?? "生成失败，请稍后重试。"
                    isGeneratingAISummary = false
                }
            }
        }
    }

    private func summaryPrompt() -> String {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let highlightClues = highlightCluesText()

        let playerLines = allPlayerIDsForSummary().map { playerID in
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            let side = game.homePlayerIDs.contains(playerID) ? "主队" : "客队"
            let role = game.role(of: playerID)?.title ?? "未标记"
            let plusMinus = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
            let plusMinusText = plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
            let minutes = GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
            let name = game.playerNamesByID[playerID] ?? "未知球员"

            return "- [\(side)] \(name)（\(role)） 时间 \(minutes) 得分 \(stats.points) 篮板 \(stats.rebounds) 助攻 \(stats.assists) 犯规 \(stats.fouls) 投篮 \(stats.made)/\(stats.attempts) 三分 \(stats.threeMade)/\(stats.threeAttempts) 罚球 \(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts) 正负值 \(plusMinusText)"
        }

        let logs = game.snapshot.logs.suffix(24).map {
            "- \(GameView.timeFormatter.string(from: $0.timestamp)) \($0.message)"
        }

        let playersText = playerLines.isEmpty ? "- 无可用球员数据" : playerLines.joined(separator: "\n")
        let logText = logs.isEmpty ? "- 无事件日志" : logs.joined(separator: "\n")

        return """
        你将基于一场篮球比赛数据生成赛后复盘。请严格用中文输出，并且严格按照以下 Markdown 结构，不要添加其他一级标题：

        ### 比赛总结
        （2-4段，说明比赛走势、关键转折和双方表现）

        ### MVP
        （只评选1人，给出姓名、核心数据与理由）

        ### 高亮时刻
        1. （关键回合）
        2. （关键回合）
        3. （关键回合）

        额外要求：
        - 直接输出 Markdown 正文，不要使用 ```markdown 或 ``` 代码块包裹。
        - 不要输出字面量 \n 或 \\n，请使用真实换行。
        - 各级标题、段落、列表之间保留空行，保证排版清晰。
        - 高亮时刻优先从以下角度提炼：个人连续得分、球队连续得分、比分焦灼时的关键球、关键篮板、连续助攻、关键封盖。
        - 结合比赛事件日志来描述高亮时刻。
        - 不要虚构未给出的球员或事件。
        - 如果数据不足，请明确说明“基于现有记录”。
        - 本应用日志只可靠记录：2分命中/2分不中/3分命中/3分不中/罚球命中/罚球不中/助攻/篮板/犯规/换人/节次开始结束等。
        - 若日志没有明确“上篮/中投/抛投/扣篮”等出手类型，禁止写具体出手动作；统一写“2分命中”或“3分命中”。
        - 可以基于比分变化与连续事件做合理推测，但推测语气要用“可能/倾向于”，且不能把推测写成确定事实。
        - 最终输出不要出现“依据”“参考事件”“证据”等字样，也不要在每条高亮后附加引用括号。

        【比赛信息】
        日期：\(Self.aiPromptDateFormatter.string(from: game.savedAt))
        对阵：\(game.homeTeamName) vs \(game.awayTeamName)
        比分：\(game.homeTeamName) \(homeScore) - \(awayScore) \(game.awayTeamName)
        节数：\(game.snapshot.periodCount)
        事件数：\(game.snapshot.logs.count)

        【球员数据】
        \(playersText)

        【高光候选线索（系统基于日志提取）】
        \(highlightClues)

        【事件日志（最多24条，按时间）】
        \(logText)
        """
    }

    private func normalizeAISummary(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = stripOuterCodeFenceIfNeeded(text)

        if text.contains("\\n") {
            text = text.replacingOccurrences(of: "\\n", with: "\n")
        }
        if text.contains("\\t") {
            text = text.replacingOccurrences(of: "\\t", with: "\t")
        }

        var normalizedLines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("###") {
                if normalizedLines.last?.isEmpty == false {
                    normalizedLines.append("")
                }
                normalizedLines.append(trimmed)
                normalizedLines.append("")
                continue
            }

            if trimmed.hasPrefix("• ") {
                normalizedLines.append("- " + String(trimmed.dropFirst(2)))
                continue
            }

            normalizedLines.append(line)
        }

        let normalized = normalizedLines.joined(separator: "\n")
        return collapseExtraBlankLines(normalized)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripOuterCodeFenceIfNeeded(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") && trimmed.hasSuffix("```") else {
            return trimmed
        }

        var lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2 else { return trimmed }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collapseExtraBlankLines(_ text: String) -> String {
        let pattern = "\\n{3,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\n\n")
    }

    private func parseAISummarySections(from text: String) -> [AISummarySection] {
        guard !text.isEmpty else { return [] }

        var sections: [AISummarySection] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushCurrent() {
            let items = summaryItems(from: currentLines)
            guard !items.isEmpty else {
                currentLines.removeAll()
                return
            }
            sections.append(AISummarySection(title: currentTitle ?? "比赛总结", items: items))
            currentLines.removeAll()
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("###") {
                flushCurrent()
                currentTitle = line
                    .replacingOccurrences(of: "###", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentTitle = stripMarkdownDecorations(from: currentTitle ?? "")
                continue
            }

            if !line.isEmpty || !currentLines.isEmpty {
                currentLines.append(line)
            }
        }

        flushCurrent()

        if sections.isEmpty {
            let fallbackItems = summaryItems(from: text.components(separatedBy: "\n"))
            if !fallbackItems.isEmpty {
                sections = [AISummarySection(title: "比赛总结", items: fallbackItems)]
            }
        }

        return sections
    }

    private func summaryItems(from lines: [String]) -> [String] {
        var items: [String] = []
        var paragraph: [String] = []

        func flushParagraph() {
            let content = paragraph
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                items.append(stripMarkdownDecorations(from: content))
            }
            paragraph.removeAll()
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let bullet = summaryBulletText(from: line) {
                flushParagraph()
                items.append(stripMarkdownDecorations(from: bullet))
                continue
            }

            paragraph.append(line)
        }

        flushParagraph()
        return items
    }

    private func summaryBulletText(from line: String) -> String? {
        if line.hasPrefix("- ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if line.hasPrefix("• ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let range = line.range(of: #"^\d+[\.、]\s*"#, options: .regularExpression) {
            let content = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        }

        return nil
    }

    private func stripMarkdownDecorations(from text: String) -> String {
        var cleaned = text

        cleaned = replacing(#"(?m)^\s*#{1,6}\s*"#, in: cleaned, with: "")
        cleaned = replacing(#"(?m)^\s*>+\s*"#, in: cleaned, with: "")
        cleaned = replacing(#"!\[[^\]]*\]\([^\)]*\)"#, in: cleaned, with: "")
        cleaned = replacing(#"\[([^\]]+)\]\([^\)]*\)"#, in: cleaned, with: "$1")
        cleaned = replacing(#"`([^`]+)`"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\*\*([^*]+)\*\*"#, in: cleaned, with: "$1")
        cleaned = replacing(#"__([^_]+)__"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\*([^*]+)\*"#, in: cleaned, with: "$1")
        cleaned = replacing(#"_([^_]+)_"#, in: cleaned, with: "$1")
        cleaned = replacing(#"~~([^~]+)~~"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\"([^\"]+)\""#, in: cleaned, with: "$1")
        cleaned = replacing(#"[“”]"#, in: cleaned, with: "")
        cleaned = replacing(#"[‘’]"#, in: cleaned, with: "")
        cleaned = replacing(#"(?<![A-Za-z])'([^']+)'(?![A-Za-z])"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\\([\*_`~\[\]\(\)])"#, in: cleaned, with: "$1")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isMVPSection(_ title: String) -> Bool {
        title.localizedCaseInsensitiveContains("mvp")
    }

    private func mvpPlayerID(in text: String) -> UUID? {
        let normalized = stripMarkdownDecorations(from: text)
        let candidates = game.playerNamesByID
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }

        return candidates.first(where: { normalized.contains($0.name) })?.id
    }

    private func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private func iconForSummarySection(_ title: String) -> String {
        if title.localizedCaseInsensitiveContains("mvp") {
            return "trophy.fill"
        }
        if title.contains("高亮") {
            return "sparkles"
        }
        if title.contains("总结") {
            return "text.quote"
        }
        return "doc.text"
    }

    private func iconForSummaryItem(sectionTitle: String, item: String, index: Int) -> String {
        if sectionTitle.localizedCaseInsensitiveContains("mvp") {
            return "person.crop.circle.badge.checkmark"
        }
        if sectionTitle.contains("高亮") {
            return "bolt.fill"
        }
        if item.contains("关键") {
            return "flag.fill"
        }
        if item.contains("比分") {
            return "chart.line.uptrend.xyaxis"
        }
        return index == 0 ? "circle.fill" : "smallcircle.filled.circle"
    }

    private struct AISummarySection {
        var title: String
        var items: [String]
    }

    private func highlightCluesText() -> String {
        let clues = extractHighlightClues()
        if clues.isEmpty {
            return "- 未提取到明确高光线索，请仅基于日志谨慎总结。"
        }
        return clues.prefix(10).map { "- \($0)" }.joined(separator: "\n")
    }

    private func extractHighlightClues() -> [String] {
        let events = parsedHighlightEvents()
        guard !events.isEmpty else { return [] }

        var clues: [String] = []

        let scoringEvents = events.filter {
            if case .score = $0.kind { return true }
            return false
        }

        var index = 0
        while index < scoringEvents.count {
            let start = index
            guard let playerID = scoringEvents[index].playerID else {
                index += 1
                continue
            }

            var totalPoints = scoringEvents[index].points
            var hitCount = 1
            var end = index

            while end + 1 < scoringEvents.count,
                  scoringEvents[end + 1].playerID == playerID {
                end += 1
                hitCount += 1
                totalPoints += scoringEvents[end].points
            }

            if hitCount >= 2, totalPoints >= 4 {
                let startTime = GameView.timeFormatter.string(from: scoringEvents[start].entry.timestamp)
                let endTime = GameView.timeFormatter.string(from: scoringEvents[end].entry.timestamp)
                clues.append("个人连续得分：\(playerName(playerID)) 连得 \(totalPoints) 分（\(hitCount) 次命中，\(startTime)-\(endTime)）")
            }

            index = end + 1
        }

        index = 0
        while index < scoringEvents.count {
            let start = index
            guard let side = scoringEvents[index].side else {
                index += 1
                continue
            }

            var totalPoints = scoringEvents[index].points
            var hitCount = 1
            var end = index

            while end + 1 < scoringEvents.count,
                  scoringEvents[end + 1].side == side {
                end += 1
                hitCount += 1
                totalPoints += scoringEvents[end].points
            }

            if hitCount >= 3, totalPoints >= 6 {
                let startTime = GameView.timeFormatter.string(from: scoringEvents[start].entry.timestamp)
                let endTime = GameView.timeFormatter.string(from: scoringEvents[end].entry.timestamp)
                clues.append("球队连续得分：\(teamName(for: side)) 连得 \(totalPoints) 分（\(hitCount) 次命中，\(startTime)-\(endTime)）")
            }

            index = end + 1
        }

        for event in events {
            switch event.kind {
            case .score(let points):
                guard let side = event.side,
                      let homeAfter = event.homeScore,
                      let awayAfter = event.awayScore else { continue }

                var homeBefore = homeAfter
                var awayBefore = awayAfter
                if side == .home {
                    homeBefore -= points
                } else {
                    awayBefore -= points
                }

                let diffBefore = abs(homeBefore - awayBefore)
                let diffAfter = abs(homeAfter - awayAfter)
                if min(diffBefore, diffAfter) <= 3 {
                    clues.append("焦灼比分关键球：\(playerName(event.playerID)) 命中 \(points) 分")
                }

            case .rebound:
                if let home = event.homeScore,
                   let away = event.awayScore,
                   abs(home - away) <= 3 {
                    clues.append("焦灼比分关键篮板：\(playerName(event.playerID))")
                }

            case .block:
                if let home = event.homeScore,
                   let away = event.awayScore,
                   abs(home - away) <= 3 {
                    clues.append("焦灼比分关键封盖：\(playerName(event.playerID))")
                }

            case .assist, .other:
                continue
            }
        }

        let assistEvents = events.filter { $0.kind == .assist }
        index = 0
        while index < assistEvents.count {
            let start = index
            guard let playerID = assistEvents[index].playerID else {
                index += 1
                continue
            }

            var count = 1
            var end = index
            while end + 1 < assistEvents.count,
                  assistEvents[end + 1].playerID == playerID {
                end += 1
                count += 1
            }

            if count >= 2 {
                let startTime = GameView.timeFormatter.string(from: assistEvents[start].entry.timestamp)
                let endTime = GameView.timeFormatter.string(from: assistEvents[end].entry.timestamp)
                clues.append("连续助攻：\(playerName(playerID)) 连续 \(count) 次助攻（\(startTime)-\(endTime)）")
            }

            index = end + 1
        }

        var seen: Set<String> = []
        return clues.filter { seen.insert($0).inserted }
    }

    private func parsedHighlightEvents() -> [ParsedHighlightEvent] {
        game.snapshot.logs.map { entry in
            let (cleanMessage, homeScore, awayScore) = parseMessageAndScore(entry.message)
            let playerID = detectPlayerID(in: cleanMessage)
            let side = side(for: playerID)
            return ParsedHighlightEvent(
                entry: entry,
                cleanMessage: cleanMessage,
                homeScore: homeScore,
                awayScore: awayScore,
                playerID: playerID,
                side: side,
                kind: highlightKind(for: cleanMessage)
            )
        }
    }

    private func parseMessageAndScore(_ message: String) -> (String, Int?, Int?) {
        guard let leftParenthesis = message.lastIndex(of: "("),
              message.hasSuffix(")") else {
            return (message, nil, nil)
        }

        let cleanMessage = message[..<leftParenthesis].trimmingCharacters(in: .whitespacesAndNewlines)
        let scoreBody = message[message.index(after: leftParenthesis)..<message.index(before: message.endIndex)]
        let components = scoreBody.split(separator: ":")
        guard components.count == 2,
              let homeScore = Int(components[0]),
              let awayScore = Int(components[1]) else {
            return (String(cleanMessage), nil, nil)
        }
        return (String(cleanMessage), homeScore, awayScore)
    }

    private func detectPlayerID(in message: String) -> UUID? {
        for (playerID, name) in game.playerNamesByID.sorted(by: { $0.value.count > $1.value.count }) where !name.isEmpty {
            if message.contains(name) {
                return playerID
            }
        }
        return nil
    }

    private func side(for playerID: UUID?) -> TeamSide? {
        guard let playerID else { return nil }
        if game.homePlayerIDs.contains(playerID) { return .home }
        if game.awayPlayerIDs.contains(playerID) { return .away }
        return nil
    }

    private func playerName(_ playerID: UUID?) -> String {
        guard let playerID else { return "未知球员" }
        return game.playerNamesByID[playerID] ?? store.player(for: playerID)?.name ?? "未知球员"
    }

    private func teamName(for side: TeamSide) -> String {
        side == .home ? game.homeTeamName : game.awayTeamName
    }

    private func highlightKind(for message: String) -> HighlightKind {
        if message.contains("3分命中") { return .score(points: 3) }
        if message.contains("2分命中") { return .score(points: 2) }
        if message.contains("加罚命中") || message.contains("罚篮命中") { return .score(points: 1) }
        if message.contains("助攻") { return .assist }
        if message.contains("篮板") { return .rebound }
        if message.contains("封盖") { return .block }
        return .other
    }

    private struct ParsedHighlightEvent {
        let entry: GameLogEntry
        let cleanMessage: String
        let homeScore: Int?
        let awayScore: Int?
        let playerID: UUID?
        let side: TeamSide?
        let kind: HighlightKind

        var evidence: String {
            "\(GameView.timeFormatter.string(from: entry.timestamp)) \(cleanMessage)"
        }

        var points: Int {
            if case let .score(points) = kind {
                return points
            }
            return 0
        }
    }

    private enum HighlightKind: Equatable {
        case score(points: Int)
        case assist
        case rebound
        case block
        case other
    }

    private func allPlayerIDsForSummary() -> [UUID] {
        let allIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
        return allIDs.sorted { lhs, rhs in
            let lhsPoints = game.snapshot.statsByPlayerID[lhs, default: PlayerStats()].points
            let rhsPoints = game.snapshot.statsByPlayerID[rhs, default: PlayerStats()].points
            if lhsPoints != rhsPoints { return lhsPoints > rhsPoints }
            return (game.playerNamesByID[lhs] ?? "") < (game.playerNamesByID[rhs] ?? "")
        }
    }

    private static let aiPromptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

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

    @ViewBuilder
    private func mvpPlayerAvatar(for playerID: UUID) -> some View {
        if let player = store.player(for: playerID) {
            PlayerAvatarView(player: player, size: 24)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(String((game.playerNamesByID[playerID] ?? "?").prefix(2)))
                        .font(.caption2.weight(.semibold))
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
    @State private var copyFeedbackTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在生成压缩编码…")
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
                    Section("比赛分享编码") {
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
            .onDisappear {
                copyFeedbackTask?.cancel()
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
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
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
    @State private var isShowingClipboardAutoFillAlert = false
    @State private var hasCheckedClipboard = false
    @State private var isParsing = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴分享编码") {
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
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppNeutralProminentButtonStyle())
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
            .alert("已自动识别", isPresented: $isShowingClipboardAutoFillAlert) {
                Button("知道了") { }
            } message: {
                Text("已从剪贴板识别到比赛数据，并自动粘贴解析成功。")
            }
            .onAppear {
                guard !hasCheckedClipboard else { return }
                hasCheckedClipboard = true
                tryAutoFillFromClipboard()
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
            parseResultText = "解析失败\n类型: 比赛\n请确认粘贴的是完整分享编码。"
            return
        }
        applyDecodedPackage(decoded)
    }

    private func tryAutoFillFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty,
              let decoded = store.decodeGamePackage(from: clipboardText) else {
            return
        }

        base64 = clipboardText
        applyDecodedPackage(decoded)
        isShowingClipboardAutoFillAlert = true
    }

    private func applyDecodedPackage(_ decoded: ExportedGamePackage) {
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
                statLine("身份", roleText)
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

    private var roleText: String {
        game.role(of: playerID)?.title ?? "未记录"
    }
}
