import XCTest
@testable import BasketballRecord

@MainActor
final class GameLogEditTests: XCTestCase {
    override func setUpWithError() throws {
        UserDefaults.standard.removeObject(forKey: "basketball-record-store-v1")
        CoreDataStore().clearAll()
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.removeObject(forKey: "basketball-record-store-v1")
        CoreDataStore().clearAll()
    }

    private func uuid(_ s: String) -> UUID { UUID(uuidString: s)! }

    private func makeGame() -> (AppStore, UUID) {
        let store = AppStore()
        store.players = []; store.teams = []; store.savedGames = []

        let pid1 = uuid("10000000-0000-0000-0000-000000000001")
        let pid2 = uuid("10000000-0000-0000-0000-000000000002")
        let tid = UUID()
        store.players = [Player(id: pid1, name: "A"), Player(id: pid2, name: "B")]
        store.teams = [Team(id: tid, name: "T", playerIDs: [pid1, pid2])]

        let now = Date()
        var snap = GameSnapshot(homeTeamID: tid, awayTeamID: tid)
        snap.logs = [
            GameLogEntry(timestamp: now, message: "开始", eventCode: "event.period_start"),
            GameLogEntry(timestamp: now + 10, message: "A两分", eventCode: "stat.twoMade", playerID: pid1),
            GameLogEntry(timestamp: now + 20, message: "B助攻", eventCode: "stat.assist", playerID: pid2),
            GameLogEntry(timestamp: now + 30, message: "结束", eventCode: "event.game_end"),
        ]
        snap.isComplete = true
        snap.starterPlayerIDs = [pid1, pid2]
        var s1 = PlayerStats(); s1.twoMade = 1; s1.twoAttempts = 1
        var s2 = PlayerStats(); s2.assists = 1
        snap.statsByPlayerID = [pid1: s1, pid2: s2]

        let g = SavedGame(id: UUID(), savedAt: now, snapshot: snap, homeTeamName: "H", awayTeamName: "A",
                          homePlayerIDs: [pid1, pid2], awayPlayerIDs: [pid1, pid2],
                          playerNamesByID: [pid1: "A", pid2: "B"])
        store.savedGames = [g]
        return (store, g.id)
    }

    func testAddEvent() throws {
        let (store, gid) = makeGame()
        guard let gi = store.savedGames.firstIndex(where: { $0.id == gid }) else { XCTFail(); return }
        let pid1 = uuid("10000000-0000-0000-0000-000000000001")
        let t = store.savedGames[gi].snapshot.logs.first!.timestamp

        let e = GameLogEntry(timestamp: t + 15, message: "A篮板", eventCode: "stat.rebound", playerID: pid1)
        store.savedGames[gi].snapshot.logs.append(e)
        store.savedGames[gi].snapshot.logs.sort { $0.timestamp < $1.timestamp }

        XCTAssertEqual(store.savedGames[gi].snapshot.logs.count, 5)
        XCTAssertTrue(store.savedGames[gi].snapshot.logs.contains(where: { $0.id == e.id }))
    }

    func testModifyPlayer() throws {
        let (store, gid) = makeGame()
        guard let gi = store.savedGames.firstIndex(where: { $0.id == gid }),
              let li = store.savedGames[gi].snapshot.logs.firstIndex(where: { $0.eventCode == "stat.twoMade" }) else { XCTFail(); return }
        let pid2 = uuid("10000000-0000-0000-0000-000000000002")

        let old = store.savedGames[gi].snapshot.logs[li]
        store.savedGames[gi].snapshot.logs[li].playerID = pid2
        store.savedGames[gi].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "modify", eventID: old.id,
            previousMessage: old.message, previousEventCode: old.eventCode, previousPlayerID: old.playerID,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: store.savedGames[gi].snapshot.logs[li].message, currentEventCode: "stat.twoMade", currentPlayerID: pid2
        ))

        XCTAssertEqual(store.savedGames[gi].snapshot.logs[li].playerID, pid2)
        let mods = store.savedGames[gi].snapshot.editHistory.filter { $0.action == "modify" && $0.eventID == old.id }
        XCTAssertEqual(mods.count, 1)
    }

    func testDeleteAndRestore() throws {
        let (store, gid) = makeGame()
        guard let gi = store.savedGames.firstIndex(where: { $0.id == gid }),
              let ev = store.savedGames[gi].snapshot.logs.first(where: { $0.eventCode == "stat.assist" }) else { XCTFail(); return }

        store.savedGames[gi].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "delete", eventID: ev.id,
            previousMessage: ev.message, previousEventCode: ev.eventCode, previousPlayerID: ev.playerID,
            previousTimestamp: ev.timestamp, previousPeriod: ev.period,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        ))
        store.savedGames[gi].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "restore", eventID: ev.id,
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        ))

        let dels = store.savedGames[gi].snapshot.editHistory.filter { $0.action == "delete" && $0.eventID == ev.id }
        let rests = store.savedGames[gi].snapshot.editHistory.filter { $0.action == "restore" && $0.eventID == ev.id }
        XCTAssertEqual(dels.count, 1)
        XCTAssertEqual(rests.count, 1)
    }

    func testAddedThenDeletedVanishes() throws {
        let (store, gid) = makeGame()
        guard let gi = store.savedGames.firstIndex(where: { $0.id == gid }) else { XCTFail(); return }
        let pid1 = uuid("10000000-0000-0000-0000-000000000001")
        let t = store.savedGames[gi].snapshot.logs.first!.timestamp

        let e = GameLogEntry(timestamp: t + 25, message: "A三分", eventCode: "stat.threeMade", playerID: pid1)
        store.savedGames[gi].snapshot.logs.append(e)
        store.savedGames[gi].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "add", eventID: e.id,
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: e.message, currentEventCode: e.eventCode, currentPlayerID: e.playerID
        ))
        store.savedGames[gi].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "delete", eventID: e.id,
            previousMessage: e.message, previousEventCode: e.eventCode, previousPlayerID: e.playerID,
            previousTimestamp: e.timestamp, previousPeriod: e.period,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        ))

        let addIDs = Set(store.savedGames[gi].snapshot.editHistory.filter { $0.action == "add" }.map(\.eventID))
        let delIDs = Set(store.savedGames[gi].snapshot.editHistory.filter { $0.action == "delete" }.map(\.eventID))
        let restIDs = Set(store.savedGames[gi].snapshot.editHistory.filter { $0.action == "restore" }.map(\.eventID))
        let deletedVisible = delIDs.subtracting(restIDs).subtracting(addIDs)
        XCTAssertFalse(deletedVisible.contains(e.id))
    }

    func testStatsExcludeDeleted() throws {
        let (store, gid) = makeGame()
        guard let gi = store.savedGames.firstIndex(where: { $0.id == gid }),
              let ev = store.savedGames[gi].snapshot.logs.first(where: { $0.eventCode == "stat.twoMade" }) else { XCTFail(); return }

        store.savedGames[gi].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "delete", eventID: ev.id,
            previousMessage: ev.message, previousEventCode: ev.eventCode, previousPlayerID: ev.playerID,
            previousTimestamp: ev.timestamp, previousPeriod: ev.period,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        ))

        let deletedIDs = Set(store.savedGames[gi].snapshot.editHistory.filter { $0.action == "delete" }.map(\.eventID))
        let filteredLogs = store.savedGames[gi].snapshot.logs.filter { !deletedIDs.contains($0.id) }
        let twoMadeCount = filteredLogs.filter { $0.eventCode == "stat.twoMade" }.count
        XCTAssertEqual(twoMadeCount, 0)
    }
}
