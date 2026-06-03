import XCTest
@testable import BasketballRecord

final class GameUndoMultilingualTests: XCTestCase {
    let homePlayerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let awayPlayerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let homeTeamID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let awayTeamID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!

    var store: AppStore!

    override func setUpWithError() throws {
        store = AppStore()
        store.players = [
            Player(id: homePlayerID, name: "张三"),
            Player(id: awayPlayerID, name: "John")
        ]
        store.teams = [
            Team(id: homeTeamID, name: "Home", playerIDs: [homePlayerID]),
            Team(id: awayTeamID, name: "Away", playerIDs: [awayPlayerID])
        ]
        store.savedGames = []
    }

    // MARK: - Helpers

    private func makeSnapshot() -> GameSnapshot {
        var snapshot = GameSnapshot(homeTeamID: homeTeamID, awayTeamID: awayTeamID)
        snapshot.homeOnCourtPlayerIDs = [homePlayerID]
        snapshot.awayOnCourtPlayerIDs = [awayPlayerID]
        return snapshot
    }

    @discardableResult
    private func revertLastAction(in snapshot: inout GameSnapshot) -> Bool {
        guard let lastLog = snapshot.logs.last else { return false }
        let normalized = GameLogFormatter.normalizedMessage(lastLog.message)
        let eventCode = lastLog.eventCode ?? GameLogFormatter.extractEventCode(from: lastLog.message)

        switch eventCode {
        case "event.substitution":
            return revertSubstitution(entry: lastLog, in: &snapshot)
        case "event.late_arrival":
            guard let playerID = lastLog.playerID else { return false }
            snapshot.logs.removeLast()
            if snapshot.homeAvailablePlayerIDs.contains(playerID) {
                snapshot.homeAvailablePlayerIDs.removeAll { $0 == playerID }
            } else if snapshot.awayAvailablePlayerIDs.contains(playerID) {
                snapshot.awayAvailablePlayerIDs.removeAll { $0 == playerID }
            }
            return true
        default:
            let parsed = StatAction.parseLog(normalized)
            guard let action = StatAction.allCases.first(where: { $0.eventCode == eventCode }) ?? parsed?.action else {
                return false
            }

            guard let playerID = lastLog.playerID
                    ?? parsed.flatMap({ resolvePlayerID(forName: $0.playerName, in: snapshot) }),
                  let side = sideOfPlayer(playerID, in: snapshot) else {
                return false
            }

            snapshot.logs.removeLast()

            var stats = snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            guard action.revert(on: &stats) else { return false }
            snapshot.statsByPlayerID[playerID] = stats

            if action == .foul {
                snapshot.currentPeriodFoulsBySide[side.rawValue] = max(0, (snapshot.currentPeriodFoulsBySide[side.rawValue] ?? 0) - 1)
            }
            if action.points > 0 {
                let scoringIDs = side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
                let defendingIDs = side == .home ? snapshot.awayOnCourtPlayerIDs : snapshot.homeOnCourtPlayerIDs
                scoringIDs.forEach { snapshot.plusMinusByPlayerID[$0, default: 0] -= action.points }
                defendingIDs.forEach { snapshot.plusMinusByPlayerID[$0, default: 0] += action.points }
            }
            return true
        }
    }

