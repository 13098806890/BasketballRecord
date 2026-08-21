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
    @State private var boardKind: CareerBoardKind = .team
    @State private var selectedGroupID: UUID?
    @State private var selectedPlayerGroupID: UUID?
    @State private var playerSortField: PlayerSortField = .avgPoints
    @State private var playerSortAscending = false
    @AppStorage(AppSkin.storageKey) private var appSkinRaw = AppSkin.classic.rawValue

    private var usesPixelSkin: Bool { AppSkin(rawValue: appSkinRaw) == .pixelEsports }

    var body: some View {
        NavigationStack {
            careerRootContent
            .navigationTitle(boardKind == .history ? LocalizedStringKey("nav_game_history") : LocalizedStringKey("tab_career"))
            .modifier(CareerNavigationBarSkin(isPixelSkin: usesPixelSkin))
            .toolbar {
                if !usesPixelSkin, boardKind != .history, store.isPro {
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

    @ViewBuilder
    private var careerRootContent: some View {
        if usesPixelSkin {
            CareerPixelView(
                boardKind: $boardKind,
                selectedGroupID: $selectedGroupID,
                selectedPlayerGroupID: $selectedPlayerGroupID,
                playerSortField: $playerSortField,
                playerSortAscending: $playerSortAscending
            )
        } else {
            classicContent
        }
    }

    private var classicContent: some View {
        VStack(spacing: 10) {
            Picker(LocalizedStringKey("tab_career"), selection: $boardKind) {
                ForEach(CareerBoardKind.allCases) { kind in
                    Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            classicFilters
            boardContent(usesPixelSkin: false)
        }
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
    private func boardContent(usesPixelSkin: Bool) -> some View {
        if boardKind == .history {
            HistoryView(embedInNavigation: false)
        } else if boardKind == .team {
            TeamCareerBoardView(selectedGroupID: $selectedGroupID, usesPixelSkin: usesPixelSkin)
        } else {
            PlayerCareerBoardView(
                selectedGroupID: $selectedGroupID,
                selectedPlayerGroupID: $selectedPlayerGroupID,
                sortField: $playerSortField,
                sortAscending: $playerSortAscending,
                usesPixelSkin: usesPixelSkin
            )
        }
    }

}

struct TeamCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?
    var usesPixelSkin = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if summaries.isEmpty {
                    if usesPixelSkin {
                        Text(LocalizedStringKey("empty_no_team_data"))
                            .font(.system(.caption, design: .monospaced).weight(.black))
                            .foregroundStyle(CareerPixelDesign.muted)
                            .padding(.top, 80)
                    } else {
                        ContentUnavailableView(LocalizedStringKey("empty_no_team_data"), systemImage: "person.3.sequence")
                            .padding(.top, 80)
                    }
                }

                ForEach(summaries) { summary in
                    if usesPixelSkin {
                        pixelTeamCard(summary)
                    } else {
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
                                teamCard(title: LocalizedStringKey("career_tile_games"), value: "\(summary.games)")
                                teamCard(title: LocalizedStringKey("career_tile_win_rate"), value: summary.winRateText)
                                teamCard(title: LocalizedStringKey("career_tile_net"), value: summary.diffText)
                            }
                            HStack(spacing: 8) {
                                teamCard(title: LocalizedStringKey("career_tile_avg_points"), value: summary.avgForText)
                                teamCard(title: LocalizedStringKey("career_tile_avg_points_against"), value: summary.avgAgainstText)
                                teamCard(title: LocalizedStringKey("career_tile_total_score"), value: "\(summary.pointsFor)-\(summary.pointsAgainst)")
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator).opacity(0.15), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, usesPixelSkin ? 14 : 16)
            .padding(.bottom)
        }
        .background(usesPixelSkin ? CareerPixelDesign.background : Color(.systemGroupedBackground))
    }

    private func pixelTeamCard(_ summary: TeamCareerSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.teamName)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(CareerPixelDesign.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Text("\(summary.wins)-\(summary.losses)")
                    .font(.system(.headline, design: .monospaced).weight(.black))
                    .foregroundStyle(CareerPixelDesign.ink)
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    pixelTeamMetric(title: LocalizedStringKey("career_tile_games"), value: "\(summary.games)", color: CareerPixelDesign.ink)
                    pixelTeamMetric(title: LocalizedStringKey("career_tile_win_rate"), value: summary.winRateText, color: CareerPixelDesign.cyan)
                    pixelTeamMetric(title: LocalizedStringKey("career_tile_net"), value: summary.diffText, color: CareerPixelDesign.lime)
                }
                HStack(spacing: 0) {
                    pixelTeamMetric(title: LocalizedStringKey("career_tile_avg_points"), value: summary.avgForText, color: CareerPixelDesign.amber)
                    pixelTeamMetric(title: LocalizedStringKey("career_tile_avg_points_against"), value: summary.avgAgainstText, color: CareerPixelDesign.amber)
                    pixelTeamMetric(title: LocalizedStringKey("career_tile_total_score"), value: "\(summary.pointsFor)-\(summary.pointsAgainst)", color: CareerPixelDesign.amber)
                }
            }
            .background(CareerPixelDesign.panelStrong.opacity(0.62))
            .overlay(CareerPixelPanelShape().stroke(CareerPixelDesign.line, lineWidth: 1))
        }
        .padding(12)
        .background(CareerPixelPanelShape().fill(CareerPixelDesign.panel))
        .overlay(CareerPixelPanelShape().stroke(CareerPixelDesign.line, lineWidth: 1))
        .shadow(color: CareerPixelDesign.cyan.opacity(0.16), radius: 0, x: 3, y: 3)
    }

    private func pixelTeamMetric(title: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(CareerPixelDesign.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(CareerPixelDesign.line)
                .frame(width: 1, height: 42)
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


    private func teamCard(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator).opacity(0.15), lineWidth: 1))
    }
}

