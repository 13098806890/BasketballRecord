import XCTest
@testable import BasketballRecord

@MainActor
final class VoiceMatchingTests: XCTestCase {
    var store: AppStore!
    var snapshot: GameSnapshot!

    let homePlayer1ID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let homePlayer2ID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    let homePlayer3ID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    let homePlayer4ID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
    let awayPlayer1ID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    let awayPlayer2ID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    let awayPlayer3ID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
    let homeTeamID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    let awayTeamID = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!

    override func setUp() async throws {
        try await super.setUp()
        store = AppStore()
        store.players = [
            Player(id: homePlayer1ID, name: "张三", number: "3"),
            Player(id: homePlayer2ID, name: "李四", number: "7"),
            Player(id: homePlayer3ID, name: "王五", number: "10"),
            Player(id: homePlayer4ID, name: "AD", number: "1"),
            Player(id: awayPlayer1ID, name: "赵六", number: "5"),
            Player(id: awayPlayer2ID, name: "Bobo", number: "23"),
            Player(id: awayPlayer3ID, name: "老冯", number: "8"),
        ]
        store.teams = [
            Team(id: homeTeamID, name: "红队", playerIDs: [homePlayer1ID, homePlayer2ID, homePlayer3ID, homePlayer4ID]),
            Team(id: awayTeamID, name: "蓝队", playerIDs: [awayPlayer1ID, awayPlayer2ID, awayPlayer3ID]),
        ]
        snapshot = GameSnapshot()
        snapshot.homeTeamID = homeTeamID
        snapshot.awayTeamID = awayTeamID
        snapshot.homeOnCourtPlayerIDs = [homePlayer1ID, homePlayer2ID, homePlayer3ID, homePlayer4ID]
        snapshot.awayOnCourtPlayerIDs = [awayPlayer1ID, awayPlayer2ID, awayPlayer3ID]
        snapshot.homeAvailablePlayerIDs = [homePlayer1ID, homePlayer2ID, homePlayer3ID, homePlayer4ID]
        snapshot.awayAvailablePlayerIDs = [awayPlayer1ID, awayPlayer2ID, awayPlayer3ID]
    }

    // MARK: - Pinyin Conversion

    func testToPinyin() {
        XCTAssertEqual(VoiceRules.chinese.toPinyin("篮板"), "lan ban")
        XCTAssertEqual(VoiceRules.chinese.toPinyin("三分命中"), "san fen ming zhong")
        XCTAssertEqual(VoiceRules.chinese.toPinyin("张三"), "zhang san")
        XCTAssertEqual(VoiceRules.chinese.toPinyin("李四"), "li si")
        XCTAssertEqual(VoiceRules.chinese.toPinyin("bobo"), "bobo")
    }

    // MARK: - Similarity Matching

    func testExactMatch() {
        let score = VoiceRecognizer.similarity("lan ban", "lan ban")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPartialMatchWithinText() {
        let score = VoiceRecognizer.similarity("lan ban", "zhang san lan ban")
        XCTAssertGreaterThan(score, 0.37)
        XCTAssertLessThan(score, 0.5)
    }

    func testFuzzyNasalMatch() {
        // "篮板" -> "lan ban", ASR says "nan ban" (n/l confusion)
        let score = VoiceRecognizer.similarity("lan ban", "nan ban")
        XCTAssertGreaterThan(score, 0.5)
    }

    func testShortPatternInText() {
        // "ban" within "zhang san lan ban"
        let score = VoiceRecognizer.similarity("ban", "zhang san lan ban")
        XCTAssertGreaterThan(score, 0.18)
        XCTAssertLessThan(score, 0.35)
    }

    func testLowSimilarity() {
        let score = VoiceRecognizer.similarity("liang fen", "san fen ming zhong")
        XCTAssertLessThan(score, 0.5)
    }

    // MARK: - Action Pattern Matching

    // MARK: - Number Matching

    // MARK: - English Name Matching

    // MARK: - Command Matching

    func testSubstitutionByNameIntegration() async throws {
        let pid1 = UUID()  // bobo — on court, #8
        let pid2 = UUID()  // 哼哼 — on bench, #88
        store.players.append(Player(id: pid1, name: "bobo", number: "8"))
        store.players.append(Player(id: pid2, name: "哼哼", number: "88"))
        snapshot.homeOnCourtPlayerIDs = [pid1, homePlayer1ID]
        snapshot.homeAvailablePlayerIDs = [pid1, homePlayer1ID, pid2]

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        let expectation = expectation(description: "onSubstitution called")
        var capturedOutgoing: UUID?
        var capturedIncoming: UUID?
        recognizer.onSubstitution = { side, outgoing, incoming in
            capturedOutgoing = outgoing
            capturedIncoming = incoming
            expectation.fulfill()
        }

        recognizer.simulateText("bobo换哼哼")

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedOutgoing, pid1, "bobo should be outgoing (on court)")
        XCTAssertEqual(capturedIncoming, pid2, "哼哼 should be incoming (on bench)")
    }

