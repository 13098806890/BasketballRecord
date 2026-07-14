import Foundation

struct PeriodAwareLog: Identifiable, Hashable {
    var entry: GameLogEntry
    var inferredPeriod: Int?
    var resolvedPlayerID: UUID?
    var id: UUID { entry.id }
}

struct SavedGamePeriodAnalysis {
    var logs: [PeriodAwareLog] = []
    var statsByPeriod: [Int: [UUID: PlayerStats]] = [:]
    var plusMinusByPeriod: [Int: [UUID: Int]] = [:]

    func logs(for period: Int?) -> [PeriodAwareLog] {
        guard let period else { return logs }
        return logs.filter { $0.inferredPeriod == period }
    }

    func statsByPlayerID(for period: Int?) -> [UUID: PlayerStats] {
        guard let period else { return [:] }
        return statsByPeriod[period] ?? [:]
    }

    func plusMinusByPlayerID(for period: Int?) -> [UUID: Int] {
        guard let period else { return [:] }
        return plusMinusByPeriod[period] ?? [:]
    }

    func playerLogs(for playerID: UUID, period: Int?) -> [PeriodAwareLog] {
        logs(for: period).filter { $0.resolvedPlayerID == playerID }
    }
}

struct SavedGameAnalyzer {
    var game: SavedGame
    var resolvePlayerIDByName: (String) -> UUID?

    private var playerNameCandidates: [(id: UUID, name: String)] {
        game.playerNamesByID
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }
    }

    func analyze() -> SavedGamePeriodAnalysis {
        var currentPeriod = 1
        var logs: [PeriodAwareLog] = []
        var statsByPeriod: [Int: [UUID: PlayerStats]] = [:]
        var plusMinusByPeriod: [Int: [UUID: Int]] = [:]
        var homeOnCourt: Set<UUID> = []
        var awayOnCourt: Set<UUID> = []

        let allPlayerIDs = Set(game.homePlayerIDs + game.awayPlayerIDs)
        let homeIDs = Set(game.homePlayerIDs)
        if game.snapshot.startersRecorded {
            let starters = Set(game.snapshot.starterPlayerIDs).intersection(allPlayerIDs)
            homeOnCourt = starters.intersection(homeIDs)
            awayOnCourt = starters.subtracting(homeIDs)
        } else {
            homeOnCourt = homeIDs
            awayOnCourt = Set(game.awayPlayerIDs)
        }

        for entry in game.snapshot.logs {
            let normalizedMessage = GameLogFormatter.normalizedMessage(entry.message)
            var inferredPeriod = entry.period

            if inferredPeriod == nil {
                inferredPeriod = currentPeriod
            }

            // Update currentPeriod: eventCode preferred, message fallback for old games
            if let code = entry.eventCode {
                if code == "event.period_start" {
                    currentPeriod = inferredPeriod ?? currentPeriod
                } else if code == "event.period_end", let ep = inferredPeriod {
                    currentPeriod = max(ep + 1, 1)
                } else {
                    currentPeriod = inferredPeriod ?? currentPeriod
                }
            } else {
                if let startedPeriod = GameLogFormatter.startedPeriodNumber(from: normalizedMessage) {
                    currentPeriod = startedPeriod
                    inferredPeriod = startedPeriod
                } else if let endedPeriod = GameLogFormatter.endedPeriodNumber(from: normalizedMessage) {
                    currentPeriod = max(endedPeriod + 1, 1)
                    inferredPeriod = endedPeriod
                } else {
                    currentPeriod = inferredPeriod ?? currentPeriod
                }
            }

            // Handle control events for on-court tracking
            if let code = entry.eventCode {
                if code == "event.period_start" {
                    if game.snapshot.startersRecorded {
                        let starters = Set(game.snapshot.starterPlayerIDs).intersection(allPlayerIDs)
                        homeOnCourt = starters.intersection(homeIDs)
                        awayOnCourt = starters.subtracting(homeIDs)
                    }
                } else if code == "event.substitution", let incoming = entry.playerID, let outgoing = entry.relatedPlayerID {
                    if homeOnCourt.contains(outgoing) { homeOnCourt.remove(outgoing); homeOnCourt.insert(incoming) }
                    if awayOnCourt.contains(outgoing) { awayOnCourt.remove(outgoing); awayOnCourt.insert(incoming) }
                }
            }

            let resolvedPlayerID = resolvedPlayerID(entry: entry, normalizedMessage: normalizedMessage)
            logs.append(
                PeriodAwareLog(
                    entry: entry,
                    inferredPeriod: inferredPeriod,
                    resolvedPlayerID: resolvedPlayerID
                )
            )

            guard let period = inferredPeriod else { continue }

            var resolvedCode = entry.eventCode ?? GameLogFormatter.extractEventCode(from: entry.message)
            if resolvedCode == nil {
                for candidate in StatAction.allCases {
                    let normalized = normalizedMessage
                    if normalized.hasSuffix(candidate.suffix) || normalized.hasSuffix(candidate.englishSuffix) {
                        resolvedCode = candidate.eventCode
                        break
                    }
                }
            }
            guard let code = resolvedCode,
                  let action = StatAction.allCases.first(where: { $0.eventCode == code }) else { continue }

            guard let playerID = entry.playerID ?? resolvedPlayerID ?? game.resolvedTeamID(from: entry.message) else { continue }

            var statsByPlayer = statsByPeriod[period, default: [:]]
            var stats = statsByPlayer[playerID, default: PlayerStats()]
            action.apply(to: &stats)
            statsByPlayer[playerID] = stats

            if let related = action.relatedAction,
               let rpid = entry.relatedPlayerID {
                var relatedStats = statsByPlayer[rpid, default: PlayerStats()]
                related.apply(to: &relatedStats)
                statsByPlayer[rpid] = relatedStats
            }

            statsByPeriod[period] = statsByPlayer

            // Plus-minus tracking
            if action.points > 0 {
                let isHome = homeIDs.contains(playerID) || game.snapshot.homeTeamID == playerID
                var pmByPlayer = plusMinusByPeriod[period, default: [:]]
                if isHome {
                    for pid in homeOnCourt { pmByPlayer[pid, default: 0] += action.points }
                    for pid in awayOnCourt { pmByPlayer[pid, default: 0] -= action.points }
                } else {
                    for pid in homeOnCourt { pmByPlayer[pid, default: 0] -= action.points }
                    for pid in awayOnCourt { pmByPlayer[pid, default: 0] += action.points }
                }
                plusMinusByPeriod[period] = pmByPlayer
            }
        }

        return SavedGamePeriodAnalysis(logs: logs, statsByPeriod: statsByPeriod, plusMinusByPeriod: plusMinusByPeriod)
    }

    private func resolvedPlayerID(entry: GameLogEntry, normalizedMessage: String) -> UUID? {
        if let playerID = entry.playerID {
            return playerID
        }

        for candidate in playerNameCandidates where normalizedMessage.contains(candidate.name) {
            return candidate.id
        }

        return nil
    }

}

