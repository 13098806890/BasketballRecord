import XCTest
@testable import BasketballRecord

@MainActor
final class AppStoreOperationsTests: XCTestCase {
    private let storageKey = "basketball-record-store-v1"

    override func setUpWithError() throws {
        clearStore()
        CoreDataStore().clearAll()
    }

    override func tearDownWithError() throws {
        clearStore()
        CoreDataStore().clearAll()
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
        snapshot.statsByPlayerID[sourceHomePlayerID] = {
            var s = PlayerStats(); s.twoMade = 2; return s
        }()
        snapshot.statsByPlayerID[sourceAwayPlayerID] = {
            var s = PlayerStats(); s.threeMade = 1; return s
        }()
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
        snapshot.statsByPlayerID[targetID] = {
            var s = PlayerStats(); s.twoMade = 1; s.rebounds = 1; return s
        }()
        snapshot.statsByPlayerID[sourceID] = {
            var s = PlayerStats(); s.threeMade = 2; s.assists = 3; return s
        }()
        snapshot.playingSecondsByPlayerID[targetID] = 120
        snapshot.playingSecondsByPlayerID[sourceID] = 45
        snapshot.plusMinusByPlayerID[targetID] = 4
        snapshot.plusMinusByPlayerID[sourceID] = 6
        snapshot.starterPlayerIDs = [targetID, sourceID]
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
        XCTAssertEqual(mergedGame.snapshot.starterPlayerIDs, [targetID])
        XCTAssertNil(mergedGame.snapshot.statsByPlayerID[sourceID])
        XCTAssertEqual(mergedGame.homePlayerIDs, [targetID])
        XCTAssertNil(mergedGame.playerNamesByID[sourceID])
    }

