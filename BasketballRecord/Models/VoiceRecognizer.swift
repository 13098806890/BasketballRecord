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
    case substitution(outgoingID: UUID, incomingID: UUID, side: TeamSide)
}

@MainActor
final class VoiceRecognizer: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var match: (playerID: UUID, side: TeamSide, action: StatAction)?
    @Published var flashColor: Color?
    @Published var errorMessage: String?
    private let maxLogCount = 200
    /// Buffered log detail for the current recognition session.
    /// Accumulates all matching steps; flushed to store.voiceLog on completion or failure.
    private var logBuffer: String = ""
    private var logText: String = ""
    private var logIsSuccess = false
    private var logAction: String?
    private var logPlayerName: String?
    private var logPattern: String?

    /// Generate pinyin variants for a player name that may contain English letters/abbreviations.
    /// Only generates variants for multi-letter names (2-4 chars) to avoid short-name false matches.
    /// If `surnameOverrides` is provided, also generates variants with alternative surname readings.
    private static func namePinyinVariants(_ name: String, surnameOverrides: [Character: [String]] = [:]) -> [String] {
        let clean = Self.toPinyin(name)
        var variants = [clean]
        // For multi-letter English names, add letter-pinyin approximations
        let letters = name.lowercased().filter { $0.isLetter && $0.isASCII }
        if letters.count >= 2 && letters.count <= 4 {
            let letterPinyins = letters.map { Self.letterPinyin($0) }
            variants.append(letterPinyins.joined(separator: " "))
        }
        // Add surname pinyin overrides for polyphonic Chinese surnames
        if !surnameOverrides.isEmpty {
            let chars = Array(name)
            let syllables = clean.split(separator: " ").map(String.init)
            guard syllables.count == chars.count else { return variants }
            for (i, ch) in chars.enumerated() {
                guard let alternatives = surnameOverrides[ch] else { continue }
                for alt in alternatives {
                    var altSyllables = syllables
                    altSyllables[i] = alt
                    variants.append(altSyllables.joined(separator: " "))
                }
            }
        }
        return variants
    }

    /// Single-letter Chinese pronunciation approximation
    static func letterPinyin(_ ch: Character) -> String {
        switch ch {
        case "a": return "ei"; case "b": return "bo"; case "c": return "ci"
        case "d": return "di"; case "e": return "e"
        case "f": return "efu"; case "g": return "ji"; case "h": return "equ"
        case "i": return "ai"; case "j": return "jie"; case "k": return "ke"
        case "l": return "elou"; case "m": return "emu"; case "n": return "en"
        case "o": return "ou"; case "p": return "pi"; case "q": return "q"
        case "r": return "aer"; case "s": return "esi"; case "t": return "ti"
        case "u": return "you"; case "v": return "wei"; case "w": return "dabuliu"
        case "x": return "eks"; case "y": return "wai"; case "z": return "zei"
        default: return String(ch)
        }
    }

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
        voiceShotTypes = rules.shotKeywords.map { VoiceShotDef(keyword: $0.keyword, eventPrefix: $0.eventPrefix) }
        voiceMadeStates = rules.madeStates
        voiceMissedStates = rules.missedStates
    }

    private var store: AppStore?
    var currentSnapshot: GameSnapshot?
    var onAction: ((StatAction, UUID, TeamSide) -> Void)?
    var onCommand: ((VoiceCommand) -> Void)?
    var onSubstitution: ((TeamSide, UUID, UUID) -> Void)?

    var currentRules: VoiceRules = .chinese

    private struct VoiceShotDef {
        let keyword: String
        let eventPrefix: String
    }

    private var voiceShotTypes: [VoiceShotDef] = []
    private var voiceMadeStates: [String] = []
    private var voiceMissedStates: [String] = []

    func configure(store: AppStore) {
        self.store = store
        prepareEngine()
    }

    private func prepareEngine() {
        guard !enginePrepared else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
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
        errorMessage = nil
        match = nil
        flashColor = nil

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            SFSpeechRecognizer.requestAuthorization { _ in }
            showError("请在设置中允许语音识别")
            return
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            AVAudioApplication.requestRecordPermission { _ in }
            showError("请在设置中允许麦克风权限")
            return
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            showError("语音识别不可用")
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
        if logBuffer.isEmpty { logBuffer = msg }
        else { logBuffer += " | \(msg)" }
    }

    /// Finalize and persist the log entry with the accumulated buffer.
    private func logFlush(isSuccess: Bool, action: String? = nil, playerName: String? = nil, matchedPattern: String? = nil) {
        guard let store, store.voiceLogEnabled else { return }
        let entry = VoiceLogEntry(
            timestamp: Date(), text: logText,
            textPinyin: Self.toPinyin(logText),
            isSuccess: isSuccess, action: action ?? logAction,
            playerName: playerName ?? logPlayerName,
            matchedPattern: matchedPattern ?? logPattern,
            matchDetail: logBuffer
        )
        store.voiceLog.insert(entry, at: 0)
        if store.voiceLog.count > maxLogCount { store.voiceLog.removeLast() }
    }

    private func addLog(text: String, isSuccess: Bool, action: String? = nil, playerName: String? = nil, matchedPattern: String? = nil, matchDetail: String? = nil) {
        guard store?.voiceLogEnabled != false else { return }
        // If a log buffer is active, accumulate into the buffer.
        if !logText.isEmpty {
            if let detail = matchDetail { logStep(detail) }
            if action != nil { logAction = action }
            if playerName != nil { logPlayerName = playerName }
            logPattern = matchedPattern ?? logPattern
            logIsSuccess = logIsSuccess || isSuccess
            // Auto-flush on final result: success with action+player, or any ❌ failure terminator
            let isFailure = matchDetail?.hasPrefix("❌") == true || (!isSuccess && (matchDetail != nil || action != nil))
            if (isSuccess && action != nil && playerName != nil) || isFailure {
                logFlush(isSuccess: isSuccess, action: action, playerName: playerName, matchedPattern: matchedPattern)
            }
            return
        }
        guard let store else { return }
        let entry = VoiceLogEntry(
            timestamp: Date(), text: text,
            textPinyin: Self.toPinyin(text),
            isSuccess: isSuccess, action: action,
            playerName: playerName,
            matchedPattern: matchedPattern,
            matchDetail: matchDetail
        )
        store.voiceLog.insert(entry, at: 0)
        if store.voiceLog.count > maxLogCount { store.voiceLog.removeLast() }
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        Task {
            for _ in 0..<3 {
                await MainActor.run { impact.impactOccurred() }
                try? await Task.sleep(for: .seconds(0.08))
            }
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                if errorMessage == msg { errorMessage = nil }
            }
        }
    }

    private func matchPlayerIDs(from text: String, textPinyin: String, in allIDs: [UUID], context: String = "") -> [(UUID, TeamSide, Double)] {
        let (results, _) = matchPlayerIDsDebug(text: text, textPinyin: textPinyin, in: allIDs, context: context)
        return results
    }

    private func matchPlayerIDsDebug(text: String, textPinyin: String, in allIDs: [UUID], context: String = "") -> ([(UUID, TeamSide, Double)], String) {
        guard let store, let snapshot = currentSnapshot else { return ([], "\(context): store/snapshot=nil") }
        let threshold = 0.5
        var results: [(UUID, TeamSide, Double)] = []
        var details: [String] = []

        for id in allIDs {
            guard let player = store.player(for: id) else { continue }
            let nameLower = player.name.lowercased()
            // Direct text match
            if text.lowercased().contains(nameLower) || nameLower.contains(text.lowercased()) {
                let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                results.append((id, side, 1.0))
                details.append("\(player.name)(直配1.0)")
                continue
            }
            // Fuzzy pinyin match — try all pronunciation variants
            let fuzzyTP = Self.fuzzyPinyin(textPinyin)
            let nameVariants = Self.namePinyinVariants(player.name, surnameOverrides: currentRules.surnamePinyinOverrides)
            var matched = false
            for variant in nameVariants {
                let namePinyin = Self.fuzzyPinyin(variant)
                let score = Self.nameSimilarity(namePinyin, fuzzyTP)
                if score >= threshold {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, score))
                    details.append("\(player.name)(拼音\(String(format:"%.2f", score)))")
                    matched = true
                    break
                }
            }
            if !matched {
                let pinyin = Self.fuzzyPinyin(Self.toPinyin(player.name))
                let score = Self.nameSimilarity(pinyin, fuzzyTP)
                details.append("\(player.name)(拼音=\(pinyin) vs \(fuzzyTP)=\(String(format:"%.2f", score)))")
            }
        }

                let sorted = results.sorted { a, b in
            if a.2 != b.2 { return a.2 > b.2 }
            let aName = store.player(for: a.0)?.name ?? ""
            let bName = store.player(for: b.0)?.name ?? ""
            return aName.count > bName.count
        }

        let dbg = details.joined(separator: ", ")
        return (sorted, "\(context)[\(dbg)]")
    }

    private func handleSubstitution(text: String, textPinyin: String) {
        let _ = Self.fuzzyPinyin(textPinyin)
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
                        addLog(text: text, isSuccess: true, action: "换人", playerName: "\(p1)→\(p2)"); flashColor = .green
                        onSubstitution?(side, o, i); Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }; return
                    }
                }
            }
        }

        // Split by keyword: everything before = subject, everything after = object
        var subject = text, object = "", usedKw = ""
        for kw in currentRules.substitutionKeywords {
            if let range = text.range(of: kw) {
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
            showError("换人失败: 无主语/宾语"); flashColor = .red
            Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }; return
        }

        let subPinyin = Self.fuzzyPinyin(Self.toPinyin(subject))
        let objPinyin = Self.fuzzyPinyin(Self.toPinyin(object))

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
                    addLog(text: text, isSuccess: true, action: "换人", playerName: "\(outN)→\(inN)"); flashColor = .green
                    onSubstitution?(side, ot.0, it.0); Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }; return
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
                addLog(text: text, isSuccess: true, action: "换人", playerName: "\(outN)→\(inN)"); flashColor = .green
                onSubstitution?(sd, ot.0, it.0); Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }; return
            }
        }

        addLog(text: text, isSuccess: false, action: "换人", matchDetail: dbgLines.joined(separator: " | "))
        showError("换人失败"); flashColor = .red
        Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
    }

    func simulateText(_ text: String) {
        processText(text)
    }

    private func processText(_ text: String) {
        logStart(text)
        let textPinyin = Self.toPinyin(text)
        logStep("原文: \(text) | 拼音: \(textPinyin)")

        // Priority 1: Check custom voice mappings — contains-match, not exact dict lookup
        if let mappings = store?.customVoiceMappings {
            for (phrase, eventCode) in mappings {
                guard let range = text.range(of: phrase) else { continue }
                let action = StatAction.allCases.first(where: { $0.eventCode == eventCode })
                guard let store, let snapshot = currentSnapshot, let act = action else {
                    addLog(text: text, isSuccess: false, action: eventCode, matchDetail: "自定义映射无对应动作: \(phrase)")
                    return
                }
                let leftText = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
                let number = extractNumber(from: leftText)
                var pid: UUID?; var sd: TeamSide?
                if let number {
                    for id in allIDs {
                        guard let p = store.player(for: id) else { continue }
                        if p.number == "\(number)" { pid = id; sd = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away; break }
                    }
                }
                if pid == nil, !leftText.isEmpty {
                    let leftPinyin = Self.fuzzyPinyin(Self.toPinyin(leftText))
                    let (matches, _) = matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, in: allIDs, context: "自定义映射")
                    if let m = matches.first { pid = m.0; sd = m.1 }
                }
                guard let playerID = pid, let side = sd else {
                    addLog(text: text, isSuccess: false, action: eventCode, matchDetail: "自定义映射无球员匹配: \(phrase)")
                    return
                }
                let pn = store.player(for: playerID)?.name ?? "?"
                addLog(text: text, isSuccess: true, action: act.message, playerName: pn, matchedPattern: eventCode, matchDetail: "自定义映射: \(phrase)")
                let actCopy = act; let pidCopy = playerID; let sideCopy = side
                DispatchQueue.main.async { [self] in
                    match = (pidCopy, sideCopy, actCopy); flashColor = .green; onAction?(actCopy, pidCopy, sideCopy)
                }
                Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
                Task { try? await Task.sleep(for: .seconds(1.5)); await MainActor.run { if match?.playerID == pidCopy { match = nil } } }
                return
            }
        }

        // Pre-check for substitution
        if currentRules.substitutionKeywords.contains(where: { text.contains($0) }) {
            handleSubstitution(text: text, textPinyin: textPinyin)
            return
        }

        // Shot events
        var allEvents: [(keyword: String, chinese: String, code: String, isShot: Bool)] = []
        for shot in voiceShotTypes {
            allEvents.append((shot.keyword, shot.keyword, shot.eventPrefix, true))
        }

        // Non-shot events — from currentRules (no dedup, all variants preserved)
        var nonShotEvents: [(chinese: String, code: String)] = []
        for (keyword, code) in currentRules.statEvents {
            nonShotEvents.append((keyword, code))
        }
        for (keyword, code) in currentRules.commandEvents {
            nonShotEvents.append((keyword, code))
        }

        // Helper: find keyword in original Chinese text, split into [left, keyword, right]
        func findKeyword(_ kw: String) -> (left: String, right: String)? {
            guard let range = text.range(of: kw) else { return nil }
            let left = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (left, right)
        }

        // Helper: match player from left text, then execute action
        func resolvePlayer(leftText: String, eventCode: String, isShot: Bool, rightText: String) -> Bool {
            guard let store, let snapshot = currentSnapshot else { return false }

            let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
            var playerID: UUID?; var side: TeamSide?
            var dbgPlayer = ""

            let number = extractNumber(from: text)
            if let number {
                let preferredSide = detectTeamPrefix(text)
                for id in allIDs {
                    guard let p = store.player(for: id) else { continue }
                    guard p.number == "\(number)" else { continue }
                    let pSide: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    if let pref = preferredSide, pSide != pref { continue }
                    playerID = id; side = pSide
                    dbgPlayer = "号码\(number)直配\(preferredSide.map { $0 == .home ? "(主队)" : "(客队)" } ?? "")"
                    break
                }
                if playerID == nil, preferredSide != nil {
                    for id in allIDs {
                        guard let p = store.player(for: id) else { continue }
                        if p.number == "\(number)" {
                            playerID = id; side = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                            dbgPlayer = "号码\(number)直配(跨队)"
                            break
                        }
                    }
                }
            }

            if playerID == nil, !leftText.isEmpty {
                let leftPinyin = Self.fuzzyPinyin(Self.toPinyin(leftText))
                let (matches, dbg) = matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, in: allIDs, context: "左侧球员")
                dbgPlayer = dbg
                if let m = matches.first {
                    playerID = m.0; side = m.1
                }
            }

            // Determine made/missed for shots
            let finalCode: String
            if isShot {
                var bestStateScore = 0.0
                var foundMade: Bool?
                for state in voiceMadeStates {
                    let sp = Self.fuzzyPinyin(Self.toPinyin(state))
                    let s = Self.similarity(sp, Self.fuzzyPinyin(Self.toPinyin(rightText)))
                    if s > bestStateScore { bestStateScore = s; foundMade = true }
                }
                for state in voiceMissedStates {
                    let sp = Self.fuzzyPinyin(Self.toPinyin(state))
                    let s = Self.similarity(sp, Self.fuzzyPinyin(Self.toPinyin(rightText)))
                    if s > bestStateScore { bestStateScore = s; foundMade = false }
                }
                let isMade = foundMade ?? true
                finalCode = eventCode + (isMade ? "Made" : "Missed")

                // Log state matching
                let stateLabel = foundMade.map { $0 ? "命中" : "未中" } ?? "默认命中"
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "🔍 关键词: \(eventCode) | 右侧状态=\(rightText.isEmpty ? "空" : rightText) → \(stateLabel)(得分=\(String(format:"%.2f", bestStateScore)))")
            } else {
                finalCode = eventCode
            }

            guard let pid = playerID, let sd = side else {
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 未匹配到球员 | 左侧文本: \(leftText.isEmpty ? "空" : leftText) | 拼音: \(textPinyin)")
                showError("未识别：\"\(text)\""); flashColor = .red
                Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
                return false
            }

            guard let action = StatAction.allCases.first(where: { $0.eventCode == finalCode }) else {
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 无对应StatAction: \(finalCode)"); return false
            }

            let pn = store.player(for: pid)?.name ?? "?"
            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "球员匹配: \(dbgPlayer)")
            let actCopy = action; let pidCopy = pid; let sideCopy = sd
            DispatchQueue.main.async { [self] in
                match = (pidCopy, sideCopy, actCopy); flashColor = .green; onAction?(actCopy, pidCopy, sideCopy)
            }
            Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
            Task { try? await Task.sleep(for: .seconds(1.5)); await MainActor.run { if match?.playerID == pidCopy { match = nil } } }
            return true
        }

        // 1) Try shot keywords first — direct text match
        for evt in allEvents {
            if let (left, right) = findKeyword(evt.keyword) {
                addLog(text: text, isSuccess: false, action: evt.code, matchDetail: "🔍 找到关键词「\(evt.keyword)」 | 左侧原文: \(left.isEmpty ? "空" : left) | 右侧原文: \(right.isEmpty ? "空" : right)")
                if resolvePlayer(leftText: left, eventCode: evt.code, isShot: true, rightText: right) { return }
            }
        }

        // 1b) Pinyin fallback for shot events — handles ASR pinyin output or misrecognized characters
        let textFuzzy = Self.fuzzyPinyin(Self.toPinyin(text))
        for shot in voiceShotTypes {
            let shotPinyin = Self.fuzzyPinyin(Self.toPinyin(shot.keyword))
            guard let kwRange = textFuzzy.range(of: shotPinyin) else { continue }
            let leftPinyin = String(textFuzzy[textFuzzy.startIndex..<kwRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rightPinyin = String(textFuzzy[kwRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            addLog(text: text, isSuccess: false, action: shot.eventPrefix, matchDetail: "🔍 拼音回退: 关键词pinyin=\(shotPinyin) | 左侧拼音: \(leftPinyin.isEmpty ? "空" : leftPinyin) | 右侧拼音: \(rightPinyin.isEmpty ? "空" : rightPinyin)")
            var bestStateScore = 0.0
            var foundMade: Bool?
            for state in voiceMadeStates {
                let statePinyin = Self.fuzzyPinyin(Self.toPinyin(state))
                let s = Self.similarity(rightPinyin, statePinyin)
                if s > bestStateScore { bestStateScore = s; foundMade = true }
            }
            for state in voiceMissedStates {
                let statePinyin = Self.fuzzyPinyin(Self.toPinyin(state))
                let s = Self.similarity(rightPinyin, statePinyin)
                if s > bestStateScore { bestStateScore = s; foundMade = false }
            }
            guard let isMade = foundMade else { continue }
            let finalCode = shot.eventPrefix + (isMade ? "Made" : "Missed")
            guard let store, let snapshot = currentSnapshot else { return }
            let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
            var playerID: UUID?; var side: TeamSide?; var dbgPlayer = ""
            let number = extractNumber(from: text)
            if let number {
                let preferredSide = detectTeamPrefix(text)
                for id in allIDs {
                    guard let p = store.player(for: id) else { continue }
                    guard p.number == "\(number)" else { continue }
                    let pSide: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    if let pref = preferredSide, pSide != pref { continue }
                    playerID = id; side = pSide
                    dbgPlayer = "号码\(number)直配\(preferredSide.map { $0 == .home ? "(主队)" : "(客队)" } ?? "")"
                    break
                }
                if playerID == nil, preferredSide != nil {
                    for id in allIDs {
                        guard let p = store.player(for: id) else { continue }
                        if p.number == "\(number)" {
                            playerID = id; side = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                            dbgPlayer = "号码\(number)直配(跨队)"
                            break
                        }
                    }
                }
            }
            if playerID == nil, !leftPinyin.isEmpty {
                let (matches, dbg) = matchPlayerIDsDebug(text: leftPinyin, textPinyin: leftPinyin, in: allIDs, context: "拼音回退球员")
                dbgPlayer = dbg
                if let m = matches.first {
                    playerID = m.0; side = m.1
                }
            }
            guard let pid = playerID, let sd = side else {
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 拼音回退: 未匹配到球员 | 左侧拼音: \(leftPinyin.isEmpty ? "空" : leftPinyin)")
                showError("未识别：\"\(text)\""); flashColor = .red
                Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
                return
            }
            guard let action = StatAction.allCases.first(where: { $0.eventCode == finalCode }) else {
                addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 拼音回退: 无对应StatAction: \(finalCode)")
                showError("未识别：\"\(text)\""); flashColor = .red
                Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
                return
            }
            let pn = store.player(for: pid)?.name ?? "?"
            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "拼音回退球员: \(dbgPlayer)")
            let actCopy = action; let pidCopy = pid; let sideCopy = sd
            DispatchQueue.main.async { [self] in
                match = (pidCopy, sideCopy, actCopy); flashColor = .green; onAction?(actCopy, pidCopy, sideCopy)
            }
            Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
            Task { try? await Task.sleep(for: .seconds(1.5)); await MainActor.run { if match?.playerID == pidCopy { match = nil } } }
            return
        }

        // 2) Non-shot events — direct text match
        for (chinese, code) in nonShotEvents {
            guard code.hasPrefix("stat.") else { continue } // skip commands
            if let (left, _) = findKeyword(chinese) {
                addLog(text: text, isSuccess: false, action: code, matchDetail: "🔍 找到关键词「\(chinese)」 | 左侧原文: \(left.isEmpty ? "空" : left)")
                if resolvePlayer(leftText: left, eventCode: code, isShot: false, rightText: "") { return }
            }
        }

        // 3) Command events — no player needed
        for (chinese, code) in nonShotEvents {
            guard code.hasPrefix("event.") else { continue }
            if findKeyword(chinese) != nil {
                addLog(text: text, isSuccess: true, action: code, matchDetail: "命令: \(chinese)")
                flashColor = .green
                let cmd: VoiceCommand
                if code == "event.period" { cmd = .startPeriod }
                else if code == "event.pause" { cmd = .togglePause }
                else { cmd = .finishGame }
                let cmdCopy = cmd
                DispatchQueue.main.async { [self] in onCommand?(cmdCopy); flashColor = .green }
                Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
                return
            }
        }

        addLog(text: text, isSuccess: false, matchDetail: "❌ 全文无匹配: \(text) | 拼音: \(textPinyin)")
        showError("未识别：\"\(text)\""); flashColor = .red
        Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
    }

    /// Detect team prefix in text: "主队", "客队" or their pinyin
    private func detectTeamPrefix(_ text: String) -> TeamSide? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.hasPrefix("主队") || lower.hasPrefix("zhudui") || lower.hasPrefix("zhu dui") { return .home }
        if lower.hasPrefix("客队") || lower.hasPrefix("kedui") || lower.hasPrefix("ke dui") { return .away }
        // English variants
        if lower.hasPrefix("home") { return .home }
        if lower.hasPrefix("away") { return .away }
        return nil
    }

    private func extractNumber(from text: String) -> Int? {
        // Try CJK patterns: 号, hao, 番, 번
        let cjk = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|hao|番|번)")
        if let match = cjk?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        }
        // Try English patterns: number 5, no.5, #5
        let eng = try? NSRegularExpression(pattern: "(?:number|no\\.?|#)\\s*(\\d+)", options: [.caseInsensitive])
        if let match = eng?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        }
        // Try standalone number at word boundary
        let standalone = try? NSRegularExpression(pattern: "(?:^|\\s)(\\d+)(?:\\s|$)")
        if let match = standalone?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 1, num <= 99 else { return nil }
            return num
        }
        return nil
    }

    private func extractAllNumbers(from text: String) -> [Int] {
        // CJK: 号, hao, 番, 번
        let cjk = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|hao|番|번)")
        var nums = cjk?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        } ?? []
        // English: number 5, no.5, #5
        let eng = try? NSRegularExpression(pattern: "(?:number|no\\.?|#)\\s*(\\d+)", options: [.caseInsensitive])
        nums += eng?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        } ?? []
        // Standalone numbers
        let standalone = try? NSRegularExpression(pattern: "(?:^|\\s)(\\d+)(?:\\s|$)")
        nums += standalone?.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> Int? in
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 1, num <= 99 else { return nil }
            return num
        } ?? []
        return nums
    }

    private func containsNumberKeyword(_ text: String) -> Bool {
        text.contains("号") || text.contains("hao") || text.contains("番") || text.contains("번")
    }

    static func toPinyin(_ s: String) -> String {
        let mutable = NSMutableString(string: s) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String).lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Apply fuzzy pinyin normalization to handle common Chinese pronunciation confusions.
    /// Operates on space-separated pinyin syllables to avoid corrupting syllable boundaries.
    static func fuzzyPinyin(_ s: String) -> String {
        let syllables = s.split(separator: " ").map { String($0) }
        let fuzzyMap: [(String, String)] = [
            ("zh", "z"), ("ch", "c"), ("sh", "s"),
            ("r", "l"),
            ("eng", "en"), ("ing", "in"), ("ang", "an"),
        ]
        return syllables.map { syl in
            var r = syl
            for (a, b) in fuzzyMap {
                r = r.replacingOccurrences(of: a, with: b)
            }
            return r
        }.joined(separator: " ")
    }

    /// Slide shorter string across longer string, return best match ratio and its position in b.
    /// Uses (a.count + b.count) / 2 as denominator (arithmetic mean of both lengths).
    /// This biases against short-pattern-high-score while still allowing short names to match.
    static func bestMatch(_ a: String, _ b: String) -> (score: Double, position: Int) {
        let aClean = a.replacingOccurrences(of: " ", with: "")
        let bClean = b.replacingOccurrences(of: " ", with: "")
        let aChars = Array(aClean)
        let bChars = Array(bClean)
        guard !aChars.isEmpty else { return (0, 0) }

        let denom = Double(aChars.count + bChars.count) / 2.0
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

    /// Character-level phonetic similarity for pinyin.
    /// Gives partial credit for commonly confused vowels and consonants.
    static func charSimilarity(_ c1: Character, _ c2: Character) -> Double {
        guard c1 != c2 else { return 1.0 }
        switch (c1, c2) {
        // Vowel confusions
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
}
