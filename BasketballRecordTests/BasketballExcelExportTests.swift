import XCTest
@testable import BasketballRecord

final class BasketballExcelExportTests: XCTestCase {
    func testExportFilenameUsesXLSXExtension() {
        XCTAssertEqual(BasketballExcelExportFileName.addingXLSXExtension(to: "BasketballRecord_history"), "BasketballRecord_history.xlsx")
        XCTAssertEqual(BasketballExcelExportFileName.addingXLSXExtension(to: "career.xlsx"), "career.xlsx")
    }

    func testGameSelectionReturnsOnlySelectedGames() {
        let homeID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        let awayID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
        let first = makeGame(homeID: homeID, awayID: awayID, playerID: playerID, stats: PlayerStats(), timestamp: 1_700_000_000)
        let second = makeGame(homeID: homeID, awayID: awayID, playerID: playerID, stats: PlayerStats(), timestamp: 1_700_000_100)

        let selected = BasketballExcelGameSelection.selectedGames(from: [first, second], ids: [second.id])

        XCTAssertEqual(selected.map(\.id), [second.id])
    }

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

    func testSingleGameEventExportLocalizesGameLifecycleEventsInsteadOfAssist() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [
            GameLogEntry(timestamp: timestamp, message: "第1节开始", eventCode: "event.period_start", period: 1),
            GameLogEntry(timestamp: timestamp, message: "比赛暂停", eventCode: "event.pause", period: 1),
            GameLogEntry(timestamp: timestamp, message: "比赛继续", eventCode: "event.resume", period: 1)
        ]
        let game = SavedGame(
            savedAt: timestamp,
            snapshot: GameSnapshot(logs: logs),
            homeTeamName: "Home",
            awayTeamName: "Away",
            homePlayerIDs: [],
            awayPlayerIDs: [],
            playerNamesByID: [:]
        )

        let report = BasketballExcelReportBuilder.singleGame(game, players: [])
        let eventMessages = report.sheets[4].rows.dropFirst().map { $0[5] }