    func testSaveGameKeepsStarterWhenNoTechnicalStats() throws {
        let homeStarterID = uuid("00000000-0000-0000-0000-000000006001")
        let awayStarterID = uuid("00000000-0000-0000-0000-000000006002")
        let homeTeamID = uuid("00000000-0000-0000-0000-000000006011")
        let awayTeamID = uuid("00000000-0000-0000-0000-000000006012")

        let store = AppStore()
        store.players = [
            Player(id: homeStarterID, name: "主队首发"),
            Player(id: awayStarterID, name: "客队首发")
        ]
        store.teams = [
            Team(id: homeTeamID, name: "主队", playerIDs: [homeStarterID]),
            Team(id: awayTeamID, name: "客队", playerIDs: [awayStarterID])
        ]

        var snapshot = GameSnapshot(homeTeamID: homeTeamID, awayTeamID: awayTeamID)
        snapshot.homeAvailablePlayerIDs = [homeStarterID]
        snapshot.awayAvailablePlayerIDs = [awayStarterID]
        snapshot.homeOnCourtPlayerIDs = [homeStarterID]
        snapshot.awayOnCourtPlayerIDs = [awayStarterID]
        snapshot.starterPlayerIDs = [homeStarterID, awayStarterID]
        snapshot.startersRecorded = true

        store.saveGame(snapshot)

        let saved = try XCTUnwrap(store.savedGames.first)
        XCTAssertEqual(saved.homePlayerIDs, [homeStarterID])
        XCTAssertEqual(saved.awayPlayerIDs, [awayStarterID])
        XCTAssertEqual(saved.snapshot.starterPlayerIDs, [homeStarterID, awayStarterID])
        XCTAssertEqual(saved.role(of: homeStarterID), .starter)
        XCTAssertEqual(saved.role(of: awayStarterID), .starter)
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

    func testMergePlayerPreservesPreviousAndUndoSnapshots() throws {
        let targetID = uuid("00000000-0000-0000-0000-000000005001")
        let sourceID = uuid("00000000-0000-0000-0000-000000005002")
        let homeTeamID = uuid("00000000-0000-0000-0000-000000005011")
        let awayTeamID = uuid("00000000-0000-0000-0000-000000005012")

        let store = AppStore()
        store.players = [
            Player(id: targetID, name: "目标"),
            Player(id: sourceID, name: "来源")
        ]
        store.teams = [
            Team(id: homeTeamID, name: "主队", playerIDs: [targetID, sourceID]),
            Team(id: awayTeamID, name: "客队", playerIDs: [])
        ]

        var currentSnapshot = GameSnapshot(homeTeamID: homeTeamID, awayTeamID: awayTeamID)
        currentSnapshot.statsByPlayerID[sourceID] = {
            var s = PlayerStats(); s.twoMade = 1; return s
        }()

        var previousSnapshot = currentSnapshot
        previousSnapshot.statsByPlayerID[sourceID] = {
            var s = PlayerStats(); s.threeMade = 1; return s
        }()

        var undoSnapshot = currentSnapshot
        undoSnapshot.statsByPlayerID[sourceID] = {
            var s = PlayerStats(); s.freeThrowMade = 2; return s
        }()

        let saved = SavedGame(
            savedAt: Date(),
            snapshot: currentSnapshot,
            previousSnapshot: previousSnapshot,
            undoSnapshots: [undoSnapshot],
            homeTeamName: "主队",
            awayTeamName: "客队",
            homePlayerIDs: [targetID, sourceID],
            awayPlayerIDs: [],
            playerNamesByID: [targetID: "目标", sourceID: "来源"]
        )
        store.savedGames = [saved]

        _ = try XCTUnwrap(store.mergePlayer(sourceID: sourceID, into: targetID))

        let merged = try XCTUnwrap(store.savedGames.first)
        XCTAssertNil(merged.snapshot.statsByPlayerID[sourceID])
        XCTAssertEqual(merged.snapshot.statsByPlayerID[targetID]?.twoMade, 1)

        let mergedPrevious = try XCTUnwrap(merged.previousSnapshot)
        XCTAssertNil(mergedPrevious.statsByPlayerID[sourceID])
        XCTAssertEqual(mergedPrevious.statsByPlayerID[targetID]?.threeMade, 1)

        let mergedUndo = try XCTUnwrap(merged.undoSnapshots.first)
        XCTAssertNil(mergedUndo.statsByPlayerID[sourceID])
        XCTAssertEqual(mergedUndo.statsByPlayerID[targetID]?.freeThrowMade, 2)
    }

    func testImportGamePackageUpsertsByGameID() throws {
        let homePlayerID = uuid("00000000-0000-0000-0000-000000006001")
        let awayPlayerID = uuid("00000000-0000-0000-0000-000000006002")
        let homeTeamID = uuid("00000000-0000-0000-0000-000000006011")
        let awayTeamID = uuid("00000000-0000-0000-0000-000000006012")
        let gameID = uuid("00000000-0000-0000-0000-000000006099")

        let source = AppStore()
        source.players = [
            Player(id: homePlayerID, name: "主队球员"),
            Player(id: awayPlayerID, name: "客队球员")
        ]
        source.teams = [
            Team(id: homeTeamID, name: "主队", playerIDs: [homePlayerID]),
            Team(id: awayTeamID, name: "客队", playerIDs: [awayPlayerID])
        ]

        var snapshot = GameSnapshot(homeTeamID: homeTeamID, awayTeamID: awayTeamID)
        snapshot.statsByPlayerID[homePlayerID] = {
            var s = PlayerStats(); s.twoMade = 1; return s
        }()
        let saved = SavedGame(
            id: gameID,
            savedAt: Date(),
            snapshot: snapshot,
            homeTeamName: "主队",
            awayTeamName: "客队",
            homePlayerIDs: [homePlayerID],
            awayPlayerIDs: [awayPlayerID],
            playerNamesByID: [homePlayerID: "主队球员", awayPlayerID: "客队球员"]
        )
        source.savedGames = [saved]

        let base64 = try XCTUnwrap(source.exportGameBase64(saved))
        var package = try XCTUnwrap(source.decodeGamePackage(from: base64))

        let target = AppStore()
        target.players = source.players
        target.teams = source.teams
        target.savedGames = []

        target.importGamePackage(package, importsUnmatchedRoster: false)
        XCTAssertEqual(target.savedGames.count, 1)
        XCTAssertEqual(target.savedGames[0].id, gameID)

        package.game.snapshot.logs.append(GameLogEntry(timestamp: Date(), message: "模拟事件 (2:0)"))
        target.importGamePackage(package, importsUnmatchedRoster: false)

        XCTAssertEqual(target.savedGames.count, 1)
        XCTAssertEqual(target.savedGames[0].id, gameID)
        XCTAssertEqual(target.savedGames[0].snapshot.logs.count, 1)
    }

    func testCorruptedStoredPayloadDoesNotSeedSampleData() {
        // Force-clear CoreData using an explicit save to flush
        let cd = CoreDataStore()
        cd.clearAll()
        cd.stack.save()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "store_meta")
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: "store_games_index")

        // Write corrupt data to old storage key
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: storageKey)

        let store = AppStore()

        // After load: corrupt legacy data should NOT trigger sample data seeding
        XCTAssertTrue(store.players.isEmpty, "Expected empty players, got \(store.players.count)")
        XCTAssertTrue(store.teams.isEmpty, "Expected empty teams, got \(store.teams.count)")
        XCTAssertTrue(store.savedGames.isEmpty)
    }

    private func clearStore() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value)!
    }
}
