import SwiftUI
import WebKit

struct PlayerProfileView: View {
    @EnvironmentObject private var store: AppStore
    var playerID: UUID
    var fixedGame: SavedGame? = nil
    @Binding var selectedGroupID: UUID?
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var hasInitializedGameSelection = false
    @State private var selectedPeriod: Int? = nil
    @State private var fixedGameAnalysis = SavedGamePeriodAnalysis()
    @State private var showingELOHistory = false

    private var player: Player? { store.player(for: playerID) }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if fixedGame == nil {
                        NavigationLink {
                            PlayerGameSelectionView(games: allPlayerGames, selectedIDs: $selectedGameIDs)
                        } label: {
                            HStack {
                                Label(LocalizedStringKey("button_choose_games"), systemImage: "list.bullet.rectangle")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(selectionSummaryText)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                            .padding(.horizontal)

                        if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(group.name)
                                        .font(.headline)
                                }
                                Spacer()
                                Button(action: { selectedGroupID = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                        }

                    }

                    header

                    if let fixedGame, fixedGame.snapshot.periodCount > 1 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedStringKey("label_data_range"))
                                .font(.headline)
                            Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                                Text(LocalizedStringKey("label_full_game")).tag(Optional<Int>.none)
                                ForEach(1...fixedGame.snapshot.periodCount, id: \.self) { period in
                                    Text(localizedFormat("label_period_number_format", period)).tag(Optional(period))
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                    }


                    if fixedGame != nil {
                        statSection(localized("label_this_game_stats"), rows: buildGameStatRows())
                    } else {
                        statSection(localized("label_career_stats"), rows: buildCareerStatRows())
                        statSection(localized("label_average_stats"), rows: buildAverageStatRows())
                    }

                    if fixedGame != nil {
                        eventSection
                    }
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: UIColor { tc in
                tc.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1) : UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
            }))
        }
        .navigationTitle(player?.name ?? localized("label_player"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncSelectedGamesIfNeeded()
            rebuildFixedGameAnalysisIfNeeded()
        }
        .onChange(of: store.savedGames) { _, _ in
            syncSelectedGamesIfNeeded()
            rebuildFixedGameAnalysisIfNeeded()
        }
        .sheet(isPresented: $showingELOHistory) {
            ELOHistoryView(playerID: playerID, playerName: player?.name ?? "", games: filteredGames)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            if let player {
                PlayerAvatarView(player: player, size: 76)
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.name)
                        .font(.title2.weight(.bold))
                    Text(profileSubtitle(player))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let fg = fixedGame, let role = fg.role(of: playerID) {
                        Text(role.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    } else {
                        HStack(spacing: 6) {
                            Text(localizedFormat("count_games_format", filteredGames.count))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                            HStack(spacing: 4) {
                                Text(String(format: NSLocalizedString("elo_format", comment: "ELO value"), Int(playerELO)))
                                    .font(.caption.monospacedDigit().weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .onTapGesture { DispatchQueue.main.async { showingELOHistory = true } }
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: UIColor { tc in
                        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.30, blue: 0.22, alpha: 1) : UIColor(red: 0.82, green: 0.88, blue: 0.82, alpha: 1)
                    }),
                    Color(uiColor: UIColor { tc in
                        tc.userInterfaceStyle == .dark ? UIColor(red: 0.30, green: 0.24, blue: 0.18, alpha: 1) : UIColor(red: 0.90, green: 0.84, blue: 0.78, alpha: 1)
                    })
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal)
    }

    private var playerELO: Double {
        ELOEngine.computeELO(for: playerID, from: filteredGames)
    }

    private var eloHistory: [ELOGameEntry] {
        ELOEngine.computeELOHistory(for: playerID, from: filteredGames)
    }

    private struct StatCell: Identifiable {
        var id: String { label }
        var label: String
        var value: String
    }

    private struct StatRow: Identifiable {
        var id: String
        var left: StatCell
        var leftSplit: StatCell? = nil
        var right: StatCell? = nil
        var rightSplit: StatCell? = nil
    }

    private func makeStatCard(_ cell: StatCell) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(cell.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(cell.value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func statSection(_ title: String, rows: [StatRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if rows.isEmpty {
                Text(LocalizedStringKey("text_no_stats_in_group"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            if let split = row.leftSplit {
                                HStack(spacing: 8) {
                                    makeStatCard(row.left)
                                    makeStatCard(split)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                makeStatCard(row.left)
                                    .frame(maxWidth: .infinity)
                            }
                            if let split = row.rightSplit {
                                HStack(spacing: 8) {
                                    makeStatCard(split)
                                    if let right = row.right {
                                        makeStatCard(right)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            } else if let right = row.right {
                                makeStatCard(right)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private enum StatCardStyle {
        case game, career, average
    }

    private func buildStatRows(style: StatCardStyle) -> [StatRow] {
        let s = totalStats
        let games = max(1, filteredGames.count)
        let pct = { percent($0) }

        let mins: String
        let pm: String
        let avg: ((Int) -> String)?

        switch style {
        case .game:
            mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
            pm = isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")
            avg = nil
        case .career:
            mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
            pm = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
            avg = nil
        case .average:
            mins = String(format: "%.1f", totalMinutes / Double(games))
            pm = String(format: "%.1f", Double(totalPlusMinus) / Double(games))
            avg = { v in String(format: "%.1f", Double(v) / Double(games)) }
        }

        let pts = StatCell(label: localized("stats_points_format_short"), value: avg?(s.points) ?? "\(s.points)")
        let min = StatCell(label: localized("stats_minutes"), value: mins)
        let reb = StatCell(label: localized("stats_rebound_detail"), value: "\(avg?(s.totalRebounds) ?? "\(s.totalRebounds)") / \(avg?(s.offensiveRebounds) ?? "\(s.offensiveRebounds)") / \(avg?(s.defensiveRebounds) ?? "\(s.defensiveRebounds)")")
        let astStlBlk = StatCell(label: localized("stats_assist_steal_block"), value: "\(avg?(s.assists) ?? "\(s.assists)") / \(avg?(s.steals) ?? "\(s.steals)") / \(avg?(s.blocks) ?? "\(s.blocks)")")
        let foul = StatCell(label: localized("stats_foul_turnover") + " / " + localized("stats_plus_minus"), value: "\(avg?(s.fouls) ?? "\(s.fouls)") / \(avg?(s.turnovers) ?? "\(s.turnovers)") / \(pm)")
        let fg = StatCell(label: localized("stats_shooting"), value: "\(avg?(s.made) ?? "\(s.made)")/\(avg?(s.attempts) ?? "\(s.attempts)")\n\(pct(s.fieldGoalRate))")
        let ft = StatCell(label: localized("stat_label_free_throw"), value: "\(avg?(s.allFreeThrowMade) ?? "\(s.allFreeThrowMade)")/\(avg?(s.allFreeThrowAttempts) ?? "\(s.allFreeThrowAttempts)")\n\(pct(s.freeThrowRate))")
        let two = StatCell(label: localized("stat_label_2pt"), value: "\(avg?(s.twoMade) ?? "\(s.twoMade)")/\(avg?(s.twoAttempts) ?? "\(s.twoAttempts)")\n\(pct(s.twoPointRate))")
        let three = StatCell(label: localized("stat_label_3pt"), value: "\(avg?(s.threeMade) ?? "\(s.threeMade)")/\(avg?(s.threeAttempts) ?? "\(s.threeAttempts)")\n\(pct(s.threePointRate))")
        let efg = StatCell(label: "eFG / TS", value: "\(pct(s.effectiveFieldGoalRate)) / \(pct(s.trueShootingRate))")
        let pps = StatCell(label: NSLocalizedString("stats_points_per_shot", comment: "PTS/FGA"), value: String(format: "%.2f", s.pointsPerShot))

        switch style {
        case .game:
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, right: reb),
                StatRow(id: "row2", left: astStlBlk, leftSplit: foul),
                StatRow(id: "row3", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row4", left: pps, rightSplit: efg),
            ]
        case .career:
            let sb = StatCell(label: "\(localized("stats_games")) / \(localized("stat_label_starter")) / \(localized("stat_label_bench"))", value: "\(filteredGames.count) / \(starterGameCount) / \(benchGameCount)")
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, rightSplit: sb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: reb, right: astStlBlk),
                StatRow(id: "row4", left: foul, right: efg, rightSplit: pps),
            ]
        case .average:
            let sb = StatCell(label: "\(localized("stats_games")) / \(localized("stat_label_starter")) / \(localized("stat_label_bench"))", value: "\(filteredGames.count) / \(starterGameCount) / \(benchGameCount)")
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, rightSplit: sb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: reb, right: astStlBlk),
                StatRow(id: "row4", left: foul, right: pps, rightSplit: efg),
            ]
        }
    }

    private func buildGameStatRows() -> [StatRow] { buildStatRows(style: .game) }
    private func buildCareerStatRows() -> [StatRow] { buildStatRows(style: .career) }
    private func buildAverageStatRows() -> [StatRow] { buildStatRows(style: .average) }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("label_events"))
                .font(.headline)

            if filteredPlayerLogs.isEmpty {
                Text(LocalizedStringKey("text_no_player_events_for_range"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredPlayerLogs) { log in
                            Text(GameLogFormatter.lineText(for: log))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(GameLogFormatter.isScoring(log) ? Color.blue : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(.horizontal)
    }

    private var allPlayerGames: [SavedGame] {
        let games = store.savedGames
            .filter { containsPlayer(in: $0) }
            .sorted { $0.savedAt > $1.savedAt }

        if store.isPro, let selectedGroupID = selectedGroupID {
            return games.filter { $0.groupIDs.contains(selectedGroupID) }
        }
        return games
    }

    private var selectionSummaryText: String {
        "\(selectedGameIDs.count)/\(allPlayerGames.count)"
    }

    private var filteredGames: [SavedGame] {
        if let fixedGame {
            let participates = containsPlayer(in: fixedGame)
            return participates ? [fixedGame] : []
        }

        return allPlayerGames.filter { game in
            selectedGameIDs.contains(game.id)
        }
    }

    private var isFixedPeriodMode: Bool {
        fixedGame != nil && selectedPeriod != nil
    }

    private var filteredPlayerLogs: [PeriodAwareLog] {
        guard fixedGame != nil else { return [] }
        return fixedGameAnalysis.playerLogs(for: playerID, period: selectedPeriod).reversed()
    }

    private struct PlayerStatsGroup {
        let totalStats: PlayerStats
        let totalMinutes: Double
        let totalPlusMinus: Int
        let starterGameCount: Int
        let benchGameCount: Int
    }

    private var statsGroup: PlayerStatsGroup {
        computeStatsGroup(for: filteredGames)
    }

    private func computeStatsGroup(for games: [SavedGame]) -> PlayerStatsGroup {
        if let selectedPeriod, fixedGame != nil {
            let stats = fixedGameAnalysis.statsByPlayerID(for: selectedPeriod)[playerID, default: PlayerStats()]
            return PlayerStatsGroup(totalStats: stats, totalMinutes: 0, totalPlusMinus: 0, starterGameCount: 0, benchGameCount: 0)
        }

        var total = PlayerStats()
        var minutes: Double = 0
        var plusMinus: Int = 0
        var starter = 0
        var bench = 0

        for game in games {
            let raw = game.snapshot.statsByPlayerID[playerID] ?? PlayerStats()
            total.twoMade += raw.twoMade
            total.twoAttempts += raw.twoAttempts
            total.threeMade += raw.threeMade
            total.threeAttempts += raw.threeAttempts
            total.bonusFreeThrowMade += raw.bonusFreeThrowMade
            total.bonusFreeThrowAttempts += raw.bonusFreeThrowAttempts
            total.freeThrowMade += raw.freeThrowMade
            total.freeThrowAttempts += raw.freeThrowAttempts
            total.rebounds += raw.rebounds
            total.offensiveRebounds += raw.offensiveRebounds
            total.defensiveRebounds += raw.defensiveRebounds
            total.assists += raw.assists
            total.fouls += raw.fouls
            total.blocks += raw.blocks
            total.steals += raw.steals
            total.turnovers += raw.turnovers
            minutes += game.snapshot.playingSecondsByPlayerID[playerID, default: 0] / 60
            plusMinus += game.snapshot.plusMinusByPlayerID[playerID, default: 0]
            let role = game.role(of: playerID)
            if role == .starter { starter += 1 }
            else if role == .bench { bench += 1 }
        }

        return PlayerStatsGroup(totalStats: total, totalMinutes: minutes, totalPlusMinus: plusMinus, starterGameCount: starter, benchGameCount: bench)
    }

    private var totalStats: PlayerStats { statsGroup.totalStats }
    private var totalMinutes: Double { isFixedPeriodMode ? 0 : statsGroup.totalMinutes }
    private var totalPlusMinus: Int { isFixedPeriodMode ? 0 : statsGroup.totalPlusMinus }
    private var starterGameCount: Int { statsGroup.starterGameCount }
    private var benchGameCount: Int { statsGroup.benchGameCount }

    private var totalValues: [(String, String)] {
        let stats = totalStats
        let rebLine = "\(stats.totalRebounds) / \(stats.offensiveRebounds) / \(stats.defensiveRebounds)"
        let astStlBlkLine = "\(stats.assists) / \(stats.steals) / \(stats.blocks)"
        let fouls = "\(stats.fouls) / \(stats.turnovers)"
        let mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
        let items: [(String, String)] = [
            (localized("stats_pts_min"), "\(stats.points) / \(mins)"),
            (localized("stats_rebound_detail"), rebLine),
            (localized("stats_assist_steal_block"), astStlBlkLine),
            (localized("stats_foul_turnover"), fouls),
            (localized("stats_starter_bench"), "\(starterGameCount) / \(benchGameCount)"),
            (localized("stats_plus_minus"), isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")),
            (localized("stats_shooting"), "\(stats.made)/\(stats.attempts)  \(percent(stats.fieldGoalRate))"),
            (localized("stat_label_2pt"), "\(stats.twoMade)/\(stats.twoAttempts)  \(percent(stats.twoPointRate))"),
            (localized("stat_label_3pt"), "\(stats.threeMade)/\(stats.threeAttempts)  \(percent(stats.threePointRate))"),
            (localized("stat_label_free_throw"), "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  \(percent(stats.freeThrowRate))"),
            ("eFG / TS", "\(percent(stats.effectiveFieldGoalRate)) / \(percent(stats.trueShootingRate))"),
        ]
        return items
    }

    private var careerSummaryValues: [(String, String)] {
        let stats = totalStats
        let games = filteredGames.count
        let mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
        let pmText = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
        return [
            ("\(localized("label_games_count"))", "\(games) (\(localized("stat_label_starter")) \(starterGameCount)/\(localized("stat_label_bench")) \(benchGameCount))"),
            ("\(localized("stats_pts_min"))", "\(stats.points) / \(mins)"),
            ("\(localized("stats_field_goal"))", "\(stats.made)/\(stats.attempts)  \(percent(stats.fieldGoalRate))"),
            ("\(localized("stat_label_2pt"))", "\(stats.twoMade)/\(stats.twoAttempts)  \(percent(stats.twoPointRate))"),
            ("\(localized("stat_label_3pt"))", "\(stats.threeMade)/\(stats.threeAttempts)  \(percent(stats.threePointRate))"),
            ("\(localized("stat_label_free_throw"))", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  \(percent(stats.freeThrowRate))"),
            ("\(localized("stats_plus_minus"))", pmText),
            ("\(localized("stats_rebound_detail"))", "\(stats.totalRebounds) / \(stats.offensiveRebounds) / \(stats.defensiveRebounds)"),
            ("\(localized("stats_assist_steal_block"))", "\(stats.assists) / \(stats.steals) / \(stats.blocks)"),
            ("\(localized("stats_foul_turnover"))", "\(stats.fouls) / \(stats.turnovers)"),
        ]
    }

    private var averageValues: [(String, String)] {
        let games = max(1, filteredGames.count)
        let stats = totalStats
        let items: [(CareerStatItem, String)] = [
            (.averagePoints, average(stats.points, games)),
            (.averageRebounds, average(stats.totalRebounds, games)),
            (.averageAssists, average(stats.assists, games)),
            (.averageFouls, average(stats.fouls, games)),
            (.averageBlocks, average(stats.blocks, games)),
            (.averageSteals, average(stats.steals, games)),
            (.averageTurnovers, average(stats.turnovers, games)),
            (.averageMinutes, String(format: "%.1f", totalMinutes / Double(games))),
            (.averagePlusMinus, String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
            (.averageTwoMade, average(stats.twoMade, games)),
            (.averageThreeMade, average(stats.threeMade, games)),
            (.averageFreeThrowMade, average(stats.allFreeThrowMade, games)),
            (.averageThreePointRate, percent(stats.threePointRate)),
            (.averageFreeThrowRate, percent(stats.freeThrowRate))
        ]
        return items.compactMap { item, value in
            store.isCareerStatVisible(item) ? (item.title, value) : nil
        }
    }

    private var averageCardValues: [(String, String)] {
        let stats = totalStats
        let games = max(1, filteredGames.count)
        let avg = { (val: Int) -> String in String(format: "%.1f", Double(val) / Double(games)) }
        let rebLine = "\(avg(stats.totalRebounds)) / \(avg(stats.offensiveRebounds)) / \(avg(stats.defensiveRebounds))"
        let astStlBlkLine = "\(avg(stats.assists)) / \(avg(stats.steals)) / \(avg(stats.blocks))"
        let fouls = "\(avg(stats.fouls)) / \(avg(stats.turnovers))"
        let avgMin = String(format: "%.1f", totalMinutes / Double(games))
        return [
            (localized("stats_pts_min"), "\(avg(stats.points)) / \(avgMin)"),
            (localized("stats_rebound_detail"), rebLine),
            (localized("stats_assist_steal_block"), astStlBlkLine),
            (localized("stats_foul_turnover"), fouls),
            (localized("stats_shooting"), "\(avg(stats.made))/\(avg(stats.attempts))  \(percent(stats.fieldGoalRate))"),
            (localized("stat_label_2pt"), "\(avg(stats.twoMade))/\(avg(stats.twoAttempts))  \(percent(stats.twoPointRate))"),
            (localized("stat_label_3pt"), "\(avg(stats.threeMade))/\(avg(stats.threeAttempts))  \(percent(stats.threePointRate))"),
            (localized("stat_label_free_throw"), "\(avg(stats.allFreeThrowMade))/\(avg(stats.allFreeThrowAttempts))  \(percent(stats.freeThrowRate))"),
            (localized("stats_plus_minus"), String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
        ]
    }

    private var advancedValues: [(String, String)] {
        let stats = totalStats
        let efg = percent(stats.effectiveFieldGoalRate)
        let ts = percent(stats.trueShootingRate)
        return [
            ("eFG / TS", "\(efg) / \(ts)"),
            (NSLocalizedString("stats_points_per_shot", comment: "PTS/FGA"), String(format: "%.2f", stats.pointsPerShot))
        ]
    }

    private func madeAttemptRate(made: Int, attempts: Int, rate: Double) -> String {
        "\(made)/\(attempts)  \(percent(rate))"
    }

    private func average(_ value: Int, _ games: Int) -> String {
        String(format: "%.1f", Double(value) / Double(games))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func profileSubtitle(_ player: Player) -> String {
        var parts: [String] = []
        if !player.number.isEmpty { parts.append("No. \(player.number)") }
        if !player.height.isEmpty { parts.append(UnitSettings.displayHeight(player.height)) }
        if !player.weight.isEmpty { parts.append(UnitSettings.displayWeight(player.weight)) }
        return parts.isEmpty ? localized("player_profile_missing_basic") : parts.joined(separator: " · ")
    }

    private func containsPlayer(in game: SavedGame) -> Bool {
        game.didParticipate(playerID)
    }

    private func syncSelectedGamesIfNeeded() {
        guard fixedGame == nil else { return }
        let availableIDs = Set(allPlayerGames.map(\.id))

        if !hasInitializedGameSelection {
            selectedGameIDs = availableIDs
            hasInitializedGameSelection = true
            return
        }

        selectedGameIDs = selectedGameIDs.intersection(availableIDs)
    }

    private func rebuildFixedGameAnalysisIfNeeded() {
        guard let fixedGame else {
            fixedGameAnalysis = SavedGamePeriodAnalysis()
            selectedPeriod = nil
            return
        }

        let analyzer = SavedGameAnalyzer(game: fixedGame) { name in
            if let localID = fixedGame.playerNamesByID.first(where: { $0.value == name })?.key {
                return localID
            }
            return store.players.first(where: { $0.name == name })?.id
        }
        fixedGameAnalysis = analyzer.analyze()
    }
}

private struct PlayerGameSelectionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var games: [SavedGame]
    @Binding var selectedIDs: Set<UUID>
    @State private var selectedGroupID: UUID? = nil

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(LocalizedStringKey("text_no_selectable_games"), systemImage: "clock.badge.questionmark")
            }

            if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: { selectedGroupID = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            ForEach(monthGroups) { group in
                DisclosureGroup {
                    HStack {
                        Button(allSelected(in: group.games) ? localized("button_clear_month") : localized("button_select_month")) {
                            toggleMonthSelection(for: group.games)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()
                        Text("\(selectedCount(in: group.games))/\(group.games.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    ForEach(group.games) { game in
                        Button {
                            toggle(game.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(game.id) ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 5) {
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
                } label: {
                    HStack {
                        Text(group.title)
                            .font(.headline)
                        Spacer()
                        Text("\(selectedCount(in: group.games))/\(group.games.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("button_choose_games"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isPro {
                ToolbarItem(placement: .topBarLeading) {
                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizedStringKey("button_clear_all")) {
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("button_select_all")) {
                    selectedIDs = Set(games.map(\.id))
                }
                .disabled(games.isEmpty || selectedIDs.count == games.count)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(LocalizedStringKey("button_done")) { dismiss() }
            }
        }
    }

    private var monthGroups: [PlayerGameMonthGroup] {
        let calendar = Calendar.current
        
        // Filter games by selected group if any (Pro only)
        let filteredGames = (store.isPro ? selectedGroupID.map { groupID in
            games.filter { $0.groupIDs.contains(groupID) }
        } : nil) ?? games
        
        let grouped = Dictionary(grouping: filteredGames) { game in
            let components = calendar.dateComponents([.year, .month], from: game.savedAt)
            return PlayerGameMonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }

        return grouped.keys.sorted(by: >).map { key in
            PlayerGameMonthGroup(key: key, games: grouped[key, default: []].sorted { $0.savedAt > $1.savedAt })
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleMonthSelection(for games: [SavedGame]) {
        if allSelected(in: games) {
            games.forEach { selectedIDs.remove($0.id) }
        } else {
            games.forEach { selectedIDs.insert($0.id) }
        }
    }

    private func allSelected(in games: [SavedGame]) -> Bool {
        !games.isEmpty && games.allSatisfy { selectedIDs.contains($0.id) }
    }

    private func selectedCount(in games: [SavedGame]) -> Int {
        games.reduce(0) { count, game in
            count + (selectedIDs.contains(game.id) ? 1 : 0)
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

private struct PlayerGameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: PlayerGameMonthKey, rhs: PlayerGameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

private struct PlayerGameMonthGroup: Identifiable {
    var key: PlayerGameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { localizedFormat("month_title_format", key.year, key.month) }
}


struct CollaborativeGameListView: View {
    @EnvironmentObject private var store: AppStore

    private var games: [SavedGame] {
        store.savedGames.filter { $0.snapshot.wasBluetoothCollaborated }
            .sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_bluetooth_games"), systemImage: "dot.radiowaves.left.and.right")
            }
            ForEach(games) { game in
                NavigationLink {
                    SavedGameDetailView(game: game)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(game.homeTeamName) vs \(game.awayTeamName)")
                            .font(.headline)
                        Text(Self.dateFormatter.string(from: game.savedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_bluetooth_games"))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

struct CloudStorageView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var isSyncing = false
    @State private var expandedCloudSections: Set<String> = []
    @State private var expandedLocalSections: Set<String> = []
    @State private var cloudOnlyGames: [SavedGame] = []

    private var cloudGames: [SavedGame] {
        store.savedGames.filter { store.cloudEnabledGameIDs.contains($0.id) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var localOnlyGames: [SavedGame] {
        store.savedGames.filter { !store.cloudEnabledGameIDs.contains($0.id) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var allGroups: [GameGroup] { store.gameGroups }

    var body: some View {
        List {
            Section {
                Text(LocalizedStringKey("cloud_storage_description"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    sync()
                } label: {
                    HStack {
                        if isSyncing || cloudKit.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(LocalizedStringKey(isSyncing ? "cloud_syncing" : "cloud_sync_now"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSyncing || cloudKit.isSyncing)

                if let error = cloudKit.lastSyncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            let cloudSubs = buildGroupedSections(games: cloudGames)
            if !cloudSubs.isEmpty {
                Section(LocalizedStringKey("section_cloud_enabled")) {
                    ForEach(cloudSubs, id: \.name) { sub in
                        DisclosureGroup(sub.name, isExpanded: Binding(
                            get: { expandedCloudSections.contains(sub.name) },
                            set: { if $0 { expandedCloudSections.insert(sub.name) } else { expandedCloudSections.remove(sub.name) } }
                        )) {
                            ForEach(sub.games) { game in
                                gameRow(game: game, isCloud: true)
                            }
                        }
                    }
                }
            }

            let localSubs = buildGroupedSections(games: localOnlyGames)
            if !localSubs.isEmpty {
                Section(LocalizedStringKey("section_local_only")) {
                    ForEach(localSubs, id: \.name) { sub in
                        DisclosureGroup(sub.name, isExpanded: Binding(
                            get: { expandedLocalSections.contains(sub.name) },
                            set: { if $0 { expandedLocalSections.insert(sub.name) } else { expandedLocalSections.remove(sub.name) } }
                        )) {
                            ForEach(sub.games) { game in
                                gameRow(game: game, isCloud: false)
                            }
                        }
                    }
                }
            }

            if let error = cloudKit.lastSyncError, cloudOnlyGames.isEmpty {
                Section(LocalizedStringKey("section_cloud_only")) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(LocalizedStringKey("cloud_unavailable_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !cloudOnlyGames.isEmpty {
                Section(LocalizedStringKey("section_cloud_only")) {
                    ForEach(cloudOnlyGames) { game in
                        HStack {
                            gameRow(game: game, isCloud: true)
                            Button {
                                store.downloadFromCloud(game)
                                refreshCloudOnly()
                            } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_cloud_storage"))
        .onAppear { refreshCloudOnly() }
        .onChange(of: store.savedGames.count) { _, _ in refreshCloudOnly() }
    }

    private func refreshCloudOnly() {
        Task {
            let allCloud = await CloudKitManager.shared.fetchGames(ids: store.cloudEnabledGameIDs)
            let localIDs = Set(store.savedGames.map(\.id))
            cloudOnlyGames = allCloud.filter { !localIDs.contains($0.id) }
        }
    }

    private struct GameSubSection {
        var name: String
        var games: [SavedGame]
    }

    private func buildGroupedSections(games: [SavedGame]) -> [GameSubSection] {
        var remaining = Set(games.map(\.id))
        var subs: [GameSubSection] = []

        for group in allGroups {
            let groupGames = games.filter { $0.groupIDs.contains(group.id) }
            if !groupGames.isEmpty {
                subs.append(GameSubSection(name: group.name, games: groupGames))
                for g in groupGames { remaining.remove(g.id) }
            }
        }

        let ungrouped = games.filter { remaining.contains($0.id) }
        if !ungrouped.isEmpty {
            subs.append(GameSubSection(name: NSLocalizedString("game_group_ungrouped", comment: "Ungrouped"), games: ungrouped))
        }

        return subs
    }

    private func gameRow(game: SavedGame, isCloud: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayTitle)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: game.savedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(scoreLine(for: game))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: isCloud ? "icloud.fill" : "icloud.slash")
                .foregroundStyle(isCloud ? .blue : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.toggleCloudStorage(for: game.id)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        let homeScore = game.homePlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
        let awayScore = game.awayPlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
        return "\(homeScore) - \(awayScore)"
    }

    private func sync() {
        isSyncing = true
        Task {
            await store.syncCloudGames()
            refreshCloudOnly()
            isSyncing = false
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

private struct ELOHistoryView: View {
    let playerID: UUID
    let playerName: String
    let games: [SavedGame]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetail: ELOComputationDetail?

    private var history: [ELOGameEntry] {
        ELOEngine.computeELOHistory(for: playerID, from: games)
    }

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("text_no_data"),
                        systemImage: "chart.line.downtrend.xyaxis"
                    )
                } else {
                    ForEach(history) { entry in
                        ELOGameRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedDetail = entry.detail }
                    }
                }
            }
            .navigationTitle(String(format: NSLocalizedString("elo_title_format", comment: "ELO title"), playerName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .sheet(item: $selectedDetail) { detail in
                ELOComputationView(detail: detail)
            }
        }
    }
}

private struct ELOGameRow: View {
    let entry: ELOGameEntry

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.game.homeTeamName) vs \(entry.game.awayTeamName)")
                        .font(.subheadline.weight(.semibold))
                    Text(dateFormatter.string(from: entry.game.savedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: entry.won ? "trophy.fill" : "hand.thumbsdown.fill")
                    .foregroundStyle(entry.won ? .yellow : .secondary)
            }

            HStack(spacing: 8) {
                Text("\(Int(entry.preELO))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("\(Int(entry.postELO))")
                    .font(.headline.monospacedDigit().weight(.bold))
                Text(entry.delta >= 0 ? "+\(String(format: "%.1f", entry.delta))" : "\(String(format: "%.1f", entry.delta))")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(entry.delta >= 0 ? .green : .red)
            }

            HStack {
                Text("GS: \(String(format: "%.1f", entry.gameScore))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ELOComputationView: View {
    let detail: ELOComputationDetail

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(NSLocalizedString("elo_section_result", comment: "Game Result")) {
                    row("elo_label_score", "\(detail.myScore) – \(detail.opponentScore)")
                    row("elo_label_outcome", detail.won
                        ? NSLocalizedString("elo_outcome_win", comment: "Win")
                        : (detail.isDraw
                            ? NSLocalizedString("elo_outcome_draw", comment: "Draw")
                            : NSLocalizedString("elo_outcome_loss", comment: "Loss")))
                }

                Section(NSLocalizedString("elo_section_elo", comment: "ELO Parameters")) {
                    row("elo_label_pre_elo", "\(Int(detail.preELO))")
                    row("elo_label_avg_opponent_elo", String(format: "%.1f", detail.avgOpponentELO))
                    row("elo_label_expected", String(format: "%.4f", detail.expected))
                    row("elo_label_actual", String(format: "%.1f", detail.actual))
                }

                Section(NSLocalizedString("elo_section_gs", comment: "Game Score Adjustment")) {
                    Text("GS = PTS + 0.4\u{00d7}FGM \u{2212} 0.7\u{00d7}FGA \u{2212} 0.4\u{00d7}(FTA\u{2212}FTM) + 0.5\u{00d7}REB + STL + 0.7\u{00d7}AST + 0.7\u{00d7}BLK \u{2212} 0.4\u{00d7}PF \u{2212} TOV")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    row("elo_label_player_gs", String(format: "%.1f", detail.playerGS))
                    row("elo_label_avg_gs", String(format: "%.1f", detail.avgGS))
                    Text("Relative = \(String(format: "%.1f", detail.playerGS)) - \(String(format: "%.1f", detail.avgGS)) = \(String(format: "%.1f", detail.relativeGS))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("perf = tanh(\(String(format: "%.1f", detail.relativeGS)) / 15) = \(String(format: "%.3f", detail.perf))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(detail.won
                         ? "GS_Factor = 1 + \(String(format: "%.3f", detail.perf)) \u{00d7} 0.5 = \(String(format: "%.3f", detail.gsFactorRaw))"
                         : "GS_Factor = 1 - \(String(format: "%.3f", detail.perf)) \u{00d7} 0.5 = \(String(format: "%.3f", detail.gsFactorRaw))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if detail.gsFactorClamped != detail.gsFactorRaw {
                        Text("clamped to [0.3, 2.0] \u{2192} \(String(format: "%.3f", detail.gsFactorClamped))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    row("elo_label_gs_factor", String(format: "%.3f", detail.gsFactorClamped))
                }

                Section(NSLocalizedString("elo_section_formula", comment: "Formula")) {
                    Text("ELO = K \u{00d7} (Actual - Expected) \u{00d7} GS_Factor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\u{0394} = \(String(format: "%.0f", detail.K)) \u{00d7} (\(String(format: "%.4f", detail.actual)) - \(String(format: "%.4f", detail.expected))) \u{00d7} \(String(format: "%.3f", detail.gsFactorClamped))")
                        .font(.caption.monospacedDigit())
                    Text("= \(String(format: "%.1f", detail.K * (detail.actual - detail.expected) * detail.gsFactorClamped))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
            .navigationTitle(NSLocalizedString("elo_computation_title", comment: "ELO Calculation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(key))
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }
}

struct SafariWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let wk = WKWebView()
        wk.load(URLRequest(url: url))
        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
