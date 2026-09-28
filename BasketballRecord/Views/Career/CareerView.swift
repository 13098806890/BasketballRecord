import SwiftUI

enum PlayerSortField: String, CaseIterable {
    case totalPoints
    case avgPoints
    case plusMinus
    case elo

    var title: String {
        switch self {
        case .totalPoints: return NSLocalizedString("sort_total_points", comment: "Total Points")
        case .avgPoints: return NSLocalizedString("sort_avg_points", comment: "Avg Points")
        case .plusMinus: return NSLocalizedString("stats_plus_minus", comment: "+/-")
        case .elo: return NSLocalizedString("label_elo", comment: "ELO")
        }
    }
}

struct CareerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var boardKind: CareerBoardKind = Self.initialBoardKind
    @State private var selectedGroupID: UUID?
    @State private var selectedPlayerGroupID: UUID?
    @State private var playerSortField: PlayerSortField = .avgPoints
    @State private var playerSortAscending = false
    private static var initialBoardKind: CareerBoardKind {
#if DEBUG
        if let argumentIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-screenshotCareerBoard"),
           argumentIndex + 1 < ProcessInfo.processInfo.arguments.count,
           let boardKind = CareerBoardKind(rawValue: ProcessInfo.processInfo.arguments[argumentIndex + 1]) {
            return boardKind
        }
#endif
        return .team
    }

    var body: some View {
        NavigationStack {
            careerRootContent
            .navigationTitle(boardKind == .history ? LocalizedStringKey("nav_game_history") : LocalizedStringKey("tab_career"))
            .toolbar {
                if boardKind == .player {
                    ToolbarItem(placement: .topBarTrailing) {
                        BasketballExcelExportButton(
                            gamesForSelection: {
                                (store.isPro ? selectedGroupID.map { store.gamesInGroup($0) } : nil) ?? store.savedGames
                            },
                            selectedGamesExportFile: { selectedGames in
                                let players = (store.isPro ? selectedPlayerGroupID.map { groupID in store.players.filter { $0.playerGroupIDs.contains(groupID) } } : nil) ?? store.players
                                return BasketballExcelReportBuilder.playerCareerSummary(players: players, games: selectedGames).exportFile
                            }
                        ) {
                            let games = (store.isPro ? selectedGroupID.map { store.gamesInGroup($0) } : nil) ?? store.savedGames
                            let players = (store.isPro ? selectedPlayerGroupID.map { groupID in store.players.filter { $0.playerGroupIDs.contains(groupID) } } : nil) ?? store.players
                            return BasketballExcelReportBuilder.playerCareerSummary(players: players, games: games).exportFile
                        }
                    }
                }
                if boardKind != .history, store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 8) {
                            PlayerGroupPicker(store: store, selectedGroupID: $selectedPlayerGroupID)
                            GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedGroupID = store.isPro ? FilterDefaults.load(FilterDefaults.careerKey) : nil
            selectedPlayerGroupID = store.isPro ? FilterDefaults.load(FilterDefaults.careerPlayerGroupKey) : nil
        }
        .onChange(of: selectedGroupID) { _, newValue in
            guard store.isPro else { return }
            FilterDefaults.save(FilterDefaults.careerKey, newValue)
        }
        .onChange(of: selectedPlayerGroupID) { _, newValue in
            guard store.isPro else { return }
            FilterDefaults.save(FilterDefaults.careerPlayerGroupKey, newValue)
        }
    }

    private var careerRootContent: some View {
        classicContent
    }

    private var classicContent: some View {
        VStack(spacing: 10) {
            Picker(LocalizedStringKey("tab_career"), selection: $boardKind) {
                ForEach(CareerBoardKind.allCases) { kind in
                    Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .tint(EditorialDesign.blue)
            .padding(.horizontal)
            .padding(.top, 8)

            classicFilters
            boardContent
        }
        .background(EditorialBackground())
    }

    @ViewBuilder
    private var classicFilters: some View {
        if boardKind != .history, store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
            filterRow(title: NSLocalizedString("game_group_selected_filter", comment: "Filtering by"), name: group.name) {
                selectedGroupID = nil
            }
        }

        if boardKind != .history, store.isPro, let groupID = selectedPlayerGroupID, let group = store.playerGroups.first(where: { $0.id == groupID }) {
            filterRow(title: NSLocalizedString("player_group_selected_filter", comment: "Filtering by player group"), name: group.name) {
                selectedPlayerGroupID = nil
            }
        }
    }

    private func filterRow(title: String, name: String, clear: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(name)
                    .font(.headline)
            }
            Spacer()
            Button(action: clear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var boardContent: some View {
        if boardKind == .history {
            HistoryView(embedInNavigation: false)
        } else if boardKind == .team {
            TeamCareerBoardView(selectedGroupID: $selectedGroupID)
        } else {
            PlayerCareerBoardView(
                selectedGroupID: $selectedGroupID,
                selectedPlayerGroupID: $selectedPlayerGroupID,
                sortField: $playerSortField,
                sortAscending: $playerSortAscending
            )
        }
    }

}

struct TeamCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if summaries.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("empty_no_team_data"), systemImage: "person.3.sequence")
                        .padding(.top, 80)
                }

                ForEach(summaries) { summary in
                    teamSummaryCard(summary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom)
        }
        .background(Color.clear)
    }

    private func teamSummaryCard(_ summary: TeamCareerSummary) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TeamBadgeView(teamID: summary.id, fallbackName: summary.teamName, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.teamName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(EditorialDesign.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 4) {
                    teamHeaderMetric(
                        title: NSLocalizedString("career_tile_games", comment: "Games"),
                        value: "\(summary.games)"
                    )
                    teamHeaderMetric(
                        title: NSLocalizedString("career_tile_record", comment: "Record"),
                        value: "\(summary.wins)-\(summary.losses)"
                    )
                }
                .frame(minWidth: 74, alignment: .leading)

                ZStack {
                    Circle()
                        .stroke(EditorialDesign.orange.opacity(0.24), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: max(0.02, min(summary.winRate, 1)))
                        .stroke(EditorialDesign.orange, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(summary.winRateText)
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(EditorialDesign.navy)
                        Text(LocalizedStringKey("career_tile_win_rate"))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
                .frame(width: 64, height: 64)
            }

            teamOverviewRow([
                (NSLocalizedString("career_tile_net", comment: "Average net"), summary.avgDiffText),
                (NSLocalizedString("career_tile_avg_points", comment: "Average points"), summary.avgForText),
                (NSLocalizedString("career_tile_avg_points_against", comment: "Average allowed"), summary.avgAgainstText)
            ])
        }
        .padding(14)
        .background(EditorialDesign.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(EditorialDesign.divider.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: EditorialDesign.navy.opacity(0.06), radius: 12, y: 6)
    }

    private func teamHeaderMetric(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(EditorialDesign.navy)
        }
        .lineLimit(1)
    }

    private func teamOverviewRow(_ items: [(String, String)]) -> some View {
        HStack(spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 3) {
                    Text(item.0)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(item.1)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(EditorialDesign.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .trailing) {
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(.secondary.opacity(0.25))
                            .frame(width: 1, height: 12)
                    }
                }
            }
        }
    }

    private var summaries: [TeamCareerSummary] {
        store.teams.compactMap { team in
            var games = 0
            var wins = 0
            var losses = 0
            var pointsFor = 0
            var pointsAgainst = 0

            let relevantGames = (store.isPro ? selectedGroupID.map { store.gamesInGroup($0) } : nil) ?? store.savedGames

            for game in relevantGames {
                if game.snapshot.homeTeamID == team.id {
                    let home = game.score(forTeamID: team.id)
                    let awayID = game.snapshot.awayTeamID
                    let away = awayID.map { game.score(forTeamID: $0) } ?? 0
                    games += 1
                    pointsFor += home
                    pointsAgainst += away
                    if home > away { wins += 1 } else if home < away { losses += 1 }
                } else if game.snapshot.awayTeamID == team.id {
                    let away = game.score(forTeamID: team.id)
                    let homeID = game.snapshot.homeTeamID
                    let home = homeID.map { game.score(forTeamID: $0) } ?? 0
                    games += 1
                    pointsFor += away
                    pointsAgainst += home
                    if away > home { wins += 1 } else if away < home { losses += 1 }
                }
            }

            guard games > 0 else { return nil }

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

}

struct PlayerCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?
    @Binding var selectedPlayerGroupID: UUID?
    @Binding var sortField: PlayerSortField
    @Binding var sortAscending: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                sortRow

                if summaries.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("empty_no_player_data"), systemImage: "person.crop.circle.badge.questionmark")
                        .padding(.top, 56)
                }

                ForEach(summaries) { summary in
                    NavigationLink {
                        PlayerProfileView(playerID: summary.id, selectedGroupID: $selectedGroupID)
                    } label: {
                        playerSummaryCard(summary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            PlayerProfileDebugLog.log("xdz career player cell received tap playerID=\(summary.id) name=\(summary.name)")
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private func playerSummaryCard(_ summary: PlayerCareerSummary) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if let player = store.player(for: summary.id) {
                    PlayerAvatarView(player: player, size: 58)
                } else {
                    Circle()
                        .fill(EditorialDesign.paleOrange)
                        .frame(width: 58, height: 58)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(EditorialDesign.orange)
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(EditorialDesign.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if let player = store.player(for: summary.id), !player.position.isEmpty {
                        Text(player.position)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(EditorialDesign.blue)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(EditorialDesign.paleBlue, in: Capsule())
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(sortValueText(for: summary))
                        .font(.title2.monospacedDigit().weight(.bold))
                        .foregroundStyle(EditorialDesign.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(sortField.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .overlay(EditorialDesign.divider)

            HStack(spacing: 0) {
                playerMetric(title: localized("career_stat_games_played_short"), value: "\(summary.games)")
                playerMetric(title: localized("stats_points_format_short"), value: summary.avgPointsText)
                playerMetric(title: metricLabel(from: "stats_rebound_detail_short"), value: summary.avgReboundsText)
                playerMetric(title: metricLabel(from: "stats_assist_steal_block_short"), value: summary.avgAssistsText)
                playerMetric(title: localized("stats_minutes"), value: summary.avgMinutesText)
            }
        }
        .padding(16)
        .editorialCard(tint: EditorialDesign.card, radius: 24)
        .contentShape(Rectangle())
    }

    private func playerMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(EditorialDesign.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricLabel(from key: String) -> String {
        localized(key)
            .components(separatedBy: "/")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? localized(key)
    }

    private func sortValueText(for summary: PlayerCareerSummary) -> String {
        switch sortField {
        case .totalPoints: return "\(summary.totalPoints)"
        case .avgPoints: return summary.avgPointsText
        case .plusMinus:
            return summary.totalPlusMinus > 0 ? "+\(summary.totalPlusMinus)" : "\(summary.totalPlusMinus)"
        case .elo: return "\(Int(summary.elo))"
        }
    }

    private var sortRow: some View {
        HStack {
            Text(NSLocalizedString("label_sort_by", comment: "Sort by"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EditorialDesign.navy)
            Spacer()
            Menu {
                ForEach(PlayerSortField.allCases, id: \.self) { field in
                    Button {
                        if sortField == field {
                            sortAscending.toggle()
                        } else {
                            sortField = field
                            sortAscending = false
                        }
                    } label: {
                        HStack {
                            Text(field.title)
                            if sortField == field {
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortField.title)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(EditorialDesign.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(EditorialDesign.paleBlue, in: Capsule())
            }
        }
        .padding(.horizontal, 2)
    }

    private var summaries: [PlayerCareerSummary] {
        let relevantGames = (store.isPro ? selectedGroupID.map { store.gamesInGroup($0) } : nil) ?? store.savedGames
        let rosteredIDs: Set<UUID>?
        if store.isPro, selectedGroupID != nil {
            rosteredIDs = Set(relevantGames.flatMap { $0.homePlayerIDs + $0.awayPlayerIDs })
        } else {
            rosteredIDs = nil
        }

        let candidates = rosteredIDs.map { ids in store.players.filter { ids.contains($0.id) } } ?? store.players

        let filtered = (store.isPro ? selectedPlayerGroupID.map { groupID in candidates.filter { $0.playerGroupIDs.contains(groupID) } } : nil) ?? candidates

        var result = filtered.compactMap { player -> PlayerCareerSummary? in
            var games = 0
            var total = PlayerStats()
            var totalSeconds: TimeInterval = 0
            var totalPlusMinus = 0

            for game in relevantGames {
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
                total.offensiveRebounds += stats.offensiveRebounds
                total.defensiveRebounds += stats.defensiveRebounds
                total.assists += stats.assists
                total.fouls += stats.fouls
                total.blocks += stats.blocks
                total.steals += stats.steals
                total.turnovers += stats.turnovers
                totalSeconds += game.snapshot.playingSecondsByPlayerID[player.id, default: 0]
                totalPlusMinus += game.snapshot.plusMinusByPlayerID[player.id, default: 0]
            }

            guard games > 0 else { return nil }

            let elo = ELOEngine.computeELO(for: player.id, from: relevantGames)

            return PlayerCareerSummary(
                id: player.id,
                name: player.name,
                games: games,
                totalPoints: total.points,
                totalRebounds: total.rebounds,
                totalAssists: total.assists,
                totalSeconds: totalSeconds,
                totalPlusMinus: totalPlusMinus,
                elo: elo
            )
        }

        result.sort {
            let ascending = sortAscending

            switch sortField {
            case .totalPoints:
                return ascending ? $0.totalPoints < $1.totalPoints : $0.totalPoints > $1.totalPoints
            case .avgPoints:
                if $0.avgPoints == $1.avgPoints { return $0.totalPoints > $1.totalPoints }
                return ascending ? $0.avgPoints < $1.avgPoints : $0.avgPoints > $1.avgPoints
            case .plusMinus:
                if $0.totalPlusMinus == $1.totalPlusMinus { return $0.totalPoints > $1.totalPoints }
                return ascending ? $0.totalPlusMinus < $1.totalPlusMinus : $0.totalPlusMinus > $1.totalPlusMinus
            case .elo:
                if $0.elo == $1.elo { return $0.totalPoints > $1.totalPoints }
                return ascending ? $0.elo < $1.elo : $0.elo > $1.elo
            }
        }

        return result
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

    var avgDiffText: String {
        guard games > 0 else { return "0.0" }
        let average = Double(pointsFor - pointsAgainst) / Double(games)
        return average > 0 ? String(format: "+%.1f", average) : String(format: "%.1f", average)
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
    var totalPlusMinus: Int = 0
    var elo: Double = 1500

    var avgPoints: Double { games > 0 ? Double(totalPoints) / Double(games) : 0 }
    var avgPointsText: String { String(format: "%.1f", avgPoints) }
    var avgReboundsText: String { String(format: "%.1f", games > 0 ? Double(totalRebounds) / Double(games) : 0) }
    var avgAssistsText: String { String(format: "%.1f", games > 0 ? Double(totalAssists) / Double(games) : 0) }
    var avgMinutesText: String { String(format: "%.1f", games > 0 ? totalSeconds / 60 / Double(games) : 0) }
}
