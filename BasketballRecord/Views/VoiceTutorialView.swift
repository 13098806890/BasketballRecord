import SwiftUI

struct VoiceTutorialView: View {
    @ObservedObject var store: AppStore
    @StateObject private var recognizer = VoiceRecognizer()

    private static let playerIDs: [UUID] = [
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E50")!,
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E51")!,
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E52")!,
    ]

    private let tutorialPlayers: TutorialPlayers
    private let tasks: [TutorialTaskDef]
    private let substitutionTaskID: Int
    private let freePlayTaskID: Int
    private static let dualActionTaskIDs: Set<Int> = [20, 25]
    private static let commandTaskIDs: Set<Int> = [21, 22, 23, 24]
    private static let keepOriginalHintTaskIDs: Set<Int> = [18]

    @State private var snapshot = GameSnapshot()
    @State private var selectedTaskIndex: Int
    @State private var taskResults: [Bool?]
    @State private var tutorialLog: [String]
    @State private var feedbackMessage = ""
    @State private var feedbackIsSuccess = false
    @State private var isWaitingForResult = false
    @State private var animatingTaskID: Int?
    @State private var voiceLanguage: String = ""
    @State private var isPaused = false
    @State private var showingFreePlay = false
    @State private var scrollTarget: Int?
    @State private var totalAttempts: Int
    @State private var successfulAttempts: Int
    @State private var freePlayReboundMode = false
    @State private var voiceErrorMessage: String?

    private var isFreePlaySelected: Bool { showingFreePlay }

    private static let resultsKey = "voice_tutorial_results"
    private static let attemptsKey = "voice_tutorial_attempts"
    private static let successAttemptsKey = "voice_tutorial_success_attempts"

    init(store: AppStore, voiceLocale: String? = nil) {
        self.store = store
        let lang = voiceLocale ?? Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        let data = TutorialDataProvider.localizedData(for: lang, playerIDs: Self.playerIDs)
        tutorialPlayers = data.players
        tasks = data.tasks.filter { $0.id != data.freePlayTaskID }
        substitutionTaskID = data.substitutionTaskID
        freePlayTaskID = data.freePlayTaskID

        tutorialLog = []
        let saved = UserDefaults.standard.string(forKey: Self.resultsKey) ?? ""
        let decoded = Self.decodeResults(from: saved, count: data.tasks.count)
        let freePlayIdx = data.tasks.firstIndex(where: { $0.id == data.freePlayTaskID }) ?? (data.tasks.count - 1)
        let filteredResults = decoded.enumerated()
            .filter { $0.offset != freePlayIdx }
            .map { $0.element }
        taskResults = filteredResults
        let firstUncompleted = filteredResults.firstIndex(where: { $0 == nil }) ?? 0
        _selectedTaskIndex = State(initialValue: firstUncompleted)
        _totalAttempts = State(initialValue: UserDefaults.standard.integer(forKey: Self.attemptsKey))
        _successfulAttempts = State(initialValue: UserDefaults.standard.integer(forKey: Self.successAttemptsKey))
        _voiceLanguage = State(initialValue: voiceLocale ?? "")
    }

    fileprivate var selectedTask: TutorialTaskDef? {
        guard selectedTaskIndex < tasks.count else { return nil }
        return tasks[selectedTaskIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            playerHeader

            modeToggleView

            if showingFreePlay {
                Toggle(isOn: $freePlayReboundMode) {
                    Label(LocalizedStringKey("action_offensive_defensive_rebound"), systemImage: "rectangle.split.2x2")
                        .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .onChange(of: freePlayReboundMode) { _, newValue in
                    recognizer.setReboundFilterMode(newValue ? true : nil)
                }

                if !tutorialLog.isEmpty {
                    eventFlowView
                        .frame(maxHeight: .infinity)
                }
                Spacer()
            } else if selectedTask == nil {
                completionView
            } else {
                taskListView
                    .frame(maxHeight: 330)

                currentTaskCard

                Spacer()
            }
        }
        .navigationTitle(LocalizedStringKey("settings_voice_tutorial"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    resetTutorial()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(selectedTaskIndex == 0 && taskResults.allSatisfy { $0 == nil })
            }
        }
        .onAppear(perform: setupTutorial)
        .onDisappear(perform: cleanupTutorial)
        .overlay(alignment: .bottom) {
            if showingFreePlay || selectedTask != nil {
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
                    micButton
                }
                .padding(.bottom, 24)
            }
        }
        .overlay(alignment: .center) {
            if recognizer.isRecording {
                voiceWave
                    .allowsHitTesting(false)
            }
        }
    }

