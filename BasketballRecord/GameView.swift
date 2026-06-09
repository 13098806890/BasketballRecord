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
                    guard snapshot.periodIsRunning else {
                        statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: ""), snapshot.currentPeriod + 1)
                        return
                    }
                    self.applyRecordOperation(action: action, playerID: playerID, side: side, at: clockNow)
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
                .disabled(!snapshot.periodIsRunning || snapshot.isComplete)
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
        TimelineView(.animation(minimumInterval: 0.06)) { timeline in
            WaveView(time: timeline.date)
        }
        .frame(width: UIScreen.main.bounds.width * 0.5, height: 100)
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private struct WaveView: View {
        let time: Date
        var body: some View {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let midY = h / 2
                let phase = time.timeIntervalSinceReferenceDate * 5
                let barCount = max(Int(w / 8), 12)
                let barSpacing: CGFloat = 6
                let barW = (w - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount)

                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { i in
                        let angle = Double(i) / Double(barCount) * .pi * 3 + phase
                        let barH = max(4, CGFloat((sin(angle) * 0.5 + 0.5)) * h * 0.8)
                        RoundedRectangle(cornerRadius: barW / 2)
                            .fill(.blue.opacity(0.8))
                            .frame(width: max(2, barW), height: barH)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: 72, height: 72)
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                .frame(width: 72, height: 72)
            Image(systemName: voiceRecognizer.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(voiceRecognizer.isRecording ? Color.blue : Color.primary)
                .scaleEffect(voiceRecognizer.isRecording ? 1.15 : 1)
                .animation(.spring(response: 0.2), value: voiceRecognizer.isRecording)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
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
        guard snapshot.periodIsRunning, !snapshot.isComplete else { return }
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
                let playerNames = allPlayers.map(\.name).filter { $0 != incomingName && message.contains($0) }
                if let outgoingName = playerNames.max(by: { $0.count < $1.count }) {
                    outgoingID = allPlayers.first(where: { $0.name == outgoingName })!.id
                } else {
                    guard let range = message.range(of: " 替换 ") ?? message.range(of: " vs ") else { return false }
                    let outgoingName = String(message[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    guard let resolvedID = playerID(for: outgoingName, action: .turnover, in: snapshot) else { return false }
                    outgoingID = resolvedID
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

enum TeamSide: String {
    case home = "主队"
    case away = "客队"
}

extension TeamSide: CaseIterable, Identifiable {
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:
            return NSLocalizedString("team_home_default", comment: "Home team")
        case .away:
            return NSLocalizedString("team_away_default", comment: "Away team")
        }
    }
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
    static let make = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.40, blue: 0.20, alpha: 1) : UIColor(red: 0.78, green: 0.93, blue: 0.78, alpha: 1)
    })
    static let miss = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.30, blue: 0.45, alpha: 1) : UIColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1)
    })
    static let assist = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.28, blue: 0.45, alpha: 1) : UIColor(red: 0.74, green: 0.86, blue: 0.98, alpha: 1)
    })
    static let rebound = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.32, blue: 0.48, alpha: 1) : UIColor(red: 0.80, green: 0.90, blue: 0.99, alpha: 1)
    })
    static let warning = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.45, green: 0.18, blue: 0.18, alpha: 1) : UIColor(red: 0.96, green: 0.80, blue: 0.80, alpha: 1)
    })
    static let period = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.40, blue: 0.70, alpha: 1) : UIColor(red: 0.36, green: 0.63, blue: 0.95, alpha: 1)
    })
    static let periodEnd = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.30, blue: 0.18, alpha: 1) : UIColor(red: 0.96, green: 0.72, blue: 0.63, alpha: 1)
    })
    static let substitution = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.38, blue: 0.68, alpha: 1) : UIColor(red: 0.42, green: 0.67, blue: 0.95, alpha: 1)
    })
    static let pause = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.50, green: 0.38, blue: 0.12, alpha: 1) : UIColor(red: 0.98, green: 0.82, blue: 0.45, alpha: 1)
    })
    static let finish = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.18, blue: 0.12, alpha: 1) : UIColor(red: 0.95, green: 0.48, blue: 0.44, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1) : UIColor(red: 0.96, green: 0.98, blue: 1.00, alpha: 1)
    })
    static let selectedBorder = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.50, green: 0.70, blue: 0.95, alpha: 1) : UIColor(red: 0.25, green: 0.55, blue: 0.90, alpha: 1)
    })
    static let onCourtBorder = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1) : UIColor(red: 0.45, green: 0.69, blue: 0.93, alpha: 1)
    })
    static let text = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1) : UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1)
    })
}

