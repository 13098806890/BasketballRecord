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
                inferredPeriod = GameLogFormatter.periodNumber(fromControlMessage: normalizedMessage) ?? currentPeriod
            }

            if let startedPeriod = GameLogFormatter.startedPeriodNumber(from: normalizedMessage) {
                currentPeriod = startedPeriod
            } else if let endedPeriod = GameLogFormatter.endedPeriodNumber(from: normalizedMessage) {
                currentPeriod = min(max(endedPeriod + 1, 1), max(game.snapshot.periodCount, 1))
            } else if let inferredPeriod {
                currentPeriod = inferredPeriod
            }

            let resolvedPlayerID = resolvedPlayerID(entry: entry, normalizedMessage: normalizedMessage)
            logs.append(
                PeriodAwareLog(
                    entry: entry,
                    inferredPeriod: inferredPeriod,
                    resolvedPlayerID: resolvedPlayerID
                )
            )

            guard let period = inferredPeriod,
                  let (playerName, action) = LoggedAction.parse(from: normalizedMessage),
                  let playerID = entry.playerID ?? resolvePlayerIDByName(playerName) else {
                continue
            }

            var statsByPlayer = statsByPeriod[period, default: [:]]
            var stats = statsByPlayer[playerID, default: PlayerStats()]
            action.apply(to: &stats)
            statsByPlayer[playerID] = stats
            statsByPeriod[period] = statsByPlayer
        }

        return SavedGamePeriodAnalysis(logs: logs, statsByPeriod: statsByPeriod)
    }

    private func resolvedPlayerID(entry: GameLogEntry, normalizedMessage: String) -> UUID? {
        if let playerID = entry.playerID {
            return playerID
        }

        if let (playerName, _) = LoggedAction.parse(from: normalizedMessage),
           let playerID = resolvePlayerIDByName(playerName) {
            return playerID
        }

        for candidate in playerNameCandidates where normalizedMessage.contains(candidate.name) {
            return candidate.id
        }

        return nil
    }

    private enum LoggedAction: CaseIterable {
        case twoMade
        case twoMissed
        case threeMade
        case threeMissed
        case bonusMade
        case bonusMissed
        case freeThrowMade
        case freeThrowMissed
        case foul
        case assist
        case rebound
        case block
        case steal
        case turnover

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
            case .block: return "封盖"
            case .steal: return "抢断"
            case .turnover: return "失误"
            }
        }

        static func parse(from message: String) -> (playerName: String, action: LoggedAction)? {
            for action in allCases {
                guard message.hasSuffix(action.suffix) else { continue }
                let playerName = String(message.dropLast(action.suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !playerName.isEmpty else { return nil }
                return (playerName, action)
            }
            return nil
        }

        func apply(to stats: inout PlayerStats) {
            switch self {
            case .twoMade:
                stats.twoMade += 1
                stats.twoAttempts += 1
            case .twoMissed:
                stats.twoAttempts += 1
            case .threeMade:
                stats.threeMade += 1
                stats.threeAttempts += 1
            case .threeMissed:
                stats.threeAttempts += 1
            case .bonusMade:
                stats.bonusFreeThrowMade += 1
                stats.bonusFreeThrowAttempts += 1
            case .bonusMissed:
                stats.bonusFreeThrowAttempts += 1
            case .freeThrowMade:
                stats.freeThrowMade += 1
                stats.freeThrowAttempts += 1
            case .freeThrowMissed:
                stats.freeThrowAttempts += 1
            case .foul:
                stats.fouls += 1
            case .assist:
                stats.assists += 1
            case .rebound:
                stats.rebounds += 1
            case .block:
                stats.blocks += 1
            case .steal:
                stats.steals += 1
            case .turnover:
                stats.turnovers += 1
            }
        }
    }
}

enum GameLogFormatter {
    static func lineText(for log: PeriodAwareLog) -> String {
        let periodText = GameView.periodContextText(period: log.inferredPeriod, elapsedSeconds: log.entry.periodElapsedSeconds)
        return [timeString(log.entry.timestamp), periodText, log.entry.message]
            .filter { !$0.isEmpty }
            .joined(separator: "  ")
    }

    static func normalizedMessage(_ message: String) -> String {
        guard message.hasSuffix(")"),
              let start = message.lastIndex(of: "("),
              start > message.startIndex else {
            return message
        }

        let scoreText = message[message.index(after: start)..<message.index(before: message.endIndex)]
        let parts = scoreText.split(separator: ":")
        guard parts.count == 2,
              Int(parts[0]) != nil,
              Int(parts[1]) != nil else {
            return message
        }

        let beforeScore = message[..<start]
        guard beforeScore.last == " " else { return message }
        return String(beforeScore.dropLast())
    }

    static func isScoring(_ log: PeriodAwareLog) -> Bool {
        isScoringMessage(log.entry.message)
    }

    static func isScoring(_ entry: GameLogEntry) -> Bool {
        isScoringMessage(entry.message)
    }

    static func periodNumber(fromControlMessage message: String) -> Int? {
        periodNumber(in: message)
    }

    static func startedPeriodNumber(from message: String) -> Int? {
        guard message.hasSuffix("节开始") else { return nil }
        return periodNumber(in: message)
    }

    static func endedPeriodNumber(from message: String) -> Int? {
        guard message.hasSuffix("节结束") else { return nil }
        return periodNumber(in: message)
    }

    private static func periodNumber(in message: String) -> Int? {
        guard let start = message.firstIndex(of: "第"),
              let end = message.firstIndex(of: "节"),
              start < end else {
            return nil
        }
        let numberText = message[message.index(after: start)..<end]
        return Int(numberText)
    }

    private static func isScoringMessage(_ message: String) -> Bool {
        let normalized = normalizedMessage(message)
        return normalized.contains("2分命中")
            || normalized.contains("3分命中")
            || normalized.contains("加罚命中")
            || normalized.contains("罚篮命中")
    }

    private static func timeString(_ date: Date) -> String {
        GameView.timeFormatter.string(from: date)
    }
}
