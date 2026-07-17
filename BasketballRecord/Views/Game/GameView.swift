//
//  GameView.swift
//  BasketballRecord
//
//  Created by Xie, Dongze on 2026/7/3.
//


import SwiftUI
import UIKit
import MultipeerConnectivity
import CryptoKit

struct GameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager

    @StateObject private var gameVM = GameViewModel()
    @State private var currentGameRecordID: UUID?
    @State private var hasRestoredLatestGame = false
    @State private var selectedPlayerID: UUID?
    @State private var selectedSide: TeamSide = .home
    @State private var isShowingSubstitution = false
    @State private var isShowingLateArrival = false
    @State private var isShowingNewGameSetup = false
    @State private var isShowingUnfinishedGameAlert = false
    @State private var isShowingOTSetup = false
    @State private var isShowingFinishedGameAlert = false
    @State private var otPeriodCount = 1
    @State private var otPeriodEndCondition = PeriodEndCondition.byTime
    @State private var otTimeLimit = 12
    @State private var otScoreLimit = 30
    @State private var isShowingSimulateConfirmation = false
    @State private var isShowingFinishGameConfirmation = false
    @State private var isShowingResetConfirmation = false
    @State private var isShowingManualEndPeriodConfirmation = false
    @State private var manualEndPeriodMessage = ""
    @State private var substitutionSide: TeamSide = .home
    @State private var lateArrivalSide: TeamSide = .home
    @State private var outgoingPlayerID: UUID?
    @State private var incomingPlayerID: UUID?
    @State private var lateArrivalIncomingPlayerID: UUID?
    @State private var saveConfirmation: String?
    @State private var statAlertMessage: String?
    @State private var simulationAlertMessage: String?
    @State private var collaborationAlertMessage: String?
    @StateObject private var liveManager = LiveCollaborationManager()
    @State private var isSimulating = false
    @State private var clockNow = Date()
    @State private var scorePulseSide: TeamSide?
    @State private var scorePulseDismissTask: Task<Void, Never>?
    @State private var actionButtonPulseKey: String?
    @State private var actionButtonPulseDismissTask: Task<Void, Never>?
    @State private var recordingIndicatorBlink = false
    @State private var blinkTimer: Timer?
    @State private var highlightedLogID: UUID?
    @State private var highlightedLogDismissTask: Task<Void, Never>?
    @State private var voiceMatchDismissTask: Task<Void, Never>?
    @State private var voiceFlashDismissTask: Task<Void, Never>?
    @State private var voiceErrorDismissTask: Task<Void, Never>?
    @State private var showAutoEndAlert = false
    @State private var autoEndAlertMessage = ""
    @State private var isShowingPurchase = false
    @State private var voiceMatch: (playerID: UUID, side: TeamSide, action: StatAction)?
    @State private var voiceFlashColor: Color?
    @State private var voiceErrorMessage: String?
    @State private var voiceSuccessItem: (player: Player, action: StatAction)?
    @State private var voiceSuccessDismissTask: Task<Void, Never>?

    @StateObject private var voiceRecognizer = VoiceRecognizer()
    @AppStorage("voice_locale") private var voiceLocale: String = ""
    @AppStorage("voice_matching_threshold") private var voiceMatchingThreshold: Double = 0.6
    @AppStorage("voice_show_success_animation") private var showVoiceSuccessAnimation = true

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
                .overlay(alignment: .top) {
                    VStack(spacing: 16) {
                        if showVoiceSuccessAnimation, let item = voiceSuccessItem {
                            VStack(spacing: 16) {
                                Group {
                                    if let data = item.player.photoData, let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        ZStack {
                                            Circle().fill(Color.primary.opacity(0.12))
                                            Text(String(item.player.name.prefix(2)))
                                                .font(.largeTitle.weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                }
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.separator, lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                                Text(item.action.message)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.top, UIScreen.main.bounds.height / 3 - 120)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(voiceSuccessItem != nil ? 1 : 0.5)
                    .opacity(voiceSuccessItem != nil ? 1 : 0)
                    .animation(.easeOut(duration: 0.25), value: voiceSuccessItem != nil)
                    .allowsHitTesting(false)
                }
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
                        .disabled(gameVM.snapshot.isComplete || gameVM.snapshot.logs.isEmpty)
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            if gameVM.snapshot.isComplete {
                                isShowingFinishedGameAlert = true
                            } else if hasUnfinishedGameToConfirm {
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
                            .disabled(currentGameRecordID == nil || needsNewGameSetup)
                        }

                        Button {
                            saveCurrentGame()
                        } label: {
                            Label(LocalizedStringKey("button_save_history"), systemImage: "clock.badge.checkmark")
                        }
                        .disabled(gameVM.snapshot.logs.isEmpty)
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
                    initialHomeTeamID: gameVM.snapshot.homeTeamID,
                    initialAwayTeamID: gameVM.snapshot.awayTeamID,
                    onStart: startNewGame(with:)
                )
            }
            .sheet(isPresented: $isShowingOTSetup) {
                NavigationStack {
                    Form {
                        Section(LocalizedStringKey("section_overtime_settings")) {
                            Stepper(value: $otPeriodCount, in: 1...10) {
                                Text(String(format: NSLocalizedString("label_ot_period_count", comment: "OT period count"), otPeriodCount))
                            }
                            Picker(LocalizedStringKey("label_period_end_condition"), selection: $otPeriodEndCondition) {
                                ForEach(PeriodEndCondition.allCases) { condition in
                                    Text(conditionLabel(condition)).tag(condition)
                                }
                            }
                            if otPeriodEndCondition == .byTime {
                                HStack {
                                    Text(LocalizedStringKey("label_period_time_limit"))
                                    Spacer()
                                    TextField(value: $otTimeLimit, format: .number) {
                                        Text("12")
                                    }
                                    .keyboardType(.numberPad)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    Text(LocalizedStringKey("label_minutes"))
                                }
                            }
                            if otPeriodEndCondition == .byScore {
                                HStack {
                                    Text(LocalizedStringKey("label_period_score_limit"))
                                    Spacer()
                                    TextField(value: $otScoreLimit, format: .number) {
                                        Text("30")
                                    }
                                    .keyboardType(.numberPad)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    Text(LocalizedStringKey("label_points"))
                                }
                            }
                        }
                    }
                    .navigationTitle(LocalizedStringKey("overtime_setup_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(LocalizedStringKey("button_cancel")) { isShowingOTSetup = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(LocalizedStringKey("button_start_overtime")) { startOvertime() }
                        }
                    }
                    .onAppear {
                        otTimeLimit = gameVM.snapshot.periodTimeLimit
                        otScoreLimit = gameVM.snapshot.periodScoreLimit
                    }
                }
            }
            .sheet(isPresented: $isShowingSubstitution) {
                SubstitutionView(
                    side: $substitutionSide,
                    outgoingPlayerID: $outgoingPlayerID,
                    incomingPlayerID: $incomingPlayerID,
                    homeTeamName: store.team(for: gameVM.snapshot.homeTeamID)?.name ?? NSLocalizedString("team_home_default", comment: "Default home team name"),
                    awayTeamName: store.team(for: gameVM.snapshot.awayTeamID)?.name ?? NSLocalizedString("team_away_default", comment: "Default away team name"),
                    homeOnCourtPlayers: players(in: gameVM.snapshot.homeTeamID).filter { gameVM.snapshot.homeOnCourtPlayerIDs.contains($0.id) },
                    homeBenchPlayers: benchPlayers(for: .home),
                    awayOnCourtPlayers: players(in: gameVM.snapshot.awayTeamID).filter { gameVM.snapshot.awayOnCourtPlayerIDs.contains($0.id) },
                    awayBenchPlayers: benchPlayers(for: .away),
                    onConfirm: performSubstitution
                )
            }
            .sheet(isPresented: $isShowingLateArrival) {
                LateArrivalEntryView(
                    side: $lateArrivalSide,
                    incomingPlayerID: $lateArrivalIncomingPlayerID,
                    homeTeamName: store.team(for: gameVM.snapshot.homeTeamID)?.name ?? NSLocalizedString("team_home_default", comment: "Default home team name"),
                    awayTeamName: store.team(for: gameVM.snapshot.awayTeamID)?.name ?? NSLocalizedString("team_away_default", comment: "Default away team name"),
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
        AnyView(sheetWrappedView
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
            .alert(LocalizedStringKey("alert_manual_end_period_title"), isPresented: $isShowingManualEndPeriodConfirmation) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_ok")) {
                    let now = Date()
                    _ = liveManager.submitLiveOperation(.togglePeriod(at: now)) {
                        applyTogglePeriodOperation(at: now)
                    }
                }
            } message: {
                Text(manualEndPeriodMessage)
            }
            .alert(LocalizedStringKey("alert_unfinished_game_title"), isPresented: $isShowingUnfinishedGameAlert) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_overtime")) {
                    finishGame()
                    isShowingOTSetup = true
                }
                Button(LocalizedStringKey("button_end_current_game")) {
                    finishGame()
                    isShowingNewGameSetup = true
                }
            } message: {
                Text(LocalizedStringKey("alert_unfinished_game_message"))
            }
            .alert(LocalizedStringKey("alert_finished_game_title"), isPresented: $isShowingFinishedGameAlert) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_overtime")) {
                    isShowingOTSetup = true
                }
                Button(LocalizedStringKey("button_new_game")) {
                    isShowingNewGameSetup = true
                }
            } message: {
                Text(LocalizedStringKey("alert_finished_game_message"))
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
            })
    }

    private var lifecycleWrappedView: some View {
        AnyView(alertWrappedView
            .onAppear {
                restoreLatestGameIfNeeded()
            }
            .onReceive(matchClockTicker) { date in
                clockNow = date
                if gameVM.snapshot.periodEndCondition == .byTime {
                    checkAndAutoEndPeriod()
                }
            }
            .onAppear { [self] in
                liveManager.bluetooth = bluetooth
                liveManager.store = store
               liveManager.onBuildStatePayload = { [self] in
                    (gameVM.snapshot, gameVM.undoStack, currentGameRecordID)
               }
                liveManager.onApplyOperation = { [self] payload in
                    applyLiveOperationPayload(payload)
                }
                liveManager.onStateChanged = { [self] snapshot, undoStack, redo, gameID in
                    gameVM.snapshot = snapshot
                    gameVM.undoStack = undoStack
                    gameVM.redoStack = redo
                    self.currentGameRecordID = gameID
                    trimInvalidLineups()
                    ensureSelectedPlayer()
                    autoSaveCurrentGame()
                    let currentLogID = gameVM.snapshot.logs.last?.id
                    if let previousLogID = gameVM.snapshot.logs.dropLast().last?.id,
                       currentLogID != previousLogID, let currentLogID {
                        highlightLatestLog(currentLogID)
                    }
                }
                liveManager.onAlert = { [self] message in
                    collaborationAlertMessage = message
                }
                voiceRecognizer.configure(store: store)
                voiceRecognizer.matchingThreshold = voiceMatchingThreshold
                if !voiceLocale.isEmpty {
                    voiceRecognizer.updateRules(for: Locale(identifier: voiceLocale))
                }
                voiceRecognizer.onClear = { [self] in
                    voiceMatch = nil
                    voiceFlashColor = nil
                    voiceErrorMessage = nil
                }
                voiceRecognizer.onError = { [self] msg in
                    voiceErrorMessage = msg
                    clearVoiceErrorAfterDelay()
                }
                voiceRecognizer.onFlash = { [self] color in
                    voiceFlashColor = color
                    clearVoiceFlashAfterDelay()
                }
                voiceRecognizer.onAction = { [self] action, playerID, side, text in
                    guard !gameVM.snapshot.isComplete else {
                        statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "")
                        return
                    }
                    guard !gameVM.snapshot.isPaused else {
                        statAlertMessage = NSLocalizedString("stat_game_paused", comment: "")
                        return
                    }
                    guard gameVM.snapshot.periodIsRunning else {
                        statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: ""), gameVM.snapshot.currentPeriod)
                        return
                    }
                    let now = Date()
                    let operation = BluetoothLiveOperationPayload.record(
                        action: action.liveAction,
                        playerID: playerID,
                        side: side.liveSide,
                        at: now
                    )
                    _ = liveManager.submitLiveOperation(operation) {
                        self.applyRecordOperation(action: action, playerID: playerID, side: side, at: now, eventMessage: text)
                    }
                    voiceMatch = (playerID, side, action)
                    clearVoiceMatchAfterDelay(playerID: playerID)
                    if let player = store.player(for: playerID) {
                        voiceSuccessItem = (player, action)
                    }
                    clearVoiceSuccessAfterDelay(playerID: playerID)
                }
                voiceRecognizer.onDualAction = { [self] action1, pid1, side1, action2, pid2, side2 in
                    guard !gameVM.snapshot.isComplete else {
                        statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "")
                        return
                    }
                    guard !gameVM.snapshot.isPaused else {
                        statAlertMessage = NSLocalizedString("stat_game_paused", comment: "")
                        return
                    }
                    guard gameVM.snapshot.periodIsRunning else {
                        statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: ""), gameVM.snapshot.currentPeriod)
                        return
                    }
                    let now = Date()
                    let pn1 = self.name(for: pid1)
                    let pn2 = self.name(for: pid2)
                    let locale = voiceRecognizer.currentRules.locale

                    if action1 == .steal && action2 == .turnover {
                        let combinedMsg = Self.dualStealMessage(pn1: pn1, pn2: pn2, locale: locale)
                        _ = liveManager.submitLiveOperation(.dualAction(
                            action1: .turnover, playerID1: pid1, side1: side1.liveSide,
                            action2: .turnover, playerID2: pid2, side2: side2.liveSide,
                            at: now
                        )) {
                            self.applyRecordOperation(action: .stealTurnover, playerID: pid1, side: side1, at: now, eventMessage: combinedMsg, relatedPlayerID: pid2)
                            return true
                        }
                    } else {
                        let compositeAction: StatAction
                        if action2 == .twoMade || action2 == .layupMade || action2 == .midRangeMade || action2 == .paintMade || action2 == .dunkMade || action2 == .putbackMade {
                            compositeAction = .assistTwoMade
                        } else if action2 == .threeMade {
                            compositeAction = .assistThreeMade
                        } else {
                            let combinedMsg = Self.dualAssistMessage(pn1: pn1, pn2: pn2, shot: action2.message, locale: locale)
                            _ = liveManager.submitLiveOperation(.dualAction(
                                action1: action1.liveAction, playerID1: pid1, side1: side1.liveSide,
                                action2: action2.liveAction, playerID2: pid2, side2: side2.liveSide,
                                at: now
                            )) {
                                self.applyRecordOperation(action: action2, playerID: pid2, side: side2, at: now)
                                self.applyRecordOperation(action: action1, playerID: pid1, side: side1, at: now, eventMessage: combinedMsg)
                                return true
                            }
                            voiceMatch = (pid1, side1, action1)
                            clearVoiceMatchAfterDelay(playerID: pid1)
                            if let player = store.player(for: pid1) {
                                voiceSuccessItem = (player, action1)
                            }
                            clearVoiceSuccessAfterDelay(playerID: pid1)
                            return
                        }
                        let combinedMsg = Self.dualAssistMessage(pn1: pn1, pn2: pn2, shot: action2.message, locale: locale)
                        _ = liveManager.submitLiveOperation(.dualAction(
                            action1: action1.liveAction, playerID1: pid1, side1: side1.liveSide,
                            action2: action2.liveAction, playerID2: pid2, side2: side2.liveSide,
                            at: now
                        )) {
                            self.applyRecordOperation(action: compositeAction, playerID: pid1, side: side1, at: now, eventMessage: combinedMsg, relatedPlayerID: pid2)
                            return true
                        }
                    }
                    voiceMatch = (pid1, side1, action1)
                    clearVoiceMatchAfterDelay(playerID: pid1)
                    if let player = store.player(for: pid1) {
                        voiceSuccessItem = (player, action1)
                    }
                    clearVoiceSuccessAfterDelay(playerID: pid1)
                }
                voiceRecognizer.onCommand = { [self] command in
                    switch command {
                    case .togglePause: togglePause()
                    case .startPeriod: togglePeriod()
                    case .finishGame: isShowingFinishGameConfirmation = true
                    case .undo: undo()
                    case .redo: redo()
                    case .substitution(_, _, _): break
                    }
                }
                voiceRecognizer.onSubstitution = { [self] side, outgoingID, incomingID in
                    let now = Date()
                    _ = liveManager.submitLiveOperation(.substitution(outgoingPlayerID: outgoingID, incomingPlayerID: incomingID, side: side.liveSide, at: now)) {
                        applySubstitutionOperation(outgoingPlayerID: outgoingID, incomingPlayerID: incomingID, side: side, at: now)
                    }
                }
            }
            .onChange(of: gameVM.snapshot) { _, newValue in
                voiceRecognizer.currentSnapshot = newValue
            }
            .onChange(of: bluetooth.latestLiveSnapshot?.id) { _, _ in
                guard let incoming = bluetooth.latestLiveSnapshot else { return }
                liveManager.applyRemoteLiveSnapshot(incoming)
            }
            .onChange(of: voiceLocale) { _, newValue in
                voiceRecognizer.updateRules(for: Locale(identifier: newValue.isEmpty ? "en" : newValue))
            }
            .onChange(of: voiceMatchingThreshold) { _, newValue in
                voiceRecognizer.matchingThreshold = newValue
            }
            .onChange(of: bluetooth.latestInviteResponse?.id) { _, _ in
                guard let response = bluetooth.latestInviteResponse else { return }
                liveManager.handleInviteResponse(response)
            }
            .onChange(of: bluetooth.pendingLiveOpRequest?.id) { _, _ in
                guard let request = bluetooth.pendingLiveOpRequest else { return }
                liveManager.handleIncomingLiveOpRequest(request)
            }
            .onChange(of: bluetooth.latestLiveOpCommit?.id) { _, _ in
                guard let commit = bluetooth.latestLiveOpCommit else { return }
                liveManager.handleIncomingLiveOpCommit(commit)
            }
            .onChange(of: bluetooth.latestLiveOpAck?.id) { _, _ in
                guard let ack = bluetooth.latestLiveOpAck else { return }
                liveManager.handleIncomingLiveOpAck(ack)
            }
            .onChange(of: bluetooth.latestLiveResyncRequest?.id) { _, _ in
                guard let request = bluetooth.latestLiveResyncRequest else { return }
                liveManager.handleIncomingResyncRequest(request)
            }
            .onChange(of: store.teams) { _, _ in ensureInitialSelection() }
            .onChange(of: substitutionSide) { _, _ in prepareSubstitutionDefaults() }
            .onChange(of: lateArrivalSide) { _, _ in prepareLateArrivalDefaults() }
            .onDisappear {
                scorePulseDismissTask?.cancel()
                actionButtonPulseDismissTask?.cancel()
                highlightedLogDismissTask?.cancel()
                voiceMatchDismissTask?.cancel()
                voiceFlashDismissTask?.cancel()
                voiceErrorDismissTask?.cancel()
                voiceSuccessDismissTask?.cancel()
            })
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
                    if let error = voiceErrorMessage {
                        Text(error)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                            .transition(.opacity)
                    }
                    if let match = voiceMatch {
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
                } else if let color = voiceFlashColor {
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
                        team: store.team(for: gameVM.snapshot.homeTeamID),
                        players: onCourtPlayers(for: .home),
                        score: score(for: gameVM.snapshot.homeTeamID),
                        isScorePulsing: scorePulseSide == .home,
                        fouls: displayedTeamFouls(for: .home),
                        foulLabel: gameVM.snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
                        onCourtPlayerIDs: gameVM.snapshot.homeOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer,
                        teamStatsMode: gameVM.snapshot.homeTeamStatsMode
                    )

                    CompactTeamRow(
                        side: .away,
                        team: store.team(for: gameVM.snapshot.awayTeamID),
                        players: onCourtPlayers(for: .away),
                        score: score(for: gameVM.snapshot.awayTeamID),
                        isScorePulsing: scorePulseSide == .away,
                        fouls: displayedTeamFouls(for: .away),
                        foulLabel: gameVM.snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
                        onCourtPlayerIDs: gameVM.snapshot.awayOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer,
                        teamStatsMode: gameVM.snapshot.awayTeamStatsMode
                    )
                }
            } else {
                VStack(spacing: 6) {
                    CompactTeamRow(
                        side: .home,
                        team: store.team(for: gameVM.snapshot.homeTeamID),
                        players: onCourtPlayers(for: .home),
                        score: score(for: gameVM.snapshot.homeTeamID),
                        isScorePulsing: scorePulseSide == .home,
                        fouls: displayedTeamFouls(for: .home),
                        foulLabel: gameVM.snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
                        onCourtPlayerIDs: gameVM.snapshot.homeOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer,
                        teamStatsMode: gameVM.snapshot.homeTeamStatsMode
                    )

                    CompactTeamRow(
                        side: .away,
                        team: store.team(for: gameVM.snapshot.awayTeamID),
                        players: onCourtPlayers(for: .away),
                        score: score(for: gameVM.snapshot.awayTeamID),
                        isScorePulsing: scorePulseSide == .away,
                        fouls: displayedTeamFouls(for: .away),
                        foulLabel: gameVM.snapshot.resetsTeamFoulsEachPeriod ? NSLocalizedString("label_foul_period", comment: "Team fouls this period") : NSLocalizedString("label_foul_total", comment: "Team fouls total"),
                        onCourtPlayerIDs: gameVM.snapshot.awayOnCourtPlayerIDs,
                        selectedPlayerID: selectedPlayerID,
                        selectedSide: selectedSide,
                        onSelect: selectPlayer,
                        teamStatsMode: gameVM.snapshot.awayTeamStatsMode
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
        guard let role = liveManager.liveRole,
              liveManager.activeLiveSessionID != nil else {
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
            guard let hostName = liveManager.liveHostPeerName, !hostName.isEmpty else {
                return (String(format: NSLocalizedString("collab_status_participant_waiting_host", comment: "participant waiting host status"), roleLabel), false)
            }
            if connectedPeerNames.contains(hostName) {
                return (String(format: NSLocalizedString("collab_status_participant_with_host", comment: "participant with host"), roleLabel, hostName), false)
            }
            return (String(format: NSLocalizedString("collab_status_participant_host_disconnected", comment: "participant host disconnected"), roleLabel, hostName), true)

        case .host:
            let knownParticipants = liveManager.liveParticipantNames.sorted()
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
                if gameVM.snapshot.showsAssistButton {
                    actionButton(LocalizedStringKey("action_assist"), systemImage: "person.2.fill", style: .assist) { record(.assist) }
                }
                if gameVM.snapshot.showsOffensiveDefensiveRebound {
                    actionButton(LocalizedStringKey("action_offensive_rebound"), systemImage: "arrow.up.forward.circle.fill", style: .rebound) { record(.offensiveRebound) }
                    actionButton(LocalizedStringKey("action_defensive_rebound"), systemImage: "arrow.down.backward.circle.fill", style: .rebound) { record(.defensiveRebound) }
                } else if gameVM.snapshot.showsReboundButton {
                    actionButton(LocalizedStringKey("action_rebound"), systemImage: "arrow.up.circle.fill", style: .rebound) { record(.rebound) }
                }
                if gameVM.snapshot.showsBlockButton {
                    actionButton(LocalizedStringKey("action_block"), systemImage: "shield.lefthalf.filled", style: .rebound) { record(.block) }
                }
                if !gameVM.snapshot.showsOffensiveDefensiveRebound, gameVM.snapshot.showsStealButton {
                    actionButton(LocalizedStringKey("action_steal"), systemImage: "hand.raised.fill", style: .assist) { record(.steal) }
                }
            }

            HStack(spacing: 8) {
                if gameVM.snapshot.showsOffensiveDefensiveRebound, gameVM.snapshot.showsStealButton {
                    actionButton(LocalizedStringKey("action_steal"), systemImage: "hand.raised.fill", style: .assist) { record(.steal) }
                }
                if gameVM.snapshot.showsFoulButton {
                    actionButton(LocalizedStringKey("action_foul"), systemImage: "exclamationmark.triangle", style: .warning) { record(.foul) }
                }
                if gameVM.snapshot.showsTurnoverButton {
                    actionButton(LocalizedStringKey("action_turnover"), systemImage: "arrow.triangle.2.circlepath", style: .warning) { record(.turnover) }
                }
                Button {
                    togglePause()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: gameVM.snapshot.isPaused ? "play.fill" : "pause.fill")
                        Text(pauseButtonTitle)
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: .pause))
                .disabled(gameVM.snapshot.isComplete)
            }

            HStack(spacing: 8) {
                Button {
                    togglePeriod()
                    triggerTapFeedback()
                    pulseActionButton("period-toggle")
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: gameVM.snapshot.periodIsRunning ? "stop.circle" : "play.circle")
                        Text(LocalizedStringKey(periodButtonTitle))
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(PastelActionButtonStyle(style: gameVM.snapshot.periodIsRunning ? .periodEnd : .period))
                .scaleEffect(actionButtonPulseKey == "period-toggle" ? 1.09 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.68), value: actionButtonPulseKey == "period-toggle")
                .disabled(gameVM.snapshot.isComplete)

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
                .disabled(gameVM.undoStack.isEmpty)

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
                .disabled(gameVM.redoStack.isEmpty)
            }
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LocalizedStringKey("label_events"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(gameVM.snapshot.logs.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if gameVM.snapshot.logs.isEmpty {
                ContentUnavailableView(LocalizedStringKey("text_no_events"), systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(gameVM.snapshot.logs.reversed()) { entry in
                                Text(logText(for: entry))
                                    .font(highlightedLogID == entry.id ? .footnote.monospacedDigit().weight(.bold) : .footnote.monospacedDigit())
                                    .lineLimit(2)
                                    .foregroundStyle(GameLogFormatter.isScoring(entry) ? Color.blue : Color.primary)
                                    .scaleEffect(highlightedLogID == entry.id ? 1.05 : 1)
                                    .animation(.spring(response: 0.24, dampingFraction: 0.72), value: highlightedLogID == entry.id)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .id(entry.id)
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                    .onChange(of: gameVM.snapshot.logs.count) { oldCount, newCount in
                        if newCount > oldCount, let newestId = gameVM.snapshot.logs.last?.id {
                            withAnimation {
                                proxy.scrollTo(newestId, anchor: .top)
                            }
                        }
                    }
                }
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
        var snapshotForDisplay = gameVM.snapshot
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
        guard gameVM.snapshot.homeTeamID != nil, gameVM.snapshot.awayTeamID != nil else { return true }
        if !gameVM.snapshot.homeTeamStatsMode, gameVM.snapshot.homeOnCourtPlayerIDs.isEmpty { return true }
        if !gameVM.snapshot.awayTeamStatsMode, gameVM.snapshot.awayOnCourtPlayerIDs.isEmpty { return true }
        return false
    }

    private var hasUnfinishedGameToConfirm: Bool {
        currentGameRecordID != nil && !gameVM.snapshot.isComplete
    }

    private var canEditTeamSelection: Bool {
        gameVM.snapshot.logs.isEmpty && currentGameRecordID == nil
    }

    private var periodSummary: String {
        if gameVM.snapshot.isComplete { return NSLocalizedString("period_summary_finished", comment: "Period summary when game finished") }
        if gameVM.snapshot.periodIsRunning {
            return gameVM.snapshot.isPaused
                ? String(format: NSLocalizedString("period_summary_paused_format", comment: "Period paused format"), gameVM.snapshot.currentPeriod, gameVM.snapshot.periodCount)
                : String(format: NSLocalizedString("period_summary_in_progress_format", comment: "Period in progress format"), gameVM.snapshot.currentPeriod, gameVM.snapshot.periodCount)
        }
        return String(format: NSLocalizedString("period_summary_format", comment: "Period summary format"), gameVM.snapshot.currentPeriod, gameVM.snapshot.periodCount)
    }

    private var periodButtonTitle: String {
        if gameVM.snapshot.isComplete { return NSLocalizedString("period_button_finished", comment: "Period button title when game finished") }
        let action = gameVM.snapshot.periodIsRunning ? NSLocalizedString("period_button_action_end", comment: "Period button action end") : NSLocalizedString("period_button_action_start", comment: "Period button action start")
        return String(format: NSLocalizedString("period_button_toggle_format", comment: "Period button format"), gameVM.snapshot.currentPeriod, action)
    }

    private var currentMatchElapsedSeconds: TimeInterval {
        guard gameVM.snapshot.periodIsRunning,
              !gameVM.snapshot.isPaused,
              let activeSince = gameVM.snapshot.matchActiveSince else {
            return gameVM.snapshot.matchElapsedSeconds
        }

        return gameVM.snapshot.matchElapsedSeconds + max(0, clockNow.timeIntervalSince(activeSince))
    }

    private var currentPeriodElapsedSeconds: TimeInterval {
        guard gameVM.snapshot.periodIsRunning,
              !gameVM.snapshot.isPaused,
              let activeSince = gameVM.snapshot.periodActiveSince else {
            return gameVM.snapshot.periodElapsedSeconds
        }

        return gameVM.snapshot.periodElapsedSeconds + max(0, clockNow.timeIntervalSince(activeSince))
    }

    private var pauseButtonTitle: LocalizedStringKey {
        gameVM.snapshot.isPaused ? LocalizedStringKey("button_continue") : LocalizedStringKey("button_pause")
    }

    private var isRecordingActive: Bool {
        gameVM.snapshot.periodIsRunning && !gameVM.snapshot.isPaused && !gameVM.snapshot.isComplete
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
        guard let side = side(for: teamID), let teamID else { return 0 }
        if (side == .home && gameVM.snapshot.homeTeamStatsMode) || (side == .away && gameVM.snapshot.awayTeamStatsMode) {
            return gameVM.snapshot.teamStatsByID[teamID, default: PlayerStats()].points
        }
        return gamePlayerIDs(for: side).reduce(0) { total, playerID in
            total + gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func teamFouls(for teamID: UUID?) -> Int {
        guard let side = side(for: teamID), let teamID else { return 0 }
        let teamFouls = gameVM.snapshot.teamStatsByID[teamID, default: PlayerStats()].fouls
        let playerFouls = gamePlayerIDs(for: side).reduce(0) { total, playerID in
            total + gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()].fouls
        }
        return teamFouls + playerFouls
    }

    private func displayedTeamFouls(for side: TeamSide) -> Int {
        if gameVM.snapshot.resetsTeamFoulsEachPeriod {
            return gameVM.snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0]
        }
        return teamFouls(for: side == .home ? gameVM.snapshot.homeTeamID : gameVM.snapshot.awayTeamID)
    }

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        guard let side = side(for: teamID) else { return PlayerStats() }
        return gamePlayerIDs(for: side).reduce(PlayerStats()) { partial, playerID in
            var total = partial
            let stats = gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
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
            return total
        }
    }

    private func onCourtIDs(for side: TeamSide) -> [UUID] {
        side == .home ? gameVM.snapshot.homeOnCourtPlayerIDs : gameVM.snapshot.awayOnCourtPlayerIDs
    }

    private func gamePlayerIDs(for side: TeamSide) -> [UUID] {
        let explicitIDs = side == .home ? gameVM.snapshot.homeAvailablePlayerIDs : gameVM.snapshot.awayAvailablePlayerIDs
        if !explicitIDs.isEmpty {
            return explicitIDs
        }
        let fallback = onCourtIDs(for: side)
        if !fallback.isEmpty {
            return fallback
        }
        let teamID = side == .home ? gameVM.snapshot.homeTeamID : gameVM.snapshot.awayTeamID
        return players(in: teamID).map(\.id)
    }

    private func setGamePlayerIDs(_ ids: [UUID], for side: TeamSide) {
        let uniqueIDs = unique(ids)
        if side == .home {
            gameVM.snapshot.homeAvailablePlayerIDs = uniqueIDs
        } else {
            gameVM.snapshot.awayAvailablePlayerIDs = uniqueIDs
        }
    }

    private func setOnCourtIDs(_ ids: [UUID], for side: TeamSide) {
        if side == .home {
            gameVM.snapshot.homeOnCourtPlayerIDs = ids
        } else {
            gameVM.snapshot.awayOnCourtPlayerIDs = ids
        }
    }

    private func isOnCourt(_ playerID: UUID, side: TeamSide) -> Bool {
        onCourtIDs(for: side).contains(playerID)
    }

    private func side(for teamID: UUID?) -> TeamSide? {
        if teamID == gameVM.snapshot.homeTeamID { return .home }
        if teamID == gameVM.snapshot.awayTeamID { return .away }
        return nil
    }

    private func benchPlayers(for side: TeamSide) -> [Player] {
        let onCourt = Set(onCourtIDs(for: side))
        return gamePlayerIDs(for: side)
            .filter { !onCourt.contains($0) }
            .compactMap { store.player(for: $0) }
    }

    private func unregisteredPlayers(for side: TeamSide) -> [Player] {
        let teamID = side == .home ? gameVM.snapshot.homeTeamID : gameVM.snapshot.awayTeamID
        let registered = Set(gamePlayerIDs(for: side))
        return players(in: teamID).filter { !registered.contains($0.id) }
    }

    private func playingSeconds(for playerID: UUID, now: Date = Date()) -> TimeInterval {
        let stored = gameVM.snapshot.playingSecondsByPlayerID[playerID, default: 0]
        guard gameVM.snapshot.periodIsRunning else { return stored }
        guard let activeSince = gameVM.snapshot.activeSinceByPlayerID[playerID] else { return stored }
        return stored + max(0, now.timeIntervalSince(activeSince))
    }

    private func selectPlayer(_ player: Player, _ side: TeamSide) {
        selectedPlayerID = player.id
        selectedSide = side
    }

    private func ensureInitialSelection() {
        if gameVM.snapshot.homeTeamID == nil {
            gameVM.snapshot.homeTeamID = store.teams.first?.id
        }
        if gameVM.snapshot.awayTeamID == nil {
            gameVM.snapshot.awayTeamID = store.teams.dropFirst().first?.id ?? store.teams.first?.id
        }
        trimInvalidLineups()
        ensureSelectedPlayer()
    }

    private func ensureDefaultLineups() {
        trimInvalidLineups()
    }

    private func trimInvalidLineups() {
        let homeTeamIDs = Set(players(in: gameVM.snapshot.homeTeamID).map(\.id))
        let awayTeamIDs = Set(players(in: gameVM.snapshot.awayTeamID).map(\.id))

        let homeRegistered = unique((gameVM.snapshot.homeAvailablePlayerIDs + gameVM.snapshot.homeOnCourtPlayerIDs).filter { homeTeamIDs.contains($0) })
        let awayRegistered = unique((gameVM.snapshot.awayAvailablePlayerIDs + gameVM.snapshot.awayOnCourtPlayerIDs).filter { awayTeamIDs.contains($0) })

        var homeOnCourt = unique(gameVM.snapshot.homeOnCourtPlayerIDs.filter { homeRegistered.contains($0) })
        var awayOnCourt = unique(gameVM.snapshot.awayOnCourtPlayerIDs.filter { awayRegistered.contains($0) })

        let maxHomeOnCourt = min(gameVM.snapshot.courtPlayerCount, homeRegistered.count)
        let maxAwayOnCourt = min(gameVM.snapshot.courtPlayerCount, awayRegistered.count)

        if homeOnCourt.count < maxHomeOnCourt {
            let supplement = homeRegistered.filter { !homeOnCourt.contains($0) }
            homeOnCourt.append(contentsOf: supplement.prefix(maxHomeOnCourt - homeOnCourt.count))
        }
        if awayOnCourt.count < maxAwayOnCourt {
            let supplement = awayRegistered.filter { !awayOnCourt.contains($0) }
            awayOnCourt.append(contentsOf: supplement.prefix(maxAwayOnCourt - awayOnCourt.count))
        }

        gameVM.snapshot.homeAvailablePlayerIDs = homeRegistered
        gameVM.snapshot.awayAvailablePlayerIDs = awayRegistered
        gameVM.snapshot.homeOnCourtPlayerIDs = Array(homeOnCourt.prefix(gameVM.snapshot.courtPlayerCount))
        gameVM.snapshot.awayOnCourtPlayerIDs = Array(awayOnCourt.prefix(gameVM.snapshot.courtPlayerCount))
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
        guard !gameVM.snapshot.isComplete else {
            statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "Game already finished message")
            return
        }
        guard !gameVM.snapshot.isPaused else {
            statAlertMessage = NSLocalizedString("stat_game_paused", comment: "Game paused message")
            return
        }
        guard gameVM.snapshot.periodIsRunning else {
            statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: "Period not started message"), gameVM.snapshot.currentPeriod)
            return
        }
        let isTeamMode = selectedSide == .home ? gameVM.snapshot.homeTeamStatsMode : gameVM.snapshot.awayTeamStatsMode
        guard let pid = selectedPlayerID else {
            statAlertMessage = NSLocalizedString("stat_select_player_first", comment: "Please select a player message")
            return
        }
        guard isTeamMode || isOnCourt(pid, side: selectedSide) else { return }

        let now = Date()
        let operation = BluetoothLiveOperationPayload.record(
            action: action.liveAction,
            playerID: pid,
            side: selectedSide.liveSide,
            at: now
        )
        liveManager.submitLiveOperation(operation) {
            applyRecordOperation(action: action, playerID: pid, side: selectedSide, at: now)
        }
        showRecordFeedback(action: action, side: selectedSide)
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
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1)
    }

    private func checkAndAutoEndPeriod() {
        guard gameVM.snapshot.periodIsRunning, !gameVM.snapshot.isPaused, !gameVM.snapshot.isComplete else { return }

        switch gameVM.snapshot.periodEndCondition {
        case .manual:
            return
        case .byTime:
            let limit = TimeInterval(gameVM.snapshot.periodTimeLimit * 60)
            guard currentPeriodElapsedSeconds >= limit else { return }
            autoEndAlertMessage = String(format: NSLocalizedString("alert_period_auto_ended_time_format", comment: "Period ended by time"), gameVM.snapshot.currentPeriod)

        case .byScore:
            let homeScore = score(for: gameVM.snapshot.homeTeamID)
            let awayScore = score(for: gameVM.snapshot.awayTeamID)
            let scoreThreshold = gameVM.snapshot.periodScoreLimit * gameVM.snapshot.currentPeriod
            guard homeScore >= scoreThreshold || awayScore >= scoreThreshold else { return }
            autoEndAlertMessage = String(format: NSLocalizedString("alert_period_auto_ended_score_format", comment: "Period ended by score"), gameVM.snapshot.currentPeriod)
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

        liveManager.sendLiveInvite(to: bluetooth.connectedPeers)
    }

    private func togglePeriod() {
        guard !needsNewGameSetup else {
            isShowingNewGameSetup = true
            return
        }
        if gameVM.snapshot.periodIsRunning && !gameVM.snapshot.isComplete {
            switch gameVM.snapshot.periodEndCondition {
            case .manual:
                break
            case .byTime:
                let limit = TimeInterval(gameVM.snapshot.periodTimeLimit * 60)
                if currentPeriodElapsedSeconds < limit {
                    manualEndPeriodMessage = String(format: NSLocalizedString("alert_manual_end_period_time_format", comment: "Manual end period time warning"), gameVM.snapshot.currentPeriod, gameVM.snapshot.periodTimeLimit)
                    isShowingManualEndPeriodConfirmation = true
                    return
                }
            case .byScore:
                let homeScore = score(for: gameVM.snapshot.homeTeamID)
                let awayScore = score(for: gameVM.snapshot.awayTeamID)
                let scoreThreshold = gameVM.snapshot.periodScoreLimit * gameVM.snapshot.currentPeriod
                if homeScore < scoreThreshold && awayScore < scoreThreshold {
                    manualEndPeriodMessage = String(format: NSLocalizedString("alert_manual_end_period_score_format", comment: "Manual end period score warning"), gameVM.snapshot.currentPeriod, scoreThreshold)
                    isShowingManualEndPeriodConfirmation = true
                    return
                }
            }
        }
        let now = Date()
        _ = liveManager.submitLiveOperation(.togglePeriod(at: now)) {
            applyTogglePeriodOperation(at: now)
        }
    }

    private func togglePause() {
        guard !gameVM.snapshot.isComplete else {
            statAlertMessage = NSLocalizedString("stat_game_already_finished", comment: "Game already finished message")
            return
        }
        guard gameVM.snapshot.periodIsRunning else {
            statAlertMessage = String(format: NSLocalizedString("stat_period_not_started", comment: "Period not started message"), gameVM.snapshot.currentPeriod)
            return
        }
        let now = Date()
        _ = liveManager.submitLiveOperation(.togglePause(at: now)) {
            applyTogglePauseOperation(at: now)
        }
    }

    @discardableResult
    private func applyLiveOperationPayload(_ payload: BluetoothLiveOperationPayload) -> Bool {
        switch payload {
        case let .record(action, playerID, side, at):
            guard let statAction = StatAction(liveAction: action) else { return false }
            return applyRecordOperation(action: statAction, playerID: playerID, side: TeamSide(liveSide: side), at: at)

        case let .dualAction(action1, playerID1, side1, action2, playerID2, side2, at):
            guard let statAction1 = StatAction(liveAction: action1),
                  let statAction2 = StatAction(liveAction: action2) else { return false }
            // Merge compatible dual actions into single composite event
            let side = TeamSide(liveSide: side1)
            if statAction1 == .steal, statAction2 == .turnover {
                return applyRecordOperation(action: .stealTurnover, playerID: playerID1, side: side, at: at, relatedPlayerID: playerID2)
            }
            if statAction1 == .assist, statAction2.isAssistableShot {
                let composite: StatAction = statAction2 == .threeMade ? .assistThreeMade : .assistTwoMade
                return applyRecordOperation(action: composite, playerID: playerID1, side: side, at: at, relatedPlayerID: playerID2)
            }
            applyRecordOperation(action: statAction2, playerID: playerID2, side: TeamSide(liveSide: side2), at: at)
            return applyRecordOperation(action: statAction1, playerID: playerID1, side: side, at: at)

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
            if let previous = gameVM.undoStack.popLast() {
                gameVM.redoStack.append(gameVM.snapshot)
                if gameVM.redoStack.count > 30 { gameVM.redoStack.removeFirst(gameVM.redoStack.count - 30) }
                gameVM.snapshot = previous
                ensureSelectedPlayer()
                autoSaveCurrentGame()
                return true
            }
            let now = Date()
            var redoSnapshot = gameVM.snapshot
            closeActiveStints(in: &redoSnapshot, at: now)
            closeMatchClock(in: &redoSnapshot, at: now)
            closePeriodClock(in: &redoSnapshot, at: now)
            gameVM.redoStack.append(redoSnapshot)
            if revertLastAction() {
                autoSaveCurrentGame()
                return true
            }
            gameVM.redoStack.removeLast()
            return false

        case .redo:
            guard let next = gameVM.redoStack.popLast() else { return false }
            gameVM.undoStack.append(gameVM.snapshot)
            if gameVM.undoStack.count > 30 { gameVM.undoStack.removeFirst(gameVM.undoStack.count - 30) }
            gameVM.snapshot = next
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    @discardableResult
    func applyRecordOperation(action: StatAction, playerID: UUID, side: TeamSide, at: Date? = nil, eventMessage: String? = nil, relatedPlayerID: UUID? = nil) -> Bool {
        let isTeamMode = side == .home ? gameVM.snapshot.homeTeamStatsMode : gameVM.snapshot.awayTeamStatsMode
        let teamID = side == .home ? gameVM.snapshot.homeTeamID : gameVM.snapshot.awayTeamID

        guard isTeamMode || isOnCourt(playerID, side: side) else { return false }

        if action == .putbackMade || action == .putbackMissed {
            return applyPutbackOperation(action: action, playerID: playerID, side: side, isTeamMode: isTeamMode, teamID: teamID, at: at, eventMessage: eventMessage)
        }

        mutateSnapshot {
            if isTeamMode, let teamID {
                var stats = gameVM.snapshot.teamStatsByID[teamID, default: PlayerStats()]
                action.apply(to: &stats)
                gameVM.snapshot.teamStatsByID[teamID] = stats
            } else {
                var stats = gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
                action.apply(to: &stats)
                gameVM.snapshot.statsByPlayerID[playerID] = stats
            }

            // Apply related action (scorer points, turnover) for composite events
            if let related = action.relatedAction, let rpid = relatedPlayerID {
                var relatedStats = gameVM.snapshot.statsByPlayerID[rpid, default: PlayerStats()]
                related.apply(to: &relatedStats)
                gameVM.snapshot.statsByPlayerID[rpid] = relatedStats
            }

            if action == .foul {
                gameVM.snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0] += 1
            }
            if action.points > 0 {
                applyPlusMinus(points: action.points, scoringSide: side)
                if let msg = eventMessage?.lowercased(), msg.contains("快攻") {
                    var fbStats = gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
                    fbStats.fastBreakPoints += action.points
                    gameVM.snapshot.statsByPlayerID[playerID] = fbStats
                }
            }
            let eventName = isTeamMode ? (store.team(for: teamID)?.name ?? "?") : name(for: playerID)
            let eventPlayerID = isTeamMode ? teamID : playerID
            if let eventMessage {
                if !eventMessage.isEmpty {
                    gameVM.addEvent(eventMessage, playerID: eventPlayerID, relatedPlayerID: relatedPlayerID, eventCode: action.eventCode, at: at)
                }
            } else {
                gameVM.addEvent("\(eventName) \(action.message)", playerID: eventPlayerID, relatedPlayerID: relatedPlayerID, eventCode: action.eventCode, at: at)
            }
        }
        if action.points > 0, gameVM.snapshot.periodEndCondition == .byScore {
            checkAndAutoEndPeriod()
        }
        return true
    }

    private func applyPutbackOperation(action: StatAction, playerID: UUID, side: TeamSide, isTeamMode: Bool, teamID: UUID?, at: Date?, eventMessage: String?) -> Bool {
        let isMade = action == .putbackMade
        mutateSnapshot {
            if isTeamMode, let teamID {
                var stats = gameVM.snapshot.teamStatsByID[teamID, default: PlayerStats()]
                if gameVM.snapshot.showsOffensiveDefensiveRebound {
                    stats.offensiveRebounds += 1
                } else {
                    stats.rebounds += 1
                }
                if isMade {
                    stats.twoMade += 1; stats.twoAttempts += 1
                } else {
                    stats.twoAttempts += 1
                }
                gameVM.snapshot.teamStatsByID[teamID] = stats
            } else {
                var stats = gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
                if gameVM.snapshot.showsOffensiveDefensiveRebound {
                    stats.offensiveRebounds += 1
                } else {
                    stats.rebounds += 1
                }
                if isMade {
                    stats.twoMade += 1; stats.twoAttempts += 1
                } else {
                    stats.twoAttempts += 1
                }
                gameVM.snapshot.statsByPlayerID[playerID] = stats
            }
            if isMade {
                applyPlusMinus(points: 2, scoringSide: side)
            }
            let eventName = isTeamMode ? (store.team(for: teamID)?.name ?? "?") : name(for: playerID)
            let combinedMsg = eventMessage ?? "\(eventName) \(NSLocalizedString(isMade ? "action_putback_made" : "action_putback_missed", comment: ""))"
            gameVM.addEvent(combinedMsg, playerID: isTeamMode ? teamID : playerID, eventCode: action.eventCode, at: at)
        }
        if isMade, gameVM.snapshot.periodEndCondition == .byScore {
            checkAndAutoEndPeriod()
        }
        return true
    }

    @discardableResult
    private func applyTogglePeriodOperation(at now: Date) -> Bool {
        mutateSnapshot {
            if gameVM.snapshot.periodIsRunning {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                gameVM.addEvent(
                    String(format: NSLocalizedString("event_period_end_format", comment: "Period end event format"), gameVM.snapshot.currentPeriod),
                    eventCode: "event.period_end"
                )
                gameVM.snapshot.periodIsRunning = false
                gameVM.snapshot.isPaused = false
                if gameVM.snapshot.currentPeriod >= gameVM.snapshot.periodCount {
                    gameVM.snapshot.isComplete = true
                    gameVM.addEvent(NSLocalizedString("event_game_end", comment: "Game end event"), eventCode: "event.game_end")
                } else {
                    gameVM.snapshot.currentPeriod += 1
                    gameVM.snapshot.periodElapsedSeconds = 0
                    gameVM.snapshot.periodActiveSince = nil
                }
            } else {
                trimInvalidLineups()
                if gameVM.snapshot.resetsTeamFoulsEachPeriod {
                    gameVM.snapshot.currentPeriodFoulsBySide[TeamSide.home.rawValue] = 0
                    gameVM.snapshot.currentPeriodFoulsBySide[TeamSide.away.rawValue] = 0
                }
                if !gameVM.snapshot.startersRecorded {
                    gameVM.snapshot.starterPlayerIDs = unique(gameVM.snapshot.homeOnCourtPlayerIDs + gameVM.snapshot.awayOnCourtPlayerIDs)
                    gameVM.addEvent(
                        String(format: NSLocalizedString("event_starters_home_format", comment: "Home starters event format"), names(for: gameVM.snapshot.homeOnCourtPlayerIDs)),
                        eventCode: "event.starters_home"
                    )
                    gameVM.addEvent(
                        String(format: NSLocalizedString("event_starters_away_format", comment: "Away starters event format"), names(for: gameVM.snapshot.awayOnCourtPlayerIDs)),
                        eventCode: "event.starters_away"
                    )
                    gameVM.snapshot.startersRecorded = true
                }
                gameVM.snapshot.periodElapsedSeconds = 0
                gameVM.snapshot.periodActiveSince = nil
                gameVM.addEvent(
                    String(format: NSLocalizedString("event_period_start_format", comment: "Period start event format"), gameVM.snapshot.currentPeriod),
                    eventCode: "event.period_start"
                )
                startMatchClock(at: now)
                startPeriodClock(at: now)
                startActiveStints(at: now)
                gameVM.snapshot.periodIsRunning = true
                gameVM.snapshot.isPaused = false
            }
        }
        return true
    }

    @discardableResult
    private func applyTogglePauseOperation(at now: Date) -> Bool {
        guard gameVM.snapshot.periodIsRunning, !gameVM.snapshot.isComplete else { return false }

        mutateSnapshot {
            if gameVM.snapshot.isPaused {
                gameVM.snapshot.isPaused = false
                startMatchClock(at: now)
                startPeriodClock(at: now)
                startActiveStints(at: now)
                gameVM.addEvent(NSLocalizedString("event_game_resumed", comment: "Game resumed event"), eventCode: "event.resume")
            } else {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                gameVM.snapshot.isPaused = true
                gameVM.addEvent(NSLocalizedString("event_game_paused", comment: "Game paused event"), eventCode: "event.pause")
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

            if gameVM.snapshot.periodIsRunning && !gameVM.snapshot.isPaused {
                closeStint(for: outgoingPlayerID, at: now)
                startStint(for: incomingPlayerID, at: now)
            }

            gameVM.addEvent(
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
            gameVM.addEvent(
                String(format: NSLocalizedString("event_late_arrival_format", comment: "Late arrival event format"), name(for: playerID)),
                eventCode: "event.late_arrival"
            )
            changed = true
        }
        return changed
    }

    @discardableResult
    private func applyFinishGameOperation(at now: Date) -> Bool {
        guard !gameVM.snapshot.isComplete else { return false }

        mutateSnapshot {
            if gameVM.snapshot.periodIsRunning {
                closeActiveStints(at: now)
                closeMatchClock(at: now)
                closePeriodClock(at: now)
                gameVM.snapshot.periodIsRunning = false
                gameVM.addEvent(
                    String(format: NSLocalizedString("event_period_end_format", comment: "Period end event format"), gameVM.snapshot.currentPeriod),
                    eventCode: "event.period_end"
                )
            }
            gameVM.snapshot.isPaused = false
            gameVM.snapshot.isComplete = true
            gameVM.addEvent(NSLocalizedString("event_game_end", comment: "Game end event"), eventCode: "event.game_end")
        }
        return true
    }

    @discardableResult
    private func applyResetGameOperation(keepLiveSession: Bool) -> Bool {
        if !keepLiveSession {
            liveManager.resetSession()
        }

        gameVM.undoStack.removeAll()
        gameVM.redoStack.removeAll()
        currentGameRecordID = keepLiveSession ? currentGameRecordID : nil
        gameVM.snapshot = GameSnapshot(
            homeTeamID: gameVM.snapshot.homeTeamID,
            awayTeamID: gameVM.snapshot.awayTeamID,
            periodCount: gameVM.snapshot.periodCount,
            originalPeriodCount: gameVM.snapshot.originalPeriodCount,
            courtPlayerCount: gameVM.snapshot.courtPlayerCount,
            resetsTeamFoulsEachPeriod: gameVM.snapshot.resetsTeamFoulsEachPeriod,
            showsReboundButton: gameVM.snapshot.showsReboundButton,
            showsOffensiveDefensiveRebound: gameVM.snapshot.showsOffensiveDefensiveRebound,
            showsAssistButton: gameVM.snapshot.showsAssistButton,
            showsFoulButton: gameVM.snapshot.showsFoulButton,
            showsBlockButton: gameVM.snapshot.showsBlockButton,
            showsStealButton: gameVM.snapshot.showsStealButton,
            showsTurnoverButton: gameVM.snapshot.showsTurnoverButton
        )
        ensureSelectedPlayer()
        autoSaveCurrentGame()
        return true
    }

    private func startNewGame(with config: GameSetupConfig) {
        liveManager.resetSession()
        gameVM.undoStack.removeAll()
        gameVM.redoStack.removeAll()
        currentGameRecordID = UUID()
        gameVM.snapshot = GameSnapshot(
            homeTeamID: config.homeTeamID,
            awayTeamID: config.awayTeamID,
            periodCount: config.periodCount,
            originalPeriodCount: config.periodCount,
            courtPlayerCount: config.courtPlayerCount,
            resetsTeamFoulsEachPeriod: config.resetsTeamFoulsEachPeriod,
            showsReboundButton: config.showsReboundButton,
            showsOffensiveDefensiveRebound: config.showsOffensiveDefensiveRebound,
            showsAssistButton: config.showsAssistButton,
            showsFoulButton: config.showsFoulButton,
            showsBlockButton: config.showsBlockButton,
            showsStealButton: config.showsStealButton,
            showsTurnoverButton: config.showsTurnoverButton,
            homeOnCourtPlayerIDs: config.homeTeamStatsMode ? [] : config.homeStarterIDs,
            awayOnCourtPlayerIDs: config.awayTeamStatsMode ? [] : config.awayStarterIDs,
            homeAvailablePlayerIDs: config.homeTeamStatsMode ? [] : unique(config.homeStarterIDs + config.homeBenchIDs),
            awayAvailablePlayerIDs: config.awayTeamStatsMode ? [] : unique(config.awayStarterIDs + config.awayBenchIDs),
            periodEndCondition: config.periodEndCondition,
            periodTimeLimit: config.periodTimeLimit,
            periodScoreLimit: config.periodScoreLimit,
            homeTeamStatsMode: config.homeTeamStatsMode,
            awayTeamStatsMode: config.awayTeamStatsMode
        )
        voiceRecognizer.currentSnapshot = gameVM.snapshot
        selectedPlayerID = nil
        selectedSide = .home
        ensureSelectedPlayer()
        autoSaveCurrentGame()
    }

    private func saveCurrentGame() {
        var snapshotForSaving = gameVM.snapshot
        let now = Date()
        closeActiveStints(in: &snapshotForSaving, at: now)
        closeMatchClock(in: &snapshotForSaving, at: now)
        closePeriodClock(in: &snapshotForSaving, at: now)
        snapshotForSaving.periodIsRunning = false
        currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: gameVM.undoStack)
        store.saveIfNeeded()
        saveConfirmation = NSLocalizedString("game_saved_to_history", comment: "Saved to history confirmation")
    }

    private func finishGame() {
        guard !gameVM.snapshot.isComplete else { return }
        let now = Date()
        _ = liveManager.submitLiveOperation(.finishGame(at: now)) {
            applyFinishGameOperation(at: now)
        }
    }

    private func prepareSubstitutionDefaults() {
        let onCourt = substitutionSide == .home ? gameVM.snapshot.homeOnCourtPlayerIDs : gameVM.snapshot.awayOnCourtPlayerIDs
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
        _ = liveManager.submitLiveOperation(
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

        let periodCount = min(max(gameVM.snapshot.periodCount, 1), 8)
        let courtCount = max(1, min(gameVM.snapshot.courtPlayerCount, context.homeRosterIDs.count, context.awayRosterIDs.count))
        let homeAvailable = context.homeRosterIDs.shuffled()
        let awayAvailable = context.awayRosterIDs.shuffled()

        var simulated = GameSnapshot(
            homeTeamID: context.homeTeam.id,
            awayTeamID: context.awayTeam.id,
            periodCount: periodCount,
            originalPeriodCount: periodCount,
            courtPlayerCount: courtCount,
            resetsTeamFoulsEachPeriod: gameVM.snapshot.resetsTeamFoulsEachPeriod,
            showsReboundButton: gameVM.snapshot.showsReboundButton,
            showsOffensiveDefensiveRebound: gameVM.snapshot.showsOffensiveDefensiveRebound,
            showsAssistButton: gameVM.snapshot.showsAssistButton,
            showsFoulButton: gameVM.snapshot.showsFoulButton,
            showsBlockButton: gameVM.snapshot.showsBlockButton,
            showsStealButton: gameVM.snapshot.showsStealButton,
            showsTurnoverButton: gameVM.snapshot.showsTurnoverButton,
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
               gameVM.snapshot.showsAssistButton,
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

            if !isMade, gameVM.snapshot.showsReboundButton, Double.random(in: 0...1) < 0.58 {
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
                } else if roll < 0.88, gameVM.snapshot.showsStealButton {
                    addStealEvent()
                } else if roll < 0.93, gameVM.snapshot.showsBlockButton {
                    addBlockEvent()
                } else if roll < 0.97, gameVM.snapshot.showsTurnoverButton {
                    addTurnoverEvent()
                } else if roll < 0.99 {
                    addSubstitutionEvent()
                } else if gameVM.snapshot.showsReboundButton {
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

        gameVM.undoStack.removeAll()
        gameVM.redoStack.removeAll()
        currentGameRecordID = UUID()
        gameVM.snapshot = simulated
        selectedPlayerID = gameVM.snapshot.homeOnCourtPlayerIDs.first
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

        let preferredHomeRoster = rosterIDs(for: gameVM.snapshot.homeTeamID)
        let preferredAwayRoster = rosterIDs(for: gameVM.snapshot.awayTeamID)
        if let homeTeam = store.team(for: gameVM.snapshot.homeTeamID),
           let awayTeam = store.team(for: gameVM.snapshot.awayTeamID),
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
        _ = liveManager.submitLiveOperation(
            .lateArrival(playerID: incomingPlayerID, side: lateArrivalSide.liveSide)
        ) {
            applyLateArrivalOperation(playerID: incomingPlayerID, side: lateArrivalSide)
        }
    }
    private func undo() {
        guard !gameVM.undoStack.isEmpty else { return }
        _ = liveManager.submitLiveOperation(.undo) {
            gameVM.undo()
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    private func redo() {
        guard !gameVM.redoStack.isEmpty else { return }
        _ = liveManager.submitLiveOperation(.redo) {
            gameVM.redo()
            ensureSelectedPlayer()
            autoSaveCurrentGame()
            return true
        }
    }

    private func resetGame() {
        _ = liveManager.submitLiveOperation(.resetGame) {
            applyResetGameOperation(keepLiveSession: liveManager.isLiveSessionActive)
        }
    }


    private func conditionLabel(_ condition: PeriodEndCondition) -> String {
        switch condition {
        case .manual: return NSLocalizedString("period_end_manual", comment: "")
        case .byTime: return NSLocalizedString("period_end_by_time", comment: "")
        case .byScore: return NSLocalizedString("period_end_by_score", comment: "")
        }
    }

    private func startOvertime() {
        isShowingOTSetup = false
        mutateSnapshot {
            gameVM.snapshot.isComplete = false
            gameVM.snapshot.periodCount += otPeriodCount
            gameVM.snapshot.periodEndCondition = otPeriodEndCondition
            gameVM.snapshot.periodTimeLimit = otTimeLimit
            gameVM.snapshot.periodScoreLimit = otScoreLimit
            gameVM.snapshot.currentPeriod += 1
            gameVM.snapshot.periodElapsedSeconds = 0
            gameVM.snapshot.periodActiveSince = nil
            gameVM.snapshot.periodIsRunning = false
            gameVM.snapshot.isPaused = false
            gameVM.addEvent(
                String(format: NSLocalizedString("event_overtime_start_format", comment: "Overtime start event format"), otPeriodCount),
                eventCode: "event.ot_start"
            )
        }
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

    private func clearVoiceFlashAfterDelay() {
        voiceFlashDismissTask?.cancel()
        voiceFlashDismissTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.16)) {
                    voiceFlashColor = nil
                }
            }
        }
    }

    private func clearVoiceMatchAfterDelay(playerID: UUID) {
        voiceMatchDismissTask?.cancel()
        voiceMatchDismissTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard voiceMatch?.playerID == playerID else { return }
                voiceMatch = nil
            }
        }
    }

    private func clearVoiceSuccessAfterDelay(playerID: UUID) {
        voiceSuccessDismissTask?.cancel()
        voiceSuccessDismissTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard voiceSuccessItem?.player.id == playerID else { return }
                voiceSuccessItem = nil
            }
        }
    }

    private func clearVoiceErrorAfterDelay() {
        voiceErrorDismissTask?.cancel()
        voiceErrorDismissTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                voiceErrorMessage = nil
            }
        }
    }



    private var scoreSuffix: String {
        "(\(score(for: gameVM.snapshot.homeTeamID)):\(score(for: gameVM.snapshot.awayTeamID)))"
    }

    private func mutateSnapshot(pushUndo: Bool = true, _ updates: () -> Void) {
        gameVM.mutateSnapshot(pushUndo: pushUndo, updates)
        autoSaveCurrentGame()
    }

    private func autoSaveCurrentGame() {
        var snapshotForSaving = gameVM.snapshot
        if liveManager.activeLiveSessionID != nil {
            snapshotForSaving.wasBluetoothCollaborated = true
        }
        if snapshotForSaving.logs.isEmpty {
            guard let currentGameRecordID,
                  store.savedGames.contains(where: { $0.id == currentGameRecordID }) else {
                return
            }
            self.currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: gameVM.undoStack)
            return
        }
        currentGameRecordID = store.autoSaveGame(snapshotForSaving, gameID: currentGameRecordID, undoSnapshots: gameVM.undoStack)
    }

    private func restoreLatestGameIfNeeded() {
        guard !hasRestoredLatestGame else { return }
        hasRestoredLatestGame = true

        if let latest = store.latestUnfinishedGame() {
            gameVM.snapshot = latest.snapshot
            voiceRecognizer.currentSnapshot = gameVM.snapshot
            gameVM.undoStack = []
            gameVM.redoStack.removeAll()
            currentGameRecordID = latest.id
            trimInvalidLineups()
            ensureSelectedPlayer()
            return
        }

        ensureInitialSelection()
    }

    private func startActiveStints(at date: Date) {
        (gameVM.snapshot.homeOnCourtPlayerIDs + gameVM.snapshot.awayOnCourtPlayerIDs).forEach { playerID in
            startStint(for: playerID, at: date)
        }
    }

    private func startMatchClock(at date: Date) {
        if gameVM.snapshot.matchActiveSince == nil {
            gameVM.snapshot.matchActiveSince = date
        }
    }

    private func startPeriodClock(at date: Date) {
        if gameVM.snapshot.periodActiveSince == nil {
            gameVM.snapshot.periodActiveSince = date
        }
    }

    private func startStint(for playerID: UUID, at date: Date) {
        if gameVM.snapshot.activeSinceByPlayerID[playerID] == nil {
            gameVM.snapshot.activeSinceByPlayerID[playerID] = date
        }
    }

    private func closeActiveStints(at date: Date) {
        closeActiveStints(in: &gameVM.snapshot, at: date)
    }

    private func closeActiveStints(in target: inout GameSnapshot, at date: Date) {
        for (playerID, startedAt) in target.activeSinceByPlayerID {
            target.playingSecondsByPlayerID[playerID, default: 0] += max(0, date.timeIntervalSince(startedAt))
        }
        target.activeSinceByPlayerID.removeAll()
    }

    private func closeMatchClock(at date: Date) {
        closeMatchClock(in: &gameVM.snapshot, at: date)
    }

    private func closeMatchClock(in target: inout GameSnapshot, at date: Date) {
        guard let activeSince = target.matchActiveSince else { return }
        target.matchElapsedSeconds += max(0, date.timeIntervalSince(activeSince))
        target.matchActiveSince = nil
    }

    private func closePeriodClock(at date: Date) {
        closePeriodClock(in: &gameVM.snapshot, at: date)
    }

    private func closePeriodClock(in target: inout GameSnapshot, at date: Date) {
        guard let activeSince = target.periodActiveSince else { return }
        target.periodElapsedSeconds += max(0, date.timeIntervalSince(activeSince))
        target.periodActiveSince = nil
    }

    private func closeStint(for playerID: UUID, at date: Date) {
        guard let startedAt = gameVM.snapshot.activeSinceByPlayerID[playerID] else { return }
        gameVM.snapshot.playingSecondsByPlayerID[playerID, default: 0] += max(0, date.timeIntervalSince(startedAt))
        gameVM.snapshot.activeSinceByPlayerID[playerID] = nil
    }

    private func applyPlusMinus(points: Int, scoringSide: TeamSide) {
        applyPlusMinus(points: points, scoringSide: scoringSide, in: &gameVM.snapshot)
    }

    private func applyPlusMinus(points: Int, scoringSide: TeamSide, in target: inout GameSnapshot) {
        let scoringIDs = scoringSide == .home ? target.homeOnCourtPlayerIDs : target.awayOnCourtPlayerIDs
        let defendingIDs = scoringSide == .home ? target.awayOnCourtPlayerIDs : target.homeOnCourtPlayerIDs
        scoringIDs.forEach { target.plusMinusByPlayerID[$0, default: 0] += points }
        defendingIDs.forEach { target.plusMinusByPlayerID[$0, default: 0] -= points }
    }

    /// Revert the last action directly on the current gameVM.snapshot. Returns true if successful.
    @discardableResult
    private func revertLastAction() -> Bool {
        guard let lastLog = gameVM.snapshot.logs.last else { return false }
        let normalizedMessage = normalizedLogMessage(lastLog.message)
        let lastEventCode = lastLog.eventCode ?? GameLogFormatter.extractEventCode(from: lastLog.message)

        gameVM.snapshot.logs.removeLast()

        switch lastEventCode {
        case "event.game_saved":
            return true

        case "event.game_end":
            gameVM.snapshot.isComplete = false
            return true

        case "event.substitution":
            guard let incomingID = lastLog.playerID else { return false }
            guard let side = sideOfPlayer(incomingID, in: gameVM.snapshot) else { return false }
            let outgoingID: UUID
            if let storedOutgoingID = lastLog.relatedPlayerID {
                outgoingID = storedOutgoingID
            } else {
                return false
            }
            // Swap back: remove incoming, add outgoing
            if side == .home {
                gameVM.snapshot.homeOnCourtPlayerIDs.removeAll { $0 == incomingID }
                if !gameVM.snapshot.homeOnCourtPlayerIDs.contains(outgoingID) {
                    gameVM.snapshot.homeOnCourtPlayerIDs.append(outgoingID)
                }
            } else {
                gameVM.snapshot.awayOnCourtPlayerIDs.removeAll { $0 == incomingID }
                if !gameVM.snapshot.awayOnCourtPlayerIDs.contains(outgoingID) {
                    gameVM.snapshot.awayOnCourtPlayerIDs.append(outgoingID)
                }
            }
            return true

        case "event.period_start":
            let now = Date()
            closeActiveStints(at: now)
            closeMatchClock(at: now)
            closePeriodClock(at: now)
            gameVM.snapshot.periodIsRunning = false
            gameVM.snapshot.isPaused = false
            return true

        case "event.period_end":
            // Revert ending a period: period was running, mark it running again
            if gameVM.snapshot.currentPeriod > 1 {
                gameVM.snapshot.currentPeriod -= 1
            }
            gameVM.snapshot.periodIsRunning = true
            return true

        case "event.late_arrival":
            // Remove the late-arriving player from team roster
            guard let playerID = lastLog.playerID else { return false }
            if gameVM.snapshot.homeAvailablePlayerIDs.contains(playerID) {
                gameVM.snapshot.homeAvailablePlayerIDs.removeAll { $0 == playerID }
            } else if gameVM.snapshot.awayAvailablePlayerIDs.contains(playerID) {
                gameVM.snapshot.awayAvailablePlayerIDs.removeAll { $0 == playerID }
            }
            return true

        default:
            let parsed = StatAction.parseLog(normalizedMessage)
            guard let action = StatAction.allCases.first(where: { $0.eventCode == lastEventCode }) ?? parsed?.action else {
                return false
            }

            guard let playerID = lastLog.playerID
                    ?? parsed.flatMap({ playerID(for: $0.playerName, action: action, in: gameVM.snapshot) }),
                  let side = sideOfPlayer(playerID, in: gameVM.snapshot) else {
                return false
            }

            var stats = gameVM.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            guard action.revert(on: &stats) else { return false }
            gameVM.snapshot.statsByPlayerID[playerID] = stats

            // Revert related player for composite events
            if let related = action.relatedAction, let rpid = lastLog.relatedPlayerID {
                var relatedStats = gameVM.snapshot.statsByPlayerID[rpid, default: PlayerStats()]
                guard related.revert(on: &relatedStats) else { return false }
                gameVM.snapshot.statsByPlayerID[rpid] = relatedStats
            }

            if action == .foul {
                let currentFouls = gameVM.snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0]
                gameVM.snapshot.currentPeriodFoulsBySide[side.rawValue] = max(0, currentFouls - 1)
            }

            if action.points > 0 {
                applyPlusMinus(points: -action.points, scoringSide: side, in: &gameVM.snapshot)
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

    static func dualStealMessage(pn1: String, pn2: String, locale: Locale) -> String {
        let lang = locale.identifier
        if lang.hasPrefix("zh-Hant") {
            return "\(pn1)抄截\(pn2)"
        } else if lang.hasPrefix("zh") {
            return "\(pn1)抢断\(pn2)"
        } else if lang.hasPrefix("ja") {
            return "\(pn1)が\(pn2)からスティール"
        } else if lang.hasPrefix("ko") {
            return "\(pn1)가\(pn2)를 스틸"
        } else if lang.hasPrefix("es") {
            return "\(pn1) robo a \(pn2)"
        } else if lang.hasPrefix("fr") {
            return "\(pn1) interception \(pn2)"
        } else if lang.hasPrefix("it") {
            return "\(pn1) palla rubata a \(pn2)"
        } else if lang.hasPrefix("de") {
            return "\(pn1) steal \(pn2)"
        } else if lang.hasPrefix("ru") {
            return "\(pn1) перехват у \(pn2)"
        } else {
            return "\(pn1) stole from \(pn2)"
        }
    }

    static func dualAssistMessage(pn1: String, pn2: String, shot: String, locale: Locale) -> String {
        let lang = locale.identifier
        if lang.hasPrefix("zh-Hant") {
            return "\(pn1)助攻\(pn2)\(shot)"
        } else if lang.hasPrefix("zh") {
            return "\(pn1)助攻\(pn2)\(shot)"
        } else if lang.hasPrefix("ja") {
            return "\(pn1)が\(pn2)の\(shot)アシスト"
        } else if lang.hasPrefix("ko") {
            return "\(pn1)가\(pn2)의 \(shot) 어시스트"
        } else if lang.hasPrefix("es") {
            return "\(pn1) asistio a \(pn2) para \(shot)"
        } else if lang.hasPrefix("fr") {
            return "\(pn1) passe a \(pn2) pour \(shot)"
        } else if lang.hasPrefix("it") {
            return "\(pn1) assist per \(pn2) \(shot)"
        } else if lang.hasPrefix("de") {
            return "\(pn1) assist \(pn2) fur \(shot)"
        } else if lang.hasPrefix("ru") {
            return "\(pn1) ассист \(pn2) на \(shot)"
        } else {
            return "\(pn1) assisted \(pn2) for \(shot)"
        }
    }

    private func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    static func durationFormatter(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func periodContextText(period: Int?, elapsedSeconds: TimeInterval?, originalPeriodCount: Int = 4) -> String {
        guard let period else { return "" }
        let label: String
        if period > originalPeriodCount {
            label = "OT\(period - originalPeriodCount)"
        } else {
            label = String(format: NSLocalizedString("period_context_only_format", comment: "Period context without elapsed time"), period)
        }
        guard let elapsedSeconds else { return label }
        return "\(label) \(durationFormatter(elapsedSeconds))"
    }

    private func logText(for entry: GameLogEntry) -> String {
        let periodText = Self.periodContextText(period: entry.period, elapsedSeconds: entry.periodElapsedSeconds, originalPeriodCount: gameVM.snapshot.originalPeriodCount)
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