private enum ActionButtonStyle {
    case made, missed, assist, rebound, warning, substitution, pause, period, periodEnd, neutral

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
        case .neutral: return Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(red: 0.25, green: 0.26, blue: 0.30, alpha: 1) : UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1)
        })
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

enum StatAction {
    case twoMade, twoMissed, threeMade, threeMissed
    case bonusMade, bonusMissed, freeThrowMade, freeThrowMissed
    case foul, assist, rebound, block, steal, turnover
    case layupMade, layupMissed, midRangeMade, midRangeMissed, paintMade, paintMissed

    var eventCode: String {
        switch self {
        case .twoMade: return "stat.twoMade"
        case .twoMissed: return "stat.twoMissed"
        case .threeMade: return "stat.threeMade"
        case .threeMissed: return "stat.threeMissed"
        case .bonusMade: return "stat.bonusMade"
        case .bonusMissed: return "stat.bonusMissed"
        case .freeThrowMade: return "stat.freeThrowMade"
        case .freeThrowMissed: return "stat.freeThrowMissed"
        case .foul: return "stat.foul"
        case .assist: return "stat.assist"
        case .rebound: return "stat.rebound"
        case .block: return "stat.block"
        case .steal: return "stat.steal"
        case .turnover: return "stat.turnover"
        case .layupMade: return "stat.layupMade"
        case .layupMissed: return "stat.layupMissed"
        case .midRangeMade: return "stat.midRangeMade"
        case .midRangeMissed: return "stat.midRangeMissed"
        case .paintMade: return "stat.paintMade"
        case .paintMissed: return "stat.paintMissed"
        }
    }

    var messageKey: String {
        switch self {
        case .twoMade: return "action_two_made"
        case .twoMissed: return "action_two_missed"
        case .threeMade: return "action_three_made"
        case .threeMissed: return "action_three_missed"
        case .bonusMade: return "action_bonus_made"
        case .bonusMissed: return "action_bonus_missed"
        case .freeThrowMade: return "action_free_made"
        case .freeThrowMissed: return "action_free_missed"
        case .foul: return "action_foul"
        case .assist: return "action_assist"
        case .rebound: return "action_rebound"
        case .block: return "action_block"
        case .steal: return "action_steal"
        case .turnover: return "action_turnover"
        case .layupMade: return "action_layup_made"
        case .layupMissed: return "action_layup_missed"
        case .midRangeMade: return "action_mid_range_made"
        case .midRangeMissed: return "action_mid_range_missed"
        case .paintMade: return "action_paint_made"
        case .paintMissed: return "action_paint_missed"
        }
    }

    var message: String {
        NSLocalizedString(messageKey, comment: "")
    }

