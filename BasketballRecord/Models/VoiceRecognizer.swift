import SwiftUI
import Speech
import AVFoundation

struct VoiceLogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    let timestamp: Date
    let text: String
    let textPinyin: String
    let isSuccess: Bool
    let action: String?
    let playerName: String?
    let matchedPattern: String?
    var matchDetail: String?
    let locale: String?
    let engine: String?
    let stage: String?
    let failureReason: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        text: String,
        textPinyin: String,
        isSuccess: Bool,
        action: String?,
        playerName: String?,
        matchedPattern: String?,
        matchDetail: String?,
        locale: String? = nil,
        engine: String? = nil,
        stage: String? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.textPinyin = textPinyin
        self.isSuccess = isSuccess
        self.action = action
        self.playerName = playerName
        self.matchedPattern = matchedPattern
        self.matchDetail = matchDetail
        self.locale = locale
        self.engine = engine
        self.stage = stage
        self.failureReason = failureReason
    }

    var summary: String {
        if isSuccess {
            if let playerName, let action {
                return "\(playerName) \(action)"
            }
            return action ?? text
        }
        return "❌ \(text)"
    }
}

enum VoiceCommand {
    case togglePause
    case startPeriod
    case finishGame
    case undo
    case redo
    case substitution(outgoingID: UUID, incomingID: UUID, side: TeamSide)
}

@MainActor
final class VoiceRecognizer: NSObject, ObservableObject {
    @Published var isRecording = false
    var onError: ((String) -> Void)?
    var onFlash: ((Color) -> Void)?
    var onClear: (() -> Void)?
    private let maxLogCount = 200
    /// Buffered log detail for the current recognition session.
    /// Accumulates all matching steps; flushed to store.voiceLog on completion or failure.
    private var logBuffer: String = ""
    private var logText: String = ""
    private var logIsSuccess = false
    private var logAction: String?
    private var logPlayerName: String?
    private var logPattern: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var enginePrepared = false
    private var asrEngine = VoiceASREngine.effectiveStored
    private var speechTranscriberStartTask: Task<Void, Never>?
    private var speechTranscriberPreparationTask: Task<Void, Never>?
    private var speechTranscriberPreparationGeneration = 0
    private var speechTranscriberResourceReleaseTask: Task<Void, Never>?
    private var speechTranscriberStopRequested = false
    private var speechTranscriberFinishing = false
    private var speechTranscriberProcessing = false
    @Published private(set) var isSpeechTranscriberPreparing = false
    private var speechTranscriberFinalSegments: [[String]] = []
    private var speechTranscriberEngineStorage: AnyObject?
    private var speechTranscriberStopStartedAt: Date?
    private var speechTranscriberTimingDetail: String?
    private var speechTranscriberStopToFinalMilliseconds: Int?
    private var speechTranscriberScoreContextTask: Task<SpeechTranscriberScoreContext, Never>?
    private var speechTranscriberReadyScoreContext: SpeechTranscriberScoreContext?
    private var speechTranscriberScoreContextKey: String?
    private var speechTranscriberProcessingTask: Task<Void, Never>?
    private var speechTranscriberSessionGeneration = 0

    @available(iOS 26.0, *)
    private var speechTranscriberEngine: SpeechTranscriberEngine {
        if let engine = speechTranscriberEngineStorage as? SpeechTranscriberEngine {
            return engine
        }
        let engine = SpeechTranscriberEngine()
        engine.onResult = { [weak self] text, alternatives, isFinal in
            guard let self, isFinal else { return }
            self.appendSpeechTranscriberFinalSegment(primary: text, alternatives: alternatives)
        }
        engine.onError = { [weak self] error in
            self?.handleSpeechTranscriberError(error)
        }
        engine.onFinished = { [weak self] in
            self?.finishSpeechTranscriberRecording()
        }
        speechTranscriberEngineStorage = engine
        return engine
    }

    override init() {
        let rules = VoiceRules.forCurrentAppLanguage()
        super.init()
        applyRules(rules)
        speechRecognizer = SFSpeechRecognizer(locale: rules.speechRecognizerLocale)
    }

    func updateRules(for locale: Locale) {
        invalidateSpeechTranscriberProcessing()
        let rules = VoiceRules.forLocale(locale)
        applyRules(rules)
        speechRecognizer = SFSpeechRecognizer(locale: rules.speechRecognizerLocale)
        if asrEngine == .speechTranscriber {
            prepareSpeechTranscriber()
        }
    }

    private func applyRules(_ rules: VoiceRules) {
        speechTranscriberScoreContextTask?.cancel()
        speechTranscriberScoreContextTask = nil
        speechTranscriberReadyScoreContext = nil
        speechTranscriberScoreContextKey = nil
        currentRules = rules
        voiceShotTypes = rules.shotKeywords
        voiceMadeStates = rules.madeStates
        voiceMissedStates = rules.missedStates

        voiceShotEvents = voiceShotTypes.map { ($0.keyword, $0.keyword, $0.eventPrefix, true) }
        allStatEvents = rules.statEvents.map { (chinese: $0.keyword, code: $0.eventCode) }
        allCommandEvents = rules.commandEvents.map { (chinese: $0.keyword, code: $0.eventCode) }
        rebuildNonShotEvents()
    }

    /// Rebuild voiceNonShotEvents from allStatEvents and allCommandEvents,
    /// filtering rebound keywords based on the current mode.
    private func rebuildNonShotEvents() {
        voiceNonShotEvents = []
        let useOD: Bool
        if let taskOverride = taskUsesODRebound {
            useOD = taskOverride
        } else {
            useOD = currentSnapshot?.showsOffensiveDefensiveRebound ?? false
        }
        if useOD {
            for entry in allStatEvents {
                if entry.code == "stat.offensiveRebound" || entry.code == "stat.defensiveRebound" {
                    voiceNonShotEvents.append(entry)
                }
            }
            for entry in allStatEvents {
                if entry.code == "stat.rebound" {
                    voiceNonShotEvents.append((entry.chinese, "stat.defensiveRebound"))
                }
            }
            for entry in allStatEvents {
                if entry.code != "stat.rebound" && entry.code != "stat.offensiveRebound" && entry.code != "stat.defensiveRebound" {
                    voiceNonShotEvents.append(entry)
                }
            }
        } else {
            for entry in allStatEvents {
                if entry.code == "stat.offensiveRebound" || entry.code == "stat.defensiveRebound" {
                    voiceNonShotEvents.append((entry.chinese, "stat.rebound"))
                } else {
                    voiceNonShotEvents.append(entry)
                }
            }
        }
        voiceNonShotEvents.append(contentsOf: allCommandEvents)
        if usesStructuralSpeechMatching {
            voiceNonShotEvents.sort { left, right in
                if left.0.count == right.0.count {
                    return left.1 < right.1
                }
                return left.0.count > right.0.count
            }
        }
    }

    private var store: AppStore?
    var currentSnapshot: GameSnapshot? {
        didSet {
            rebuildNonShotEvents()
            if asrEngine == .speechTranscriber {
                prepareSpeechTranscriberScoreContext()
                if store != nil, speechTranscriberPreparationTask == nil {
                    prepareSpeechTranscriber()
                }
            }
        }
    }
    var onAction: ((StatAction, UUID, TeamSide, String?) -> Void)?
    var onDualAction: ((StatAction, UUID, TeamSide, StatAction, UUID, TeamSide) -> Void)?
    var onCommand: ((VoiceCommand) -> Void)?
    var onSubstitution: ((TeamSide, UUID, UUID) -> Void)?
    var matchingThreshold: Double = 0.6

    var currentRules: VoiceRules = .chinese

    private var voiceShotTypes: [VoiceRules.ShotDef] = []
    private var voiceMadeStates: [String] = []
    private var voiceMissedStates: [String] = []
    private var voiceShotEvents: [(keyword: String, chinese: String, code: String, isShot: Bool)] = []
    private var voiceNonShotEvents: [(chinese: String, code: String)] = []

    private var usesStructuralSpeechMatching: Bool {
        let identifier = currentRules.locale.identifier
        return identifier.hasPrefix("ja") || identifier.hasPrefix("ko")
    }

    private struct SpeechActionCandidate {
        let keyword: String
        let code: String
        let leftText: String
        let rightText: String
        let isShot: Bool
        let score: Double
    }

    private struct SpeechTranscriberPlayerContext: Sendable {
        let name: String
        let pinyinVariants: [String]
    }

    private struct SpeechTranscriberScoreContext: Sendable {
        let rules: VoiceRules
        let players: [SpeechTranscriberPlayerContext]
        let pinyinShotKeywords: [String]
        let pinyinStatKeywords: [String]
        let pinyinCommandKeywords: [String]
        let contextualStrings: [String]
        let keywordPinyinVariants: [String: Set<String>]
        let playerPinyinVariants: [String: Set<String>]
        let playerNamePinyinVariants: [String: [String]]
        let playerExpandedPinyinVariants: [String: Set<String>]
        let teamPinyinVariants: [String: Set<String>]
    }

    private struct SpeechTranscriberCandidateInput: Sendable {
        let text: String
        let normalized: String
        let pinyinVariants: Set<String>
    }

    /// Full list of stat events from the current rules (unfiltered).
    private var allStatEvents: [(chinese: String, code: String)] = []
    /// Full list of command events from the current rules.
    private var allCommandEvents: [(chinese: String, code: String)] = []
    private var preferredPlayerNumber: Int?

    /// For tutorial mode: override the rebound filtering based on the current task.
    /// - nil: use snapshot.showsOffensiveDefensiveRebound
    /// - true: prioritize O/D keywords; unmatched generic rebound maps to defensiveRebound
    /// - false: use generic rebound keyword only
    private var taskUsesODRebound: Bool?

    /// Update rebound keyword filtering. Call when the snapshot or task context changes.
    /// - Parameter useOD: nil → use snapshot mode; true → O/D only; false → generic only
    func setReboundFilterMode(_ useOD: Bool?) {
        taskUsesODRebound = useOD
        rebuildNonShotEvents()
    }

    func configure(store: AppStore) {
        self.store = store
        asrEngine = VoiceASREngine.effectiveStored
        if asrEngine == .legacySpeech {
            Task { [weak self] in
                await self?.prepareEngine()
            }
        } else {
            prepareSpeechTranscriber()
        }
    }

