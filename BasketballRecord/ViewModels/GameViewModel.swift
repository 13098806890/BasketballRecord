import Foundation
import SwiftUI

@MainActor
class GameViewModel: ObservableObject {
    @Published var snapshot = GameSnapshot()
    @Published var undoStack: [GameSnapshot] = []
    @Published var redoStack: [GameSnapshot] = []

    func mutateSnapshot(pushUndo: Bool = true, _ updates: () -> Void) {
        if pushUndo {
            undoStack.append(snapshot)
            if undoStack.count > 30 { undoStack.removeFirst(undoStack.count - 30) }
        }
        redoStack.removeAll()
        updates()
    }

    func undo() {
        guard let last = undoStack.last else { return }
        redoStack.append(snapshot)
        snapshot = last
        undoStack.removeLast()
    }

    func redo() {
        guard let last = redoStack.last else { return }
        undoStack.append(snapshot)
        snapshot = last
        redoStack.removeLast()
    }

    func resetGame() {
        snapshot = GameSnapshot()
        undoStack.removeAll()
        redoStack.removeAll()
    }

    func addEvent(_ message: String, playerID: UUID? = nil, relatedPlayerID: UUID? = nil, eventCode: String? = nil, at: Date? = nil) {
        let context = eventPeriodContext(for: message, eventCode: eventCode)
        let logEntry = GameLogEntry(
            timestamp: at ?? Date(),
            message: message,
            eventCode: eventCode,
            playerID: playerID,
            relatedPlayerID: relatedPlayerID,
            period: context.period,
            periodElapsedSeconds: context.periodElapsedSeconds
        )
        snapshot.logs.append(logEntry)
    }

    func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return snapshot.teamStatsByID[teamID, default: PlayerStats()].points
    }

    private func eventPeriodContext(for message: String, eventCode: String?) -> (period: Int?, periodElapsedSeconds: TimeInterval?) {
        let nonPeriodEventCodes: Set<String> = ["event.game_end", "event.game_saved"]
        let nonPeriodMessages: Set<String> = [
            NSLocalizedString("event_game_end", comment: "Game end event"),
            NSLocalizedString("event_game_saved", comment: "Game saved event")
        ]

        if let eventCode,
           nonPeriodEventCodes.contains(eventCode) {
            return (nil, nil)
        }

        guard !nonPeriodMessages.contains(message), snapshot.currentPeriod > 0 else {
            return (nil, nil)
        }

        let elapsed: TimeInterval
        if snapshot.periodIsRunning,
           !snapshot.isPaused,
           let activeSince = snapshot.periodActiveSince {
            elapsed = snapshot.periodElapsedSeconds + max(0, Date().timeIntervalSince(activeSince))
        } else {
            elapsed = snapshot.periodElapsedSeconds
        }

        return (snapshot.currentPeriod, max(0, elapsed))
    }
}
