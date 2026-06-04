import XCTest
@testable import BasketballRecord

final class BluetoothProtocolTests: XCTestCase {
    // MARK: - StatAction

    func testStatActionApplyAndRevert() {
        for action in StatAction.allCases {
            var stats = PlayerStats()
            action.apply(to: &stats)
            XCTAssertTrue(action.revert(on: &stats), "\(action) should revert")
            XCTAssertEqual(stats.twoMade, 0)
            XCTAssertEqual(stats.twoAttempts, 0)
            XCTAssertEqual(stats.threeMade, 0)
            XCTAssertEqual(stats.threeAttempts, 0)
            XCTAssertEqual(stats.freeThrowMade, 0)
            XCTAssertEqual(stats.freeThrowAttempts, 0)
            XCTAssertEqual(stats.bonusFreeThrowMade, 0)
            XCTAssertEqual(stats.bonusFreeThrowAttempts, 0)
            XCTAssertEqual(stats.fouls, 0)
            XCTAssertEqual(stats.assists, 0)
            XCTAssertEqual(stats.rebounds, 0)
            XCTAssertEqual(stats.blocks, 0)
            XCTAssertEqual(stats.steals, 0)
            XCTAssertEqual(stats.turnovers, 0)
        }
    }

    func testStatActionEventCodes() {
        let testCases: [(StatAction, String)] = [
            (.twoMade, "stat.twoMade"),
            (.twoMissed, "stat.twoMissed"),
            (.threeMade, "stat.threeMade"),
            (.threeMissed, "stat.threeMissed"),
            (.freeThrowMade, "stat.freeThrowMade"),
            (.freeThrowMissed, "stat.freeThrowMissed"),
            (.bonusMade, "stat.bonusMade"),
            (.bonusMissed, "stat.bonusMissed"),
            (.foul, "stat.foul"),
            (.assist, "stat.assist"),
            (.rebound, "stat.rebound"),
            (.block, "stat.block"),
            (.steal, "stat.steal"),
            (.turnover, "stat.turnover"),
        ]
        for (action, code) in testCases {
            XCTAssertEqual(action.eventCode, code, "\(action)")
        }
    }

    func testStatActionPoints() {
        XCTAssertEqual(StatAction.twoMade.points, 2)
        XCTAssertEqual(StatAction.twoMissed.points, 0)
        XCTAssertEqual(StatAction.threeMade.points, 3)
        XCTAssertEqual(StatAction.threeMissed.points, 0)
        XCTAssertEqual(StatAction.freeThrowMade.points, 1)
        XCTAssertEqual(StatAction.freeThrowMissed.points, 0)
        XCTAssertEqual(StatAction.bonusMade.points, 1)
        XCTAssertEqual(StatAction.bonusMissed.points, 0)
        XCTAssertEqual(StatAction.foul.points, 0)
        XCTAssertEqual(StatAction.assist.points, 0)
        XCTAssertEqual(StatAction.rebound.points, 0)
        XCTAssertEqual(StatAction.block.points, 0)
        XCTAssertEqual(StatAction.steal.points, 0)
        XCTAssertEqual(StatAction.turnover.points, 0)
    }

    // MARK: - PlayerStats

    func testPlayerStatsPoints() {
        var stats = PlayerStats()
        stats.twoMade = 4
        stats.threeMade = 2
        stats.freeThrowMade = 3
        stats.bonusFreeThrowMade = 1
        XCTAssertEqual(stats.points, 4*2 + 2*3 + 3 + 1)
    }

    func testPlayerStatsFieldGoalAggregation() {
        var stats = PlayerStats()
        stats.twoMade = 5; stats.twoAttempts = 10
        stats.threeMade = 3; stats.threeAttempts = 7
        XCTAssertEqual(stats.made, 8)
        XCTAssertEqual(stats.attempts, 17)
    }

    func testPlayerStatsFreeThrowAggregation() {
        var stats = PlayerStats()
        stats.freeThrowMade = 3; stats.freeThrowAttempts = 4
        stats.bonusFreeThrowMade = 1; stats.bonusFreeThrowAttempts = 2
        XCTAssertEqual(stats.allFreeThrowMade, 4)
        XCTAssertEqual(stats.allFreeThrowAttempts, 6)
    }

    func testPlayerStatsFieldGoalRate() {
        var stats = PlayerStats()
        stats.twoMade = 5; stats.twoAttempts = 10
        stats.threeMade = 2; stats.threeAttempts = 5
        XCTAssertEqual(stats.fieldGoalRate, 7.0 / 15.0)
        XCTAssertEqual(stats.twoPointRate, 5.0 / 10.0)
        XCTAssertEqual(stats.threePointRate, 2.0 / 5.0)
    }

