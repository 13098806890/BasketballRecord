import SwiftUI

struct ELOComputationDetail: Identifiable {
    let id = UUID()
    let preELO: Double
    let myScore: Int
    let opponentScore: Int
    let avgOpponentELO: Double
    let expected: Double
    let actual: Double
    let playerGS: Double
    let avgGS: Double
    let relativeGS: Double
    let perf: Double
    let gsFactorRaw: Double
    let gsFactorClamped: Double
    let K: Double
    let won: Bool
    let isDraw: Bool
}

struct ELOGameEntry: Identifiable {
    var id: UUID { game.id }
    let game: SavedGame
    let preELO: Double
    let postELO: Double
    let gameScore: Double
    let won: Bool
    let delta: Double
    let detail: ELOComputationDetail
}

struct ELOEngine {
    static let initialELO: Double = 1500

    static func computeELO(for playerID: UUID, from games: [SavedGame]) -> Double {
        computeELOHistory(for: playerID, from: games).last?.postELO ?? initialELO
    }

    static func computeELOHistory(for playerID: UUID, from games: [SavedGame]) -> [ELOGameEntry] {
        let sortedGames = games
            .filter { $0.didParticipate(playerID) }
            .sorted { $0.savedAt < $1.savedAt }

        var eloByPlayer: [UUID: Double] = [:]
        var history: [ELOGameEntry] = []

        for game in sortedGames {
            let isHome = game.homePlayerIDs.contains(playerID)
            let isAway = game.awayPlayerIDs.contains(playerID)
            guard isHome || isAway else { continue }

            let myTeamIDs = isHome ? game.homePlayerIDs : game.awayPlayerIDs
            let opponentIDs = isHome ? game.awayPlayerIDs : game.homePlayerIDs
            let myTeamID = isHome ? game.snapshot.homeTeamID : game.snapshot.awayTeamID
            let opponentTeamID = isHome ? game.snapshot.awayTeamID : game.snapshot.homeTeamID

            let myScore: Int
            let opponentScore: Int
            if let tid = myTeamID, let oid = opponentTeamID {
                myScore = game.score(forTeamID: tid)
                opponentScore = game.score(forTeamID: oid)
            } else {
                myScore = myTeamIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
                opponentScore = opponentIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
            }

            for id in myTeamIDs where eloByPlayer[id] == nil {
                eloByPlayer[id] = initialELO
            }
            for id in opponentIDs where eloByPlayer[id] == nil {
                eloByPlayer[id] = initialELO
            }

            let playerWon = myScore > opponentScore
            let isDraw = myScore == opponentScore

            let opponentELOs = opponentIDs.compactMap { eloByPlayer[$0] }
            let avgOpponentELO = opponentELOs.isEmpty ? initialELO : opponentELOs.reduce(0, +) / Double(opponentELOs.count)

            let preELO = eloByPlayer[playerID] ?? initialELO
            let expected = 1.0 / (1.0 + pow(10, (avgOpponentELO - preELO) / 400.0))

            let actual: Double
            if playerWon { actual = 1.0 }
            else if isDraw { actual = 0.5 }
            else { actual = 0.0 }

            let playerStats = game.snapshot.statsByPlayerID[playerID] ?? PlayerStats()
            let playerGS = playerStats.gameScore

            let allIDs = game.homePlayerIDs + game.awayPlayerIDs
            let allGS = allIDs.compactMap { game.snapshot.statsByPlayerID[$0]?.gameScore }
            let avgGS = allGS.isEmpty ? 5.0 : allGS.reduce(0, +) / Double(allGS.count)
            let relativeGS = playerGS - avgGS
            let perf = tanh(relativeGS / 15.0)
            let gsFactor: Double
            if playerWon {
                gsFactor = 1.0 + perf * 0.5
            } else {
                gsFactor = 1.0 - perf * 0.5
            }
            let clampedFactor = max(0.3, min(2.0, gsFactor))

            let gameCount = sortedGames.count
            let K: Double
            if gameCount < 30 { K = 32 }
            else if gameCount < 100 { K = 24 }
            else { K = 16 }

            let delta = K * (actual - expected) * clampedFactor
            let postELO = preELO + delta
            eloByPlayer[playerID] = postELO

            history.append(ELOGameEntry(
                game: game,
                preELO: preELO,
                postELO: postELO,
                gameScore: playerGS,
                won: playerWon,
                delta: delta,
                detail: ELOComputationDetail(
                    preELO: preELO,
                    myScore: myScore,
                    opponentScore: opponentScore,
                    avgOpponentELO: avgOpponentELO,
                    expected: expected,
                    actual: actual,
                    playerGS: playerGS,
                    avgGS: avgGS,
                    relativeGS: relativeGS,
                    perf: perf,
                    gsFactorRaw: gsFactor,
                    gsFactorClamped: clampedFactor,
                    K: K,
                    won: playerWon,
                    isDraw: isDraw
                )
            ))
        }

        return history
    }
}
