import SwiftUI

struct CareerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var boardKind: CareerBoardKind = .team
    @State private var selectedGroupID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker(LocalizedStringKey("tab_career"), selection: $boardKind) {
                    ForEach(CareerBoardKind.allCases) { kind in
                        Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
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
                    .padding(.top, 4)
                }

                if boardKind == .team {
                    TeamCareerBoardView(selectedGroupID: $selectedGroupID)
                } else {
                    PlayerCareerBoardView(selectedGroupID: $selectedGroupID)
                }
            }
            .navigationTitle(LocalizedStringKey("tab_career"))
            .toolbar {
                if store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                    }
                }
            }
        }
        .onAppear {
            selectedGroupID = FilterDefaults.load(FilterDefaults.careerKey)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            FilterDefaults.save(FilterDefaults.careerKey, newValue)
        }
    }
}

private struct TeamCareerBoardView: View {
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
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var summaries: [TeamCareerSummary] {
        store.teams.map { team in
            var games = 0
            var wins = 0
            var losses = 0
            var pointsFor = 0
            var pointsAgainst = 0

            let relevantGames = selectedGroupID.map { store.gamesInGroup($0) } ?? store.savedGames

            for game in relevantGames {
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

private struct PlayerCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?

    var body: some View {
        List {
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
                                Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), summary.totalPoints))
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
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

    private var summaries: [PlayerCareerSummary] {
        store.players.map { player in
            var games = 0
            var total = PlayerStats()
            var totalSeconds: TimeInterval = 0

            let relevantGames = selectedGroupID.map { store.gamesInGroup($0) } ?? store.savedGames

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
                total.assists += stats.assists
                total.fouls += stats.fouls
                total.blocks += stats.blocks
                total.steals += stats.steals
                total.turnovers += stats.turnovers
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

