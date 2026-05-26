import XCTest
@testable import BasketballRecord

@MainActor
final class AppStoreOperationsTests: XCTestCase {
    private let storageKey = "basketball-record-store-v1"

    override func setUpWithError() throws {
        clearStore()
    }

    override func tearDownWithError() throws {
        clearStore()
    }

    func testTeamExportImportRoundTripKeepsUUIDsAndBasicInfo() throws {
        let player1ID = uuid("00000000-0000-0000-0000-000000000101")
        let player2ID = uuid("00000000-0000-0000-0000-000000000102")
        let teamID = uuid("00000000-0000-0000-0000-000000000201")

        let source = AppStore()
        source.players = []
        source.teams = []
        source.savedGames = []

        let player1 = Player(id: player1ID, name: "张三", height: "181", weight: "76", number: "7", photoData: Data([1, 2, 3]))
        let player2 = Player(id: player2ID, name: "李四", height: "186", weight: "82", number: "11", photoData: Data([9, 8, 7]))
        let team = Team(id: teamID, name: "测试队", playerIDs: [player1ID, player2ID])

        source.players = [player1, player2]
        source.teams = [team]

        let base64 = try XCTUnwrap(source.exportTeamBase64(team))
        let package = try XCTUnwrap(source.decodeTeamPackage(from: base64))

        XCTAssertEqual(package.team.id, teamID)
        XCTAssertEqual(package.team.playerIDs, [player1ID, player2ID])
        XCTAssertEqual(package.players.map(\.id), [player1ID, player2ID])

        clearStore()
        let target = AppStore()
        target.players = []
        target.teams = []
        target.savedGames = []

        let summary = target.importTeamPackage(package)

        XCTAssertEqual(summary.addedPlayers, 2)
        XCTAssertEqual(summary.addedTeams, 1)

        let importedTeam = try XCTUnwrap(target.teams.first)
        XCTAssertEqual(importedTeam.id, teamID)
        XCTAssertEqual(importedTeam.playerIDs, [player1ID, player2ID])

        let importedPlayer = try XCTUnwrap(target.player(for: player1ID))
        XCTAssertEqual(importedPlayer.name, "张三")
        XCTAssertEqual(importedPlayer.number, "7")
        XCTAssertNil(importedPlayer.photoData)
    }

    func testGameExportImportSupportsExplicitIDMapping() throws {
        let sourceHomePlayerID = uuid("00000000-0000-0000-0000-000000001001")
        let sourceAwayPlayerID = uuid("00000000-0000-0000-0000-000000001002")
        let sourceHomeTeamID = uuid("00000000-0000-0000-0000-000000001011")
        let sourceAwayTeamID = uuid("00000000-0000-0000-0000-000000001012")

        let source = AppStore()
        source.players = []
        source.teams = []
        source.savedGames = []
        source.players = [
            Player(id: sourceHomePlayerID, name: "甲"),
            Player(id: sourceAwayPlayerID, name: "乙")
        ]
        source.teams = [
            Team(id: sourceHomeTeamID, name: "主队A", playerIDs: [sourceHomePlayerID]),
            Team(id: sourceAwayTeamID, name: "客队A", playerIDs: [sourceAwayPlayerID])
        ]

        var snapshot = GameSnapshot(homeTeamID: sourceHomeTeamID, awayTeamID: sourceAwayTeamID)
        snapshot.statsByPlayerID[sourceHomePlayerID] = PlayerStats(twoMade: 2)
        snapshot.statsByPlayerID[sourceAwayPlayerID] = PlayerStats(threeMade: 1)
        source.saveGame(snapshot)

        let game = try XCTUnwrap(source.savedGames.first)
        let base64 = try XCTUnwrap(source.exportGameBase64(game))
        let package = try XCTUnwrap(source.decodeGamePackage(from: base64))

        let localHomePlayerID = uuid("00000000-0000-0000-0000-000000002001")
        let localAwayPlayerID = uuid("00000000-0000-0000-0000-000000002002")
        let localHomeTeamID = uuid("00000000-0000-0000-0000-000000002011")
        let localAwayTeamID = uuid("00000000-0000-0000-0000-000000002012")

        clearStore()
        let target = AppStore()
        target.players = []
        target.teams = []
        target.savedGames = []
        target.players = [
            Player(id: localHomePlayerID, name: "甲(本地)"),
            Player(id: localAwayPlayerID, name: "乙(本地)")
        ]
        target.teams = [
            Team(id: localHomeTeamID, name: "主队B", playerIDs: [localHomePlayerID]),
            Team(id: localAwayTeamID, name: "客队B", playerIDs: [localAwayPlayerID])
        ]

        target.importGamePackage(
            package,
            playerMapping: [
                sourceHomePlayerID: localHomePlayerID,
                sourceAwayPlayerID: localAwayPlayerID
            ],
            teamMapping: [
                sourceHomeTeamID: localHomeTeamID,
                sourceAwayTeamID: localAwayTeamID
            ],
            importsUnmatchedRoster: false
        )

        let imported = try XCTUnwrap(target.savedGames.first)
        XCTAssertEqual(imported.snapshot.homeTeamID, localHomeTeamID)
        XCTAssertEqual(imported.snapshot.awayTeamID, localAwayTeamID)
        XCTAssertEqual(imported.snapshot.statsByPlayerID[localHomePlayerID]?.twoMade, 2)
        XCTAssertEqual(imported.snapshot.statsByPlayerID[localAwayPlayerID]?.threeMade, 1)
        XCTAssertNil(imported.snapshot.statsByPlayerID[sourceHomePlayerID])
        XCTAssertNil(imported.snapshot.statsByPlayerID[sourceAwayPlayerID])
    }

