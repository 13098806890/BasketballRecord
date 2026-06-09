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

    /// Generate pinyin variants for a player name that may contain English letters/abbreviations.
    /// Only generates variants for multi-letter names (2-4 chars) to avoid short-name false matches.
    private static func namePinyinVariants(_ name: String) -> [String] {
        let clean = Self.toPinyin(name)
        var variants = [clean]
        // For multi-letter English names, add letter-pinyin approximations
        let letters = name.lowercased().filter { $0.isLetter && $0.isASCII }
        if letters.count >= 2 && letters.count <= 4 {
            let letterPinyins = letters.map { Self.letterPinyin($0) }
            variants.append(letterPinyins.joined(separator: " "))
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

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    private var recognitionTask: SFSpeechRecognitionTask?

    private var store: AppStore?
    var currentSnapshot: GameSnapshot?
    var onAction: ((StatAction, UUID, TeamSide) -> Void)?
    var onCommand: ((VoiceCommand) -> Void)?
    var onSubstitution: ((TeamSide, UUID, UUID) -> Void)?

    private struct VoiceShotDef {
        let keyword: String
        let eventPrefix: String
    }

    private let voiceShotTypes: [VoiceShotDef] = [
        .init(keyword: "两分", eventPrefix: "stat.two"),
        .init(keyword: "2分", eventPrefix: "stat.two"),
        .init(keyword: "三分", eventPrefix: "stat.three"),
        .init(keyword: "3分", eventPrefix: "stat.three"),
        .init(keyword: "上篮", eventPrefix: "stat.layup"),
        .init(keyword: "中投", eventPrefix: "stat.midRange"),
        .init(keyword: "中距离", eventPrefix: "stat.midRange"),
        .init(keyword: "篮下", eventPrefix: "stat.paint"),
        .init(keyword: "内线", eventPrefix: "stat.paint"),
        .init(keyword: "罚球", eventPrefix: "stat.freeThrow"),
        .init(keyword: "罚篮", eventPrefix: "stat.freeThrow"),
        .init(keyword: "加罚", eventPrefix: "stat.bonus"),
    ]

    private let voiceMadeStates = ["命中", "进", "得分", "成功"]
    private let voiceMissedStates = ["未中", "没中", "不中", "不进", "没进", "打铁"]

    private lazy var pinyinPatterns: [(pinyin: String, chinese: String, eventCode: String)] = {
        var results: [(String, String, String)] = []

        // Cartesian product: shot type × made/missed state
        for shot in voiceShotTypes {
            for state in voiceMadeStates {
                let chinese = shot.keyword + state
                results.append((Self.fuzzyPinyin(Self.toPinyin(chinese)), chinese,
                                shot.eventPrefix + "Made"))
            }
            for state in voiceMissedStates {
                let chinese = shot.keyword + state
                results.append((Self.fuzzyPinyin(Self.toPinyin(chinese)), chinese,
                                shot.eventPrefix + "Missed"))
            }
        }

        // Non-shot actions and events (manually defined)
        let special: [(String, String, String)] = [
            ("远投", "远投", "stat.threeMade"),
            ("犯规", "犯规", "stat.foul"),
            ("篮板", "篮板", "stat.rebound"), ("板", "板", "stat.rebound"),
            ("前场板", "前场板", "stat.rebound"), ("后场板", "后场板", "stat.rebound"), ("抢板", "抢板", "stat.rebound"),
            ("nanban", "nanban", "stat.rebound"), ("nan ban", "nan ban", "stat.rebound"), ("nan", "nan", "stat.rebound"),
            ("助攻", "助攻", "stat.assist"), ("成功", "成功", "stat.assist"),
            ("盖帽", "盖帽", "stat.block"), ("封盖", "封盖", "stat.block"),
            ("抢断", "抢断", "stat.steal"), ("断球", "断球", "stat.steal"),
            ("失误", "失误", "stat.turnover"), ("走步", "走步", "stat.turnover"), ("违例", "违例", "stat.turnover"),
            ("开始", "开始", "event.period"), ("第一节", "第一节", "event.period"), ("第1节", "第1节", "event.period"),
            ("第二节", "第二节", "event.period"), ("第2节", "第2节", "event.period"), ("第三节", "第三节", "event.period"),
            ("第3节", "第3节", "event.period"), ("第四节", "第四节", "event.period"), ("第4节", "第4节", "event.period"),
            ("下一节", "下一节", "event.period"),
            ("暂停", "暂停", "event.pause"), ("停表", "停表", "event.pause"), ("继续", "继续", "event.pause"),
            ("继续比赛", "继续比赛", "event.pause"), ("比赛继续", "比赛继续", "event.pause"),
            ("结束", "结束", "event.game_end"), ("比赛结束", "比赛结束", "event.game_end"), ("完场", "完场", "event.game_end"),
            ("换人", "换人", "event.substitution"), ("替换", "替换", "event.substitution"),
        ]
        for (phrase, chinese, code) in special {
            results.append((Self.fuzzyPinyin(Self.toPinyin(phrase)), chinese, code))
        }

        return results
    }()

    func configure(store: AppStore) {
        self.store = store
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

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { buffer, _ in
                self.recognitionRequest.append(buffer)
            }

            try audioEngine.start()
        } catch {
            showError("麦克风不可用")
            isRecording = false
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
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
        recognitionRequest.endAudio()
        recognitionTask?.finish()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func addLog(text: String, isSuccess: Bool, action: String? = nil, playerName: String? = nil, matchedPattern: String? = nil, matchDetail: String? = nil) {
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
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                if errorMessage == msg { errorMessage = nil }
            }
        }
    }

    private func matchPlayerIDs(from text: String, textPinyin: String, in allIDs: [UUID]) -> [(UUID, TeamSide, Double)] {
        guard let store, let snapshot = currentSnapshot else { return [] }
        let threshold = 0.5
        var results: [(UUID, TeamSide, Double)] = []

        for id in allIDs {
            guard let player = store.player(for: id) else { continue }
            // Direct text match — also try stripping descriptive prefixes
            let nameLower = player.name.lowercased()
            if text.lowercased().contains(nameLower) || nameLower.contains(text.lowercased()) {
                let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                results.append((id, side, 1.0))
                continue
            }
            // Fuzzy pinyin match — try all pronunciation variants
            let fuzzyTP = Self.fuzzyPinyin(textPinyin)
            let nameVariants = Self.namePinyinVariants(player.name)
            for variant in nameVariants {
                let namePinyin = Self.fuzzyPinyin(variant)
                let score = Self.nameSimilarity(namePinyin, fuzzyTP)
                if score >= threshold {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    results.append((id, side, score))
                    break
                }
            }
        }

        return results.sorted { a, b in
            if a.2 != b.2 { return a.2 > b.2 }
            let aName = store.player(for: a.0)?.name ?? ""
            let bName = store.player(for: b.0)?.name ?? ""
            return aName.count > bName.count
        }
    }

    private func handleSubstitution(text: String, textPinyin: String) {
        let fuzzyTextPinyin = Self.fuzzyPinyin(textPinyin)
        guard let store, let snapshot = currentSnapshot else { return }

        // Try number-based matching first
        let textNumber = extractNumber(from: text)
        if let textNumber {
            for side in [TeamSide.home, TeamSide.away] {
                let courtIDs = side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
                let benchIDs = (side == .home ? snapshot.homeAvailablePlayerIDs : snapshot.awayAvailablePlayerIDs)
                    .filter { !courtIDs.contains($0) }
                let courtByNumber = courtIDs.first { store.player(for: $0)?.number == "\(textNumber)" }
                let benchByNumber = benchIDs.first { store.player(for: $0)?.number == "\(textNumber)" }
                if let outgoing = courtByNumber, let incoming = benchByNumber {
                    flashColor = .green
                    let p1 = store.player(for: outgoing)?.name ?? "?"
                    let p2 = store.player(for: incoming)?.name ?? "?"
                    addLog(text: text, isSuccess: true, action: "换人", playerName: "\(p1)→\(p2)")
                    onSubstitution?(side, outgoing, incoming)
                    Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
                    return
                }
            }
        }

        // Fall back to name matching
        var detailParts: [String] = []
        for side in [TeamSide.home, TeamSide.away] {
            let label = side == .home ? "主队" : "客队"
            let courtIDs = side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
            let benchIDs = (side == .home ? snapshot.homeAvailablePlayerIDs : snapshot.awayAvailablePlayerIDs)
                .filter { !courtIDs.contains($0) }
            let courtMatches = matchPlayerIDs(from: text, textPinyin: fuzzyTextPinyin, in: courtIDs)
            let benchMatches = matchPlayerIDs(from: text, textPinyin: fuzzyTextPinyin, in: benchIDs)
            let courtDesc = courtMatches.prefix(3).map { id, _, s -> String in
                "\(store.player(for: id)?.name ?? "?")(\(String(format: "%.2f", s)))"
            }.joined(separator: ", ")
            let benchDesc = benchMatches.prefix(3).map { id, _, s -> String in
                "\(store.player(for: id)?.name ?? "?")(\(String(format: "%.2f", s)))"
            }.joined(separator: ", ")
            detailParts.append("\(label): 上场=\(courtDesc.isEmpty ? "无" : courtDesc), 下场=\(benchDesc.isEmpty ? "无" : benchDesc)")

            guard let outgoing = courtMatches.first, let incoming = benchMatches.first else {
                continue
            }
            flashColor = .green
            let p1 = store.player(for: outgoing.0)?.name ?? "?"
            let p2 = store.player(for: incoming.0)?.name ?? "?"
            addLog(text: text, isSuccess: true, action: "换人", playerName: "\(p1)→\(p2)")
            onSubstitution?(side, outgoing.0, incoming.0)
            Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
            return
        }

        let detail = detailParts.joined(separator: " | ")
        addLog(text: text, isSuccess: false, action: "换人", matchDetail: detail)
        showError("未识别到换人球员")
        flashColor = .red
        Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
    }

    private func processText(_ text: String) {
        let textPinyin = Self.toPinyin(text)
        let fuzzyTextPinyin = Self.fuzzyPinyin(textPinyin)

        // Score each pattern by sliding-window similarity
        let threshold: Double = 0.48
        var bestEventScore = threshold
        var matchedEventCode: String?
        var matchedPinyin: String?
        var matchPosition = 0

        for (fuzzyPinyin, _, eventCode) in pinyinPatterns {
            let (score, pos) = Self.bestMatch(fuzzyPinyin, fuzzyTextPinyin)
            if score > bestEventScore {
                bestEventScore = score
                matchedEventCode = eventCode
                matchedPinyin = fuzzyPinyin
                matchPosition = pos
            }
        }

        guard let eventCode = matchedEventCode else {
            addLog(text: text, isSuccess: false, matchDetail: "拼音: \(textPinyin)")
            showError("未识别：\"\(text)\"")
            flashColor = .red
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                flashColor = nil
            }
            return
        }

        // Handle game commands (no player needed)
        if eventCode == "event.period" || eventCode == "event.pause" || eventCode == "event.game_end" {
            match = nil
            let commandLabel: String = eventCode == "event.period" ? "节次"
                : eventCode == "event.pause" ? "暂停" : "结束比赛"
            addLog(text: text, isSuccess: true, action: commandLabel, matchedPattern: eventCode, matchDetail: "拼音: \(textPinyin)")
            flashColor = .green
            let command: VoiceCommand = eventCode == "event.period" ? .startPeriod
                : eventCode == "event.pause" ? .togglePause : .finishGame
            onCommand?(command)
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                await MainActor.run { flashColor = nil }
            }
            return
        }

        // Handle substitution (two players)
        if eventCode == "event.substitution" {
            handleSubstitution(text: text, textPinyin: textPinyin)
            return
        }

        // Parse StatAction from eventCode
        guard let action = StatAction.allCases.first(where: { $0.eventCode == eventCode }) else {
            showError("未识别：\"\(text)\"")
            flashColor = .red
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                flashColor = nil
            }
            return
        }

        // Match player — number matching first, then name matching
        guard let store, let snapshot = currentSnapshot else { return }
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs

        // Skip fuzzy player matching if action consumes most of the text (no room for a name)
        let textClean = fuzzyTextPinyin.replacingOccurrences(of: " ", with: "")
        let patternClean = (matchedPinyin ?? "").replacingOccurrences(of: " ", with: "")
        let prefixLen = matchPosition
        let suffixLen = textClean.count - patternClean.count - prefixLen
        let canFuzzyMatchPlayer = prefixLen > 0 || suffixLen > 0

        // Build residual pinyin (only the text outside the matched pattern window)
        let residualFuzzy: String
        if prefixLen + patternClean.count <= textClean.count {
            let chars = Array(textClean)
            let prefix = String(chars[0..<prefixLen])
            let suffix = String(chars[(prefixLen + patternClean.count)...])
            let parts = [prefix, suffix].filter { !$0.isEmpty }
            residualFuzzy = parts.joined(separator: " ")
        } else {
            residualFuzzy = fuzzyTextPinyin
        }

        var bestPlayer: (UUID, TeamSide, Double)?

        let number = extractNumber(from: text)
        if let number {
            for id in allIDs {
                guard let player = store.player(for: id) else { continue }
                if player.number == "\(number)" {
                    let side: TeamSide = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away
                    bestPlayer = (id, side, 100)
                    break
                }
            }
        }

        if bestPlayer == nil, canFuzzyMatchPlayer, !containsNumberKeyword(text) {
            bestPlayer = matchPlayerIDs(from: text, textPinyin: residualFuzzy, in: allIDs).first
        }

        guard let (playerID, side, _) = bestPlayer else {
            addLog(text: text, isSuccess: false, action: eventCode, matchDetail: "拼音: \(textPinyin), 未匹配到球员")
            showError("未识别：\"\(text)\"")
            flashColor = .red
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                flashColor = nil
            }
            return
        }

        let player = store.player(for: playerID)
        addLog(text: text, isSuccess: true, action: action.message, playerName: player?.name, matchedPattern: eventCode, matchDetail: "拼音: \(textPinyin)")

        match = (playerID, side, action)
        flashColor = .green
        onAction?(action, playerID, side)

        Task {
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run { flashColor = nil }
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                if match?.playerID == playerID { match = nil }
            }
        }
    }

    private func extractNumber(from text: String) -> Int? {
        let pattern = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|hao)")
        if let match = pattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        }
        return nil
    }

    private func containsNumberKeyword(_ text: String) -> Bool {
        text.contains("号") || text.contains("hao")
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

    /// Name-specific similarity: divides by min(len) for the denominator.
    /// Short names (3-4 pinyin chars) can match within long text without being penalized.
    /// Cap scales with name length: longer names (more reliable match) can score closer to 1.0.
    static func nameSimilarity(_ namePinyin: String, _ textPinyin: String) -> Double {
        let aClean = namePinyin.replacingOccurrences(of: " ", with: "")
        let bClean = textPinyin.replacingOccurrences(of: " ", with: "")
        let aChars = Array(aClean)
        let bChars = Array(bClean)
        guard !aChars.isEmpty else { return 0 }
        let denom = Double(max(aChars.count, bChars.count))
        let cap = 0.80 + Double(aChars.count) * 0.03
        if bChars.count < aChars.count {
            let matches = zip(aChars, bChars).filter { $0 == $1 }.count
            return min(Double(matches) / denom, cap)
        }
        var best = 0.0
        for offset in 0...(bChars.count - aChars.count) {
            var matches = 0
            for i in aChars.indices {
                if aChars[i] == bChars[offset + i] { matches += 1 }
            }
            let score = Double(matches) / denom
            best = max(best, score)
        }
        return min(best, cap)
    }
}
