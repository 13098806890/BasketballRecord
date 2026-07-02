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

    func logs(for period: Int?) -> [PeriodAwareLog] {
        guard let period else { return logs }
        return logs.filter { $0.inferredPeriod == period }
    }

    func statsByPlayerID(for period: Int?) -> [UUID: PlayerStats] {
        guard let period else { return [:] }
        return statsByPeriod[period] ?? [:]
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
                // Fallback: try matching from message suffix for old games without eventCode
                for candidate in LoggedAction.allCases {
                    let normalized = normalizedMessage
                    if normalized.hasSuffix(candidate.suffix) || normalized.hasSuffix(candidate.englishSuffix) {
                        resolvedCode = candidate.eventCode
                        break
                    }
                }
            }
            guard let code = resolvedCode,
                  let action = LoggedAction.allCases.first(where: { $0.eventCode == code }) else { continue }

            guard let playerID = entry.playerID ?? resolvedPlayerID else { continue }

            var statsByPlayer = statsByPeriod[period, default: [:]]
            var stats = statsByPlayer[playerID, default: PlayerStats()]
            action.apply(to: &stats)
            statsByPlayer[playerID] = stats

            if let relatedActionCode = action.relatedActionEventCode,
               let rpid = entry.relatedPlayerID,
               let relatedAction = LoggedAction.allCases.first(where: { $0.eventCode == relatedActionCode }) {
                var relatedStats = statsByPlayer[rpid, default: PlayerStats()]
                relatedAction.apply(to: &relatedStats)
                statsByPlayer[rpid] = relatedStats
            }

            statsByPeriod[period] = statsByPlayer
        }

        return SavedGamePeriodAnalysis(logs: logs, statsByPeriod: statsByPeriod)
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

    private enum LoggedAction: CaseIterable {
        case twoMade, twoMissed, threeMade, threeMissed
        case bonusMade, bonusMissed, freeThrowMade, freeThrowMissed
        case foul, assist, rebound, offensiveRebound, defensiveRebound, block, steal, turnover
        case layupMade, layupMissed, midRangeMade, midRangeMissed, paintMade, paintMissed
        case putbackMade, putbackMissed, dunkMade, dunkMissed
        case assistTwoMade, assistThreeMade, stealTurnover

        /// Chinese suffix for backward-compatible message parsing (old games without eventCode).
        var suffix: String {
            switch self {
            case .twoMade: return "2分命中"
            case .twoMissed: return "2分不中"
            case .threeMade: return "3分命中"
            case .threeMissed: return "3分不中"
            case .bonusMade: return "加罚命中"
            case .bonusMissed: return "加罚不中"
            case .freeThrowMade: return "罚篮命中"
            case .freeThrowMissed: return "罚篮不中"
            case .foul: return "犯规"
            case .assist: return "助攻"
            case .rebound: return "篮板"
            case .offensiveRebound: return "前场板"
            case .defensiveRebound: return "后场板"
            case .block: return "封盖"
            case .steal: return "抢断"
            case .turnover: return "失误"
            case .layupMade: return "上篮命中"
            case .layupMissed: return "上篮不中"
            case .midRangeMade: return "中投命中"
            case .midRangeMissed: return "中投不中"
            case .paintMade: return "篮下命中"
            case .paintMissed: return "篮下不中"
            case .putbackMade: return "补篮命中"
            case .putbackMissed: return "补篮不中"
            case .dunkMade: return "扣篮命中"
            case .dunkMissed: return "扣篮不中"
            case .assistTwoMade: return ""
            case .assistThreeMade: return ""
            case .stealTurnover: return ""
            }
        }

        /// English suffix for backward-compatible message parsing.
        var englishSuffix: String {
            switch self {
            case .twoMade: return "2PT Made"
            case .twoMissed: return "2PT Missed"
            case .threeMade: return "3PT Made"
            case .threeMissed: return "3PT Missed"
            case .bonusMade: return "And-1 Made"
            case .bonusMissed: return "And-1 Missed"
            case .freeThrowMade: return "FT Made"
            case .freeThrowMissed: return "FT Missed"
            case .foul: return "Foul"
            case .assist: return "Assist"
            case .rebound: return "Rebound"
            case .offensiveRebound: return "OREB"
            case .defensiveRebound: return "DREB"
            case .block: return "Block"
            case .steal: return "Steal"
            case .turnover: return "Turnover"
            case .layupMade: return "Layup Made"
            case .layupMissed: return "Layup Missed"
            case .midRangeMade: return "Mid-range Made"
            case .midRangeMissed: return "Mid-range Missed"
            case .paintMade: return "Paint Made"
            case .paintMissed: return "Paint Missed"
            case .putbackMade: return "Putback Made"
            case .putbackMissed: return "Putback Missed"
            case .dunkMade: return "Dunk Made"
            case .dunkMissed: return "Dunk Missed"
            case .assistTwoMade: return ""
            case .assistThreeMade: return ""
            case .stealTurnover: return ""
            }
        }

        var eventCode: String {
            switch self {
            case .twoMade: return "stat.twoMade"
            case .twoMissed: return "stat.twoMissed"
            case .threeMade: return "stat.threeMade"
            case .threeMissed: return "stat.threeMissed"
            case .bonusMade: return "stat.bonusMade"
            case .bonusMissed: return "stat.bonusMissed"
            case .freeThrowMade: return "stat.freeThrowMade"
            case .freeThrowMissed: return "stat.freeThrowMissed"
            case .foul: return "stat.foul"
            case .assist: return "stat.assist"
            case .rebound: return "stat.rebound"
            case .offensiveRebound: return "stat.offensiveRebound"
            case .defensiveRebound: return "stat.defensiveRebound"
            case .block: return "stat.block"
            case .steal: return "stat.steal"
            case .turnover: return "stat.turnover"
            case .layupMade: return "stat.layupMade"
            case .layupMissed: return "stat.layupMissed"
            case .midRangeMade: return "stat.midRangeMade"
            case .midRangeMissed: return "stat.midRangeMissed"
            case .paintMade: return "stat.paintMade"
            case .paintMissed: return "stat.paintMissed"
            case .putbackMade: return "stat.putbackMade"
            case .putbackMissed: return "stat.putbackMissed"
            case .dunkMade: return "stat.dunkMade"
            case .dunkMissed: return "stat.dunkMissed"
            case .assistTwoMade: return "stat.assistTwoMade"
            case .assistThreeMade: return "stat.assistThreeMade"
            case .stealTurnover: return "stat.stealTurnover"
            }
        }

        var relatedActionEventCode: String? {
            switch self {
            case .assistTwoMade: return "stat.twoMade"
            case .assistThreeMade: return "stat.threeMade"
            case .stealTurnover: return "stat.turnover"
            default: return nil
            }
        }

        func apply(to stats: inout PlayerStats) {
            switch self {
            case .twoMade:
                stats.twoMade += 1; stats.twoAttempts += 1
            case .twoMissed:
                stats.twoAttempts += 1
            case .threeMade:
                stats.threeMade += 1; stats.threeAttempts += 1
            case .threeMissed:
                stats.threeAttempts += 1
            case .bonusMade:
                stats.bonusFreeThrowMade += 1; stats.bonusFreeThrowAttempts += 1
            case .bonusMissed:
                stats.bonusFreeThrowAttempts += 1
            case .freeThrowMade:
                stats.freeThrowMade += 1; stats.freeThrowAttempts += 1
            case .freeThrowMissed:
                stats.freeThrowAttempts += 1
            case .foul:
                stats.fouls += 1
            case .assist:
                stats.assists += 1
            case .rebound:
                stats.rebounds += 1
            case .offensiveRebound:
                stats.offensiveRebounds += 1
            case .defensiveRebound:
                stats.defensiveRebounds += 1
            case .block:
                stats.blocks += 1
            case .steal:
                stats.steals += 1
            case .turnover:
                stats.turnovers += 1
            case .layupMade:
                stats.layupMade += 1; stats.layupAttempts += 1
                stats.twoMade += 1; stats.twoAttempts += 1
            case .layupMissed:
                stats.layupAttempts += 1; stats.twoAttempts += 1
            case .midRangeMade:
                stats.midRangeMade += 1; stats.midRangeAttempts += 1
                stats.twoMade += 1; stats.twoAttempts += 1
            case .midRangeMissed:
                stats.midRangeAttempts += 1; stats.twoAttempts += 1
            case .paintMade:
                stats.paintMade += 1; stats.paintAttempts += 1
                stats.twoMade += 1; stats.twoAttempts += 1
            case .paintMissed:
                stats.paintAttempts += 1; stats.twoAttempts += 1
            case .putbackMade:
                stats.rebounds += 1
                stats.twoMade += 1; stats.twoAttempts += 1
            case .putbackMissed:
                stats.offensiveRebounds += 1
                stats.twoAttempts += 1
            case .dunkMade:
                stats.dunkMade += 1; stats.dunkAttempts += 1
                stats.twoMade += 1; stats.twoAttempts += 1
            case .dunkMissed:
                stats.dunkAttempts += 1; stats.twoAttempts += 1
            case .assistTwoMade, .assistThreeMade:
                stats.assists += 1
            case .stealTurnover:
                stats.steals += 1
            }
        }
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

    private static let scoringEventCodes: Set<String> = [
        "stat.twoMade", "stat.threeMade", "stat.bonusMade", "stat.freeThrowMade",
        "stat.layupMade", "stat.midRangeMade", "stat.paintMade", "stat.putbackMade", "stat.dunkMade",
        "stat.assistTwoMade", "stat.assistThreeMade"
    ]

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
