import SwiftUI
import UIKit
import MultipeerConnectivity
import CryptoKit

struct GameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager

    @State private var snapshot = GameSnapshot()
    @State private var undoStack: [GameSnapshot] = []
    @State private var redoStack: [GameSnapshot] = []
    @State private var currentGameRecordID: UUID?
    @State private var hasRestoredLatestGame = false
    @State private var selectedPlayerID: UUID?
    @State private var selectedSide: TeamSide = .home
    @State private var isShowingSubstitution = false
    @State private var isShowingLateArrival = false
    @State private var isShowingNewGameSetup = false
    @State private var isShowingUnfinishedGameAlert = false
    @State private var isShowingSimulateConfirmation = false
    @State private var isShowingFinishGameConfirmation = false
    @State private var isShowingResetConfirmation = false
    @State private var substitutionSide: TeamSide = .home
    @State private var lateArrivalSide: TeamSide = .home
    @State private var outgoingPlayerID: UUID?
    @State private var incomingPlayerID: UUID?
    @State private var lateArrivalIncomingPlayerID: UUID?
    @State private var saveConfirmation: String?
    @State private var statAlertMessage: String?
    @State private var simulationAlertMessage: String?
    @State private var collaborationAlertMessage: String?
    @State private var isSimulating = false
    @State private var activeLiveSessionID: UUID?
    @State private var liveRole: LiveCollaborationRole?
    @State private var liveVersion = 0
    @State private var liveStateHash = ""
    @State private var liveHostPeerName: String?
    @State private var liveHostPeerID: MCPeerID?
    @State private var liveParticipantNames: Set<String> = []
    @State private var localLiveOpSeq = 0
    @State private var liveCommitHistory: [BluetoothLiveOpCommitPayload] = []
    @State private var peerAckVersionByDeviceID: [String: Int] = [:]
    @State private var isApplyingRemoteSnapshot = false
    @State private var clockNow = Date()
    @State private var scorePulseSide: TeamSide?
    @State private var scorePulseDismissTask: Task<Void, Never>?
    @State private var actionButtonPulseKey: String?
    @State private var actionButtonPulseDismissTask: Task<Void, Never>?
    @State private var recordingIndicatorBlink = false
    @State private var highlightedLogID: UUID?
    @State private var highlightedLogDismissTask: Task<Void, Never>?

    private let matchClockTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        lifecycleWrappedView
    }

    private var navigationRoot: some View {
        NavigationStack {
            gameLayout
                .overlay(alignment: .center) {
                    simulationLoadingView
                }
                .allowsHitTesting(!isSimulating)
                .navigationTitle(LocalizedStringKey("nav_game"))
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
                            Label(LocalizedStringKey("button_new_game"), systemImage: "plus.circle")
                        }

                        Button {
                            handleInviteSyncTapped()
                        } label: {
                            Label(LocalizedStringKey("button_invite_collab"), systemImage: "dot.radiowaves.left.and.right")
                        }
                        .disabled(currentGameRecordID == nil || needsNewGameSetup || bluetooth.connectedPeers.isEmpty)

                        if store.showsSimulationButton {
                            Button {
                                handleSimulateTapped()
                            } label: {
                                Label(LocalizedStringKey("button_simulate"), systemImage: "sparkles")
                            }
                            .disabled(isSimulating)
                        }

                        Button {
                            saveCurrentGame()
                        } label: {
                            Label(LocalizedStringKey("button_save_history"), systemImage: "clock.badge.checkmark")
                        }
                        .disabled(snapshot.logs.isEmpty)
                    }
                }
        }
    }

    private var sheetWrappedView: some View {
        navigationRoot
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
                    initialShowsBlockButton: snapshot.showsBlockButton,
                    initialShowsStealButton: snapshot.showsStealButton,
                    initialShowsTurnoverButton: snapshot.showsTurnoverButton,
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
                    homeBenchPlayers: benchPlayers(for: .home),
                    awayOnCourtPlayers: players(in: snapshot.awayTeamID).filter { snapshot.awayOnCourtPlayerIDs.contains($0.id) },
                    awayBenchPlayers: benchPlayers(for: .away),
                    onConfirm: performSubstitution
                )
            }
            .sheet(isPresented: $isShowingLateArrival) {
                LateArrivalEntryView(
                    side: $lateArrivalSide,
                    incomingPlayerID: $lateArrivalIncomingPlayerID,
                    homeTeamName: store.team(for: snapshot.homeTeamID)?.name ?? "主队",
                    awayTeamName: store.team(for: snapshot.awayTeamID)?.name ?? "客队",
                    homeUnregisteredPlayers: unregisteredPlayers(for: .home),
                    awayUnregisteredPlayers: unregisteredPlayers(for: .away),
                    onConfirm: performLateArrival
                )
            }
    }

    private var alertWrappedView: some View {
        sheetWrappedView
            .alert(LocalizedStringKey("alert_saved"), isPresented: Binding(
                get: { saveConfirmation != nil },
                set: { if !$0 { saveConfirmation = nil } }
            )) {
                Button(LocalizedStringKey("button_ok")) { saveConfirmation = nil }
            } message: {
                Text(saveConfirmation ?? "")
            }
            .alert(LocalizedStringKey("alert_reset_game_title"), isPresented: $isShowingResetConfirmation) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_confirm_reset")) { resetGame() }
            } message: {
                Text(LocalizedStringKey("alert_reset_game_message"))
            }
            .alert(LocalizedStringKey("alert_unfinished_game_title"), isPresented: $isShowingUnfinishedGameAlert) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_end_current_game")) {
                    finishGame()
                    isShowingNewGameSetup = true
                }
            } message: {
                Text(LocalizedStringKey("alert_unfinished_game_message"))
            }
            .alert(LocalizedStringKey("alert_unfinished_game_title"), isPresented: $isShowingSimulateConfirmation) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_end_and_simulate")) {
                    finishGame()
                    startSimulation()
                }
            } message: {
                Text(LocalizedStringKey("alert_unfinished_game_simulate_message"))
            }
            .alert(LocalizedStringKey("alert_cannot_record_title"), isPresented: Binding(
                get: { statAlertMessage != nil },
                set: { if !$0 { statAlertMessage = nil } }
            )) {
                Button(LocalizedStringKey("button_ok")) { statAlertMessage = nil }
            } message: {
                Text(statAlertMessage ?? "")
            }
            .alert(LocalizedStringKey("alert_cannot_simulate_title"), isPresented: Binding(
                get: { simulationAlertMessage != nil },
                set: { if !$0 { simulationAlertMessage = nil } }
            )) {
                Button(LocalizedStringKey("button_ok")) { simulationAlertMessage = nil }
            } message: {
                Text(simulationAlertMessage ?? "")
            }
            .alert(LocalizedStringKey("alert_bluetooth_collab_title"), isPresented: Binding(
                get: { collaborationAlertMessage != nil },
                set: { if !$0 { collaborationAlertMessage = nil } }
            )) {
                Button(LocalizedStringKey("button_ok")) { collaborationAlertMessage = nil }
            } message: {
                Text(collaborationAlertMessage ?? "")
            }
    }

    private var lifecycleWrappedView: some View {
        alertWrappedView
            .onAppear {
                restoreLatestGameIfNeeded()
            }
            .onReceive(matchClockTicker) { date in
                clockNow = date
            }
            .onChange(of: bluetooth.latestLiveSnapshot?.id) { _, _ in
                guard let incoming = bluetooth.latestLiveSnapshot else { return }
                applyRemoteLiveSnapshot(incoming)
            }
            .onChange(of: bluetooth.latestInviteResponse?.id) { _, _ in
                guard let response = bluetooth.latestInviteResponse else { return }
                handleInviteResponse(response)
            }
            .onChange(of: bluetooth.pendingLiveOpRequest?.id) { _, _ in
                guard let request = bluetooth.pendingLiveOpRequest else { return }
                handleIncomingLiveOpRequest(request)
            }
            .onChange(of: bluetooth.latestLiveOpCommit?.id) { _, _ in
                guard let commit = bluetooth.latestLiveOpCommit else { return }
                handleIncomingLiveOpCommit(commit)
            }
            .onChange(of: bluetooth.latestLiveOpAck?.id) { _, _ in
                guard let ack = bluetooth.latestLiveOpAck else { return }
                handleIncomingLiveOpAck(ack)
            }
            .onChange(of: bluetooth.latestLiveResyncRequest?.id) { _, _ in
                guard let request = bluetooth.latestLiveResyncRequest else { return }
                handleIncomingResyncRequest(request)
            }
            .onChange(of: store.teams) { _, _ in ensureInitialSelection() }
            .onChange(of: substitutionSide) { _, _ in prepareSubstitutionDefaults() }
            .onChange(of: lateArrivalSide) { _, _ in prepareLateArrivalDefaults() }
            .onDisappear {
                scorePulseDismissTask?.cancel()
                actionButtonPulseDismissTask?.cancel()
                highlightedLogDismissTask?.cancel()
            }
    }

    private var gameLayout: some View {
        VStack(spacing: 8) {
            teamPickers
                .padding(.horizontal)
                .padding(.top, 8)

            teamRows

            liveGameDataEntry
                .padding(.horizontal)

            actionButtons
                .padding(.horizontal)

            logView
                .padding(.horizontal)
        }
    }

    private var liveGameDataEntry: some View {
        NavigationLink {
            SavedGameDetailView(game: currentLiveSavedGame, displayMode: .live)
        } label: {
            HStack(spacing: 10) {
                Label(LocalizedStringKey("label_game_data"), systemImage: "chart.bar.doc.horizontal")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Text(LocalizedStringKey("label_view"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(needsNewGameSetup)
        .opacity(needsNewGameSetup ? 0.5 : 1)
    }

    private var teamRows: some View {
        VStack(spacing: 6) {
            CompactTeamRow(
                side: .home,
                team: store.team(for: snapshot.homeTeamID),
                players: onCourtPlayers(for: .home),
                score: score(for: snapshot.homeTeamID),
                isScorePulsing: scorePulseSide == .home,
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
                isScorePulsing: scorePulseSide == .away,
                fouls: displayedTeamFouls(for: .away),
                foulLabel: snapshot.resetsTeamFoulsEachPeriod ? "本节犯规" : "累计犯规",
                onCourtPlayerIDs: snapshot.awayOnCourtPlayerIDs,
                selectedPlayerID: selectedPlayerID,
                selectedSide: selectedSide,
                onSelect: selectPlayer
            )
        }
    }

    private var teamPickers: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(Self.durationFormatter(currentMatchElapsedSeconds))
                        .monospacedDigit()
                }
                .font(.callout.weight(.bold))
                .foregroundStyle(.black)

                if isRecordingActive {
                    recordingIndicator
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text(periodSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(Self.durationFormatter(currentPeriodElapsedSeconds))
                            .monospacedDigit()
                    }
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.black)
                }
            }

            if let collaborationStatus {
                HStack(spacing: 6) {
                    Image(systemName: collaborationStatus.isDisconnected ? "wifi.slash" : "dot.radiowaves.left.and.right")
                        .font(.caption.weight(.semibold))
                    Text(collaborationStatus.message)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(collaborationStatus.isDisconnected ? Color.orange : Color.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((collaborationStatus.isDisconnected ? Color.orange : Color.blue).opacity(0.12), in: Capsule())
            }
        }
    }

    private var collaborationStatus: (message: String, isDisconnected: Bool)? {
        guard let role = liveRole,
              activeLiveSessionID != nil else {
            return nil
        }

        let roleLabel: String
        switch role {
        case .host:
            roleLabel = "Host（主机）"
        case .participant:
            roleLabel = "Client（客户端）"
        }

        let connectedPeerNames = Set(bluetooth.connectedPeers.map(\.displayName))

        switch role {
        case .participant:
            guard let hostName = liveHostPeerName, !hostName.isEmpty else {
                return ("\(roleLabel) · 协同中：等待主机状态同步", false)
            }
            if connectedPeerNames.contains(hostName) {
                return ("\(roleLabel) · 协同中：与 \(hostName)", false)
            }
            return ("\(roleLabel) · 协同中断：\(hostName) 已断开", true)

        case .host:
            let knownParticipants = liveParticipantNames.sorted()
            guard !knownParticipants.isEmpty else {
                return ("\(roleLabel) · 协同中：等待队友加入", false)
            }

            let connected = knownParticipants.filter { connectedPeerNames.contains($0) }
            let disconnected = knownParticipants.filter { !connectedPeerNames.contains($0) }

            if disconnected.isEmpty {
                return ("\(roleLabel) · 协同中：与 \(connected.joined(separator: "、"))", false)
            }
            if connected.isEmpty {
                return ("\(roleLabel) · 协同中断：\(disconnected.joined(separator: "、")) 已断开", true)
            }

            return (
                "\(roleLabel) · 协同中：与 \(connected.joined(separator: "、"))（\(disconnected.joined(separator: "、")) 已断开）",
                true
            )
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton(LocalizedStringKey("action_two_made"), systemImage: "2.circle.fill", style: .made) { record(.twoMade) }
                actionButton(LocalizedStringKey("action_three_made"), systemImage: "3.circle.fill", style: .made) { record(.threeMade) }
                actionButton(LocalizedStringKey("action_bonus_made"), systemImage: "plus.circle.fill", style: .made) { record(.bonusMade) }
                actionButton(LocalizedStringKey("action_free_made"), systemImage: "f.circle.fill", style: .made) { record(.freeThrowMade) }
            }

            HStack(spacing: 8) {
                actionButton(LocalizedStringKey("action_two_missed"), systemImage: "2.circle", style: .missed) { record(.twoMissed) }
                actionButton(LocalizedStringKey("action_three_missed"), systemImage: "3.circle", style: .missed) { record(.threeMissed) }
                actionButton(LocalizedStringKey("action_bonus_missed"), systemImage: "plus.circle", style: .missed) { record(.bonusMissed) }
                actionButton(LocalizedStringKey("action_free_missed"), systemImage: "f.circle", style: .missed) { record(.freeThrowMissed) }
            }

            HStack(spacing: 8) {
                if snapshot.showsAssistButton {
                    actionButton(LocalizedStringKey("action_assist"), systemImage: "person.2.fill", style: .assist) { record(.assist) }
                }
                if snapshot.showsReboundButton {
                    actionButton(LocalizedStringKey("action_rebound"), systemImage: "arrow.up.circle.fill", style: .rebound) { record(.rebound) }
                }
                if snapshot.showsFoulButton {
                    actionButton(LocalizedStringKey("action_foul"), systemImage: "exclamationmark.triangle", style: .warning) { record(.foul) }
                }
                if snapshot.showsStealButton {
                    actionButton(LocalizedStringKey("action_steal"), systemImage: "hand.raised.fill", style: .assist) { record(.steal) }
                }
            }

            HStack(spacing: 8) {
                if snapshot.showsBlockButton {
                    actionButton(LocalizedStringKey("action_block"), systemImage: "shield.lefthalf.filled", style: .rebound) { record(.block) }
                }
                if snapshot.showsTurnoverButton {
                    actionButton(LocalizedStringKey("action_turnover"), systemImage: "arrow.triangle.2.circlepath", style: .warning) { record(.turnover) }
                }
                Button {
                    togglePause()
                } label: {
                    Label(LocalizedStringKey(pauseButtonTitle), systemImage: snapshot.isPaused ? "play.fill" : "pause.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .pause))
                .disabled(!snapshot.periodIsRunning || snapshot.isComplete)
            }

            HStack(spacing: 8) {
                Button {
                    togglePeriod()
                    triggerTapFeedback()
                    pulseActionButton("period-toggle")
                } label: {
                    Label(LocalizedStringKey(periodButtonTitle), systemImage: snapshot.periodIsRunning ? "stop.circle" : "play.circle")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: snapshot.periodIsRunning ? .periodEnd : .period))
                .scaleEffect(actionButtonPulseKey == "period-toggle" ? 1.09 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.68), value: actionButtonPulseKey == "period-toggle")
                .disabled(snapshot.isComplete)

                Button {
                    openSubstitution(selectedSide)
                } label: {
                    Label(LocalizedStringKey("button_substitute"), systemImage: "arrow.left.arrow.right.circle")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .substitution))
                .disabled(needsNewGameSetup)

                Button {
                    openLateArrival(selectedSide)
                } label: {
                    Label(LocalizedStringKey("button_add_late_arrival"), systemImage: "person.crop.circle.badge.plus")
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
                    isShowingResetConfirmation = true
                } label: {
                    Label(LocalizedStringKey("button_reset_game"), systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingFinishGameConfirmation = true
                } label: {
                    Label(LocalizedStringKey("button_finish_game"), systemImage: "flag.checkered.circle.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(GamePalette.finish)
                .disabled(snapshot.isComplete || snapshot.logs.isEmpty)
                .alert("结束比赛？", isPresented: $isShowingFinishGameConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("确认结束") {
                        finishGame()
                    }
                } message: {
                    Text("结束后将无法继续本场记分，确认结束当前比赛吗？")
                }

                Button {
                    undo()
                } label: {
                    Label(LocalizedStringKey("button_undo"), systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .disabled(undoStack.isEmpty)

                Button {
                    redo()
                } label: {
                    Label(LocalizedStringKey("button_redo"), systemImage: "arrow.uturn.forward")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                ContentUnavailableView(LocalizedStringKey("text_no_events"), systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                List(snapshot.logs.reversed()) { entry in
                    Text(logText(for: entry))
                        .font(highlightedLogID == entry.id ? .footnote.monospacedDigit().weight(.bold) : .footnote.monospacedDigit())
                        .lineLimit(2)
                        .foregroundStyle(GameLogFormatter.isScoring(entry) ? Color.blue : Color.primary)
                        .scaleEffect(highlightedLogID == entry.id ? 1.05 : 1)
                        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: highlightedLogID == entry.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }

    private var selectedPlayer: Player? {
        guard let selectedPlayerID else { return nil }
        return store.player(for: selectedPlayerID)
    }

    @ViewBuilder
    private var simulationLoadingView: some View {
        if isSimulating {
            VStack(spacing: 8) {
                ProgressView()
                Text("模拟比赛中...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var currentLiveSavedGame: SavedGame {
        var snapshotForDisplay = snapshot
        if snapshotForDisplay.periodIsRunning,
           !snapshotForDisplay.isPaused {
            let now = Date()
            closeActiveStints(in: &snapshotForDisplay, at: now)
            closeMatchClock(in: &snapshotForDisplay, at: now)
            closePeriodClock(in: &snapshotForDisplay, at: now)
        }

        let homeTeam = store.team(for: snapshotForDisplay.homeTeamID)
        let awayTeam = store.team(for: snapshotForDisplay.awayTeamID)

        let homePlayerIDs = dedupedGameRosterIDs(
            primary: snapshotForDisplay.homeAvailablePlayerIDs,
            fallback: homeTeam?.playerIDs ?? snapshotForDisplay.homeOnCourtPlayerIDs
        )
        let awayPlayerIDs = dedupedGameRosterIDs(
            primary: snapshotForDisplay.awayAvailablePlayerIDs,
            fallback: awayTeam?.playerIDs ?? snapshotForDisplay.awayOnCourtPlayerIDs
        )

        let gamePlayerIDs = unique(
            homePlayerIDs
                + awayPlayerIDs
                + snapshotForDisplay.starterPlayerIDs
                + Array(snapshotForDisplay.statsByPlayerID.keys)
                + Array(snapshotForDisplay.playingSecondsByPlayerID.keys)
                + Array(snapshotForDisplay.plusMinusByPlayerID.keys)
        )

        let playerNamesByID = Dictionary(uniqueKeysWithValues: gamePlayerIDs.compactMap { playerID in
            store.player(for: playerID).map { (playerID, $0.name) }
        })

        return SavedGame(
            id: currentGameRecordID ?? UUID(),
            savedAt: Date(),
            snapshot: snapshotForDisplay,
            homeTeamName: homeTeam?.name ?? "主队",
            awayTeamName: awayTeam?.name ?? "客队",
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNamesByID
        )
    }

    private func dedupedGameRosterIDs(primary: [UUID], fallback: [UUID]) -> [UUID] {
        let source = primary.isEmpty ? fallback : primary
        return unique(source)
    }

    private var needsNewGameSetup: Bool {
        snapshot.homeTeamID == nil || snapshot.awayTeamID == nil || snapshot.homeOnCourtPlayerIDs.isEmpty || snapshot.awayOnCourtPlayerIDs.isEmpty
    }

    private var hasUnfinishedGameToConfirm: Bool {
        currentGameRecordID != nil && !snapshot.isComplete
    }

    private var canEditTeamSelection: Bool {
        snapshot.logs.isEmpty && currentGameRecordID == nil
    }

    private var periodSummary: String {
        if snapshot.isComplete { return "已结束" }
        if snapshot.periodIsRunning {
            return snapshot.isPaused
                ? "第\(snapshot.currentPeriod)/\(snapshot.periodCount)节(暂停)"
                : "第\(snapshot.currentPeriod)/\(snapshot.periodCount)节中"
        }
        return "第\(snapshot.currentPeriod)/\(snapshot.periodCount)节"
    }

    private var periodButtonTitle: String {
        if snapshot.isComplete { return "比赛结束" }
        return "第\(snapshot.currentPeriod)节\(snapshot.periodIsRunning ? "结束" : "开始")"
    }

    private var currentMatchElapsedSeconds: TimeInterval {
        guard snapshot.periodIsRunning,
              !snapshot.isPaused,
              let activeSince = snapshot.matchActiveSince else {
            return snapshot.matchElapsedSeconds
        }

        return snapshot.matchElapsedSeconds + max(0, clockNow.timeIntervalSince(activeSince))
    }

    private var currentPeriodElapsedSeconds: TimeInterval {
        guard snapshot.periodIsRunning,
              !snapshot.isPaused,
              let activeSince = snapshot.periodActiveSince else {
            return snapshot.periodElapsedSeconds
        }

        return snapshot.periodElapsedSeconds + max(0, clockNow.timeIntervalSince(activeSince))
    }

    private var pauseButtonTitle: LocalizedStringKey {
        snapshot.isPaused ? LocalizedStringKey("button_continue") : LocalizedStringKey("button_pause")
    }

    private var isRecordingActive: Bool {
        snapshot.periodIsRunning && !snapshot.isPaused && !snapshot.isComplete
    }

    private var recordingIndicator: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(recordingIndicatorBlink ? 0.25 : 1)
                .scaleEffect(recordingIndicatorBlink ? 0.85 : 1.05)

            Text(LocalizedStringKey("label_rec"))
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.red.opacity(0.10), in: Capsule())
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: recordingIndicatorBlink)
        .onAppear { recordingIndicatorBlink = true }
        .onDisappear { recordingIndicatorBlink = false }
    }

    private func actionButton(_ title: String, systemImage: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        Button {
            action()
            pulseActionButton(title)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(PastelActionButtonStyle(style: style))
        .scaleEffect(actionButtonPulseKey == title ? 1.09 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.68), value: actionButtonPulseKey == title)
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
        guard let side = side(for: teamID) else { return 0 }
        return gamePlayerIDs(for: side).reduce(0) { total, playerID in
            total + snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func teamFouls(for teamID: UUID?) -> Int {
        guard let side = side(for: teamID) else { return 0 }
        return gamePlayerIDs(for: side).reduce(0) { total, playerID in
            total + snapshot.statsByPlayerID[playerID, default: PlayerStats()].fouls
        }
    }

    private func displayedTeamFouls(for side: TeamSide) -> Int {
        if snapshot.resetsTeamFoulsEachPeriod {
            return snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0]
        }
        return teamFouls(for: side == .home ? snapshot.homeTeamID : snapshot.awayTeamID)
    }

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        guard let side = side(for: teamID) else { return PlayerStats() }
        return gamePlayerIDs(for: side).reduce(PlayerStats()) { partial, playerID in
            var total = partial
            let stats = snapshot.statsByPlayerID[playerID, default: PlayerStats()]
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
            return total
        }
    }

    private func onCourtIDs(for side: TeamSide) -> [UUID] {
        side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
    }

    private func gamePlayerIDs(for side: TeamSide) -> [UUID] {
        let explicitIDs = side == .home ? snapshot.homeAvailablePlayerIDs : snapshot.awayAvailablePlayerIDs
        if !explicitIDs.isEmpty {
            return explicitIDs
        }
        let fallback = onCourtIDs(for: side)
        if !fallback.isEmpty {
            return fallback
        }
        let teamID = side == .home ? snapshot.homeTeamID : snapshot.awayTeamID
        return players(in: teamID).map(\.id)
    }

    private func setGamePlayerIDs(_ ids: [UUID], for side: TeamSide) {
        let uniqueIDs = unique(ids)
        if side == .home {
            snapshot.homeAvailablePlayerIDs = uniqueIDs
        } else {
            snapshot.awayAvailablePlayerIDs = uniqueIDs
        }
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

    private func side(for teamID: UUID?) -> TeamSide? {
        if teamID == snapshot.homeTeamID { return .home }
        if teamID == snapshot.awayTeamID { return .away }
        return nil
    }

    private func benchPlayers(for side: TeamSide) -> [Player] {
        let onCourt = Set(onCourtIDs(for: side))
        return gamePlayerIDs(for: side)
            .filter { !onCourt.contains($0) }
            .compactMap { store.player(for: $0) }
    }

    private func unregisteredPlayers(for side: TeamSide) -> [Player] {
        let teamID = side == .home ? snapshot.homeTeamID : snapshot.awayTeamID
        let registered = Set(gamePlayerIDs(for: side))
        return players(in: teamID).filter { !registered.contains($0.id) }
    }

    private func playingSeconds(for playerID: UUID, now: Date = Date()) -> TimeInterval {
        let stored = snapshot.playingSecondsByPlayerID[playerID, default: 0]
        guard snapshot.periodIsRunning else { return stored }
        guard let activeSince = snapshot.activeSinceByPlayerID[playerID] else { return stored }
        return stored + max(0, now.timeIntervalSince(activeSince))
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
        trimInvalidLineups()
    }

    private func trimInvalidLineups() {
        let homeTeamIDs = Set(players(in: snapshot.homeTeamID).map(\.id))
        let awayTeamIDs = Set(players(in: snapshot.awayTeamID).map(\.id))

        let homeRegistered = unique((snapshot.homeAvailablePlayerIDs + snapshot.homeOnCourtPlayerIDs).filter { homeTeamIDs.contains($0) })
        let awayRegistered = unique((snapshot.awayAvailablePlayerIDs + snapshot.awayOnCourtPlayerIDs).filter { awayTeamIDs.contains($0) })

        var homeOnCourt = unique(snapshot.homeOnCourtPlayerIDs.filter { homeRegistered.contains($0) })
        var awayOnCourt = unique(snapshot.awayOnCourtPlayerIDs.filter { awayRegistered.contains($0) })

        let maxHomeOnCourt = min(snapshot.courtPlayerCount, homeRegistered.count)
        let maxAwayOnCourt = min(snapshot.courtPlayerCount, awayRegistered.count)

        if homeOnCourt.count < maxHomeOnCourt {
            let supplement = homeRegistered.filter { !homeOnCourt.contains($0) }
            homeOnCourt.append(contentsOf: supplement.prefix(maxHomeOnCourt - homeOnCourt.count))
        }
        if awayOnCourt.count < maxAwayOnCourt {
            let supplement = awayRegistered.filter { !awayOnCourt.contains($0) }
            awayOnCourt.append(contentsOf: supplement.prefix(maxAwayOnCourt - awayOnCourt.count))
        }

        snapshot.homeAvailablePlayerIDs = homeRegistered
        snapshot.awayAvailablePlayerIDs = awayRegistered
        snapshot.homeOnCourtPlayerIDs = Array(homeOnCourt.prefix(snapshot.courtPlayerCount))
        snapshot.awayOnCourtPlayerIDs = Array(awayOnCourt.prefix(snapshot.courtPlayerCount))
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
        guard !snapshot.isPaused else {
            statAlertMessage = "比赛暂停中"
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

        let operation = BluetoothLiveOperationPayload.record(
            action: action.liveAction,
            playerID: player.id,
            side: selectedSide.liveSide
        )
        let changed = submitLiveOperation(operation) {
            applyRecordOperation(action: action, playerID: player.id, side: selectedSide)
        }
        if changed {
            showRecordFeedback(action: action, side: selectedSide)
        }
    }

    private func showRecordFeedback(action: StatAction, side: TeamSide) {
        triggerTapFeedback()

        guard action.points > 0 else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
            scorePulseSide = side
        }
        scorePulseDismissTask?.cancel()
        scorePulseDismissTask = Task {
            try? await Task.sleep(for: .seconds(0.48))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.16)) {
                    scorePulseSide = nil
                }
            }
        }
    }

    private func triggerTapFeedback() {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred(intensity: 1)
    }

    private func pulseActionButton(_ key: String) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            actionButtonPulseKey = key
        }
        actionButtonPulseDismissTask?.cancel()
        actionButtonPulseDismissTask = Task {
            try? await Task.sleep(for: .seconds(0.18))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.12)) {
                    actionButtonPulseKey = nil
                }
            }
        }
    }

    private func handleInviteSyncTapped() {
        guard currentGameRecordID != nil else {
            collaborationAlertMessage = "请先新建比赛后再发起协同邀请。"
            return
        }
        guard !needsNewGameSetup else {
            collaborationAlertMessage = "请先完成比赛阵容设置后再邀请协同。"
            return
        }
        guard !bluetooth.connectedPeers.isEmpty else {
            collaborationAlertMessage = "请先在设置 > 蓝牙协同里连接设备。"
            return
        }

        sendLiveInvite(to: bluetooth.connectedPeers)
    }

    private func sendLiveInvite(to peers: [MCPeerID]) {
        let payload = buildLiveStatePayload()
        liveVersion = 0
        liveStateHash = stateHash(for: payload)
        liveRole = .host
        liveHostPeerName = nil
        liveHostPeerID = nil
        liveParticipantNames.removeAll()
        localLiveOpSeq = 0
        liveCommitHistory.removeAll()
        peerAckVersionByDeviceID.removeAll()

        guard let sessionID = bluetooth.sendLiveInvite(
            players: store.players,
            teams: store.teams,
            state: payload,
            stateVersion: liveVersion,
            stateHash: liveStateHash,
            to: peers
        ) else {
            collaborationAlertMessage = "邀请发送失败，请检查连接状态。"
            return
        }

        activeLiveSessionID = sessionID
        collaborationAlertMessage = "协同邀请已发送，等待对方同意。"
    }

    private func handleInviteResponse(_ response: BluetoothReceivedInviteResponse) {
        guard response.payload.sessionID == activeLiveSessionID else { return }
        if response.payload.accepted {
            bluetooth.noteAcceptedLiveSession(sessionID: response.payload.sessionID, with: response.fromPeerName)
            liveParticipantNames.insert(response.fromPeerName)
            sendAuthoritativeSnapshot(reason: "新设备加入")
        } else {
            liveParticipantNames.remove(response.fromPeerName)
        }
    }

    private func applyRemoteLiveSnapshot(_ incoming: BluetoothReceivedLiveSnapshot) {
        let isNewSession = activeLiveSessionID != incoming.payload.sessionID
        let needsParticipantBootstrap = liveRole != .participant
        if isNewSession || needsParticipantBootstrap {
            activeLiveSessionID = incoming.payload.sessionID
            liveRole = .participant
            liveParticipantNames.removeAll()
            localLiveOpSeq = 0
            liveCommitHistory.removeAll()
            peerAckVersionByDeviceID.removeAll()
        }
        guard incoming.payload.sessionID == activeLiveSessionID else { return }
        liveHostPeerName = incoming.fromPeerName
        liveHostPeerID = incoming.fromPeerID
        bluetooth.noteAcceptedLiveSession(sessionID: incoming.payload.sessionID, with: incoming.fromPeerName)
        applyAuthoritativeState(
            incoming.payload.state,
            version: incoming.payload.version,
            hash: incoming.payload.stateHash
        )
    }

    private func applyAuthoritativeState(_ state: BluetoothLiveGameStatePayload, version: Int, hash: String) {
        let previousLastLogID = snapshot.logs.last?.id

        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }

        currentGameRecordID = state.gameID
        undoStack = state.undoSnapshots
        redoStack.removeAll()
        snapshot = snapshotForLocalClock(fromRemote: state.snapshot)
        trimInvalidLineups()
        ensureSelectedPlayer()
        autoSaveCurrentGame()
        liveVersion = version
        liveStateHash = hash

        if let latestLogID = snapshot.logs.last?.id,
           latestLogID != previousLastLogID {
            highlightLatestLog(latestLogID)
        }
    }

    private func snapshotForLiveSync(_ source: GameSnapshot) -> GameSnapshot {
        var synced = source
        let now = Date()

        if synced.periodIsRunning && !synced.isPaused && !synced.isComplete {
            if let activeSince = synced.matchActiveSince {
                synced.matchElapsedSeconds += max(0, now.timeIntervalSince(activeSince))
            }
            synced.matchActiveSince = now

            if let activeSince = synced.periodActiveSince {
                synced.periodElapsedSeconds += max(0, now.timeIntervalSince(activeSince))
            }
            synced.periodActiveSince = now

            for (playerID, startedAt) in synced.activeSinceByPlayerID {
                synced.playingSecondsByPlayerID[playerID, default: 0] += max(0, now.timeIntervalSince(startedAt))
            }

            let onCourtIDs = unique(synced.homeOnCourtPlayerIDs + synced.awayOnCourtPlayerIDs)
            synced.activeSinceByPlayerID = Dictionary(uniqueKeysWithValues: onCourtIDs.map { ($0, now) })
        } else {
            synced.matchActiveSince = nil
            synced.periodActiveSince = nil
            synced.activeSinceByPlayerID = [:]
        }

        return synced
    }

    private func snapshotForLocalClock(fromRemote source: GameSnapshot) -> GameSnapshot {
        var adjusted = source
        let now = Date()

        if adjusted.periodIsRunning && !adjusted.isPaused && !adjusted.isComplete {
            adjusted.matchActiveSince = now
            adjusted.periodActiveSince = now
            let onCourtIDs = unique(adjusted.homeOnCourtPlayerIDs + adjusted.awayOnCourtPlayerIDs)
            adjusted.activeSinceByPlayerID = Dictionary(uniqueKeysWithValues: onCourtIDs.map { ($0, now) })
        } else {
            adjusted.matchActiveSince = nil
            adjusted.periodActiveSince = nil
            adjusted.activeSinceByPlayerID = [:]
        }

        return adjusted
    }

    private func buildLiveStatePayload() -> BluetoothLiveGameStatePayload {
        BluetoothLiveGameStatePayload(
            gameID: currentGameRecordID,
            snapshot: snapshotForLiveSync(snapshot),
            undoSnapshots: undoStack
        )
    }

    private func stateHash(for payload: BluetoothLiveGameStatePayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sendAuthoritativeSnapshot(reason: String, to peers: [MCPeerID]? = nil) {
        guard liveRole == .host,
              let sessionID = activeLiveSessionID else {
            return
        }

        let payload = buildLiveStatePayload()
        liveStateHash = stateHash(for: payload)
        bluetooth.sendLiveSnapshot(
            sessionID: sessionID,
            state: payload,
            version: liveVersion,
            stateHash: liveStateHash,
            reason: reason,
            to: peers
        )
    }

    private func requestLiveResync(reason: String) {
        guard let sessionID = activeLiveSessionID else { return }
        bluetooth.sendLiveResyncRequest(
            sessionID: sessionID,
            expectedVersion: liveVersion,
            reason: reason,
            to: liveHostPeerID
        )
    }

    private func handleIncomingLiveOpRequest(_ incoming: BluetoothReceivedLiveOpRequest) {
        bluetooth.clearPendingLiveOpRequest()
        guard liveRole == .host,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        liveParticipantNames.insert(incoming.fromPeerName)

        guard incoming.payload.op.baseVersion == liveVersion else {
            sendAuthoritativeSnapshot(reason: "版本不一致，触发重同步", to: [incoming.fromPeerID])
            return
        }

        let applied = applyLiveOperationPayload(incoming.payload.op.payload)
        guard applied else {
            sendAuthoritativeSnapshot(reason: "操作无法应用，触发重同步", to: [incoming.fromPeerID])
            return
        }

        liveVersion += 1
        let payload = buildLiveStatePayload()
        liveStateHash = stateHash(for: payload)
        let commit = BluetoothLiveOpCommitPayload(
            sessionID: sessionID,
            op: incoming.payload.op,
            newVersion: liveVersion,
            stateHash: liveStateHash
        )
        appendLiveCommitHistory(commit)
        bluetooth.sendLiveOpCommit(sessionID: sessionID, commit: commit)
    }

    private func handleIncomingLiveOpCommit(_ incoming: BluetoothReceivedLiveOpCommit) {
        guard liveRole == .participant,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        liveHostPeerName = incoming.fromPeerName
        liveHostPeerID = incoming.fromPeerID

        guard incoming.payload.op.baseVersion == liveVersion,
              incoming.payload.newVersion == liveVersion + 1 else {
            requestLiveResync(reason: "收到提交版本异常")
            return
        }

        let applied = applyLiveOperationPayload(incoming.payload.op.payload)
        guard applied else {
            requestLiveResync(reason: "收到提交但本地无法应用")
            return
        }

        liveVersion = incoming.payload.newVersion
        let computedHash = stateHash(for: buildLiveStatePayload())
        guard computedHash == incoming.payload.stateHash else {
            requestLiveResync(reason: "提交后哈希不一致")
            return
        }

        liveStateHash = incoming.payload.stateHash
        bluetooth.sendLiveOpAck(
            sessionID: sessionID,
            opID: incoming.payload.op.opID,
            version: liveVersion,
            to: liveHostPeerID
        )
    }

    private func handleIncomingLiveOpAck(_ incoming: BluetoothReceivedLiveOpAck) {
        bluetooth.clearLatestLiveOpAck()
        guard liveRole == .host,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        let currentVersion = peerAckVersionByDeviceID[incoming.payload.deviceID] ?? -1
        if incoming.payload.version > currentVersion {
            peerAckVersionByDeviceID[incoming.payload.deviceID] = incoming.payload.version
        }
    }

    private func handleIncomingResyncRequest(_ incoming: BluetoothReceivedLiveResyncRequest) {
        guard liveRole == .host,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        liveParticipantNames.insert(incoming.fromPeerName)

        if let commits = missingCommits(after: incoming.payload.expectedVersion), !commits.isEmpty {
            for commit in commits {
                bluetooth.sendLiveOpCommit(sessionID: sessionID, commit: commit, to: [incoming.fromPeerID])
            }
            return
        }

        sendAuthoritativeSnapshot(reason: "收到重同步请求", to: [incoming.fromPeerID])
    }

    private var isLiveSessionActive: Bool {
        activeLiveSessionID != nil && liveRole != nil
    }

    private func appendLiveCommitHistory(_ commit: BluetoothLiveOpCommitPayload) {
        liveCommitHistory.append(commit)
        if liveCommitHistory.count > 300 {
            liveCommitHistory.removeFirst(liveCommitHistory.count - 300)
        }
    }

    private func missingCommits(after version: Int) -> [BluetoothLiveOpCommitPayload]? {
        guard version < liveVersion else { return [] }
        let expectedRange = (version + 1)...liveVersion
        let commits = liveCommitHistory.filter { expectedRange.contains($0.newVersion) }
            .sorted { $0.newVersion < $1.newVersion }
        let versions = commits.map(\.newVersion)
        let expected = Array(expectedRange)
        return versions == expected ? commits : nil
    }

    @discardableResult
    private func submitLiveOperation(_ payload: BluetoothLiveOperationPayload, applyLocal: () -> Bool) -> Bool {
        guard let sessionID = activeLiveSessionID,
              let role = liveRole else {
            return applyLocal()
        }

        localLiveOpSeq += 1
        let operation = BluetoothLiveOperation(
            opID: UUID(),
            deviceID: bluetooth.localDeviceID,
            seq: localLiveOpSeq,
            baseVersion: liveVersion,
            payload: payload
        )

        switch role {
        case .host:
            let changed = applyLocal()
            guard changed else { return false }
            liveVersion += 1
            liveStateHash = stateHash(for: buildLiveStatePayload())
            let commit = BluetoothLiveOpCommitPayload(
                sessionID: sessionID,
                op: operation,
                newVersion: liveVersion,
                stateHash: liveStateHash
            )
            appendLiveCommitHistory(commit)
            bluetooth.sendLiveOpCommit(sessionID: sessionID, commit: commit)
            return true

        case .participant:
            let sent = bluetooth.sendLiveOpRequest(
                sessionID: sessionID,
                op: operation,
                toHost: liveHostPeerID,
                hostName: liveHostPeerName
            )
            if !sent {
                collaborationAlertMessage = "操作发送失败，请检查连接后重试。"
            }
            return false
        }
    }

    private func togglePeriod() {
        guard !needsNewGameSetup else {
            isShowingNewGameSetup = true
            return
        }
        let now = Date()
        _ = submitLiveOperation(.togglePeriod(at: now)) {
            applyTogglePeriodOperation(at: now)
        }
    }

    private func togglePause() {
        guard snapshot.periodIsRunning, !snapshot.isComplete else { return }
        let now = Date()
        _ = submitLiveOperation(.togglePause(at: now)) {
            applyTogglePauseOperation(at: now)
        }
    }

    @discardableResult
    private func applyLiveOperationPayload(_ payload: BluetoothLiveOperationPayload) -> Bool {
        switch payload {
        case let .record(action, playerID, side):
            guard let statAction = StatAction(liveAction: action) else { return false }
            return applyRecordOperation(action: statAction, playerID: playerID, side: TeamSide(liveSide: side))

        case let .togglePeriod(at):
            return applyTogglePeriodOperation(at: at)

        case let .togglePause(at):
            return applyTogglePauseOperation(at: at)

        case let .substitution(outgoingPlayerID, incomingPlayerID, side, at):
            return applySubstitutionOperation(
                outgoingPlayerID: outgoingPlayerID,
                incomingPlayerID: incomingPlayerID,
                side: TeamSide(liveSide: side),
                at: at
            )

        case let .lateArrival(playerID, side):
            return applyLateArrivalOperation(playerID: playerID, side: TeamSide(liveSide: side))

        case let .finishGame(at):
            return applyFinishGameOperation(at: at)

        case .resetGame:
            return applyResetGameOperation(keepLiveSession: true)

        case .undo:
            guard let previous = undoStack.popLast() else { return false }
            redoStack.append(snapshot)
            snapshot = previous
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true

        case .redo:
            guard let next = redoStack.popLast() else { return false }
            undoStack.append(snapshot)
            snapshot = next
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    @discardableResult
    private func applyRecordOperation(action: StatAction, playerID: UUID, side: TeamSide) -> Bool {
        guard isOnCourt(playerID, side: side) else { return false }

        mutateSnapshot {
            var stats = snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            action.apply(to: &stats)
            snapshot.statsByPlayerID[playerID] = stats
            if action == .foul {
                snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0] += 1
            }
            if action.points > 0 {
                applyPlusMinus(points: action.points, scoringSide: side)
            }
            addEvent("\(name(for: playerID)) \(action.message)", playerID: playerID)
        }
        return true
    }

    @discardableResult
    private func applyTogglePeriodOperation(at now: Date) -> Bool {
        mutateSnapshot {
            if snapshot.periodIsRunning {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                addEvent("第\(snapshot.currentPeriod)节结束")
                snapshot.periodIsRunning = false
                snapshot.isPaused = false
                if snapshot.currentPeriod >= snapshot.periodCount {
                    snapshot.isComplete = true
                    addEvent("比赛结束")
                } else {
                    snapshot.currentPeriod += 1
                    snapshot.periodElapsedSeconds = 0
                    snapshot.periodActiveSince = nil
                }
            } else {
                trimInvalidLineups()
                if snapshot.resetsTeamFoulsEachPeriod {
                    snapshot.currentPeriodFoulsBySide[TeamSide.home.rawValue] = 0
                    snapshot.currentPeriodFoulsBySide[TeamSide.away.rawValue] = 0
                }
                if !snapshot.startersRecorded {
                    snapshot.starterPlayerIDs = unique(snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs)
                    addEvent("主队首发：\(names(for: snapshot.homeOnCourtPlayerIDs))")
                    addEvent("客队首发：\(names(for: snapshot.awayOnCourtPlayerIDs))")
                    snapshot.startersRecorded = true
                }
                snapshot.periodElapsedSeconds = 0
                snapshot.periodActiveSince = nil
                addEvent("第\(snapshot.currentPeriod)节开始")
                startMatchClock(at: now)
                startPeriodClock(at: now)
                startActiveStints(at: now)
                snapshot.periodIsRunning = true
                snapshot.isPaused = false
            }
        }
        return true
    }

    @discardableResult
    private func applyTogglePauseOperation(at now: Date) -> Bool {
        guard snapshot.periodIsRunning, !snapshot.isComplete else { return false }

        mutateSnapshot {
            if snapshot.isPaused {
                snapshot.isPaused = false
                startMatchClock(at: now)
                startPeriodClock(at: now)
                startActiveStints(at: now)
                addEvent("比赛继续")
            } else {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                snapshot.isPaused = true
                addEvent("比赛暂停")
            }
        }
        return true
    }

    @discardableResult
    private func applySubstitutionOperation(
        outgoingPlayerID: UUID,
        incomingPlayerID: UUID,
        side: TeamSide,
        at now: Date
    ) -> Bool {
        guard outgoingPlayerID != incomingPlayerID else { return false }

        var changed = false
        mutateSnapshot {
            var ids = onCourtIDs(for: side)
            guard ids.contains(outgoingPlayerID) else { return }

            ids.removeAll { $0 == outgoingPlayerID }
            if !ids.contains(incomingPlayerID) {
                ids.append(incomingPlayerID)
            }
            setOnCourtIDs(ids, for: side)

            if snapshot.periodIsRunning && !snapshot.isPaused {
                closeStint(for: outgoingPlayerID, at: now)
                startStint(for: incomingPlayerID, at: now)
            }

            addEvent("\(name(for: incomingPlayerID)) 替换 \(name(for: outgoingPlayerID))")
            selectedPlayerID = incomingPlayerID
            selectedSide = side
            changed = true
        }
        return changed
    }

    @discardableResult
    private func applyLateArrivalOperation(playerID: UUID, side: TeamSide) -> Bool {
        var changed = false
        mutateSnapshot {
            var registered = gamePlayerIDs(for: side)
            guard !registered.contains(playerID) else { return }
            registered.append(playerID)
            setGamePlayerIDs(registered, for: side)
            addEvent("\(name(for: playerID)) 已加入出场名单")
            changed = true
        }
        return changed
    }

    @discardableResult
    private func applyFinishGameOperation(at now: Date) -> Bool {
        guard !snapshot.isComplete else { return false }

        mutateSnapshot {
            if snapshot.periodIsRunning {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                snapshot.periodIsRunning = false
            }
            snapshot.isPaused = false
            snapshot.isComplete = true
            addEvent("比赛结束")
        }
        return true
    }

    @discardableResult
    private func applyResetGameOperation(keepLiveSession: Bool) -> Bool {
        if !keepLiveSession {
            activeLiveSessionID = nil
            liveRole = nil
            liveHostPeerName = nil
            liveHostPeerID = nil
            liveParticipantNames.removeAll()
            liveVersion = 0
            liveStateHash = ""
            localLiveOpSeq = 0
            liveCommitHistory.removeAll()
            peerAckVersionByDeviceID.removeAll()
        }

        undoStack.removeAll()
        redoStack.removeAll()
        currentGameRecordID = keepLiveSession ? currentGameRecordID : nil
        snapshot = GameSnapshot(
            homeTeamID: snapshot.homeTeamID,
            awayTeamID: snapshot.awayTeamID,
            periodCount: snapshot.periodCount,
            courtPlayerCount: snapshot.courtPlayerCount,
            resetsTeamFoulsEachPeriod: snapshot.resetsTeamFoulsEachPeriod,
            showsReboundButton: snapshot.showsReboundButton,
            showsAssistButton: snapshot.showsAssistButton,
            showsFoulButton: snapshot.showsFoulButton,
            showsBlockButton: snapshot.showsBlockButton,
            showsStealButton: snapshot.showsStealButton,
            showsTurnoverButton: snapshot.showsTurnoverButton
        )
        ensureSelectedPlayer()
        autoSaveCurrentGame()
        return true
    }

    private func startNewGame(
        homeTeamID: UUID,
        awayTeamID: UUID,
        homeStarterIDs: [UUID],
        awayStarterIDs: [UUID],
        homeBenchIDs: [UUID],
        awayBenchIDs: [UUID],
        periodCount: Int,
        courtPlayerCount: Int,
        resetsTeamFoulsEachPeriod: Bool,
        showsReboundButton: Bool,
        showsAssistButton: Bool,
        showsFoulButton: Bool,
        showsBlockButton: Bool,
        showsStealButton: Bool,
        showsTurnoverButton: Bool
    ) {
        activeLiveSessionID = nil
        liveRole = nil
        liveHostPeerName = nil
        liveHostPeerID = nil
        liveParticipantNames.removeAll()
        liveVersion = 0
        liveStateHash = ""
        localLiveOpSeq = 0
        liveCommitHistory.removeAll()
        peerAckVersionByDeviceID.removeAll()
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
            showsBlockButton: showsBlockButton,
            showsStealButton: showsStealButton,
            showsTurnoverButton: showsTurnoverButton,
            homeOnCourtPlayerIDs: homeStarterIDs,
            awayOnCourtPlayerIDs: awayStarterIDs,
            homeAvailablePlayerIDs: unique(homeStarterIDs + homeBenchIDs),
            awayAvailablePlayerIDs: unique(awayStarterIDs + awayBenchIDs)
        )
        selectedPlayerID = nil
        selectedSide = .home
        ensureSelectedPlayer()
        autoSaveCurrentGame()
    }

    private func saveCurrentGame() {
        var snapshotForSaving = snapshot
        let now = Date()
        closeActiveStints(in: &snapshotForSaving, at: now)
        closeMatchClock(in: &snapshotForSaving, at: now)
        closePeriodClock(in: &snapshotForSaving, at: now)
        snapshotForSaving.periodIsRunning = false
        currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: undoStack)
        saveConfirmation = "比赛已保存到历史记录。"
    }

    private func finishGame() {
        guard !snapshot.isComplete else { return }
        let now = Date()
        _ = submitLiveOperation(.finishGame(at: now)) {
            applyFinishGameOperation(at: now)
        }
    }

    private func prepareSubstitutionDefaults() {
        let onCourt = substitutionSide == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
        let bench = gamePlayerIDs(for: substitutionSide).filter { !onCourt.contains($0) }
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
        _ = submitLiveOperation(
            .substitution(
                outgoingPlayerID: outgoingPlayerID,
                incomingPlayerID: incomingPlayerID,
                side: substitutionSide.liveSide,
                at: now
            )
        ) {
            applySubstitutionOperation(
                outgoingPlayerID: outgoingPlayerID,
                incomingPlayerID: incomingPlayerID,
                side: substitutionSide,
                at: now
            )
        }
    }

    private func prepareLateArrivalDefaults() {
        let incomingCandidates = unregisteredPlayers(for: lateArrivalSide).map(\.id)
        lateArrivalIncomingPlayerID = incomingCandidates.first
    }

    private func openLateArrival(_ side: TeamSide) {
        lateArrivalSide = side
        prepareLateArrivalDefaults()
        isShowingLateArrival = true
    }

    private func handleSimulateTapped() {
        guard !isSimulating else { return }
        if hasUnfinishedGameToConfirm {
            isShowingSimulateConfirmation = true
            return
        }
        startSimulation()
    }

    private func startSimulation() {
        guard !isSimulating else { return }
        isSimulating = true
        Task { @MainActor in
            defer { isSimulating = false }
            await Task.yield()
            simulateGame()
        }
    }

    private func simulateGame() {
        guard let context = simulationContext() else {
            simulationAlertMessage = "至少需要两支有球员的球队才能模拟比赛。"
            return
        }

        let periodCount = min(max(snapshot.periodCount, 1), 8)
        let courtCount = max(1, min(snapshot.courtPlayerCount, context.homeRosterIDs.count, context.awayRosterIDs.count))
        let homeAvailable = context.homeRosterIDs.shuffled()
        let awayAvailable = context.awayRosterIDs.shuffled()

        var simulated = GameSnapshot(
            homeTeamID: context.homeTeam.id,
            awayTeamID: context.awayTeam.id,
            periodCount: periodCount,
            courtPlayerCount: courtCount,
            resetsTeamFoulsEachPeriod: snapshot.resetsTeamFoulsEachPeriod,
            showsReboundButton: snapshot.showsReboundButton,
            showsAssistButton: snapshot.showsAssistButton,
            showsFoulButton: snapshot.showsFoulButton,
            showsBlockButton: snapshot.showsBlockButton,
            showsStealButton: snapshot.showsStealButton,
            showsTurnoverButton: snapshot.showsTurnoverButton,
            homeOnCourtPlayerIDs: Array(homeAvailable.prefix(courtCount)),
            awayOnCourtPlayerIDs: Array(awayAvailable.prefix(courtCount)),
            homeAvailablePlayerIDs: homeAvailable,
            awayAvailablePlayerIDs: awayAvailable
        )

        var eventTime = Date().addingTimeInterval(-Double(periodCount) * 700)
        var simulatedMatchElapsedSeconds: TimeInterval = 0
        var simulatedCurrentPeriod: Int?
        var simulatedPeriodElapsedSeconds: TimeInterval?

        func onCourtIDs(for side: TeamSide) -> [UUID] {
            side == .home ? simulated.homeOnCourtPlayerIDs : simulated.awayOnCourtPlayerIDs
        }

        func setOnCourtIDs(_ ids: [UUID], for side: TeamSide) {
            if side == .home {
                simulated.homeOnCourtPlayerIDs = ids
            } else {
                simulated.awayOnCourtPlayerIDs = ids
            }
        }

        func availableIDs(for side: TeamSide) -> [UUID] {
            side == .home ? simulated.homeAvailablePlayerIDs : simulated.awayAvailablePlayerIDs
        }

        func randomOnCourtPlayerID(for side: TeamSide) -> UUID? {
            onCourtIDs(for: side).randomElement()
        }

        func randomTeammateID(side: TeamSide, excluding playerID: UUID) -> UUID? {
            onCourtIDs(for: side).filter { $0 != playerID }.randomElement()
        }

        func randomBenchPlayerID(for side: TeamSide) -> UUID? {
            let onCourt = Set(onCourtIDs(for: side))
            let bench = availableIDs(for: side).filter { !onCourt.contains($0) }
            return bench.randomElement()
        }

        func sideScore(_ side: TeamSide) -> Int {
            availableIDs(for: side).reduce(0) { total, playerID in
                total + simulated.statsByPlayerID[playerID, default: PlayerStats()].points
            }
        }

        func scoreSuffix() -> String {
            "(\(sideScore(.home)):\(sideScore(.away)))"
        }

        func appendEvent(_ message: String, playerID: UUID? = nil) {
            simulated.logs.append(
                GameLogEntry(
                    timestamp: eventTime,
                    message: "\(message) \(scoreSuffix())",
                    playerID: playerID,
                    period: simulatedCurrentPeriod,
                    periodElapsedSeconds: simulatedPeriodElapsedSeconds
                )
            )
        }

        func addPlayingTime(_ seconds: TimeInterval) {
            guard seconds > 0 else { return }
            for playerID in simulated.homeOnCourtPlayerIDs + simulated.awayOnCourtPlayerIDs {
                simulated.playingSecondsByPlayerID[playerID, default: 0] += seconds
            }
        }

        func addFoulEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let foulerID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[foulerID, default: PlayerStats()]
            stats.fouls += 1
            simulated.statsByPlayerID[foulerID] = stats
            simulated.currentPeriodFoulsBySide[side.rawValue, default: 0] += 1
            appendEvent("\(name(for: foulerID)) 犯规", playerID: foulerID)
        }

        func addReboundEvent(preferredSide: TeamSide? = nil) {
            let side: TeamSide
            if let preferredSide {
                side = preferredSide
            } else {
                side = Double.random(in: 0...1) < 0.5 ? .home : .away
            }
            guard let rebounderID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[rebounderID, default: PlayerStats()]
            stats.rebounds += 1
            simulated.statsByPlayerID[rebounderID] = stats
            appendEvent("\(name(for: rebounderID)) 篮板", playerID: rebounderID)
        }

        func addSubstitutionEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let outgoingID = randomOnCourtPlayerID(for: side),
                  let incomingID = randomBenchPlayerID(for: side),
                  outgoingID != incomingID else {
                return
            }

            var nextOnCourt = onCourtIDs(for: side)
            nextOnCourt.removeAll { $0 == outgoingID }
            nextOnCourt.append(incomingID)
            setOnCourtIDs(nextOnCourt, for: side)
            appendEvent("\(name(for: incomingID)) 替换 \(name(for: outgoingID))")
        }

        func addBlockEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let blockerID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[blockerID, default: PlayerStats()]
            stats.blocks += 1
            simulated.statsByPlayerID[blockerID] = stats
            appendEvent("\(name(for: blockerID)) 封盖", playerID: blockerID)
        }

        func addStealEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let stealerID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[stealerID, default: PlayerStats()]
            stats.steals += 1
            simulated.statsByPlayerID[stealerID] = stats
            appendEvent("\(name(for: stealerID)) 抢断", playerID: stealerID)
        }

        func addTurnoverEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let turnoverID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[turnoverID, default: PlayerStats()]
            stats.turnovers += 1
            simulated.statsByPlayerID[turnoverID] = stats
            appendEvent("\(name(for: turnoverID)) 失误", playerID: turnoverID)
        }

        func addShotEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.52 ? .home : .away
            guard let shooterID = randomOnCourtPlayerID(for: side) else { return }

            var stats = simulated.statsByPlayerID[shooterID, default: PlayerStats()]
            let isThree = Double.random(in: 0...1) < 0.35
            let isMade = Double.random(in: 0...1) < (isThree ? 0.37 : 0.54)

            if isThree {
                stats.threeAttempts += 1
                if isMade { stats.threeMade += 1 }
                simulated.statsByPlayerID[shooterID] = stats
                appendEvent("\(name(for: shooterID)) \(isMade ? "3分命中" : "3分不中")", playerID: shooterID)
                if isMade {
                    applyPlusMinus(points: 3, scoringSide: side, in: &simulated)
                }
            } else {
                stats.twoAttempts += 1
                if isMade { stats.twoMade += 1 }
                simulated.statsByPlayerID[shooterID] = stats
                appendEvent("\(name(for: shooterID)) \(isMade ? "2分命中" : "2分不中")", playerID: shooterID)
                if isMade {
                    applyPlusMinus(points: 2, scoringSide: side, in: &simulated)
                }
            }

            if isMade,
               snapshot.showsAssistButton,
               Double.random(in: 0...1) < 0.35,
               let assistID = randomTeammateID(side: side, excluding: shooterID) {
                var assistStats = simulated.statsByPlayerID[assistID, default: PlayerStats()]
                assistStats.assists += 1
                simulated.statsByPlayerID[assistID] = assistStats
                appendEvent("\(name(for: assistID)) 助攻", playerID: assistID)
            }

            if isMade, Double.random(in: 0...1) < 0.12 {
                var bonusStats = simulated.statsByPlayerID[shooterID, default: PlayerStats()]
                bonusStats.bonusFreeThrowAttempts += 1
                let bonusMade = Double.random(in: 0...1) < 0.7
                if bonusMade {
                    bonusStats.bonusFreeThrowMade += 1
                }
                simulated.statsByPlayerID[shooterID] = bonusStats
                appendEvent("\(name(for: shooterID)) \(bonusMade ? "加罚命中" : "加罚不中")", playerID: shooterID)
                if bonusMade {
                    applyPlusMinus(points: 1, scoringSide: side, in: &simulated)
                }
            }

            if !isMade, snapshot.showsReboundButton, Double.random(in: 0...1) < 0.58 {
                let reboundSide: TeamSide = Double.random(in: 0...1) < 0.25 ? side : (side == .home ? .away : .home)
                addReboundEvent(preferredSide: reboundSide)
            }
        }

        for period in 1...periodCount {
            simulated.currentPeriod = period
            simulatedCurrentPeriod = period
            simulatedPeriodElapsedSeconds = 0
            if simulated.resetsTeamFoulsEachPeriod {
                simulated.currentPeriodFoulsBySide[TeamSide.home.rawValue] = 0
                simulated.currentPeriodFoulsBySide[TeamSide.away.rawValue] = 0
            }

            if !simulated.startersRecorded {
                simulated.starterPlayerIDs = unique(simulated.homeOnCourtPlayerIDs + simulated.awayOnCourtPlayerIDs)
                appendEvent("主队首发：\(names(for: simulated.homeOnCourtPlayerIDs))")
                appendEvent("客队首发：\(names(for: simulated.awayOnCourtPlayerIDs))")
                simulated.startersRecorded = true
            }

            appendEvent("第\(period)节开始")

            let periodDuration = Double.random(in: 630...690)
            var elapsed: TimeInterval = 0
            let eventBudget = Int.random(in: 48...64)

            for _ in 0..<eventBudget {
                let remaining = periodDuration - elapsed
                if remaining <= 5 { break }

                let delta = min(Double.random(in: 6...16), remaining)
                elapsed += delta
                simulatedPeriodElapsedSeconds = elapsed
                eventTime.addTimeInterval(delta)
                addPlayingTime(delta)
                simulatedMatchElapsedSeconds += delta

                let roll = Double.random(in: 0...1)
                if roll < 0.72 {
                    addShotEvent()
                } else if roll < 0.82 {
                    addFoulEvent()
                } else if roll < 0.88, snapshot.showsStealButton {
                    addStealEvent()
                } else if roll < 0.93, snapshot.showsBlockButton {
                    addBlockEvent()
                } else if roll < 0.97, snapshot.showsTurnoverButton {
                    addTurnoverEvent()
                } else if roll < 0.99 {
                    addSubstitutionEvent()
                } else if snapshot.showsReboundButton {
                    addReboundEvent()
                }
            }

            if elapsed < periodDuration {
                let remaining = periodDuration - elapsed
                eventTime.addTimeInterval(remaining)
                addPlayingTime(remaining)
                simulatedMatchElapsedSeconds += remaining
                elapsed = periodDuration
            }

            simulatedPeriodElapsedSeconds = elapsed
            appendEvent("第\(period)节结束")
        }

        simulated.currentPeriod = periodCount
        simulated.periodIsRunning = false
        simulated.isPaused = false
        simulated.isComplete = true
        simulated.matchElapsedSeconds = simulatedMatchElapsedSeconds
        simulated.matchActiveSince = nil
        simulated.periodElapsedSeconds = 0
        simulated.periodActiveSince = nil
        simulatedCurrentPeriod = nil
        simulatedPeriodElapsedSeconds = nil
        eventTime.addTimeInterval(10)
        appendEvent("比赛结束")

        undoStack.removeAll()
        redoStack.removeAll()
        currentGameRecordID = UUID()
        snapshot = simulated
        selectedPlayerID = snapshot.homeOnCourtPlayerIDs.first
        selectedSide = .home
        ensureSelectedPlayer()
        autoSaveCurrentGame()
        saveConfirmation = "已生成一场模拟比赛并保存到历史记录。"
    }

    private struct SimulationContext {
        var homeTeam: Team
        var awayTeam: Team
        var homeRosterIDs: [UUID]
        var awayRosterIDs: [UUID]
    }

    private func simulationContext() -> SimulationContext? {
        func rosterIDs(for teamID: UUID?) -> [UUID] {
            guard let team = store.team(for: teamID) else { return [] }
            let validIDs = team.playerIDs.filter { store.player(for: $0) != nil }
            return unique(validIDs)
        }

        let preferredHomeRoster = rosterIDs(for: snapshot.homeTeamID)
        let preferredAwayRoster = rosterIDs(for: snapshot.awayTeamID)
        if let homeTeam = store.team(for: snapshot.homeTeamID),
           let awayTeam = store.team(for: snapshot.awayTeamID),
           homeTeam.id != awayTeam.id,
           !preferredHomeRoster.isEmpty,
           !preferredAwayRoster.isEmpty {
            return SimulationContext(
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                homeRosterIDs: preferredHomeRoster,
                awayRosterIDs: preferredAwayRoster
            )
        }

        let candidates = store.teams.compactMap { team -> (Team, [UUID])? in
            let ids = rosterIDs(for: team.id)
            guard !ids.isEmpty else { return nil }
            return (team, ids)
        }

        guard candidates.count >= 2 else { return nil }
        let homeCandidate = candidates[0]
        let awayCandidate = candidates.first(where: { $0.0.id != homeCandidate.0.id }) ?? candidates[1]

        return SimulationContext(
            homeTeam: homeCandidate.0,
            awayTeam: awayCandidate.0,
            homeRosterIDs: homeCandidate.1,
            awayRosterIDs: awayCandidate.1
        )
    }

    private func performLateArrival() {
        guard let incomingPlayerID = lateArrivalIncomingPlayerID else { return }
        _ = submitLiveOperation(
            .lateArrival(playerID: incomingPlayerID, side: lateArrivalSide.liveSide)
        ) {
            applyLateArrivalOperation(playerID: incomingPlayerID, side: lateArrivalSide)
        }
    }

    private func undo() {
        guard !undoStack.isEmpty else { return }
        _ = submitLiveOperation(.undo) {
            guard let previous = undoStack.popLast() else { return false }
            redoStack.append(snapshot)
            snapshot = previous
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    private func redo() {
        guard !redoStack.isEmpty else { return }
        _ = submitLiveOperation(.redo) {
            guard let next = redoStack.popLast() else { return false }
            undoStack.append(snapshot)
            snapshot = next
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    private func resetGame() {
        _ = submitLiveOperation(.resetGame) {
            applyResetGameOperation(keepLiveSession: isLiveSessionActive)
        }
    }

    private func mutateSnapshot(pushUndo: Bool = true, _ updates: () -> Void) {
        if pushUndo { undoStack.append(snapshot) }
        redoStack.removeAll()
        updates()
        autoSaveCurrentGame()
    }

    private func addEvent(_ message: String, playerID: UUID? = nil) {
        let context = eventPeriodContext(for: message)
        let logEntry = GameLogEntry(
            timestamp: Date(),
            message: "\(message) \(scoreSuffix)",
            playerID: playerID,
            period: context.period,
            periodElapsedSeconds: context.periodElapsedSeconds
        )
        snapshot.logs.append(logEntry)
        highlightLatestLog(logEntry.id)
    }

    private func highlightLatestLog(_ logID: UUID) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
            highlightedLogID = logID
        }

        highlightedLogDismissTask?.cancel()
        highlightedLogDismissTask = Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard highlightedLogID == logID else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    highlightedLogID = nil
                }
            }
        }
    }

    private func eventPeriodContext(for message: String) -> (period: Int?, periodElapsedSeconds: TimeInterval?) {
        guard !["比赛结束", "比赛保存"].contains(message), snapshot.currentPeriod > 0 else {
            return (nil, nil)
        }

        let elapsed: TimeInterval
        if snapshot.periodIsRunning,
           !snapshot.isPaused,
           let activeSince = snapshot.periodActiveSince {
            elapsed = snapshot.periodElapsedSeconds + max(0, Date().timeIntervalSince(activeSince))
        } else {
            elapsed = snapshot.periodElapsedSeconds
        }

        return (snapshot.currentPeriod, max(0, elapsed))
    }

    private var scoreSuffix: String {
        "(\(score(for: snapshot.homeTeamID)):\(score(for: snapshot.awayTeamID)))"
    }

    private func autoSaveCurrentGame() {
        if snapshot.logs.isEmpty {
            guard let currentGameRecordID,
                  store.savedGames.contains(where: { $0.id == currentGameRecordID }) else {
                return
            }
            self.currentGameRecordID = store.autoSaveGame(snapshot, gameID: currentGameRecordID, undoSnapshots: undoStack)
            return
        }
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
            trimInvalidLineups()
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

    private func startMatchClock(at date: Date) {
        if snapshot.matchActiveSince == nil {
            snapshot.matchActiveSince = date
        }
    }

    private func startPeriodClock(at date: Date) {
        if snapshot.periodActiveSince == nil {
            snapshot.periodActiveSince = date
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

    private func closeMatchClock(at date: Date) {
        closeMatchClock(in: &snapshot, at: date)
    }

    private func closeMatchClock(in target: inout GameSnapshot, at date: Date) {
        guard let activeSince = target.matchActiveSince else { return }
        target.matchElapsedSeconds += max(0, date.timeIntervalSince(activeSince))
        target.matchActiveSince = nil
    }

    private func closePeriodClock(at date: Date) {
        closePeriodClock(in: &snapshot, at: date)
    }

    private func closePeriodClock(in target: inout GameSnapshot, at date: Date) {
        guard let activeSince = target.periodActiveSince else { return }
        target.periodElapsedSeconds += max(0, date.timeIntervalSince(activeSince))
        target.periodActiveSince = nil
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
        let normalizedMessage = normalizedLogMessage(lastLog.message)

        var previous = current
        previous.logs.removeLast()

        if normalizedMessage == "比赛保存" {
            return previous
        }

        if normalizedMessage == "比赛结束" {
            previous.isComplete = false
            return previous
        }

        guard let (playerName, action) = StatAction.parseLog(normalizedMessage) else {
            return nil
        }

        let resolvedPlayerID = lastLog.playerID ?? playerID(for: playerName, action: action, in: current)
        guard let playerID = resolvedPlayerID,
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

    private func normalizedLogMessage(_ message: String) -> String {
        guard message.hasSuffix(")"),
              let start = message.lastIndex(of: "("),
              start > message.startIndex else {
            return message
        }

        let scoreText = message[message.index(after: start)..<message.index(before: message.endIndex)]
        let parts = scoreText.split(separator: ":")
        guard parts.count == 2,
              Int(parts[0]) != nil,
              Int(parts[1]) != nil else {
            return message
        }

        let beforeScore = message[..<start]
        guard beforeScore.last == " " else { return message }
        return String(beforeScore.dropLast())
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

    private func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    static func durationFormatter(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func periodContextText(period: Int?, elapsedSeconds: TimeInterval?) -> String {
        guard let period else { return "" }
        guard let elapsedSeconds else { return "第\(period)节" }
        return "第\(period)节 \(durationFormatter(elapsedSeconds))"
    }

    private func logText(for entry: GameLogEntry) -> String {
        let periodText = Self.periodContextText(period: entry.period, elapsedSeconds: entry.periodElapsedSeconds)
        return [Self.timeFormatter.string(from: entry.timestamp), periodText, entry.message]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
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

private enum LiveCollaborationRole {
    case host
    case participant
}

private extension TeamSide {
    init(liveSide: BluetoothLiveSide) {
        switch liveSide {
        case .home:
            self = .home
        case .away:
            self = .away
        }
    }

    var liveSide: BluetoothLiveSide {
        switch self {
        case .home:
            return .home
        case .away:
            return .away
        }
    }
}

private enum GamePalette {
    static let make = Color(red: 0.78, green: 0.93, blue: 0.78)
    static let miss = Color(red: 0.86, green: 0.92, blue: 0.98)
    static let assist = Color(red: 0.74, green: 0.86, blue: 0.98)
    static let rebound = Color(red: 0.80, green: 0.90, blue: 0.99)
    static let warning = Color(red: 0.96, green: 0.80, blue: 0.80)
    static let period = Color(red: 0.36, green: 0.63, blue: 0.95)
    static let periodEnd = Color(red: 0.96, green: 0.72, blue: 0.63)
    static let substitution = Color(red: 0.42, green: 0.67, blue: 0.95)
    static let pause = Color(red: 0.98, green: 0.82, blue: 0.45)
    static let finish = Color(red: 0.95, green: 0.48, blue: 0.44)
    static let surface = Color(red: 0.96, green: 0.98, blue: 1.00)
    static let selectedBorder = Color(red: 0.25, green: 0.55, blue: 0.90)
    static let onCourtBorder = Color(red: 0.45, green: 0.69, blue: 0.93)
    static let text = Color(red: 0.18, green: 0.20, blue: 0.22)
}

private enum ActionButtonStyle {
    case made, missed, assist, rebound, warning, substitution, pause, period, periodEnd

    var background: Color {
        switch self {
        case .made: return GamePalette.make
        case .missed: return GamePalette.miss
        case .assist: return GamePalette.assist
        case .rebound: return GamePalette.rebound
        case .warning: return GamePalette.warning
        case .substitution: return GamePalette.substitution
        case .pause: return GamePalette.pause
        case .period: return GamePalette.period
        case .periodEnd: return GamePalette.periodEnd
        }
    }

    var foreground: Color { GamePalette.text }
}

private struct PastelActionButtonStyle: ButtonStyle {
    var style: ActionButtonStyle
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(style.foreground)
            .background(style.background.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private enum StatAction {
    case twoMade, twoMissed, threeMade, threeMissed
    case bonusMade, bonusMissed, freeThrowMade, freeThrowMissed
    case foul, assist, rebound, block, steal, turnover

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
        case .block: return "封盖"
        case .steal: return "抢断"
        case .turnover: return "失误"
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
        case .block:
            stats.blocks += 1
        case .steal:
            stats.steals += 1
        case .turnover:
            stats.turnovers += 1
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
        case .block:
            guard stats.blocks > 0 else { return false }
            stats.blocks -= 1
        case .steal:
            guard stats.steals > 0 else { return false }
            stats.steals -= 1
        case .turnover:
            guard stats.turnovers > 0 else { return false }
            stats.turnovers -= 1
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

private extension StatAction {
    init?(liveAction: BluetoothLiveStatAction) {
        switch liveAction {
        case .twoMade: self = .twoMade
        case .twoMissed: self = .twoMissed
        case .threeMade: self = .threeMade
        case .threeMissed: self = .threeMissed
        case .bonusMade: self = .bonusMade
        case .bonusMissed: self = .bonusMissed
        case .freeThrowMade: self = .freeThrowMade
        case .freeThrowMissed: self = .freeThrowMissed
        case .foul: self = .foul
        case .assist: self = .assist
        case .rebound: self = .rebound
        case .block: self = .block
        case .steal: self = .steal
        case .turnover: self = .turnover
        }
    }

    var liveAction: BluetoothLiveStatAction {
        switch self {
        case .twoMade: return .twoMade
        case .twoMissed: return .twoMissed
        case .threeMade: return .threeMade
        case .threeMissed: return .threeMissed
        case .bonusMade: return .bonusMade
        case .bonusMissed: return .bonusMissed
        case .freeThrowMade: return .freeThrowMade
        case .freeThrowMissed: return .freeThrowMissed
        case .foul: return .foul
        case .assist: return .assist
        case .rebound: return .rebound
        case .block: return .block
        case .steal: return .steal
        case .turnover: return .turnover
        }
    }
}

extension StatAction: Equatable {}

extension StatAction: CaseIterable {
    static var allCases: [StatAction] {
        [.twoMade, .twoMissed, .threeMade, .threeMissed, .bonusMade, .bonusMissed, .freeThrowMade, .freeThrowMissed, .foul, .assist, .rebound, .block, .steal, .turnover]
    }
}

private struct CompactTeamRow: View {
    var side: TeamSide
    var team: Team?
    var players: [Player]
    var score: Int
    var isScorePulsing: Bool = false
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
                        .foregroundStyle(isScorePulsing ? GamePalette.period : GamePalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .layoutPriority(1)
                        .scaleEffect(isScorePulsing ? 1.15 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.72), value: isScorePulsing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(foulLabel)
                            .font(.caption2)
                        Text("\(fouls)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 114, alignment: .leading)

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

enum TeamStatsCardStyle {
    case scoreboard
    case record
}

struct TeamStatsDisclosureView: View {
    var homeName: String
    var awayName: String
    var homeStats: PlayerStats
    var awayStats: PlayerStats
    var homeFouls: Int
    var awayFouls: Int
    var style: TeamStatsCardStyle = .scoreboard

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
        .background(containerBackground, in: RoundedRectangle(cornerRadius: containerCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: containerCornerRadius).stroke(containerBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func teamRow(_ name: String, stats: PlayerStats, fouls: Int) -> some View {
        if style == .record {
            recordTeamRow(name, stats: stats, fouls: fouls)
        } else {
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
                    statTile("2分", "\(stats.twoMade)/\(stats.twoAttempts)", percent(stats.twoPointRate))
                    statTile("3分", "\(stats.threeMade)/\(stats.threeAttempts)", percent(stats.threePointRate))
                }
                HStack(spacing: 8) {
                    statTile("罚篮", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)", percent(stats.freeThrowRate))
                    statTile("板 / 助 / 犯", "\(stats.rebounds) / \(stats.assists) / \(fouls)", "")
                    statTile("盖 / 断 / 失", "\(stats.blocks) / \(stats.steals) / \(stats.turnovers)", "")
                }
                HStack(spacing: 8) {
                    statTile("高阶", "eFG \(percent(stats.effectiveFieldGoalRate))", "TS \(percent(stats.trueShootingRate))")
                    statTile("每次出手得分", String(format: "%.2f", stats.pointsPerShot), "PTS/FGA")
                }
            }
            .padding(8)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: tileCornerRadius))
        }
    }

    private func recordTeamRow(_ name: String, stats: PlayerStats, fouls: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(stats.points)分")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }

            Text("投篮 \(stats.made)/\(stats.attempts)  2分 \(stats.twoMade)/\(stats.twoAttempts)  3分 \(stats.threeMade)/\(stats.threeAttempts)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("罚球 \(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  板 \(stats.rebounds)  助 \(stats.assists)  犯 \(fouls)  盖 \(stats.blocks)  断 \(stats.steals)  失 \(stats.turnovers)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("eFG \(percent(stats.effectiveFieldGoalRate))  TS \(percent(stats.trueShootingRate))  PTS/FGA \(String(format: "%.2f", stats.pointsPerShot))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
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

    private var containerBackground: Color {
        switch style {
        case .scoreboard:
            return GamePalette.surface
        case .record:
            return .clear
        }
    }

    private var containerBorder: Color {
        switch style {
        case .scoreboard:
            return .white.opacity(0.85)
        case .record:
            return .clear
        }
    }

    private var tileBackground: Color {
        switch style {
        case .scoreboard:
            return .white.opacity(0.52)
        case .record:
            return .clear
        }
    }

    private var containerCornerRadius: CGFloat {
        style == .record ? 12 : 8
    }

    private var tileCornerRadius: CGFloat {
        style == .record ? 10 : 8
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
                    statTile("板 / 助 / 犯 / 盖 / 断 / 失", "\(stats.rebounds) / \(stats.assists) / \(stats.fouls) / \(stats.blocks) / \(stats.steals) / \(stats.turnovers)", "")
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
                Text("盖\(stats.blocks)")
                Text("断\(stats.steals)")
                Text("失\(stats.turnovers)")
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
    var initialShowsBlockButton: Bool
    var initialShowsStealButton: Bool
    var initialShowsTurnoverButton: Bool
    var onStart: (UUID, UUID, [UUID], [UUID], [UUID], [UUID], Int, Int, Bool, Bool, Bool, Bool, Bool, Bool, Bool) -> Void

    @State private var homeTeamID: UUID?
    @State private var awayTeamID: UUID?
    @State private var homeStarterIDs: [UUID] = []
    @State private var awayStarterIDs: [UUID] = []
    @State private var homeBenchIDs: [UUID] = []
    @State private var awayBenchIDs: [UUID] = []
    @State private var periodCount = 4
    @State private var courtPlayerCount = 4
    @State private var resetsTeamFoulsEachPeriod = true
    @State private var showsReboundButton = true
    @State private var showsAssistButton = true
    @State private var showsFoulButton = true
    @State private var showsBlockButton = true
    @State private var showsStealButton = true
    @State private var showsTurnoverButton = true

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_teams")) {
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

                Section(LocalizedStringKey("section_game_settings")) {
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

                Section(LocalizedStringKey("section_scoring_buttons")) {
                    Toggle("篮板", isOn: $showsReboundButton)
                    Toggle("助攻", isOn: $showsAssistButton)
                    Toggle("犯规", isOn: $showsFoulButton)
                    Toggle("封盖", isOn: $showsBlockButton)
                    Toggle("抢断", isOn: $showsStealButton)
                    Toggle("失误", isOn: $showsTurnoverButton)
                }

                starterSection(title: LocalizedStringKey("starter_home_title"), players: homePlayers, selectedIDs: $homeStarterIDs, requiredCount: requiredHomeCount)
                benchSection(
                    title: "主队替补",
                    players: homeBenchCandidates,
                    selectedIDs: $homeBenchIDs
                )

                starterSection(title: LocalizedStringKey("starter_away_title"), players: awayPlayers, selectedIDs: $awayStarterIDs, requiredCount: requiredAwayCount)
                benchSection(
                    title: "客队替补",
                    players: awayBenchCandidates,
                    selectedIDs: $awayBenchIDs
                )
            }
                .navigationTitle(LocalizedStringKey("nav_new_game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_start")) {
                        guard let homeTeamID, let awayTeamID else { return }
                        onStart(
                            homeTeamID,
                            awayTeamID,
                            homeStarterIDs,
                            awayStarterIDs,
                            homeBenchIDs,
                            awayBenchIDs,
                            periodCount,
                            courtPlayerCount,
                            resetsTeamFoulsEachPeriod,
                            showsReboundButton,
                            showsAssistButton,
                            showsFoulButton,
                            showsBlockButton,
                            showsStealButton,
                            showsTurnoverButton
                        )
                        dismiss()
                    }
                    .disabled(!canStart)
                }
            }
            .onAppear(perform: prepareDefaults)
            .onChange(of: homeTeamID) { _, _ in syncSelections(fillMissingStarters: true) }
            .onChange(of: awayTeamID) { _, _ in syncSelections(fillMissingStarters: true) }
            .onChange(of: courtPlayerCount) { _, _ in syncSelections(fillMissingStarters: true) }
        }
    }

    private var homePlayers: [Player] { playersForTeam(homeTeamID) }
    private var awayPlayers: [Player] { playersForTeam(awayTeamID) }
    private var requiredHomeCount: Int { min(courtPlayerCount, homePlayers.count) }
    private var requiredAwayCount: Int { min(courtPlayerCount, awayPlayers.count) }
    private var homeBenchCandidates: [Player] { homePlayers.filter { !homeStarterIDs.contains($0.id) } }
    private var awayBenchCandidates: [Player] { awayPlayers.filter { !awayStarterIDs.contains($0.id) } }

    private var canStart: Bool {
        return homeTeamID != nil
            && awayTeamID != nil
            && homeTeamID != awayTeamID
            && homeStarterIDs.count == requiredHomeCount
            && awayStarterIDs.count == requiredAwayCount
            && requiredHomeCount > 0
            && requiredAwayCount > 0
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

    private func benchSection(title: String, players: [Player], selectedIDs: Binding<[UUID]>) -> some View {
        Section("\(title) · 可选") {
            if players.isEmpty {
                Text("当前没有可选替补")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            SelectablePlayerAvatarButton(
                                player: player,
                                isSelected: selectedIDs.wrappedValue.contains(player.id),
                                badge: selectedIDs.wrappedValue.contains(player.id) ? "替补" : nil
                            ) {
                                toggleBench(player.id, in: selectedIDs)
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
        showsBlockButton = initialShowsBlockButton
        showsStealButton = initialShowsStealButton
        showsTurnoverButton = initialShowsTurnoverButton
        if awayTeamID == homeTeamID {
            awayTeamID = teams.first(where: { $0.id != homeTeamID })?.id
        }
        syncSelections(fillMissingStarters: true)
    }

    private func toggle(_ id: UUID, in selectedIDs: Binding<[UUID]>, limit: Int) {
        if selectedIDs.wrappedValue.contains(id) {
            selectedIDs.wrappedValue.removeAll { $0 == id }
        } else if selectedIDs.wrappedValue.count < limit {
            selectedIDs.wrappedValue.append(id)
        } else if !selectedIDs.wrappedValue.isEmpty {
            selectedIDs.wrappedValue.removeFirst()
            selectedIDs.wrappedValue.append(id)
        }
        syncSelections(fillMissingStarters: false)
    }

    private func toggleBench(_ id: UUID, in selectedIDs: Binding<[UUID]>) {
        if selectedIDs.wrappedValue.contains(id) {
            selectedIDs.wrappedValue.removeAll { $0 == id }
        } else {
            selectedIDs.wrappedValue.append(id)
        }
        syncSelections(fillMissingStarters: false)
    }

    private func syncSelections(fillMissingStarters: Bool) {
        let homePlayerIDs = homePlayers.map(\.id)
        let awayPlayerIDs = awayPlayers.map(\.id)

        homeStarterIDs = Array(homeStarterIDs.filter { homePlayerIDs.contains($0) }.prefix(requiredHomeCount))
        awayStarterIDs = Array(awayStarterIDs.filter { awayPlayerIDs.contains($0) }.prefix(requiredAwayCount))

        if fillMissingStarters, homeStarterIDs.count < requiredHomeCount {
            let candidates = homePlayerIDs.filter { !homeStarterIDs.contains($0) }
            homeStarterIDs.append(contentsOf: candidates.prefix(requiredHomeCount - homeStarterIDs.count))
        }
        if fillMissingStarters, awayStarterIDs.count < requiredAwayCount {
            let candidates = awayPlayerIDs.filter { !awayStarterIDs.contains($0) }
            awayStarterIDs.append(contentsOf: candidates.prefix(requiredAwayCount - awayStarterIDs.count))
        }

        homeBenchIDs = homeBenchIDs.filter { homePlayerIDs.contains($0) && !homeStarterIDs.contains($0) }
        awayBenchIDs = awayBenchIDs.filter { awayPlayerIDs.contains($0) && !awayStarterIDs.contains($0) }
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

private struct LateArrivalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var side: TeamSide
    @Binding var incomingPlayerID: UUID?

    var homeTeamName: String
    var awayTeamName: String
    var homeUnregisteredPlayers: [Player]
    var awayUnregisteredPlayers: [Player]
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
                    sectionHeader("新增到出场名单", selectedName(for: incomingPlayerID))
                    if incomingPlayers.isEmpty {
                        Text("没有可新增上场的球员")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(incomingPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: incomingPlayerID == player.id,
                                        badge: incomingPlayerID == player.id ? "上场" : nil
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
            .navigationTitle("新增上场")
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
                    .disabled(incomingPlayerID == nil)
                }
            }
        }
    }

    private var incomingPlayers: [Player] {
        side == .home ? homeUnregisteredPlayers : awayUnregisteredPlayers
    }

    private func selectedName(for id: UUID?) -> String {
        guard let id else { return "未选择" }
        return incomingPlayers.first(where: { $0.id == id })?.name ?? "未选择"
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
