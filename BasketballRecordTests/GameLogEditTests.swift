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

        let hiddenIDs = GameLogEditLogic.addedThenDeletedEventIDs(in: store.savedGames[gi].snapshot.editHistory)
        XCTAssertTrue(hiddenIDs.contains(e.id))
        XCTAssertFalse(GameLogEditLogic.activeLogs(store.savedGames[gi].snapshot.logs, history: store.savedGames[gi].snapshot.editHistory).contains(where: { $0.id == e.id }))
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

        let filteredLogs = GameLogEditLogic.activeLogs(store.savedGames[gi].snapshot.logs, history: store.savedGames[gi].snapshot.editHistory)
        let twoMadeCount = filteredLogs.filter { $0.eventCode == "stat.twoMade" }.count
        XCTAssertEqual(twoMadeCount, 0)
    }

    func testAnalyzerExcludesDeletedEventFromPeriodStats() throws {
        let (store, gid) = makeGame()
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == gid }),
              let event = store.savedGames[gameIndex].snapshot.logs.first(where: { $0.eventCode == "stat.twoMade" }),
              let playerID = event.playerID else { XCTFail(); return }

        store.savedGames[gameIndex].snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "delete", eventID: event.id,
            previousMessage: event.message, previousEventCode: event.eventCode, previousPlayerID: event.playerID,
            previousTimestamp: event.timestamp, previousPeriod: event.period,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        ))

        let analysis = SavedGameAnalyzer(game: store.savedGames[gameIndex]) { _ in nil }.analyze()

        XCTAssertEqual(analysis.statsByPeriod[1]?[playerID]?.twoMade ?? 0, 0)
    }

    func testDeleteAfterRestoreIsStillExcludedFromPeriodStats() throws {
        let (store, gid) = makeGame()
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == gid }),
              let event = store.savedGames[gameIndex].snapshot.logs.first(where: { $0.eventCode == "stat.assist" }),
              let playerID = event.playerID else { XCTFail(); return }

        let deletion = GameLogEditRecord(
            timestamp: Date(), action: "delete", eventID: event.id,
            previousMessage: event.message, previousEventCode: event.eventCode, previousPlayerID: event.playerID,
            previousTimestamp: event.timestamp, previousPeriod: event.period,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        )
        let restoration = GameLogEditRecord(
            timestamp: Date(), action: "restore", eventID: event.id,
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        )
        store.savedGames[gameIndex].snapshot.editHistory.append(contentsOf: [deletion, restoration, deletion])

        let analysis = SavedGameAnalyzer(game: store.savedGames[gameIndex]) { _ in nil }.analyze()

        XCTAssertEqual(analysis.statsByPeriod[1]?[playerID]?.assists ?? 0, 0)
    }

    func testOnlySupportedStatEventsCanBeEditedAsStats() {
        XCTAssertTrue(GameLogEditLogic.canEditAsStat("stat.twoMade"))
        XCTAssertFalse(GameLogEditLogic.canEditAsStat("event.pause"))
        XCTAssertFalse(GameLogEditLogic.canEditAsStat("event.substitution"))
        XCTAssertFalse(GameLogEditLogic.canEditAsStat("stat.assistTwoMade"))
        XCTAssertFalse(GameLogEditLogic.canEditAsStat(GameLogEntry(timestamp: Date(), message: "暂停 [event:event.pause]")))
    }

    func testLatestDeleteOrRestoreDeterminesEventState() {
        let eventID = UUID()
        let delete = GameLogEditRecord(
            timestamp: Date(), action: "delete", eventID: eventID,
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        )
        let restore = GameLogEditRecord(
            timestamp: Date(), action: "restore", eventID: eventID,
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        )

        XCTAssertEqual(GameLogEditLogic.deletedEventIDs(in: [delete, restore]), [])
        XCTAssertEqual(GameLogEditLogic.deletedEventIDs(in: [delete, restore, delete]), [eventID])
        XCTAssertEqual(GameLogEditLogic.addedThenDeletedEventIDs(in: [delete, restore]), [])
    }

    func testModifyUsesEventIDAfterLogOrderChangesAndCanRestoreTimestamp() {
        var snapshot = GameSnapshot()
        let originalTimestamp = Date(timeIntervalSince1970: 100)
        let target = GameLogEntry(timestamp: originalTimestamp, message: "A 2分命中", eventCode: "stat.twoMade", period: 1, periodElapsedSeconds: 9)
        let inserted = GameLogEntry(timestamp: originalTimestamp.addingTimeInterval(10), message: "B 篮板", eventCode: "stat.rebound")
        snapshot.logs = [target, inserted]
        snapshot.logs.insert(GameLogEntry(timestamp: originalTimestamp.addingTimeInterval(5), message: "新事件", eventCode: "stat.assist"), at: 1)
        snapshot.editHistory.append(GameLogEditRecord(
            timestamp: originalTimestamp, action: "modify", eventID: target.id,
            previousMessage: "A 2分命中", previousEventCode: "stat.twoMade", previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: "A 2分命中", currentEventCode: "stat.twoMade", currentPlayerID: nil
        ))
        let newTimestamp = originalTimestamp.addingTimeInterval(20)

        let modified = GameLogEditLogic.modify(
            snapshot: &snapshot,
            eventID: target.id,
            timestamp: newTimestamp,
            playerID: UUID(),
            eventCode: "stat.threeMade",
            message: "A 3分命中",
            period: 2,
            periodElapsedSeconds: 42
        )

        XCTAssertTrue(modified)
        XCTAssertEqual(snapshot.logs.first(where: { $0.id == target.id })?.timestamp, newTimestamp)
        XCTAssertEqual(snapshot.logs.first(where: { $0.id == inserted.id })?.eventCode, "stat.rebound")
        XCTAssertTrue(GameLogEditLogic.restoreModification(snapshot: &snapshot, eventID: target.id))
        XCTAssertEqual(snapshot.logs.first(where: { $0.id == target.id })?.timestamp, originalTimestamp)
        XCTAssertEqual(snapshot.logs.first(where: { $0.id == target.id })?.period, 1)
        XCTAssertEqual(snapshot.logs.first(where: { $0.id == target.id })?.periodElapsedSeconds, 9)
    }

    func testOlderEditRecordWithoutPeriodElapsedSecondsStillDecodes() throws {
        let record = GameLogEditRecord(
            timestamp: Date(), action: "modify", eventID: UUID(),
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        )
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        payload.removeValue(forKey: "previousPeriodElapsedSeconds")
        let oldData = try JSONSerialization.data(withJSONObject: payload)

        let decoded = try JSONDecoder().decode(GameLogEditRecord.self, from: oldData)

        XCTAssertNil(decoded.previousPeriodElapsedSeconds)
    }
}