struct PlayerCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?
    @Binding var selectedPlayerGroupID: UUID?
    @Binding var sortField: PlayerSortField
    @Binding var sortAscending: Bool
    var usesPixelSkin = false

    var body: some View {
        if usesPixelSkin {
            pixelBody
        } else {
            classicBody
        }
    }

    private var classicBody: some View {
        List {
            Section {
                sortRow
            }

            if summaries.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_player_data"), systemImage: "person.crop.circle.badge.questionmark")
            }

            ForEach(summaries) { summary in
                NavigationLink {
                    PlayerProfileView(playerID: summary.id, selectedGroupID: $selectedGroupID)
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
                                Text(sortValueText(for: summary))
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            Text(String(format: NSLocalizedString("career_summary_format", comment: "Career summary"), summary.games, summary.avgPointsText, summary.avgReboundsText, summary.avgAssistsText, summary.avgMinutesText))
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

    private var pixelBody: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                pixelSortRow

                if summaries.isEmpty {
                    Text(LocalizedStringKey("empty_no_player_data"))
                        .font(.system(.caption, design: .monospaced).weight(.black))
                        .foregroundStyle(CareerPixelDesign.muted)
                        .padding(.top, 70)
                }

            ForEach(summaries) { summary in
                NavigationLink {
                    PlayerProfileView(playerID: summary.id, selectedGroupID: $selectedGroupID)
                } label: {
                    pixelPlayerRow(summary)
                    }
                    .buttonStyle(CareerPixelButtonStyle(accent: CareerPixelDesign.cyan))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom)
        }
        .background(CareerPixelDesign.background)
    }

    private var pixelSortRow: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey("label_sort_by"))
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPixelDesign.muted)
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
                HStack(spacing: 5) {
                    Text(sortField.title)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundStyle(CareerPixelDesign.cyan)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(CareerPixelPanelShape().fill(CareerPixelDesign.panel))
                .overlay(CareerPixelPanelShape().stroke(CareerPixelDesign.line, lineWidth: 1))
            }
            .buttonStyle(CareerPixelButtonStyle(accent: CareerPixelDesign.cyan))
        }
        .padding(.vertical, 4)
    }

    private func pixelPlayerRow(_ summary: PlayerCareerSummary) -> some View {
        HStack(spacing: 10) {
            if let player = store.player(for: summary.id) {
                PlayerAvatarView(player: player, size: 44, usesPixelSkin: true)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(summary.name)
                        .font(.system(.subheadline, design: .monospaced).weight(.black))
                        .foregroundStyle(CareerPixelDesign.ink)
                        .lineLimit(1)
                    if let player = store.player(for: summary.id), !player.position.isEmpty {
                        Text(player.position)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(CareerPixelDesign.amber)
                    }
                    Spacer(minLength: 4)
                    Text(sortValueText(for: summary))
                        .font(.system(.subheadline, design: .monospaced).weight(.black))
                        .foregroundStyle(CareerPixelDesign.cyan)
                }
                Text(String(format: NSLocalizedString("career_summary_format", comment: "Career summary"), summary.games, summary.avgPointsText, summary.avgReboundsText, summary.avgAssistsText, summary.avgMinutesText))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CareerPixelDesign.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.black))
                .foregroundStyle(CareerPixelDesign.muted)
        }
        .padding(10)
        .background(CareerPixelPanelShape().fill(CareerPixelDesign.panel))
        .overlay(CareerPixelPanelShape().stroke(CareerPixelDesign.line, lineWidth: 1))
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
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        .font(.caption.weight(.semibold))
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
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
