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
            ("换", "换", "event.substitution"), ("换上", "换上", "event.substitution"), ("换下", "换下", "event.substitution"),
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
            let nameVariants = Self.namePinyinVariants(player.name)
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
        let fuzzyTextPinyin = Self.fuzzyPinyin(textPinyin)
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
        let keywordVariants = ["替换", "换下", "换上", "换"]
        var subject = text, object = "", usedKw = ""
        for kw in keywordVariants {
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
        let textPinyin = Self.toPinyin(text)
        addLog(text: text, isSuccess: false, action: nil, matchDetail: "开始匹配 → 原文: \(text) | 拼音: \(textPinyin)")

        // Pre-check for substitution
        if text.contains("换") || text.contains("替换") {
            handleSubstitution(text: text, textPinyin: textPinyin)
            return
        }

        // Build a precedence-ordered list of events with their keywords and Chinese text
        // Each entry: (keyword, chineseKeyword, eventCode, isShot, needsPlayer)
        typealias Evt = (keyword: String, chinese: String, code: String, isShot: Bool)

        // Shot events
        var allEvents: [Evt] = []
        for shot in voiceShotTypes {
            allEvents.append((shot.keyword, shot.keyword, shot.eventPrefix, true))
        }

        // Non-shot events
        let nonShotStatCodes: Set<String> = ["stat.foul", "stat.rebound", "stat.assist", "stat.block", "stat.steal", "stat.turnover"]
        let commandCodes: Set<String> = ["event.period", "event.pause", "event.game_end"]
        var nonShotEvents: [(chinese: String, code: String)] = []
        for (_, chinese, code) in pinyinPatterns {
            if nonShotStatCodes.contains(code) || commandCodes.contains(code) {
                if !nonShotEvents.contains(where: { $0.code == code }) {
                    nonShotEvents.append((chinese, code))
                }
            }
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
            var playerID: UUID?; var side: TeamSide?; var playerScore: Double = 0
            var dbgPlayer = ""

            let number = extractNumber(from: text)
            if let number {
                for id in allIDs {
                    guard let p = store.player(for: id) else { continue }
                    if p.number == "\(number)" {
                        playerID = id; side = snapshot.homeOnCourtPlayerIDs.contains(id) ? .home : .away; playerScore = 100
                        dbgPlayer = "号码\(number)直配"
                        break
                    }
                }
            }

            if playerID == nil, !leftText.isEmpty {
                let leftPinyin = Self.fuzzyPinyin(Self.toPinyin(leftText))
                let (matches, dbg) = matchPlayerIDsDebug(text: leftText, textPinyin: leftPinyin, in: allIDs, context: "左侧球员")
                dbgPlayer = dbg
                if let m = matches.first {
                    playerID = m.0; side = m.1; playerScore = m.2
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

            guard let action = StatAction.allCases.first(where: { $0.eventCode == finalCode }) ?? (isShot ? nil : nil) else {
                // For shots, StatAction may use stat.twoMade etc — already handled by finalCode
                // Find by prefix
                let found = StatAction.allCases.first { $0.eventCode == finalCode }
                guard let act = found else {
                    addLog(text: text, isSuccess: false, action: finalCode, matchDetail: "❌ 无对应StatAction: \(finalCode)"); return false
                }
                let pn = store.player(for: pid)?.name ?? "?"
                addLog(text: text, isSuccess: true, action: act.message, playerName: pn, matchedPattern: finalCode, matchDetail: "球员匹配: \(dbgPlayer)")
                match = (pid, sd, act); flashColor = .green; onAction?(act, pid, sd)
                Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
                Task { try? await Task.sleep(for: .seconds(1.5)); await MainActor.run { if match?.playerID == pid { match = nil } } }
                return true
            }

            let pn = store.player(for: pid)?.name ?? "?"
            addLog(text: text, isSuccess: true, action: action.message, playerName: pn, matchedPattern: finalCode, matchDetail: "球员匹配: \(dbgPlayer)")
            match = (pid, sd, action); flashColor = .green; onAction?(action, pid, sd)
            Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
            Task { try? await Task.sleep(for: .seconds(1.5)); await MainActor.run { if match?.playerID == pid { match = nil } } }
            return true
        }

        // 1) Try shot keywords first — direct text match
        for evt in allEvents {
            if let (left, right) = findKeyword(evt.keyword) {
                addLog(text: text, isSuccess: false, action: evt.code, matchDetail: "🔍 找到关键词「\(evt.keyword)」 | 左侧原文: \(left.isEmpty ? "空" : left) | 右侧原文: \(right.isEmpty ? "空" : right)")
                if resolvePlayer(leftText: left, eventCode: evt.code, isShot: true, rightText: right) { return }
            }
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
                let label = code == "event.period" ? "节次" : code == "event.pause" ? "暂停" : code == "event.game_end" ? "结束比赛" : chinese
                flashColor = .green
                let cmd: VoiceCommand = code == "event.period" ? .startPeriod : code == "event.pause" ? .togglePause : .finishGame
                onCommand?(cmd)
                Task { try? await Task.sleep(for: .seconds(0.5)); await MainActor.run { flashColor = nil } }
                return
            }
        }

        addLog(text: text, isSuccess: false, matchDetail: "❌ 全文无匹配: \(text) | 拼音: \(textPinyin)")
        showError("未识别：\"\(text)\""); flashColor = .red
        Task { try? await Task.sleep(for: .seconds(0.5)); flashColor = nil }
    }

    private func extractNumber(from text: String) -> Int? {
        let pattern = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|hao)")
        if let match = pattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        }
        return nil
    }

    private func extractAllNumbers(from text: String) -> [Int] {
        let pattern = try? NSRegularExpression(pattern: "(\\d+)\\s*(号|hao)")
        let matches = pattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let range = Range(match.range(at: 1), in: text)!
            let num = Int(String(text[range]))!
            guard num >= 0, num <= 99 else { return nil }
            return num
        }
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
