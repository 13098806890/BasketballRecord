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
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }

        let lines = summary.split(separator: "\n").map(String.init)
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().contains("mvp") || trimmed.contains("最有价值") || trimmed.contains("最有價值") else { continue }

            for candidate in candidates where trimmed.contains(candidate.name) {
                return candidate.id
            }

            for j in (i + 1)..<min(i + 3, lines.count) {
                let next = lines[j].trimmingCharacters(in: .whitespaces)
                guard !next.isEmpty else { continue }
                for candidate in candidates where next.contains(candidate.name) {
                    return candidate.id
                }
            }
        }
        return nil
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
