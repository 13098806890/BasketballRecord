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

            guard let period = inferredPeriod else { continue }

            let parsedAction: (playerName: String, action: LoggedAction)?
            if let code = entry.eventCode {
                parsedAction = LoggedAction.allCases.first(where: { $0.eventCode == code }).map { ("", $0) }
            } else {
                parsedAction = LoggedAction.parse(from: normalizedMessage)
            }
            guard let (playerName, action) = parsedAction else { continue }

            let resolvedByName = playerName.isEmpty ? nil : resolvePlayerIDByName(playerName)
            let teamID: UUID? = {
                guard game.snapshot.homeTeamStatsMode || game.snapshot.awayTeamStatsMode else { return nil }
                let msg = entry.message.lowercased()
                if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID,
                   msg.contains(game.homeTeamName.lowercased()) || msg.contains("主队") || msg.contains("zhudui") { return tid }
                if game.snapshot.awayTeamStatsMode, let tid = game.snapshot.awayTeamID,
                   msg.contains(game.awayTeamName.lowercased()) || msg.contains("客队") || msg.contains("kedui") { return tid }
                return nil
            }()
            guard let playerID = entry.playerID ?? resolvedByName ?? teamID else {
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

        // Team stats mode: match team name
        if game.snapshot.homeTeamStatsMode || game.snapshot.awayTeamStatsMode {
            let msg = normalizedMessage.lowercased()
            if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID,
               msg.contains(game.homeTeamName.lowercased()) || msg.contains("主队") { return tid }
            if game.snapshot.awayTeamStatsMode, let tid = game.snapshot.awayTeamID,
               msg.contains(game.awayTeamName.lowercased()) || msg.contains("客队") { return tid }
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
            case .block: return "Block"
            case .steal: return "Steal"
            case .turnover: return "Turnover"
            }
        }

        var suffixCandidates: [String] {
            [suffix, englishSuffix]
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
            case .block: return "stat.block"
            case .steal: return "stat.steal"
            case .turnover: return "stat.turnover"
            }
        }

        static func parse(from message: String) -> (playerName: String, action: LoggedAction)? {
            let normalized = GameLogFormatter.normalizedMessage(message)

            if let code = GameLogFormatter.extractEventCode(from: message),
               let action = allCases.first(where: { $0.eventCode == code }) {
                let playerName = extractPlayerName(from: normalized, action: action)
                return (playerName, action)
            }

            // Fallback: legacy suffix-based parsing (language-dependent)
            for action in allCases {
                let playerName = extractPlayerName(from: normalized, action: action)
                guard !playerName.isEmpty else { return nil }
                if action.suffixCandidates.contains(where: { normalized.hasSuffix($0) }) {
                    return (playerName, action)
                }
            }
            return nil
        }

        private static func extractPlayerName(from normalized: String, action: LoggedAction) -> String {
            for suffix in action.suffixCandidates where normalized.hasSuffix(suffix) {
                return String(normalized.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
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

    static func periodNumber(fromControlMessage message: String) -> Int? {
        periodNumber(in: message)
    }

    static func startedPeriodNumber(from message: String) -> Int? {
        if extractEventCode(from: message) == "event.period_start" {
            return periodNumber(in: normalizedMessage(message))
        }

        let normalized = normalizedMessage(message)
        guard normalized.hasSuffix("节开始") else { return nil }
        return periodNumber(in: normalized)
    }

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
        "stat.twoMade",
        "stat.threeMade",
        "stat.bonusMade",
        "stat.freeThrowMade"
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