    func testSubstitutionByNumberIntegration() async throws {
        let pid1 = UUID()
        let pid2 = UUID()
        store.players.append(Player(id: pid1, name: "bobo", number: "8"))
        store.players.append(Player(id: pid2, name: "哼哼", number: "88"))
        snapshot.homeOnCourtPlayerIDs = [pid1, homePlayer1ID]
        snapshot.homeAvailablePlayerIDs = [pid1, homePlayer1ID, pid2]

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        let expectation = expectation(description: "onSubstitution called by number")
        var capturedOutgoing: UUID?
        var capturedIncoming: UUID?
        recognizer.onSubstitution = { _, outgoing, incoming in
            capturedOutgoing = outgoing
            capturedIncoming = incoming
            expectation.fulfill()
        }

        recognizer.simulateText("8号换88号")

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedOutgoing, pid1, "8号 should be outgoing")
        XCTAssertEqual(capturedIncoming, pid2, "88号 should be incoming")
    }

    // MARK: - Fuzzy Matching

    // MARK: - English Voice Integration Tests

    func testEnglishThreeMissed() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("李四 three missed")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .threeMissed)
    }

    func testEnglishFoul() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("张三 foul")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .foul)
    }

    func testEnglishRebound() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("李四 board")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .rebound)
    }

    func testEnglishAssist() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("李四 dime")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .assist)
    }

    func testEnglishBlock() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("王五 swat")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .block)
    }

    func testEnglishSteal() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("赵六 takeaway")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .steal)
    }

    func testEnglishTurnover() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("赵六 walk")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .turnover)
    }

    func testEnglishTimeout() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onCommand called")
        var capturedCmd: VoiceCommand?
        recognizer.onCommand = { cmd in
            capturedCmd = cmd
            exp.fulfill()
        }
        recognizer.simulateText("timeout")
        await fulfillment(of: [exp], timeout: 1.0)
        if case .togglePause = capturedCmd { } else { XCTFail("Expected togglePause") }
    }

    func testEnglishSubstitution() async throws {
        let pid1 = UUID()
        let pid2 = UUID()
        store.players.append(Player(id: pid1, name: "John", number: "8"))
        store.players.append(Player(id: pid2, name: "Mike", number: "88"))
        snapshot.homeOnCourtPlayerIDs = [pid1, homePlayer1ID]
        snapshot.homeAvailablePlayerIDs = [pid1, homePlayer1ID, pid2]

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onSubstitution called")
        var capturedOutgoing: UUID?
        var capturedIncoming: UUID?
        recognizer.onSubstitution = { _, outgoing, incoming in
            capturedOutgoing = outgoing
            capturedIncoming = incoming
            exp.fulfill()
        }
        recognizer.simulateText("John sub in Mike")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedOutgoing, pid1)
        XCTAssertEqual(capturedIncoming, pid2)
    }

    func testEnglishThreeNoThree() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("3 no 3")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .threeMissed)
    }

    func testEnglishNumberThreeNoThree() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("number 3 no 3")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .threeMissed)
    }

    func testEnglishThreeWordNoThree() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("three no three")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .threeMissed)
    }

    func testEnglishNumberThreeWordNoThree() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("number three no three")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .threeMissed)
    }

    func testEnglishBlockStat() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("张三 block")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .block)
    }

    func testEnglishTurnOver() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("张三 turn over")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .turnover)
    }

    func testEnglishBlockCapitalized() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action
            exp.fulfill()
        }
        recognizer.simulateText("张三 Block")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .block)
    }

    // MARK: - No Match Cases

    // MARK: - Helpers

    private func findEvent(text: String) -> (eventCode: String?, playerName: String?) {
        let textPinyin = VoiceRules.chinese.toPinyin(text)
        let fuzzyTextPinyin = VoiceRules.chinese.fuzzyPinyin(textPinyin)

        // Pre-check for substitution (same as VoiceRecognizer.processText)
        if text.contains("换") || text.contains("替换") {
            return ("event.substitution", nil)
        }

        let threshold = 0.5
        var bestEventScore = threshold
        var matchedEventCode: String?
        var matchedPattern: String?
        var matchPosition = 0

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot

        // Use reflection to access pinyinPatterns... Instead, build it directly from patterns
        let patterns: [(String, String)] = [
            ("liang fen ming zhong", "stat.twoMade"), ("2 fen ming zhong", "stat.twoMade"),
            ("liang fen jin", "stat.twoMade"), ("2 fen jin", "stat.twoMade"),
            ("liang fen wei zhong", "stat.twoMissed"), ("liang fen mei zhong", "stat.twoMissed"),
            ("liang fen bu zhong", "stat.twoMissed"), ("2 fen wei zhong", "stat.twoMissed"),
            ("2 fen mei zhong", "stat.twoMissed"), ("2 fen bu zhong", "stat.twoMissed"),
            ("liang fen da tie", "stat.twoMissed"),
            ("san fen ming zhong", "stat.threeMade"), ("3 fen ming zhong", "stat.threeMade"),
            ("san fen jin", "stat.threeMade"), ("3 fen jin", "stat.threeMade"),
            ("yuan tou", "stat.threeMade"),
            ("san fen wei zhong", "stat.threeMissed"), ("san fen mei zhong", "stat.threeMissed"),
            ("san fen bu zhong", "stat.threeMissed"), ("3 fen wei zhong", "stat.threeMissed"),
            ("3 fen mei zhong", "stat.threeMissed"), ("3 fen bu zhong", "stat.threeMissed"),
            ("fa qiu ming zhong", "stat.freeThrowMade"), ("fa qiu jin", "stat.freeThrowMade"),
            ("fa qiu wei zhong", "stat.freeThrowMissed"), ("fa qiu mei zhong", "stat.freeThrowMissed"), ("fa qiu bu zhong", "stat.freeThrowMissed"),
            ("jia fa ming zhong", "stat.bonusMade"), ("jia fa jin", "stat.bonusMade"),
            ("jia fa wei zhong", "stat.bonusMissed"), ("jia fa mei zhong", "stat.bonusMissed"),
            ("fan gui", "stat.foul"), ("lan ban", "stat.rebound"),
            ("qian chang ban", "stat.rebound"), ("hou chang ban", "stat.rebound"),
            ("zhu gong", "stat.assist"), ("gai mao", "stat.block"), ("feng gai", "stat.block"),
            ("qiang duan", "stat.steal"), ("duan qiu", "stat.steal"),
            ("shi wu", "stat.turnover"), ("zou bu", "stat.turnover"), ("wei li", "stat.turnover"),
            ("zan ting", "event.pause"), ("ting biao", "event.pause"), ("ji xu", "event.pause"),
            ("bi sai ji xu", "event.pause"), ("ji xu bi sai", "event.pause"),
            ("kai shi", "event.period"),
            ("di yi jie", "event.period"), ("di 1 jie", "event.period"),
            ("di er jie", "event.period"), ("di 2 jie", "event.period"),
            ("di san jie", "event.period"), ("di 3 jie", "event.period"),
            ("di si jie", "event.period"), ("di 4 jie", "event.period"),
            ("huan ren", "event.substitution"), ("ti huan", "event.substitution"),
        ]

        for (pinyin, eventCode) in patterns {
            let fuzzyPinyin = VoiceRules.chinese.fuzzyPinyin(pinyin)
            let (score, pos) = VoiceRecognizer.bestMatch(fuzzyPinyin, fuzzyTextPinyin)
            if score > bestEventScore {
                bestEventScore = score
                matchedEventCode = eventCode
                matchedPattern = fuzzyPinyin
                matchPosition = pos
            }
        }

        guard let eventCode = matchedEventCode else {
            return (nil, nil)
        }

        // Skip player matching for commands
        if eventCode == "event.period" || eventCode == "event.pause" || eventCode == "event.substitution" {
            return (eventCode, nil)
        }

        // Match player — same logic as production processText
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs

        let textClean = fuzzyTextPinyin.replacingOccurrences(of: " ", with: "")
        let patternClean = (matchedPattern ?? "").replacingOccurrences(of: " ", with: "")
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

        // Number matching first
        if let range = text.range(of: "\\d+\\s*(号|hao)", options: .regularExpression) {
            let numStr = String(text[range])
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "号", with: "")
                .replacingOccurrences(of: "hao", with: "")
            if let number = Int(numStr) {
                for id in allIDs {
                    guard let player = store.player(for: id) else { continue }
                    if player.number == "\(number)" {
                        return (eventCode, player.name)
                    }
                }
            }
        }

        // Fuzzy player matching against residual pinyin only
        if canFuzzyMatchPlayer, !text.contains("号"), !text.contains("hao") {
            let matchThreshold = 0.5
            var bestPlayerName: String?
            var bestPlayerScore = matchThreshold

            for id in allIDs {
                guard let player = store.player(for: id) else { continue }
                let nameLower = player.name.lowercased()
                if text.lowercased().contains(nameLower) {
                    return (eventCode, player.name)
                }
                let nameFuzzy = VoiceRules.chinese.fuzzyPinyin(VoiceRules.chinese.toPinyin(player.name))
                let score = VoiceRecognizer.nameSimilarity(nameFuzzy, residualFuzzy)
                if score >= bestPlayerScore {
                    bestPlayerScore = score
                    bestPlayerName = player.name
                }
                // Also try letter-pinyin variants for English names
                let letters = player.name.lowercased().filter { $0.isLetter && $0.isASCII }
                if letters.count >= 2 && letters.count <= 4 {
                    let letterPinyins = letters.map { VoiceRules.chinese.letterPinyin($0) }
                    let letterFuzzy = VoiceRules.chinese.fuzzyPinyin(letterPinyins.joined(separator: " "))
                    let letterScore = VoiceRecognizer.nameSimilarity(letterFuzzy, residualFuzzy)
                    if letterScore >= bestPlayerScore {
                        bestPlayerScore = letterScore
                        bestPlayerName = player.name
                    }
                }
            }

            if let name = bestPlayerName {
                return (eventCode, name)
            }
        }

        return (eventCode, nil)
    }

    private func assertMatch(text: String, expectedEvent: String, expectedPlayer: String, file: StaticString = #filePath, line: UInt = #line) {
        let result = findEvent(text: text)
        XCTAssertEqual(result.eventCode, expectedEvent, "Event mismatch for: \(text)", file: file, line: line)
        if let name = result.playerName {
            XCTAssertTrue(name.contains(expectedPlayer) || expectedPlayer.contains(name),
                          "Player mismatch: expected '\(expectedPlayer)' got '\(name)'", file: file, line: line)
        }
    }

    // MARK: - Team Stats Mode Voice (tests real snapshot creation + matching chain)

    func testTeamModeHomeWithInitFlag() async throws {
        let snap = GameSnapshot(
            homeTeamID: homeTeamID, awayTeamID: awayTeamID,
            homeOnCourtPlayerIDs: [], awayOnCourtPlayerIDs: [],
            homeAvailablePlayerIDs: [], awayAvailablePlayerIDs: [],
            homeTeamStatsMode: true, awayTeamStatsMode: false
        )
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snap
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        var capturedPlayerID: UUID?
        recognizer.onAction = { action, pid, _ in
            capturedAction = action; capturedPlayerID = pid; exp.fulfill()
        }
        recognizer.simulateText("红队两分命中")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .twoMade)
        XCTAssertEqual(capturedPlayerID, homeTeamID)
    }

    func testTeamModeAwayWithTeamName() async throws {
        let snap = GameSnapshot(
            homeTeamID: homeTeamID, awayTeamID: awayTeamID,
            homeTeamStatsMode: false, awayTeamStatsMode: true
        )
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snap
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        var capturedPlayerID: UUID?
        recognizer.onAction = { action, pid, _ in
            capturedAction = action; capturedPlayerID = pid; exp.fulfill()
        }
        recognizer.simulateText("蓝队三分")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .threeMade)
        XCTAssertEqual(capturedPlayerID, awayTeamID)
    }

    func testTeamModeHomeAliasZhuDui() async throws {
        let snap = GameSnapshot(
            homeTeamID: homeTeamID, awayTeamID: awayTeamID,
            homeTeamStatsMode: true, awayTeamStatsMode: false
        )
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snap
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        let exp = expectation(description: "onAction called")
        var capturedPlayerID: UUID?
        recognizer.onAction = { _, pid, _ in
            capturedPlayerID = pid; exp.fulfill()
        }
        recognizer.simulateText("主队两分命中")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedPlayerID, homeTeamID)
    }

    // MARK: - Pinyin Variants Generation

    func testGeneratePinyinVariants() {
        // Test basic variant generation
        let variants = VoiceRules.chinese.generatePinyinVariants("张三")
        XCTAssertTrue(variants.contains("zhang san"), "应包含原始拼音")
        XCTAssertTrue(variants.contains("zang san"), "应包含 zh→z 变体")

        // Test team name variants
        let teamVariants = VoiceRules.chinese.generatePinyinVariants("战神队")
        XCTAssertTrue(teamVariants.contains("zhan shen dui"), "应包含原始拼音")
        XCTAssertTrue(teamVariants.contains("zan shen dui"), "应包含 zh→z 变体")
        XCTAssertTrue(teamVariants.contains("zhan sen dui"), "应包含 sh→s 变体")

        // Test nasal variants
        let nasalVariants = VoiceRules.chinese.generatePinyinVariants("英格兰")
        XCTAssertTrue(nasalVariants.contains("ying ge lan"), "应包含原始拼音")
        XCTAssertTrue(nasalVariants.contains("yin ge lan"), "应包含 ing→in 变体")
        XCTAssertTrue(nasalVariants.contains("ying ge lan"), "应包含原始拼音")
        XCTAssertTrue(nasalVariants.contains("yingen lan") == false, "不应产生空格消失的变体")
    }

    func testTeamModeWithVariants() async throws {
        let snap = GameSnapshot(
            homeTeamID: homeTeamID, awayTeamID: awayTeamID,
            homeOnCourtPlayerIDs: [], awayOnCourtPlayerIDs: [],
            homeAvailablePlayerIDs: [], awayAvailablePlayerIDs: [],
            homeTeamStatsMode: true, awayTeamStatsMode: false
        )
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snap
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        let exp = expectation(description: "onAction called")
        var capturedAction: StatAction?
        var capturedPlayerID: UUID?
        recognizer.onAction = { action, pid, _ in
            capturedAction = action; capturedPlayerID = pid; exp.fulfill()
        }
        // Test with fuzzy variant: "洪队" (ASR might recognize "红队" as "洪队")
        recognizer.simulateText("洪队两分命中")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .twoMade)
        XCTAssertEqual(capturedPlayerID, homeTeamID)
    }

    // MARK: - Duplicate Number Across Teams

    func testDuplicateNumber7HomeAndAway() async throws {
        let away7ID = UUID(uuidString: "20000000-0000-0000-0000-000000000099")!
        store.players.append(Player(id: away7ID, name: "刘七", number: "7"))
        store.teams[1].playerIDs.append(away7ID)
        snapshot.awayOnCourtPlayerIDs.append(away7ID)
        snapshot.awayAvailablePlayerIDs.append(away7ID)

        let home7ID = homePlayer2ID

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "zh-CN"))

        // Test 1: no team prefix → should match home #7 (home comes first in allIDs)
        do {
            let exp = expectation(description: "onAction 7号两分")
            var capturedPID: UUID?
            recognizer.onAction = { _, pid, _ in capturedPID = pid; exp.fulfill() }
            recognizer.simulateText("7号两分")
            await fulfillment(of: [exp], timeout: 1.0)
            XCTAssertEqual(capturedPID, home7ID, "无前缀应匹配主队7号（allIDs中主队优先）")
        }

        // Test 2: 主队 prefix → should match home #7
        do {
            let exp = expectation(description: "onAction 主队7号两分")
            var capturedPID: UUID?
            recognizer.onAction = { _, pid, _ in capturedPID = pid; exp.fulfill() }
            recognizer.simulateText("主队7号两分")
            await fulfillment(of: [exp], timeout: 1.0)
            XCTAssertEqual(capturedPID, home7ID, "主队前缀应匹配主队7号")
        }

        // Test 3: 客队 prefix → should match away #7
        do {
            let exp = expectation(description: "onAction 客队7号两分")
            var capturedPID: UUID?
            recognizer.onAction = { _, pid, _ in capturedPID = pid; exp.fulfill() }
            recognizer.simulateText("客队7号两分")
            await fulfillment(of: [exp], timeout: 1.0)
            XCTAssertEqual(capturedPID, away7ID, "客队前缀应匹配客队7号")
        }
    }

    // MARK: - English Anchor Matching

    func testEnglishAnchorGotNumberTwo() async throws {
        let johnID = UUID(uuidString: "10000000-0000-0000-0000-000000000099")!
        store.players.append(Player(id: johnID, name: "John", number: "7"))
        snapshot.homeOnCourtPlayerIDs.append(johnID)
        snapshot.homeAvailablePlayerIDs.append(johnID)

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction for John got 2")
        var capturedAction: StatAction?
        var capturedPID: UUID?
        recognizer.onAction = { action, pid, _ in
            capturedAction = action; capturedPID = pid; exp.fulfill()
        }
        recognizer.simulateText("John got 2")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .twoMade)
        XCTAssertEqual(capturedPID, johnID)
    }

    func testEnglishAnchorGotNumberTwoWithName() async throws {
        let johnID = UUID(uuidString: "10000000-0000-0000-0000-000000000098")!
        store.players.append(Player(id: johnID, name: "John", number: "7"))
        snapshot.homeOnCourtPlayerIDs.append(johnID)
        snapshot.homeAvailablePlayerIDs.append(johnID)

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction for John got two")
        var capturedAction: StatAction?
        var capturedPID: UUID?
        recognizer.onAction = { action, pid, _ in
            capturedAction = action; capturedPID = pid; exp.fulfill()
        }
        recognizer.simulateText("John got two")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .twoMade)
        XCTAssertEqual(capturedPID, johnID)
    }

    func testMacFreeThroughMatchesMike() async throws {
        let mikeID = UUID(uuidString: "10000000-0000-0000-0000-000000000097")!
        store.players.append(Player(id: mikeID, name: "Mike", number: "10"))
        snapshot.homeOnCourtPlayerIDs.append(mikeID)
        snapshot.homeAvailablePlayerIDs.append(mikeID)

        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction for Mac free through")
        var capturedAction: StatAction?
        var capturedPID: UUID?
        recognizer.onAction = { action, pid, _ in
            capturedAction = action; capturedPID = pid; exp.fulfill()
        }
        recognizer.simulateText("Mac free through")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .freeThrowMade)
        XCTAssertEqual(capturedPID, mikeID)
    }

    func testEnglishToKnowAsTwoMissed() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction for ... to know")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action; exp.fulfill()
        }
        recognizer.simulateText("张三 to know")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .twoMissed)
    }

    func testEnglishMrAsMiss() async throws {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: "en-US"))

        let exp = expectation(description: "onAction for AD 2 Mr")
        var capturedAction: StatAction?
        recognizer.onAction = { action, _, _ in
            capturedAction = action; exp.fulfill()
        }
        recognizer.simulateText("AD 2 Mr")
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(capturedAction, .twoMissed)
    }

    private func assertCommand(text: String, expectedCommand: String, file: StaticString = #filePath, line: UInt = #line) {
        let result = findEvent(text: text)
        let commandMap: [String: [String]] = [
            "togglePause": ["event.pause"],
            "startPeriod": ["event.period"],
            "substitution": ["event.substitution"],
        ]
        guard let expectedCodes = commandMap[expectedCommand] else {
            XCTFail("Unknown command: \(expectedCommand)", file: file, line: line)
            return
        }
        guard let eventCode = result.eventCode else {
            XCTFail("No event matched for: \(text)", file: file, line: line)
            return
        }
        XCTAssertTrue(expectedCodes.contains(eventCode), "Expected '\(expectedCommand)' but got '\(eventCode)'", file: file, line: line)
    }
}