    func testMergePlayerRemapsTeamAndGameData() throws {
        let targetID = uuid("00000000-0000-0000-0000-000000003001")
        let sourceID = uuid("00000000-0000-0000-0000-000000003002")
        let homeTeamID = uuid("00000000-0000-0000-0000-000000003011")
        let awayTeamID = uuid("00000000-0000-0000-0000-000000003012")

        let targetPlayer = Player(id: targetID, name: "本地球员", height: "", weight: "", number: "")
        let sourcePlayer = Player(id: sourceID, name: "外部球员", height: "188", weight: "84", number: "33", photoData: Data([5, 5, 5]))

        var snapshot = GameSnapshot(homeTeamID: homeTeamID, awayTeamID: awayTeamID)
        snapshot.statsByPlayerID[targetID] = PlayerStats(twoMade: 1, rebounds: 1)
        snapshot.statsByPlayerID[sourceID] = PlayerStats(threeMade: 2, assists: 3)
        snapshot.playingSecondsByPlayerID[targetID] = 120
        snapshot.playingSecondsByPlayerID[sourceID] = 45
        snapshot.plusMinusByPlayerID[targetID] = 4
        snapshot.plusMinusByPlayerID[sourceID] = 6
        snapshot.homeOnCourtPlayerIDs = [targetID, sourceID]

        let game = SavedGame(
            savedAt: Date(),
            snapshot: snapshot,
            homeTeamName: "主队",
            awayTeamName: "客队",
            homePlayerIDs: [targetID, sourceID],
            awayPlayerIDs: [],
            playerNamesByID: [targetID: "本地球员", sourceID: "外部球员"]
        )

        let store = AppStore()
        store.players = [targetPlayer, sourcePlayer]
        store.teams = [
            Team(id: homeTeamID, name: "主队", playerIDs: [targetID, sourceID]),
            Team(id: awayTeamID, name: "客队", playerIDs: [])
        ]
        store.savedGames = [game]

        let summary = try XCTUnwrap(store.mergePlayer(sourceID: sourceID, into: targetID))

        XCTAssertEqual(summary.updatedTeams, 1)
        XCTAssertEqual(summary.updatedGames, 1)

        XCTAssertNil(store.player(for: sourceID))
        let mergedPlayer = try XCTUnwrap(store.player(for: targetID))
        XCTAssertEqual(mergedPlayer.height, "188")
        XCTAssertEqual(mergedPlayer.weight, "84")
        XCTAssertEqual(mergedPlayer.number, "33")
        XCTAssertEqual(mergedPlayer.photoData, Data([5, 5, 5]))

        let mergedTeam = try XCTUnwrap(store.team(for: homeTeamID))
        XCTAssertEqual(mergedTeam.playerIDs, [targetID])

        let mergedGame = try XCTUnwrap(store.savedGames.first)
        let mergedStats = try XCTUnwrap(mergedGame.snapshot.statsByPlayerID[targetID])
        XCTAssertEqual(mergedStats.twoMade, 1)
        XCTAssertEqual(mergedStats.threeMade, 2)
        XCTAssertEqual(mergedStats.rebounds, 1)
        XCTAssertEqual(mergedStats.assists, 3)
        XCTAssertEqual(mergedGame.snapshot.playingSecondsByPlayerID[targetID], 165)
        XCTAssertEqual(mergedGame.snapshot.plusMinusByPlayerID[targetID], 10)
        XCTAssertNil(mergedGame.snapshot.statsByPlayerID[sourceID])
        XCTAssertEqual(mergedGame.homePlayerIDs, [targetID])
        XCTAssertNil(mergedGame.playerNamesByID[sourceID])
    }

