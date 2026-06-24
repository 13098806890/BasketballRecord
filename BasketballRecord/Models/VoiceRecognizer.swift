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

    override init() {
        let rules = VoiceRules.forCurrentAppLanguage()
        super.init()
        applyRules(rules)
        speechRecognizer = SFSpeechRecognizer(locale: rules.speechRecognizerLocale)
    }

    func updateRules(for locale: Locale) {
        let rules: VoiceRules
        switch locale.identifier {
        case let id where id.hasPrefix("en"): rules = .english
        case let id where id.hasPrefix("ja"): rules = .japanese
        case let id where id.hasPrefix("ko"): rules = .korean
        case let id where id.hasPrefix("de"): rules = .german
        case let id where id.hasPrefix("es"): rules = .spanish
        case let id where id.hasPrefix("fr"): rules = .french
        case let id where id.hasPrefix("it"): rules = .italian
        case let id where id.hasPrefix("ru"): rules = .russian
        case let id where id.hasPrefix("zh-Hant"): rules = .traditionalChinese
        default: rules = .chinese
        }
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
    }

    private var store: AppStore?
    var currentSnapshot: GameSnapshot? {
        didSet {
            rebuildNonShotEvents()
        }
    }
    var onAction: ((StatAction, UUID, TeamSide) -> Void)?
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
        prepareEngine()
    }

    private func prepareEngine() {
        guard !enginePrepared else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                print("[Voice] Invalid recording format: sampleRate=\(recordingFormat.sampleRate) channels=\(recordingFormat.channelCount)")
                return
            }
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            try audioEngine.start()
            enginePrepared = true
        } catch {
            print("[Voice] Engine prepare failed: \(error)")
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
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            showError(NSLocalizedString("voice_unavailable", comment: ""))
            return
        }

        isRecording = true
        prepareEngine()

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

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
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
        let entry = VoiceLogEntry(
            timestamp: Date(),
            text: logText,
            textPinyin: currentRules.toPinyin(logText),
            isSuccess: isSuccess,
            action: action ?? logAction,
            playerName: playerName ?? logPlayerName,
            matchedPattern: matchedPattern ?? logPattern,
            matchDetail: logBuffer
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
            matchDetail: matchDetail
        )
        appendToVoiceLog(entry)
    }

    // MARK: - Helper Methods for UI Feedback

    private func showSuccessFeedback(action: StatAction, playerID: UUID, side: TeamSide) {
        onFlash?(.green)
        onAction?(action, playerID, side)
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
                if text.lowercased().contains(nameLower) || nameLower.contains(text.lowercased()) {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, 1.0))
                    details.append("\(player.name)(直配1.0)")
                    continue
                }

                // Priority 1.5: Levenshtein distance for Latin-script names
                if currentRules.useLevenshteinMatching {
                    let dist = Self.levenshteinDistance(text, player.name)
                    let threshold = player.name.count < 4
                        ? currentRules.levenshteinThreshold.short
                        : currentRules.levenshteinThreshold.long
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
                if currentRules.useLevenshteinMatching {
                    let dist = Self.levenshteinDistance(text, team.name)
                    let threshold = team.name.count < 4
                        ? currentRules.levenshteinThreshold.short
                        : currentRules.levenshteinThreshold.long
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
        showSuccessFeedback(action: action, playerID: pid, side: sd)
        return true
    }

    func simulateText(_ text: String) {
        processText(text)
    }

    private func processText(_ text: String) {
        preferredPlayerNumber = nil
        logStart(text)
        let textPinyin = currentRules.toPinyin(text)
        logStep("原文: \(text) | 拼音: \(textPinyin)")

        if let mappings = store?.customVoiceMappings {
            for (phrase, eventCode) in mappings {
                guard let range = text.range(of: phrase, options: [.caseInsensitive]) else { continue }
                let action = StatAction.allCases.first(where: { $0.eventCode == eventCode })
                guard let store, let snapshot = currentSnapshot, let act = action else {
                    addLog(text: text, isSuccess: false, action: eventCode, matchDetail: "自定义映射无对应动作: \(phrase)")
                    return
                }
                let leftText = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
                var pid: UUID?; var sd: TeamSide?
                if let res = resolvePlayerNumber(from: leftText, allIDs: allIDs) { pid = res.playerID; sd = res.side }
                if pid == nil, !leftText.isEmpty {
                    let leftPinyin = currentRules.toPinyin(leftText)
                    let (matches, _) = matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, in: allIDs, context: "自定义映射")
                    if let m = matches.first { pid = m.0; sd = m.1 }
                }
                guard let playerID = pid, let side = sd else {
                    addLog(text: text, isSuccess: false, action: eventCode, matchDetail: "自定义映射无球员匹配: \(phrase)")
                    return
                }
                let pn = store.player(for: playerID)?.name ?? "?"
                addLog(text: text, isSuccess: true, action: act.message, playerName: pn, matchedPattern: eventCode, matchDetail: "自定义映射: \(phrase)")
                showSuccessFeedback(action: act, playerID: playerID, side: side)
                return
            }
        }

        if currentRules.substitutionKeywords.contains(where: { text.range(of: $0, options: [.caseInsensitive]) != nil }) {
            handleSubstitution(text: text, textPinyin: textPinyin)
            return
        }

        // Only preprocess English text for English locale
        let processedText = currentRules.locale.identifier.hasPrefix("en") ? preprocessEnglishText(text) : text

        if processAnchorMatch(processedText) { return }
        if processByDirectTextMatching(text: processedText, textPinyin: textPinyin) { return }
        if processByPinyinFallback(text: processedText, textPinyin: textPinyin) { return }

        addLog(text: processedText, isSuccess: false, matchDetail: "❌ 全文无匹配: \(processedText) | 拼音: \(textPinyin)")
        showError(String(format: NSLocalizedString("voice_unrecognized_format", comment: ""), processedText))
        onFlash?(.red)
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
                        showSuccessFeedback(action: action, playerID: pid, side: sd)
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
                guard let (playerBText, shotRight) = findKeyword(evt.keyword, in: effectiveRight) else { continue }
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
        showSuccessFeedback(action: action, playerID: pid, side: sd)
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
        let textVariants = currentRules.generatePinyinVariants(text)
        let shotPinyinVariants = voiceShotTypes.map { (shot: $0, variants: currentRules.generatePinyinVariants($0.keyword)) }
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
            showSuccessFeedback(action: action, playerID: pid, side: sd)
            return true
        }

        let statEvents = voiceNonShotEvents.filter { $0.1.hasPrefix("stat.") }
        let statPinyinVariants = statEvents.map { (keyword: $0.0, code: $0.1, variants: currentRules.generatePinyinVariants($0.0)) }
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
                    let (matches, _) = matchPlayerIDsDebug(text: candidate, textPinyin: candidate, in: matchIDs, context: "统计拼音回退抢断目标")
                    if let m = matches.first {
                        targetID = m.0; targetSide = m.1
                    }
                    if let tid = targetID, let ts = targetSide, ts != sd, tid != pid {
                        guard let turnoverAction = StatAction.allCases.first(where: { $0.eventCode == "stat.turnover" }) else {
                            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: stat.code, matchDetail: "统计拼音回退球员: \(dbgPlayer)")
                            showSuccessFeedback(action: action, playerID: pid, side: sd)
                            return true
                        }
                        let pn2 = store.player(for: tid)?.name ?? "?"
                        addLog(text: text, isSuccess: true, action: "\(action.message) + \(turnoverAction.message)", playerName: "\(pn) → \(pn2)", matchedPattern: "\(stat.code)+turnover", matchDetail: "统计拼音回退双事件: \(pn)抢断\(pn2)")
                        showDualSuccessFeedback(action1: action, playerID1: pid, side1: sd, action2: turnoverAction, playerID2: tid, side2: ts)
                        return true
                    }
                }
            }

            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: stat.code, matchDetail: "统计拼音回退球员: \(dbgPlayer)")
            showSuccessFeedback(action: action, playerID: pid, side: sd)
            return true
        }

        return false
    }

    private func extractNumber(from text: String) -> Int? {
        return extractAllNumbers(from: text).first
    }

    private func extractAllNumbers(from text: String) -> [Int] {
        // CJK: 号, hao, 番, 번
        let cjk = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|hao|番|번)")
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