enum GameLogFormatter {
    static func lineText(for log: PeriodAwareLog, originalPeriodCount: Int = 4) -> String {
        let periodText = GameView.periodContextText(period: log.inferredPeriod, elapsedSeconds: log.entry.periodElapsedSeconds, originalPeriodCount: originalPeriodCount)
        return [timeString(log.entry.timestamp), periodText, normalizedMessage(log.entry.message)]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    static func normalizedMessage(_ message: String) -> String {
        let withoutTag = cleanedMessage(message).trimmingCharacters(in: .whitespacesAndNewlines)

        guard withoutTag.hasSuffix(")"),
              let start = withoutTag.lastIndex(of: "("),
              start > withoutTag.startIndex else {
            return withoutTag
        }

        let scoreText = withoutTag[withoutTag.index(after: start)..<withoutTag.index(before: withoutTag.endIndex)]
        let parts = scoreText.split(separator: ":")
        guard parts.count == 2,
              Int(parts[0]) != nil,
              Int(parts[1]) != nil else {
            return withoutTag
        }

        let beforeScore = withoutTag[..<start]
        return String(beforeScore).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractEventCode(from message: String) -> String? {
        guard let start = message.range(of: "[event:") else { return nil }
        guard let end = message.range(of: "]", range: start.upperBound..<message.endIndex) else { return nil }
        let code = String(message[start.upperBound..<end.lowerBound])
        return code.isEmpty ? nil : code
    }

    private static func cleanedMessage(_ message: String) -> String {
        message.replacingOccurrences(of: "\\s*\\[event:[^\\]]+\\]", with: "", options: .regularExpression)
    }

    static func isScoring(_ log: PeriodAwareLog) -> Bool {
        isScoring(log.entry)
    }

    static func isScoring(_ entry: GameLogEntry) -> Bool {
        if let code = entry.eventCode {
            return scoringEventCodes.contains(code)
        }
        return isScoringMessage(entry.message)
    }

    /// Extract period number from a legacy control message (e.g. "第1节" or "暂停").
    static func periodNumber(fromControlMessage message: String) -> Int? {
        periodNumber(in: message)
    }

    /// Detect period start from message (eventCode preferred, Chinese "节开始" fallback).
    static func startedPeriodNumber(from message: String) -> Int? {
        if extractEventCode(from: message) == "event.period_start" {
            return periodNumber(in: normalizedMessage(message))
        }
        let normalized = normalizedMessage(message)
        guard normalized.hasSuffix("节开始") else { return nil }
        return periodNumber(in: normalized)
    }

    /// Detect period end from message (eventCode preferred, Chinese "节结束" fallback).
    static func endedPeriodNumber(from message: String) -> Int? {
        if extractEventCode(from: message) == "event.period_end" {
            return periodNumber(in: normalizedMessage(message))
        }
        let normalized = normalizedMessage(message)
        guard normalized.hasSuffix("节结束") else { return nil }
        return periodNumber(in: normalized)
    }

    private static func periodNumber(in message: String) -> Int? {
        guard let start = message.firstIndex(of: "第"),
              let end = message.firstIndex(of: "节"),
              start < end else {
            let digits = message.filter(\.isNumber)
            return Int(digits)
        }
        let numberText = message[message.index(after: start)..<end]
        return Int(numberText)
    }

    private static let scoringEventCodes = StatAction.scoringEventCodes

    private static func isScoringMessage(_ message: String) -> Bool {
        if let code = extractEventCode(from: message) {
            if scoringEventCodes.contains(code) {
                return true
            }
        }
        let normalized = normalizedMessage(message)
        return normalized.contains("2分命中")
            || normalized.contains("3分命中")
            || normalized.contains("加罚命中")
            || normalized.contains("罚篮命中")
            || normalized.contains("2PT Made")
            || normalized.contains("3PT Made")
            || normalized.contains("And-1 Made")
            || normalized.contains("FT Made")
    }

    private static func timeString(_ date: Date) -> String {
        GameView.timeFormatter.string(from: date)
    }
}
