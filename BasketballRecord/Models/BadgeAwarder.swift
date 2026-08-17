import Foundation

@MainActor
struct BadgeAwarder {
    static func awardBadges(for game: SavedGame, store: AppStore) {
        let allPlayerIDs = Set(game.homePlayerIDs + game.awayPlayerIDs)
        let playerIDs = Array(allPlayerIDs).filter { game.snapshot.statsByPlayerID[$0] != nil }
        let statsByID = game.snapshot.statsByPlayerID

        var awarded: [(UUID, PlayerBadge)] = []

        if let (pid, _) = topPlayer(playerIDs, statsByID: statsByID, value: { $0.points }), statsByID[pid]!.points > 0 {
            awarded.append((pid, PlayerBadge(type: .scoringKing, gameID: game.id)))
        }

        if let (pid, _) = topPlayer(playerIDs, statsByID: statsByID, value: { $0.turnovers }), statsByID[pid]!.turnovers > 0 {
            awarded.append((pid, PlayerBadge(type: .turnoverKing, gameID: game.id)))
        }

        let efficiencyCandidates = playerIDs.filter { statsByID[$0]!.allShotAttempts >= 5 }
        if let (pid, _) = topPlayer(efficiencyCandidates, statsByID: statsByID, value: { Double($0.points) / Double(max($0.allShotAttempts, 1)) }) {
            awarded.append((pid, PlayerBadge(type: .efficiencyKing, gameID: game.id)))
        }

        if let (pid, _) = topPlayer(playerIDs, statsByID: statsByID, value: { $0.allShotAttempts - $0.allShotsMade }), (statsByID[pid]!.allShotAttempts - statsByID[pid]!.allShotsMade) > 0 {
            awarded.append((pid, PlayerBadge(type: .ironKing, gameID: game.id)))
        }

        if let (pid, _) = topPlayer(playerIDs, statsByID: statsByID, value: { $0.blocks }), statsByID[pid]!.blocks > 0 {
            awarded.append((pid, PlayerBadge(type: .blockKing, gameID: game.id)))
        }

        if let pid = bestThreeShooter(playerIDs, statsByID: statsByID) {
            awarded.append((pid, PlayerBadge(type: .threeKing, gameID: game.id)))
        }

        if let (pid, _) = topPlayer(playerIDs, statsByID: statsByID, value: { $0.totalRebounds }), statsByID[pid]!.totalRebounds > 0 {
            awarded.append((pid, PlayerBadge(type: .reboundKing, gameID: game.id)))
        }

        if let (pid, _) = topPlayer(playerIDs, statsByID: statsByID, value: { $0.assists }), statsByID[pid]!.assists > 0 {
            awarded.append((pid, PlayerBadge(type: .assistKing, gameID: game.id)))
        }

        if let pid = findThreeStreak(game) {
            awarded.append((pid, PlayerBadge(type: .threeStreak, gameID: game.id)))
        }

        if let mvpID = parseMVP(from: game.aiSummary, playerNames: game.playerNamesByID) {
            awarded.append((mvpID, PlayerBadge(type: .mvp, gameID: game.id)))
        }

        applyAwards(awarded, store: store)
    }

    private static func topPlayer(_ ids: [UUID], statsByID: [UUID: PlayerStats], value: (PlayerStats) -> Double) -> (UUID, Double)? {
        guard !ids.isEmpty else { return nil }
        let sorted = ids.sorted { value(statsByID[$0]!) > value(statsByID[$1]!) }
        let top = value(statsByID[sorted[0]]!)
        guard top > 0 else { return nil }
        return (sorted[0], top)
    }

    private static func topPlayer(_ ids: [UUID], statsByID: [UUID: PlayerStats], value: (PlayerStats) -> Int) -> (UUID, Int)? {
        guard !ids.isEmpty else { return nil }
        let sorted = ids.sorted { value(statsByID[$0]!) > value(statsByID[$1]!) }
        let top = value(statsByID[sorted[0]]!)
        guard top > 0 else { return nil }
        return (sorted[0], top)
    }