    var points: Int {
        switch self {
        case .twoMade, .layupMade, .midRangeMade, .paintMade: return 2
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
        case .layupMade:
            stats.layupMade += 1; stats.layupAttempts += 1
            stats.twoMade += 1; stats.twoAttempts += 1
        case .layupMissed:
            stats.layupAttempts += 1; stats.twoAttempts += 1
        case .midRangeMade:
            stats.midRangeMade += 1; stats.midRangeAttempts += 1
            stats.twoMade += 1; stats.twoAttempts += 1
        case .midRangeMissed:
            stats.midRangeAttempts += 1; stats.twoAttempts += 1
        case .paintMade:
            stats.paintMade += 1; stats.paintAttempts += 1
            stats.twoMade += 1; stats.twoAttempts += 1
        case .paintMissed:
            stats.paintAttempts += 1; stats.twoAttempts += 1
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
        case .layupMade:
            guard stats.layupMade > 0, stats.layupAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.layupMade -= 1; stats.layupAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .layupMissed:
            guard stats.layupAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.layupAttempts -= 1; stats.twoAttempts -= 1
        case .midRangeMade:
            guard stats.midRangeMade > 0, stats.midRangeAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.midRangeMade -= 1; stats.midRangeAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .midRangeMissed:
            guard stats.midRangeAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.midRangeAttempts -= 1; stats.twoAttempts -= 1
        case .paintMade:
            guard stats.paintMade > 0, stats.paintAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.paintMade -= 1; stats.paintAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .paintMissed:
            guard stats.paintAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.paintAttempts -= 1; stats.twoAttempts -= 1
        }
        return true
    }

