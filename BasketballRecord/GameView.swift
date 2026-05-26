import SwiftUI

struct GameView: View {
    @EnvironmentObject private var store: AppStore

    @State private var snapshot = GameSnapshot()
    @State private var undoStack: [GameSnapshot] = []
    @State private var redoStack: [GameSnapshot] = []
    @State private var currentGameRecordID: UUID?
    @State private var hasRestoredLatestGame = false
    @State private var selectedPlayerID: UUID?
    @State private var selectedSide: TeamSide = .home
    @State private var isStatsExpanded = false
    @State private var isShowingSubstitution = false
    @State private var isShowingNewGameSetup = false
    @State private var isShowingUnfinishedGameAlert = false
    @State private var isShowingResetConfirmation = false
    @State private var substitutionSide: TeamSide = .home
    @State private var outgoingPlayerID: UUID?
    @State private var incomingPlayerID: UUID?
    @State private var saveConfirmation: String?
    @State private var statAlertMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                teamPickers
                    .padding(.horizontal)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    CompactTeamRow(
                        side: .home,
                        team: store.team(for: snapshot.homeTeamID),
                        players: onCourtPlayers(for: .home),
                        score: score(for: snapshot.homeTeamID),
                        fouls: displayedTeamFouls(for: .home),
                        foulLabel: snapshot.resetsTeamFoulsEachPeriod ? "本节犯规" : "累计犯规",
                        onCourtPlayerIDs: snapshot.homeOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer
                    )

