import XCTest
@testable import BasketballRecord

@MainActor
final class DataCompatibilityTests: XCTestCase {
    private let storageKey = "basketball-record-store-v1"
    private let metaKey = "store_meta"
    private let gamesIndexKey = "store_games_index"
    private func gameKey(for id: UUID) -> String { "game_\(id.uuidString)" }

    override func setUp() async throws {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: metaKey)
        UserDefaults.standard.removeObject(forKey: gamesIndexKey)
        CoreDataStore().clearAll()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        CoreDataStore().clearAll()
    }

    // MARK: - JSON Round-trip (Core Data stores JSON in snapshotData)

    func testSavedGameJSONRoundTrip() throws {
        var stats = PlayerStats()
        stats.twoMade = 5; stats.twoAttempts = 10; stats.threeMade = 2; stats.threeAttempts = 6
        let snapshot = GameSnapshot(statsByPlayerID: [uuid("1001"): stats])
        let game = SavedGame(
            id: uuid("2001"),
            savedAt: Date(),
            snapshot: snapshot,
            homeTeamName: "Home",
            awayTeamName: "Away",
            homePlayerIDs: [uuid("1001"), uuid("1002")],
            awayPlayerIDs: [uuid("1003")],
            playerNamesByID: [uuid("1001"): "Alice", uuid("1002"): "Bob"]
        )

        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(SavedGame.self, from: data)

        XCTAssertEqual(decoded.id, uuid("2001"))
        XCTAssertEqual(decoded.homeTeamName, "Home")
        XCTAssertEqual(decoded.awayTeamName, "Away")
        XCTAssertEqual(decoded.homePlayerIDs, [uuid("1001"), uuid("1002")])
        XCTAssertEqual(decoded.awayPlayerIDs, [uuid("1003")])
        XCTAssertEqual(decoded.snapshot.statsByPlayerID[uuid("1001")]?.twoMade, 5)
        XCTAssertEqual(decoded.snapshot.statsByPlayerID[uuid("1001")]?.threeMade, 2)
    }

    func testGameSnapshotJSONRoundTrip() throws {
        var stats = PlayerStats()
        stats.twoMade = 4
        stats.twoAttempts = 8
        stats.threeMade = 1
        stats.threeAttempts = 3
        stats.rebounds = 7
        stats.assists = 3
        stats.fouls = 2

        let snapshot = GameSnapshot(
            statsByPlayerID: [uuid("1001"): stats],
            homeTeamID: uuid("3001"),
            awayTeamID: uuid("3002"),
            homeOnCourtPlayerIDs: [uuid("1001")],
            awayOnCourtPlayerIDs: [uuid("1002")]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)

        let decodedStats = decoded.statsByPlayerID[uuid("1001")]
        XCTAssertEqual(decodedStats?.twoMade, 4)
        XCTAssertEqual(decodedStats?.rebounds, 7)
        XCTAssertEqual(decoded.homeTeamID, uuid("3001"))
        XCTAssertEqual(decoded.awayTeamID, uuid("3002"))
    }

    func testPlayerRoundTrip() throws {
        let player = Player(id: uuid("4001"), name: "TestPlayer", height: "180", weight: "75", number: "23")
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: data)
        XCTAssertEqual(decoded.id, uuid("4001"))
        XCTAssertEqual(decoded.name, "TestPlayer")
        XCTAssertEqual(decoded.height, "180")
        XCTAssertEqual(decoded.weight, "75")
        XCTAssertEqual(decoded.number, "23")
    }

    func testTeamRoundTrip() throws {
        let team = Team(id: uuid("5001"), name: "TestTeam", playerIDs: [uuid("4001"), uuid("4002")])
        let data = try JSONEncoder().encode(team)
        let decoded = try JSONDecoder().decode(Team.self, from: data)
        XCTAssertEqual(decoded.id, uuid("5001"))
        XCTAssertEqual(decoded.name, "TestTeam")
        XCTAssertEqual(decoded.playerIDs, [uuid("4001"), uuid("4002")])
    }

    func testGameGroupRoundTrip() throws {
        let group = GameGroup(id: uuid("6001"), name: "Tournament", description: "Summer league", createdAt: Date(), color: "#FF0000")
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(GameGroup.self, from: data)
        XCTAssertEqual(decoded.id, uuid("6001"))
        XCTAssertEqual(decoded.name, "Tournament")
        XCTAssertEqual(decoded.description, "Summer league")
        XCTAssertEqual(decoded.color, "#FF0000")
    }

    // MARK: - Core Data Persistence

    func testCoreDataPlayerPersistence() async throws {
        let store = CoreDataStore()
        let player = Player(id: uuid("7001"), name: "CoreDataPlayer")
        store.savePlayers([player])

        let fetched = store.fetchAllPlayers()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, uuid("7001"))
        XCTAssertEqual(fetched[0].name, "CoreDataPlayer")
    }

    func testCoreDataTeamPersistence() async throws {
        let store = CoreDataStore()
        let team = Team(id: uuid("8001"), name: "CoreDataTeam", playerIDs: [uuid("7001"), uuid("7002")])
        store.saveTeams([team])

        let fetched = store.fetchAllTeams()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, uuid("8001"))
        XCTAssertEqual(fetched[0].playerIDs, [uuid("7001"), uuid("7002")])
    }

    func testCoreDataGamePersistence() async throws {
        let store = CoreDataStore()
        var stats = PlayerStats()
        stats.twoMade = 3; stats.twoAttempts = 7
        let snapshot = GameSnapshot(statsByPlayerID: [uuid("7001"): stats])
        let game = SavedGame(
            id: uuid("9001"),
            savedAt: Date(),
            snapshot: snapshot,
            homeTeamName: "HomeTeam",
            awayTeamName: "AwayTeam",
            homePlayerIDs: [uuid("7001")],
            awayPlayerIDs: [uuid("7002")],
            playerNamesByID: [uuid("7001"): "Alice"],
            groupIDs: [uuid("6001")]
        )
        store.upsertSavedGame(game)

        let fetched = store.fetchAllSavedGames()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, uuid("9001"))
        XCTAssertEqual(fetched[0].homeTeamName, "HomeTeam")
        XCTAssertEqual(fetched[0].snapshot.statsByPlayerID[uuid("7001")]?.twoMade, 3)
        XCTAssertEqual(fetched[0].groupIDs, [uuid("6001")])

        // Test update
        var updated = game
        updated.homeTeamName = "UpdatedHome"
        store.upsertSavedGame(updated)

        let refetched = store.fetchAllSavedGames()
        XCTAssertEqual(refetched.count, 1)
        XCTAssertEqual(refetched[0].homeTeamName, "UpdatedHome")

        // Test delete
        store.deleteSavedGame(id: uuid("9001"))
        let afterDelete = store.fetchAllSavedGames()
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testCoreDataGroupPersistence() async throws {
        let store = CoreDataStore()
        let group = GameGroup(id: uuid("6001"), name: "CDGroup", description: nil, createdAt: Date(), color: nil)
        store.saveGameGroups([group])

        let fetched = store.fetchAllGameGroups()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, uuid("6001"))
        XCTAssertEqual(fetched[0].name, "CDGroup")
    }

    // MARK: - Legacy Migration Compatibility

    func testPlayerWithNilPhotoMigratesCorrectly() throws {
        let player = Player(id: uuid("1001"), name: "PhotoTest", photoData: nil)
        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: data)
        XCTAssertNil(decoded.photoData)
    }

    func testGameWithEmptyUndoSnapshotsRoundTrip() throws {
        let game = SavedGame(
            id: uuid("3001"),
            savedAt: Date(),
            snapshot: GameSnapshot(),
            undoSnapshots: [],
            homeTeamName: "A",
            awayTeamName: "B",
            homePlayerIDs: [],
            awayPlayerIDs: [],
            playerNamesByID: [:]
        )
        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(SavedGame.self, from: data)
        XCTAssertTrue(decoded.undoSnapshots.isEmpty)
    }

    func testGameWithGroupIDsRoundTrip() throws {
        let game = SavedGame(
            id: uuid("4001"),
            savedAt: Date(),
            snapshot: GameSnapshot(),
            homeTeamName: "X",
            awayTeamName: "Y",
            homePlayerIDs: [],
            awayPlayerIDs: [],
            playerNamesByID: [:],
            groupIDs: [uuid("5001"), uuid("5002")]
        )
        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(SavedGame.self, from: data)
        XCTAssertEqual(decoded.groupIDs, [uuid("5001"), uuid("5002")])
    }

    func testPlayerStatsCodingAllFields() throws {
        var stats = PlayerStats()
        stats.twoMade = 10; stats.twoAttempts = 20
        stats.threeMade = 4; stats.threeAttempts = 10
        stats.freeThrowMade = 5; stats.freeThrowAttempts = 6
        stats.bonusFreeThrowMade = 2; stats.bonusFreeThrowAttempts = 3
        stats.rebounds = 8; stats.assists = 6; stats.fouls = 3
        stats.blocks = 2; stats.steals = 1; stats.turnovers = 4

        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(PlayerStats.self, from: data)

        XCTAssertEqual(decoded.points, 10*2 + 4*3 + 7)
        XCTAssertEqual(decoded.fouls, 3)
        XCTAssertEqual(decoded.rebounds, 8)
        XCTAssertEqual(decoded.fieldGoalRate, 14.0/30.0)
        XCTAssertEqual(decoded.effectiveFieldGoalRate, (10 + 4 + 0.5*4) / 30.0)
    }

    // MARK: - Backward Compat: Legacy single groupID

    func testLegacySingleGroupIDDecoding() throws {
        let savedAt = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let game = SavedGame(
            id: uuid("A0000000-0000-0000-0000-000000000001"),
            savedAt: savedAt,
            snapshot: GameSnapshot(),
            homeTeamName: "Home",
            awayTeamName: "Away",
            homePlayerIDs: [],
            awayPlayerIDs: [],
            playerNamesByID: [:]
        )
        // Simulate legacy encoding with groupID instead of groupIDs
        let legacyData = try JSONEncoder().encode(LegacyGameWrapper(
            id: game.id, savedAt: game.savedAt,
            snapshot: game.snapshot,
            homeTeamName: game.homeTeamName, awayTeamName: game.awayTeamName,
            homePlayerIDs: game.homePlayerIDs, awayPlayerIDs: game.awayPlayerIDs,
            playerNamesByID: game.playerNamesByID,
            groupID: uuid("B0000000-0000-0000-0000-000000000002")
        ))
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SavedGame.self, from: legacyData)
        XCTAssertEqual(decoded.groupIDs, [uuid("B0000000-0000-0000-0000-000000000002")])
    }

    private struct LegacyGameWrapper: Codable {
        var id: UUID
        var savedAt: Date
        var snapshot: GameSnapshot
        var homeTeamName: String
        var awayTeamName: String
        var homePlayerIDs: [UUID]
        var awayPlayerIDs: [UUID]
        var playerNamesByID: [UUID: String]
        var groupID: UUID

        enum CodingKeys: String, CodingKey {
            case id, savedAt, snapshot, homeTeamName, awayTeamName
            case homePlayerIDs, awayPlayerIDs, playerNamesByID, groupID
        }
    }

    // MARK: - Cloud Enabled Game IDs

    func testCloudEnabledGameIDPersistence() {
        let ids: Set<UUID> = [uuid("C001"), uuid("C002")]
        let array = ids.map(\.uuidString)
        NSUbiquitousKeyValueStore.default.set(array, forKey: "cloud_enabled_game_ids")
        let loaded = (NSUbiquitousKeyValueStore.default.array(forKey: "cloud_enabled_game_ids") as? [String])?
            .compactMap(UUID.init)
        XCTAssertEqual(Set(loaded ?? []), ids)
    }

    // MARK: - Helpers

    private func uuid(_ value: String) -> UUID {
        let padded = value.count == 4
            ? "00000000-0000-0000-0000-\(String(repeating: "0", count: 12 - value.count))\(value)"
            : value
        guard let uuid = UUID(uuidString: padded) else {
            fatalError("Invalid UUID string: \(padded)")
        }
        return uuid
    }

    // MARK: - Team Stats Mode Serialization

    func testTeamStatsModeFlagsRoundTrip() throws {
        var snapshot = GameSnapshot(homeTeamID: uuid("1001"), awayTeamID: uuid("1002"))
        snapshot.homeTeamStatsMode = true
        snapshot.awayTeamStatsMode = true

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)

        XCTAssertTrue(decoded.homeTeamStatsMode, "homeTeamStatsMode should persist through encode/decode")
        XCTAssertTrue(decoded.awayTeamStatsMode, "awayTeamStatsMode should persist through encode/decode")
    }

    func testTeamStatsByIDRoundTrip() throws {
        var snapshot = GameSnapshot(homeTeamID: uuid("1001"), awayTeamID: uuid("1002"))
        var teamStats = PlayerStats()
        teamStats.twoMade = 5
        teamStats.twoAttempts = 8
        teamStats.threeMade = 2
        teamStats.threeAttempts = 5
        teamStats.freeThrowMade = 3
        teamStats.freeThrowAttempts = 4
        teamStats.rebounds = 10
        teamStats.assists = 7
        teamStats.fouls = 4
        teamStats.blocks = 2
        teamStats.steals = 3
        teamStats.turnovers = 5
        snapshot.teamStatsByID[uuid("1001")] = teamStats

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)

        let decodedStats = decoded.teamStatsByID[uuid("1001")]
        XCTAssertNotNil(decodedStats, "teamStatsByID should persist through encode/decode")
        XCTAssertEqual(decodedStats?.twoMade, 5)
        XCTAssertEqual(decodedStats?.threeMade, 2)
        XCTAssertEqual(decodedStats?.freeThrowMade, 3)
        XCTAssertEqual(decodedStats?.rebounds, 10)
        XCTAssertEqual(decodedStats?.assists, 7)
        XCTAssertEqual(decodedStats?.points, 5*2 + 2*3 + 3)
    }

    func testSavedGameWithTeamStatsRoundTrip() throws {
        var snapshot = GameSnapshot(homeTeamID: uuid("1001"), awayTeamID: uuid("1002"))
        snapshot.homeTeamStatsMode = true
        snapshot.awayTeamStatsMode = false
        var teamStats = PlayerStats()
        teamStats.twoMade = 10
        teamStats.twoAttempts = 15
        snapshot.teamStatsByID[uuid("1001")] = teamStats

        let game = SavedGame(
            id: uuid("3001"),
            savedAt: Date(),
            snapshot: snapshot,
            homeTeamName: "湘北",
            awayTeamName: "陵南",
            homePlayerIDs: [],
            awayPlayerIDs: [],
            playerNamesByID: [:]
        )

        let data = try JSONEncoder().encode(game)
        let decoded = try JSONDecoder().decode(SavedGame.self, from: data)

        XCTAssertTrue(decoded.snapshot.homeTeamStatsMode, "homeTeamStatsMode should survive SavedGame round-trip")
        XCTAssertFalse(decoded.snapshot.awayTeamStatsMode, "awayTeamStatsMode should survive SavedGame round-trip")

        let decodedStats = decoded.snapshot.teamStatsByID[uuid("1001")]
        XCTAssertNotNil(decodedStats, "teamStatsByID should survive SavedGame round-trip")
        XCTAssertEqual(decodedStats?.twoMade, 10)
        XCTAssertEqual(decoded.score(forTeamID: uuid("1001")), 20, "score(forTeamID:) should return team stats points")
    }
}