    private static func bestThreeShooter(_ ids: [UUID], statsByID: [UUID: PlayerStats]) -> UUID? {
        let sorted = ids.filter { statsByID[$0]!.threeMade > 0 }.sorted { a, b in
            let aMade = statsByID[a]!.threeMade
            let bMade = statsByID[b]!.threeMade
            if aMade != bMade { return aMade > bMade }
            let aRate = statsByID[a]!.threeAttempts > 0 ? Double(aMade) / Double(statsByID[a]!.threeAttempts) : 0
            let bRate = statsByID[b]!.threeAttempts > 0 ? Double(bMade) / Double(statsByID[b]!.threeAttempts) : 0
            return aRate > bRate
        }
        return sorted.first
    }

    private static func findThreeStreak(_ game: SavedGame) -> UUID? {
        let logs = game.snapshot.logs
            .filter { $0.eventCode == "stat.threeMade" || $0.eventCode == "stat.threeMissed" }
            .sorted { $0.timestamp < $1.timestamp }
        var streaks: [UUID: Int] = [:]
        for entry in logs {
            guard let pid = entry.playerID else { continue }
            if entry.eventCode == "stat.threeMade" {
                streaks[pid, default: 0] += 1
                if streaks[pid]! >= 3 { return pid }
            } else {
                streaks[pid] = 0
            }
        }
        return nil
    }

    static func parseMVP(from summary: String?, playerNames: [UUID: String]) -> UUID? {
        guard let summary = summary else { return nil }
        let candidates = playerNames
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }

        // Tier 1: structured "MVP: PlayerName" / "MVP：球员名" across the whole summary
        let mvpPattern = try? NSRegularExpression(pattern: #"(?i)(?:mvp|最有价值|最有價值|most valuable)[：:]\s*([^\n，。,.()（）【】]+)"#)
        if let mvpPattern {
            let range = NSRange(summary.startIndex..., in: summary)
            for match in mvpPattern.matches(in: summary, options: [], range: range) {
                let nameRange = Range(match.range(at: 1), in: summary)
                let extracted = nameRange.map { String(summary[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                if !extracted.isEmpty {
                    let sorted = candidates.sorted { $0.name.count > $1.name.count }
                    if let found = sorted.first(where: { extracted.contains($0.name) }) {
                        return found.id
                    }
                    if let found = candidates.first(where: { normalizeForMatch($0.name) == normalizeForMatch(extracted) }) {
                        return found.id
                    }
                }
            }
        }

        // Tier 2: fall back to lines that mention MVP, checking the same line then the next few
        let lines = summary.split(separator: "\n").map(String.init)
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard isMVPKeywordLine(trimmed) else { continue }

            let sorted = candidates.sorted { $0.name.count > $1.name.count }
            if let found = sorted.first(where: { trimmed.contains($0.name) }) {
                return found.id
            }

            for j in (i + 1)..<min(i + 3, lines.count) {
                let next = lines[j].trimmingCharacters(in: .whitespaces)
                guard !next.isEmpty else { continue }
                if let found = sorted.first(where: { next.contains($0.name) }) {
                    return found.id
                }
            }
        }
        return nil
    }

    private static func isMVPKeywordLine(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("mvp")
            || lower.contains("most valuable")
            || text.contains("最有价值")
            || text.contains("最有價值")
    }

    private static func normalizeForMatch(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]"#, with: "", options: .regularExpression)
    }

    @MainActor static func scanAllGames(store: AppStore) {
        for game in store.savedGames {
            awardBadges(for: game, store: store)
        }
    }

    @MainActor private static func applyAwards(_ awards: [(UUID, PlayerBadge)], store: AppStore) {
        for (pid, badge) in awards {
            if var player = store.players.first(where: { $0.id == pid }) {
                if !player.badges.contains(where: { $0.gameID == badge.gameID && $0.type == badge.type }) {
                    player.badges.append(badge)
                    store.updatePlayer(player)
                }
            }
        }
    }
}