    func testPlayerStatsFreeThrowRate() {
        var stats = PlayerStats()
        stats.freeThrowMade = 3; stats.freeThrowAttempts = 4
        stats.bonusFreeThrowMade = 1; stats.bonusFreeThrowAttempts = 2
        XCTAssertEqual(stats.freeThrowRate, 4.0 / 6.0)
    }

    func testPlayerStatsEffectiveFieldGoalRate() {
        var stats = PlayerStats()
        stats.twoMade = 5; stats.twoAttempts = 10
        stats.threeMade = 2; stats.threeAttempts = 5
        let expected = (5 + 2 + 0.5 * 2) / 15.0
        XCTAssertEqual(stats.effectiveFieldGoalRate, expected)
    }

    func testPlayerStatsTrueShootingRate() {
        var stats = PlayerStats()
        stats.twoMade = 5; stats.twoAttempts = 10
        stats.threeMade = 2; stats.threeAttempts = 5
        stats.freeThrowMade = 3; stats.freeThrowAttempts = 4
        stats.bonusFreeThrowMade = 1; stats.bonusFreeThrowAttempts = 2
        let pts = 5*2 + 2*3 + 3 + 1
        let fga = 15.0
        let fta = 6.0
        let expected = Double(pts) / (2 * (fga + 0.44 * fta))
        XCTAssertEqual(stats.trueShootingRate, expected)
    }

    func testPlayerStatsPointsPerShot() {
        var stats = PlayerStats()
        stats.twoMade = 5; stats.twoAttempts = 10
        stats.threeMade = 2; stats.threeAttempts = 5
        stats.freeThrowMade = 3; stats.freeThrowAttempts = 4
        stats.bonusFreeThrowMade = 1; stats.bonusFreeThrowAttempts = 2
        let expected = Double(5*2 + 2*3 + 3 + 1) / 15.0
        XCTAssertEqual(stats.pointsPerShot, expected)
    }

    func testPlayerStatsZeroRates() {
        let stats = PlayerStats()
        XCTAssertEqual(stats.fieldGoalRate, 0)
        XCTAssertEqual(stats.threePointRate, 0)
        XCTAssertEqual(stats.freeThrowRate, 0)
        XCTAssertEqual(stats.effectiveFieldGoalRate, 0)
        XCTAssertEqual(stats.trueShootingRate, 0)
        XCTAssertEqual(stats.pointsPerShot, 0)
    }

    func testPlayerStatsEquality() {
        var a = PlayerStats()
        a.twoMade = 3; a.rebounds = 5
        var b = PlayerStats()
        b.twoMade = 3; b.rebounds = 5
        XCTAssertEqual(a, b)
        b.assists = 1
        XCTAssertNotEqual(a, b)
    }

    // MARK: - StatAction message

    func testStatActionMessages() {
        XCTAssertFalse(StatAction.twoMade.message.isEmpty)
        XCTAssertFalse(StatAction.foul.message.isEmpty)
        for action in StatAction.allCases {
            XCTAssertFalse(action.message.isEmpty, "\(action) should have a message")
        }
    }

    // MARK: - BluetoothLiveStatAction

    func testBluetoothLiveStatActionRawValues() {
        XCTAssertEqual(BluetoothLiveStatAction.twoMade.rawValue, "twoMade")
        XCTAssertEqual(BluetoothLiveStatAction.threeMade.rawValue, "threeMade")
        XCTAssertEqual(BluetoothLiveStatAction.foul.rawValue, "foul")
    }

    // MARK: - TeamSide

    func testTeamSideDisplayName() {
        XCTAssertFalse(TeamSide.home.displayName.isEmpty)
        XCTAssertFalse(TeamSide.away.displayName.isEmpty)
    }

    // MARK: - GameLogEntry

    func testGameLogEntryIdUniqueness() {
        let entry1 = GameLogEntry(timestamp: Date(), message: "test", eventCode: nil, playerID: nil, relatedPlayerID: nil, period: nil, periodElapsedSeconds: nil)
        let entry2 = GameLogEntry(timestamp: Date(), message: "test", eventCode: nil, playerID: nil, relatedPlayerID: nil, period: nil, periodElapsedSeconds: nil)
        XCTAssertNotEqual(entry1.id, entry2.id)
    }
}