    static func parseLog(_ message: String, eventCode: String? = nil) -> (playerName: String, action: StatAction)? {
        if let eventCode = eventCode ?? GameLogFormatter.extractEventCode(from: message),
           let action = allCases.first(where: { $0.eventCode == eventCode }) {
            let normalized = GameLogFormatter.normalizedMessage(message)
            guard normalized.hasSuffix(action.message) else { return nil }
            let name = String(normalized.dropLast(action.message.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, action)
        }

        let normalized = GameLogFormatter.normalizedMessage(message)
        for action in allCases {
            guard normalized.hasSuffix(action.message) else { continue }
            let name = String(normalized.dropLast(action.message.count)).trimmingCharacters(in: .whitespacesAndNewlines)
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
        case .layupMade, .midRangeMade, .paintMade: return .twoMade
        case .layupMissed, .midRangeMissed, .paintMissed: return .twoMissed
        }
    }
}

extension StatAction: Equatable {}

extension StatAction: CaseIterable {
    static var allCases: [StatAction] {
        [.twoMade, .twoMissed, .threeMade, .threeMissed, .bonusMade, .bonusMissed, .freeThrowMade, .freeThrowMissed, .foul, .assist, .rebound, .block, .steal, .turnover, .layupMade, .layupMissed, .midRangeMade, .midRangeMissed, .paintMade, .paintMissed]
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
                HStack(spacing: 4) {
                    Text(team?.name ?? side.displayName)
                        .font(.caption.weight(.semibold))
                    Text(side == .home ? "(主队)" : "(客队)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
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
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                        Text("\(fouls)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .frame(maxWidth: 48, alignment: .leading)
                    .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            if players.isEmpty {
                Text(LocalizedStringKey("text_no_players"))
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
                                    Text(player.number.isEmpty ? player.name : "\(player.number) \(player.name)")
                                        .font(.caption2)
                                        .foregroundStyle(onCourtPlayerIDs.contains(player.id) ? .primary : .secondary)
                                        .lineLimit(1)
                                        .frame(width: 64)
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
            VStack(spacing: 6) {
                HStack {
                    Text(homeName)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(String(format: NSLocalizedString("stats_points_format", comment: "Points format"), homeStats.points))
                        .font(.title.monospacedDigit().weight(.bold))
                    Text("vs")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: NSLocalizedString("stats_points_format", comment: "Points format"), awayStats.points))
                        .font(.title.monospacedDigit().weight(.bold))
                    Spacer()
                    Text(awayName)
                        .font(.caption.weight(.semibold))
                }
                .padding(.bottom, 4)

                compareRow(label: localized("stats_field_goal"),
                           home: "\(homeStats.made)/\(homeStats.attempts)", homePct: percent(homeStats.fieldGoalRate),
                           away: "\(awayStats.made)/\(awayStats.attempts)", awayPct: percent(awayStats.fieldGoalRate))
                compareRow(label: localized("stat_label_2pt"),
                           home: "\(homeStats.twoMade)/\(homeStats.twoAttempts)", homePct: percent(homeStats.twoPointRate),
                           away: "\(awayStats.twoMade)/\(awayStats.twoAttempts)", awayPct: percent(awayStats.twoPointRate))
                compareRow(label: localized("stat_label_3pt"),
                           home: "\(homeStats.threeMade)/\(homeStats.threeAttempts)", homePct: percent(homeStats.threePointRate),
                           away: "\(awayStats.threeMade)/\(awayStats.threeAttempts)", awayPct: percent(awayStats.threePointRate))
                compareRow(label: localized("stat_label_free_throw"),
                           home: "\(homeStats.allFreeThrowMade)/\(homeStats.allFreeThrowAttempts)", homePct: percent(homeStats.freeThrowRate),
                           away: "\(awayStats.allFreeThrowMade)/\(awayStats.allFreeThrowAttempts)", awayPct: percent(awayStats.freeThrowRate))
                compareRow(label: "\(localized("stats_rebound_assist_steal_block")) / \(localized("stats_foul_turnover"))",
                           home: "\(homeStats.rebounds)/\(homeStats.assists)/\(homeStats.steals)/\(homeStats.blocks) · \(homeFouls)/\(homeStats.turnovers)",
                           homePct: nil,
                           away: "\(awayStats.rebounds)/\(awayStats.assists)/\(awayStats.steals)/\(awayStats.blocks) · \(awayFouls)/\(awayStats.turnovers)",
                           awayPct: nil)
                compareRow(label: "eFG / TS",
                           home: "\(percent(homeStats.effectiveFieldGoalRate)) / \(percent(homeStats.trueShootingRate))",
                           homePct: nil,
                           away: "\(percent(awayStats.effectiveFieldGoalRate)) / \(percent(awayStats.trueShootingRate))",
                           awayPct: nil)
                compareRow(label: localized("stats_points_per_shot"),
                           home: String(format: "%.2f", homeStats.pointsPerShot),
                           homePct: nil,
                           away: String(format: "%.2f", awayStats.pointsPerShot),
                           awayPct: nil)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        } label: {
            HStack {
                Text(LocalizedStringKey("label_team_stats"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(homeStats.points)-\(awayStats.points)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compareRow(label: String, home: String, homePct: String?, away: String, awayPct: String?) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(home)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let homePct {
                    Text(homePct)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: 64)

            VStack(alignment: .leading, spacing: 1) {
                Text(away)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let awayPct {
                    Text(awayPct)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
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
                    statTile(NSLocalizedString("stats_field_goal", comment: "Field goal"), "\(stats.made)/\(stats.attempts)", percent(stats.fieldGoalRate))
                    statTile(NSLocalizedString("stats_two_point", comment: "Two-point"), "\(stats.twoMade)/\(stats.twoAttempts)", percent(stats.twoPointRate))
                    statTile(NSLocalizedString("stats_three_point", comment: "Three-point"), "\(stats.threeMade)/\(stats.threeAttempts)", percent(stats.threePointRate))
                }

                HStack(spacing: 8) {
                    statTile(NSLocalizedString("stats_free_throw", comment: "Free throw"), "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)", percent(stats.freeThrowRate))
                    statTile(NSLocalizedString("stats_full_misc_format", comment: "Rebounds assists fouls blocks steals turnovers"), "\(stats.rebounds) / \(stats.assists) / \(stats.fouls) / \(stats.blocks) / \(stats.steals) / \(stats.turnovers)", "")
                    statTile(NSLocalizedString("stats_advanced", comment: "Advanced stats"), "eFG \(percent(stats.effectiveFieldGoalRate))", "TS \(percent(stats.trueShootingRate))")
                }

                HStack(spacing: 8) {
                    statTile(NSLocalizedString("stats_points_per_shot", comment: "Points per shot"), pointsPerShotText, "PTS/FGA")
                    statTile(NSLocalizedString("stats_plus_minus", comment: "Plus minus"), plusMinusText, NSLocalizedString("stats_plus_minus_footnote", comment: "Plus minus footnote"))
                    statTile(NSLocalizedString("stats_playing_time", comment: "Playing time"), playingTime, "")
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Text(player?.name ?? NSLocalizedString("select_player", comment: "Select player"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: NSLocalizedString("stats_points_format", comment: "Points format"), stats.points))
                Text(playingTime)
                Text(String(format: NSLocalizedString("stats_rebound_short_format", comment: "Rebound short format"), stats.rebounds))
                Text(String(format: NSLocalizedString("stats_assist_short_format", comment: "Assist short format"), stats.assists))
                Text(String(format: NSLocalizedString("stats_foul_short_format", comment: "Foul short format"), stats.fouls))
                Text(String(format: NSLocalizedString("stats_block_short_format", comment: "Block short format"), stats.blocks))
                Text(String(format: NSLocalizedString("stats_steal_short_format", comment: "Steal short format"), stats.steals))
                Text(String(format: NSLocalizedString("stats_turnover_short_format", comment: "Turnover short format"), stats.turnovers))
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
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct GameSetupConfig {
    var homeTeamID: UUID
    var awayTeamID: UUID
    var homeStarterIDs: [UUID]
    var awayStarterIDs: [UUID]
    var homeBenchIDs: [UUID]
    var awayBenchIDs: [UUID]
    var periodCount: Int
    var courtPlayerCount: Int
    var resetsTeamFoulsEachPeriod: Bool
    var showsReboundButton: Bool
    var showsAssistButton: Bool
    var showsFoulButton: Bool
    var showsBlockButton: Bool
    var showsStealButton: Bool
    var showsTurnoverButton: Bool
    var periodEndCondition: PeriodEndCondition
    var periodTimeLimit: Int
    var periodScoreLimit: Int
}

private struct NewGameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var teams: [Team]
    var playersForTeam: (UUID?) -> [Player]
    var initialHomeTeamID: UUID?
    var initialAwayTeamID: UUID?
    var onStart: (GameSetupConfig) -> Void

    @State private var homeTeamID: UUID?
    @State private var awayTeamID: UUID?
    @State private var homeStarterIDs: [UUID] = []
    @State private var awayStarterIDs: [UUID] = []
    @State private var homeBenchIDs: [UUID] = []
    @State private var awayBenchIDs: [UUID] = []
    @AppStorage("setup_period_count") private var periodCount = 4
    @AppStorage("setup_court_player_count") private var courtPlayerCount = 4
    @AppStorage("setup_reset_fouls") private var resetsTeamFoulsEachPeriod = true
    @AppStorage("setup_show_rebound") private var showsReboundButton = true
    @AppStorage("setup_show_assist") private var showsAssistButton = true
    @AppStorage("setup_show_foul") private var showsFoulButton = true
    @AppStorage("setup_show_block") private var showsBlockButton = true
    @AppStorage("setup_show_steal") private var showsStealButton = true
    @AppStorage("setup_show_turnover") private var showsTurnoverButton = true
    @AppStorage("setup_period_end_condition") private var periodEndCondition = PeriodEndCondition.byTime
    @AppStorage("setup_period_time_limit") private var periodTimeLimit = 12
    @AppStorage("setup_period_score_limit") private var periodScoreLimit = 30

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_teams")) {
                    Picker(LocalizedStringKey("picker_home_team"), selection: $homeTeamID) {
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                    Picker(LocalizedStringKey("picker_away_team"), selection: $awayTeamID) {
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                }

                starterSection(title: NSLocalizedString("starter_home_title", comment: "Home starters"), players: homePlayers, selectedIDs: $homeStarterIDs, requiredCount: requiredHomeCount)
                benchSection(
                    title: NSLocalizedString("starter_home_bench_title", comment: "Home bench title"),
                    players: homeBenchCandidates,
                    selectedIDs: $homeBenchIDs
                )

                starterSection(title: NSLocalizedString("starter_away_title", comment: "Away starters"), players: awayPlayers, selectedIDs: $awayStarterIDs, requiredCount: requiredAwayCount)
                benchSection(
                    title: NSLocalizedString("starter_away_bench_title", comment: "Away bench title"),
                    players: awayBenchCandidates,
                    selectedIDs: $awayBenchIDs
                )

                Section(LocalizedStringKey("section_game_settings")) {
                    Stepper(value: $periodCount, in: 1...8) {
                        HStack {
                            Text(LocalizedStringKey("label_period_count"))
                            Spacer()
                            Text(String(format: NSLocalizedString("count_periods_format", comment: "Periods count"), periodCount))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $courtPlayerCount, in: 1...8) {
                        HStack {
                            Text(LocalizedStringKey("label_starter_count"))
                            Spacer()
                            Text(String(format: NSLocalizedString("count_players_format", comment: "Players count"), courtPlayerCount))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(LocalizedStringKey("toggle_reset_team_fouls_each_period"), isOn: $resetsTeamFoulsEachPeriod)

                    Picker(LocalizedStringKey("label_period_end_condition"), selection: $periodEndCondition) {
                        Text(LocalizedStringKey("period_end_manual")).tag(PeriodEndCondition.manual)
                        Text(LocalizedStringKey("period_end_by_time")).tag(PeriodEndCondition.byTime)
                        Text(LocalizedStringKey("period_end_by_score")).tag(PeriodEndCondition.byScore)
                    }

                    if periodEndCondition == .byTime {
                        HStack {
                            Text(LocalizedStringKey("label_period_time_limit"))
                            Spacer()
                            TextField(LocalizedStringKey("label_minutes"), value: $periodTimeLimit, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text(LocalizedStringKey("label_minutes_unit"))
                                .foregroundStyle(.secondary)
                        }
                    } else if periodEndCondition == .byScore {
                        HStack {
                            Text(LocalizedStringKey("label_period_score_limit"))
                            Spacer()
                            TextField(LocalizedStringKey("label_points"), value: $periodScoreLimit, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text(LocalizedStringKey("label_points_unit"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(LocalizedStringKey("section_scoring_buttons")) {
                    Toggle(LocalizedStringKey("action_rebound"), isOn: $showsReboundButton)
                    Toggle(LocalizedStringKey("action_assist"), isOn: $showsAssistButton)
                    Toggle(LocalizedStringKey("action_foul"), isOn: $showsFoulButton)
                    Toggle(LocalizedStringKey("action_block"), isOn: $showsBlockButton)
                    Toggle(LocalizedStringKey("action_steal"), isOn: $showsStealButton)
                    Toggle(LocalizedStringKey("action_turnover"), isOn: $showsTurnoverButton)
                }
            }
                .navigationTitle(LocalizedStringKey("nav_new_game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(LocalizedStringKey("button_done")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_start")) {
                        guard let homeTeamID, let awayTeamID else { return }
                        onStart(GameSetupConfig(
                            homeTeamID: homeTeamID,
                            awayTeamID: awayTeamID,
                            homeStarterIDs: homeStarterIDs,
                            awayStarterIDs: awayStarterIDs,
                            homeBenchIDs: homeBenchIDs,
                            awayBenchIDs: awayBenchIDs,
                            periodCount: periodCount,
                            courtPlayerCount: courtPlayerCount,
                            resetsTeamFoulsEachPeriod: resetsTeamFoulsEachPeriod,
                            showsReboundButton: showsReboundButton,
                            showsAssistButton: showsAssistButton,
                            showsFoulButton: showsFoulButton,
                            showsBlockButton: showsBlockButton,
                            showsStealButton: showsStealButton,
                            showsTurnoverButton: showsTurnoverButton,
                            periodEndCondition: periodEndCondition,
                            periodTimeLimit: periodTimeLimit,
                            periodScoreLimit: periodScoreLimit
                        ))
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
        Section(String(format: NSLocalizedString("section_starter_select_format", comment: "Starter section title"), title, requiredCount)) {
            if players.isEmpty {
                Text(LocalizedStringKey("text_team_has_no_players"))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            SelectablePlayerAvatarButton(
                                player: player,
                                isSelected: selectedIDs.wrappedValue.contains(player.id),
                                badge: selectedIDs.wrappedValue.contains(player.id) ? NSLocalizedString("badge_starter", comment: "Starter badge") : nil
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
        Section(String(format: NSLocalizedString("section_bench_optional_format", comment: "Bench section title"), title)) {
            if players.isEmpty {
                Text(LocalizedStringKey("text_no_optional_bench"))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            SelectablePlayerAvatarButton(
                                player: player,
                                isSelected: selectedIDs.wrappedValue.contains(player.id),
                                badge: selectedIDs.wrappedValue.contains(player.id) ? NSLocalizedString("badge_bench", comment: "Bench badge") : nil
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
        periodCount = max(periodCount, 1)
        courtPlayerCount = max(courtPlayerCount, 1)
        periodTimeLimit = max(periodTimeLimit, 1)
        periodScoreLimit = max(periodScoreLimit, 1)
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
                    Picker(LocalizedStringKey("picker_team"), selection: $side) {
                        Text(homeTeamName).tag(TeamSide.home)
                        Text(awayTeamName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(NSLocalizedString("section_substitute_out", comment: "Substitute out"), selectedName(for: outgoingPlayerID))
                    if onCourtPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_on_court_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(onCourtPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: outgoingPlayerID == player.id,
                                        badge: outgoingPlayerID == player.id ? NSLocalizedString("badge_sub_out", comment: "Substitute out badge") : nil
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
                    sectionHeader(NSLocalizedString("section_substitute_in", comment: "Substitute in"), selectedName(for: incomingPlayerID))
                    if benchPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_bench_to_sub_in"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(benchPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: incomingPlayerID == player.id,
                                        badge: incomingPlayerID == player.id ? NSLocalizedString("badge_sub_in", comment: "Substitute in badge") : nil
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
            .navigationTitle(LocalizedStringKey("nav_substitution"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_record")) {
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
        guard let id else { return NSLocalizedString("text_not_selected", comment: "Not selected") }
        return (onCourtPlayers + benchPlayers).first(where: { $0.id == id })?.name ?? NSLocalizedString("text_not_selected", comment: "Not selected")
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
                    Picker(LocalizedStringKey("picker_team"), selection: $side) {
                        Text(homeTeamName).tag(TeamSide.home)
                        Text(awayTeamName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(NSLocalizedString("section_add_to_roster", comment: "Add to roster"), selectedName(for: incomingPlayerID))
                    if incomingPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_late_arrival_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(incomingPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: incomingPlayerID == player.id,
                                        badge: incomingPlayerID == player.id ? NSLocalizedString("badge_on_court", comment: "On-court badge") : nil
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
            .navigationTitle(LocalizedStringKey("nav_late_arrival"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_record")) {
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
        guard let id else { return NSLocalizedString("text_not_selected", comment: "Not selected") }
        return incomingPlayers.first(where: { $0.id == id })?.name ?? NSLocalizedString("text_not_selected", comment: "Not selected")
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
                Text(player.number.isEmpty ? player.name : "\(player.number) \(player.name)")
                    .font(.caption)
                    .lineLimit(1)
                    .frame(width: 72)
            }
            .foregroundStyle(GamePalette.text)
        }
        .buttonStyle(.plain)
    }
}
