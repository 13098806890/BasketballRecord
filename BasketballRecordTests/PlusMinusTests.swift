import XCTest
@testable import BasketballRecord

final class PlusMinusTests: XCTestCase {

    private func uuid(_ s: String) -> UUID { UUID(uuidString: s)! }

    private let homeTeamID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let awayTeamID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    private let h1 = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let h2 = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    private let h3 = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    private let a1 = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    private let a2 = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
    private let a3 = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!

    // MARK: - Helpers

    private func log(_ code: String, playerID: UUID? = nil, relatedPlayerID: UUID? = nil, period: Int = 1, at: TimeInterval) -> GameLogEntry {
        GameLogEntry(
            timestamp: Date(timeIntervalSinceReferenceDate: at),
            message: code,
            eventCode: code,
            playerID: playerID,
            relatedPlayerID: relatedPlayerID,
            period: period,
            periodElapsedSeconds: at
        )
    }

    private func makeGame(
        homeOnCourt: [UUID],
        awayOnCourt: [UUID],
        homeTeamStatsMode: Bool = false,
        awayTeamStatsMode: Bool = false,
        logs: [GameLogEntry]
    ) -> SavedGame {
        var snapshot = GameSnapshot(homeTeamID: homeTeamID, awayTeamID: awayTeamID)
        snapshot.homeOnCourtPlayerIDs = homeOnCourt
        snapshot.awayOnCourtPlayerIDs = awayOnCourt
        snapshot.homeTeamStatsMode = homeTeamStatsMode
        snapshot.awayTeamStatsMode = awayTeamStatsMode
        snapshot.startersRecorded = true
        snapshot.starterPlayerIDs = homeOnCourt + awayOnCourt
        snapshot.logs = logs

        let allPlayerIDs = homeOnCourt + awayOnCourt + [h3, a3]
        var names: [UUID: String] = [:]
        for pid in allPlayerIDs { names[pid] = "P\(pid.uuidString.prefix(3))" }

        return SavedGame(
            id: UUID(),
            savedAt: Date(timeIntervalSinceReferenceDate: 0),
            snapshot: snapshot,
            homeTeamName: "主队",
            awayTeamName: "客队",
            homePlayerIDs: [h1, h2, h3],
            awayPlayerIDs: [a1, a2, a3],
            playerNamesByID: names
        )
    }

    private func analyze(_ game: SavedGame) -> [Int: [UUID: Int]] {
        let analyzer = SavedGameAnalyzer(game: game) { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        }
        return analyzer.analyze().plusMinusByPeriod
    }

    private func totalPM(_ pmByPeriod: [Int: [UUID: Int]], for pid: UUID) -> Int {
        pmByPeriod.values.reduce(0) { $0 + ($1[pid] ?? 0) }
    }

    // MARK: - Full game flow with substitution

    func testFullGameFlowWithSubstitution() {
        let logs: [GameLogEntry] = [
            log("event.period_start", period: 1, at: 0),
            log("stat.twoMade", playerID: h1, period: 1, at: 10),
            log("stat.threeMade", playerID: a1, period: 1, at: 20),
            log("event.substitution", playerID: h3, relatedPlayerID: h1, period: 1, at: 30),
            log("stat.twoMade", playerID: h3, period: 1, at: 40),
            log("stat.twoMade", playerID: a2, period: 1, at: 50),
            log("event.game_end", at: 60),
        ]
        let game = makeGame(homeOnCourt: [h1, h2], awayOnCourt: [a1, a2], logs: logs)
        let pm = analyze(game)

        // h1: 主队 +2, 客队三分 -3 → -1（换人后不再参与）
        XCTAssertEqual(totalPM(pm, for: h1), -1)
        // h2: +2 -3 +2 -2 → -1
        XCTAssertEqual(totalPM(pm, for: h2), -1)
        // h3: 换人后 +2 -2 → 0
        XCTAssertEqual(totalPM(pm, for: h3), 0)
        // a1: -2 +3 -2 +2 → +1
        XCTAssertEqual(totalPM(pm, for: a1), 1)
        // a2: -2 +3 -2 +2 → +1
        XCTAssertEqual(totalPM(pm, for: a2), 1)
        // a3: 从未上场 → 0
        XCTAssertEqual(totalPM(pm, for: a3), 0)
    }

