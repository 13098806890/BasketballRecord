import SwiftUI

struct RosterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false
    @State private var editingPlayer: Player?
    @State private var editingTeam: Team?

    var body: some View {
        NavigationStack {
            List {
                Section("球员") {
                    if store.players.isEmpty {
                        ContentUnavailableView("还没有球员", systemImage: "person.crop.circle.badge.plus")
                    }

                    ForEach(store.players) { player in
                        HStack(spacing: 8) {
                            NavigationLink {
                                PlayerProfileView(playerID: player.id)
                            } label: {
                                HStack(spacing: 12) {
                                    PlayerAvatarView(player: player, size: 44)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(player.name)
                                            .font(.headline)
                                        Text(playerSubtitle(player))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Button {
                                editingPlayer = player
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: store.deletePlayers)
                }

                Section("球队") {
                    if store.teams.isEmpty {
                        ContentUnavailableView("还没有球队", systemImage: "person.3.fill")
                    }

                    ForEach(store.teams) { team in
                        Button {
                            editingTeam = team
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(team.name)
                                    .font(.headline)
                                Text(team.playerIDs.compactMap { store.player(for: $0)?.name }.joined(separator: "、"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete(perform: store.deleteTeams)
                }
            }
            .navigationTitle("配置")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingTeamEditor = true
                    } label: {
                        Label("新建球队", systemImage: "person.3.fill")
                    }

                    Button {
                        showingPlayerEditor = true
                    } label: {
                        Label("新建球员", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingPlayerEditor) {
                PlayerEditorView(player: nil)
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditorView(player: player)
            }
            .sheet(isPresented: $showingTeamEditor) {
                TeamEditorView(team: nil)
            }
            .sheet(item: $editingTeam) { team in
                TeamEditorView(team: team)
            }
        }
    }

    private func playerSubtitle(_ player: Player) -> String {
        var parts: [String] = []
        if !player.number.isEmpty { parts.append("#\(player.number)") }
        if !player.height.isEmpty { parts.append("\(player.height)cm") }
        if !player.weight.isEmpty { parts.append("\(player.weight)kg") }
        return parts.isEmpty ? "未填写号码、身高、体重" : parts.joined(separator: " · ")
    }
}

private struct PlayerProfileView: View {
    @EnvironmentObject private var store: AppStore
    var playerID: UUID
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()

    private var player: Player? { store.player(for: playerID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                DatePicker("统计起始日期", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                statSection("场均", values: averageValues)
                statSection("总数据", values: totalValues)
            }
            .padding(.vertical)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .navigationTitle(player?.name ?? "球员")
        .navigationBarTitleDisplayMode(.inline)
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
                    Text("比赛 \(filteredGames.count) 场")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.7), in: Capsule())
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.82, green: 0.88, blue: 0.82), Color(red: 0.90, green: 0.84, blue: 0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal)
    }

    private func statSection(_ title: String, values: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(values, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.headline.monospacedDigit().weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal)
    }

    private var filteredGames: [SavedGame] {
        store.savedGames.filter { game in
            game.savedAt >= startDate && (game.homePlayerIDs.contains(playerID) || game.awayPlayerIDs.contains(playerID) || game.snapshot.statsByPlayerID[playerID] != nil)
        }
    }

    private var totalStats: PlayerStats {
        filteredGames.reduce(PlayerStats()) { partial, game in
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            var total = partial
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

    private var totalMinutes: Double {
        filteredGames.reduce(0) { $0 + ($1.snapshot.playingSecondsByPlayerID[playerID, default: 0] / 60) }
    }

    private var totalPlusMinus: Int {
        filteredGames.reduce(0) { $0 + $1.snapshot.plusMinusByPlayerID[playerID, default: 0] }
    }

    private var totalValues: [(String, String)] {
        let stats = totalStats
        return [
            ("得分", "\(stats.points)"),
            ("篮板", "\(stats.rebounds)"),
            ("助攻", "\(stats.assists)"),
            ("犯规", "\(stats.fouls)"),
            ("时间", String(format: "%.1f", totalMinutes)),
            ("正负值", totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"),
            ("投篮", "\(stats.made)/\(stats.attempts)"),
            ("3分", "\(stats.threeMade)/\(stats.threeAttempts)"),
            ("罚篮", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)")
        ]
    }

    private var averageValues: [(String, String)] {
        let games = max(1, filteredGames.count)
        let stats = totalStats
        return [
            ("PTS", average(stats.points, games)),
            ("REB", average(stats.rebounds, games)),
            ("AST", average(stats.assists, games)),
            ("FOUL", average(stats.fouls, games)),
            ("MIN", String(format: "%.1f", totalMinutes / Double(games))),
            ("+/-", String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
            ("FG%", percent(stats.fieldGoalRate)),
            ("3P%", percent(stats.threePointRate)),
            ("FT%", percent(stats.freeThrowRate))
        ]
    }

    private func average(_ value: Int, _ games: Int) -> String {
        String(format: "%.1f", Double(value) / Double(games))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func profileSubtitle(_ player: Player) -> String {
        var parts: [String] = []
        if !player.number.isEmpty { parts.append("#\(player.number)") }
        if !player.height.isEmpty { parts.append("\(player.height)cm") }
        if !player.weight.isEmpty { parts.append("\(player.weight)kg") }
        return parts.isEmpty ? "未填写基础资料" : parts.joined(separator: " · ")
    }
}