    private var playerHeader: some View {
        VStack(spacing: 6) {
            teamRow(
                side: .home,
                teamName: tutorialPlayers.homeTeamName,
                players: tutorialPlayers.home
            )
            teamRow(
                side: .away,
                teamName: tutorialPlayers.awayTeamName,
                players: tutorialPlayers.away
            )
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    private func teamRow(side: TeamSide, teamName: String, players: [Player]) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(teamName)
                        .font(.caption.weight(.semibold))
                    Text(side == .home ? LocalizedStringKey("team_home_default") : LocalizedStringKey("team_away_default"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: players.count >= 5 ? 0 : 6) {
                    ForEach(players) { player in
                        VStack(spacing: 3) {
                            PlayerAvatarView(player: player, size: 42)
                            Text(player.number.isEmpty ? player.name : "No\(player.number) \(player.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(7.0 / 12.0)
                                .frame(width: 64)
                        }
                        .opacity(0.85)
                    }
                }
                .padding(.vertical, 7)
                .padding(.trailing, 8)
            }
        }
        .frame(height: 78)
        .padding(.horizontal, 12)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.85), lineWidth: 1))
        .padding(.horizontal)
    }

    private var taskListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                        taskRow(task, index: idx)
                            .id(idx)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectTask(idx)
                            }
                    }
                }
                .padding()
            }
            .onChange(of: scrollTarget) { _, target in
                if let t = target {
                    withAnimation {
                        proxy.scrollTo(t, anchor: .top)
                    }
                    scrollTarget = nil
                }
            }
        }
    }

    private var modeToggleView: some View {
        HStack(spacing: 0) {
            Button {
                showingFreePlay = false
            } label: {
                Text("voice_tutorial_tab_tasks")
                    .font(.subheadline.weight(showingFreePlay ? .regular : .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .foregroundStyle(showingFreePlay ? .secondary : .primary)

            Button {
                showingFreePlay = true
            } label: {
                Text("voice_tutorial_tab_freeplay")
                    .font(.subheadline.weight(showingFreePlay ? .semibold : .regular))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
            .foregroundStyle(showingFreePlay ? .primary : .secondary)
        }
        .background(Color(.systemGray5), in: Capsule())
        .padding(.vertical, 6)
    }

    private var eventFlowView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Event Flow")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(tutorialLog.count) event(s)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(tutorialLog.reversed().enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.caption.monospacedDigit().weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 3)
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func taskRow(_ task: TutorialTaskDef, index: Int) -> some View {
        let isSelected = index == selectedTaskIndex
        let result = index < taskResults.count ? taskResults[index] : nil
        let isAnimating = animatingTaskID == task.id

        return HStack(spacing: 10) {
            Group {
                if let r = result {
                    Image(systemName: r ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(r ? .green : .red)
                        .font(.title3)
                        .scaleEffect(isAnimating ? 1.3 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAnimating)
                } else if isSelected {
                    Image(systemName: "arrowtriangle.right.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                }
            }
            .frame(width: 24)

            Text("\(index + 1).")
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
            Text(task.description)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(result == nil && !isSelected ? .tertiary : .primary)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var currentTaskCard: some View {
        VStack(spacing: 12) {
            if let task = selectedTask {
                VStack(spacing: 4) {
                    Text(LocalizedStringKey("voice_tutorial_current_task"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(task.hint)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }
                .padding()
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
            Image(systemName: recognizer.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(recognizer.isRecording ? Color.blue : Color.primary)
                .scaleEffect(recognizer.isRecording ? 1.15 : 1)
                .animation(.spring(response: 0.2), value: recognizer.isRecording)
        }
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !recognizer.isRecording {
                        isWaitingForResult = true
                        recognizer.startRecording()
                    }
                }
                .onEnded { _ in
                    recognizer.stopRecording()
                }
        )
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

    private var completionView: some View {
        let successCount = taskResults.compactMap { $0 }.filter { $0 }.count
        let rate = totalAttempts > 0 ? Double(successfulAttempts) / Double(totalAttempts) * 100 : 0
        let passed = rate >= 90
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: passed ? "star.fill" : "flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(passed ? .yellow : .blue)
            Text(passed
                 ? LocalizedStringKey("voice_tutorial_complete_all")
                 : LocalizedStringKey("voice_tutorial_complete_done"))
                .font(.title2.weight(.bold))
            Text(String(format: NSLocalizedString("voice_tutorial_score", comment: ""), successCount, tasks.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: NSLocalizedString("voice_tutorial_rate", comment: ""), rate))
                .font(.headline)
                .foregroundStyle(passed ? .green : .orange)
            Button(LocalizedStringKey("voice_tutorial_restart")) {
                resetTutorial()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func selectTask(_ index: Int) {
        guard index < tasks.count else { return }
        let ids = Self.playerIDs
        selectedTaskIndex = index
        feedbackMessage = ""
        voiceErrorMessage = nil
        let task = tasks[index]
        if task.id == substitutionTaskID {
            snapshot.homeOnCourtPlayerIDs = [ids[0]]
            snapshot.awayOnCourtPlayerIDs = [ids[2]]
            snapshot.homeAvailablePlayerIDs = [ids[0], ids[1]]
            snapshot.awayAvailablePlayerIDs = [ids[2], ids[3]]
        } else {
            snapshot.homeOnCourtPlayerIDs = [ids[0], ids[1]]
            snapshot.awayOnCourtPlayerIDs = [ids[2], ids[3]]
            snapshot.homeAvailablePlayerIDs = [ids[0], ids[1]]
            snapshot.awayAvailablePlayerIDs = [ids[2], ids[3]]
        }
        recognizer.currentSnapshot = snapshot
        if task.expectedAction == .offensiveRebound || task.expectedAction == .defensiveRebound {
            recognizer.setReboundFilterMode(true)
        } else if task.expectedAction == .rebound {
            recognizer.setReboundFilterMode(false)
        } else {
            recognizer.setReboundFilterMode(nil)
        }
    }

    private func setupTutorial() {
        store.players.append(contentsOf: tutorialPlayers.all)

        let ids = Self.playerIDs
        snapshot = GameSnapshot(
            homeOnCourtPlayerIDs: [ids[0], ids[1]],
            awayOnCourtPlayerIDs: [ids[2], ids[3]],
            homeAvailablePlayerIDs: [ids[0], ids[1]],
            awayAvailablePlayerIDs: [ids[2], ids[3]],
            homeTeamStatsMode: false,
            awayTeamStatsMode: false
        )

        recognizer.configure(store: store)
        if !voiceLanguage.isEmpty {
            recognizer.updateRules(for: Locale(identifier: voiceLanguage))
        }
        recognizer.onClear = { [self] in
            voiceErrorMessage = nil
        }
        recognizer.onError = { [self] msg in
            voiceErrorMessage = msg
        }
        recognizer.onAction = { [self] action, playerID, _ in
            let pn = store.player(for: playerID)?.name ?? "?"
            tutorialLog.append("\(pn) \(action.message)")

            if isFreePlaySelected {
                isWaitingForResult = false
                return
            }

            guard !recognizer.isRecording, isWaitingForResult, let task = selectedTask else { return }
            if Self.dualActionTaskIDs.contains(task.id) || Self.commandTaskIDs.contains(task.id) {
                markTask(success: false)
                isWaitingForResult = false
                return
            }
            if action == task.expectedAction && playerID == task.expectedPlayerID {
                markTask(success: true)
            } else {
                markTask(success: false)
            }
            isWaitingForResult = false
        }
        recognizer.onDualAction = { [self] action1, pid1, _, action2, pid2, _ in
            let pn1 = store.player(for: pid1)?.name ?? "?"
            let pn2 = store.player(for: pid2)?.name ?? "?"
            let locale = recognizer.currentRules.locale
            let msg: String
            if action1 == .steal && action2 == .turnover {
                msg = GameView.dualStealMessage(pn1: pn1, pn2: pn2, locale: locale)
            } else {
                msg = GameView.dualAssistMessage(pn1: pn1, pn2: pn2, shot: action2.message, locale: locale)
            }
            tutorialLog.append(msg)

            if isFreePlaySelected {
                isWaitingForResult = false
                return
            }

            guard !recognizer.isRecording, isWaitingForResult, let task = selectedTask else { return }
            if Self.commandTaskIDs.contains(task.id) {
                markTask(success: false)
                isWaitingForResult = false
                return
            }
            if action1 == task.expectedAction && pid1 == task.expectedPlayerID {
                markTask(success: true)
            } else {
                markTask(success: false)
            }
            isWaitingForResult = false
        }
        recognizer.onSubstitution = { [self] side, outgoingID, incomingID in
            let outN = store.player(for: outgoingID)?.name ?? "?"
            let inN = store.player(for: incomingID)?.name ?? "?"
            tutorialLog.append(String(format: NSLocalizedString("event_substitution_format", comment: ""), inN, outN))

            if isFreePlaySelected {
                isWaitingForResult = false
                return
            }

            guard !recognizer.isRecording, isWaitingForResult, let task = selectedTask, task.id == substitutionTaskID else { return }
            let ids = Self.playerIDs
            if outgoingID == ids[0] && incomingID == ids[1] && side == .home {
                markTask(success: true)
            } else {
                markTask(success: false)
            }
            isWaitingForResult = false
        }
        recognizer.onCommand = { [self] command in
            if isFreePlaySelected {
                _ = recognizer.currentRules.locale
                switch command {
                case .startPeriod:
                    tutorialLog.append(String(format: NSLocalizedString("event_period_start_format", comment: ""), snapshot.currentPeriod))
                case .togglePause:
                    isPaused.toggle()
                    tutorialLog.append(NSLocalizedString(isPaused ? "event_game_paused" : "event_game_resumed", comment: ""))
                default:
                    break
                }
                isWaitingForResult = false
                return
            }

            guard !recognizer.isRecording, isWaitingForResult, let task = selectedTask, Self.commandTaskIDs.contains(task.id) else { return }
            switch command {
            case .startPeriod:
                if task.id == 21 || task.id == 24 {
                    markTask(success: true)
                } else {
                    markTask(success: false)
                }
            case .togglePause:
                if task.id == 22 || task.id == 23 {
                    markTask(success: true)
                } else {
                    markTask(success: false)
                }
            default:
                markTask(success: false)
            }
            isWaitingForResult = false
        }
        recognizer.currentSnapshot = snapshot
    }

    private func cleanupTutorial() {
        recognizer.stopRecording()
        store.players.removeAll { Self.playerIDs.contains($0.id) }
    }

    private func resetTutorial() {
        selectedTaskIndex = 0
        showingFreePlay = false
        totalAttempts = 0
        successfulAttempts = 0
        taskResults = Array(repeating: nil, count: tasks.count)
        clearSavedResults()
        feedbackMessage = ""
        isWaitingForResult = false
        animatingTaskID = nil
        let ids = Self.playerIDs
        snapshot.homeOnCourtPlayerIDs = [ids[0], ids[1]]
        snapshot.awayOnCourtPlayerIDs = [ids[2], ids[3]]
        snapshot.homeAvailablePlayerIDs = [ids[0], ids[1]]
        snapshot.awayAvailablePlayerIDs = [ids[2], ids[3]]
        recognizer.currentSnapshot = snapshot
    }

    private func markTask(success: Bool) {
        guard selectedTaskIndex < tasks.count else { return }
        let taskID = tasks[selectedTaskIndex].id
        taskResults[selectedTaskIndex] = success
        totalAttempts += 1
        if success { successfulAttempts += 1 }
        saveResults()
        voiceErrorMessage = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            animatingTaskID = taskID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            animatingTaskID = nil
        }

        if success {
            let nextIndex = selectedTaskIndex + 1
            if nextIndex < tasks.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    selectTask(nextIndex)
                    scrollTarget = nextIndex
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    selectedTaskIndex = tasks.count
                }
            }
        }
    }

    private static func decodeResults(from string: String, count: Int) -> [Bool?] {
        let parts = string.split(separator: ",", omittingEmptySubsequences: false)
        return (0..<count).map { i in
            guard i < parts.count else { return nil }
            if parts[i] == "1" { return true }
            if parts[i] == "0" { return false }
            return nil
        }
    }

    private static func encodeResults(_ results: [Bool?]) -> String {
        results.map { $0 == true ? "1" : $0 == false ? "0" : "" }.joined(separator: ",")
    }

    private func saveResults() {
        let encoded = Self.encodeResults(taskResults)
        UserDefaults.standard.set(encoded, forKey: Self.resultsKey)
        UserDefaults.standard.set(totalAttempts, forKey: Self.attemptsKey)
        UserDefaults.standard.set(successfulAttempts, forKey: Self.successAttemptsKey)
    }

    private func clearSavedResults() {
        UserDefaults.standard.removeObject(forKey: Self.resultsKey)
    }
}