        XCTAssertEqual(eventMessages, [
            .text(String(format: NSLocalizedString("event_period_start_format", comment: ""), 1)),
            .text(NSLocalizedString("event_game_paused", comment: "")),
            .text(NSLocalizedString("event_game_resumed", comment: ""))
        ])
        XCTAssertNil(StatAction.parseFromSuffix("比赛开始"))
        XCTAssertNil(StatAction.parseFromSuffix("比赛暂停"))
        XCTAssertNil(StatAction.parseFromSuffix("比赛继续"))
    }

    func testEventExportsOmitDeletedEventsFromGameAndPlayerSheets() {
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let kept = GameLogEntry(timestamp: timestamp, message: "Alex 2分命中", eventCode: StatAction.twoMade.eventCode, playerID: playerID)
        let deleted = GameLogEntry(timestamp: timestamp.addingTimeInterval(10), message: "Alex 助攻", eventCode: StatAction.assist.eventCode, playerID: playerID)
        var game = makeEventGame(logs: [kept, deleted], playerID: playerID)
        game.snapshot.editHistory.append(deletionRecord(for: deleted))

        let gameRows = singleGameEventRows(game)
        XCTAssertEqual(gameRows.count, 1)
        XCTAssertEqual(gameRows[0][4], .text(kept.eventCode!))

        let playerRows = playerEventRows(game, playerID: playerID)
        XCTAssertEqual(playerRows.count, 1)
        XCTAssertEqual(playerRows[0][4], .text(kept.eventCode!))
    }

    func testEventExportsRestoreEventsAfterRestoreEdit() {
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let deleted = GameLogEntry(timestamp: timestamp, message: "Alex 篮板", eventCode: StatAction.rebound.eventCode, playerID: playerID)
        var game = makeEventGame(logs: [deleted], playerID: playerID)
        game.snapshot.editHistory.append(deletionRecord(for: deleted))
        game.snapshot.editHistory.append(restorationRecord(for: deleted.id))

        let rows = singleGameEventRows(game)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][4], .text(deleted.eventCode!))
    }

    func testEventExportsModifiedEventFields() {
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000053")!
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let target = GameLogEntry(timestamp: timestamp, message: "Alex 2分命中", eventCode: StatAction.twoMade.eventCode, playerID: playerID, period: 1, periodElapsedSeconds: 30)
        var game = makeEventGame(logs: [target], playerID: playerID)
        let modified = GameLogEditLogic.modify(
            snapshot: &game.snapshot,
            eventID: target.id,
            timestamp: timestamp.addingTimeInterval(20),
            playerID: playerID,
            eventCode: StatAction.threeMade.eventCode,
            message: "Alex 3分命中",
            period: 2,
            periodElapsedSeconds: 95
        )

        XCTAssertTrue(modified)
        let rows = singleGameEventRows(game)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0][2], .integer(2))
        XCTAssertEqual(rows[0][3], .text("01:35"))
        XCTAssertEqual(rows[0][4], .text(StatAction.threeMade.eventCode))
    }

    func testEventExportsOmitAddedThenDeletedEvents() {
        let playerID = UUID(uuidString: "00000000-0000-0000-0000-000000000054")!
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let added = GameLogEntry(timestamp: timestamp, message: "Alex 抢断", eventCode: StatAction.steal.eventCode, playerID: playerID)
        var game = makeEventGame(logs: [added], playerID: playerID)
        game.snapshot.editHistory.append(additionRecord(for: added))
        game.snapshot.editHistory.append(deletionRecord(for: added))

        XCTAssertTrue(singleGameEventRows(game).isEmpty)
        XCTAssertTrue(playerEventRows(game, playerID: playerID).isEmpty)
    }

    func testCompositeEventsKeepBothPlayersAndShotDetailsInExport() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let assisterID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        let scorerID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let stealerID = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        let turnoverID = UUID(uuidString: "00000000-0000-0000-0000-000000000044")!
        let logs = [
            GameLogEntry(timestamp: timestamp, message: "Assist event", eventCode: StatAction.assistTwoMade.eventCode, playerID: assisterID, relatedPlayerID: scorerID),
            GameLogEntry(timestamp: timestamp, message: "Steal event", eventCode: StatAction.stealTurnover.eventCode, playerID: stealerID, relatedPlayerID: turnoverID)
        ]
        let game = SavedGame(
            savedAt: timestamp,
            snapshot: GameSnapshot(logs: logs),
            homeTeamName: "Home",
            awayTeamName: "Away",
            homePlayerIDs: [assisterID, scorerID, stealerID, turnoverID],
            awayPlayerIDs: [],
            playerNamesByID: [
                assisterID: "Assister",
                scorerID: "Scorer",
                stealerID: "Stealer",
                turnoverID: "Turnover Player"
            ]
        )

        let report = BasketballExcelReportBuilder.singleGame(game, players: [])
        let eventMessages = report.sheets[4].rows.dropFirst().map { $0[5] }

        XCTAssertEqual(
            eventMessages[0],
            .text(String(
                format: NSLocalizedString("excel_event_assist_format", comment: ""),
                "Assister",
                "Scorer",
                NSLocalizedString("action_two_made", comment: "")
            ))
        )
        XCTAssertEqual(
            eventMessages[1],
            .text(String(
                format: NSLocalizedString("excel_event_steal_turnover_format", comment: ""),
                "Stealer",
                "Turnover Player"
            ))
        )
    }

    func testLegacyEventExportPreservesPlayerNameWhenPlayerIDIsMissing() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let log = GameLogEntry(timestamp: timestamp, message: "Legacy Player 2分命中")
        let game = SavedGame(
            savedAt: timestamp,
            snapshot: GameSnapshot(logs: [log]),
            homeTeamName: "Home",
            awayTeamName: "Away",
            homePlayerIDs: [],
            awayPlayerIDs: [],
            playerNamesByID: [:]
        )

        let report = BasketballExcelReportBuilder.singleGame(game, players: [])

        XCTAssertEqual(
            report.sheets[4].rows[1][5],
            .text("Legacy Player \(StatAction.twoMade.message)")
        )
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
        XCTAssertEqual(averageRow[5], .number(3))
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

    private func makeEventGame(logs: [GameLogEntry], playerID: UUID) -> SavedGame {
        let teamID = UUID(uuidString: "00000000-0000-0000-0000-000000000055")!
        let snapshot = GameSnapshot(logs: logs, homeTeamID: teamID, awayTeamID: teamID)
        return SavedGame(savedAt: Date(timeIntervalSince1970: 1_700_000_000), snapshot: snapshot, homeTeamName: "Home", awayTeamName: "Away", homePlayerIDs: [playerID], awayPlayerIDs: [], playerNamesByID: [playerID: "Alex"])
    }

    private func singleGameEventRows(_ game: SavedGame) -> [[BasketballExcelCell]] {
        Array(BasketballExcelReportBuilder.singleGame(game, players: []).sheets[4].rows.dropFirst())
    }

    private func playerEventRows(_ game: SavedGame, playerID: UUID) -> [[BasketballExcelCell]] {
        Array(BasketballExcelReportBuilder.playerProfile(playerID: playerID, games: [game], players: []).sheets[4].rows.dropFirst())
    }

    private func additionRecord(for event: GameLogEntry) -> GameLogEditRecord {
        GameLogEditRecord(
            timestamp: event.timestamp,
            action: "add",
            eventID: event.id,
            previousMessage: nil,
            previousEventCode: nil,
            previousPlayerID: nil,
            previousTimestamp: nil,
            previousPeriod: nil,
            previousPeriodElapsedSeconds: nil,
            currentMessage: event.message,
            currentEventCode: event.eventCode,
            currentPlayerID: event.playerID
        )
    }

    private func deletionRecord(for event: GameLogEntry) -> GameLogEditRecord {
        GameLogEditRecord(
            timestamp: event.timestamp,
            action: "delete",
            eventID: event.id,
            previousMessage: event.message,
            previousEventCode: event.eventCode,
            previousPlayerID: event.playerID,
            previousTimestamp: event.timestamp,
            previousPeriod: event.period,
            previousPeriodElapsedSeconds: event.periodElapsedSeconds,
            currentMessage: nil,
            currentEventCode: nil,
            currentPlayerID: nil
        )
    }

    private func restorationRecord(for eventID: UUID) -> GameLogEditRecord {
        GameLogEditRecord(
            timestamp: Date(timeIntervalSince1970: 1_700_000_001),
            action: "restore",
            eventID: eventID,
            previousMessage: nil,
            previousEventCode: nil,
            previousPlayerID: nil,
            previousTimestamp: nil,
            previousPeriod: nil,
            previousPeriodElapsedSeconds: nil,
            currentMessage: nil,
            currentEventCode: nil,
            currentPlayerID: nil
        )
    }
}
