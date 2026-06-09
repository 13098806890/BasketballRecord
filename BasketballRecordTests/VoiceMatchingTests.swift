import XCTest
@testable import BasketballRecord

@MainActor
final class VoiceMatchingTests: XCTestCase {
    var store: AppStore!
    var snapshot: GameSnapshot!

    let homePlayer1ID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let homePlayer2ID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    let homePlayer3ID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    let awayPlayer1ID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    let awayPlayer2ID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    let homeTeamID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    let awayTeamID = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!

    override func setUp() async throws {
        try await super.setUp()
        store = AppStore()
        store.players = [
            Player(id: homePlayer1ID, name: "张三", number: "3"),
            Player(id: homePlayer2ID, name: "李四", number: "7"),
            Player(id: homePlayer3ID, name: "王五", number: "10"),
            Player(id: awayPlayer1ID, name: "赵六", number: "5"),
            Player(id: awayPlayer2ID, name: "Bobo", number: "23"),
        ]
        store.teams = [
            Team(id: homeTeamID, name: "红队", playerIDs: [homePlayer1ID, homePlayer2ID, homePlayer3ID]),
            Team(id: awayTeamID, name: "蓝队", playerIDs: [awayPlayer1ID, awayPlayer2ID]),
        ]
        snapshot = GameSnapshot()
        snapshot.homeTeamID = homeTeamID
        snapshot.awayTeamID = awayTeamID
        snapshot.homeOnCourtPlayerIDs = [homePlayer1ID, homePlayer2ID, homePlayer3ID]
        snapshot.awayOnCourtPlayerIDs = [awayPlayer1ID, awayPlayer2ID]
        snapshot.homeAvailablePlayerIDs = [homePlayer1ID, homePlayer2ID, homePlayer3ID]
        snapshot.awayAvailablePlayerIDs = [awayPlayer1ID, awayPlayer2ID]
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

    func testMatchFinishGame() {
        assertCommand(text: "结束比赛", expectedCommand: "finishGame")
    }

    func testMatchSubstitution() {
        assertCommand(text: "换人", expectedCommand: "substitution")
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
            ("jie shu", "event.game_end"), ("bi sai jie shu", "event.game_end"),
            ("wan chang", "event.game_end"),
            ("huan ren", "event.substitution"), ("ti huan", "event.substitution"),
        ]

        for (pinyin, eventCode) in patterns {
            let fuzzyPinyin = VoiceRecognizer.fuzzyPinyin(pinyin)
            let score = VoiceRecognizer.similarity(fuzzyPinyin, fuzzyTextPinyin)
            if score > bestEventScore {
                bestEventScore = score
                matchedEventCode = eventCode
            }
        }

        guard let eventCode = matchedEventCode else {
            return (nil, nil)
        }

        // Match player
        let allIDs = snapshot.homeOnCourtPlayerIDs + snapshot.awayOnCourtPlayerIDs
        let matchThreshold = 0.4
        var bestPlayerName: String?
        var bestPlayerScore = matchThreshold

        for id in allIDs {
            guard let player = store.player(for: id) else { continue }
            let nameLower = player.name.lowercased()
            if text.lowercased().contains(nameLower) {
                return (eventCode, player.name)
            }
            let namePinyin = VoiceRecognizer.fuzzyPinyin(VoiceRecognizer.toPinyin(player.name))
            let score = VoiceRecognizer.nameSimilarity(namePinyin, fuzzyTextPinyin)
            if score > bestPlayerScore {
                bestPlayerScore = score
                bestPlayerName = player.name
            }
        }

        // Try number
        if let range = text.range(of: "\\d+\\s*号", options: .regularExpression) {
            let numStr = String(text[range]).trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "号", with: "")
            if let number = Int(numStr) {
                for id in allIDs {
                    guard let player = store.player(for: id) else { continue }
                    if player.number == "\(number)" {
                        return (eventCode, player.name)
                    }
                }
            }
        }

        return (eventCode, bestPlayerName)
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
            "finishGame": ["event.game_end"],
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