    // MARK: - Team stats mode (home) vs player mode (away)

    func testTeamStatsModeHomeScoringDoesNotTouchHomePlayers() {
        let logs: [GameLogEntry] = [
            log("event.period_start", period: 1, at: 0),
            log("stat.twoMade", playerID: homeTeamID, period: 1, at: 10),
            log("stat.threeMade", playerID: awayTeamID, period: 1, at: 20),
            log("event.game_end", at: 60),
        ]
        let game = makeGame(
            homeOnCourt: [],
            awayOnCourt: [a1, a2],
            homeTeamStatsMode: true,
            awayTeamStatsMode: false,
            logs: logs
        )
        let pm = analyze(game)

        // 主队球队模式：主队球员不参与正负值
        XCTAssertEqual(totalPM(pm, for: h1), 0)
        XCTAssertEqual(totalPM(pm, for: h2), 0)
        XCTAssertEqual(totalPM(pm, for: h3), 0)
        // 主队两分命中（球队模式）：客队球员 -2
        // 客队三分命中（球队模式）：客队球员 +3
        // a1/a2: -2 +3 → +1
        XCTAssertEqual(totalPM(pm, for: a1), 1)
        XCTAssertEqual(totalPM(pm, for: a2), 1)
    }

    // MARK: - Team stats mode (away) vs player mode (home)

    func testTeamStatsModeAwayScoringDoesNotTouchAwayPlayers() {
        let logs: [GameLogEntry] = [
            log("event.period_start", period: 1, at: 0),
            log("stat.twoMade", playerID: h1, period: 1, at: 10),
            log("stat.threeMade", playerID: awayTeamID, period: 1, at: 20),
            log("event.game_end", at: 60),
        ]
        let game = makeGame(
            homeOnCourt: [h1, h2],
            awayOnCourt: [],
            homeTeamStatsMode: false,
            awayTeamStatsMode: true,
            logs: logs
        )
        let pm = analyze(game)

        // 客队球队模式：客队球员不参与正负值
        XCTAssertEqual(totalPM(pm, for: a1), 0)
        XCTAssertEqual(totalPM(pm, for: a2), 0)
        XCTAssertEqual(totalPM(pm, for: a3), 0)
        // 主队两分命中：主队球员 +2
        // 客队三分命中（球队模式）：主队球员 -3
        // h1/h2: +2 -3 → -1
        XCTAssertEqual(totalPM(pm, for: h1), -1)
        XCTAssertEqual(totalPM(pm, for: h2), -1)
    }

    // MARK: - Both teams in player mode, bench player never affects

    func testBenchPlayerNotAffected() {
        let logs: [GameLogEntry] = [
            log("event.period_start", period: 1, at: 0),
            log("stat.twoMade", playerID: h1, period: 1, at: 10),
            log("event.game_end", at: 60),
        ]
        let game = makeGame(homeOnCourt: [h1, h2], awayOnCourt: [a1, a2], logs: logs)
        let pm = analyze(game)

        XCTAssertEqual(totalPM(pm, for: h3), 0, "替补不上场不应有正负值")
        XCTAssertEqual(totalPM(pm, for: a3), 0, "替补不上场不应有正负值")
        XCTAssertEqual(totalPM(pm, for: h1), 2)
        XCTAssertEqual(totalPM(pm, for: h2), 2)
        XCTAssertEqual(totalPM(pm, for: a1), -2)
        XCTAssertEqual(totalPM(pm, for: a2), -2)
    }

    // MARK: - Engine direct behavior (both teams team mode → nobody tracked)

    func testEngineBothTeamsStatsModeTracksNobody() {
        var dict: [UUID: Int] = [:]
        PlusMinusEngine.apply(
            points: 2,
            scoringSide: .home,
            homeTeamStatsMode: true,
            awayTeamStatsMode: true,
            homeOnCourt: [h1, h2],
            awayOnCourt: [a1, a2],
            to: &dict
        )
        XCTAssertTrue(dict.isEmpty)
    }
}