    func testMergeTeamRemapsHistoricalTeamIDsAndMergesRoster() throws {
        let sourceTeamID = uuid("00000000-0000-0000-0000-000000004011")
        let targetTeamID = uuid("00000000-0000-0000-0000-000000004012")
        let thirdTeamID = uuid("00000000-0000-0000-0000-000000004013")
        let p1 = uuid("00000000-0000-0000-0000-000000004101")
        let p2 = uuid("00000000-0000-0000-0000-000000004102")
        let p3 = uuid("00000000-0000-0000-0000-000000004103")

        let store = AppStore()
        store.players = [
            Player(id: p1, name: "甲"),
            Player(id: p2, name: "乙"),
            Player(id: p3, name: "丙")
        ]
        store.teams = [
            Team(id: sourceTeamID, name: "来源队", playerIDs: [p1, p2]),
            Team(id: targetTeamID, name: "目标队", playerIDs: [p2, p3]),
            Team(id: thirdTeamID, name: "第三队", playerIDs: [])
        ]

        let game1 = SavedGame(
            savedAt: Date(),
            snapshot: GameSnapshot(homeTeamID: sourceTeamID, awayTeamID: thirdTeamID),
            homeTeamName: "来源队",
            awayTeamName: "第三队",
            homePlayerIDs: [p1, p2],
            awayPlayerIDs: [],
            playerNamesByID: [:]
        )
        let game2 = SavedGame(
            savedAt: Date(),
            snapshot: GameSnapshot(homeTeamID: thirdTeamID, awayTeamID: sourceTeamID),
            homeTeamName: "第三队",
            awayTeamName: "来源队",
            homePlayerIDs: [],
            awayPlayerIDs: [p1, p2],
            playerNamesByID: [:]
        )
        store.savedGames = [game1, game2]

        let summary = try XCTUnwrap(store.mergeTeam(sourceID: sourceTeamID, into: targetTeamID))

        XCTAssertEqual(summary.mergedPlayers, 1)
        XCTAssertEqual(summary.updatedGames, 2)

        XCTAssertFalse(store.teams.contains(where: { $0.id == sourceTeamID }))
        let mergedTargetTeam = try XCTUnwrap(store.team(for: targetTeamID))
        XCTAssertEqual(Set(mergedTargetTeam.playerIDs), Set([p1, p2, p3]))

        XCTAssertEqual(store.savedGames[0].snapshot.homeTeamID, targetTeamID)
        XCTAssertEqual(store.savedGames[0].homeTeamName, "目标队")
        XCTAssertEqual(store.savedGames[1].snapshot.awayTeamID, targetTeamID)
        XCTAssertEqual(store.savedGames[1].awayTeamName, "目标队")
    }

    private func clearStore() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
