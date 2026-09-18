import Foundation

enum GameLogEditLogic {
    static let shotActions: [StatAction] = [
        .twoMade, .twoMissed, .threeMade, .threeMissed,
        .layupMade, .layupMissed, .midRangeMade, .midRangeMissed, .paintMade, .paintMissed,
        .dunkMade, .dunkMissed, .putbackMade, .putbackMissed, .bonusMade, .bonusMissed,
        .freeThrowMade, .freeThrowMissed
    ]

    static let statActions: [StatAction] = [
        .assist, .rebound, .offensiveRebound, .defensiveRebound,
        .block, .steal, .turnover, .foul
    ]

    static var editableActions: [StatAction] { shotActions + statActions }

    static func canEditAsStat(_ eventCode: String?) -> Bool {
        guard let eventCode else { return false }
        return editableActions.contains { $0.eventCode == eventCode }
    }

    static func canEditAsStat(_ entry: GameLogEntry) -> Bool {
        canEditAsStat(entry.eventCode ?? GameLogFormatter.extractEventCode(from: entry.message))
    }

    static func deletedEventIDs(in history: [GameLogEditRecord]) -> Set<UUID> {
        var deleted = Set<UUID>()
        for record in history {
            if record.action == "delete" {
                deleted.insert(record.eventID)
            } else if record.action == "restore" {
                deleted.remove(record.eventID)
            }
        }
        return deleted
    }

    static func addedThenDeletedEventIDs(in history: [GameLogEditRecord]) -> Set<UUID> {
        let added = Set(history.filter { $0.action == "add" }.map(\.eventID))
        return deletedEventIDs(in: history).intersection(added)
    }

    static func activeLogs(_ logs: [GameLogEntry], history: [GameLogEditRecord]) -> [GameLogEntry] {
        let deleted = deletedEventIDs(in: history)
        return logs.filter { !deleted.contains($0.id) }
    }

    @discardableResult
    static func modify(
        snapshot: inout GameSnapshot,
        eventID: UUID,
        timestamp: Date,
        playerID: UUID,
        eventCode: String,
        message: String,
        period: Int?,
        periodElapsedSeconds: TimeInterval?
    ) -> Bool {
        guard canEditAsStat(eventCode),
              let logIndex = snapshot.logs.firstIndex(where: { $0.id == eventID }) else { return false }

        let previous = snapshot.logs[logIndex]
        snapshot.logs[logIndex].timestamp = timestamp
        snapshot.logs[logIndex].playerID = playerID
        snapshot.logs[logIndex].eventCode = eventCode
        snapshot.logs[logIndex].message = message
        snapshot.logs[logIndex].period = period
        snapshot.logs[logIndex].periodElapsedSeconds = periodElapsedSeconds
        snapshot.logs.sort { $0.timestamp < $1.timestamp }
        snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(),
            action: "modify",
            eventID: eventID,
            previousMessage: previous.message,
            previousEventCode: previous.eventCode,
            previousPlayerID: previous.playerID,
            previousTimestamp: previous.timestamp,
            previousPeriod: previous.period,
            previousPeriodElapsedSeconds: previous.periodElapsedSeconds,
            currentMessage: message,
            currentEventCode: eventCode,
            currentPlayerID: playerID
        ))
        return true
    }

    @discardableResult
    static func restoreModification(snapshot: inout GameSnapshot, eventID: UUID) -> Bool {
        guard let logIndex = snapshot.logs.firstIndex(where: { $0.id == eventID }),
              let record = snapshot.editHistory.first(where: { $0.eventID == eventID && $0.action == "modify" }) else { return false }
        let timestampRecord = snapshot.editHistory.first { $0.eventID == eventID && $0.action == "modify" && $0.previousTimestamp != nil } ?? record

        if let message = record.previousMessage { snapshot.logs[logIndex].message = message }
        snapshot.logs[logIndex].eventCode = record.previousEventCode
        snapshot.logs[logIndex].playerID = record.previousPlayerID
        if let timestamp = timestampRecord.previousTimestamp {
            snapshot.logs[logIndex].timestamp = timestamp
            snapshot.logs[logIndex].period = timestampRecord.previousPeriod
            snapshot.logs[logIndex].periodElapsedSeconds = timestampRecord.previousPeriodElapsedSeconds
        }
        snapshot.logs.sort { $0.timestamp < $1.timestamp }
        snapshot.editHistory.removeAll { $0.eventID == eventID && $0.action == "modify" }
        return true
    }
}
