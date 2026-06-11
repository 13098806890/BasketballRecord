import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import MultipeerConnectivity
import CryptoKit

struct GameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager

    @State private var snapshot = GameSnapshot()
    @State private var undoStack: [GameSnapshot] = []
    @State private var redoStack: [GameSnapshot] = []
    @State private var hasMigratedUndo = false
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
    @State private var blinkTimer: Timer?
    @State private var highlightedLogID: UUID?
    @State private var highlightedLogDismissTask: Task<Void, Never>?
    @State private var showAutoEndAlert = false
    @State private var autoEndAlertMessage = ""
    @State private var isShowingPurchase = false
    @StateObject private var voiceRecognizer = VoiceRecognizer()

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
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            isShowingResetConfirmation = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.callout)
                        }

                        Button {
                            isShowingFinishGameConfirmation = true
                        } label: {
                            Image(systemName: "flag.checkered.circle.fill")
                        }
                        .disabled(snapshot.isComplete || snapshot.logs.isEmpty)
                    }

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

                        if store.showsBluetoothGamesButton {
                            Button {
                                handleInviteSyncTapped()
                            } label: {
                                Label(LocalizedStringKey("button_invite_collab"), systemImage: "dot.radiowaves.left.and.right")
                            }
                            .disabled(currentGameRecordID == nil || needsNewGameSetup || bluetooth.connectedPeers.isEmpty)
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
                    onStart: startNewGame(with:)
                )
            }
            .sheet(isPresented: $isShowingSubstitution) {
                SubstitutionView(
                    side: $substitutionSide,
                    outgoingPlayerID: $outgoingPlayerID,
                    incomingPlayerID: $incomingPlayerID,
                    homeTeamName: store.team(for: snapshot.homeTeamID)?.name ?? NSLocalizedString("team_home_default", comment: "Default home team name"),
                    awayTeamName: store.team(for: snapshot.awayTeamID)?.name ?? NSLocalizedString("team_away_default", comment: "Default away team name"),
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
                    homeTeamName: store.team(for: snapshot.homeTeamID)?.name ?? NSLocalizedString("team_home_default", comment: "Default home team name"),
                    awayTeamName: store.team(for: snapshot.awayTeamID)?.name ?? NSLocalizedString("team_away_default", comment: "Default away team name"),
                    homeUnregisteredPlayers: unregisteredPlayers(for: .home),
                    awayUnregisteredPlayers: unregisteredPlayers(for: .away),
                    onConfirm: performLateArrival
                )
            }
            .sheet(isPresented: $isShowingPurchase) {
                ProSubscriptionStoreView()
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
            .alert(LocalizedStringKey("alert_finish_game_title"), isPresented: $isShowingFinishGameConfirmation) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_confirm_finish")) {
                    finishGame()
                }
            } message: {
                Text(LocalizedStringKey("alert_finish_game_message"))
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
            .alert(LocalizedStringKey("alert_period_auto_ended_title"), isPresented: $showAutoEndAlert) {
                Button(LocalizedStringKey("button_ok")) { }
            } message: {
                Text(autoEndAlertMessage)
            }
    }

    private var lifecycleWrappedView: some View {
        alertWrappedView
            .onAppear {
                restoreLatestGameIfNeeded()
            }
            .onReceive(matchClockTicker) { date in
                clockNow = date
                if snapshot.periodEndCondition == .byTime {
                    checkAndAutoEndPeriod()
                }
            }
            .onAppear {
                voiceRecognizer.configure(store: store)
                voiceRecognizer.onAction = { [self] action, playerID, side in
                    guard !snapshot.isComplete else {
                        statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "")
                        return
                    }
                    guard !snapshot.isPaused else {
                        statAlertMessage = NSLocalizedString("stat_game_paused", comment: "")
                        return
                    }
                    guard snapshot.periodIsRunning else {
                        statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: ""), snapshot.currentPeriod)
                        return
                    }
                    let now = Date()
                    let operation = BluetoothLiveOperationPayload.record(
                        action: action.liveAction,
                        playerID: playerID,
                        side: side.liveSide,
                        at: now
                    )
                    _ = submitLiveOperation(operation) {
                        self.applyRecordOperation(action: action, playerID: playerID, side: side, at: now)
                    }
                }
                voiceRecognizer.onCommand = { [self] command in
                    switch command {
                    case .togglePause: togglePause()
                    case .startPeriod: togglePeriod()
                    case .finishGame: isShowingFinishGameConfirmation = true
                    case .substitution(_, _, _): break
                    }
                }
                voiceRecognizer.onSubstitution = { [self] side, outgoingID, incomingID in
                    let now = Date()
                    _ = submitLiveOperation(.substitution(outgoingPlayerID: outgoingID, incomingPlayerID: incomingID, side: side.liveSide, at: now)) {
                        applySubstitutionOperation(outgoingPlayerID: outgoingID, incomingPlayerID: incomingID, side: side, at: now)
                    }
                }
            }
            .onChange(of: snapshot) { _, newValue in
                voiceRecognizer.currentSnapshot = newValue
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
        ScrollView {
            VStack(spacing: 8) {
                teamPickers
                    .padding(.horizontal)
                    .padding(.top, 8)

                teamRows

                actionButtons
                    .padding(.horizontal)

                liveGameDataEntry
                    .padding(.horizontal)

                logView
                    .padding(.horizontal)
                    .padding(.bottom, 8)

            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .bottom) {
            if store.showsVoiceButton, !needsNewGameSetup {
                VStack(spacing: 6) {
                    if let error = voiceRecognizer.errorMessage {
                        Text(error)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                            .transition(.opacity)
                    }
                    if let match = voiceRecognizer.match {
                        Text(match.action.message)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                            .transition(.opacity)
                    }
                    micButton
                }
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .center) {
            Group {
                if voiceRecognizer.isRecording {
                    voiceWave
                        .allowsHitTesting(false)
                } else if let color = voiceRecognizer.flashColor {
                    Rectangle()
                        .fill(color.opacity(0.15))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
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

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var teamRows: some View {
        let isLandscape = verticalSizeClass == .compact
        return Group {
            if isLandscape {
                HStack(spacing: 8) {
                    CompactTeamRow(
                        side: .home,
                        team: store.team(for: snapshot.homeTeamID),
                        players: onCourtPlayers(for: .home),
                        score: score(for: snapshot.homeTeamID),
                        isScorePulsing: scorePulseSide == .home,
                        fouls: displayedTeamFouls(for: .home),
                        foulLabel: snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
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
                        foulLabel: snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
                        onCourtPlayerIDs: snapshot.awayOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer
                    )
                }
            } else {
                VStack(spacing: 6) {
                    CompactTeamRow(
                        side: .home,
                        team: store.team(for: snapshot.homeTeamID),
                        players: onCourtPlayers(for: .home),
                        score: score(for: snapshot.homeTeamID),
                        isScorePulsing: scorePulseSide == .home,
                        fouls: displayedTeamFouls(for: .home),
                        foulLabel: snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
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
                        foulLabel: snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
                        onCourtPlayerIDs: snapshot.awayOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer
                    )
                }
            }
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
                .foregroundStyle(.primary)

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
                    .foregroundStyle(.primary)
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
            roleLabel = NSLocalizedString("role_host", comment: "Host role label")
        case .participant:
            roleLabel = NSLocalizedString("role_client", comment: "Client role label")
        }

        let connectedPeerNames = Set(bluetooth.connectedPeers.map(\.displayName))

        switch role {
        case .participant:
            guard let hostName = liveHostPeerName, !hostName.isEmpty else {
                return (String(format: NSLocalizedString("collab_status_participant_waiting_host", comment: "participant waiting host status"), roleLabel), false)
            }
            if connectedPeerNames.contains(hostName) {
                return (String(format: NSLocalizedString("collab_status_participant_with_host", comment: "participant with host"), roleLabel, hostName), false)
            }
            return (String(format: NSLocalizedString("collab_status_participant_host_disconnected", comment: "participant host disconnected"), roleLabel, hostName), true)

        case .host:
            let knownParticipants = liveParticipantNames.sorted()
            guard !knownParticipants.isEmpty else {
                return (String(format: NSLocalizedString("collab_status_host_waiting_for_participants", comment: "host waiting for participants"), roleLabel), false)
            }

            let connected = knownParticipants.filter { connectedPeerNames.contains($0) }
            let disconnected = knownParticipants.filter { !connectedPeerNames.contains($0) }

            if disconnected.isEmpty {
                return (String(format: NSLocalizedString("collab_status_host_with_connected", comment: "host with connected"), roleLabel, ListFormatter.localizedString(byJoining: connected)), false)
            }
            if connected.isEmpty {
                return (String(format: NSLocalizedString("collab_status_host_disconnected_some", comment: "host disconnected some"), roleLabel, ListFormatter.localizedString(byJoining: disconnected)), true)
            }

            return (
                String(format: NSLocalizedString("collab_status_host_mixed", comment: "host mixed connected and disconnected"), roleLabel, ListFormatter.localizedString(byJoining: connected), ListFormatter.localizedString(byJoining: disconnected)),
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
                if snapshot.showsBlockButton {
                    actionButton(LocalizedStringKey("action_block"), systemImage: "shield.lefthalf.filled", style: .rebound) { record(.block) }
                }
                if snapshot.showsStealButton {
                    actionButton(LocalizedStringKey("action_steal"), systemImage: "hand.raised.fill", style: .assist) { record(.steal) }
                }
            }

            HStack(spacing: 8) {
                if snapshot.showsFoulButton {
                    actionButton(LocalizedStringKey("action_foul"), systemImage: "exclamationmark.triangle", style: .warning) { record(.foul) }
                }
                if snapshot.showsTurnoverButton {
                    actionButton(LocalizedStringKey("action_turnover"), systemImage: "arrow.triangle.2.circlepath", style: .warning) { record(.turnover) }
                }
                Button {
                    togglePause()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: snapshot.isPaused ? "play.fill" : "pause.fill")
                        Text(pauseButtonTitle)
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .pause))
                .disabled(snapshot.isComplete)
            }

            HStack(spacing: 8) {
                Button {
                    togglePeriod()
                    triggerTapFeedback()
                    pulseActionButton("period-toggle")
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: snapshot.periodIsRunning ? "stop.circle" : "play.circle")
                        Text(LocalizedStringKey(periodButtonTitle))
                    }
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
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.arrow.right.circle")
                        Text(LocalizedStringKey("button_substitute"))
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .assist))
                .disabled(needsNewGameSetup)

                Button {
                    openLateArrival(selectedSide)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text(LocalizedStringKey("button_add_late_arrival"))
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .rebound))
                .disabled(needsNewGameSetup)
            }

            HStack(spacing: 8) {
                Button {
                    undo()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                        Text(LocalizedStringKey("button_undo"))
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .neutral))
                .disabled(undoStack.isEmpty)

                Button {
                    redo()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.forward")
                        Text(LocalizedStringKey("button_redo"))
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .neutral))
                .disabled(redoStack.isEmpty)
            }
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey("label_events"))
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(snapshot.logs.reversed()) { entry in
                            Text(logText(for: entry))
                                .font(highlightedLogID == entry.id ? .footnote.monospacedDigit().weight(.bold) : .footnote.monospacedDigit())
                                .lineLimit(2)
                                .foregroundStyle(GameLogFormatter.isScoring(entry) ? Color.blue : Color.primary)
                                .scaleEffect(highlightedLogID == entry.id ? 1.05 : 1)
                                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: highlightedLogID == entry.id)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
    }

    private var selectedPlayer: Player? {
        guard let selectedPlayerID else { return nil }
        return store.player(for: selectedPlayerID)
    }

    private var voiceWave: some View {
        TimelineView(.animation(minimumInterval: 0.04)) { timeline in
            ThreeWaves(time: timeline.date)
        }
        .frame(height: 120)
    }

    private struct ThreeWaves: View {
        let time: Date
        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let midY = h / 2
                let phase = time.timeIntervalSinceReferenceDate * 3.5
                let amp = h * 0.28

                Canvas { context, size in
                    let samples = Int(w / 2)
                    let waves: [(offset: Double, color: Color)] = [
                        (0, Color.cyan),
                        (2.5, Color.green),
                        (5.0, Color(red: 1, green: 0.75, blue: 0.8)),
                    ]

                    for (offset, color) in waves {
                        var path = Path()
                        let firstPt = CGPoint(x: 0, y: midY + sin(phase + offset) * amp)
                        path.move(to: firstPt)

                        for i in 0..<samples {
                            let x = CGFloat(i) / CGFloat(samples) * w
                            let angle = Double(i) / Double(samples) * .pi * 3 + phase + offset
                            let y = midY + sin(angle) * amp
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        // Draw with per-segment width for tapered effect
                        let allPts = (0..<samples).map { i -> CGPoint in
                            let x = CGFloat(i) / CGFloat(samples) * w
                            let angle = Double(i) / Double(samples) * .pi * 3 + phase + offset
                            return CGPoint(x: x, y: midY + sin(angle) * amp)
                        }

                        for i in 0..<(allPts.count - 1) {
                            let progress = Double(i) / Double(allPts.count - 1)
                            let edgeDist = min(progress, 1 - progress) * 2
                            let width = CGFloat(0.5 + edgeDist * 7.0)
                            let alpha = 0.15 + edgeDist * 0.7
                            context.stroke(
                                Path { p in p.move(to: allPts[i]); p.addLine(to: allPts[i + 1]) },
                                with: .color(color.opacity(alpha)),
                                lineWidth: width
                            )
                        }
                    }
                }
            }
        }
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 72, height: 72)
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                .frame(width: 72, height: 72)
            Image(systemName: voiceRecognizer.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(voiceRecognizer.isRecording ? Color.blue : Color.primary)
                .scaleEffect(voiceRecognizer.isRecording ? 1.15 : 1)
                .animation(.spring(response: 0.2), value: voiceRecognizer.isRecording)
        }
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard store.isPro else {
                        isShowingPurchase = true
                        return
                    }
                    if !voiceRecognizer.isRecording {
                        voiceRecognizer.startRecording()
                    }
                }
                .onEnded { _ in
                    voiceRecognizer.stopRecording()
                }
        )
    }

    @ViewBuilder
    private var simulationLoadingView: some View {
        if isSimulating {
            VStack(spacing: 8) {
                ProgressView()
                Text(LocalizedStringKey("text_simulating"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 12))
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
            homeTeamName: homeTeam?.name ?? NSLocalizedString("team_home_default", comment: "Default home team name"),
            awayTeamName: awayTeam?.name ?? NSLocalizedString("team_away_default", comment: "Default away team name"),
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
        if snapshot.isComplete { return NSLocalizedString("period_summary_finished", comment: "Period summary when game finished") }
        if snapshot.periodIsRunning {
            return snapshot.isPaused
                ? String(format: NSLocalizedString("period_summary_paused_format", comment: "Period paused format"), snapshot.currentPeriod, snapshot.periodCount)
                : String(format: NSLocalizedString("period_summary_in_progress_format", comment: "Period in progress format"), snapshot.currentPeriod, snapshot.periodCount)
        }
        return String(format: NSLocalizedString("period_summary_format", comment: "Period summary format"), snapshot.currentPeriod, snapshot.periodCount)
    }

    private var periodButtonTitle: String {
        if snapshot.isComplete { return NSLocalizedString("period_button_finished", comment: "Period button title when game finished") }
        let action = snapshot.periodIsRunning ? NSLocalizedString("period_button_action_end", comment: "Period button action end") : NSLocalizedString("period_button_action_start", comment: "Period button action start")
        return String(format: NSLocalizedString("period_button_toggle_format", comment: "Period button format"), snapshot.currentPeriod, action)
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
                .scaleEffect(recordingIndicatorBlink ? 1.05 : 0.85)

            Text(LocalizedStringKey("label_rec"))
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.red.opacity(0.10), in: Capsule())
        .onAppear {
            recordingIndicatorBlink = true
            blinkTimer?.invalidate()
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.35)) {
                    recordingIndicatorBlink.toggle()
                }
            }
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }

    private func actionButton(_ title: LocalizedStringKey, systemImage: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        let titleKey = String(describing: title)
        return Button {
            action()
            pulseActionButton(titleKey)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(PastelActionButtonStyle(style: style))
        .scaleEffect(actionButtonPulseKey == titleKey ? 1.09 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.68), value: actionButtonPulseKey == titleKey)
        .disabled(needsNewGameSetup)
    }

    private func actionButton(_ title: String, systemImage: String, style: ActionButtonStyle, action: @escaping () -> Void) -> some View {
        actionButton(LocalizedStringKey(title), systemImage: systemImage, style: style, action: action)
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
            statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "Game already finished message")
            return
        }
        guard !snapshot.isPaused else {
            statAlertMessage = NSLocalizedString("stat_game_paused", comment: "Game paused message")
            return
        }
        guard snapshot.periodIsRunning else {
            statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: "Period not started message"), snapshot.currentPeriod)
            return
        }
        guard let player = selectedPlayer else {
            statAlertMessage = NSLocalizedString("stat_select_player_first", comment: "Please select a player message")
            return
        }
        guard isOnCourt(player.id, side: selectedSide) else { return }

        let now = Date()
        let operation = BluetoothLiveOperationPayload.record(
            action: action.liveAction,
            playerID: player.id,
            side: selectedSide.liveSide,
            at: now
        )
        let changed = submitLiveOperation(operation) {
            applyRecordOperation(action: action, playerID: player.id, side: selectedSide, at: now)
        }
        if changed {
            showRecordFeedback(action: action, side: selectedSide)
        }
    }

    private func showRecordFeedback(action: StatAction, side: TeamSide) {
        triggerTapFeedback()

        if action.points > 0 {
            Task {
                try? await Task.sleep(for: .milliseconds(60))
                triggerTapFeedback()
            }
        } else {
            return
        }
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
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred(intensity: 1)
    }

    private func checkAndAutoEndPeriod() {
        guard snapshot.periodIsRunning, !snapshot.isPaused, !snapshot.isComplete else { return }

        switch snapshot.periodEndCondition {
        case .manual:
            return
        case .byTime:
            let limit = TimeInterval(snapshot.periodTimeLimit * 60)
            guard currentPeriodElapsedSeconds >= limit else { return }
            autoEndAlertMessage = String(format: NSLocalizedString("alert_period_auto_ended_time_format", comment: "Period ended by time"), snapshot.currentPeriod)

        case .byScore:
            let homeScore = score(for: snapshot.homeTeamID)
            let awayScore = score(for: snapshot.awayTeamID)
            let scoreThreshold = snapshot.periodScoreLimit * snapshot.currentPeriod
            guard homeScore >= scoreThreshold || awayScore >= scoreThreshold else { return }
            autoEndAlertMessage = String(format: NSLocalizedString("alert_period_auto_ended_score_format", comment: "Period ended by score"), snapshot.currentPeriod)
        }

        let now = Date()
        applyTogglePeriodOperation(at: now)
        showAutoEndAlert = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
            collaborationAlertMessage = NSLocalizedString("collab_invite_before_new_game", comment: "Prompt user to create a new game before inviting")
            return
        }
        guard !needsNewGameSetup else {
            collaborationAlertMessage = NSLocalizedString("collab_invite_complete_lineup", comment: "Prompt user to complete lineup before inviting collab")
            return
        }
        guard !bluetooth.connectedPeers.isEmpty else {
            collaborationAlertMessage = NSLocalizedString("collab_no_connected_devices", comment: "Prompt to connect devices in settings before inviting")
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
            collaborationAlertMessage = NSLocalizedString("collab_invite_send_failed", comment: "Invite send failed message")
            return
        }

        activeLiveSessionID = sessionID
        collaborationAlertMessage = NSLocalizedString("collab_invite_sent_waiting", comment: "Invite sent, waiting message")
    }

    private func handleInviteResponse(_ response: BluetoothReceivedInviteResponse) {
        guard response.payload.sessionID == activeLiveSessionID else { return }
        if response.payload.accepted {
            bluetooth.noteAcceptedLiveSession(sessionID: response.payload.sessionID, with: response.fromPeerName)
            liveParticipantNames.insert(response.fromPeerName)
            sendAuthoritativeSnapshot(reason: "New device joined")
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
            sendAuthoritativeSnapshot(reason: "Version mismatch, triggering resync", to: [incoming.fromPeerID])
            return
        }

        let applied = applyLiveOperationPayload(incoming.payload.op.payload)
        guard applied else {
            sendAuthoritativeSnapshot(reason: "Operation could not be applied, triggering resync", to: [incoming.fromPeerID])
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

        sendAuthoritativeSnapshot(reason: "Resync request received", to: [incoming.fromPeerID])
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
                collaborationAlertMessage = NSLocalizedString("collab_operation_send_failed", comment: "Operation send failed")
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
        guard !snapshot.isComplete else {
            statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "Game already finished message")
            return
        }
        guard snapshot.periodIsRunning else {
            statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: "Period not started message"), snapshot.currentPeriod)
            return
        }
        let now = Date()
        _ = submitLiveOperation(.togglePause(at: now)) {
            applyTogglePauseOperation(at: now)
        }
    }

    @discardableResult
    private func applyLiveOperationPayload(_ payload: BluetoothLiveOperationPayload) -> Bool {
        switch payload {
        case let .record(action, playerID, side, at):
            guard let statAction = StatAction(liveAction: action) else { return false }
            return applyRecordOperation(action: statAction, playerID: playerID, side: TeamSide(liveSide: side), at: at)

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
            // Try action-based undo first (revert last log)
            let now = Date()
            var redoSnapshot = snapshot
            closeActiveStints(in: &redoSnapshot, at: now)
            closeMatchClock(in: &redoSnapshot, at: now)
            closePeriodClock(in: &redoSnapshot, at: now)
            redoStack.append(redoSnapshot)

            if revertLastAction() {
                autoSaveCurrentGame()
                return true
            }
            redoStack.removeLast()
            return false

        case .redo:
            guard let next = redoStack.popLast() else { return false }
            undoStack.append(snapshot)
            if undoStack.count > 30 { undoStack.removeFirst(undoStack.count - 30) }
            snapshot = next
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    @discardableResult
    func applyRecordOperation(action: StatAction, playerID: UUID, side: TeamSide, at: Date? = nil) -> Bool {
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
            addEvent("\(name(for: playerID)) \(action.message)", playerID: playerID, eventCode: action.eventCode, at: at)
        }
        if action.points > 0, snapshot.periodEndCondition == .byScore {
            checkAndAutoEndPeriod()
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
                addEvent(
                    String(format: NSLocalizedString("event_period_end_format", comment: "Period end event format"), snapshot.currentPeriod),
                    eventCode: "event.period_end"
                )
                snapshot.periodIsRunning = false
                snapshot.isPaused = false
                if snapshot.currentPeriod >= snapshot.periodCount {
                    snapshot.isComplete = true
                    addEvent(NSLocalizedString("event_game_end", comment: "Game end event"), eventCode: "event.game_end")
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
                    addEvent(
                        String(format: NSLocalizedString("event_starters_home_format", comment: "Home starters event format"), names(for: snapshot.homeOnCourtPlayerIDs)),
                        eventCode: "event.starters_home"
                    )
                    addEvent(
                        String(format: NSLocalizedString("event_starters_away_format", comment: "Away starters event format"), names(for: snapshot.awayOnCourtPlayerIDs)),
                        eventCode: "event.starters_away"
                    )
                    snapshot.startersRecorded = true
                }
                snapshot.periodElapsedSeconds = 0
                snapshot.periodActiveSince = nil
                addEvent(
                    String(format: NSLocalizedString("event_period_start_format", comment: "Period start event format"), snapshot.currentPeriod),
                    eventCode: "event.period_start"
                )
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
                addEvent(NSLocalizedString("event_game_resumed", comment: "Game resumed event"), eventCode: "event.resume")
            } else {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                snapshot.isPaused = true
                addEvent(NSLocalizedString("event_game_paused", comment: "Game paused event"), eventCode: "event.pause")
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

            addEvent(
                String(
                    format: NSLocalizedString("event_substitution_format", comment: "Substitution event format"),
                    name(for: incomingPlayerID),
                    name(for: outgoingPlayerID)
                ),
                playerID: incomingPlayerID,
                relatedPlayerID: outgoingPlayerID,
                eventCode: "event.substitution"
            )
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
            addEvent(
                String(format: NSLocalizedString("event_late_arrival_format", comment: "Late arrival event format"), name(for: playerID)),
                eventCode: "event.late_arrival"
            )
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
            addEvent(NSLocalizedString("event_game_end", comment: "Game end event"), eventCode: "event.game_end")
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

    private func startNewGame(with config: GameSetupConfig) {
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
            homeTeamID: config.homeTeamID,
            awayTeamID: config.awayTeamID,
            periodCount: config.periodCount,
            courtPlayerCount: config.courtPlayerCount,
            resetsTeamFoulsEachPeriod: config.resetsTeamFoulsEachPeriod,
            showsReboundButton: config.showsReboundButton,
            showsAssistButton: config.showsAssistButton,
            showsFoulButton: config.showsFoulButton,
            showsBlockButton: config.showsBlockButton,
            showsStealButton: config.showsStealButton,
            showsTurnoverButton: config.showsTurnoverButton,
            homeOnCourtPlayerIDs: config.homeStarterIDs,
            awayOnCourtPlayerIDs: config.awayStarterIDs,
            homeAvailablePlayerIDs: unique(config.homeStarterIDs + config.homeBenchIDs),
            awayAvailablePlayerIDs: unique(config.awayStarterIDs + config.awayBenchIDs),
            periodEndCondition: config.periodEndCondition,
            periodTimeLimit: config.periodTimeLimit,
            periodScoreLimit: config.periodScoreLimit
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
        saveConfirmation = NSLocalizedString("game_saved_to_history", comment: "Saved to history confirmation")
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
            simulationAlertMessage = NSLocalizedString("simulate_need_two_teams_with_players", comment: "Need two teams with players to simulate")
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

        func appendEvent(_ message: String, playerID: UUID? = nil, relatedPlayerID: UUID? = nil, eventCode: String? = nil) {
            simulated.logs.append(
                GameLogEntry(
                    timestamp: eventTime,
                    message: "\(message) \(scoreSuffix())",
                    eventCode: eventCode,
                    playerID: playerID,
                    relatedPlayerID: relatedPlayerID,
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
            appendEvent("\(name(for: foulerID)) \(StatAction.foul.message)", playerID: foulerID, eventCode: StatAction.foul.eventCode)
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
            appendEvent("\(name(for: rebounderID)) \(StatAction.rebound.message)", playerID: rebounderID, eventCode: StatAction.rebound.eventCode)
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
            appendEvent(
                String(
                    format: NSLocalizedString("event_substitution_format", comment: "Substitution event format"),
                    name(for: incomingID),
                    name(for: outgoingID)
                ),
                playerID: incomingID,
                relatedPlayerID: outgoingID,
                eventCode: "event.substitution"
            )
        }

        func addBlockEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let blockerID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[blockerID, default: PlayerStats()]
            stats.blocks += 1
            simulated.statsByPlayerID[blockerID] = stats
            appendEvent("\(name(for: blockerID)) \(StatAction.block.message)", playerID: blockerID, eventCode: StatAction.block.eventCode)
        }

        func addStealEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let stealerID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[stealerID, default: PlayerStats()]
            stats.steals += 1
            simulated.statsByPlayerID[stealerID] = stats
            appendEvent("\(name(for: stealerID)) \(StatAction.steal.message)", playerID: stealerID, eventCode: StatAction.steal.eventCode)
        }

        func addTurnoverEvent() {
            let side: TeamSide = Double.random(in: 0...1) < 0.5 ? .home : .away
            guard let turnoverID = randomOnCourtPlayerID(for: side) else { return }
            var stats = simulated.statsByPlayerID[turnoverID, default: PlayerStats()]
            stats.turnovers += 1
            simulated.statsByPlayerID[turnoverID] = stats
            appendEvent("\(name(for: turnoverID)) \(StatAction.turnover.message)", playerID: turnoverID, eventCode: StatAction.turnover.eventCode)
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
                let action: StatAction = isMade ? .threeMade : .threeMissed
                appendEvent("\(name(for: shooterID)) \(action.message)", playerID: shooterID, eventCode: action.eventCode)
                if isMade {
                    applyPlusMinus(points: 3, scoringSide: side, in: &simulated)
                }
            } else {
                stats.twoAttempts += 1
                if isMade { stats.twoMade += 1 }
                simulated.statsByPlayerID[shooterID] = stats
                let action: StatAction = isMade ? .twoMade : .twoMissed
                appendEvent("\(name(for: shooterID)) \(action.message)", playerID: shooterID, eventCode: action.eventCode)
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
                appendEvent("\(name(for: assistID)) \(StatAction.assist.message)", playerID: assistID, eventCode: StatAction.assist.eventCode)
            }

            if isMade, Double.random(in: 0...1) < 0.12 {
                var bonusStats = simulated.statsByPlayerID[shooterID, default: PlayerStats()]
                bonusStats.bonusFreeThrowAttempts += 1
                let bonusMade = Double.random(in: 0...1) < 0.7
                if bonusMade {
                    bonusStats.bonusFreeThrowMade += 1
                }
                simulated.statsByPlayerID[shooterID] = bonusStats
                appendEvent(
                    "\(name(for: shooterID)) \(bonusMade ? StatAction.bonusMade.message : StatAction.bonusMissed.message)",
                    playerID: shooterID,
                    eventCode: bonusMade ? StatAction.bonusMade.eventCode : StatAction.bonusMissed.eventCode
                )
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
                appendEvent(
                    String(format: NSLocalizedString("event_starters_home_format", comment: "Home starters event format"), names(for: simulated.homeOnCourtPlayerIDs)),
                    eventCode: "event.starters_home"
                )
                appendEvent(
                    String(format: NSLocalizedString("event_starters_away_format", comment: "Away starters event format"), names(for: simulated.awayOnCourtPlayerIDs)),
                    eventCode: "event.starters_away"
                )
                simulated.startersRecorded = true
            }

            appendEvent(
                String(format: NSLocalizedString("event_period_start_format", comment: "Period start event format"), period),
                eventCode: "event.period_start"
            )

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
            appendEvent(
                String(format: NSLocalizedString("event_period_end_format", comment: "Period end event format"), period),
                eventCode: "event.period_end"
            )
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
        appendEvent(NSLocalizedString("event_game_end", comment: "Game end event"), eventCode: "event.game_end")

        undoStack.removeAll()
        redoStack.removeAll()
        currentGameRecordID = UUID()
        snapshot = simulated
        selectedPlayerID = snapshot.homeOnCourtPlayerIDs.first
        selectedSide = .home
        ensureSelectedPlayer()
        autoSaveCurrentGame()
        saveConfirmation = NSLocalizedString("game_saved_to_history", comment: "Saved to history confirmation")
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
            if redoStack.count > 30 { redoStack.removeFirst(redoStack.count - 30) }
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
            if undoStack.count > 30 { undoStack.removeFirst(undoStack.count - 30) }
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
        if pushUndo {
            undoStack.append(snapshot)
            if undoStack.count > 30 { undoStack.removeFirst(undoStack.count - 30) }
        }
        redoStack.removeAll()
        updates()
        autoSaveCurrentGame()
    }

    private func addEvent(_ message: String, playerID: UUID? = nil, relatedPlayerID: UUID? = nil, eventCode: String? = nil, at: Date? = nil) {
        let context = eventPeriodContext(for: message, eventCode: eventCode)
        let fullMessage = "\(message) \(scoreSuffix)"
        let logEntry = GameLogEntry(
            timestamp: at ?? Date(),
            message: fullMessage,
            eventCode: eventCode,
            playerID: playerID,
            relatedPlayerID: relatedPlayerID,
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

    private func eventPeriodContext(for message: String, eventCode: String?) -> (period: Int?, periodElapsedSeconds: TimeInterval?) {
        let nonPeriodEventCodes: Set<String> = ["event.game_end", "event.game_saved"]
        let nonPeriodMessages: Set<String> = [
            NSLocalizedString("event_game_end", comment: "Game end event"),
            NSLocalizedString("event_game_saved", comment: "Game saved event")
        ]

        if let eventCode,
           nonPeriodEventCodes.contains(eventCode) {
            return (nil, nil)
        }

        guard !nonPeriodMessages.contains(message), snapshot.currentPeriod > 0 else {
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
        var snapshotForSaving = snapshot
        if activeLiveSessionID != nil {
            snapshotForSaving.wasBluetoothCollaborated = true
        }
        if snapshotForSaving.logs.isEmpty {
            guard let currentGameRecordID,
                  store.savedGames.contains(where: { $0.id == currentGameRecordID }) else {
                return
            }
            self.currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: undoStack)
            return
        }
        currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: undoStack)
    }

    private func restoreLatestGameIfNeeded() {
        guard !hasRestoredLatestGame else { return }
        hasRestoredLatestGame = true

        if let latest = store.latestUnfinishedGame() {
            snapshot = latest.snapshot
            undoStack = []
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

    /// Revert the last action directly on the current snapshot. Returns true if successful.
    @discardableResult
    private func revertLastAction() -> Bool {
        guard let lastLog = snapshot.logs.last else { return false }
        let normalizedMessage = normalizedLogMessage(lastLog.message)
        let lastEventCode = lastLog.eventCode ?? GameLogFormatter.extractEventCode(from: lastLog.message)

        snapshot.logs.removeLast()

        switch lastEventCode {
        case "event.game_saved":
            return true

        case "event.game_end":
            snapshot.isComplete = false
            return true

        case "event.substitution":
            guard let incomingID = lastLog.playerID else { return false }
            guard let side = sideOfPlayer(incomingID, in: snapshot) else { return false }
            let outgoingID: UUID
            if let storedOutgoingID = lastLog.relatedPlayerID {
                outgoingID = storedOutgoingID
            } else {
                let message = lastLog.message
                let incomingName = name(for: incomingID)
                let allPlayers = players(in: snapshot.homeTeamID) + players(in: snapshot.awayTeamID)
                let playerNames = allPlayers.filter { $0.id != incomingID && message.contains($0.name) }
                if let outgoingMatch = playerNames.max(by: { $0.name.count < $1.name.count }) {
                    outgoingID = outgoingMatch.id
                } else {
                    return false
                }
            }
            // Swap back: remove incoming, add outgoing
            if side == .home {
                snapshot.homeOnCourtPlayerIDs.removeAll { $0 == incomingID }
                if !snapshot.homeOnCourtPlayerIDs.contains(outgoingID) {
                    snapshot.homeOnCourtPlayerIDs.append(outgoingID)
                }
            } else {
                snapshot.awayOnCourtPlayerIDs.removeAll { $0 == incomingID }
                if !snapshot.awayOnCourtPlayerIDs.contains(outgoingID) {
                    snapshot.awayOnCourtPlayerIDs.append(outgoingID)
                }
            }
            return true

        case "event.period_start":
            // Revert starting a period: period was ended, just mark it not running
            snapshot.periodIsRunning = false
            snapshot.periodElapsedSeconds = 0
            snapshot.periodActiveSince = nil
            return true

        case "event.period_end":
            // Revert ending a period: period was running, mark it running again
            if snapshot.currentPeriod > 1 {
                snapshot.currentPeriod -= 1
            }
            snapshot.periodIsRunning = true
            return true

        case "event.late_arrival":
            // Remove the late-arriving player from team roster
            guard let playerID = lastLog.playerID else { return false }
            if snapshot.homeAvailablePlayerIDs.contains(playerID) {
                snapshot.homeAvailablePlayerIDs.removeAll { $0 == playerID }
            } else if snapshot.awayAvailablePlayerIDs.contains(playerID) {
                snapshot.awayAvailablePlayerIDs.removeAll { $0 == playerID }
            }
            return true

        default:
            let parsed = StatAction.parseLog(normalizedMessage)
            guard let action = StatAction.allCases.first(where: { $0.eventCode == lastEventCode }) ?? parsed?.action else {
                return false
            }

            guard let playerID = lastLog.playerID
                    ?? parsed.flatMap({ playerID(for: $0.playerName, action: action, in: snapshot) }),
                  let side = sideOfPlayer(playerID, in: snapshot) else {
                return false
            }

            var stats = snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            guard action.revert(on: &stats) else { return false }
            snapshot.statsByPlayerID[playerID] = stats

            if action == .foul {
                let currentFouls = snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0]
                snapshot.currentPeriodFoulsBySide[side.rawValue] = max(0, currentFouls - 1)
            }

            if action.points > 0 {
                applyPlusMinus(points: -action.points, scoringSide: side, in: &snapshot)
            }

            return true
        }
    }

    private func normalizedLogMessage(_ message: String) -> String {
        GameLogFormatter.normalizedMessage(message)
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
        store.player(for: playerID)?.name ?? NSLocalizedString("unknown_player", comment: "Unknown player fallback")
    }

    private func names(for playerIDs: [UUID]) -> String {
        let names = playerIDs.map { name(for: $0) }
        guard !names.isEmpty else { return NSLocalizedString("text_not_set", comment: "Not set fallback") }
        return ListFormatter.localizedString(byJoining: names)
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
        guard let elapsedSeconds else {
            return String(format: NSLocalizedString("period_context_only_format", comment: "Period context without elapsed time"), period)
        }
        return String(
            format: NSLocalizedString("period_context_with_time_format", comment: "Period context with elapsed time"),
            period,
            durationFormatter(elapsedSeconds)
        )
    }

    private func logText(for entry: GameLogEntry) -> String {
        let periodText = Self.periodContextText(period: entry.period, elapsedSeconds: entry.periodElapsedSeconds)
        return [Self.timeFormatter.string(from: entry.timestamp), periodText, entry.message]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