                    CompactTeamRow(
                        side: .away,
                        team: store.team(for: snapshot.awayTeamID),
                        players: onCourtPlayers(for: .away),
                        score: score(for: snapshot.awayTeamID),
                        fouls: displayedTeamFouls(for: .away),
                        foulLabel: snapshot.resetsTeamFoulsEachPeriod ? "本节犯规" : "累计犯规",
                        onCourtPlayerIDs: snapshot.awayOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer
                    )
                }

                TeamStatsDisclosureView(
                    homeName: store.team(for: snapshot.homeTeamID)?.name ?? "主队",
                    awayName: store.team(for: snapshot.awayTeamID)?.name ?? "客队",
                    homeStats: aggregateStats(for: snapshot.homeTeamID),
                    awayStats: aggregateStats(for: snapshot.awayTeamID),
                    homeFouls: teamFouls(for: snapshot.homeTeamID),
                    awayFouls: teamFouls(for: snapshot.awayTeamID)
                )
                .padding(.horizontal)

                CollapsibleStatsView(
                    player: selectedPlayer,
                    stats: selectedStats,
                    plusMinus: selectedPlayerID.map { snapshot.plusMinusByPlayerID[$0, default: 0] } ?? 0,
                    playingTime: selectedPlayerID.map { playingTimeText(for: $0) } ?? "00:00",
                    isExpanded: $isStatsExpanded
                )
                    .padding(.horizontal)

                actionButtons
                    .padding(.horizontal)

                logView
                    .padding(.horizontal)
            }
            .navigationTitle("比赛记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if hasUnfinishedGameToConfirm {
                            isShowingUnfinishedGameAlert = true
                        } else {
                            isShowingNewGameSetup = true
                        }
                    } label: {
                        Label("新比赛", systemImage: "plus.circle")
                    }

                    Button {
                        saveCurrentGame()
                    } label: {
                        Label("存到历史", systemImage: "clock.badge.checkmark")
                    }
                    .disabled(snapshot.logs.isEmpty)

                    Button {
                        finishGame()
                    } label: {
                        Label("结束比赛", systemImage: "flag.checkered.circle.fill")
                    }
                    .disabled(snapshot.isComplete || snapshot.logs.isEmpty)

                    Button {
                        isShowingResetConfirmation = true
                    } label: {
                        Label("重置比赛", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewGameSetup) {
                NewGameSetupView(
                    teams: store.teams,
                    playersForTeam: players(in:),
                    initialHomeTeamID: snapshot.homeTeamID,
                    initialAwayTeamID: snapshot.awayTeamID,
                    initialPeriodCount: snapshot.periodCount,
                    initialCourtPlayerCount: snapshot.courtPlayerCount,
                    initialResetsTeamFoulsEachPeriod: snapshot.resetsTeamFoulsEachPeriod,
                    initialShowsReboundButton: snapshot.showsReboundButton,
                    initialShowsAssistButton: snapshot.showsAssistButton,
                    initialShowsFoulButton: snapshot.showsFoulButton,
                    onStart: startNewGame
                )
            }
            .sheet(isPresented: $isShowingSubstitution) {
                SubstitutionView(
                    side: $substitutionSide,
                    outgoingPlayerID: $outgoingPlayerID,
                    incomingPlayerID: $incomingPlayerID,
                    homeTeamName: store.team(for: snapshot.homeTeamID)?.name ?? "主队",
                    awayTeamName: store.team(for: snapshot.awayTeamID)?.name ?? "客队",
                    homeOnCourtPlayers: players(in: snapshot.homeTeamID).filter { snapshot.homeOnCourtPlayerIDs.contains($0.id) },
                    homeBenchPlayers: players(in: snapshot.homeTeamID).filter { !snapshot.homeOnCourtPlayerIDs.contains($0.id) },
                    awayOnCourtPlayers: players(in: snapshot.awayTeamID).filter { snapshot.awayOnCourtPlayerIDs.contains($0.id) },
                    awayBenchPlayers: players(in: snapshot.awayTeamID).filter { !snapshot.awayOnCourtPlayerIDs.contains($0.id) },
                    onConfirm: performSubstitution
                )
            }
            .alert("已保存", isPresented: Binding(
                get: { saveConfirmation != nil },
                set: { if !$0 { saveConfirmation = nil } }
            )) {
                Button("好") { saveConfirmation = nil }
            } message: {
                Text(saveConfirmation ?? "")
            }
            .alert("重置比赛数据？", isPresented: $isShowingResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认重置") { resetGame() }
            } message: {
                Text("当前比赛的得分、事件、上场时间和在场名单都会清空。")
            }
            .alert("当前比赛未结束", isPresented: $isShowingUnfinishedGameAlert) {
                Button("取消", role: .cancel) { }
                Button("结束当前比赛") {
                    finishGame()
                    isShowingNewGameSetup = true
                }
            } message: {
                Text("是否先结束当前比赛，再开始新比赛？")
            }
            .alert("无法记录统计", isPresented: Binding(
                get: { statAlertMessage != nil },
                set: { if !$0 { statAlertMessage = nil } }
            )) {
                Button("知道了") { statAlertMessage = nil }
            } message: {
                Text(statAlertMessage ?? "")
            }
            .onAppear {
                restoreLatestGameIfNeeded()
            }
            .onChange(of: store.teams) { _, _ in ensureInitialSelection() }
            .onChange(of: substitutionSide) { _, _ in prepareSubstitutionDefaults() }
        }
    }

    private var teamPickers: some View {
        HStack(spacing: 8) {
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
                .font(.caption.weight(.bold))
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

            Spacer(minLength: 0)

            Text(periodSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("2分命中", systemImage: "2.circle.fill", style: .made) { record(.twoMade) }
                actionButton("3分命中", systemImage: "3.circle.fill", style: .made) { record(.threeMade) }
                actionButton("加罚命中", systemImage: "plus.circle.fill", style: .made) { record(.bonusMade) }
                actionButton("罚篮命中", systemImage: "f.circle.fill", style: .made) { record(.freeThrowMade) }
            }

            HStack(spacing: 8) {
                actionButton("2分不中", systemImage: "2.circle", style: .missed) { record(.twoMissed) }
                actionButton("3分不中", systemImage: "3.circle", style: .missed) { record(.threeMissed) }
                actionButton("加罚不中", systemImage: "plus.circle", style: .missed) { record(.bonusMissed) }
                actionButton("罚篮不中", systemImage: "f.circle", style: .missed) { record(.freeThrowMissed) }
            }

            HStack(spacing: 8) {
                if snapshot.showsAssistButton {
                    actionButton("助攻", systemImage: "person.2.fill", style: .assist) { record(.assist) }
                }
                if snapshot.showsReboundButton {
                    actionButton("篮板", systemImage: "arrow.up.circle.fill", style: .rebound) { record(.rebound) }
                }
                if snapshot.showsFoulButton {
                    actionButton("犯规", systemImage: "exclamationmark.triangle", style: .warning) { record(.foul) }
                }

                Button {
                    openSubstitution(selectedSide)
                } label: {
                    Label("换人", systemImage: "arrow.left.arrow.right.circle")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .substitution))
                .disabled(needsNewGameSetup)
            }

            HStack(spacing: 8) {
                Button {
                    togglePeriod()
                } label: {
                    Label(periodButtonTitle, systemImage: snapshot.periodIsRunning ? "stop.circle" : "play.circle")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(snapshot.periodIsRunning ? GamePalette.periodEnd : GamePalette.period)
                .disabled(snapshot.isComplete)

                Button {
                    undo()
                } label: {
                    Label("撤回", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .disabled(undoStack.isEmpty)

                Button {
                    redo()
                } label: {
                    Label("重做", systemImage: "arrow.uturn.forward")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .disabled(redoStack.isEmpty)
            }
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("事件")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(snapshot.logs.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if snapshot.logs.isEmpty {
                ContentUnavailableView("还没有事件", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List(snapshot.logs.reversed()) { entry in
                    Text("\(Self.timeFormatter.string(from: entry.timestamp))  \(entry.message)")
                        .font(.footnote.monospacedDigit())
                        .lineLimit(2)
                        .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                }
                .listStyle(.plain)
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

    private var needsNewGameSetup: Bool {
        snapshot.homeTeamID == nil || snapshot.awayTeamID == nil || snapshot.homeOnCourtPlayerIDs.isEmpty || snapshot.awayOnCourtPlayerIDs.isEmpty
    }

    private var hasUnfinishedGameToConfirm: Bool {
        currentGameRecordID != nil && !snapshot.isComplete
    }

    private var periodSummary: String {
        if snapshot.isComplete { return "已结束" }
        return "第\(snapshot.currentPeriod)/\(snapshot.periodCount)节\(snapshot.periodIsRunning ? "中" : "")"
    }

    private var periodButtonTitle: String {
        if snapshot.isComplete { return "比赛结束" }
        return "第\(snapshot.currentPeriod)节\(snapshot.periodIsRunning ? "结束" : "开始")"
    }

    private func actionButton(_ title: String, systemImage: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(PastelActionButtonStyle(style: style))
        .disabled(needsNewGameSetup)
    }

    private func players(in teamID: UUID?) -> [Player] {
        guard let team = store.team(for: teamID) else { return [] }
        return team.playerIDs.compactMap { store.player(for: $0) }
    }

    private func onCourtPlayers(for side: TeamSide) -> [Player] {
        let ids = onCourtIDs(for: side)
        return ids.compactMap { store.player(for: $0) }
    }

    private func score(for teamID: UUID?) -> Int {
        players(in: teamID).reduce(0) { total, player in
            total + snapshot.statsByPlayerID[player.id, default: PlayerStats()].points
        }
    }

    private func teamFouls(for teamID: UUID?) -> Int {
        players(in: teamID).reduce(0) { total, player in
            total + snapshot.statsByPlayerID[player.id, default: PlayerStats()].fouls
        }
    }

    private func displayedTeamFouls(for side: TeamSide) -> Int {
        if snapshot.resetsTeamFoulsEachPeriod {
            return snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0]
        }
        return teamFouls(for: side == .home ? snapshot.homeTeamID : snapshot.awayTeamID)
    }

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        players(in: teamID).reduce(PlayerStats()) { partial, player in
            var total = partial
            let stats = snapshot.statsByPlayerID[player.id, default: PlayerStats()]
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

    private func onCourtIDs(for side: TeamSide) -> [UUID] {
        side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
    }

    private func setOnCourtIDs(_ ids: [UUID], for side: TeamSide) {
        if side == .home {
            snapshot.homeOnCourtPlayerIDs = ids
        } else {
            snapshot.awayOnCourtPlayerIDs = ids
        }
    }

    private func isOnCourt(_ playerID: UUID, side: TeamSide) -> Bool {
        onCourtIDs(for: side).contains(playerID)
    }

    private func playingSeconds(for playerID: UUID, now: Date = Date()) -> TimeInterval {
        let stored = snapshot.playingSecondsByPlayerID[playerID, default: 0]
        guard snapshot.periodIsRunning else { return stored }
        guard let activeSince = snapshot.activeSinceByPlayerID[playerID] else { return stored }
        return stored + max(0, now.timeIntervalSince(activeSince))
    }

    private func playingTimeText(for playerID: UUID) -> String {
        Self.durationFormatter(playingSeconds(for: playerID))
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
        trimInvalidLineups()
        ensureSelectedPlayer()
    }

    private func ensureDefaultLineups() {
        let homeIDs = players(in: snapshot.homeTeamID).map(\.id)
        let awayIDs = players(in: snapshot.awayTeamID).map(\.id)

        snapshot.homeOnCourtPlayerIDs = snapshot.homeOnCourtPlayerIDs.filter { homeIDs.contains($0) }
        snapshot.awayOnCourtPlayerIDs = snapshot.awayOnCourtPlayerIDs.filter { awayIDs.contains($0) }

        if snapshot.homeOnCourtPlayerIDs.isEmpty {
            snapshot.homeOnCourtPlayerIDs = Array(homeIDs.prefix(snapshot.courtPlayerCount))
        }
        if snapshot.awayOnCourtPlayerIDs.isEmpty {
            snapshot.awayOnCourtPlayerIDs = Array(awayIDs.prefix(snapshot.courtPlayerCount))
        }

        if snapshot.homeOnCourtPlayerIDs.count < snapshot.courtPlayerCount {
            let bench = homeIDs.filter { !snapshot.homeOnCourtPlayerIDs.contains($0) }
            snapshot.homeOnCourtPlayerIDs.append(contentsOf: bench.prefix(snapshot.courtPlayerCount - snapshot.homeOnCourtPlayerIDs.count))
        }
        if snapshot.awayOnCourtPlayerIDs.count < snapshot.courtPlayerCount {
            let bench = awayIDs.filter { !snapshot.awayOnCourtPlayerIDs.contains($0) }
            snapshot.awayOnCourtPlayerIDs.append(contentsOf: bench.prefix(snapshot.courtPlayerCount - snapshot.awayOnCourtPlayerIDs.count))
        }

        snapshot.homeOnCourtPlayerIDs = Array(snapshot.homeOnCourtPlayerIDs.prefix(snapshot.courtPlayerCount))
        snapshot.awayOnCourtPlayerIDs = Array(snapshot.awayOnCourtPlayerIDs.prefix(snapshot.courtPlayerCount))
    }

    private func trimInvalidLineups() {
        let homeIDs = players(in: snapshot.homeTeamID).map(\.id)
        let awayIDs = players(in: snapshot.awayTeamID).map(\.id)
        snapshot.homeOnCourtPlayerIDs = Array(snapshot.homeOnCourtPlayerIDs.filter { homeIDs.contains($0) }.prefix(snapshot.courtPlayerCount))
        snapshot.awayOnCourtPlayerIDs = Array(snapshot.awayOnCourtPlayerIDs.filter { awayIDs.contains($0) }.prefix(snapshot.courtPlayerCount))
    }

    private func ensureSelectedPlayer() {
        let currentPlayers = onCourtPlayers(for: selectedSide)
        if let selectedPlayerID, currentPlayers.contains(where: { $0.id == selectedPlayerID }) {
            return
        }

        if let firstHome = onCourtPlayers(for: .home).first {
            selectPlayer(firstHome, .home)
        } else if let firstAway = onCourtPlayers(for: .away).first {
            selectPlayer(firstAway, .away)
        } else {
            selectedPlayerID = nil
        }
    }

    private func record(_ action: StatAction) {
        guard !snapshot.isComplete else {
            statAlertMessage = "比赛已结束"
            return
        }
        guard snapshot.periodIsRunning else {
            statAlertMessage = "第\(snapshot.currentPeriod)节比赛未开始"
            return
        }
        guard let player = selectedPlayer else {
            statAlertMessage = "请先选择球员"
            return
        }
        guard isOnCourt(player.id, side: selectedSide) else { return }
        mutateSnapshot {
            var stats = snapshot.statsByPlayerID[player.id, default: PlayerStats()]
            action.apply(to: &stats)
            snapshot.statsByPlayerID[player.id] = stats
            if action == .foul {
                snapshot.currentPeriodFoulsBySide[selectedSide.rawValue, default: 0] += 1
            }
            if action.points > 0 {
                applyPlusMinus(points: action.points, scoringSide: selectedSide)
            }
            addEvent("\(player.name) \(action.message)")
        }
    }

    private func togglePeriod() {
        guard !needsNewGameSetup else {
            isShowingNewGameSetup = true
            return
        }
        let now = Date()
        mutateSnapshot {
            if snapshot.periodIsRunning {
                closeActiveStints(at: now)
                addEvent("第\(snapshot.currentPeriod)节结束")
                snapshot.periodIsRunning = false
                if snapshot.currentPeriod >= snapshot.periodCount {
                    snapshot.isComplete = true
                    addEvent("比赛结束")
                } else {
                    snapshot.currentPeriod += 1
                }
            } else {
                trimInvalidLineups()
                if snapshot.resetsTeamFoulsEachPeriod {
                    snapshot.currentPeriodFoulsBySide[TeamSide.home.rawValue] = 0
                    snapshot.currentPeriodFoulsBySide[TeamSide.away.rawValue] = 0
                }
                if !snapshot.startersRecorded {
                    addEvent("主队首发：\(names(for: snapshot.homeOnCourtPlayerIDs))")
                    addEvent("客队首发：\(names(for: snapshot.awayOnCourtPlayerIDs))")
                    snapshot.startersRecorded = true
                }
                addEvent("第\(snapshot.currentPeriod)节开始")
                startActiveStints(at: now)
                snapshot.periodIsRunning = true
            }
        }
    }

    private func startNewGame(
        homeTeamID: UUID,
        awayTeamID: UUID,
        homeStarterIDs: [UUID],
        awayStarterIDs: [UUID],
        periodCount: Int,
        courtPlayerCount: Int,
        resetsTeamFoulsEachPeriod: Bool,
        showsReboundButton: Bool,
        showsAssistButton: Bool,
        showsFoulButton: Bool
    ) {
        undoStack.removeAll()
        redoStack.removeAll()
        currentGameRecordID = UUID()
        snapshot = GameSnapshot(
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            periodCount: periodCount,
            courtPlayerCount: courtPlayerCount,
            resetsTeamFoulsEachPeriod: resetsTeamFoulsEachPeriod,
            showsReboundButton: showsReboundButton,
            showsAssistButton: showsAssistButton,
            showsFoulButton: showsFoulButton,
            homeOnCourtPlayerIDs: homeStarterIDs,
            awayOnCourtPlayerIDs: awayStarterIDs
        )
        selectedPlayerID = nil
        selectedSide = .home
        ensureSelectedPlayer()
        autoSaveCurrentGame()
    }

    private func saveCurrentGame() {
        var snapshotForSaving = snapshot
        closeActiveStints(in: &snapshotForSaving, at: Date())
        snapshotForSaving.periodIsRunning = false
        mutateSnapshot(pushUndo: false) {
            addEvent("比赛保存")
        }
        snapshotForSaving.logs = snapshot.logs
        currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: undoStack)
        saveConfirmation = "比赛已保存到历史记录。"
    }

    private func finishGame() {
        guard !snapshot.isComplete else { return }
        let now = Date()
        mutateSnapshot {
            if snapshot.periodIsRunning {
                closeActiveStints(at: now)
                snapshot.periodIsRunning = false
            }
            snapshot.isComplete = true
            addEvent("比赛结束")
        }
    }

    private func prepareSubstitutionDefaults() {
        let onCourt = substitutionSide == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
        let bench = players(in: substitutionSide == .home ? snapshot.homeTeamID : snapshot.awayTeamID).map(\.id).filter { !onCourt.contains($0) }
        outgoingPlayerID = onCourt.first
        incomingPlayerID = bench.first
    }

    private func openSubstitution(_ side: TeamSide) {
        substitutionSide = side
        prepareSubstitutionDefaults()
        isShowingSubstitution = true
    }

    private func performSubstitution() {
        guard let outgoingPlayerID,
              let incomingPlayerID,
              outgoingPlayerID != incomingPlayerID else { return }

        let now = Date()
        mutateSnapshot {
            var ids = onCourtIDs(for: substitutionSide)
            ids.removeAll { $0 == outgoingPlayerID }
            if !ids.contains(incomingPlayerID) {
                ids.append(incomingPlayerID)
            }
            setOnCourtIDs(ids, for: substitutionSide)

            if snapshot.periodIsRunning {
                closeStint(for: outgoingPlayerID, at: now)
                startStint(for: incomingPlayerID, at: now)
            }

            addEvent("\(name(for: incomingPlayerID)) 替换 \(name(for: outgoingPlayerID))")
            selectedPlayerID = incomingPlayerID
            selectedSide = substitutionSide
        }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(snapshot)
        snapshot = previous
        ensureSelectedPlayer()
        autoSaveCurrentGame()
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        snapshot = next
        ensureSelectedPlayer()
        autoSaveCurrentGame()
    }

    private func resetGame() {
        undoStack.removeAll()
        redoStack.removeAll()
        currentGameRecordID = nil
        snapshot = GameSnapshot(
            homeTeamID: snapshot.homeTeamID,
            awayTeamID: snapshot.awayTeamID,
            periodCount: snapshot.periodCount,
            courtPlayerCount: snapshot.courtPlayerCount,
            resetsTeamFoulsEachPeriod: snapshot.resetsTeamFoulsEachPeriod,
            showsReboundButton: snapshot.showsReboundButton,
            showsAssistButton: snapshot.showsAssistButton,
            showsFoulButton: snapshot.showsFoulButton
        )
        isStatsExpanded = false
        ensureSelectedPlayer()
    }

    private func mutateSnapshot(pushUndo: Bool = true, _ updates: () -> Void) {
        if pushUndo { undoStack.append(snapshot) }
        redoStack.removeAll()
        updates()
        autoSaveCurrentGame()
    }

    private func addEvent(_ message: String) {
        snapshot.logs.append(GameLogEntry(timestamp: Date(), message: message))
    }

    private func autoSaveCurrentGame() {
        guard !snapshot.logs.isEmpty else { return }
        currentGameRecordID = store.autoSaveGame(snapshot, gameID: currentGameRecordID, undoSnapshots: undoStack)
    }

    private func restoreLatestGameIfNeeded() {
        guard !hasRestoredLatestGame else { return }
        hasRestoredLatestGame = true

        if let latest = store.latestUnfinishedGame() {
            snapshot = latest.snapshot
            if !latest.undoSnapshots.isEmpty {
                undoStack = latest.undoSnapshots
            } else if let previous = latest.previousSnapshot ?? legacyPreviousSnapshot(from: latest.snapshot) {
                undoStack = [previous]
            } else {
                undoStack = []
            }
            redoStack.removeAll()
            currentGameRecordID = latest.id
            ensureSelectedPlayer()
            return
        }

        ensureInitialSelection()
    }

    private func startActiveStints(at date: Date) {
        (snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs).forEach { playerID in
            startStint(for: playerID, at: date)
        }
    }

    private func startStint(for playerID: UUID, at date: Date) {
        if snapshot.activeSinceByPlayerID[playerID] == nil {
            snapshot.activeSinceByPlayerID[playerID] = date
        }
    }

    private func closeActiveStints(at date: Date) {
        closeActiveStints(in: &snapshot, at: date)
    }

    private func closeActiveStints(in target: inout GameSnapshot, at date: Date) {
        for (playerID, startedAt) in target.activeSinceByPlayerID {
            target.playingSecondsByPlayerID[playerID, default: 0] += max(0, date.timeIntervalSince(startedAt))
        }
        target.activeSinceByPlayerID.removeAll()
    }

    private func closeStint(for playerID: UUID, at date: Date) {
        guard let startedAt = snapshot.activeSinceByPlayerID[playerID] else { return }
        snapshot.playingSecondsByPlayerID[playerID, default: 0] += max(0, date.timeIntervalSince(startedAt))
        snapshot.activeSinceByPlayerID[playerID] = nil
    }

    private func applyPlusMinus(points: Int, scoringSide: TeamSide) {
        applyPlusMinus(points: points, scoringSide: scoringSide, in: &snapshot)
    }

    private func applyPlusMinus(points: Int, scoringSide: TeamSide, in target: inout GameSnapshot) {
        let scoringIDs = scoringSide == .home ? target.homeOnCourtPlayerIDs : target.awayOnCourtPlayerIDs
        let defendingIDs = scoringSide == .home ? target.awayOnCourtPlayerIDs : target.homeOnCourtPlayerIDs
        scoringIDs.forEach { target.plusMinusByPlayerID[$0, default: 0] += points }
        defendingIDs.forEach { target.plusMinusByPlayerID[$0, default: 0] -= points }
    }

    private func legacyPreviousSnapshot(from current: GameSnapshot) -> GameSnapshot? {
        guard let lastLog = current.logs.last else { return nil }

        var previous = current
        previous.logs.removeLast()

        if lastLog.message == "比赛保存" {
            return previous
        }

        if lastLog.message == "比赛结束" {
            previous.isComplete = false
            return previous
        }

        guard let (playerName, action) = StatAction.parseLog(lastLog.message) else {
            return nil
        }

        guard let playerID = playerID(for: playerName, action: action, in: current),
              let side = sideOfPlayer(playerID, in: current) else {
            return nil
        }

        var stats = previous.statsByPlayerID[playerID, default: PlayerStats()]
        guard action.revert(on: &stats) else { return nil }
        previous.statsByPlayerID[playerID] = stats

        if action == .foul {
            let currentFouls = previous.currentPeriodFoulsBySide[side.rawValue, default: 0]
            previous.currentPeriodFoulsBySide[side.rawValue] = max(0, currentFouls - 1)
        }

        if action.points > 0 {
            applyPlusMinus(points: -action.points, scoringSide: side, in: &previous)
        }

        return previous
    }

    private func playerID(for playerName: String, action: StatAction, in current: GameSnapshot) -> UUID? {
        let homeIDs = players(in: current.homeTeamID).map(\.id)
        let awayIDs = players(in: current.awayTeamID).map(\.id)
        let allIDs = Array(Set(homeIDs + awayIDs + Array(current.statsByPlayerID.keys)))

        let matchedByName = allIDs.filter { store.player(for: $0)?.name == playerName }
        guard !matchedByName.isEmpty else { return nil }

        if let precise = matchedByName.first(where: { canRevert(action: action, for: $0, in: current) }) {
            return precise
        }

        return matchedByName.first
    }

    private func canRevert(action: StatAction, for playerID: UUID, in current: GameSnapshot) -> Bool {
        var stats = current.statsByPlayerID[playerID, default: PlayerStats()]
        return action.revert(on: &stats)
    }

    private func sideOfPlayer(_ playerID: UUID, in current: GameSnapshot) -> TeamSide? {
        let homeIDs = Set(players(in: current.homeTeamID).map(\.id))
        let awayIDs = Set(players(in: current.awayTeamID).map(\.id))
        if homeIDs.contains(playerID) { return .home }
        if awayIDs.contains(playerID) { return .away }
        return nil
    }

    private func name(for playerID: UUID) -> String {
        store.player(for: playerID)?.name ?? "未知球员"
    }

    private func names(for playerIDs: [UUID]) -> String {
        let text = playerIDs.map { name(for: $0) }.joined(separator: "、")
        return text.isEmpty ? "未设置" : text
    }

    static func durationFormatter(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

enum TeamSide: String {
    case home = "主队"
    case away = "客队"
}

extension TeamSide: CaseIterable, Identifiable {
    var id: String { rawValue }
}

private enum GamePalette {
    static let make = Color(red: 0.78, green: 0.93, blue: 0.78)
    static let miss = Color(red: 0.86, green: 0.92, blue: 0.98)
    static let assist = Color(red: 0.74, green: 0.86, blue: 0.98)
    static let rebound = Color(red: 0.80, green: 0.90, blue: 0.99)
    static let warning = Color(red: 0.96, green: 0.80, blue: 0.80)
    static let period = Color(red: 0.36, green: 0.63, blue: 0.95)
    static let periodEnd = Color(red: 0.52, green: 0.72, blue: 0.95)
    static let substitution = Color(red: 0.42, green: 0.67, blue: 0.95)
    static let surface = Color(red: 0.96, green: 0.98, blue: 1.00)
    static let selectedBorder = Color(red: 0.25, green: 0.55, blue: 0.90)
    static let onCourtBorder = Color(red: 0.45, green: 0.69, blue: 0.93)
    static let text = Color(red: 0.18, green: 0.20, blue: 0.22)
}

private enum ActionButtonStyle {
    case made, missed, assist, rebound, warning, substitution

    var background: Color {
        switch self {
        case .made: return GamePalette.make
        case .missed: return GamePalette.miss
        case .assist: return GamePalette.assist
        case .rebound: return GamePalette.rebound
        case .warning: return GamePalette.warning
        case .substitution: return GamePalette.substitution
        }
    }

    var foreground: Color { GamePalette.text }
}

private struct PastelActionButtonStyle: ButtonStyle {
    var style: ActionButtonStyle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(style.foreground)
            .background(style.background.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
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

    var points: Int {
        switch self {
        case .twoMade: return 2
        case .threeMade: return 3
        case .bonusMade, .freeThrowMade: return 1
        default: return 0
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

    func revert(on stats: inout PlayerStats) -> Bool {
        switch self {
        case .twoMade:
            guard stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.twoMade -= 1
            stats.twoAttempts -= 1
        case .twoMissed:
            guard stats.twoAttempts > 0 else { return false }
            stats.twoAttempts -= 1
        case .threeMade:
            guard stats.threeMade > 0, stats.threeAttempts > 0 else { return false }
            stats.threeMade -= 1
            stats.threeAttempts -= 1
        case .threeMissed:
            guard stats.threeAttempts > 0 else { return false }
            stats.threeAttempts -= 1
        case .bonusMade:
            guard stats.bonusFreeThrowMade > 0, stats.bonusFreeThrowAttempts > 0 else { return false }
            stats.bonusFreeThrowMade -= 1
            stats.bonusFreeThrowAttempts -= 1
        case .bonusMissed:
            guard stats.bonusFreeThrowAttempts > 0 else { return false }
            stats.bonusFreeThrowAttempts -= 1
        case .freeThrowMade:
            guard stats.freeThrowMade > 0, stats.freeThrowAttempts > 0 else { return false }
            stats.freeThrowMade -= 1
            stats.freeThrowAttempts -= 1
        case .freeThrowMissed:
            guard stats.freeThrowAttempts > 0 else { return false }
            stats.freeThrowAttempts -= 1
        case .foul:
            guard stats.fouls > 0 else { return false }
            stats.fouls -= 1
        case .assist:
            guard stats.assists > 0 else { return false }
            stats.assists -= 1
        case .rebound:
            guard stats.rebounds > 0 else { return false }
            stats.rebounds -= 1
        }
        return true
    }

    static func parseLog(_ message: String) -> (playerName: String, action: StatAction)? {
        for action in allCases {
            guard message.hasSuffix(action.message) else { continue }
            let name = String(message.dropLast(action.message.count)).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return (name, action)
        }
        return nil
    }
}

extension StatAction: Equatable {}

extension StatAction: CaseIterable {
    static var allCases: [StatAction] {
        [.twoMade, .twoMissed, .threeMade, .threeMissed, .bonusMade, .bonusMissed, .freeThrowMade, .freeThrowMissed, .foul, .assist, .rebound]
    }
}

private struct CompactTeamRow: View {
    var side: TeamSide
    var team: Team?
    var players: [Player]
    var score: Int
    var fouls: Int
    var foulLabel: String
    var onCourtPlayerIDs: [UUID]
    var selectedPlayerID: UUID?
    var selectedSide: TeamSide
    var onSelect: (Player, TeamSide) -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(team?.name ?? side.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(score)")
                        .font(.title.monospacedDigit().weight(.bold))
                        .foregroundStyle(GamePalette.text)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(foulLabel)
                            .font(.caption2)
                        Text("\(fouls)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, alignment: .leading)

            if players.isEmpty {
                Text("无球员")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(players) { player in
                            let isSelected = selectedPlayerID == player.id && selectedSide == side
                            let avatarSize: CGFloat = isSelected ? 52 : 42

                            Button {
                                onSelect(player, side)
                            } label: {
                                VStack(spacing: 3) {
                                    ZStack(alignment: .bottomTrailing) {
                                        PlayerAvatarView(player: player, size: avatarSize)
                                            .overlay {
                                                if onCourtPlayerIDs.contains(player.id) {
                                                    Circle().stroke(GamePalette.onCourtBorder, lineWidth: 2)
                                                }
                                                if isSelected {
                                                    Circle().stroke(GamePalette.selectedBorder, lineWidth: 3)
                                                }
                                            }
                                            .animation(.easeInOut(duration: 0.15), value: isSelected)

                                        if onCourtPlayerIDs.contains(player.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white, GamePalette.make)
                                                .background(Circle().fill(.white))
                                        }
                                    }
                                    Text(player.name)
                                        .font(.caption2)
                                        .foregroundStyle(onCourtPlayerIDs.contains(player.id) ? .primary : .secondary)
                                        .lineLimit(1)
                                        .frame(width: 56)
                                }
                                .opacity(isSelected ? 1 : 0.6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 7)
                    .padding(.trailing, 8)
                }
            }
        }
        .frame(height: 78)
        .padding(.horizontal, 12)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.85), lineWidth: 1))
        .padding(.horizontal)
    }
}

struct TeamStatsDisclosureView: View {
    var homeName: String
    var awayName: String
    var homeStats: PlayerStats
    var awayStats: PlayerStats
    var homeFouls: Int
    var awayFouls: Int

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                teamRow(homeName, stats: homeStats, fouls: homeFouls)
                teamRow(awayName, stats: awayStats, fouls: awayFouls)
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("球队数据")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(homeStats.points)-\(awayStats.points)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.85), lineWidth: 1))
    }

    private func teamRow(_ name: String, stats: PlayerStats, fouls: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(stats.points)分")
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            HStack(spacing: 8) {
                statTile("投篮", "\(stats.made)/\(stats.attempts)", percent(stats.fieldGoalRate))
                statTile("罚篮", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)", percent(stats.freeThrowRate))
                statTile("篮板 / 助攻 / 犯规", "\(stats.rebounds) / \(stats.assists) / \(fouls)", "")
            }
            HStack(spacing: 8) {
                statTile("高阶", "eFG \(percent(stats.effectiveFieldGoalRate))", "TS \(percent(stats.trueShootingRate))")
                statTile("每次出手得分", String(format: "%.2f", stats.pointsPerShot), "PTS/FGA")
                statTile("3分", "\(stats.threeMade)/\(stats.threeAttempts)", percent(stats.threePointRate))
            }
        }
        .padding(8)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statTile(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct CollapsibleStatsView: View {
    var player: Player?
    var stats: PlayerStats
    var plusMinus: Int
    var playingTime: String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    statTile("投篮", "\(stats.made)/\(stats.attempts)", percent(stats.fieldGoalRate))
                    statTile("2分", "\(stats.twoMade)/\(stats.twoAttempts)", percent(stats.twoPointRate))
                    statTile("3分", "\(stats.threeMade)/\(stats.threeAttempts)", percent(stats.threePointRate))
                }

                HStack(spacing: 8) {
                    statTile("罚篮", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)", percent(stats.freeThrowRate))
                    statTile("篮板 / 助攻 / 犯规", "\(stats.rebounds) / \(stats.assists) / \(stats.fouls)", "")
                    statTile("高阶", "eFG \(percent(stats.effectiveFieldGoalRate))", "TS \(percent(stats.trueShootingRate))")
                }

                HStack(spacing: 8) {
                    statTile("每次出手得分", pointsPerShotText, "PTS/FGA")
                    statTile("正负值", plusMinusText, "在场净胜分")
                    statTile("上场时间", playingTime, "")
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Text(player?.name ?? "选择球员")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(stats.points)分")
                Text(playingTime)
                Text("板\(stats.rebounds)")
                Text("助\(stats.assists)")
                Text("犯\(stats.fouls)")
            }
            .font(.caption.monospacedDigit())
        }
        .padding(10)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.85), lineWidth: 1))
    }

    private func statTile(_ title: String, _ value: String, _ detail: String, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var plusMinusText: String {
        plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
    }

    private var pointsPerShotText: String {
        String(format: "%.2f", stats.pointsPerShot)
    }
}

private struct NewGameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var teams: [Team]
    var playersForTeam: (UUID?) -> [Player]
    var initialHomeTeamID: UUID?
    var initialAwayTeamID: UUID?
    var initialPeriodCount: Int
    var initialCourtPlayerCount: Int
    var initialResetsTeamFoulsEachPeriod: Bool
    var initialShowsReboundButton: Bool
    var initialShowsAssistButton: Bool
    var initialShowsFoulButton: Bool
    var onStart: (UUID, UUID, [UUID], [UUID], Int, Int, Bool, Bool, Bool, Bool) -> Void

    @State private var homeTeamID: UUID?
    @State private var awayTeamID: UUID?
    @State private var homeStarterIDs: [UUID] = []
    @State private var awayStarterIDs: [UUID] = []
    @State private var periodCount = 4
    @State private var courtPlayerCount = 4
    @State private var resetsTeamFoulsEachPeriod = true
    @State private var showsReboundButton = true
    @State private var showsAssistButton = true
    @State private var showsFoulButton = true

    var body: some View {
        NavigationStack {
            Form {
                Section("球队") {
                    Picker("主队", selection: $homeTeamID) {
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                    Picker("客队", selection: $awayTeamID) {
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                }

                Section("比赛设定") {
                    Stepper(value: $periodCount, in: 1...8) {
                        HStack {
                            Text("比赛节数")
                            Spacer()
                            Text("\(periodCount)节")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $courtPlayerCount, in: 1...8) {
                        HStack {
                            Text("首发人数")
                            Spacer()
                            Text("\(courtPlayerCount)人")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("每节球队犯规清零", isOn: $resetsTeamFoulsEachPeriod)
                }

                Section("计分按钮") {
                    Toggle("篮板", isOn: $showsReboundButton)
                    Toggle("助攻", isOn: $showsAssistButton)
                    Toggle("犯规", isOn: $showsFoulButton)
                }

                starterSection(title: "主队首发", players: homePlayers, selectedIDs: $homeStarterIDs, requiredCount: requiredHomeCount)
                starterSection(title: "客队首发", players: awayPlayers, selectedIDs: $awayStarterIDs, requiredCount: requiredAwayCount)
            }
            .navigationTitle("新比赛")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始") {
                        guard let homeTeamID, let awayTeamID else { return }
                        onStart(
                            homeTeamID,
                            awayTeamID,
                            homeStarterIDs,
                            awayStarterIDs,
                            periodCount,
                            courtPlayerCount,
                            resetsTeamFoulsEachPeriod,
                            showsReboundButton,
                            showsAssistButton,
                            showsFoulButton
                        )
                        dismiss()
                    }
                    .disabled(!canStart)
                }
            }
            .onAppear(perform: prepareDefaults)
            .onChange(of: homeTeamID) { _, _ in syncStarterSelections() }
            .onChange(of: awayTeamID) { _, _ in syncStarterSelections() }
            .onChange(of: courtPlayerCount) { _, _ in syncStarterSelections() }
        }
    }

    private var homePlayers: [Player] { playersForTeam(homeTeamID) }
    private var awayPlayers: [Player] { playersForTeam(awayTeamID) }
    private var requiredHomeCount: Int { min(courtPlayerCount, homePlayers.count) }
    private var requiredAwayCount: Int { min(courtPlayerCount, awayPlayers.count) }

    private var canStart: Bool {
        homeTeamID != nil && awayTeamID != nil && homeTeamID != awayTeamID && homeStarterIDs.count == requiredHomeCount && awayStarterIDs.count == requiredAwayCount && requiredHomeCount > 0 && requiredAwayCount > 0
    }

    private func starterSection(title: String, players: [Player], selectedIDs: Binding<[UUID]>, requiredCount: Int) -> some View {
        Section("\(title) · 选择 \(requiredCount) 人") {
            if players.isEmpty {
                Text("这支球队还没有球员")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            SelectablePlayerAvatarButton(
                                player: player,
                                isSelected: selectedIDs.wrappedValue.contains(player.id),
                                badge: selectedIDs.wrappedValue.contains(player.id) ? "首发" : nil
                            ) {
                                toggle(player.id, in: selectedIDs, limit: requiredCount)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func prepareDefaults() {
        homeTeamID = initialHomeTeamID ?? teams.first?.id
        awayTeamID = initialAwayTeamID ?? teams.dropFirst().first?.id
        periodCount = min(max(initialPeriodCount, 1), 8)
        courtPlayerCount = min(max(initialCourtPlayerCount, 1), 8)
        resetsTeamFoulsEachPeriod = initialResetsTeamFoulsEachPeriod
        showsReboundButton = initialShowsReboundButton
        showsAssistButton = initialShowsAssistButton
        showsFoulButton = initialShowsFoulButton
        if awayTeamID == homeTeamID {
            awayTeamID = teams.first(where: { $0.id != homeTeamID })?.id
        }
        syncStarterSelections()
    }

    private func toggle(_ id: UUID, in selectedIDs: Binding<[UUID]>, limit: Int) {
        if selectedIDs.wrappedValue.contains(id) {
            selectedIDs.wrappedValue.removeAll { $0 == id }
        } else if selectedIDs.wrappedValue.count < limit {
            selectedIDs.wrappedValue.append(id)
        }
    }

    private func syncStarterSelections() {
        let homePlayerIDs = homePlayers.map(\.id)
        let awayPlayerIDs = awayPlayers.map(\.id)

        homeStarterIDs = Array(homeStarterIDs.filter { homePlayerIDs.contains($0) }.prefix(requiredHomeCount))
        awayStarterIDs = Array(awayStarterIDs.filter { awayPlayerIDs.contains($0) }.prefix(requiredAwayCount))

        if homeStarterIDs.count < requiredHomeCount {
            let candidates = homePlayerIDs.filter { !homeStarterIDs.contains($0) }
            homeStarterIDs.append(contentsOf: candidates.prefix(requiredHomeCount - homeStarterIDs.count))
        }
        if awayStarterIDs.count < requiredAwayCount {
            let candidates = awayPlayerIDs.filter { !awayStarterIDs.contains($0) }
            awayStarterIDs.append(contentsOf: candidates.prefix(requiredAwayCount - awayStarterIDs.count))
        }
    }
}

private struct SubstitutionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var side: TeamSide
    @Binding var outgoingPlayerID: UUID?
    @Binding var incomingPlayerID: UUID?

    var homeTeamName: String
    var awayTeamName: String
    var homeOnCourtPlayers: [Player]
    var homeBenchPlayers: [Player]
    var awayOnCourtPlayers: [Player]
    var awayBenchPlayers: [Player]
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("球队", selection: $side) {
                        Text(homeTeamName).tag(TeamSide.home)
                        Text(awayTeamName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("换下", selectedName(for: outgoingPlayerID))
                    if onCourtPlayers.isEmpty {
                        Text("没有已标记在场的球员")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(onCourtPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: outgoingPlayerID == player.id,
                                        badge: outgoingPlayerID == player.id ? "换下" : nil
                                    ) {
                                        outgoingPlayerID = player.id
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("换上", selectedName(for: incomingPlayerID))
                    if benchPlayers.isEmpty {
                        Text("没有可换上的替补球员")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(benchPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: incomingPlayerID == player.id,
                                        badge: incomingPlayerID == player.id ? "换上" : nil
                                    ) {
                                        incomingPlayerID = player.id
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("换人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("记录") {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(outgoingPlayerID == nil || incomingPlayerID == nil || outgoingPlayerID == incomingPlayerID)
                }
            }
        }
    }

    private var onCourtPlayers: [Player] {
        side == .home ? homeOnCourtPlayers : awayOnCourtPlayers
    }

    private var benchPlayers: [Player] {
        side == .home ? homeBenchPlayers : awayBenchPlayers
    }

    private func selectedName(for id: UUID?) -> String {
        guard let id else { return "未选择" }
        return (onCourtPlayers + benchPlayers).first(where: { $0.id == id })?.name ?? "未选择"
    }

    private func sectionHeader(_ title: String, _ detail: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SelectablePlayerAvatarButton: View {
    var player: Player
    var isSelected: Bool
    var badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .bottom) {
                    PlayerAvatarView(player: player, size: 58)
                        .overlay {
                            Circle().stroke(isSelected ? GamePalette.selectedBorder : Color.white.opacity(0.9), lineWidth: isSelected ? 3 : 1)
                        }
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(GamePalette.make, in: Capsule())
                            .offset(y: 8)
                    }
                }
                Text(player.name)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: 64)
            }
            .foregroundStyle(GamePalette.text)
        }
        .buttonStyle(.plain)
    }
}
