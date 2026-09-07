import XCTest
@testable import BasketballRecord

final class BasketballExcelExportTests: XCTestCase {
    func testStatsAggregatorPreservesDetailedShotAndTeamMetrics() {
        var first = PlayerStats()
        first.twoMade = 2
        first.twoAttempts = 4
        first.layupMade = 3
        first.layupAttempts = 5
        first.paintMade = 1
        first.paintAttempts = 2
        first.fastBreakPoints = 4

        var second = PlayerStats()
        second.threeMade = 2
        second.threeAttempts = 6
        second.dunkMade = 1
        second.dunkAttempts = 1
        second.offensiveRebounds = 3

        let result = BasketballExcelStatsAggregator.sum([first, second])

        XCTAssertEqual(result.twoMade, 2)
        XCTAssertEqual(result.threeAttempts, 6)
        XCTAssertEqual(result.layupMade, 3)
        XCTAssertEqual(result.paintAttempts, 2)
        XCTAssertEqual(result.dunkMade, 1)
        XCTAssertEqual(result.offensiveRebounds, 3)
        XCTAssertEqual(result.fastBreakPoints, 4)
    }

    func testSingleGameReportIncludesAllSheetsAndTeamScore() {
        let homeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let awayID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        var playerStats = PlayerStats()
        playerStats.twoMade = 5
        var teamStats = PlayerStats()
        teamStats.threeMade = 2

        var snapshot = GameSnapshot(
            statsByPlayerID: [playerID: playerStats],
            homeTeamID: homeID,
            awayTeamID: awayID,
            periodCount: 4,
            isComplete: true,
            starterPlayerIDs: [playerID],
            playingSecondsByPlayerID: [playerID: 600],
            plusMinusByPlayerID: [playerID: 3]
        )
        snapshot.teamStatsByID[awayID] = teamStats

        let game = SavedGame(
            savedAt: Date(timeIntervalSince1970: 1_700_000_000),
            snapshot: snapshot,
            homeTeamName: "Home",
            awayTeamName: "Away",
            homePlayerIDs: [playerID],
            awayPlayerIDs: [],
            playerNamesByID: [playerID: "Alex"]
        )
        let report = BasketballExcelReportBuilder.singleGame(game, players: [Player(id: playerID, name: "Alex")])

        XCTAssertEqual(report.sheets.count, 5)
        XCTAssertEqual(report.sheets[0].rows[5][1], .text("10 - 6"))
        XCTAssertEqual(report.sheets[1].rows.count, 2)
        XCTAssertEqual(report.sheets[2].rows.count, 3)
        XCTAssertEqual(report.data.prefix(2), Data([0x50, 0x4b]))
    }

    func testPlayerProfileReportUsesSelectedGamesAndNumericAverages() {
        let homeID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let awayID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
        var firstStats = PlayerStats()
        firstStats.twoMade = 2
        var secondStats = PlayerStats()
        secondStats.twoMade = 4

        let first = makeGame(homeID: homeID, awayID: awayID, playerID: playerID, stats: firstStats, timestamp: 1_700_000_000)
        let second = makeGame(homeID: homeID, awayID: awayID, playerID: playerID, stats: secondStats, timestamp: 1_700_000_100)
        let report = BasketballExcelReportBuilder.playerProfile(playerID: playerID, games: [first, second], players: [Player(id: playerID, name: "Alex")])
        let averageRow = report.sheets[3].rows[1]

        XCTAssertEqual(report.sheets.count, 5)
        XCTAssertEqual(averageRow[1], .integer(2))
        XCTAssertEqual(averageRow[4], .number(3))
    }

    func testTeamStatsModeDoesNotCreatePlayerBoxScoreRowsForThatTeam() {
        let homeID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let awayID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        let homePlayerID = UUID(uuidString: "00000000-0000-0000-0000-000000000023")!
        let awayPlayerID = UUID(uuidString: "00000000-0000-0000-0000-000000000024")!
        var snapshot = GameSnapshot(homeTeamID: homeID, awayTeamID: awayID, homeTeamStatsMode: true)
        snapshot.statsByPlayerID[homePlayerID] = PlayerStats()
        snapshot.statsByPlayerID[awayPlayerID] = PlayerStats()
        let game = SavedGame(savedAt: Date(), snapshot: snapshot, homeTeamName: "Home", awayTeamName: "Away", homePlayerIDs: [homePlayerID], awayPlayerIDs: [awayPlayerID], playerNamesByID: [homePlayerID: "Home Player", awayPlayerID: "Away Player"])

        let report = BasketballExcelReportBuilder.singleGame(game, players: [])
        let rows = report.sheets[1].rows

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][2], .text("Away Player"))
    }

    private func makeGame(homeID: UUID, awayID: UUID, playerID: UUID, stats: PlayerStats, timestamp: TimeInterval) -> SavedGame {
        let snapshot = GameSnapshot(statsByPlayerID: [playerID: stats], homeTeamID: homeID, awayTeamID: awayID, playingSecondsByPlayerID: [playerID: 600])
        return SavedGame(savedAt: Date(timeIntervalSince1970: timestamp), snapshot: snapshot, homeTeamName: "Home", awayTeamName: "Away", homePlayerIDs: [playerID], awayPlayerIDs: [], playerNamesByID: [playerID: "Alex"])
    }
}
