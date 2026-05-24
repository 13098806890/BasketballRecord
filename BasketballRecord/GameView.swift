import SwiftUI

struct GameView: View {
    @EnvironmentObject private var store: AppStore

    @State private var snapshot = GameSnapshot()
    @State private var undoStack: [GameSnapshot] = []
    @State private var selectedPlayerID: UUID?
    @State private var selectedSide: TeamSide = .home

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                teamPickers
                    .padding([.horizontal, .top])

                ScrollView {
                    VStack(spacing: 16) {
                        TeamStripView(
                            side: .home,
                            team: store.team(for: snapshot.homeTeamID),
                            players: players(in: snapshot.homeTeamID),
                            score: score(for: snapshot.homeTeamID),
                            selectedPlayerID: selectedPlayerID,
                            selectedSide: selectedSide,
                            onSelect: selectPlayer
                        )

                        TeamStripView(
                            side: .away,
                            team: store.team(for: snapshot.awayTeamID),
                            players: players(in: snapshot.awayTeamID),
                            score: score(for: snapshot.awayTeamID),
                            selectedPlayerID: selectedPlayerID,
                            selectedSide: selectedSide,
                            onSelect: selectPlayer
                        )

                        StatsCardView(player: selectedPlayer, stats: selectedStats)
                            .padding(.horizontal)

                        actionButtons
                            .padding(.horizontal)

                        logView
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("比赛记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        resetGame()
                    } label: {
                        Label("重置比赛", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .onAppear(perform: ensureInitialSelection)
            .onChange(of: store.teams) { _, _ in ensureInitialSelection() }
        }
    }

    private var teamPickers: some View {
        HStack(spacing: 12) {
            Picker("主队", selection: Binding(
                get: { snapshot.homeTeamID ?? store.teams.first?.id },
                set: { snapshot.homeTeamID = $0; ensureSelectedPlayer() }
            )) {
                ForEach(store.teams) { team in
                    Text(team.name).tag(Optional(team.id))
                }
            }
            .pickerStyle(.menu)

            Text("VS")
                .font(.headline)
                .foregroundStyle(.secondary)

            Picker("客队", selection: Binding(
                get: { snapshot.awayTeamID ?? store.teams.dropFirst().first?.id ?? store.teams.first?.id },
                set: { snapshot.awayTeamID = $0; ensureSelectedPlayer() }
            )) {
                ForEach(store.teams) { team in
                    Text(team.name).tag(Optional(team.id))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var actionButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
            statButton("2分命中", systemImage: "2.circle.fill") { record(.twoMade) }
            statButton("2分不中", systemImage: "2.circle") { record(.twoMissed) }
            statButton("3分命中", systemImage: "3.circle.fill") { record(.threeMade) }
            statButton("3分不中", systemImage: "3.circle") { record(.threeMissed) }
            statButton("加罚命中", systemImage: "plus.circle.fill") { record(.bonusMade) }
            statButton("加罚不中", systemImage: "plus.circle") { record(.bonusMissed) }
            statButton("罚篮命中", systemImage: "f.circle.fill") { record(.freeThrowMade) }
            statButton("罚篮不中", systemImage: "f.circle") { record(.freeThrowMissed) }
            statButton("犯规", systemImage: "exclamationmark.triangle") { record(.foul) }
            statButton("助攻", systemImage: "arrowshape.turn.up.right") { record(.assist) }
            statButton("篮板", systemImage: "hands.sparkles") { record(.rebound) }
            statButton("撤回", systemImage: "arrow.uturn.backward", role: .destructive) { undo() }
                .disabled(undoStack.isEmpty)
        }
        .buttonStyle(.bordered)
        .disabled(selectedPlayer == nil)
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("记录流水")
                .font(.headline)

            if snapshot.logs.isEmpty {
                ContentUnavailableView("还没有记录", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(snapshot.logs.reversed()) { entry in
                        Text("\(Self.timeFormatter.string(from: entry.timestamp))  \(entry.message)")
                            .font(.footnote.monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var selectedPlayer: Player? {
        guard let selectedPlayerID else { return nil }
        return store.player(for: selectedPlayerID)
    }

    private var selectedStats: PlayerStats {
        guard let selectedPlayerID else { return PlayerStats() }
        return snapshot.statsByPlayerID[selectedPlayerID, default: PlayerStats()]
    }

    private func statButton(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
    }

    private func players(in teamID: UUID?) -> [Player] {
        guard let team = store.team(for: teamID) else { return [] }
        return team.playerIDs.compactMap { store.player(for: $0) }
    }

    private func score(for teamID: UUID?) -> Int {
        players(in: teamID).reduce(0) { total, player in
            total + snapshot.statsByPlayerID[player.id, default: PlayerStats()].points
        }
    }

    private func selectPlayer(_ player: Player, _ side: TeamSide) {
        selectedPlayerID = player.id
        selectedSide = side
    }

    private func ensureInitialSelection() {
        if snapshot.homeTeamID == nil {
            snapshot.homeTeamID = store.teams.first?.id
        }
        if snapshot.awayTeamID == nil {
            snapshot.awayTeamID = store.teams.dropFirst().first?.id ?? store.teams.first?.id
        }
        ensureSelectedPlayer()
    }

    private func ensureSelectedPlayer() {
        let currentPlayers = players(in: selectedSide == .home ? snapshot.homeTeamID : snapshot.awayTeamID)
        if let selectedPlayerID, currentPlayers.contains(where: { $0.id == selectedPlayerID }) {
            return
        }

        if let firstHome = players(in: snapshot.homeTeamID).first {
            selectPlayer(firstHome, .home)
        } else if let firstAway = players(in: snapshot.awayTeamID).first {
            selectPlayer(firstAway, .away)
        } else {
            selectedPlayerID = nil
        }
    }

    private func record(_ action: StatAction) {
        guard let player = selectedPlayer else { return }
        undoStack.append(snapshot)

        var stats = snapshot.statsByPlayerID[player.id, default: PlayerStats()]
        action.apply(to: &stats)
        snapshot.statsByPlayerID[player.id] = stats
        snapshot.logs.append(GameLogEntry(timestamp: Date(), message: "\(player.name) \(action.message)"))
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        snapshot = previous
        ensureSelectedPlayer()
    }

    private func resetGame() {
        undoStack.removeAll()
        snapshot = GameSnapshot(homeTeamID: snapshot.homeTeamID, awayTeamID: snapshot.awayTeamID)
        ensureSelectedPlayer()
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

enum TeamSide: String {
    case home = "主队"
    case away = "客队"
}

private enum StatAction {
    case twoMade, twoMissed, threeMade, threeMissed
    case bonusMade, bonusMissed, freeThrowMade, freeThrowMissed
    case foul, assist, rebound

    var message: String {
        switch self {
        case .twoMade: return "2分命中"
        case .twoMissed: return "2分不中"
        case .threeMade: return "3分命中"
        case .threeMissed: return "3分不中"
        case .bonusMade: return "加罚命中"
        case .bonusMissed: return "加罚不中"
        case .freeThrowMade: return "罚篮命中"
        case .freeThrowMissed: return "罚篮不中"
        case .foul: return "犯规"
        case .assist: return "助攻"
        case .rebound: return "篮板"
        }
    }

    func apply(to stats: inout PlayerStats) {
        switch self {
        case .twoMade:
            stats.twoMade += 1
            stats.twoAttempts += 1
        case .twoMissed:
            stats.twoAttempts += 1
        case .threeMade:
            stats.threeMade += 1
            stats.threeAttempts += 1
        case .threeMissed:
            stats.threeAttempts += 1
        case .bonusMade:
            stats.bonusFreeThrowMade += 1
            stats.bonusFreeThrowAttempts += 1
        case .bonusMissed:
            stats.bonusFreeThrowAttempts += 1
        case .freeThrowMade:
            stats.freeThrowMade += 1
            stats.freeThrowAttempts += 1
        case .freeThrowMissed:
            stats.freeThrowAttempts += 1
        case .foul:
            stats.fouls += 1
        case .assist:
            stats.assists += 1
        case .rebound:
            stats.rebounds += 1
        }
    }
}

private struct TeamStripView: View {
    var side: TeamSide
    var team: Team?
    var players: [Player]
    var score: Int
    var selectedPlayerID: UUID?
    var selectedSide: TeamSide
    var onSelect: (Player, TeamSide) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(team?.name ?? side.rawValue)
                        .font(.headline)
                    Text("\(players.count) 名球员")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(score)")
                    .font(.largeTitle.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal)

            if players.isEmpty {
                ContentUnavailableView("这支球队还没有球员", systemImage: "person.3.sequence")
                    .frame(minHeight: 88)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            Button {
                                onSelect(player, side)
                            } label: {
                                VStack(spacing: 6) {
                                    PlayerAvatarView(player: player)
                                        .overlay {
                                            if selectedPlayerID == player.id && selectedSide == side {
                                                Circle().stroke(Color.accentColor, lineWidth: 3)
                                            }
                                        }
                                    Text(player.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .frame(width: 72)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                }
            }
        }
    }
}

private struct StatsCardView: View {
    var player: Player?
    var stats: PlayerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(player?.name ?? "选择球员")
                    .font(.headline)
                Spacer()
                Text("得分 \(stats.points)")
                    .font(.headline.monospacedDigit())
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                statRow("投篮", "\(stats.made)/\(stats.attempts)", "投篮命中率", percent(stats.fieldGoalRate))
                statRow("2分投篮", "\(stats.twoMade)/\(stats.twoAttempts)", "2分命中率", percent(stats.twoPointRate))
                statRow("3分投篮", "\(stats.threeMade)/\(stats.threeAttempts)", "3分命中率", percent(stats.threePointRate))
                statRow("篮板", "\(stats.rebounds)", "助攻", "\(stats.assists)")
                statRow("犯规", "\(stats.fouls)", "罚篮", "\(stats.freeThrowMade)/\(stats.freeThrowAttempts)")
                statRow("加罚", "\(stats.bonusFreeThrowMade)/\(stats.bonusFreeThrowAttempts)", "", "")
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func statRow(_ labelA: String, _ valueA: String, _ labelB: String, _ valueB: String) -> some View {
        GridRow {
            Text(labelA).foregroundStyle(.secondary)
            Text(valueA).fontWeight(.semibold)
            Text(labelB).foregroundStyle(.secondary)
            Text(valueB).fontWeight(.semibold)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
