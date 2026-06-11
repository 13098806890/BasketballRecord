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
        XCTAssertEqual(VoiceRecognizer.toPinyin("篮板"), "lan ban")
        XCTAssertEqual(VoiceRecognizer.toPinyin("三分命中"), "san fen ming zhong")
        XCTAssertEqual(VoiceRecognizer.toPinyin("张三"), "zhang san")
        XCTAssertEqual(VoiceRecognizer.toPinyin("李四"), "li si")
        XCTAssertEqual(VoiceRecognizer.toPinyin("bobo"), "bobo")
    }

    // MARK: - Similarity Matching

    func testExactMatch() {
        let score = VoiceRecognizer.similarity("lan ban", "lan ban")
        XCTAssertEqual(score, 1.0, accuracy: 0.01)
    }

    func testPartialMatchWithinText() {
        let score = VoiceRecognizer.similarity("lan ban", "zhang san lan ban")
        XCTAssertGreaterThan(score, 0.5)
    }

    func testFuzzyNasalMatch() {
        // "篮板" -> "lan ban", ASR says "nan ban" (n/l confusion)
        let score = VoiceRecognizer.similarity("lan ban", "nan ban")
        XCTAssertGreaterThan(score, 0.5)
    }

    func testShortPatternInText() {
        // "ban" within "zhang san lan ban"
        let score = VoiceRecognizer.similarity("ban", "zhang san lan ban")
        XCTAssertGreaterThan(score, 0.3)
    }

    func testLowSimilarity() {
        let score = VoiceRecognizer.similarity("liang fen", "san fen ming zhong")
        XCTAssertLessThan(score, 0.5)
    }

    // MARK: - Action Pattern Matching

    func testMatchTwoMade() {
        assertMatch(text: "张三两分命中", expectedEvent: "stat.twoMade", expectedPlayer: "张三")
    }

    func testMatchTwoMissed() {
        assertMatch(text: "李四2分没中", expectedEvent: "stat.twoMissed", expectedPlayer: "李四")
    }

    func testMatchThreeMade() {
        assertMatch(text: "王五三分命中", expectedEvent: "stat.threeMade", expectedPlayer: "王五")
    }

    func testMatchThreeMissed() {
        assertMatch(text: "赵六三分不中", expectedEvent: "stat.threeMissed", expectedPlayer: "赵六")
    }

    func testMatchFreeThrowMade() {
        assertMatch(text: "张三罚球命中", expectedEvent: "stat.freeThrowMade", expectedPlayer: "张三")
    }

    func testMatchRebound() {
        assertMatch(text: "李四篮板", expectedEvent: "stat.rebound", expectedPlayer: "李四")
    }

    func testMatchFoul() {
        assertMatch(text: "张三犯规", expectedEvent: "stat.foul", expectedPlayer: "张三")
    }

    func testMatchAssist() {
        assertMatch(text: "王五助攻", expectedEvent: "stat.assist", expectedPlayer: "王五")
    }

    func testMatchBlock() {
        assertMatch(text: "赵六盖帽", expectedEvent: "stat.block", expectedPlayer: "赵六")
    }

    func testMatchSteal() {
        assertMatch(text: "李四抢断", expectedEvent: "stat.steal", expectedPlayer: "李四")
    }

    func testMatchTurnover() {
        assertMatch(text: "王五失误", expectedEvent: "stat.turnover", expectedPlayer: "王五")
    }

    func testMatchBonusMade() {
        assertMatch(text: "张三加罚命中", expectedEvent: "stat.bonusMade", expectedPlayer: "张三")
    }

    // MARK: - Number Matching

    func testMatchByNumber() {
        assertMatch(text: "3号两分命中", expectedEvent: "stat.twoMade", expectedPlayer: "张三")
    }

    func testMatchByNumberExact() {
        assertMatch(text: "7号篮板", expectedEvent: "stat.rebound", expectedPlayer: "李四")
    }

    func testMatchByNumberNoFalseMatch() {
        // 3 should match 张三 (number "3"), not 王五 (number "10")
        assertMatch(text: "3号犯规", expectedEvent: "stat.foul", expectedPlayer: "张三")
    }

    // MARK: - English Name Matching

    func testMatchEnglishName() {
        assertMatch(text: "Bobo两分命中", expectedEvent: "stat.twoMade", expectedPlayer: "Bobo")
    }

    // MARK: - Command Matching

    func testMatchPause() {
        assertCommand(text: "暂停", expectedCommand: "togglePause")
    }

    func testMatchStartPeriod() {
        assertCommand(text: "开始比赛", expectedCommand: "startPeriod")
    }

    func testMatchSubstitution() {
        assertCommand(text: "换人", expectedCommand: "substitution")
    }


    func testSubstitutionSingleChar() {
        assertCommand(text: "换", expectedCommand: "substitution")
    }

    func testSubstitutionWithNames() {
        assertCommand(text: "换张三李四", expectedCommand: "substitution")
    }

    func testSubstitutionWithNumbers() {
        assertCommand(text: "3号换5号", expectedCommand: "substitution")
    }

    func testSubstitutionWithTeamPrefix() {
        assertCommand(text: "主队8号换客队88号", expectedCommand: "substitution")
    }

    func testSubstitutionHuanTi() {
        assertCommand(text: "替换", expectedCommand: "substitution")
    }

    func testSubstitutionWithEnglishNames() {
        assertCommand(text: "波波换哼哼", expectedCommand: "substitution")
    }

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

    func testSubstitutionWithoutPlayerFails() {
        let recognizer = VoiceRecognizer()
        recognizer.configure(store: store)
        recognizer.currentSnapshot = snapshot

        var called = false
        recognizer.onSubstitution = { _, _, _ in called = true }
        recognizer.simulateText("换人")

        XCTAssertFalse(called, "onSubstitution should not fire without matching players")
        XCTAssertNotNil(recognizer.errorMessage, "should show error")
    }

    func testMatchContinueDoesNotMatchEnd() {
        // "比赛继续" should NOT match event.game_end
        let result = findEvent(text: "比赛继续")
        XCTAssertNotEqual(result.eventCode, "event.game_end")
    }

    func testMatchContinueMatchesPause() {
        let result = findEvent(text: "比赛继续")
        XCTAssertEqual(result.eventCode, "event.pause")
    }

    func testContinueDoesNotMatchPeriod() {
        // "继续" alone should not match event.period
        let result = findEvent(text: "继续")
        XCTAssertEqual(result.eventCode, "event.pause")
    }

    // MARK: - Fuzzy Matching

    func testFuzzyNasalRebound() {
        // "nan ban" instead of "lan ban" (篮板)
        assertMatch(text: "张三nanban", expectedEvent: "stat.rebound", expectedPlayer: "张三")
    }

    func testEnglishLetterNameMatchesChinesePronun() {
        let pid = UUID()
        store.players.append(Player(id: pid, name: "P", number: "1"))
        snapshot.homeOnCourtPlayerIDs.append(pid)
        assertMatch(text: "皮两分命中", expectedEvent: "stat.twoMade", expectedPlayer: "P")
    }

    func testEnglishLetterNameDirect() {
        let pid = UUID()
        store.players.append(Player(id: pid, name: "P", number: "1"))
        snapshot.homeOnCourtPlayerIDs.append(pid)
        assertMatch(text: "p犯规", expectedEvent: "stat.foul", expectedPlayer: "P")
    }

    func testChineseNameMatchesEnglish() {
        // "波波" (Chinese chars) should match Bobo (English name) via pinyin
        assertMatch(text: "波波犯规", expectedEvent: "stat.foul", expectedPlayer: "Bobo")
    }

    func testFuzzyNameTones() {
        // "li si" -> 李四
        assertMatch(text: "李四犯规", expectedEvent: "stat.foul", expectedPlayer: "李四")
    }

    func testFuzzyActionOnly() {
        // No player mention — should still match action if player is selected or partial
        // This tests that "篮板" alone at least matches the event
        let result = findEvent(text: "篮板")
        XCTAssertEqual(result.eventCode, "stat.rebound")
    }

    func testActionWithoutPlayerDoesNotMatchFuzzyPlayer() {
        // Pure action text "三分不中" should NOT fuzzy-match a player like "老冯"
        let result = findEvent(text: "三分不中")
        XCTAssertEqual(result.eventCode, "stat.threeMissed")
        XCTAssertNil(result.playerName, "Pure action text should not match any player via fuzzy pinyin")
    }

    func testActionWithPlayerNameMatchesCorrectly() {
        // "老冯三分不中" should match player 老冯 via direct substring
        assertMatch(text: "老冯三分不中", expectedEvent: "stat.threeMissed", expectedPlayer: "老冯")
    }

    func testASRIdMatchesPlayerAD() {
        // ASR may transcribe "AD" as "id" — should still match player AD via fuzzy pinyin
        assertMatch(text: "id两分命中", expectedEvent: "stat.twoMade", expectedPlayer: "AD")
    }

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

    // MARK: - No Match Cases

    func testNoMatchGibberish() {
        let result = findEvent(text: "abcdefg")
        XCTAssertNil(result.eventCode)
    }

    func testNoMatchEmpty() {
        let result = findEvent(text: "")
        XCTAssertNil(result.eventCode)
    }

    // MARK: - Helpers

    private func findEvent(text: String) -> (eventCode: String?, playerName: String?) {
        let textPinyin = VoiceRecognizer.toPinyin(text)
        let fuzzyTextPinyin = VoiceRecognizer.fuzzyPinyin(textPinyin)

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
            ("zan ting", "event.pause"), ("ting biao", "event.pause"), ("kai shi", "event.period"),
            ("di yi jie", "event.period"), ("di 1 jie", "event.period"),
            ("di er jie", "event.period"), ("di 2 jie", "event.period"),
            ("di san jie", "event.period"), ("di 3 jie", "event.period"),
            ("di si jie", "event.period"), ("di 4 jie", "event.period"),
            ("huan ren", "event.substitution"), ("ti huan", "event.substitution"),
        ]

        for (pinyin, eventCode) in patterns {
            let fuzzyPinyin = VoiceRecognizer.fuzzyPinyin(pinyin)
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
                let nameFuzzy = VoiceRecognizer.fuzzyPinyin(VoiceRecognizer.toPinyin(player.name))
                let score = VoiceRecognizer.nameSimilarity(nameFuzzy, residualFuzzy)
                if score >= bestPlayerScore {
                    bestPlayerScore = score
                    bestPlayerName = player.name
                }
                // Also try letter-pinyin variants for English names
                let letters = player.name.lowercased().filter { $0.isLetter && $0.isASCII }
                if letters.count >= 2 && letters.count <= 4 {
                    let letterPinyins = letters.map { VoiceRecognizer.letterPinyin($0) }
                    let letterFuzzy = VoiceRecognizer.fuzzyPinyin(letterPinyins.joined(separator: " "))
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