    private func revertSubstitution(entry: GameLogEntry, in snapshot: inout GameSnapshot) -> Bool {
        guard let incomingID = entry.playerID else { return false }
        guard let side = sideOfPlayer(incomingID, in: snapshot) else { return false }
        let outgoingID: UUID
        if let storedOutgoingID = entry.relatedPlayerID {
            outgoingID = storedOutgoingID
        } else {
            guard let range = entry.message.range(of: " 替换 ") ?? entry.message.range(of: " vs ") else { return false }
            let outgoingName = String(entry.message[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let resolvedID = resolvePlayerID(forName: outgoingName, in: snapshot) else { return false }
            outgoingID = resolvedID
        }
        snapshot.logs.removeLast()
        if side == .home {
            snapshot.homeOnCourtPlayerIDs.removeAll { $0 == incomingID }
            if !snapshot.homeOnCourtPlayerIDs.contains(outgoingID) {
                snapshot.homeOnCourtPlayerIDs.append(outgoingID)
            }
        } else {
            snapshot.awayOnCourtPlayerIDs.removeAll { $0 == incomingID }
            if !snapshot.awayOnCourtPlayerIDs.contains(outgoingID) {
                snapshot.awayOnCourtPlayerIDs.append(outgoingID)
            }
        }
        return true
    }

    private func resolvePlayerID(forName name: String, in snapshot: GameSnapshot) -> UUID? {
        let homeIDs = players(in: snapshot.homeTeamID).map(\.id)
        let awayIDs = players(in: snapshot.awayTeamID).map(\.id)
        let allIDs = Array(Set(homeIDs + awayIDs + Array(snapshot.statsByPlayerID.keys)))
        return allIDs.first { store.player(for: $0)?.name == name }
    }

    private func players(in teamID: UUID?) -> [Player] {
        guard let team = store.team(for: teamID) else { return [] }
        return team.playerIDs.compactMap { store.player(for: $0) }
    }

    private func sideOfPlayer(_ playerID: UUID, in snapshot: GameSnapshot) -> TeamSide? {
        let homeIDs = Set(players(in: snapshot.homeTeamID).map(\.id))
        let awayIDs = Set(players(in: snapshot.awayTeamID).map(\.id))
        if homeIDs.contains(playerID) { return .home }
        if awayIDs.contains(playerID) { return .away }
        return nil
    }

    private func recordStat(action: StatAction, playerID: UUID, in snapshot: inout GameSnapshot, message: String) {
        var stats = snapshot.statsByPlayerID[playerID, default: PlayerStats()]
        action.apply(to: &stats)
        snapshot.statsByPlayerID[playerID] = stats
        if action == .foul {
            guard let side = sideOfPlayer(playerID, in: snapshot) else { return }
            snapshot.currentPeriodFoulsBySide[side.rawValue, default: 0] += 1
        }
        if action.points > 0 {
            guard let side = sideOfPlayer(playerID, in: snapshot) else { return }
            let scoringIDs = side == .home ? snapshot.homeOnCourtPlayerIDs : snapshot.awayOnCourtPlayerIDs
            let defendingIDs = side == .home ? snapshot.awayOnCourtPlayerIDs : snapshot.homeOnCourtPlayerIDs
            scoringIDs.forEach { snapshot.plusMinusByPlayerID[$0, default: 0] += action.points }
            defendingIDs.forEach { snapshot.plusMinusByPlayerID[$0, default: 0] -= action.points }
        }
        snapshot.logs.append(GameLogEntry(
            timestamp: Date(),
            message: message,
            eventCode: action.eventCode,
            playerID: playerID
        ))
    }

    // MARK: - EventCode → Action Mapping (language-independent)

    func testAllStatActionsMapFromEventCode() {
        let expectedCount = 14
        var foundCount = 0
        for action in StatAction.allCases {
            guard let mapped = StatAction.allCases.first(where: { $0.eventCode == action.eventCode }) else {
                XCTFail("Event code '\(action.eventCode)' did not map to any action")
                return
            }
            XCTAssertEqual(mapped, action)
            foundCount += 1
        }
        XCTAssertEqual(foundCount, expectedCount)
    }

    // MARK: - Multilingual Undo (eventCode + playerID bypass message parsing)

    func testUndoWithChineseMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .twoMade, playerID: homePlayerID, in: &snapshot,
                   message: "张三 2分命中 (2:0)")

        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 1)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoAttempts, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 0)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoAttempts, 0)
    }

    func testUndoWithEnglishMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .threeMade, playerID: awayPlayerID, in: &snapshot,
                   message: "John 3PT Made (3:0)")

        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.threeMade, 1)
        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.threeAttempts, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.threeMade, 0)
        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.threeAttempts, 0)
    }

    func testUndoWithGermanMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .twoMade, playerID: homePlayerID, in: &snapshot,
                   message: "张三 2 Punkte erzielt (2:0)")

        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 0)
    }

    func testUndoWithJapaneseMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .freeThrowMade, playerID: homePlayerID, in: &snapshot,
                   message: "张三 FT成功 (1:0)")

        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.freeThrowMade, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.freeThrowMade, 0)
    }

    func testUndoWithSpanishMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .assist, playerID: homePlayerID, in: &snapshot,
                   message: "张三 Asistencia")

        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.assists, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.assists, 0)
    }

    func testUndoWithKoreanMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .rebound, playerID: awayPlayerID, in: &snapshot,
                   message: "John 리바운드")

        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.rebounds, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.rebounds, 0)
    }

    func testUndoWithFrenchMessage() {
        var snapshot = makeSnapshot()
        recordStat(action: .steal, playerID: homePlayerID, in: &snapshot,
                   message: "张三 Interception")

        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.steals, 1)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.steals, 0)
    }

    // MARK: - Foul & Plus-Minus Side Effects

    func testUndoFoulDecrementsPeriodFouls() {
        var snapshot = makeSnapshot()
        snapshot.currentPeriodFoulsBySide[TeamSide.home.rawValue] = 3
        recordStat(action: .foul, playerID: homePlayerID, in: &snapshot,
                   message: "张三 Foul")

        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.fouls, 1)
        XCTAssertEqual(snapshot.currentPeriodFoulsBySide[TeamSide.home.rawValue], 4)

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.fouls, 0)
        XCTAssertEqual(snapshot.currentPeriodFoulsBySide[TeamSide.home.rawValue], 3)
    }

    func testUndoScoringActionRevertsPlusMinus() {
        var snapshot = makeSnapshot()
        var homeStats = PlayerStats()
        homeStats.threeMade = 1
        homeStats.threeAttempts = 1
        snapshot.statsByPlayerID[homePlayerID] = homeStats
        snapshot.plusMinusByPlayerID[homePlayerID] = 3
        snapshot.plusMinusByPlayerID[awayPlayerID] = -3

        let msg = "张三 3分命中 (3:0)"
        snapshot.logs.append(GameLogEntry(
            timestamp: Date(),
            message: msg,
            eventCode: StatAction.threeMade.eventCode,
            playerID: homePlayerID
        ))

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.threeMade, 0)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.threeAttempts, 0)
        XCTAssertEqual(snapshot.plusMinusByPlayerID[homePlayerID], 0)
        XCTAssertEqual(snapshot.plusMinusByPlayerID[awayPlayerID], 0)
    }

    // MARK: - Substitution Undo

    func testSubstitutionUndoWithRelatedPlayerID() {
        let subIn = homePlayerID
        let subOut = awayPlayerID
        var snapshot = makeSnapshot()
        snapshot.homeOnCourtPlayerIDs = [subOut]
        snapshot.homeAvailablePlayerIDs = [subIn, subOut]

        snapshot.logs.append(GameLogEntry(
            timestamp: Date(),
            message: "张三 vs John 替换",
            eventCode: "event.substitution",
            playerID: subIn,
            relatedPlayerID: subOut
        ))

        snapshot.homeOnCourtPlayerIDs = [subIn]
        snapshot.homeAvailablePlayerIDs = [subIn, subOut]

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertTrue(snapshot.homeOnCourtPlayerIDs.contains(subOut))
        XCTAssertFalse(snapshot.homeOnCourtPlayerIDs.contains(subIn))
    }

    func testSubstitutionUndoEnglishVsPattern() {
        let subIn = homePlayerID
        let subOut = awayPlayerID
        store.players.append(Player(id: subOut, name: "John"))
        var snapshot = makeSnapshot()
        snapshot.homeOnCourtPlayerIDs = [subOut]
        snapshot.homeAvailablePlayerIDs = [subIn, subOut]

        snapshot.logs.append(GameLogEntry(
            timestamp: Date(),
            message: "张三 vs John",
            eventCode: "event.substitution",
            playerID: subIn
        ))

        snapshot.homeOnCourtPlayerIDs = [subIn]

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertTrue(snapshot.homeOnCourtPlayerIDs.contains(subOut))
        XCTAssertFalse(snapshot.homeOnCourtPlayerIDs.contains(subIn))
    }

    // MARK: - Legacy Fallback (no eventCode, no playerID)

    func testLegacyUndoChineseOnly() {
        var snapshot = makeSnapshot()
        var stats = PlayerStats()
        stats.twoMade = 1
        stats.twoAttempts = 1
        snapshot.statsByPlayerID[homePlayerID] = stats
        snapshot.logs.append(GameLogEntry(
            timestamp: Date(),
            message: "张三 2分命中 (2:0)",
            eventCode: nil,
            playerID: nil
        ))

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result, "Legacy Chinese-only undo should succeed via parseLog fallback")
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 0)
    }

    func testLegacyUndoWithoutEventCodeButWithPlayerID() {
        var snapshot = makeSnapshot()
        var stats = PlayerStats()
        stats.twoMade = 1
        stats.twoAttempts = 1
        snapshot.statsByPlayerID[homePlayerID] = stats
        snapshot.logs.append(GameLogEntry(
            timestamp: Date(),
            message: "张三 2分命中 (2:0)",
            eventCode: nil,
            playerID: homePlayerID
        ))

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 0)
    }

    // MARK: - Apply / Revert Round-Trip for All Stat Types

    func testApplyRevertRoundTripAllStatActions() {
        let actionPlayerPairs: [(StatAction, UUID)] = [
            (.twoMade, homePlayerID), (.twoMissed, homePlayerID),
            (.threeMade, awayPlayerID), (.threeMissed, awayPlayerID),
            (.freeThrowMade, homePlayerID), (.freeThrowMissed, homePlayerID),
            (.foul, awayPlayerID), (.assist, homePlayerID),
            (.rebound, awayPlayerID), (.block, homePlayerID),
            (.steal, awayPlayerID), (.turnover, homePlayerID)
        ]

        for (action, playerID) in actionPlayerPairs {
            var snapshot = makeSnapshot()
            let player = store.player(for: playerID)!
            let msg = "\(player.name) \(action.message) (2:0)"

            recordStat(action: action, playerID: playerID, in: &snapshot, message: msg)

            let revertResult = revertLastAction(in: &snapshot)
            XCTAssertTrue(revertResult, "Revert failed for \(action)")

            let stats = snapshot.statsByPlayerID[playerID] ?? PlayerStats()
            XCTAssertEqual(stats.twoMade, 0)
            XCTAssertEqual(stats.twoAttempts, 0)
            XCTAssertEqual(stats.threeMade, 0)
            XCTAssertEqual(stats.threeAttempts, 0)
            XCTAssertEqual(stats.freeThrowMade, 0)
            XCTAssertEqual(stats.freeThrowAttempts, 0)
            XCTAssertEqual(stats.fouls, 0)
            XCTAssertEqual(stats.assists, 0)
            XCTAssertEqual(stats.rebounds, 0)
            XCTAssertEqual(stats.blocks, 0)
            XCTAssertEqual(stats.steals, 0)
            XCTAssertEqual(stats.turnovers, 0)
            XCTAssertEqual(snapshot.logs.count, 0)
        }
    }

    func testMultipleStatsAndUndoInSequence() {
        var snapshot = makeSnapshot()

        recordStat(action: .twoMade, playerID: homePlayerID, in: &snapshot,
                   message: "张三 2分命中 (2:0)")
        recordStat(action: .threeMade, playerID: awayPlayerID, in: &snapshot,
                   message: "John 3分命中 (5:0)")
        recordStat(action: .assist, playerID: homePlayerID, in: &snapshot,
                   message: "张三 助攻")

        XCTAssertEqual(snapshot.logs.count, 3)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 1)
        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.threeMade, 1)
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.assists, 1)

        // Undo assist
        XCTAssertTrue(revertLastAction(in: &snapshot))
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.assists, 0)
        XCTAssertEqual(snapshot.logs.count, 2)

        // Undo threeMade
        XCTAssertTrue(revertLastAction(in: &snapshot))
        XCTAssertEqual(snapshot.statsByPlayerID[awayPlayerID]?.threeMade, 0)
        XCTAssertEqual(snapshot.logs.count, 1)

        // Undo twoMade
        XCTAssertTrue(revertLastAction(in: &snapshot))
        XCTAssertEqual(snapshot.statsByPlayerID[homePlayerID]?.twoMade, 0)
        XCTAssertEqual(snapshot.logs.count, 0)
    }

    func testUndoNonScoringActionNoPlusMinusEffect() {
        var snapshot = makeSnapshot()
        snapshot.plusMinusByPlayerID[homePlayerID] = 5
        snapshot.plusMinusByPlayerID[awayPlayerID] = -5

        recordStat(action: .steal, playerID: homePlayerID, in: &snapshot,
                   message: "张三 Steal")

        let beforePMHome = snapshot.plusMinusByPlayerID[homePlayerID]
        let beforePMAway = snapshot.plusMinusByPlayerID[awayPlayerID]

        let result = revertLastAction(in: &snapshot)
        XCTAssertTrue(result)

        // Non-scoring actions should not affect plus-minus
        XCTAssertEqual(snapshot.plusMinusByPlayerID[homePlayerID], beforePMHome)
        XCTAssertEqual(snapshot.plusMinusByPlayerID[awayPlayerID], beforePMAway)
    }
}
