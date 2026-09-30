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
    let matchDetail: String?
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
    private var speechTranscriberStopRequested = false
    private var speechTranscriberEngineStorage: AnyObject?

    @available(iOS 26.0, *)
    private var speechTranscriberEngine: SpeechTranscriberEngine {
        if let engine = speechTranscriberEngineStorage as? SpeechTranscriberEngine {
            return engine
        }
        let engine = SpeechTranscriberEngine()
        engine.onResult = { [weak self] text, alternatives, isFinal in
            guard let self, isFinal else { return }
            self.processSpeechTranscriberCandidates(primary: text, alternatives: alternatives)
        }
        engine.onError = { [weak self] error in
            self?.handleSpeechTranscriberError(error)
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
        let rules = VoiceRules.forLocale(locale)
        applyRules(rules)
        speechRecognizer = SFSpeechRecognizer(locale: rules.speechRecognizerLocale)
    }

    private func applyRules(_ rules: VoiceRules) {
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
        if currentRules.locale.identifier.hasPrefix("ja") || currentRules.locale.identifier.hasPrefix("ko") {
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
        }
    }

    func configureForFileEvaluation(store: AppStore, engine: VoiceASREngine = .speechTranscriber) {
        self.store = store
        asrEngine = engine
    }

    func updateASREngine(_ engine: VoiceASREngine) {
        asrEngine = engine.isAvailableOnCurrentOS ? engine : .legacySpeech
        if asrEngine == .legacySpeech {
            Task { [weak self] in
                await self?.prepareEngine()
            }
        }
    }

    private func prepareEngine() async -> Bool {
        guard !enginePrepared else { return true }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try await audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
            speechTranscriberStopRequested = true
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
        speechTranscriberStopRequested = false
        speechTranscriberStartTask?.cancel()
        let locale = currentRules.speechRecognizerLocale
        let contextualStrings = speechTranscriberContextualStrings()
        speechTranscriberStartTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await speechTranscriberEngine.start(locale: locale, contextualStrings: contextualStrings)
                if speechTranscriberStopRequested {
                    speechTranscriberEngine.requestStop()
                }
            } catch is CancellationError {
            } catch {
                isRecording = false
                showError(error.localizedDescription)
            }
        }
    }

    private func speechTranscriberContextualStrings() -> [String] {
        guard let store else { return currentRules.contextualStrings(playerNames: []) }
        let snapshotIDs = (currentSnapshot?.homeOnCourtPlayerIDs ?? [])
            + (currentSnapshot?.homeAvailablePlayerIDs ?? [])
            + (currentSnapshot?.awayOnCourtPlayerIDs ?? [])
            + (currentSnapshot?.awayAvailablePlayerIDs ?? [])
        let players = snapshotIDs.isEmpty ? store.players : snapshotIDs.compactMap { store.player(for: $0) }
        return currentRules.contextualStrings(
            playerNames: players.map(\.name),
            playerNumbers: players.map(\.number)
        )
    }

    private func processSpeechTranscriberCandidates(primary: String, alternatives: [String]) {
        var candidates = [primary]
        for alternative in alternatives where !alternative.isEmpty && !candidates.contains(alternative) {
            candidates.append(alternative)
        }
        let selected = candidates.max { left, right in
            speechTranscriberCandidateScore(left) < speechTranscriberCandidateScore(right)
        } ?? primary
        processText(selected)
    }

    private func speechTranscriberCandidateScore(_ text: String) -> Int {
        let normalized = normalizeSpeechTranscriberText(text).lowercased()
        guard !normalized.isEmpty else { return 0 }
        var score = 0
        let pinyinOnlyChinese = currentRules.locale.identifier.hasPrefix("zh") || currentRules.locale.identifier.hasPrefix("zh-Hant")
        let pinyinVariants = pinyinOnlyChinese ? Set([currentRules.toPinyin(normalized)]) : currentRules.generatePinyinVariants(normalized)
        for keyword in currentRules.shotKeywords.map(\.keyword) where normalized.contains(keyword.lowercased()) {
            score += 3
        }
        for keyword in currentRules.shotKeywords.map(\.keyword) where pinyinVariants.contains(where: { $0.contains(currentRules.toPinyin(keyword)) }) {
            score += 3
        }
        for keyword in currentRules.statEvents.map(\.keyword) where normalized.contains(keyword.lowercased()) {
            score += 3
        }
        for keyword in currentRules.statEvents.map(\.keyword) where pinyinVariants.contains(where: { $0.contains(currentRules.toPinyin(keyword)) }) {
            score += 3
        }
        for keyword in currentRules.commandEvents.map(\.keyword) where normalized.contains(keyword.lowercased()) {
            score += 3
        }
        for keyword in currentRules.commandEvents.map(\.keyword) where pinyinVariants.contains(where: { $0.contains(currentRules.toPinyin(keyword)) }) {
            score += 3
        }
        for keyword in currentRules.madeStates + currentRules.missedStates where normalized.contains(keyword.lowercased()) {
            score += 1
        }
        for player in store?.players ?? [] where normalized.contains(player.name.lowercased()) {
            score += 4
        }
        for player in store?.players ?? [] {
            let nameVariants = currentRules.namePinyinVariants(player.name)
            if nameVariants.contains(where: { name in pinyinVariants.contains(where: { $0.contains(name) }) }) {
                score += 4
            }
        }
        return score
    }

    private func handleSpeechTranscriberError(_ error: Error) {
        guard isRecording else { return }
        isRecording = false
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
                variants.append(String(characters.suffix(2)))
            }
            return variants
        }
        return []
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

                if asrEngine == .speechTranscriber {
                    let normalizedText = text.lowercased()
                    if let matchedVariant = localizedPlayerNameVariants(player.name).first(where: { normalizedText.contains($0.lowercased()) }) {
                        let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                        results.append((id, side, 0.98))
                        details.append("\(player.name)(本地发音别名:\(matchedVariant))")
                        continue
                    }
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

                // Priority 2: Variant pool matching (high confidence, avoids double fuzzy)
                let playerVariants = currentRules.generatePinyinVariants(player.name)
                if !userInputVariants.isDisjoint(with: playerVariants) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 0.95))
                    details.append("\(player.name)(变体匹配0.95)")
                    continue
                }

                // Priority 3: Variant pool with nameVariants (surname overrides, letter pinyin)
                let textVariants = currentRules.generatePinyinVariants(text)
                let nameVariants = currentRules.namePinyinVariants(player.name)
                var matched = false
                for variant in nameVariants {
                    let pv = currentRules.generatePinyinVariants(variant)
                    if !pv.isDisjoint(with: textVariants) {
                        let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                        results.append((id, side, 0.90))
                        details.append("\(player.name)(拼音变体0.90)")
                        matched = true
                        break
                    }
                }
                if !matched {
                    for variant in nameVariants {
                        let score = Self.nameSimilarity(variant, textPinyin)
                        if score >= matchingThreshold {
                            let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                            results.append((id, side, score))
                            details.append("\(player.name)(拼音相似\(String(format:"%.2f", score)))")
                            matched = true
                            break
                        }
                    }
                }
                if !matched {
                    let pinyin = currentRules.toPinyin(player.name)
                    let score = Self.nameSimilarity(pinyin, textPinyin)
                    details.append("\(player.name)(拼音=\(pinyin) vs \(textPinyin)=\(String(format:"%.2f", score)))")
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
                let teamVariants = currentRules.generatePinyinVariants(team.name)
                if !userInputVariants.isDisjoint(with: teamVariants) {
                    let side: TeamSide = isHome ? .home : .away
                    results.append((id, side, 0.95))
                    details.append("\(team.name)(球队变体匹配0.95)")
                    continue
                }

                // Priority 3: Variant pool with namePinyinVariants (fallback for team names)
                let textVariants = currentRules.generatePinyinVariants(text)
                let teamPV = currentRules.generatePinyinVariants(team.name)
                if !teamPV.isDisjoint(with: textVariants) {
                    let side: TeamSide = isHome ? .home : .away
                    results.append((id, side, 0.90))
                    details.append("\(team.name)(球队变体0.90)")
                    continue
                } else {
                    let teamPinyin = currentRules.toPinyin(team.name)
                    let score = Self.nameSimilarity(teamPinyin, textPinyin)
                    details.append("\(team.name)(球队拼音=\(teamPinyin) vs \(textPinyin)=\(String(format:"%.2f", score)))")
                }
            }
        }

        let sorted = results.sorted { a, b in
            if a.2 != b.2 { return a.2 > b.2 }
            let aName = store.player(for: a.0)?.name ?? store.team(for: a.0)?.name ?? ""
            let bName = store.player(for: b.0)?.name ?? store.team(for: b.0)?.name ?? ""
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
            let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
            let (matches, dbg) = matchPlayerIDsDebug(text: left, textPinyin: leftPinyin, in: matchIDs, context: "锚点左侧球员")
            dbgPlayer = dbg
            if let m = matches.first {
                playerID = m.0
                side = m.1
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
        let normalizedText = asrEngine == .speechTranscriber
            ? normalizeSpeechTranscriberText(text)
            : text
        let pinyinOnlyChinese = asrEngine == .speechTranscriber && (currentRules.locale.identifier.hasPrefix("zh") || currentRules.locale.identifier.hasPrefix("zh-Hant"))
        preferredPlayerNumber = nil
        logStart(normalizedText)
        let textPinyin = currentRules.toPinyin(normalizedText)
        logStep("原文: \(normalizedText) | 拼音: \(textPinyin)")

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
                    let (matches, _) = matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, in: allIDs, context: "自定义映射")
                    if let m = matches.first { pid = m.0; sd = m.1 }
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
        let processedText = currentRules.locale.identifier.hasPrefix("en") ? preprocessEnglishText(normalizedText) : normalizedText

        if !pinyinOnlyChinese, processAnchorMatch(processedText) { return }
        if !pinyinOnlyChinese, processByDirectTextMatching(text: processedText, textPinyin: textPinyin) { return }
        if processByPinyinFallback(text: processedText, textPinyin: textPinyin) { return }

        addLog(text: processedText, isSuccess: false, matchDetail: "❌ 全文无匹配: \(processedText) | 拼音: \(textPinyin)")
        showError(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), processedText))
        onFlash?(.red)
    }

    private func normalizeSpeechTranscriberText(_ text: String) -> String {
        var normalized = text.precomposedStringWithCanonicalMapping
        for punctuation in ["，", "。", "！", "？", "、", ",", ".", "!", "?", ";", "：", ":"] {
            normalized = normalized.replacingOccurrences(of: punctuation, with: " ")
        }
        normalized = compactSpeechTranscriberCJKWhitespace(normalized)
        normalized = normalizeSpeechTranscriberPlayerNumberWords(normalized)
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
            ("想乱", "抢断"),
            ("相乱", "抢断"),
            ("罰錢", "罰球"),
            ("闆", "板")
        ]
        for (source, replacement) in aliases {
            normalized = normalized.replacingOccurrences(of: source, with: replacement)
        }
        if currentRules.locale.identifier.hasPrefix("en") {
            let englishAliases: [(String, String)] = [
                ("got one", "got and one"),
                ("missed it one", "missed and one"),
                ("mystery throw", "missed free throw"),
                ("got paid", "got paint"),
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
                ("miss sugg", "missed dunk"),
                ("remound", "rebound"),
                ("time out", "timeout"),
                ("miss who", "missed two"),
                ("missed and won", "missed and one"),
                ("missing one", "missed and one"),
                ("offensive remount", "offensive rebound"),
                ("turned over", "turnover"),
                ("layoff", "layup"),
                ("pained", "paint"),
                ("pot back", "putback"),
                ("pushback", "putback"),
                ("dong", "dunk"),
                ("sunk", "dunk"),
                ("miss sun", "missed dunk"),
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
        } else if currentRules.locale.identifier.hasPrefix("zh-Hant") {
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
        } else if currentRules.locale.identifier.hasPrefix("ja") {
            normalized = normalized.replacingOccurrences(of: " ", with: "")
            normalized = normalized.replacingOccurrences(of: "ディフェンスリバウンド", with: "守備リバウンド")
            let japaneseAliases: [(String, String)] = [
                ("聖校", "成功"),
                ("通", "ツー"),
                ("害した", "外した"),
                ("製鋼", "成功"),
                ("メドル", "ミドル"),
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
                ("鈴木賞", "鈴木翔"),
                ("美作数", "美咲ツー"),
                ("美作", "美咲"),
                ("伊藤親", "伊藤葵"),
                ("異断苦", "ダンク"),
                ("ミドルセコ", "ミドル成功"),
                ("フェンスリバウンド", "オフェンスリバウンド"),
                ("リマウンド", "リバウンド"),
                ("スリマインド", "リバウンド"),
                ("スピール", "スティール"),
                ("アローバー", "ターンオーバー"),
                ("タイムラブと", "タイムアウト"),
                ("ハウル", "ファウル"),
                ("ファール", "ファウル"),
                ("ミドルシュート", "ミドル"),
                ("トーンオーバー", "ターンオーバー"),
                ("ターンオーバ", "ターンオーバー"),
                ("アシスト", "アシスト")
            ]
            for (source, replacement) in japaneseAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement)
            }
            normalized = normalized.replacingOccurrences(of: "守備リバウンド", with: "ディフェンスリバウンド")
            let japaneseNumberAliases: [(String, String)] = [
                ("日本版", "4番"),
                ("ネバーズ", "2番"),
                ("ネバ", "2番"),
                ("サンマン", "3番"),
                ("サンマ", "3番"),
                ("ロマンボ", "5番"),
                ("ロマン", "5番"),
                ("60000", "6番"),
                ("6000", "6番"),
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
        } else if currentRules.locale.identifier.hasPrefix("ko") {
            let koreanAliases: [(String, String)] = [
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
                ("미투", "미드"),
                ("레이 없습니까", "레이업 성공"),
                ("타임마웃", "타임아웃")
            ]
            for (source, replacement) in koreanAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement)
            }
            let koreanNumberAliases: [(String, String)] = [
                ("오 너 심해", "5번 보너스 실패"),
                ("실은 아유 수선공", "7번 자유투 성공"),
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
                normalized = replaceSpeechTranscriberRegex(
                    normalized,
                    pattern: "(?<![가-힣])\(source)(?![가-힣])",
                    template: replacement
                )
            }
            if normalized.contains("어시스트") {
                normalized = replaceSpeechTranscriberRegex(normalized, pattern: "([가-힣])3$", template: "$1 쓰리")
            }
        } else if currentRules.locale.identifier.hasPrefix("de") {
            let germanAliases: [(String, String)] = [
                ("wurde getroffen", "bonus getroffen"),
                ("muss getroffen", "bonus getroffen"),
                ("leib", "layup"),
                ("redund", "rebound"),
                ("redound", "rebound"),
                ("bund", "rebound"),
                ("dung", "dunk"),
                ("Fuhl", "foul"),
                ("Steice", "steal"),
                ("nummer ", "number ")
            ]
            for (source, replacement) in germanAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if currentRules.locale.identifier.hasPrefix("es") {
            let spanishAliases: [(String, String)] = [
                ("no se anotó", "anotó"),
                ("Aventura", "pintura"),
                ("Valistencia", "asistencia"),
                ("Futback", "putback"),
                ("Llevo muerto", "tiempo muerto"),
                ("del partido", "fin del partido"),
                ("Royaltair", "rehacer"),
                ("rayado", "bandeja"),
                ("valle", "mate"),
                ("metano", "mate"),
                ("pbak", "putback"),
                ("budback", "putback"),
                ("rebo", "rebote"),
                ("revolte", "rebote"),
                ("bloque", "bloqueo"),
                ("hallado", "fallado"),
                ("número ", "number "),
                ("numero ", "number ")
            ]
            for (source, replacement) in spanishAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if currentRules.locale.identifier.hasPrefix("fr") {
            let frenchAliases: [(String, String)] = [
                ("doit réussir", "deux réussi"),
                ("de rater", "deux raté"),
                ("L'air du bois de balle", "perte de balle"),
                ("putbach", "putback"),
                ("putba", "putback"),
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
        } else if currentRules.locale.identifier.hasPrefix("it") {
            let italianAliases: [(String, String)] = [
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
                ("cagliato", "sbagliato"),
                ("ostensivo", "offensivo"),
                ("numero ", "number ")
            ]
            for (source, replacement) in italianAliases {
                normalized = normalized.replacingOccurrences(of: source, with: replacement, options: .caseInsensitive)
            }
        } else if currentRules.locale.identifier.hasPrefix("ru") {
            let russianNumberAliases: [(String, String)] = [
                ("номер ", "number ")
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

    private func normalizeSpeechTranscriberPlayerNumberWords(_ text: String) -> String {
        var normalized = text
        let locale = currentRules.locale.identifier
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
            normalized = replaceSpeechTranscriberRegex(normalized, pattern: "(\\d+)\\s*분", template: "$1번")
        }
        return normalized
    }

    private func replaceSpeechTranscriberRegex(_ text: String, pattern: String, template: String) -> String {
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

    private func compactSpeechTranscriberCJKWhitespace(_ text: String) -> String {
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

    private static func isCJKCharacter(_ character: Character) -> Bool {
        isSpeechTranscriberNativeScriptCharacter(character)
    }

    private static func isSpeechTranscriberNativeScriptCharacter(_ character: Character) -> Bool {
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
        let command: VoiceCommand?
        if text == "结束" || text == "結束" || text == "结束比赛" || text == "結束比賽" || (isChinese && (pinyin.contains("jie shu") || pinyin.contains("bi sai jie shu"))) {
            command = .finishGame
        } else {
            command = nil
        }
        guard let command else { return false }
        logStep(isChinese ? "SpeechTranscriber拼音命令" : "SpeechTranscriber命令别名")
        logFlush(isSuccess: true, action: "比赛结束")
        onFlash?(.green)
        DispatchQueue.main.async { [weak self] in
            self?.onCommand?(command)
            self?.onFlash?(.green)
        }
        return true
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
                if asrEngine == .speechTranscriber,
                   currentRules.locale.identifier.hasPrefix("en"),
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
        let rightVariants = currentRules.generatePinyinVariants(rightText)
        var bestScore = 0.0
        var foundMade: Bool?
        for state in voiceMadeStates {
            let stateVariants = currentRules.generatePinyinVariants(state)
            if !stateVariants.isDisjoint(with: rightVariants) {
                if 1.0 > bestScore { bestScore = 1.0; foundMade = true }
            } else {
                let s = Self.similarity(currentRules.toPinyin(state), rightPinyin)
                if s > bestScore { bestScore = s; foundMade = true }
            }
        }
        for state in voiceMissedStates {
            let stateVariants = currentRules.generatePinyinVariants(state)
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
        let pattern = parts.isEmpty ? kw : parts.joined(separator: "\\s*")
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        else { return nil }
        guard let range = Range(match.range, in: text) else { return nil }
        let left = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (left, right)
    }

    private func findPinyinKeyword(_ kw: String, in pinyin: String) -> (left: String, right: String)? {
        let keywordPinyin = currentRules.toPinyin(kw)
        guard let range = pinyin.range(of: keywordPinyin) else { return nil }
        let left = String(pinyin[pinyin.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let right = String(pinyin[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (left, right)
    }

    private func resolvePlayerAndExecute(leftText: String, eventCode: String, isShot: Bool, rightText: String, text: String, textPinyin: String) -> Bool {
        guard let store, let snapshot = currentSnapshot else { return false }
        var effectiveLeft = leftText
        var effectiveRight = rightText
        if isShot && effectiveRight.isEmpty && !effectiveLeft.isEmpty {
            let result = extractStateFromLeftText(effectiveLeft)
            effectiveLeft = result.effectiveLeft
            effectiveRight = result.effectiveRight
        }
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
        var playerID: UUID?; var side: TeamSide?
        var dbgPlayer = ""
        if let res = resolvePlayerNumber(from: effectiveLeft, allIDs: allIDs) {
            playerID = res.playerID; side = res.side; dbgPlayer = res.debug
        }
        if playerID == nil, let res = resolvePlayerNumber(from: text, allIDs: allIDs) {
            playerID = res.playerID; side = res.side; dbgPlayer = "全文(res.debug)"
        }
        if playerID == nil, !effectiveLeft.isEmpty {
            let leftPinyin = currentRules.toPinyin(effectiveLeft)
                let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                let (matches, dbg) = matchPlayerIDsDebug(text: effectiveLeft, textPinyin: leftPinyin, in: matchIDs, context: "左侧球员")
            dbgPlayer = dbg
            if let m = matches.first {
                playerID = m.0; side = m.1
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
                    let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                    let (matches, _) = matchPlayerIDsDebug(text: candidate, textPinyin: targetPinyin, in: matchIDs, context: "抢断目标")
                    if let m = matches.first {
                        targetID = m.0; targetSide = m.1
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
                let shotMatch = currentRules.locale.identifier.hasPrefix("zh") || currentRules.locale.identifier.hasPrefix("zh-Hant")
                    ? findPinyinKeyword(evt.keyword, in: effectiveRight)
                    : findKeyword(evt.keyword, in: effectiveRight)
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
                    let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                    let (matches, _) = matchPlayerIDsDebug(text: playerBText, textPinyin: targetPinyin, in: matchIDs, context: "助攻目标")
                    if let m = matches.first {
                        targetID = m.0; targetSide = m.1
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
        let nonShotEvents = voiceNonShotEvents
        for (chinese, code) in nonShotEvents {
            guard code.hasPrefix("stat.") else { continue }
            if let (left, right) = findKeyword(chinese, in: text) {
                addLog(text: text, isSuccess: false, action: code, matchDetail: "🔍 找到关键词「\(chinese)」 | 左侧原文: \(left.isEmpty ? "空" : left) | 右侧原文: \(right.isEmpty ? "空" : right)")
                let rText = (code == "stat.steal" || code == "stat.assist") ? right : ""
                if resolvePlayerAndExecute(leftText: left, eventCode: code, isShot: false, rightText: rText, text: text, textPinyin: textPinyin) { return true }
            }
        }
        for (chinese, code) in nonShotEvents {
            guard code.hasPrefix("event.") else { continue }
            if findKeyword(chinese, in: text) != nil {
                addLog(text: text, isSuccess: true, action: code, matchDetail: "命令: \(chinese)")
                onFlash?(.green)
                let cmd: VoiceCommand
                if code == "event.period" { cmd = .startPeriod }
                else if code == "event.pause" { cmd = .togglePause }
                else if code == "event.undo" { cmd = .undo }
                else if code == "event.redo" { cmd = .redo }
                else { cmd = .finishGame }
                DispatchQueue.main.async { [weak self] in
                    self?.onCommand?(cmd)
                    self?.onFlash?(.green)
                }
                return true
            }
        }
        for evt in voiceShotEvents {
            if let (left, right) = findKeyword(evt.keyword, in: text) {
                addLog(text: text, isSuccess: false, action: evt.code, matchDetail: "🔍 找到关键词「\(evt.keyword)」 | 左侧原文: \(left.isEmpty ? "空" : left) | 右侧原文: \(right.isEmpty ? "空" : right)")
                if resolvePlayerAndExecute(leftText: left, eventCode: evt.code, isShot: true, rightText: right, text: text, textPinyin: textPinyin) { return true }
            }
        }
        return false
    }

    private func processByPinyinFallback(text: String, textPinyin: String) -> Bool {
        let pinyinOnlyChinese = asrEngine == .speechTranscriber && (currentRules.locale.identifier.hasPrefix("zh") || currentRules.locale.identifier.hasPrefix("zh-Hant"))
        let textVariants = pinyinOnlyChinese ? Set([textPinyin]) : currentRules.generatePinyinVariants(text)
        let commandEvents = voiceNonShotEvents.filter { $0.1.hasPrefix("event.") }
        for (keyword, code) in commandEvents {
            let keywordVariants = pinyinOnlyChinese ? Set([currentRules.toPinyin(keyword)]) : currentRules.generatePinyinVariants(keyword)
            guard keywordVariants.contains(where: { key in textVariants.contains(where: { $0.contains(key) }) }) else { continue }
            addLog(text: text, isSuccess: true, action: code, matchDetail: "拼音命令: \(currentRules.toPinyin(keyword))")
            onFlash?(.green)
            let command: VoiceCommand
            if code == "event.period" { command = .startPeriod }
            else if code == "event.pause" { command = .togglePause }
            else if code == "event.undo" { command = .undo }
            else if code == "event.redo" { command = .redo }
            else { command = .finishGame }
            DispatchQueue.main.async { [weak self] in
                self?.onCommand?(command)
                self?.onFlash?(.green)
            }
            return true
        }
        let statEvents = voiceNonShotEvents.filter { $0.1.hasPrefix("stat.") }
        let hasExactStatEvent = pinyinOnlyChinese && statEvents.contains { keyword, _ in
            textPinyin.contains(currentRules.toPinyin(keyword))
        }
        let shotPinyinVariants = voiceShotTypes.map { shot in
            (shot: shot, variants: pinyinOnlyChinese ? Set([currentRules.toPinyin(shot.keyword)]) : currentRules.generatePinyinVariants(shot.keyword))
        }
        if !hasExactStatEvent {
            for (shot, variants) in shotPinyinVariants {
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
            if let res = resolvePlayerNumber(from: text, allIDs: allIDs) {
                playerID = res.playerID; side = res.side; dbgPlayer = res.debug
            }
            if playerID == nil, !leftPinyin.isEmpty {
                let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                let (matches, dbg) = matchPlayerIDsDebug(text: leftPinyin, textPinyin: leftPinyin, in: matchIDs, context: "拼音回退球员")
                dbgPlayer = dbg
                if let m = matches.first {
                    playerID = m.0; side = m.1
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
            (keyword: keyword, code: code, variants: pinyinOnlyChinese ? Set([currentRules.toPinyin(keyword)]) : currentRules.generatePinyinVariants(keyword))
        }
        for stat in statPinyinVariants {
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
            if let res = resolvePlayerNumber(from: text, allIDs: allIDs) {
                playerID = res.playerID; side = res.side; dbgPlayer = res.debug
            }
            if playerID == nil, !leftPinyin.isEmpty {
                let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                let (matches, dbg) = matchPlayerIDsDebug(text: leftPinyin, textPinyin: leftPinyin, in: matchIDs, context: "统计拼音回退球员")
                dbgPlayer = dbg
                if let m = matches.first {
                    playerID = m.0; side = m.1
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
                    let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                    if let res = resolvePlayerNumber(from: candidate, allIDs: allIDs) {
                        targetID = res.playerID
                        targetSide = res.side
                    } else {
                        let (matches, _) = matchPlayerIDsDebug(text: candidate, textPinyin: candidate, in: matchIDs, context: "统计拼音回退抢断目标")
                        if let m = matches.first {
                            targetID = m.0
                            targetSide = m.1
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
                    let matchIDs = matchableIDs(from: allIDs, snapshot: snapshot)
                    var targetID: UUID?
                    var targetSide: TeamSide?
                    if let res = resolvePlayerNumber(from: playerBText, allIDs: allIDs) {
                        targetID = res.playerID
                        targetSide = res.side
                    } else if !playerBText.isEmpty {
                        let (matches, _) = matchPlayerIDsDebug(text: playerBText, textPinyin: playerBText, in: matchIDs, context: "拼音回退助攻目标")
                        if let match = matches.first {
                            targetID = match.0
                            targetSide = match.1
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
        let cjk = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|號|hao|番|번)")
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