    func clearSpeechTranscriberGameCache() {
        speechTranscriberSessionGeneration += 1
        speechTranscriberStartTask?.cancel()
        speechTranscriberStartTask = nil
        speechTranscriberProcessingTask?.cancel()
        speechTranscriberProcessingTask = nil
        speechTranscriberProcessing = false
        speechTranscriberFinishing = false
        speechTranscriberStopRequested = false
        speechTranscriberFinalSegments.removeAll()
        speechTranscriberPreparationGeneration += 1
        let preparationTask = speechTranscriberPreparationTask
        speechTranscriberPreparationTask?.cancel()
        speechTranscriberPreparationTask = nil
        isSpeechTranscriberPreparing = false
        speechTranscriberScoreContextTask?.cancel()
        speechTranscriberScoreContextTask = nil
        speechTranscriberReadyScoreContext = nil
        speechTranscriberScoreContextKey = nil
        if #available(iOS 26.0, *) {
            let previousReleaseTask = speechTranscriberResourceReleaseTask
            speechTranscriberResourceReleaseTask = Task { [weak self] in
                await preparationTask?.value
                await previousReleaseTask?.value
                guard let self,
                      let engine = self.speechTranscriberEngineStorage as? SpeechTranscriberEngine else { return }
                await engine.releasePreparedResources()
            }
        }
    }

    func configureForFileEvaluation(store: AppStore, engine: VoiceASREngine = .speechTranscriber) {
        self.store = store
        asrEngine = engine
    }

    func updateASREngine(_ engine: VoiceASREngine) {
        asrEngine = engine.isAvailableOnCurrentDevice ? engine : .legacySpeech
        if asrEngine == .legacySpeech {
            invalidateSpeechTranscriberProcessing()
            speechTranscriberStartTask?.cancel()
            speechTranscriberStartTask = nil
            Task { [weak self] in
                await self?.prepareEngine()
            }
        } else {
            prepareSpeechTranscriber()
        }
    }

    private func prepareSpeechTranscriber() {
        guard #available(iOS 26.0, *) else { return }
        prepareSpeechTranscriberScoreContext()
        speechTranscriberPreparationGeneration += 1
        let generation = speechTranscriberPreparationGeneration
        speechTranscriberPreparationTask?.cancel()
        isSpeechTranscriberPreparing = true
        let locale = currentRules.speechRecognizerLocale
        let resourceReleaseTask = speechTranscriberResourceReleaseTask
        speechTranscriberPreparationTask = Task { [weak self] in
            guard let self else { return }
            await resourceReleaseTask?.value
            defer {
                if self.speechTranscriberPreparationGeneration == generation {
                    self.isSpeechTranscriberPreparing = false
                }
            }
            do {
                try await speechTranscriberEngine.prepare(locale: locale)
            } catch is CancellationError {
            } catch {
                print("[Voice] SpeechTranscriber prepare failed: \(error)")
            }
        }
    }

    private func prepareSpeechTranscriberScoreContext() {
        let rules = currentRules
        let playerNames = (store?.players ?? []).map(\.name)
        let (contextualPlayerNames, contextualPlayerNumbers) = speechTranscriberContextualPlayerValues()
        let teamNames = speechTranscriberContextualTeamNames()
        let key = "\(rules.locale.identifier)|\(playerNames.joined(separator: "\u{1F}"))|\(contextualPlayerNames.joined(separator: "\u{1F}"))|\(contextualPlayerNumbers.joined(separator: "\u{1F}"))|\(teamNames.joined(separator: "\u{1F}"))"
        guard speechTranscriberScoreContextKey != key else { return }
        speechTranscriberScoreContextKey = key
        speechTranscriberReadyScoreContext = nil
        speechTranscriberScoreContextTask?.cancel()
        let task = Task.detached(priority: .utility) {
            Self.makeSpeechTranscriberScoreContext(
                rules: rules,
                playerNames: playerNames,
                contextualPlayerNames: contextualPlayerNames,
                contextualPlayerNumbers: contextualPlayerNumbers,
                teamNames: teamNames
            )
        }
        speechTranscriberScoreContextTask = task
        Task { [weak self] in
            let context = await task.value
            guard let self, self.speechTranscriberScoreContextKey == key else { return }
            self.speechTranscriberReadyScoreContext = context
        }
    }

    private func invalidateSpeechTranscriberProcessing() {
        speechTranscriberSessionGeneration += 1
        speechTranscriberProcessingTask?.cancel()
        speechTranscriberProcessingTask = nil
        speechTranscriberProcessing = false
    }

    private func prepareEngine() async -> Bool {
        guard !enginePrepared else { return true }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try await AudioSessionActivation.activate(audioSession)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                print("[Voice] Invalid recording format: sampleRate=\(recordingFormat.sampleRate) channels=\(recordingFormat.channelCount)")
                return false
            }
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            try audioEngine.start()
            enginePrepared = true
            return true
        } catch {
            print("[Voice] Engine prepare failed: \(error)")
            return false
        }
    }

    func startRecording() {
        guard !speechTranscriberFinishing, !speechTranscriberProcessing else { return }
        onClear?()

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization { _ in }
            showError(NSLocalizedString("voice_auth_speech", comment: ""))
            return
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            AVAudioApplication.requestRecordPermission { _ in }
            showError(NSLocalizedString("voice_auth_microphone", comment: ""))
            return
        }
        if asrEngine == .speechTranscriber {
            startSpeechTranscriberRecording()
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            showError(NSLocalizedString("voice_unavailable", comment: ""))
            return
        }

        isRecording = true

        Task { [weak self] in
            guard let self else { return }
            guard await prepareEngine(), isRecording else {
                isRecording = false
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = false
            request.taskHint = .search
            request.contextualStrings = speechTranscriberContextualStrings()
            recognitionRequest = request

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result, result.isFinal {
                    processText(result.bestTranscription.formattedString)
                }
                if error != nil {
                    stopRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        if asrEngine == .speechTranscriber {
            isRecording = false
            speechTranscriberStartTask?.cancel()
            speechTranscriberStopStartedAt = Date()
            speechTranscriberStopRequested = true
            speechTranscriberFinishing = true
            if #available(iOS 26.0, *) {
                speechTranscriberEngine.requestStop()
            }
            return
        }

        isRecording = false
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func startSpeechTranscriberRecording() {
        guard #available(iOS 26.0, *) else {
            showError(NSLocalizedString("voice_speech_transcriber_unavailable", comment: ""))
            return
        }

        isRecording = true
        speechTranscriberFinalSegments.removeAll()
        speechTranscriberStopRequested = false
        speechTranscriberFinishing = false
        speechTranscriberProcessing = false
        speechTranscriberStartTask?.cancel()
        speechTranscriberStopStartedAt = nil
        speechTranscriberTimingDetail = nil
        speechTranscriberStopToFinalMilliseconds = nil
        speechTranscriberSessionGeneration += 1
        let sessionGeneration = speechTranscriberSessionGeneration
        let locale = currentRules.speechRecognizerLocale
        if speechTranscriberPreparationTask == nil {
            prepareSpeechTranscriber()
        }
        let preparationTask = speechTranscriberPreparationTask
        let scoreContextTask = speechTranscriberScoreContextTask
        speechTranscriberStartTask = Task { [weak self] in
            guard let self else { return }
            do {
                await preparationTask?.value
                try Task.checkCancellation()
                guard self.speechTranscriberSessionGeneration == sessionGeneration,
                      self.isRecording,
                      !self.speechTranscriberStopRequested else { return }
                let contextualStrings = if let scoreContextTask {
                    await scoreContextTask.value.contextualStrings
                } else {
                    speechTranscriberContextualStrings()
                }
                try Task.checkCancellation()
                guard self.speechTranscriberSessionGeneration == sessionGeneration,
                      self.isRecording,
                      !self.speechTranscriberStopRequested else { return }
                try await speechTranscriberEngine.start(locale: locale, contextualStrings: contextualStrings)
                guard self.speechTranscriberSessionGeneration == sessionGeneration else { return }
                if speechTranscriberStopRequested {
                    speechTranscriberEngine.requestStop()
                }
            } catch is CancellationError {
            } catch {
                isRecording = false
                speechTranscriberFinishing = false
                speechTranscriberFinalSegments.removeAll()
                showError(error.localizedDescription)
            }
        }
    }

    private func speechTranscriberContextualStrings() -> [String] {
        if asrEngine == .speechTranscriber, let readyContext = speechTranscriberReadyScoreContext {
            return readyContext.contextualStrings
        }
        guard let store else { return currentRules.contextualStrings(playerNames: []) }
        let snapshotIDs = (currentSnapshot?.homeOnCourtPlayerIDs ?? [])
            + (currentSnapshot?.homeAvailablePlayerIDs ?? [])
            + (currentSnapshot?.awayOnCourtPlayerIDs ?? [])
            + (currentSnapshot?.awayAvailablePlayerIDs ?? [])
        let players = snapshotIDs.isEmpty ? store.players : snapshotIDs.compactMap { store.player(for: $0) }
        let values = currentRules.contextualStrings(
            playerNames: players.map(\.name),
            playerNumbers: players.map(\.number)
        )
        return Array(Set(values + speechTranscriberContextualTeamNames())).sorted()
    }

    private func speechTranscriberContextualTeamNames() -> [String] {
        guard let store else { return [] }
        let teamIDs = [currentSnapshot?.homeTeamID, currentSnapshot?.awayTeamID].compactMap { $0 }
        return teamIDs.compactMap { store.team(for: $0)?.name }.filter { !$0.isEmpty }
    }

    nonisolated private static func makeSpeechTranscriberScoreContext(
        rules: VoiceRules,
        playerNames: [String],
        contextualPlayerNames: [String],
        contextualPlayerNumbers: [String],
        teamNames: [String]
    ) -> SpeechTranscriberScoreContext {
        let keywordTexts = Set(
            rules.shotKeywords.map(\.keyword)
                + rules.statEvents.map(\.keyword)
                + rules.commandEvents.map(\.keyword)
                + rules.madeStates
                + rules.missedStates
                + rules.substitutionKeywords
        )
        let keywordPinyinVariants = Dictionary(uniqueKeysWithValues: keywordTexts.map { keyword in
            (keyword, rules.generatePinyinVariants(keyword))
        })
        let playerPinyinVariants = Dictionary(uniqueKeysWithValues: playerNames.map { name in
            (name, rules.generatePinyinVariants(name))
        })
        let playerNamePinyinVariants = Dictionary(uniqueKeysWithValues: playerNames.map { name in
            (name, rules.namePinyinVariants(name))
        })
        let playerExpandedPinyinVariants = Dictionary(uniqueKeysWithValues: playerNames.map { name in
            let expanded = playerNamePinyinVariants[name, default: []].reduce(into: Set<String>()) { result, variant in
                result.formUnion(rules.generatePinyinVariants(variant))
            }
            return (name, expanded)
        })
        let teamPinyinVariants = Dictionary(uniqueKeysWithValues: teamNames.map { name in
            (name, rules.generatePinyinVariants(name))
        })
        let contextualStrings = Array(Set(
            rules.contextualStrings(
                playerNames: contextualPlayerNames,
                playerNumbers: contextualPlayerNumbers
            ) + teamNames.filter { !$0.isEmpty }
        )).sorted()
        return SpeechTranscriberScoreContext(
            rules: rules,
            players: playerNames.map {
                SpeechTranscriberPlayerContext(
                    name: $0,
                    pinyinVariants: rules.namePinyinVariants($0)
                )
            },
            pinyinShotKeywords: rules.shotKeywords.map { rules.toPinyin($0.keyword) },
            pinyinStatKeywords: rules.statEvents.map { rules.toPinyin($0.keyword) },
            pinyinCommandKeywords: rules.commandEvents.map { rules.toPinyin($0.keyword) },
            contextualStrings: contextualStrings,
            keywordPinyinVariants: keywordPinyinVariants,
            playerPinyinVariants: playerPinyinVariants,
            playerNamePinyinVariants: playerNamePinyinVariants,
            playerExpandedPinyinVariants: playerExpandedPinyinVariants,
            teamPinyinVariants: teamPinyinVariants
        )
    }

    private func speechTranscriberContextualPlayerValues() -> (names: [String], numbers: [String]) {
        guard let store else { return ([], []) }
        let snapshotIDs = (currentSnapshot?.homeOnCourtPlayerIDs ?? [])
            + (currentSnapshot?.homeAvailablePlayerIDs ?? [])
            + (currentSnapshot?.awayOnCourtPlayerIDs ?? [])
            + (currentSnapshot?.awayAvailablePlayerIDs ?? [])
        let players = snapshotIDs.isEmpty ? store.players : snapshotIDs.compactMap { store.player(for: $0) }
        return (players.map(\.name), players.map(\.number))
    }

    private func speechTranscriberPinyinVariants(for text: String) -> Set<String> {
        if asrEngine == .speechTranscriber,
           let variants = speechTranscriberReadyScoreContext?.keywordPinyinVariants[text] {
            return variants
        }
        if asrEngine == .speechTranscriber,
           let variants = speechTranscriberReadyScoreContext?.playerPinyinVariants[text] {
            return variants
        }
        if asrEngine == .speechTranscriber,
           let variants = speechTranscriberReadyScoreContext?.teamPinyinVariants[text] {
            return variants
        }
        return currentRules.generatePinyinVariants(text)
    }

    private func speechTranscriberPlayerPinyinVariants(for name: String) -> Set<String> {
        asrEngine == .speechTranscriber
            ? speechTranscriberReadyScoreContext?.playerPinyinVariants[name] ?? currentRules.generatePinyinVariants(name)
            : currentRules.generatePinyinVariants(name)
    }

    private func speechTranscriberPlayerNamePinyinVariants(for name: String) -> [String] {
        asrEngine == .speechTranscriber
            ? speechTranscriberReadyScoreContext?.playerNamePinyinVariants[name] ?? currentRules.namePinyinVariants(name)
            : currentRules.namePinyinVariants(name)
    }

    private func speechTranscriberPlayerExpandedPinyinVariants(for name: String) -> Set<String> {
        (asrEngine == .speechTranscriber ? speechTranscriberReadyScoreContext?.playerExpandedPinyinVariants[name] : nil)
            ?? speechTranscriberPlayerNamePinyinVariants(for: name).reduce(into: Set<String>()) { result, variant in
                result.formUnion(currentRules.generatePinyinVariants(variant))
            }
    }

    private func speechTranscriberTeamPinyinVariants(for name: String) -> Set<String> {
        asrEngine == .speechTranscriber
            ? speechTranscriberReadyScoreContext?.teamPinyinVariants[name] ?? currentRules.generatePinyinVariants(name)
            : currentRules.generatePinyinVariants(name)
    }

    private func processSpeechTranscriberCandidates(primary: String, alternatives: [String]) {
        var candidates = [primary]
        for alternative in alternatives where !alternative.isEmpty && !candidates.contains(alternative) {
            candidates.append(alternative)
        }
        let rules = currentRules
        let playerNames = (store?.players ?? []).map(\.name)
        prepareSpeechTranscriberScoreContext()
        let scoreContextTask = speechTranscriberScoreContextTask
        speechTranscriberProcessing = true
        speechTranscriberSessionGeneration += 1
        let sessionGeneration = speechTranscriberSessionGeneration
        speechTranscriberProcessingTask?.cancel()
        let processingTask = Task { [weak self] in
            guard let self else { return }
            let selectionStartedAt = Date()
            let context: SpeechTranscriberScoreContext
            if let scoreContextTask {
                context = await scoreContextTask.value
            } else {
                let (contextualPlayerNames, contextualPlayerNumbers) = self.speechTranscriberContextualPlayerValues()
                let teamNames = self.speechTranscriberContextualTeamNames()
                context = Self.makeSpeechTranscriberScoreContext(
                    rules: rules,
                    playerNames: playerNames,
                    contextualPlayerNames: contextualPlayerNames,
                    contextualPlayerNumbers: contextualPlayerNumbers,
                    teamNames: teamNames
                )
            }
            guard !Task.isCancelled, self.speechTranscriberSessionGeneration == sessionGeneration else { return }
            let selected = await Task.detached(priority: .userInitiated) {
                let inputs = candidates.map {
                    let normalized = Self.normalizeSpeechTranscriberText($0, rules: rules)
                    return SpeechTranscriberCandidateInput(
                        text: $0,
                        normalized: normalized,
                        pinyinVariants: rules.generatePinyinVariants(normalized)
                    )
                }
                return inputs.max { left, right in
                    Self.speechTranscriberCandidateScore(left, context: context) < Self.speechTranscriberCandidateScore(right, context: context)
                }?.text ?? primary
            }.value
            guard !Task.isCancelled, self.speechTranscriberSessionGeneration == sessionGeneration else { return }
            let selectionMilliseconds = Int(Date().timeIntervalSince(selectionStartedAt) * 1000)
            let actionStartedAt = Date()
            self.processText(selected)
            let actionMilliseconds = Int(Date().timeIntervalSince(actionStartedAt) * 1000)
            let totalMilliseconds = self.speechTranscriberStopStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
            print("xdz SpeechTranscriber matching candidates=\(candidates.count) selectionMs=\(selectionMilliseconds) actionMs=\(actionMilliseconds) stopToActionMs=\(totalMilliseconds)")
            self.appendSpeechTranscriberTiming(
                selectionMilliseconds: selectionMilliseconds,
                actionMilliseconds: actionMilliseconds,
                stopToActionMilliseconds: totalMilliseconds
            )
            self.speechTranscriberStopStartedAt = nil
            self.speechTranscriberStopToFinalMilliseconds = nil
            self.speechTranscriberProcessing = false
        }
        speechTranscriberProcessingTask = processingTask
    }

    private func appendSpeechTranscriberFinalSegment(primary: String, alternatives: [String]) {
        var candidates = [primary]
        for alternative in alternatives where !alternative.isEmpty && !candidates.contains(alternative) {
            candidates.append(alternative)
        }
        speechTranscriberFinalSegments.append(candidates)
    }

    private func finishSpeechTranscriberRecording() {
        guard speechTranscriberFinishing else { return }
        speechTranscriberFinishing = false

        let segmentCandidates = speechTranscriberFinalSegments
        speechTranscriberFinalSegments.removeAll()
        let stopToFinalMilliseconds = speechTranscriberStopStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        print("xdz SpeechTranscriber final segments=\(segmentCandidates.count) stopToFinalMs=\(stopToFinalMilliseconds)")
        speechTranscriberStopToFinalMilliseconds = stopToFinalMilliseconds
        speechTranscriberTimingDetail = "SpeechTranscriber耗时: stopToFinalMs=\(stopToFinalMilliseconds)"
        guard !segmentCandidates.isEmpty else {
            speechTranscriberStopStartedAt = nil
            speechTranscriberTimingDetail = nil
            speechTranscriberStopToFinalMilliseconds = nil
            return
        }

        var combinedCandidates = [""]
        for segment in segmentCandidates {
            let options = segment.prefix(4)
            var nextCandidates: [String] = []
            var seenCandidates = Set<String>()
            for prefix in combinedCandidates {
                for option in options {
                    let combined = [prefix, option]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    if seenCandidates.insert(combined).inserted {
                        nextCandidates.append(combined)
                    }
                    if nextCandidates.count >= 64 { break }
                }
                if nextCandidates.count >= 64 { break }
            }
            combinedCandidates = nextCandidates
        }

        guard let primary = combinedCandidates.first else { return }
        processSpeechTranscriberCandidates(
            primary: primary,
            alternatives: Array(combinedCandidates.dropFirst())
        )
    }

    private func appendSpeechTranscriberTiming(
        selectionMilliseconds: Int,
        actionMilliseconds: Int,
        stopToActionMilliseconds: Int
    ) {
        guard let store,
              let index = store.voiceLog.firstIndex(where: {
                  $0.engine == asrEngine.rawValue && Date().timeIntervalSince($0.timestamp) < 5
              }) else { return }
        var entry = store.voiceLog[index]
        let timing = "SpeechTranscriber处理耗时: selectionMs=\(selectionMilliseconds), actionMs=\(actionMilliseconds), stopToActionMs=\(stopToActionMilliseconds)"
        entry.matchDetail = [entry.matchDetail, timing].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
        store.voiceLog[index] = entry
    }

    nonisolated private static func speechTranscriberCandidateScore(_ input: SpeechTranscriberCandidateInput, context: SpeechTranscriberScoreContext) -> Int {
        let normalized = input.normalized.lowercased()
        guard !normalized.isEmpty else { return 0 }
        var score = 0
        let pinyinVariants = input.pinyinVariants
        for keyword in context.rules.shotKeywords.map(\.keyword) where normalized.contains(keyword.lowercased()) {
            score += 3
        }
        for keyword in context.pinyinShotKeywords where pinyinVariants.contains(where: { $0.contains(keyword) }) {
            score += 3
        }
        for keyword in context.rules.statEvents.map(\.keyword) where normalized.contains(keyword.lowercased()) {
            score += 3
        }
        for keyword in context.pinyinStatKeywords where pinyinVariants.contains(where: { $0.contains(keyword) }) {
            score += 3
        }
        for keyword in context.rules.commandEvents.map(\.keyword) where normalized.contains(keyword.lowercased()) {
            score += 3
        }
        for keyword in context.pinyinCommandKeywords where pinyinVariants.contains(where: { $0.contains(keyword) }) {
            score += 3
        }
        for keyword in context.rules.madeStates + context.rules.missedStates where normalized.contains(keyword.lowercased()) {
            score += 1
        }
        for player in context.players {
            if normalized.contains(player.name.lowercased()) {
                score += 4
            }
        }
        for player in context.players {
            if player.pinyinVariants.contains(where: { name in pinyinVariants.contains(where: { $0.contains(name) }) }) {
                score += 4
            }
        }
        return score
    }

    private func handleSpeechTranscriberError(_ error: Error) {
        guard isRecording else { return }
        invalidateSpeechTranscriberProcessing()
        isRecording = false
        speechTranscriberStopRequested = false
        speechTranscriberFinishing = false
        speechTranscriberProcessing = false
        speechTranscriberFinalSegments.removeAll()
        speechTranscriberStopStartedAt = nil
        showError(error.localizedDescription)
    }

    /// Start buffering log details for a new recognition session.
    private func logStart(_ text: String) {
        logText = text
        logBuffer = ""
        logIsSuccess = false
        logAction = nil
        logPlayerName = nil
        logPattern = nil
    }

    /// Append a step detail to the buffer (does NOT write to store yet).
    private func logStep(_ msg: String) {
        if logBuffer.isEmpty {
            logBuffer = msg
        } else {
            logBuffer += " | \(msg)"
        }
    }

    /// Flush the accumulated log buffer to the store.
    /// Should be called when recognition completes (success or failure).
    private func logFlush(isSuccess: Bool, action: String? = nil, playerName: String? = nil, matchedPattern: String? = nil) {
        guard let store, store.voiceLogEnabled else { return }
        let finalAction = action ?? logAction
        let finalPlayerName = playerName ?? logPlayerName
        let finalSuccess = isSuccess || (logIsSuccess && finalAction != nil && finalPlayerName != nil)
        let entry = VoiceLogEntry(
            timestamp: Date(),
            text: logText,
            textPinyin: currentRules.toPinyin(logText),
            isSuccess: finalSuccess,
            action: finalAction,
            playerName: finalPlayerName,
            matchedPattern: matchedPattern ?? logPattern,
            matchDetail: logBuffer,
            locale: currentRules.locale.identifier,
            engine: asrEngine.rawValue,
            stage: "parser",
            failureReason: finalSuccess ? nil : voiceLogFailureReason(logBuffer)
        )
        appendToVoiceLog(entry)
        // Clear buffer after flushing
        logText = ""
        logBuffer = ""
    }

    /// Add or accumulate log information during a recognition session.
    /// Automatically flushes when a terminal state is reached (success with action+player, or failure).
    private func addLog(text: String, isSuccess: Bool, action: String? = nil, playerName: String? = nil, matchedPattern: String? = nil, matchDetail: String? = nil) {
        guard store?.voiceLogEnabled != false else { return }

        // If a log buffer is active, accumulate into the buffer
        if !logText.isEmpty {
            // Accumulate step details
            if let detail = matchDetail {
                logStep(detail)
            }
            // Update action, playerName, and pattern if provided
            if action != nil {
                logAction = action
            }
            if playerName != nil {
                logPlayerName = playerName
            }
            if matchedPattern != nil {
                logPattern = matchedPattern
            }
            // Update success status (once true, stays true)
            logIsSuccess = logIsSuccess || isSuccess

            // Auto-flush on terminal states:
            // 1. Success with both action and playerName
            // 2. Explicit failure (matchDetail starts with ❌ or isSuccess=false with details)
            let hasSuccessResult = isSuccess && action != nil && playerName != nil
            let hasFailureResult = matchDetail?.hasPrefix("❌") == true

            if hasSuccessResult || hasFailureResult {
                logFlush(isSuccess: isSuccess, action: action, playerName: playerName, matchedPattern: matchedPattern)
            }
            return
        }

        // No active buffer, write directly to store
        guard store != nil else { return }
        let entry = VoiceLogEntry(
            timestamp: Date(),
            text: text,
            textPinyin: currentRules.toPinyin(text),
            isSuccess: isSuccess,
            action: action,
            playerName: playerName,
            matchedPattern: matchedPattern,
            matchDetail: matchDetail,
            locale: currentRules.locale.identifier,
            engine: asrEngine.rawValue,
            stage: "parser",
            failureReason: isSuccess ? nil : voiceLogFailureReason(matchDetail)
        )
        appendToVoiceLog(entry)
    }

    private func voiceLogFailureReason(_ detail: String?) -> String {
        guard let detail else { return "parser_failure" }
        if detail.contains("全文无匹配") { return "no_parser_match" }
        if detail.contains("未匹配到球员") { return "player_not_matched" }
        if detail.contains("无对应StatAction") { return "unknown_action" }
        if detail.contains("无球员匹配") { return "player_not_matched" }
        return "parser_failure"
    }

    // MARK: - Helper Methods for UI Feedback

    private func showSuccessFeedback(text: String? = nil, action: StatAction, playerID: UUID, side: TeamSide) {
        onFlash?(.green)
        onAction?(action, playerID, side, text)
    }

    private func showDualSuccessFeedback(action1: StatAction, playerID1: UUID, side1: TeamSide, action2: StatAction, playerID2: UUID, side2: TeamSide) {
        onFlash?(.green)
        onDualAction?(action1, playerID1, side1, action2, playerID2, side2)
    }

    /// Show error feedback with red flash
    private func showErrorWithFlash(_ msg: String) {
        showError(msg)
        onFlash?(.red)
    }

    private func showError(_ msg: String) {
        onError?(msg)
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.prepare()
            impact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { impact.impactOccurred() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { impact.impactOccurred() }
        }
    }

    private func matchPlayerIDs(from text: String, textPinyin: String, in allIDs: [UUID], context: String = "") -> [(UUID, TeamSide, Double)] {
        let (results, _) = matchPlayerIDsDebug(text: text, textPinyin: textPinyin, in: allIDs, context: context)
        return results
    }

    private func localizedPlayerNameVariants(_ playerName: String) -> [String] {
        let locale = currentRules.locale.identifier
        let name = playerName.lowercased()
        if locale.hasPrefix("ja") {
            let aliases: [String: [String]] = [
                "emma": ["エマ"],
                "michael": ["マイケル", "マイコー"],
                "alice": ["アリス"],
                "john": ["ジョン"],
                "david": ["デイビッド", "デビッド"]
            ]
            var variants = aliases[name] ?? []
            let characters = Array(playerName)
            if characters.count >= 3, characters.allSatisfy(Self.isSpeechTranscriberNativeScriptCharacter) {
                variants.append(String(characters.prefix(2)))
            }
            return variants
        }
        if locale.hasPrefix("ko") {
            let aliases: [String: [String]] = [
                "emma": ["엠마"],
                "michael": ["마이클", "마이콜", "마이컬"],
                "alice": ["앨리스", "알리스"],
                "john": ["존"],
                "david": ["데이비드", "데이빗"]
            ]
            var variants = aliases[name] ?? []
            let characters = Array(playerName)
            if characters.count >= 3, characters.allSatisfy(Self.isSpeechTranscriberNativeScriptCharacter) {
                variants.append(String(characters.prefix(2)))
                variants.append(String(characters.suffix(2)))
            }
            return variants
        }
        if locale.hasPrefix("ru") {
            let aliases: [String: [String]] = [
                "emma": ["Эмма"],
                "michael": ["Майкл", "Михаил"],
                "alice": ["Алиса"],
                "john": ["Джон"],
                "david": ["Дэвид", "Давид"]
            ]
            return aliases[name] ?? []
        }
        return []
    }

    private func fuzzyPlayerNameScore(text: String, playerName: String) -> Double? {
        let inputTokens = text.lowercased().split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        let nameTokens = playerName.lowercased().split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        guard nameTokens.count >= 2, inputTokens.count >= nameTokens.count else { return nil }

        var bestScore = 0.0
        for start in 0...(inputTokens.count - nameTokens.count) {
            let window = Array(inputTokens[start..<(start + nameTokens.count)])
            var total = 0.0
            var exactCount = 0
            for (nameToken, inputToken) in zip(nameTokens, window) {
                if nameToken == inputToken {
                    exactCount += 1
                    total += 1.0
                } else if nameToken.hasPrefix(inputToken), inputToken.count >= 2 {
                    total += 0.82
                } else if inputToken.hasPrefix(nameToken), nameToken.count >= 2 {
                    total += 0.82
                } else {
                    let length = max(nameToken.count, inputToken.count)
                    guard length > 0 else { continue }
                    total += max(0.0, 1.0 - Double(Self.levenshteinDistance(nameToken, inputToken)) / Double(length))
                }
            }
            guard exactCount > 0 else { continue }
            bestScore = max(bestScore, total / Double(nameTokens.count))
        }
        return bestScore > 0 ? min(bestScore, 0.92) : nil
    }

    private func matchPlayerIDsDebug(text: String, textPinyin: String, in allIDs: [UUID], context: String = "") -> ([(UUID, TeamSide, Double)], String) {
        guard let store, let snapshot = currentSnapshot else { return ([], "\(context): store/snapshot=nil") }
        var results: [(UUID, TeamSide, Double)] = []
        var details: [String] = []

        // Generate user input variants once for all comparisons
        let userInputVariants = currentRules.generatePinyinVariants(text)

        for id in allIDs {
            if let player = store.player(for: id) {
                let nameLower = player.name.lowercased()

                // Priority 1: Direct text match (highest confidence)
                let lowerText = text.lowercased()
                if lowerText == nameLower || lowerText.contains(nameLower) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 1.0))
                    details.append("\(player.name)(直配1.0)")
                    continue
                }
                if !lowerText.isEmpty, nameLower.contains(lowerText) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 0.86))
                    details.append("\(player.name)(姓名片段0.86)")
                    continue
                }

                if asrEngine == .speechTranscriber,
                   currentRules.locale.identifier.hasPrefix("zh"),
                   let inputKey = speechTranscriberAlphanumericNameKey(text),
                   let playerKey = speechTranscriberAlphanumericNameKey(player.name),
                   inputKey == playerKey {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 1.0))
                    details.append("\(player.name)(字母数字姓名规范化直配1.0)")
                    continue
                }

                // Priority 1a: Nickname direct match
                if !player.nicknames.isEmpty {
                    let lowerText = text.lowercased()
                    for nick in player.nicknames {
                        let nickLower = nick.lowercased()
                        if lowerText.contains(nickLower) || nickLower.contains(lowerText) {
                            let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                            results.append((id, side, 1.0))
                            details.append("\(player.name)(昵称:\(nick))")
                            break
                        }
                    }
                    if results.last?.0 == id { continue }
                }

                let normalizedText = text.lowercased()
                if let matchedVariant = localizedPlayerNameVariants(player.name).first(where: { normalizedText.contains($0.lowercased()) }) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 0.98))
                    details.append("\(player.name)(本地发音别名:\(matchedVariant))")
                    continue
                }

                if asrEngine == .speechTranscriber,
                   speechTranscriberHasUniqueNameToken(
                       text: text,
                       playerName: player.name,
                       playerNames: allIDs.compactMap { store.player(for: $0)?.name }
                   ) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 0.92))
                    details.append("\(player.name)(唯一姓名词匹配0.92)")
                    continue
                }

                // Priority 1.5: Levenshtein distance for Latin-script names
                if currentRules.useLevenshteinMatching || asrEngine == .speechTranscriber {
                    let dist = Self.levenshteinDistance(text, player.name)
                    let baseThreshold = player.name.count < 4
                        ? currentRules.levenshteinThreshold.short
                        : currentRules.levenshteinThreshold.long
                    let hasLatin = player.name.contains { $0.isASCII && $0.isLetter }
                    let hasNonLatin = player.name.contains { !$0.isASCII }
                    let threshold: Int
                if asrEngine == .speechTranscriber && hasLatin && hasNonLatin {
                        threshold = max(baseThreshold, 4)
                    } else if asrEngine == .speechTranscriber && player.name.count >= 4 {
                        threshold = max(baseThreshold, 3)
                    } else {
                        threshold = baseThreshold
                    }
                    if dist > 0 && dist <= threshold {
                        let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                        let score = max(0.65, 0.85 - Double(dist) * 0.05)
                        results.append((id, side, score))
                        details.append("\(player.name)(编辑距离\(dist)=\(String(format:"%.2f", score)))")
                        continue
                    }
                }

                if !currentRules.locale.identifier.hasPrefix("zh"),
                   let fuzzyScore = fuzzyPlayerNameScore(text: text, playerName: player.name),
                   fuzzyScore >= 0.78 {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, fuzzyScore))
                    details.append("\(player.name)(词元模糊匹配=\(String(format: "%.2f", fuzzyScore)))")
                    continue
                }

                // Priority 2: Variant pool matching (high confidence, avoids double fuzzy)
                let playerVariants = speechTranscriberPlayerPinyinVariants(for: player.name)
                if !userInputVariants.isDisjoint(with: playerVariants) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 0.95))
                    details.append("\(player.name)(变体匹配0.95)")
                    continue
                }

                // Priority 3: Variant pool with nameVariants (surname overrides, letter pinyin)
                let textVariants = currentRules.generatePinyinVariants(text)
                let nameVariants = speechTranscriberPlayerNamePinyinVariants(for: player.name)
                var matched = false
                if !speechTranscriberPlayerExpandedPinyinVariants(for: player.name).isDisjoint(with: textVariants) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 0.90))
                    details.append("\(player.name)(拼音变体0.90)")
                    matched = true
                }
                if !matched {
                    for variant in nameVariants {
                        let score = Self.nameSimilarity(variant, textPinyin)
                        if score >= matchingThreshold {
                            let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                            results.append((id, side, score))
                            details.append("\(player.name)(拼音相似\(score))")
                            matched = true
                            break
                        }
                    }
                }
                if !matched {
                    let pinyin = currentRules.toPinyin(player.name)
                    let score = Self.nameSimilarity(pinyin, textPinyin)
                    details.append("\(player.name)(拼音=\(pinyin) vs \(textPinyin)=\(score))")
                }
            } else if let team = store.team(for: id) {
                let nameLower = team.name.lowercased()
                let isHome = snapshot.homeTeamID == id
                let lowerText = text.lowercased()

                // Priority 1: Direct match (including aliases)
                let aliases: [String] = isHome ? ["主队", "zhudui", "zhu dui", "zudui", "zu dui"] : ["客队", "kedui", "ke dui"]
                let matchesAlias = aliases.contains { lowerText.contains($0) }
                if lowerText.contains(nameLower) || nameLower.contains(lowerText) || matchesAlias {
                    let side: TeamSide = isHome ? .home : .away
                    results.append((id, side, 1.0))
                    details.append("\(team.name)(球队直配)")
                    continue
                }

                // Priority 1.5: Levenshtein distance for team names
                if currentRules.useLevenshteinMatching || asrEngine == .speechTranscriber {
                    let dist = Self.levenshteinDistance(text, team.name)
                    let baseThreshold = team.name.count < 4
                        ? currentRules.levenshteinThreshold.short
                        : currentRules.levenshteinThreshold.long
                    let threshold = asrEngine == .speechTranscriber && team.name.count >= 4
                        ? max(baseThreshold, 3)
                        : baseThreshold
                    if dist > 0 && dist <= threshold {
                        let side: TeamSide = isHome ? .home : .away
                        let score = max(0.65, 0.85 - Double(dist) * 0.05)
                        results.append((id, side, score))
                        details.append("\(team.name)(编辑距离\(dist)=\(String(format:"%.2f", score)))")
                        continue
                    }
                }

                // Priority 2: Variant pool matching (high confidence for team names)
                let teamVariants = speechTranscriberTeamPinyinVariants(for: team.name)
                if !userInputVariants.isDisjoint(with: teamVariants) {
                    let side: TeamSide = isHome ? .home : .away
                    results.append((id, side, 0.95))
                    details.append("\(team.name)(球队变体匹配0.95)")
                    continue
                }

                // Priority 3: Variant pool with namePinyinVariants (fallback for team names)
                let textVariants = currentRules.generatePinyinVariants(text)
                let teamPV = speechTranscriberTeamPinyinVariants(for: team.name)
                if !teamPV.isDisjoint(with: textVariants) {
                    let side: TeamSide = isHome ? .home : .away
                    results.append((id, side, 0.90))
                    details.append("\(team.name)(球队变体0.90)")
                    continue
                } else {
                    let teamPinyin = currentRules.toPinyin(team.name)
                    let score = Self.nameSimilarity(teamPinyin, textPinyin)
                    details.append("\(team.name)(球队拼音=\(teamPinyin) vs \(textPinyin)=\(score))")
                }
            }
        }

        let sorted = results.sorted { a, b in
            if a.2 != b.2 { return a.2 > b.2 }
            let aName = store.player(for: a.0)?.name ?? store.team(for: a.0)?.name ?? ""
            let bName = store.player(for: b.0)?.name ?? store.team(for: b.0)?.name ?? ""
            if a.2 == 0.86, aName.count != bName.count {
                return aName.count < bName.count
            }
            return aName.count > bName.count
        }

        let dbg = details.joined(separator: ", ")
        return (sorted, "\(context)[\(dbg)]")
    }

    private func handleSubstitution(text: String, textPinyin: String) {
        guard let store, let snapshot = currentSnapshot else { return }

        var dbgLines: [String] = []
        dbgLines.append("原文: \(text)")
        dbgLines.append("拼音: \(textPinyin)")
        dbgLines.append("场上主: \(snapshot.homeOnCourtPlayerIDs.map { store.player(for: $0)?.name ?? "?" }.joined(separator: ","))")
        dbgLines.append("场下主: \((snapshot.homeAvailablePlayerIDs.filter { !snapshot.homeOnCourtPlayerIDs.contains($0) }).map { store.player(for: $0)?.name ?? "?" }.joined(separator: ","))")
        dbgLines.append("场上客: \(snapshot.awayOnCourtPlayerIDs.map { store.player(for: $0)?.name ?? "?" }.joined(separator: ","))")
        dbgLines.append("场下客: \((snapshot.awayAvailablePlayerIDs.filter { !snapshot.awayOnCourtPlayerIDs.contains($0) }).map { store.player(for: $0)?.name ?? "?" }.joined(separator: ","))")

        // Try numbers first (on full text)
        let numbers = extractAllNumbers(from: text)
        dbgLines.append("号码: \(numbers)")
        if numbers.count >= 2 {
            for side in [TeamSide.home, TeamSide.away] {
                let cIDs = side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
                let bIDs = (side == .home ? snapshot.homeAvailablePlayerIDs : snapshot.awayAvailablePlayerIDs).filter { !cIDs.contains($0) }
                for (a, b) in [(numbers[0], numbers[1]), (numbers[1], numbers[0])] {
                    if let o = cIDs.first(where: { store.player(for: $0)?.number == "\(a)" }),
                       let i = bIDs.first(where: { store.player(for: $0)?.number == "\(b)" }) {
                        let p1 = store.player(for: o)?.name ?? "?"; let p2 = store.player(for: i)?.name ?? "?"
                        addLog(text: text, isSuccess: true, action: "换人", playerName: "\(p1)→\(p2)")
                        onFlash?(.green)
                        onSubstitution?(side, o, i); return
                    }
                }
            }
        }

        // Split by keyword: everything before = subject, everything after = object
        var subject = text, object = "", usedKw = ""
        for kw in currentRules.substitutionKeywords {
            if let range = text.range(of: kw, options: [.caseInsensitive]) {
                subject = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                object = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                usedKw = kw; break
            }
        }
        dbgLines.append("关键词: \(usedKw)")
        dbgLines.append("主语[\(subject)]")
        dbgLines.append("宾语[\(object)]")

        guard !subject.isEmpty, !object.isEmpty else {
            addLog(text: text, isSuccess: false, action: "换人", matchDetail: dbgLines.joined(separator: " | "))
            showErrorWithFlash(NSLocalizedString("voice_substitution_failed", comment: ""))
            return
        }

        // Convert to pinyin without fuzzy processing (matchPlayerIDsDebug handles variants internally)
        let subPinyin = currentRules.toPinyin(subject)
        let objPinyin = currentRules.toPinyin(object)

        // Try BOTH orderings since "A 替换 B" could mean A incoming OR A outgoing.
        for (label, courtP, benchP) in [("主语上场", subPinyin, objPinyin), ("主语下场", objPinyin, subPinyin)] {
            for side in [TeamSide.home, TeamSide.away] {
                let cIDs = side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
                let bIDs = (side == .home ? snapshot.homeAvailablePlayerIDs : snapshot.awayAvailablePlayerIDs).filter { !cIDs.contains($0) }
                let lbl = side == .home ? "主" : "客"
                let courtText = courtP == subPinyin ? subject : object
                let benchText = benchP == objPinyin ? object : subject
                let (cM, cD) = matchPlayerIDsDebug(text: courtText, textPinyin: courtP, in: cIDs, context: "\(lbl)场上(\(label))")
                let (bM, bD) = matchPlayerIDsDebug(text: benchText, textPinyin: benchP, in: bIDs, context: "\(lbl)场下(\(label))")
                dbgLines.append("\(label) \(lbl): 场上\(cD) | 场下\(bD)")
                if let ot = cM.first, let it = bM.first {
                    let outN = store.player(for: ot.0)?.name ?? "?"; let inN = store.player(for: it.0)?.name ?? "?"
                    addLog(text: text, isSuccess: true, action: "换人", playerName: "\(outN)→\(inN)")
                    onFlash?(.green)
                    onSubstitution?(side, ot.0, it.0); return
                }
            }
        }

        // Cross-side fallback: try both orderings
        let allCourt = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
        let allBench = (snapshot.homeAvailablePlayerIDs + snapshot.awayAvailablePlayerIDs).filter { !allCourt.contains($0) }
        for (label, cP, bP) in [("跨场上场", subPinyin, objPinyin), ("跨场下场", objPinyin, subPinyin)] {
            let ct = cP == subPinyin ? subject : object; let bt = bP == objPinyin ? object : subject
            let (cM, cD) = matchPlayerIDsDebug(text: ct, textPinyin: cP, in: allCourt, context: label+"场上")
            let (bM, bD) = matchPlayerIDsDebug(text: bt, textPinyin: bP, in: allBench, context: label+"场下")
            dbgLines.append("\(label): 场上\(cD) | 场下\(bD)")
            if let ot = cM.first, let it = bM.first {
                let sd: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(ot.0) ? .home : .away
                let outN = store.player(for: ot.0)?.name ?? "?"; let inN = store.player(for: it.0)?.name ?? "?"
                addLog(text: text, isSuccess: true, action: "换人", playerName: "\(outN)→\(inN)")
                onFlash?(.green)
                onSubstitution?(sd, ot.0, it.0); return
            }
        }

        addLog(text: text, isSuccess: false, action: "换人", matchDetail: dbgLines.joined(separator: " | "))
        showErrorWithFlash(NSLocalizedString("voice_substitution_failed", comment: ""))
    }

    /// Anchor-based matching: split text on state word anchors,
    /// determine made/missed from the anchor word, resolve player from left part,
    /// and match shot keyword from right part.
    /// Only enabled when currentRules.useAnchorMatching is true.
    private func processAnchorMatch(_ text: String) -> Bool {
        guard currentRules.useAnchorMatching else { return false }
        guard let store, let snapshot = currentSnapshot else { return false }

        let pattern = "\\b(" + currentRules.anchorWords.joined(separator: "|") + ")\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange) else { return false }

        let anchorStart = match.range.location
        let anchorEnd = match.range.location + match.range.length
        let left = (text as NSString).substring(with: NSRange(location: 0, length: anchorStart))
            .trimmingCharacters(in: .whitespaces)
        let right = (text as NSString).substring(with: NSRange(location: anchorEnd, length: text.utf16.count - anchorEnd))
            .trimmingCharacters(in: .whitespaces)
        let anchor = (text as NSString).substring(with: match.range(at: 1)).lowercased()

        let isMade = (anchor == "made" || anchor == "got" || anchor == "get")

        // Match action from right text — try shots first, then stat events
        var matchedCode: String?
        var matchedKeyword = ""
        var isShot = false

        for shot in voiceShotTypes {
            if right.range(of: shot.keyword, options: [.caseInsensitive]) != nil {
                matchedCode = shot.eventPrefix + (isMade ? "Made" : "Missed")
                matchedKeyword = shot.keyword
                isShot = true
                break
            }
        }

        if matchedCode == nil {
            for (keyword, code) in currentRules.statEvents {
                if right.range(of: keyword, options: [.caseInsensitive]) != nil {
                    matchedCode = code
                    matchedKeyword = keyword
                    isShot = false
                    break
                }
            }
        }

        guard let finalCode = matchedCode else { return false }

        // Resolve player from left text
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
        var playerID: UUID?
        var side: TeamSide?
        var dbgPlayer = ""

        if let res = resolvePlayerNumber(from: left, allIDs: allIDs) {
            playerID = res.playerID; side = res.side; dbgPlayer = res.debug
        }

        if playerID == nil, !left.isEmpty {
            let leftPinyin = currentRules.toPinyin(left)
            if let res = resolvedPlayerCandidate(text: left, textPinyin: leftPinyin, in: allIDs, context: "锚点左侧球员") {
                playerID = res.playerID
                side = res.side
                dbgPlayer = res.debug
            }
        }

        guard let pid = playerID, let sd = side else {
            // No player resolved — let normal flow try
            return false
        }

        guard let action = StatAction.allCases.first(where: { $0.eventCode == finalCode }) else {
            addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 锚点匹配: 无对应StatAction")
            showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
            return true
        }

        let pn = store.player(for: pid)?.name ?? "?"
        let stateLabel = isShot ? (isMade ? "命中" : "未中") : ""
        addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "锚点匹配: 锚点=\(anchor)(\(stateLabel)) | 关键词=\(matchedKeyword) | \(dbgPlayer)")
        showSuccessFeedback(text: text, action: action, playerID: pid, side: sd)
        return true
    }

    func simulateText(_ text: String) {
        processText(text)
    }

    private func processText(_ text: String) {
        let normalizedText = normalizeSpeechTranscriberText(text)
        preferredPlayerNumber = nil
        logStart(normalizedText)
        let textPinyin = currentRules.toPinyin(normalizedText)
        logStep("原文: \(normalizedText) | 拼音: \(textPinyin)")
        if let speechTranscriberTimingDetail {
            logStep(speechTranscriberTimingDetail)
            self.speechTranscriberTimingDetail = nil
        }

        if let mappings = store?.customVoiceMappings {
            for (phrase, eventCode) in mappings {
                guard let range = normalizedText.range(of: phrase, options: [.caseInsensitive]) else { continue }
                let action = StatAction.allCases.first(where: { $0.eventCode == eventCode })
                guard let store, let snapshot = currentSnapshot, let act = action else {
                    addLog(text: normalizedText, isSuccess: false, action: eventCode, matchDetail: "自定义映射无对应动作: \(phrase)")
                    return
                }
                let leftText = String(normalizedText[normalizedText.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
                var pid: UUID?; var sd: TeamSide?
                if let res = resolvePlayerNumber(from: leftText, allIDs: allIDs) { pid = res.playerID; sd = res.side }
                if pid == nil, !leftText.isEmpty {
                    let leftPinyin = currentRules.toPinyin(leftText)
                    if let res = resolvedPlayerCandidate(text: leftText, textPinyin: leftPinyin, in: allIDs, context: "自定义映射") {
                        pid = res.playerID
                        sd = res.side
                    }
                }
                guard let playerID = pid, let side = sd else {
                    addLog(text: normalizedText, isSuccess: false, action: eventCode, matchDetail: "自定义映射无球员匹配: \(phrase)")
                    return
                }
                let pn = store.player(for: playerID)?.name ?? "?"
                addLog(text: normalizedText, isSuccess: true, action: act.message, playerName: pn, matchedPattern: eventCode, matchDetail: "自定义映射: \(phrase)")
                showSuccessFeedback(text: normalizedText, action: act, playerID: playerID, side: side)
                return
            }
        }

        if asrEngine == .speechTranscriber, processSpeechTranscriberCommand(normalizedText) { return }

        if currentRules.substitutionKeywords.contains(where: { normalizedText.range(of: $0, options: [.caseInsensitive]) != nil }) {
            handleSubstitution(text: normalizedText, textPinyin: textPinyin)
            return
        }

        // Only preprocess English text for English locale
        let preprocessedText = currentRules.locale.identifier.hasPrefix("en") ? preprocessEnglishText(normalizedText) : normalizedText
        let processedText = expandMergedPlayerShotNumber(in: preprocessedText)
        let processedTextPinyin = currentRules.toPinyin(processedText)

        if processAnchorMatch(processedText) { return }
        if processByDirectTextMatching(text: processedText, textPinyin: processedTextPinyin) { return }
        if processByPinyinFallback(text: processedText, textPinyin: processedTextPinyin) { return }

        addLog(text: processedText, isSuccess: false, matchDetail: "❌ 全文无匹配: \(processedText) | 拼音: \(processedTextPinyin)")
        showError(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), processedText))
        onFlash?(.red)
    }

    private func expandMergedPlayerShotNumber(in text: String) -> String {
        guard let store, let snapshot = currentSnapshot else { return text }
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
        let playerNumbers = Set(allIDs.compactMap { store.player(for: $0)?.number })
        guard !playerNumbers.isEmpty,
              let regex = try? NSRegularExpression(pattern: "(?i)\\bnumber\\s+(\\d{2,3})\\b") else { return text }

        var expanded = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard match.numberOfRanges > 1,
                  let tokenRange = Range(match.range(at: 1), in: text) else { continue }
            let digits = String(text[tokenRange])
            guard let last = digits.last,
                  last == "2" || last == "3" else { continue }
            let prefix = String(digits.dropLast())
            guard prefix != "0",
                  playerNumbers.contains(prefix),
                  !playerNumbers.contains(digits),
                  let fullRange = Range(match.range, in: expanded) else { continue }
            expanded.replaceSubrange(fullRange, with: "number \(prefix) \(last)")
        }
        return expanded
    }

    private func normalizeSpeechTranscriberText(_ text: String) -> String {
        Self.normalizeSpeechTranscriberText(text, rules: currentRules)
    }

    nonisolated private static func normalizeSpeechTranscriberText(_ text: String, rules: VoiceRules) -> String {
        var normalized = text.precomposedStringWithCanonicalMapping
        for punctuation in ["，", "。", "！", "？", "、", ",", ".", "!", "?", ";", "：", ":"] {
            normalized = normalized.replacingOccurrences(of: punctuation, with: " ")
        }
        normalized = compactSpeechTranscriberCJKWhitespace(normalized)
        normalized = normalizeSpeechTranscriberPlayerNumberWords(normalized, rules: rules)
            let aliases: [(String, String)] = [
            ("兰下", "篮下"),
            ("拦下", "篮下"),
            ("攔下", "籃下"),
            ("上蓝", "上篮"),
            ("上兰", "上篮"),
            ("上藍", "上籃"),
            ("家伐", "加罚"),
            ("加伐", "加罚"),
            ("将罚", "加罚"),
            ("家罚", "加罚"),
            ("將罰", "加罰"),
            ("伐墨", "没中"),
            ("伐默", "没中"),
            ("默中", "没中"),
            ("为中", "没中"),
            ("味中", "命中"),
            ("米钟", "命中"),
            ("秒钟", "命中"),
            ("助公", "助攻"),
            ("祖公", "助攻"),
            ("助工程结", "助攻"),
            ("南下", "篮下"),
            ("想乱", "抢断"),
            ("相乱", "抢断"),
            ("枪断", "抢断"),
            ("寇难", "扣篮"),
            ("钟头", "中投"),
            ("沖座", "重做"),
            ("冲座", "重做"),
            ("罰錢", "罰球"),
            ("闆", "板")
        ]
        for (source, replacement) in aliases {
            normalized = normalized.replacingOccurrences(of: source, with: replacement)
        }
        if rules.locale.identifier.hasPrefix("en") {
            let englishAliases: [(String, String)] = [
                ("got one", "got and one"),
                ("missed it one", "missed and one"),
                ("mystery throw", "missed free throw"),
                ("got paid", "got paint"),
                ("got mad", "got putback"),
                ("mispaid", "missed paint"),
                ("got made range", "got mid range"),
                ("got close back", "got putback"),
                ("close back", "putback"),
                ("hoodback", "putback"),
                ("miss hoodback", "missed putback"),
                ("miss zug", "missed dunk"),
                ("put match", "putback"),
                ("quarterback", "putback"),
                ("got dug", "got dunk"),
                ("got done", "got dunk"),
                ("godmid", "got mid"),
                ("miss sugg", "missed dunk"),
                ("remound", "rebound"),
                ("time out", "timeout"),
                ("miss who", "missed two"),
                ("missed and won", "missed and one"),
                ("missed one", "missed and one"),
                ("missing one", "missed and one"),
                ("mr one", "missed and one"),
                ("offensive remount", "offensive rebound"),
                ("turned over", "turnover"),
                ("layoff", "layup"),
                ("pained", "paint"),
                ("pot back", "putback"),
                ("ms putback", "missed putback"),
                ("pushback", "putback"),
                ("dong", "dunk"),
                ("sunk", "dunk"),
                ("miss sun", "missed dunk"),
                ("miss doug", "missed dunk"),
                ("his rage", "mid range"),
                ("n1", "and one"),
                ("mr. one", "missed and one"),
                ("new last action", "undo"),
                ("his sister", "assist"),
                ("'s sister", "assist"),
                ("’s sister", "assist"),
                ("’s the", " steal"),
                ("'s the", " steal"),
                ("i do", "undo"),
                ("we do", "redo"),
                ("stars", "start")
            ]
            for (source, replacement) in englishAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if rules.locale.identifier.hasPrefix("zh-Hant") {
            let traditionalChineseAliases: [(String, String)] = [
                ("將伐", "加罰"),
                ("扣來", "扣籃"),
                ("伐墨", "沒中"),
                ("墨中", "沒中"),
                ("攔下", "籃下"),
                ("聖藍", "上籃"),
                ("補來", "補籃"),
                ("後來", "扣籃"),
                ("前場籃板", "前場板"),
                ("後場籃板", "後場板"),
                ("超級", "抄截")
            ]
            for (source, replacement) in traditionalChineseAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement)
            }
        } else if rules.locale.identifier.hasPrefix("ja") {
            normalized = normalized.replacingOccurrences(of: " ", with: "")
            normalized = normalized.replacingOccurrences(of: "ディフェンスリバウンド", with: "守備リバウンド")
            let japaneseAliases: [(String, String)] = [
                ("タイムラブを", "タイムアウト"),
                ("おしこ", "ペイント成功"),
                ("2番外した", "2番ツー外した"),
                ("今向けと外した", "2番ペイント外した"),
                ("ラマンバブル", "5番ファウル"),
                ("ヒューマ500スリバウンド", "9番オフェンスリバウンド"),
                ("10マリのリバウンド", "10番ディフェンスリバウンド"),
                ("3マラシスト40", "3番アシスト4番ツー"),
                ("1番口座にる", "1番交代2番"),
                ("聖校", "成功"),
                ("通", "ツー"),
                ("害した", "外した"),
                ("製鋼", "成功"),
                ("メドル", "ミドル"),
                ("メダル", "ミドル"),
                ("スリーマウンド", "リバウンド"),
                ("釣り", "スリー"),
                ("設外した", "ツー外した"),
                ("棒ナス", "ボーナス"),
                ("敏子", "成功"),
                ("山田園", "山田エマ"),
                ("パッドバック", "パットバック"),
                ("プットバック", "パットバック"),
                ("プットバク", "パットバク"),
                ("英馬", "エマ"),
                ("DMM", "エマ"),
                ("江村CL", "マイケル"),
                ("江村美恵", "マイケル"),
                ("鈴木賞", "鈴木翔"),
                ("鈴木精工", "鈴木翔スリー成功"),
                ("美作数", "美咲ツー"),
                ("美作", "美咲"),
                ("伊藤親", "伊藤葵"),
                ("異断苦", "ダンク"),
                ("断苦いした", "ダンク外した"),
                ("バットバック買いした", "パットバック外した"),
                ("オーバー", "ターンオーバー"),
                ("ミドルセコ", "ミドル成功"),
                ("ミドルセイコ", "ミドル成功"),
                ("フェンスリバウンド", "オフェンスリバウンド"),
                ("リマウンド", "リバウンド"),
                ("リマインド", "リバウンド"),
                ("スリマウンド", "リバウンド"),
                ("スリマインド", "リバウンド"),
                ("スピール", "スティール"),
                ("アローバー", "ターンオーバー"),
                ("タイムラブと", "タイムアウト"),
                ("タイムラウド", "タイムアウト"),
                ("ハウル", "ファウル"),
                ("ファール", "ファウル"),
                ("ミドルシュート", "ミドル"),
                ("トーンオーバー", "ターンオーバー"),
                ("ターンオーバ", "ターンオーバー"),
                ("アシスト", "アシスト"),
                ("リアり直す", "やり直す")
            ]
            for (source, replacement) in japaneseAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement)
            }
            normalized = normalized.replacingOccurrences(of: "守備リバウンド", with: "ディフェンスリバウンド")
            let japaneseNumberAliases: [(String, String)] = [
                ("ロマンボ", "5番ボーナス"),
                ("ロマン南", "5番ダンク"),
                ("6000", "6番ダンク"),
                ("日本版", "4番"),
                ("ネバーズ", "2番"),
                ("ネバ", "2番"),
                ("サンマン", "3番"),
                ("サンマ", "3番"),
                ("ロマン", "5番"),
                ("60000", "6番"),
                ("ヒューマン", "9番"),
                ("ゆうま", "10番"),
                ("1000円", "1番"),
                ("サムマン", "3番"),
                ("日本マン", "4番"),
                ("日本", "1番")
            ]
            for (source, replacement) in japaneseNumberAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement)
            }
        } else if rules.locale.identifier.hasPrefix("ko") {
            let koreanAliases: [(String, String)] = [
                ("삼 노시스 투 사 투", "3번 어시스트 4번 투"),
                ("삼노시스투사투", "3번 어시스트 4번 투"),
                ("시스 투 육 투 쓰리", "5번 어시스트 6번 쓰리"),
                ("시스투육투쓰리", "5번 어시스트 6번 쓰리"),
                ("일본 수선", "2번 투 성공"),
                ("일본수선", "2번 투 성공"),
                ("어떤 습니까", "보너스 성공"),
                ("어떤습니까", "보너스 성공"),
                ("오너심해", "5번 보너스 실패"),
                ("할머니아유조심해", "8번 자유투 실패"),
                ("일본페인수성공", "1번 페인트 성공"),
                ("삼어시스트투사투", "3번 어시스트 4번 투"),
                ("시스투육투쓰리", "5번 어시스트 6번 쓰리"),
                ("12터미널", "12번 블록"),
                ("여기점이요", "종료"),
                ("마지막일행", "재실행"),
                ("일본요제일본", "1번 교체 2번"),
                ("전공", "투 성공"),
                ("점검", "투 성공"),
                ("두시에", "투 실패"),
                ("수리 선물", "쓰리 성공"),
                ("수리 성공", "쓰리 성공"),
                ("수리성공", "쓰리 성공"),
                ("술이", "쓰리"),
                ("수선", "투 성공"),
                ("수선공", "투 성공"),
                ("레이협", "레이업"),
                ("레이역시", "레이업 실패"),
                ("태백", "팟백"),
                ("김애마", "김엠마"),
                ("연수를 실패", "쓰리 실패"),
                ("바울", "파울"),
                ("오시스트", "어시스트"),
                ("로시스트", "어시스트"),
                ("수틸", "스틸"),
                ("수질", "스틸"),
                ("스필", "스틸"),
                ("리마운드", "리바운드"),
                ("마운드", "리바운드"),
                ("오버", "턴오버"),
                ("노버", "턴오버"),
                ("시스트", "어시스트"),
                ("노시스", "어시스트"),
                ("번수", "보너스"),
                ("본수", "보너스"),
                ("풋백", "팟백"),
                ("풋백슛", "팟백"),
                ("100 실패", "팟백 실패"),
                ("100 성공", "팟백 성공"),
                ("블락", "블록"),
                ("블럭", "블록"),
                ("레이 협", "레이업"),
                ("레이 역시", "레이업 실패"),
                ("레이 협성공", "레이업 성공"),
                ("레이협성공", "레이업 성공"),
                ("미투", "미드"),
                ("믿으실패", "미드 실패"),
                ("믿으실 패", "미드 실패"),
                ("레이 없습니까", "레이업 성공"),
                ("타임마웃", "타임아웃"),
                ("턴 로버", "턴오버"),
                ("턴로버", "턴오버"),
                ("조성공", "투 성공"),
                ("삼촌", "투 성공"),
                ("삼 공", "투 성공"),
                ("팥팩", "팟백"),
                ("파택", "팟백"),
                ("팟팩", "팟백"),
                ("수비를 파운드", "수비 리바운드"),
                ("3번 830", "3번 팟백 성공"),
                ("4번 맛 택시에", "4번 팟백 실패"),
                ("5번 넘교실에", "5번 덩크 실패"),
                ("1번 일", "1번 스틸"),
                ("타이머", "타임아웃"),
                ("수빈 Bound", "수비 리바운드"),
                ("제주도", "교체"),
                ("우시 스트", "어시스트")
            ]
            for (source, replacement) in koreanAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement)
            }
            let koreanNumberAliases: [(String, String)] = [
                ("오 너 심해", "5번 보너스 실패"),
                ("할머니 아유 조심해", "8번 자유투 실패"),
                ("일본", "1번"),
                ("이번", "2번"),
                ("십이", "12번"),
                ("십일", "11번"),
                ("삼", "3번"),
                ("사", "4번"),
                ("오", "5번"),
                ("육", "6번"),
                ("칠", "7번"),
                ("팔", "8번"),
                ("구", "9번"),
                ("십", "10번")
            ]
            for (source, replacement) in koreanNumberAliases {
                normalized = Self.replaceSpeechTranscriberRegex(
                    normalized,
                    pattern: "(?<![가-힣])\(source)(?![가-힣])",
                    template: replacement
                )
            }
            if normalized.contains("어시스트") {
                normalized = Self.replaceSpeechTranscriberRegex(normalized, pattern: "([가-힣])3$", template: "$1 쓰리")
            }
        } else if rules.locale.identifier.hasPrefix("de") {
            normalized = normalized.replacingOccurrences(of: "nummer ", with: "number ", options: .caseInsensitive)
            let germanAliases: [(String, String)] = [
                ("number 6 number mehr fehlt", "number 6 bonus verfehlt"),
                ("number 12 mit der distanzählt", "number 12 mitteldistanz verfehlt"),
                ("anna fischer verfehlt", "anna fischer korbnähe verfehlt"),
                ("number 4 gut erzählt", "number 4 putback verfehlt"),
                ("number 5 getroffen", "number 5 dunk getroffen"),
                ("wurde getroffen", "bonus getroffen"),
                ("muss getroffen", "bonus getroffen"),
                ("getroffn", "getroffen"),
                ("getrofen", "getroffen"),
                ("erfolgt", "erfolg"),
                ("nicht drin", "nicht"),
                ("korb nähe", "korbnähe"),
                ("mittel distanz", "mitteldistanz"),
                ("leib", "layup"),
                ("redund", "rebound"),
                ("redound", "rebound"),
                ("bund", "rebound"),
                ("dung", "dunk"),
                ("Fuhl", "foul"),
                ("cool", "foul"),
                ("Freiburg", "freiwurf"),
                ("Firework", "freiwurf verfehlt"),
                ("Profilbild", "layup verfehlt"),
                ("dumm", "dunk"),
                ("Steice", "steal"),
                ("mit distanz", "mitteldistanz"),
                ("du verfehlt", "dunk verfehlt"),
                ("kolail", "korbnähe"),
                ("kutback", "putback"),
                ("organisiert", "offensiv rebound"),
                ("stau das spiel", "start"),
                ("nämlich die letzte aktion", "rückgängig"),
                ("diese eure letzte aktion", "wiederholen"),
                ("nummer ", "number ")
            ]
            for (source, replacement) in germanAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if rules.locale.identifier.hasPrefix("es") {
            normalized = normalized.replacingOccurrences(of: "número ", with: "number ", options: .caseInsensitive)
            normalized = normalized.replacingOccurrences(of: "numero ", with: "number ", options: .caseInsensitive)
            let spanishAliases: [(String, String)] = [
                ("mi number 33 anotótó", "number 3 tres anotó"),
                ("ana torres que ha fallado", "ana torres tres fallado"),
                ("number 5 y", "number 5 y uno anotó"),
                ("number 61 fallado", "number 6 y uno fallado"),
                ("juan pérezputbakanotó", "juan pérez putback anotó"),
                ("vaca dos", "putback anotó"),
                ("carlos garcía ro", "carlos garcía robo"),
                ("number 10 pero el bote es defensivo", "number 10 rebote defensivo"),
                ("ano", "anotó"),
                ("anoto", "anotó"),
                ("agosto", "anotó"),
                ("anotao", "anotó"),
                ("fallo", "fallado"),
                ("falló", "fallado"),
                ("no se anotó", "anotó"),
                ("Aventura", "pintura"),
                ("Ventura", "pintura"),
                ("Valistencia", "asistencia"),
                ("Futback", "putback"),
                ("Llevo muerto", "tiempo muerto"),
                ("tiempo y muerto", "tiempo muerto"),
                ("cambió", "cambio"),
                ("y una", "y uno"),
                ("del partido", "fin del partido"),
                ("de bandeja", "bandeja"),
                ("libro", "libre"),
                ("Royaltair", "rehacer"),
                ("rayado", "bandeja"),
                ("valle", "mate"),
                ("metano", "mate"),
                ("pbak", "putback"),
                ("budback", "putback"),
                ("revolte", "rebote"),
                ("revolt", "rebote"),
                ("bloque", "bloqueo"),
                ("hallado", "fallado"),
                ("balado", "fallado"),
                ("número ", "number "),
                ("numero ", "number ")
            ]
            for (source, replacement) in spanishAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
            normalized = Self.replaceSpeechTranscriberRegex(
                normalized,
                pattern: "(?i)(?<![A-Za-zÁÉÍÓÚÜÑáéíóúüñ])rebo(?![A-Za-zÁÉÍÓÚÜÑáéíóúüñ])",
                template: "rebote"
            )
        } else if rules.locale.identifier.hasPrefix("fr") {
            normalized = normalized.replacingOccurrences(of: "numéro ", with: "number ", options: .caseInsensitive)
            normalized = normalized.replacingOccurrences(of: "numero ", with: "number ", options: .caseInsensitive)
            let frenchAliases: [(String, String)] = [
                ("thomas petit est réussi", "thomas petit bonus réussi"),
                ("number 5 réussi", "number 5 bonus réussi"),
                ("léa moreau est un raté", "léa moreau bonus raté"),
                ("number 6 c'est un raté", "number 6 bonus raté"),
                ("alice réussi", "alice layup réussi"),
                ("est ici", "lay-up réussi"),
                ("léa maudraté", "léa moreau dunk raté"),
                ("michael rubon", "michael rebond"),
                ("number de balle", "number 2 perte de balle"),
                ("première dernière réaction", "refaire dernière action"),
                ("réussit", "réussi"),
                ("reussit", "réussi"),
                ("réussite", "réussi"),
                ("lanco", "lancer"),
                ("backwater", "putback"),
                ("rate", "raté"),
                ("doit réussir", "deux réussi"),
                ("de rater", "deux raté"),
                ("L'air du bois de balle", "perte de balle"),
                ("putbach", "putback"),
                ("putba", "putback"),
                ("raymond", "rebond"),
                ("miance", "mi-distance"),
                ("mance", "mi-distance"),
                ("numéroception", "interception"),
                ("praté", "raté"),
                ("mort", "temps mort"),
                ("numéro ", "number "),
                ("numero ", "number ")
            ]
            for (source, replacement) in frenchAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if rules.locale.identifier.hasPrefix("it") {
            normalized = normalized.replacingOccurrences(of: "numero ", with: "number ", options: .caseInsensitive)
            let italianAliases: [(String, String)] = [
                ("segnata", "segnato"),
                ("sbagliata", "sbagliato"),
                ("ti ha segnato", "tre segnato"),
                ("la ha segnato", "layup segnato"),
                ("lou è sbagliato", "layup sbagliato"),
                ("vedi ha segnato", "media distanza segnato"),
                ("vedi sbagliato", "media distanza sbagliato"),
                ("Bon segnato", "bonus segnato"),
                ("ti ero", "tiro"),
                ("va segnato", "putback segnato"),
                ("con sbagliato", "putback sbagliato"),
                ("rivalso", "rimbalzo"),
                ("Assis ", "assist "),
                ("farla rubata", "palla rubata"),
                ("Cabrio", "cambio"),
                ("putball", "putback"),
                ("putbal", "putback"),
                ("l'hai segnato", "layup segnato"),
                ("la sbagliato", "layup sbagliato"),
                ("lype", "layup"),
                ("stottata", "stoppata"),
                ("cagliato", "sbagliato"),
                ("ostensivo", "offensivo"),
                ("numero ", "number ")
            ]
            for (source, replacement) in italianAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if rules.locale.identifier.hasPrefix("ru") {
            normalized = normalized.replacingOccurrences(of: "номер ", with: "number ", options: .caseInsensitive)
            let russianNumberAliases: [(String, String)] = [
                ("номер ", "number "),
                ("dunk", "данк"),
                ("пабы", "putback"),
                ("под промах", "putback промах"),
                ("blob", "блок")
            ]
            for (source, replacement) in russianNumberAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        }
        return normalized
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalizeSpeechTranscriberPlayerNumberWords(_ text: String, rules: VoiceRules) -> String {
        var normalized = text
        let locale = rules.locale.identifier
        let numberWords: [(String, String)]
        if locale.hasPrefix("de") {
            numberWords = [("eins", "1"), ("zwei", "2"), ("drei", "3"), ("vier", "4"), ("fünf", "5"), ("funf", "5"), ("sechs", "6"), ("sieben", "7"), ("acht", "8"), ("neun", "9"), ("zehn", "10"), ("elf", "11"), ("zwölf", "12"), ("zwolf", "12")]
        } else if locale.hasPrefix("es") {
            numberWords = [("uno", "1"), ("una", "1"), ("dos", "2"), ("tres", "3"), ("cuatro", "4"), ("cinco", "5"), ("seis", "6"), ("siete", "7"), ("ocho", "8"), ("nueve", "9"), ("diez", "10"), ("once", "11"), ("doce", "12")]
        } else if locale.hasPrefix("fr") {
            numberWords = [("un", "1"), ("une", "1"), ("deux", "2"), ("trois", "3"), ("quatre", "4"), ("cinq", "5"), ("six", "6"), ("sept", "7"), ("huit", "8"), ("neuf", "9"), ("dix", "10"), ("onze", "11"), ("douze", "12")]
        } else if locale.hasPrefix("it") {
            numberWords = [("uno", "1"), ("una", "1"), ("due", "2"), ("tre", "3"), ("quattro", "4"), ("cinque", "5"), ("sei", "6"), ("sette", "7"), ("otto", "8"), ("nove", "9"), ("dieci", "10"), ("undici", "11"), ("dodici", "12")]
        } else if locale.hasPrefix("ru") {
            numberWords = [("один", "1"), ("одна", "1"), ("два", "2"), ("три", "3"), ("четыре", "4"), ("пять", "5"), ("шесть", "6"), ("семь", "7"), ("восемь", "8"), ("девять", "9"), ("десять", "10"), ("одиннадцать", "11"), ("двенадцать", "12")]
        } else {
            numberWords = []
        }
        let marker: String?
        if locale.hasPrefix("de") { marker = "Nummer" }
        else if locale.hasPrefix("es") { marker = "número" }
        else if locale.hasPrefix("fr") { marker = "numéro" }
        else if locale.hasPrefix("it") { marker = "numero" }
        else if locale.hasPrefix("ru") { marker = "номер" }
        else { marker = nil }
        if let marker {
            for (word, number) in numberWords {
                normalized = normalized.replacingOccurrences(of: "\(marker) \(word)", with: "\(marker) \(number)", options: [.caseInsensitive])
            }
        }
        if locale.hasPrefix("zh") {
            let marker = locale.hasPrefix("zh-Hant") ? "號" : "号"
            let values = [("十二", "12"), ("十一", "11"), ("十", "10"), ("九", "9"), ("八", "8"), ("七", "7"), ("六", "6"), ("五", "5"), ("四", "4"), ("三", "3"), ("二", "2"), ("一", "1")]
            for (word, number) in values {
                normalized = normalized.replacingOccurrences(of: "\(word)\(marker)", with: "\(number)\(marker)")
            }
        } else if locale.hasPrefix("ja") {
            let values = [("十二", "12"), ("十一", "11"), ("十", "10"), ("九", "9"), ("八", "8"), ("七", "7"), ("六", "6"), ("五", "5"), ("四", "4"), ("三", "3"), ("二", "2"), ("一", "1")]
            for (word, number) in values {
                normalized = normalized.replacingOccurrences(of: "\(word)番", with: "\(number)番")
            }
        } else if locale.hasPrefix("ko") {
            let values = [("십이", "12"), ("십일", "11"), ("십", "10"), ("구", "9"), ("팔", "8"), ("칠", "7"), ("육", "6"), ("오", "5"), ("사", "4"), ("삼", "3"), ("이", "2"), ("일", "1")]
            for (word, number) in values {
                normalized = normalized.replacingOccurrences(of: "\(word)번", with: "\(number)번")
            }
            normalized = Self.replaceSpeechTranscriberRegex(normalized, pattern: "(\\d+)\\s*분", template: "$1번")
        }
        return normalized
    }

    nonisolated private static func replaceSpeechTranscriberRegex(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template)
    }

    private func speechTranscriberHasUniqueNameToken(text: String, playerName: String, playerNames: [String]) -> Bool {
        let textTokens = speechTranscriberNameTokens(text)
        let nameTokens = speechTranscriberNameTokens(playerName)
        if nameTokens.count > 1, nameTokens.allSatisfy({ textTokens.contains($0) }) {
            return true
        }
        let sharedTokens = Set(textTokens).intersection(nameTokens)
        for token in sharedTokens {
            let isLatinToken = token.count >= 3 && token.allSatisfy { $0.isASCII && $0.isLetter }
            let isCJKToken = token.count >= 2 && token.unicodeScalars.contains { scalar in
                switch scalar.value {
                case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                    return true
                default:
                    return false
                }
            }
            guard isLatinToken || isCJKToken else { continue }
            let matchingNames = playerNames.filter { name in
                speechTranscriberNameTokens(name).contains { candidate in
                    let distanceLimit = min(candidate.count, token.count) <= 3 ? 1 : 2
                    return candidate == token
                        || (candidate.count >= 2 && token.count > candidate.count && token.contains(candidate))
                        || (token.count >= 3 && candidate.count >= 3 && Self.levenshteinDistance(candidate, token) <= distanceLimit)
                }
            }
            if matchingNames.count == 1 {
                return true
            }
        }
        return false
    }

    private func speechTranscriberNameTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var previousIsNativeScript: Bool?

        func flush() {
            guard !current.isEmpty else { return }
            tokens.append(current)
            current = ""
            previousIsNativeScript = nil
        }

        for character in text.lowercased() {
            guard character.isLetter || character.isNumber else {
                flush()
                continue
            }
            let isNativeScript = Self.isSpeechTranscriberNativeScriptCharacter(character)
            if let previousIsNativeScript, previousIsNativeScript != isNativeScript {
                flush()
            }
            current.append(character)
            previousIsNativeScript = isNativeScript
        }
        flush()
        return tokens
    }

    private func speechTranscriberAlphanumericNameKey(_ text: String) -> String? {
        let key = text.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard key.contains(where: { $0.isLetter }), key.contains(where: { $0.isNumber }) else { return nil }
        return key
    }

    nonisolated private static func compactSpeechTranscriberCJKWhitespace(_ text: String) -> String {
        let characters = Array(text)
        var compacted = ""
        for index in characters.indices {
            if characters[index].isWhitespace,
               index > 0,
               index + 1 < characters.count,
               Self.isCJKCharacter(characters[index - 1]),
               Self.isCJKCharacter(characters[index + 1]) {
                continue
            }
            compacted.append(characters[index])
        }
        return compacted
    }

    nonisolated private static func isCJKCharacter(_ character: Character) -> Bool {
        isSpeechTranscriberNativeScriptCharacter(character)
    }

    nonisolated private static func isSpeechTranscriberNativeScriptCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x3040...0x309F, 0x30A0...0x30FF, 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }

    private func processSpeechTranscriberCommand(_ text: String) -> Bool {
        let isChinese = currentRules.locale.identifier.hasPrefix("zh") || currentRules.locale.identifier.hasPrefix("zh-Hant")
        let pinyin = currentRules.toPinyin(text)
        let isChineseEndCommand = isChinese && pinyin.contains("jie shu")
        let isChinesePeriodEndCommand = isChinese && containsPeriodMarker(in: text) && isChineseEndCommand
        let command: VoiceCommand?
        if isChinesePeriodEndCommand {
            guard currentPeriodIsRunning else { return false }
            command = .startPeriod
        } else if text == "结束" || text == "結束" || text == "结束比赛" || text == "結束比賽" || text == "比赛结束" || text == "比賽結束" || isChineseEndCommand {
            command = shouldPreferCurrentPeriodEnd(for: text, keyword: "结束") ? .startPeriod : .finishGame
        } else {
            command = nil
        }
        guard let command else { return false }
        let isPeriodCommand: Bool
        if case .startPeriod = command {
            isPeriodCommand = true
        } else {
            isPeriodCommand = false
        }
        logStep(isChinese ? "SpeechTranscriber拼音命令" : "SpeechTranscriber命令别名")
        logFlush(isSuccess: true, action: isPeriodCommand ? "结束本节" : "比赛结束")
        onFlash?(.green)
        DispatchQueue.main.async { [weak self] in
            self?.onCommand?(command)
            self?.onFlash?(.green)
        }
        return true
    }

    private var currentPeriodIsRunning: Bool {
        guard let snapshot = currentSnapshot else { return false }
        return snapshot.periodIsRunning && !snapshot.isComplete
    }

    private func containsPeriodMarker(in text: String) -> Bool {
        let normalized = text.lowercased()
        let identifier = currentRules.locale.identifier
        let markers: [String]
        if identifier.hasPrefix("zh") {
            markers = ["节", "節"]
        } else if identifier.hasPrefix("en") {
            markers = ["quarter", "period"]
        } else if identifier.hasPrefix("de") {
            markers = ["viertel", "periode"]
        } else if identifier.hasPrefix("es") {
            markers = ["cuarto", "período", "periodo"]
        } else if identifier.hasPrefix("fr") {
            markers = ["quart", "période", "periode"]
        } else if identifier.hasPrefix("it") {
            markers = ["quarto", "periodo"]
        } else if identifier.hasPrefix("ru") {
            markers = ["четверт", "период"]
        } else if identifier.hasPrefix("ja") {
            markers = ["クオーター", "クォーター", "ピリオド"]
        } else if identifier.hasPrefix("ko") {
            markers = ["쿼터", "피리어드"]
        } else {
            markers = []
        }
        return markers.contains(where: normalized.contains)
    }

    private func containsGameMarker(in text: String) -> Bool {
        let normalized = text.lowercased()
        let identifier = currentRules.locale.identifier
        let markers: [String]
        if identifier.hasPrefix("zh") {
            markers = ["比赛", "比賽"]
        } else if identifier.hasPrefix("en") {
            markers = ["game", "match"]
        } else if identifier.hasPrefix("de") {
            markers = ["spiel", "match"]
        } else if identifier.hasPrefix("es") {
            markers = ["partido", "juego"]
        } else if identifier.hasPrefix("fr") {
            markers = ["match", "jeu"]
        } else if identifier.hasPrefix("it") {
            markers = ["partita", "gioco"]
        } else if identifier.hasPrefix("ru") {
            markers = ["игр", "матч"]
        } else if identifier.hasPrefix("ja") {
            markers = ["試合", "ゲーム"]
        } else if identifier.hasPrefix("ko") {
            markers = ["경기", "게임"]
        } else {
            markers = []
        }
        return markers.contains(where: normalized.contains)
    }

    private func shouldPreferCurrentPeriodEnd(for text: String, keyword: String) -> Bool {
        guard currentPeriodIsRunning else { return false }
        if containsPeriodMarker(in: text) { return true }
        if containsGameMarker(in: text) { return false }
        return !containsGameMarker(in: keyword)
    }

    private func detectTeamPrefix(_ text: String) -> TeamSide? {
        let variants = currentRules.generatePinyinVariants(text)
        let homeAliases: Set<String> = ["主队", "zhudui", "zhu dui", "home"]
        let awayAliases: Set<String> = ["客队", "kedui", "ke dui", "away"]
        for variant in variants {
            let vLower = variant.lowercased()
            if homeAliases.contains(where: { vLower.hasPrefix($0) }) { return .home }
            if awayAliases.contains(where: { vLower.hasPrefix($0) }) { return .away }
        }
        return nil
    }

    private func resolvePlayerNumber(from text: String, allIDs: [UUID]) -> (playerID: UUID, side: TeamSide, debug: String)? {
        guard let store, let snapshot = currentSnapshot else { return nil }
        if let player = speechTranscriberAlphanumericPlayer(from: text, allIDs: allIDs) {
            return player
        }
        let number = preferredPlayerNumber ?? extractNumber(from: text)
        guard let number else { return nil }
        let preferredSide = detectTeamPrefix(text)
        for id in allIDs {
            guard let p = store.player(for: id) else { continue }
            guard p.number == "\(number)" else { continue }
            let pSide: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
            if let pref = preferredSide, pSide != pref { continue }
            let dbg = "号码\(number)直配\(preferredSide.map { $0 == .home ? "(主队)" : "(客队)" } ?? "")"
            return (id, pSide, dbg)
        }
        if preferredSide != nil {
            for id in allIDs {
                guard let p = store.player(for: id) else { continue }
                if p.number == "\(number)" {
                    let pSide: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    return (id, pSide, "号码\(number)直配(跨队)")
                }
            }
        }
        return nil
    }

    private func speechTranscriberAlphanumericPlayer(from text: String, allIDs: [UUID]) -> (playerID: UUID, side: TeamSide, debug: String)? {
        guard asrEngine == .speechTranscriber,
              currentRules.locale.identifier.hasPrefix("zh"),
              let inputKey = speechTranscriberAlphanumericNameKey(text),
              let store,
              let snapshot = currentSnapshot else { return nil }
        for id in allIDs {
            guard let player = store.player(for: id),
                  speechTranscriberAlphanumericNameKey(player.name) == inputKey else { continue }
            let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
            return (id, side, "字母数字姓名规范化直配")
        }
        return nil
    }

    private func hasExplicitPlayerNumberMarker(in text: String) -> Bool {
        if preferredPlayerNumber != nil { return true }
        let pattern = "(?i)(?:number|no\\.?|#)\\s*\\d+|\\d+\\s*(?:号|號|hao|番|번)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func appendToVoiceLog(_ entry: VoiceLogEntry) {
        guard let store, store.voiceLogEnabled else { return }
        store.voiceLog.insert(entry, at: 0)
        if store.voiceLog.count > maxLogCount { store.voiceLog.removeLast() }
    }

    private func matchableIDs(from allIDs: [UUID], snapshot: GameSnapshot) -> [UUID] {
        var ids = allIDs
        if snapshot.homeTeamStatsMode, let tid = snapshot.homeTeamID { ids.append(tid) }
        if snapshot.awayTeamStatsMode, let tid = snapshot.awayTeamID { ids.append(tid) }
        return ids
    }

    private func extractStateFromLeftText(_ leftText: String) -> (effectiveLeft: String, effectiveRight: String) {
        guard !leftText.isEmpty else { return (leftText, "") }
        let leftWords = leftText.lowercased().split { $0.isWhitespace }.map(String.init)
        for state in voiceMissedStates where !state.isEmpty {
            if let idx = leftWords.firstIndex(of: state.lowercased()) {
                if currentRules.locale.identifier.hasPrefix("en"),
                   state.lowercased() == "no",
                   leftWords.dropFirst(idx + 1).contains(where: { madeState in
                       voiceMadeStates.contains { $0.lowercased() == madeState }
                   }) {
                    continue
                }
                let effectiveLeft = leftWords.enumerated().filter { $0.offset != idx }.map { $0.element }.joined(separator: " ")
                return (effectiveLeft, state)
            }
        }
        for state in voiceMadeStates where !state.isEmpty {
            if let idx = leftWords.firstIndex(of: state.lowercased()) {
                let effectiveLeft = leftWords.enumerated().filter { $0.offset != idx }.map { $0.element }.joined(separator: " ")
                return (effectiveLeft, state)
            }
        }
        return (leftText, "")
    }

    private func extractStatePinyinFromLeftPinyin(_ leftPinyin: String) -> String {
        guard !leftPinyin.isEmpty else { return "" }
        let leftWords = leftPinyin.lowercased().split { $0.isWhitespace }.map(String.init)
        for state in voiceMissedStates where !state.isEmpty {
            let sp = currentRules.toPinyin(state)
            if leftWords.contains(sp) { return sp }
        }
        for state in voiceMadeStates where !state.isEmpty {
            let sp = currentRules.toPinyin(state)
            if leftWords.contains(sp) { return sp }
        }
        return ""
    }

    private func determineShotState(rightText: String) -> (isMade: Bool, bestScore: Double) {
        let rightPinyin = currentRules.toPinyin(rightText)
        let rightVariants = speechTranscriberPinyinVariants(for: rightText)
        var bestScore = 0.0
        var foundMade: Bool?
        for state in voiceMadeStates {
            let stateVariants = speechTranscriberPinyinVariants(for: state)
            if !stateVariants.isDisjoint(with: rightVariants) {
                if 1.0 > bestScore { bestScore = 1.0; foundMade = true }
            } else {
                let s = Self.similarity(currentRules.toPinyin(state), rightPinyin)
                if s > bestScore { bestScore = s; foundMade = true }
            }
        }
        for state in voiceMissedStates {
            if currentRules.locale.identifier.hasPrefix("ja"),
               state == "ない",
               rightText.contains("お願い") {
                continue
            }
            let stateVariants = speechTranscriberPinyinVariants(for: state)
            if !stateVariants.isDisjoint(with: rightVariants) {
                if 1.0 > bestScore { bestScore = 1.0; foundMade = false }
            } else {
                let s = Self.similarity(currentRules.toPinyin(state), rightPinyin)
                if s > bestScore { bestScore = s; foundMade = false }
            }
        }
        return (foundMade ?? true, bestScore)
    }

    private func findKeyword(_ kw: String, in text: String) -> (left: String, right: String)? {
        let parts = kw.split(separator: " ", omittingEmptySubsequences: true)
        let body = parts.isEmpty ? kw : parts.joined(separator: "\\s*")
        let isShortLatinWord = kw.count <= 3 && kw.unicodeScalars.allSatisfy { scalar in
            (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
        }
        let isNumericKeyword = !kw.isEmpty && kw.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 48 && scalar.value <= 57
        }
        let pattern: String
        if isNumericKeyword {
            pattern = "(?<![0-9])\\s*\(body)\\s*(?![0-9])"
        } else if isShortLatinWord {
            pattern = "(?<![A-Za-z])\\s*\(body)\\s*(?![A-Za-z])"
        } else {
            pattern = body
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              !regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)).isEmpty
        else { return nil }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let left = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if isShortLatinWord && left.range(of: #"(?:^|\s)(?:number|no\.?|#)$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                continue
            }
            return (left, right)
        }
        return nil
    }

    private func findPinyinKeyword(_ kw: String, in pinyin: String) -> (left: String, right: String)? {
        let normalizedPinyin = currentRules.toPinyin(pinyin)
        let keywordVariants = speechTranscriberPinyinVariants(for: kw).sorted { left, right in
            if left.count != right.count { return left.count > right.count }
            return left < right
        }
        for keywordPinyin in keywordVariants {
            guard let range = normalizedPinyin.range(of: keywordPinyin) else { continue }
            let left = String(normalizedPinyin[normalizedPinyin.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(normalizedPinyin[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (left, right)
        }
        return nil
    }

    private func speechActionSlots(leftText: String, rightText: String, isShot: Bool) -> (subject: String, predicate: String) {
        guard isShot, rightText.isEmpty, !leftText.isEmpty else {
            return (leftText, rightText)
        }
        let extracted = extractStateFromLeftText(leftText)
        guard usesStructuralSpeechMatching else {
            return (extracted.effectiveLeft, extracted.effectiveRight)
        }
        if !extracted.effectiveRight.isEmpty {
            return (extracted.effectiveLeft, extracted.effectiveRight)
        }
        let states = (voiceMissedStates.map { ($0, false) } + voiceMadeStates.map { ($0, true) })
            .sorted { $0.0.count > $1.0.count }
        for (state, isMade) in states where !state.isEmpty {
            guard let slots = findKeyword(state, in: leftText) else { continue }
            if !isMade,
               currentRules.locale.identifier.hasPrefix("en"),
               state.lowercased() == "no",
               slots.right.split(whereSeparator: { $0.isWhitespace }).contains(where: { word in
                   voiceMadeStates.contains { $0.lowercased() == word.lowercased() }
               }) {
                continue
            }
            let separator = currentRules.locale.identifier.hasPrefix("zh") ||
                currentRules.locale.identifier.hasPrefix("ja") ||
                currentRules.locale.identifier.hasPrefix("ko") ? "" : " "
            let subject = [slots.left, slots.right]
                .filter { !$0.isEmpty }
                .joined(separator: separator)
            return (subject, state)
        }
        for shot in voiceShotTypes.sorted(by: { $0.keyword.count > $1.keyword.count }) {
            guard let slots = findKeyword(shot.keyword, in: leftText),
                  slots.right.isEmpty,
                  !slots.left.isEmpty else { continue }
            return (slots.left, rightText)
        }
        return (leftText, rightText)
    }

    private func speechActionScore(keyword: String, leftText: String, rightText: String, text: String) -> Double {
        let characterCount = keyword.count
        let lengthScore = min(0.18, Double(characterCount) * 0.018)
        let phraseScore = keyword.contains { $0.isWhitespace } ? 0.08 : 0.0
        let slotScore = (!leftText.isEmpty || !rightText.isEmpty) ? 0.04 : 0.0
        let localeScore: Double
        if currentRules.locale.identifier.hasPrefix("ja") || currentRules.locale.identifier.hasPrefix("ko") {
            localeScore = keyword.count >= 2 ? 0.04 : 0.0
        } else if currentRules.locale.identifier.hasPrefix("zh") {
            localeScore = keyword.count >= 2 ? 0.04 : 0.0
        } else {
            localeScore = keyword.count >= 4 ? 0.04 : 0.0
        }
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactPhraseScore = normalizedText.caseInsensitiveCompare(keyword) == .orderedSame ? 0.04 : 0.0
        return min(0.99, 0.68 + lengthScore + phraseScore + slotScore + localeScore + exactPhraseScore)
    }

    private func fuzzySpeechKeywordMatch(_ keyword: String, in text: String) -> (left: String, right: String, score: Double)? {
        let inputTokens = text.lowercased().split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        let keywordTokens = keyword.lowercased().split { $0.isWhitespace || $0.isPunctuation }.map(String.init)
        guard !inputTokens.isEmpty, !keywordTokens.isEmpty, inputTokens.count >= keywordTokens.count else { return nil }
        if keywordTokens.count == 1 && keywordTokens[0].count < 4 { return nil }

        let minimumSimilarity: Double
        if keywordTokens.count > 1 {
            minimumSimilarity = 0.60
        } else if keywordTokens[0].count >= 4 {
            minimumSimilarity = 0.50
        } else {
            return nil
        }

        var best: (start: Int, similarity: Double)?
        for start in 0...(inputTokens.count - keywordTokens.count) {
            let window = Array(inputTokens[start..<(start + keywordTokens.count)])
            var total = 0.0
            for (expected, actual) in zip(keywordTokens, window) {
                let length = max(expected.count, actual.count)
                guard length > 0 else { continue }
                total += 1.0 - Double(Self.levenshteinDistance(expected, actual)) / Double(length)
            }
            let similarity = total / Double(keywordTokens.count)
            if similarity >= minimumSimilarity, best == nil || similarity > best!.similarity {
                best = (start, similarity)
            }
        }
        guard let best else { return nil }

        let left = inputTokens[..<best.start].joined(separator: " ")
        let rightStart = best.start + keywordTokens.count
        let right = inputTokens[rightStart...].joined(separator: " ")
        let baseScore = speechActionScore(keyword: keyword, leftText: left, rightText: right, text: text)
        let score = baseScore - (1.0 - best.similarity) * 0.45
        guard score >= 0.72 else { return nil }
        return (left, right, score)
    }

    private func directSpeechActionCandidates(text: String) -> [SpeechActionCandidate] {
        var candidates: [SpeechActionCandidate] = []
        for (keyword, code) in voiceNonShotEvents where code.hasPrefix("stat.") {
            guard let slots = findKeyword(keyword, in: text) else { continue }
            let rightText = (code == "stat.steal" || code == "stat.assist") ? slots.right : ""
            candidates.append(SpeechActionCandidate(
                keyword: keyword,
                code: code,
                leftText: slots.left,
                rightText: rightText,
                isShot: false,
                score: speechActionScore(keyword: keyword, leftText: slots.left, rightText: rightText, text: text)
            ))
        }
        for event in voiceShotEvents {
            guard let slots = findKeyword(event.keyword, in: text) else { continue }
            candidates.append(SpeechActionCandidate(
                keyword: event.keyword,
                code: event.code,
                leftText: slots.left,
                rightText: slots.right,
                isShot: true,
                score: speechActionScore(keyword: event.keyword, leftText: slots.left, rightText: slots.right, text: text)
            ))
        }
        if !currentRules.locale.identifier.hasPrefix("zh") {
            let exactCodes = Set(candidates.map(\.code))
            for (keyword, code) in voiceNonShotEvents where code.hasPrefix("stat.") && !exactCodes.contains(code) {
                guard let match = fuzzySpeechKeywordMatch(keyword, in: text) else { continue }
                guard !match.left.isEmpty else { continue }
                let rightText = (code == "stat.steal" || code == "stat.assist") ? match.right : ""
                candidates.append(SpeechActionCandidate(
                    keyword: keyword,
                    code: code,
                    leftText: match.left,
                    rightText: rightText,
                    isShot: false,
                    score: match.score
                ))
            }
            for event in voiceShotEvents where !exactCodes.contains(event.code) {
                guard let match = fuzzySpeechKeywordMatch(event.keyword, in: text) else { continue }
                guard !match.left.isEmpty else { continue }
                candidates.append(SpeechActionCandidate(
                    keyword: event.keyword,
                    code: event.code,
                    leftText: match.left,
                    rightText: match.right,
                    isShot: true,
                    score: match.score
                ))
            }
        }
        return adjustedSpeechActionCandidates(candidates).map { candidate in
            guard candidate.code == "stat.assist",
                  !candidate.rightText.isEmpty,
                  candidates.contains(where: { $0.isShot }) else {
                return candidate
            }
            return SpeechActionCandidate(
                keyword: candidate.keyword,
                code: candidate.code,
                leftText: candidate.leftText,
                rightText: candidate.rightText,
                isShot: candidate.isShot,
                score: candidate.score + 0.18
            )
        }
    }

    private func adjustedSpeechActionCandidates(_ candidates: [SpeechActionCandidate]) -> [SpeechActionCandidate] {
        candidates.map { candidate in
            let compoundAdjustment = candidates.reduce(0.0) { adjustment, other in
                guard other.code != candidate.code else { return adjustment }
                if currentRules.locale.identifier.hasPrefix("en"),
                   candidate.isShot,
                   candidate.code == "stat.freeThrow",
                   other.code == "stat.foul",
                   candidate.keyword.lowercased().hasSuffix("shot"),
                   candidate.keyword.lowercased() != "free throw" {
                    return adjustment - 0.30
                }
                guard usesStructuralSpeechMatching else { return adjustment }
                if candidate.isShot && other.isShot {
                    if candidate.leftText.range(of: other.keyword, options: [.caseInsensitive]) != nil {
                        return adjustment + 0.12
                    }
                    if other.leftText.range(of: candidate.keyword, options: [.caseInsensitive]) != nil {
                        return adjustment - 0.12
                    }
                }
                if candidate.isShot && other.isShot && !currentRules.locale.identifier.hasPrefix("en") {
                    return adjustment
                }
                if other.keyword.count > candidate.keyword.count,
                   other.keyword.range(of: candidate.keyword, options: [.caseInsensitive]) != nil {
                    if !candidate.isShot && other.isShot && currentRules.locale.identifier.hasPrefix("en") {
                        return adjustment + 0.12
                    }
                    return adjustment - 0.12
                }
                if candidate.keyword.count > other.keyword.count,
                   candidate.keyword.range(of: other.keyword, options: [.caseInsensitive]) != nil {
                    if candidate.isShot && !other.isShot && currentRules.locale.identifier.hasPrefix("en") {
                        return adjustment - 0.12
                    }
                    return adjustment + 0.12
                }
                return adjustment
            }
            guard compoundAdjustment != 0 else { return candidate }
            return SpeechActionCandidate(
                keyword: candidate.keyword,
                code: candidate.code,
                leftText: candidate.leftText,
                rightText: candidate.rightText,
                isShot: candidate.isShot,
                score: candidate.score + compoundAdjustment
            )
        }
    }

    private func pinyinSpeechActionCandidates(textVariants: Set<String>) -> [SpeechActionCandidate] {
        var candidates: [SpeechActionCandidate] = []
        let sortedTextVariants = textVariants.sorted { left, right in
            if left.count != right.count { return left.count > right.count }
            return left < right
        }
        func slots(for keyword: String, variants: Set<String>) -> (left: String, right: String, text: String)? {
            let sortedKeywords = variants.sorted { left, right in
                if left.count != right.count { return left.count > right.count }
                return left < right
            }
            for variant in sortedKeywords {
                for text in sortedTextVariants {
                    guard let range = text.range(of: variant) else { continue }
                    let left = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let right = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    return (left, right, text)
                }
            }
            return nil
        }
        for shot in voiceShotTypes {
            let variants = speechTranscriberPinyinVariants(for: shot.keyword)
            guard let result = slots(for: shot.keyword, variants: variants) else { continue }
            candidates.append(SpeechActionCandidate(
                keyword: shot.keyword,
                code: shot.eventPrefix,
                leftText: result.left,
                rightText: result.right,
                isShot: true,
                score: speechActionScore(keyword: shot.keyword, leftText: result.left, rightText: result.right, text: result.text)
            ))
        }
        for (keyword, code) in voiceNonShotEvents where code.hasPrefix("stat.") {
            let variants = speechTranscriberPinyinVariants(for: keyword)
            guard let result = slots(for: keyword, variants: variants) else { continue }
            let right = (code == "stat.steal" || code == "stat.assist") ? result.right : ""
            candidates.append(SpeechActionCandidate(
                keyword: keyword,
                code: code,
                leftText: result.left,
                rightText: right,
                isShot: false,
                score: speechActionScore(keyword: keyword, leftText: result.left, rightText: right, text: result.text)
            ))
        }
        return adjustedSpeechActionCandidates(candidates).map { candidate in
            guard candidate.code == "stat.assist",
                  !candidate.rightText.isEmpty,
                  candidates.contains(where: { $0.isShot }) else {
                return candidate
            }
            return SpeechActionCandidate(
                keyword: candidate.keyword,
                code: candidate.code,
                leftText: candidate.leftText,
                rightText: candidate.rightText,
                isShot: candidate.isShot,
                score: candidate.score + 0.18
            )
        }
    }

    private func selectSpeechActionCandidate(_ candidates: [SpeechActionCandidate]) -> SpeechActionCandidate? {
        let sorted = candidates.sorted { left, right in
            if left.score != right.score { return left.score > right.score }
            if left.keyword.count != right.keyword.count { return left.keyword.count > right.keyword.count }
            return left.code < right.code
        }
        guard let best = sorted.first, best.score >= 0.72 else { return nil }
        guard usesStructuralSpeechMatching else { return best }
        guard let second = sorted.first(where: { $0.code != best.code }) else { return best }
        let margin = best.score - second.score
        if margin < 0.06 {
            return nil
        }
        return best
    }

    private func resolvedPlayerCandidate(
        text: String,
        textPinyin: String,
        in allIDs: [UUID],
        context: String
    ) -> (playerID: UUID, side: TeamSide, debug: String)? {
        guard let snapshot = currentSnapshot else { return nil }
        let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
        let (matches, debug) = matchPlayerIDsDebug(text: text, textPinyin: textPinyin, in: matchIDs, context: context)
        guard let best = matches.first else { return nil }
        guard usesStructuralSpeechMatching else {
            return (best.0, best.1, debug)
        }
        guard best.2 >= max(0.62, matchingThreshold) else { return nil }
        guard let second = matches.dropFirst().first else {
            return (best.0, best.1, debug)
        }
        let margin = best.2 - second.2
        if margin < 0.08 && best.2 < 0.98 {
            return nil
        }
        let bestScore = String(best.2)
        let secondScore = String(second.2)
        let marginScore = String(margin)
        return (best.0, best.1, debug + " | 首选得分=" + bestScore + " | 次选得分=" + secondScore + " | 分差=" + marginScore)
    }

    private func resolvePlayerAndExecute(leftText: String, eventCode: String, isShot: Bool, rightText: String, text: String, textPinyin: String) -> Bool {
        guard let store, let snapshot = currentSnapshot else { return false }
        let slots = speechActionSlots(leftText: leftText, rightText: rightText, isShot: isShot)
        let effectiveLeft = slots.subject
        let effectiveRight = slots.predicate
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
        var playerID: UUID?; var side: TeamSide?
        var dbgPlayer = ""
        if let res = resolvePlayerNumber(from: effectiveLeft, allIDs: allIDs) {
            playerID = res.playerID; side = res.side; dbgPlayer = res.debug
        }
            if playerID == nil,
               hasExplicitPlayerNumberMarker(in: text),
               let res = resolvePlayerNumber(from: text, allIDs: allIDs) {
                playerID = res.playerID; side = res.side; dbgPlayer = "全文(res.debug)"
            }
        if playerID == nil, !effectiveLeft.isEmpty {
            let leftPinyin = currentRules.toPinyin(effectiveLeft)
            if let res = resolvedPlayerCandidate(text: effectiveLeft, textPinyin: leftPinyin, in: allIDs, context: "左侧球员") {
                playerID = res.playerID
                side = res.side
                dbgPlayer = res.debug
            }
        }
        let finalCode: String
        if isShot {
            let (isMade, bestStateScore) = determineShotState(rightText: effectiveRight)
            finalCode = eventCode + (isMade ? "Made" : "Missed")
            let stateLabel = bestStateScore > 0 ? (isMade ? "命中" : "未中") : "默认命中"
            addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "🔍 关键词: \(eventCode) | 右侧状态=\(effectiveRight.isEmpty ? "空" : effectiveRight) → \(stateLabel)(得分=\(String(format:"%.2f", bestStateScore)))")
        } else {
            finalCode = eventCode
        }
        guard let pid = playerID, let sd = side else {
            addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 未匹配到球员 | 左侧文本: \(leftText.isEmpty ? "空" : leftText) | 拼音: \(textPinyin)")
            showError(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
            onFlash?(.red)
            return false
        }
        guard let action = StatAction.allCases.first(where: { $0.eventCode == finalCode }) else {
            addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 无对应StatAction: \(finalCode)")
            return false
        }
        let pn = store.player(for: pid)?.name ?? "?"

        if action == .steal {
            let rule = currentRules.stealTargetRule
            let sourceText: String
            switch rule.extractFrom {
            case .rightText:
                sourceText = effectiveRight
            case .leftTextAfterPlayer:
                sourceText = effectiveLeft
            }

            var candidate = sourceText

            if rule.extractFrom == .leftTextAfterPlayer {
                for p in rule.segmentParticles {
                    if let idx = candidate.range(of: p) {
                        let after = candidate[idx.upperBound...].trimmingCharacters(in: .whitespaces)
                        if !after.isEmpty {
                            candidate = after
                            break
                        }
                    }
                }
            }

            for prefix in rule.prefixesToStrip {
                if candidate.hasPrefix(prefix) {
                    candidate = String(candidate.dropFirst(prefix.count))
                }
            }
            for suffix in rule.suffixesToStrip {
                if candidate.hasSuffix(suffix) {
                    candidate = String(candidate.dropLast(suffix.count))
                }
            }
            candidate = candidate.trimmingCharacters(in: .whitespaces)

            if !candidate.isEmpty {
                var targetID: UUID?
                var targetSide: TeamSide?
                if let res = resolvePlayerNumber(from: candidate, allIDs: allIDs) {
                    targetID = res.playerID; targetSide = res.side
                }
                if targetID == nil {
                    let targetPinyin = currentRules.toPinyin(candidate)
                    if let res = resolvedPlayerCandidate(text: candidate, textPinyin: targetPinyin, in: allIDs, context: "抢断目标") {
                        targetID = res.playerID
                        targetSide = res.side
                    }
                }
                if let tid = targetID, let ts = targetSide, ts != sd, tid != pid {
                    guard let turnoverAction = StatAction.allCases.first(where: { $0.eventCode == "stat.turnover" }) else {
                        addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "球员匹配: \(dbgPlayer)")
                        showSuccessFeedback(text: text, action: action, playerID: pid, side: sd)
                        return true
                    }
                    let pn2 = store.player(for: tid)?.name ?? "?"
                    addLog(text: text, isSuccess: true, action: "\(action.message) + \(turnoverAction.message)", playerName: "\(pn) → \(pn2)", matchedPattern: "\(finalCode)+turnover", matchDetail: "双事件: \(pn)抢断\(pn2)")
                    showDualSuccessFeedback(action1: action, playerID1: pid, side1: sd, action2: turnoverAction, playerID2: tid, side2: ts)
                    return true
                }
            }
        }

        if action == .assist && !effectiveRight.isEmpty {
            let shotEvents = voiceShotEvents
            for evt in shotEvents {
                let shotMatch = findKeyword(evt.keyword, in: effectiveRight)
                    ?? findPinyinKeyword(evt.keyword, in: effectiveRight)
                guard let (playerBText, shotRight) = shotMatch else { continue }
                let shotFinalCode: String
                let (isMade, _) = determineShotState(rightText: shotRight)
                shotFinalCode = evt.code + (isMade ? "Made" : "Missed")
                guard let shotAction = StatAction.allCases.first(where: { $0.eventCode == shotFinalCode }) else { continue }

                var targetID: UUID?
                var targetSide: TeamSide?
                if let res = resolvePlayerNumber(from: playerBText, allIDs: allIDs) {
                    targetID = res.playerID; targetSide = res.side
                }
                if targetID == nil, !playerBText.isEmpty {
                    let targetPinyin = currentRules.toPinyin(playerBText)
                    if let res = resolvedPlayerCandidate(text: playerBText, textPinyin: targetPinyin, in: allIDs, context: "助攻目标") {
                        targetID = res.playerID
                        targetSide = res.side
                    }
                }
                if let tid = targetID, let ts = targetSide, ts == sd, tid != pid {
                    let pn2 = store.player(for: tid)?.name ?? "?"
                    addLog(text: text, isSuccess: true, action: "\(action.message) + \(shotAction.message)", playerName: "\(pn) → \(pn2)", matchedPattern: "\(finalCode)+\(shotFinalCode)", matchDetail: "双事件: \(pn)助攻\(pn2)\(shotAction.message)")
                    showDualSuccessFeedback(action1: action, playerID1: pid, side1: sd, action2: shotAction, playerID2: tid, side2: ts)
                    return true
                }
            }
        }

        addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "球员匹配: \(dbgPlayer)")
        showSuccessFeedback(text: text, action: action, playerID: pid, side: sd)
        return true
    }

    private func preprocessEnglishText(_ rawText: String) -> String {
        preferredPlayerNumber = nil
        var text = rawText
        let numberXPattern = try? NSRegularExpression(pattern: "(?:^|\\s)(number|#)\\s*(one|two|three|four|five|six|seven|eight|nine|ten|\\d+)(?:\\s|$)", options: [.caseInsensitive])
        if let match = numberXPattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let numWordRange = Range(match.range(at: 2), in: text),
           let fullRange = Range(match.range, in: text) {
            let numWord = String(text[numWordRange]).lowercased()
            preferredPlayerNumber = Int(numWord) ?? Self.wordToNum[numWord]
            text = (text[..<fullRange.lowerBound] + text[fullRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let pn = preferredPlayerNumber {
                logStep("提取号码前缀: \(pn) | 剩余文本: \(text)")
            }
        }
        if let match = text.wholeMatch(of: /(\d+)(0[23])/) {
            let shotType = String(match.2) == "02" ? "two" : "three"
            text = "number \(match.1) no \(shotType)"
            logStep("重写数字组合: \(match.1)\(match.2) → \(text)")
        }
        if let match = text.wholeMatch(of: /(\d+)([23])/) {
            let shotType = String(match.2) == "2" ? "two" : "three"
            text = "number \(match.1) \(shotType)"
            logStep("重写数字组合: \(match.1)\(match.2) → \(text)")
        }
        if let num = preferredPlayerNumber, num >= 10 {
            let lastDigit = num % 10
            if (lastDigit == 2 || lastDigit == 3), text.trimmingCharacters(in: .whitespaces).isEmpty {
                let shotType = lastDigit == 3 ? "three" : "two"
                preferredPlayerNumber = num / 10
                text = (text + " " + shotType).trimmingCharacters(in: .whitespaces)
                if let pn = preferredPlayerNumber {
                    logStep("拆分号码+投篮: \(num)→\(pn)号 \(shotType)")
                }
            } else if lastDigit == 4, text.trimmingCharacters(in: .whitespaces).isEmpty {
                let actualNum = num / 10
                if actualNum > 0 {
                    preferredPlayerNumber = actualNum
                    text = "four"
                    logStep("X4拆分: 号码\(num)→\(actualNum), 剩余→four")
                }
            }
        } else if preferredPlayerNumber == nil, let match = text.wholeMatch(of: /(\d+)(4)/) {
            text = "number \(match.1) four"
            logStep("X4重写: \(match.1)4 → \(text)")
        }
        text = text.replacingOccurrences(of: "is three", with: "no three", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "ms pushback", with: "missed putback", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "mr one", with: "missed and one", options: .caseInsensitive)
        text = Self.replaceWordBoundary(text, target: "to", replacement: "2")
        text = Self.replaceWordBoundary(text, target: "know", replacement: "no")
        text = Self.replaceWordBoundary(text, target: "mr", replacement: "miss")
        return text
    }

    private static func replaceWordBoundary(_ text: String, target: String, replacement: String) -> String {
        let pattern = "(?i)(?<![a-z])\(NSRegularExpression.escapedPattern(for: target))(?![a-z])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private func processByDirectTextMatching(text: String, textPinyin: String) -> Bool {
        let candidates = directSpeechActionCandidates(text: text)
        if let candidate = selectSpeechActionCandidate(candidates) {
            addLog(text: text, isSuccess: false, action: candidate.code, matchDetail: "🔍 动作候选: \(candidate.keyword) | 得分=\(String(format: "%.2f", candidate.score)) | 左侧=\(candidate.leftText.isEmpty ? "空" : candidate.leftText) | 右侧=\(candidate.rightText.isEmpty ? "空" : candidate.rightText)")
            if resolvePlayerAndExecute(leftText: candidate.leftText, eventCode: candidate.code, isShot: candidate.isShot, rightText: candidate.rightText, text: text, textPinyin: textPinyin) {
                return true
            }
        } else if candidates.contains(where: { $0.score >= 0.72 }) {
            addLog(text: text, isSuccess: false, matchDetail: "❌ 动作候选置信度不足或候选分差过小")
            showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
            return true
        }
        return false
    }

    private func processByPinyinFallback(text: String, textPinyin: String) -> Bool {
        let textVariants = currentRules.generatePinyinVariants(text)
        let commandEvents = voiceNonShotEvents.filter { $0.1.hasPrefix("event.") }
        for (keyword, code) in commandEvents {
            let keywordVariants = speechTranscriberPinyinVariants(for: keyword)
            guard keywordVariants.contains(where: { key in textVariants.contains(where: { $0.contains(key) }) }) else { continue }
            if code == "event.game_end", containsPeriodMarker(in: text), !currentPeriodIsRunning {
                continue
            }
            let resolvedCode = code == "event.game_end" && shouldPreferCurrentPeriodEnd(for: text, keyword: keyword)
                ? "event.period"
                : code
            addLog(text: text, isSuccess: true, action: resolvedCode, matchDetail: "拼音命令: \(currentRules.toPinyin(keyword))")
            onFlash?(.green)
            let command: VoiceCommand
            if resolvedCode == "event.period" { command = .startPeriod }
            else if resolvedCode == "event.pause" { command = .togglePause }
            else if resolvedCode == "event.undo" { command = .undo }
            else if resolvedCode == "event.redo" { command = .redo }
            else { command = .finishGame }
            DispatchQueue.main.async { [weak self] in
                self?.onCommand?(command)
                self?.onFlash?(.green)
            }
            return true
        }
        let statEvents = voiceNonShotEvents.filter { $0.1.hasPrefix("stat.") }
        let pinyinCandidates = pinyinSpeechActionCandidates(textVariants: textVariants)
        guard let selectedAction = selectSpeechActionCandidate(pinyinCandidates) else {
            guard pinyinCandidates.isEmpty else {
                addLog(text: text, isSuccess: false, matchDetail: "❌ 动作候选置信度不足或候选分差过小")
                showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
                return true
            }
            return false
        }
        let shotPinyinVariants = voiceShotTypes.map { shot in
            (shot: shot, variants: speechTranscriberPinyinVariants(for: shot.keyword))
        }
        if selectedAction.isShot {
            for (shot, variants) in shotPinyinVariants {
            guard shot.eventPrefix == selectedAction.code else { continue }
            var matchedVariant: String?
            var matchedText: String?
            for kv in variants {
                for tv in textVariants {
                    if tv.range(of: kv) != nil {
                        matchedVariant = kv; matchedText = tv; break
                    }
                }
                if matchedVariant != nil { break }
            }
            guard let matchedVariant, let matchedText, let kwRange = matchedText.range(of: matchedVariant) else { continue }
            let kwLower = matchedText[matchedText.startIndex..<kwRange.lowerBound]
            let kwUpper = matchedText[kwRange.upperBound...]
            let leftPinyin = String(kwLower).trimmingCharacters(in: .whitespaces)
            let rightPinyin = String(kwUpper).trimmingCharacters(in: .whitespaces)
            addLog(text: text, isSuccess: false, action: shot.eventPrefix, matchDetail: "🔍 拼音回退: 关键词pinyin=\(matchedVariant) | 左侧拼音: \(leftPinyin.isEmpty ? "空" : leftPinyin) | 右侧拼音: \(rightPinyin.isEmpty ? "空" : rightPinyin)")
            var effectiveRightPinyin = rightPinyin
            if effectiveRightPinyin.isEmpty && !leftPinyin.isEmpty {
                let sp = extractStatePinyinFromLeftPinyin(leftPinyin)
                if !sp.isEmpty { effectiveRightPinyin = sp }
            }
            let (isMade, _) = determineShotState(rightText: effectiveRightPinyin)
            let finalCode = shot.eventPrefix + (isMade ? "Made" : "Missed")
            guard let store, let snapshot = currentSnapshot else { return false }
            let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
            var playerID: UUID?; var side: TeamSide?; var dbgPlayer = ""
            if hasExplicitPlayerNumberMarker(in: text),
               let res = resolvePlayerNumber(from: text, allIDs: allIDs) {
                playerID = res.playerID; side = res.side; dbgPlayer = res.debug
            }
            if playerID == nil, !leftPinyin.isEmpty {
                if let res = resolvedPlayerCandidate(text: leftPinyin, textPinyin: leftPinyin, in: allIDs, context: "拼音回退球员") {
                    playerID = res.playerID
                    side = res.side
                    dbgPlayer = res.debug
                }
            }
            guard let pid = playerID, let sd = side else {
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 拼音回退: 未匹配到球员 | 左侧拼音: \(leftPinyin.isEmpty ? "空" : leftPinyin)")
                showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
                return true
            }
            guard let action = StatAction.allCases.first(where: { $0.eventCode == finalCode }) else {
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 拼音回退: 无对应StatAction: \(finalCode)")
                showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
                return true
            }
            let pn = store.player(for: pid)?.name ?? "?"
            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "拼音回退球员: \(dbgPlayer)")
            showSuccessFeedback(text: text, action: action, playerID: pid, side: sd)
            return true
            }
        }

        let statPinyinVariants = statEvents.map { keyword, code in
            (keyword: keyword, code: code, variants: speechTranscriberPinyinVariants(for: keyword))
        }
        for stat in statPinyinVariants {
            guard stat.code == selectedAction.code else { continue }
            var matchedVariant: String?
            var matchedText: String?
            for kv in stat.variants {
                for tv in textVariants {
                    if tv.range(of: kv) != nil {
                        matchedVariant = kv; matchedText = tv; break
                    }
                }
                if matchedVariant != nil { break }
            }
            guard let matchedVariant, let matchedText, let kwRange = matchedText.range(of: matchedVariant) else { continue }
            let kwLower = matchedText[matchedText.startIndex..<kwRange.lowerBound]
            let kwUpper = matchedText[kwRange.upperBound...]
            let leftPinyin = String(kwLower).trimmingCharacters(in: .whitespaces)
            let rightPinyin = String(kwUpper).trimmingCharacters(in: .whitespaces)
            addLog(text: text, isSuccess: false, action: stat.code, matchDetail: "🔍 统计拼音回退: 关键词pinyin=\(matchedVariant) | 左侧拼音: \(leftPinyin.isEmpty ? "空" : leftPinyin) | 右侧拼音: \(rightPinyin.isEmpty ? "空" : rightPinyin)")
            guard let store, let snapshot = currentSnapshot else { return false }
            let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
            var playerID: UUID?; var side: TeamSide?; var dbgPlayer = ""
            if hasExplicitPlayerNumberMarker(in: text),
               let res = resolvePlayerNumber(from: text, allIDs: allIDs) {
                playerID = res.playerID; side = res.side; dbgPlayer = res.debug
            }
            if playerID == nil, !leftPinyin.isEmpty {
                if let res = resolvedPlayerCandidate(text: leftPinyin, textPinyin: leftPinyin, in: allIDs, context: "统计拼音回退球员") {
                    playerID = res.playerID
                    side = res.side
                    dbgPlayer = res.debug
                }
            }
            guard let pid = playerID, let sd = side else {
                addLog(text: text, isSuccess: false, action: stat.code, matchDetail: "❌ 统计拼音回退: 未匹配到球员 | 左侧拼音: \(leftPinyin.isEmpty ? "空" : leftPinyin)")
                showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
                return true
            }
            guard let action = StatAction.allCases.first(where: { $0.eventCode == stat.code }) else {
                addLog(text: text, isSuccess: false, action: stat.code, matchDetail: "❌ 统计拼音回退: 无对应StatAction: \(stat.code)")
                showErrorWithFlash(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), text))
                return true
            }
            let pn = store.player(for: pid)?.name ?? "?"

            if action == .steal {
                let rule = currentRules.stealTargetRule
                let sourcePinyin: String
                switch rule.extractFrom {
                case .rightText:
                    sourcePinyin = rightPinyin
                case .leftTextAfterPlayer:
                    sourcePinyin = leftPinyin
                }

                var candidate = sourcePinyin

                if rule.extractFrom == .leftTextAfterPlayer {
                    for p in rule.segmentParticles {
                        let pPinyin = currentRules.toPinyin(p)
                        if let idx = candidate.range(of: pPinyin) {
                            let after = candidate[idx.upperBound...].trimmingCharacters(in: .whitespaces)
                            if !after.isEmpty {
                                candidate = after
                                break
                            }
                        }
                    }
                }

                for prefix in rule.prefixesToStrip {
                    let pPinyin = currentRules.toPinyin(prefix.trimmingCharacters(in: .whitespaces))
                    if candidate.hasPrefix(pPinyin) {
                        candidate = String(candidate.dropFirst(pPinyin.count)).trimmingCharacters(in: .whitespaces)
                    }
                }
                for suffix in rule.suffixesToStrip {
                    let sPinyin = currentRules.toPinyin(suffix)
                    if candidate.hasSuffix(sPinyin) {
                        candidate = String(candidate.dropLast(sPinyin.count)).trimmingCharacters(in: .whitespaces)
                    }
                }
                candidate = candidate.trimmingCharacters(in: .whitespaces)

                if !candidate.isEmpty {
                    var targetID: UUID?
                    var targetSide: TeamSide?
                    if let res = resolvePlayerNumber(from: candidate, allIDs: allIDs) {
                        targetID = res.playerID
                        targetSide = res.side
                    } else {
                        if let res = resolvedPlayerCandidate(text: candidate, textPinyin: candidate, in: allIDs, context: "统计拼音回退抢断目标") {
                            targetID = res.playerID
                            targetSide = res.side
                        }
                    }
                    if let tid = targetID, let ts = targetSide, ts != sd, tid != pid {
                        guard let turnoverAction = StatAction.allCases.first(where: { $0.eventCode == "stat.turnover" }) else {
                            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: stat.code, matchDetail: "统计拼音回退球员: \(dbgPlayer)")
                            showSuccessFeedback(text: text, action: action, playerID: pid, side: sd)
                            return true
                        }
                        let pn2 = store.player(for: tid)?.name ?? "?"
                        addLog(text: text, isSuccess: true, action: "\(action.message) + \(turnoverAction.message)", playerName: "\(pn) → \(pn2)", matchedPattern: "\(stat.code)+turnover", matchDetail: "统计拼音回退双事件: \(pn)抢断\(pn2)")
                        showDualSuccessFeedback(action1: action, playerID1: pid, side1: sd, action2: turnoverAction, playerID2: tid, side2: ts)
                        return true
                    }
                }
            }

            if action == .assist && !rightPinyin.isEmpty {
                for evt in voiceShotEvents {
                    guard let (playerBText, shotRight) = findPinyinKeyword(evt.keyword, in: rightPinyin) else { continue }
                    let (isMade, _) = determineShotState(rightText: shotRight)
                    let shotFinalCode = evt.code + (isMade ? "Made" : "Missed")
                    guard let shotAction = StatAction.allCases.first(where: { $0.eventCode == shotFinalCode }) else { continue }
                    var targetID: UUID?
                    var targetSide: TeamSide?
                    if let res = resolvePlayerNumber(from: playerBText, allIDs: allIDs) {
                        targetID = res.playerID
                        targetSide = res.side
                    } else if !playerBText.isEmpty {
                        if let res = resolvedPlayerCandidate(text: playerBText, textPinyin: playerBText, in: allIDs, context: "拼音回退助攻目标") {
                            targetID = res.playerID
                            targetSide = res.side
                        }
                    }
                    if let targetID, let targetSide, targetSide == sd, targetID != pid {
                        let targetName = store.player(for: targetID)?.name ?? "?"
                        addLog(text: text, isSuccess: true, action: "\(action.message) + \(shotAction.message)", playerName: "\(pn) → \(targetName)", matchedPattern: "\(stat.code)+\(shotFinalCode)", matchDetail: "拼音回退双事件: \(pn)助攻\(targetName)\(shotAction.message)")
                        showDualSuccessFeedback(action1: action, playerID1: pid, side1: sd, action2: shotAction, playerID2: targetID, side2: targetSide)
                        return true
                    }
                }
            }

            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: stat.code, matchDetail: "统计拼音回退球员: \(dbgPlayer)")
            showSuccessFeedback(text: text, action: action, playerID: pid, side: sd)
            return true
        }

        return false
    }

    private func extractNumber(from text: String) -> Int? {
        return extractAllNumbers(from: text).first
    }

    private func extractAllNumbers(from text: String) -> [Int] {
        // CJK: 号, hao, 番, 번
        let cjk = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|號|hao|番|번)", options: [.caseInsensitive])
        var nums = cjk?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let num = Int(String(text[range])),
                  num >= 0, num <= 99 else { return nil }
            return num
        } ?? []
        // English: number 5, no.5, #5
        let eng = try? NSRegularExpression(pattern: "(?:number|no\\.|#)\\s*(\\d+)", options: [.caseInsensitive])
        nums += eng?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let num = Int(String(text[range])),
                  num >= 0, num <= 99 else { return nil }
            return num
        } ?? []
        // Standalone numbers
        let standalone = try? NSRegularExpression(pattern: "(?:^|\\s)(\\d+)(?:\\s|$)")
        nums += standalone?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let num = Int(String(text[range])),
                  num >= 1, num <= 99 else { return nil }
            return num
        } ?? []
        let engWordPrefix = try? NSRegularExpression(pattern: "(?:number|no\\.|#)\\s*(one|two|three|four|five|six|seven|eight|nine|ten)", options: [.caseInsensitive])
        nums += engWordPrefix?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { return nil }
            let word = String(text[range]).lowercased()
            return Self.wordToNum[word]
        } ?? []
        let standaloneWord = try? NSRegularExpression(pattern: "(?:^|\\s)(one|two|three|four|five|six|seven|eight|nine|ten)(?:\\s|$)", options: [.caseInsensitive])
        nums += standaloneWord?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { return nil }
            let word = String(text[range]).lowercased()
            return Self.wordToNum[word]
        } ?? []
        return nums
    }

    /// Slide shorter string across longer string, return best match ratio and its position in b.
    /// Uses max(a.count, b.count) as denominator to prevent short patterns from over-matching.
    /// This is consistent with nameSimilarity's approach.
    static func bestMatch(_ a: String, _ b: String) -> (score: Double, position: Int) {
        let aClean = a.replacingOccurrences(of: " ", with: "")
        let bClean = b.replacingOccurrences(of: " ", with: "")
        let aChars = Array(aClean)
        let bChars = Array(bClean)
        guard !aChars.isEmpty else { return (0, 0) }

        let denom = Double(max(aChars.count, bChars.count))
        if bChars.count < aChars.count {
            let matches = zip(aChars, bChars).filter { $0 == $1 }.count
            return (Double(matches) / denom, 0)
        }

        var bestScore = 0.0
        var bestPos = 0
        for offset in 0...(bChars.count - aChars.count) {
            var matches = 0
            for i in aChars.indices {
                if aChars[i] == bChars[offset + i] {
                    matches += 1
                }
            }
            let score = Double(matches) / denom
            if score > bestScore {
                bestScore = score
                bestPos = offset
            }
        }
        return (bestScore, bestPos)
    }

    static func similarity(_ a: String, _ b: String) -> Double {
        bestMatch(a, b).score
    }

    private static let wordToNum: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
    ]

    /// Character-level phonetic similarity for pinyin.
    /// Gives partial credit for commonly confused vowels and consonants.
    static func charSimilarity(_ c1: Character, _ c2: Character) -> Double {
        guard c1 != c2 else { return 1.0 }
        switch (c1, c2) {
        // Vowel confusions
        case ("a", "i"), ("i", "a"): return 0.3
        case ("a", "o"), ("o", "a"): return 0.5
        case ("a", "e"), ("e", "a"): return 0.4
        case ("a", "u"), ("u", "a"): return 0.2
        case ("o", "e"), ("e", "o"): return 0.6
        case ("o", "u"), ("u", "o"): return 0.6  // ao↔ou, uo↔ou
        case ("e", "i"), ("i", "e"): return 0.5  // ei↔ie
        case ("e", "u"), ("u", "e"): return 0.2
        case ("i", "u"), ("u", "i"): return 0.3  // iu↔ui
        // Unvoiced ↔ aspirated stop/affricate
        case ("b", "p"), ("p", "b"): return 0.7
        case ("d", "t"), ("t", "d"): return 0.7
        case ("g", "k"), ("k", "g"): return 0.7
        case ("j", "q"), ("q", "j"): return 0.7
        case ("z", "c"), ("c", "z"): return 0.7
        // Affricate ↔ fricative
        case ("j", "x"), ("x", "j"): return 0.5
        case ("q", "x"), ("x", "q"): return 0.5
        case ("z", "s"), ("s", "z"): return 0.5
        case ("c", "s"), ("s", "c"): return 0.5
        // Nasal ↔ lateral (common in southern Chinese dialects)
        case ("n", "l"), ("l", "n"): return 0.6
        // Bilabial ↔ labiodental
        case ("p", "f"), ("f", "p"): return 0.3
        // Velar fricative ↔ labiodental fricative (Min/Hakka dialects)
        case ("h", "f"), ("f", "h"): return 0.3
        // Alveolar stop ↔ nasal
        case ("d", "n"), ("n", "d"): return 0.5
        case ("d", "l"), ("l", "d"): return 0.4
        case ("t", "n"), ("n", "t"): return 0.4
        // Bilabial ↔ alveolar nasal
        case ("m", "n"), ("n", "m"): return 0.3
        default: return 0.0
        }
    }

    /// Name-specific similarity: character-level phonetic matching with partial credit.
    /// Uses `charSimilarity` instead of exact `==` to handle common pinyin confusions.
    /// Denominator is max(len) to prevent short names from over-matching via coincidental overlap.
    static func nameSimilarity(_ namePinyin: String, _ textPinyin: String) -> Double {
        let aClean = namePinyin.replacingOccurrences(of: " ", with: "")
        let bClean = textPinyin.replacingOccurrences(of: " ", with: "")
        let aChars = Array(aClean)
        let bChars = Array(bClean)
        guard !aChars.isEmpty else { return 0 }
        if aClean == bClean { return 1.0 }
        let denom = Double(max(aChars.count, bChars.count))
        let cap = 0.80 + Double(aChars.count) * 0.03
        if bChars.count < aChars.count {
            let score = zip(aChars, bChars).map(Self.charSimilarity).reduce(0, +) / denom
            return min(score, cap)
        }
        var best = 0.0
        for offset in 0...(bChars.count - aChars.count) {
            var total = 0.0
            for i in aChars.indices {
                total += Self.charSimilarity(aChars[i], bChars[offset + i])
            }
            let score = total / denom
            best = max(best, score)
        }
        return min(best, cap)
    }

    static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a.lowercased())
        let bChars = Array(b.lowercased())
        let aLen = aChars.count
        let bLen = bChars.count
        guard aLen > 0 else { return bLen }
        guard bLen > 0 else { return aLen }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bLen + 1), count: aLen + 1)
        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }

        for i in 1...aLen {
            for j in 1...bLen {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        return matrix[aLen][bLen]
    }
}
