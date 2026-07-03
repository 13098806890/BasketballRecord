import SwiftUI

struct SavedGameDetailView: View {
    enum DisplayMode {
        case history
        case live
    }

    @EnvironmentObject private var store: AppStore
    var game: SavedGame
    var displayMode: DisplayMode = .history
    @State private var isShowingExport = false
   @State private var selectedPeriod: Int? = nil
   @State private var periodAnalysis = SavedGamePeriodAnalysis()
    @State private var cachedPlayingTimeByPeriod: [Int: [UUID: TimeInterval]] = [:]
    @State private var selectedGroupID: UUID?
   @State private var editDisplayName = ""
   @State private var isShowingPurchase = false
   @State private var shareImage: UIImage?
   @State private var isEditing = false
    @State private var editRefreshID = UUID()


    init(game: SavedGame, displayMode: DisplayMode = .history) {
       self.game = game
       self.displayMode = displayMode

       _selectedGroupID = State(initialValue: game.groupIDs.first)
   }

    var body: some View {
        let l = List {
            groupAssignmentSection

            Section {
                HStack(spacing: 8) {
                    TextField(LocalizedStringKey("label_game_name"), text: $editDisplayName)
                        .font(.headline)
                        .onSubmit {
                            if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
                                store.savedGames[idx].displayName = editDisplayName
                                if store.cloudEnabledGameIDs.contains(game.id) {
                                    Task {
                                        await CloudKitManager.shared.uploadGame(store.savedGames[idx])
                                    }
                                }
                            }
                        }
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    teamSummary(.home)
                    Spacer()
                    Text(LocalizedStringKey("label_vs"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    teamSummary(.away)
                }
            }

            if game.snapshot.periodCount > 1, !availablePeriodOptions.isEmpty {
                Section(LocalizedStringKey("section_data_range")) {
                    Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                        Text(LocalizedStringKey("data_range_full")).tag(Optional<Int>.none)
                        ForEach(availablePeriodOptions, id: \.self) { period in
                            Text(game.periodDisplayName(period)).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
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
                    style: .scoreboard
                )
                .padding(.horizontal, 12)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
            }

            if !game.snapshot.homeTeamStatsMode { homePlayerSection }
           if !game.snapshot.awayTeamStatsMode { awayPlayerSection }

            if displayMode == .history {
                AISummaryView(
                    game: game,
                    store: store,
                    periodAnalysis: periodAnalysis,
                    isShowingPurchase: $isShowingPurchase
                )
            }

       }
        .navigationTitle(LocalizedStringKey("nav_game_detail"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if displayMode == .history {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.isPro {
                        Button {
                            store.toggleCloudStorage(for: game.id)
                        } label: {
                            Label(LocalizedStringKey("label_cloud"), systemImage: store.cloudEnabledGameIDs.contains(game.id) ? "icloud.fill" : "icloud")
                        }
                    }
                    if store.isPro {
                        GameGroupPicker(store: store, selectedGroupID: $selectedGroupID, iconName: "folder.badge.plus", checkedGroupIDs: Set(store.groups(for: game.id).map(\.id)))
                    }
                    Button {
                        isShowingExport = true
                    } label: {
                        Label(LocalizedStringKey("button_export"), systemImage: TransferSymbol.exportData)
                    }
                    Button {
                        if store.isPro || isEditing {
                            isEditing.toggle()
                        } else {
                            isShowingPurchase = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if !store.isPro && !isEditing {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                            }
                            Text(LocalizedStringKey(isEditing ? "button_done" : "button_edit"))
                        }
                        .foregroundStyle(store.isPro || isEditing ? Color.primary : Color.gray)
                    }
                }
            }
        }

        Group {
            if isEditing {
                GameEventLogEditorView(
                    game: game,
                    periodAnalysis: periodAnalysis,
                    selectedPeriod: selectedPeriod,
                    isEditing: $isEditing,
                    onRebuildAnalysis: {
                        rebuildPeriodAnalysis()
                        editRefreshID = UUID()
                    }
                )
                .environmentObject(store)
                .id(editRefreshID)
            } else {
                l
            }
        }
            .overlay {
                if periodAnalysis.logs.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .task {
                guard periodAnalysis.logs.isEmpty else { return }
                let analyzer = SavedGameAnalyzer(game: game) { name in
                    game.playerNamesByID.first(where: { $0.value == name })?.key
                }
                periodAnalysis = await Task.detached(priority: .userInitiated) {
                    analyzer.analyze()
                }.value
                if cachedPlayingTimeByPeriod.isEmpty {
                    cachedPlayingTimeByPeriod = game.playingTimeByPeriod()
                }
            }
            .onChange(of: store.cloudEnabledGameIDs) { _, _ in
            // UI refreshes automatically via @Published
        }
           .sheet(isPresented: $isShowingPurchase) {
               ProSubscriptionStoreView()
           }
           .sheet(isPresented: $isShowingExport) {
            ExportGameView(game: game)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            if let groupID = newValue {
                store.toggleGameGroup(game.id, groupID: groupID)
                DispatchQueue.main.async {
                    selectedGroupID = nil
                }
            }
        }
        .onAppear {
            editDisplayName = game.displayName
            sanitizeSelectedPeriod()
            BadgeAwarder.awardBadges(for: game, store: store)
            print("[EVENT_LOG] Game: \(game.homeTeamName) vs \(game.awayTeamName) | Final: \(game.homeTeamName) \(score(for: game.snapshot.homeTeamID)) : \(score(for: game.snapshot.awayTeamID)) \(game.awayTeamName)")
            print("[EVENT_LOG] periodCount=\(game.snapshot.periodCount) isComplete=\(game.snapshot.isComplete) periodEndCondition=\(game.snapshot.periodEndCondition.rawValue) scoreLimit=\(game.snapshot.periodScoreLimit)")
            print("[EVENT_LOG] --- ALL EVENTS (\(game.snapshot.logs.count) total) ---")
            for (i, entry) in game.snapshot.logs.enumerated() {
                let msg = GameLogFormatter.normalizedMessage(entry.message).prefix(60)
                let ec = entry.eventCode ?? "nil"
                let pid = entry.playerID?.uuidString.prefix(8) ?? "nil"
                let rpid = entry.relatedPlayerID?.uuidString.prefix(8) ?? "nil"
                let per = entry.period.map { "\($0)" } ?? "nil"
                let pes = entry.periodElapsedSeconds.map { String(format: "%.0f", $0) } ?? "nil"
                print("[EVENT_LOG] [\(i)] code=\(ec) period=\(per) elapsed=\(pes) pid=\(pid) related=\(rpid) msg=\(msg)")
            }
               print("[EVENT_LOG] --- END EVENTS ---")
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
            Text(String(format: NSLocalizedString("foul_count_format", comment: "Foul count"), fouls(for: teamID)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
    }

    private func playerStatRow(for playerID: UUID) -> some View {
        let stats = displayStatsByPlayerID[playerID, default: PlayerStats()]
        let playingTime: String
        if let sp = selectedPeriod {
            let timeByPeriod = cachedPlayingTimeByPeriod
            if let periodTime = timeByPeriod[sp]?[playerID], periodTime > 0 {
                playingTime = GameView.durationFormatter(periodTime)
            } else {
                playingTime = "--:--"
            }
        } else {
            playingTime = GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
        }
        let plusMinus = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
        let plusMinusText = plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"

        return NavigationLink {
            if store.player(for: playerID) != nil {
                PlayerProfileView(playerID: playerID, fixedGame: game, selectedGroupID: .constant(nil))
            } else {
                PlayerGameDetailView(game: game, playerID: playerID)
            }
        } label: {
            HStack(spacing: 10) {
                playerAvatar(for: playerID)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(game.playerNamesByID[playerID] ?? NSLocalizedString("unknown_player", comment: "Unknown player"))
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
                        Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), stats.points))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    (Text(String(format: NSLocalizedString("stats_line_format", comment: "Stats line"), playingTime, stats.made, stats.attempts, stats.allFreeThrowMade, stats.allFreeThrowAttempts, stats.totalRebounds, stats.assists, stats.fouls, stats.blocks, stats.steals, stats.turnovers))
                    + Text("  \(NSLocalizedString("stats_plus_minus", comment: "")) \(plusMinusText)  \(NSLocalizedString("stats_points_per_shot", comment: "")) \(String(format: "%.2f", stats.pointsPerShot))"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var homePlayerSection: some View {
        Section(String(format: NSLocalizedString("section_team_players_data_format", comment: "Team players data"), game.homeTeamName)) {
            ForEach(game.homePlayerIDs, id: \.self) { playerID in
                playerStatRow(for: playerID)
            }
        }
    }

    private var awayPlayerSection: some View {
        Section(String(format: NSLocalizedString("section_team_players_data_format", comment: "Team players data"), game.awayTeamName)) {
            ForEach(game.awayPlayerIDs, id: \.self) { playerID in
                playerStatRow(for: playerID)
            }
        }
    }

    @ViewBuilder
    private var groupAssignmentSection: some View {
        let assignedGroups = store.groups(for: game.id)
        if !assignedGroups.isEmpty, store.isPro {
            Section {
                ForEach(assignedGroups) { group in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_assigned_label", comment: "Assigned to"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: {
                            store.toggleGameGroup(game.id, groupID: group.id)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }

    private func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private func fouls(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        let teamFouls = game.snapshot.teamStatsByID[teamID, default: PlayerStats()].fouls
        let playerFouls = playerIDs(for: teamID).reduce(0) { total, playerID in
            total + displayStatsByPlayerID[playerID, default: PlayerStats()].fouls
        }
        return teamFouls + playerFouls
    }

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        guard let teamID else { return PlayerStats() }
        var total = game.snapshot.teamStatsByID[teamID, default: PlayerStats()]
        for playerID in playerIDs(for: teamID) {
            let stats = displayStatsByPlayerID[playerID, default: PlayerStats()]
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
        }
        return total
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private var displayStatsByPlayerID: [UUID: PlayerStats] {
        guard let selectedPeriod else {
            return game.snapshot.statsByPlayerID
        }
        let periodStats = statsByPlayerID(for: selectedPeriod)
        let homeIDs = Set(game.homePlayerIDs)
        let homePts = periodStats.filter { homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        let awayPts = periodStats.filter { !homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        let totalHome = game.snapshot.statsByPlayerID.filter { homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        let totalAway = game.snapshot.statsByPlayerID.filter { !homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        print("[SG] selectedPeriod=\(selectedPeriod) period home=\(homePts) away=\(awayPts) | total home=\(totalHome) away=\(totalAway) | match=\(homePts==totalHome && awayPts==totalAway ? "YES" : "DIFFERS")")
        return periodStats
    }

    private var availablePeriodOptions: [Int] {
        guard maxAvailablePeriod > 0 else { return [] }
        return Array(1...maxAvailablePeriod)
    }

    private var maxAvailablePeriod: Int {
        let maxConfigPeriod = max(game.snapshot.periodCount, 1)
        let maxStatsPeriod = periodAnalysis.statsByPeriod.keys.max() ?? 0
        let maxReached = max(maxStatsPeriod, maxConfigPeriod)

        if game.snapshot.isComplete {
            return maxReached
        }

       if game.snapshot.periodIsRunning || game.snapshot.periodElapsedSeconds > 0 {
            return min(max(maxReached, game.snapshot.currentPeriod), maxConfigPeriod)
        }
        return maxReached
    }


    private func statsByPlayerID(for period: Int) -> [UUID: PlayerStats] {
        periodAnalysis.statsByPlayerID(for: period)
    }

    private func rebuildPeriodAnalysis() {
        guard let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        let currentGame = store.savedGames[idx]
        let analyzer = SavedGameAnalyzer(game: currentGame) { name in
            resolvePlayerIDByName(name)
        }
        periodAnalysis = analyzer.analyze()
        rebuildGameSnapshotStats(gameIndex: idx)
        sanitizeSelectedPeriod()
    }

    private func rebuildGameSnapshotStats(gameIndex: Int) {
        let currentGame = store.savedGames[gameIndex]
        let eh = currentGame.snapshot.editHistory
        let addedIDs = Set(eh.filter { $0.action == "add" }.map(\.eventID))
        let deletedIDs = Set(eh.filter { $0.action == "delete" }.map(\.eventID))
        let restoredIDs = Set(eh.filter { $0.action == "restore" }.map(\.eventID))
        let excludedIDs = deletedIDs.subtracting(restoredIDs).union(addedIDs.intersection(deletedIDs))
        let logs = currentGame.snapshot.logs.sorted { $0.timestamp < $1.timestamp }.filter { !excludedIDs.contains($0.id) }
       let homeIDs = Set(currentGame.homePlayerIDs)
       let awayIDs = Set(currentGame.awayPlayerIDs)

       var statsByPlayer: [UUID: PlayerStats] = [:]
        var playingSeconds: [UUID: TimeInterval] = [:]
        var plusMinus: [UUID: Int] = [:]
        var homeOnCourt: Set<UUID> = []
        var awayOnCourt: Set<UUID> = []
        var lastTimestamp = logs.first?.timestamp ?? Date()

        // Initialize lineup from starters if set, otherwise empty
        let homeStarters = Set(currentGame.snapshot.starterPlayerIDs.filter { homeIDs.contains($0) })
        let awayStarters = Set(currentGame.snapshot.starterPlayerIDs.filter { awayIDs.contains($0) })

        for log in logs {
            let elapsed = max(0, log.timestamp.timeIntervalSince(lastTimestamp))
            lastTimestamp = log.timestamp

            for pid in homeOnCourt { playingSeconds[pid, default: 0] += elapsed }
            for pid in awayOnCourt { playingSeconds[pid, default: 0] += elapsed }

            guard let code = log.eventCode else { continue }

            if code.hasPrefix("event.period") {
                homeOnCourt = homeStarters
                awayOnCourt = awayStarters
                if code == "event.period_start" {
                    // Period started - ensure lineups are set
                }
            } else if code == "event.substitution", let incoming = log.playerID, let outgoing = log.relatedPlayerID {
                if homeOnCourt.contains(outgoing) { homeOnCourt.remove(outgoing); homeOnCourt.insert(incoming) }
                if awayOnCourt.contains(outgoing) { awayOnCourt.remove(outgoing); awayOnCourt.insert(incoming) }
            } else if code == "event.late_arrival", let pid = log.playerID {
                if homeIDs.contains(pid) { homeOnCourt.insert(pid) }
                if awayIDs.contains(pid) { awayOnCourt.insert(pid) }
            } else if let action = StatAction.allCases.first(where: { $0.eventCode == code }),
                      let pid = log.playerID {
                var stats = statsByPlayer[pid, default: PlayerStats()]
                action.apply(to: &stats)
                statsByPlayer[pid] = stats
                if let related = action.relatedAction,
                   let rpid = log.relatedPlayerID {
                    var relatedStats = statsByPlayer[rpid, default: PlayerStats()]
                    related.apply(to: &relatedStats)
                    statsByPlayer[rpid] = relatedStats
                }
                if action.points > 0 {
                   for p in awayOnCourt { plusMinus[p, default: 0] -= action.points }
                    for p in homeOnCourt { plusMinus[p, default: 0] += action.points }
                }
            }
        }

        let homeIDs2 = Set(currentGame.homePlayerIDs)
        let rebuiltHome = statsByPlayer.filter { homeIDs2.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        let rebuiltAway = statsByPlayer.filter { !homeIDs2.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        let storedHome = currentGame.snapshot.statsByPlayerID.filter { homeIDs2.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        let storedAway = currentGame.snapshot.statsByPlayerID.filter { !homeIDs2.contains($0.key) }.values.reduce(0) { $0 + $1.points }
        print("[SG] rebuild: rebuilt home=\(rebuiltHome) away=\(rebuiltAway) | stored home=\(storedHome) away=\(storedAway)")
        var savedGame = store.savedGames[gameIndex]
        savedGame.snapshot.statsByPlayerID = statsByPlayer
        savedGame.snapshot.playingSecondsByPlayerID = playingSeconds
        savedGame.snapshot.plusMinusByPlayerID = plusMinus
        store.savedGames[gameIndex] = savedGame
    }

    private func sanitizeSelectedPeriod() {
        guard let selectedPeriod else { return }
        if !availablePeriodOptions.contains(selectedPeriod) {
            self.selectedPeriod = nil
        }
    }

    private func resolvePlayerIDByName(_ name: String) -> UUID? {
        if let existing = game.playerNamesByID.first(where: { $0.value == name })?.key {
            return existing
        }
        return store.players.first(where: { $0.name == name })?.id
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
