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

            // Initialize all players in this game
            for id in game.homePlayerIDs + game.awayPlayerIDs where eloByPlayer[id] == nil {
                eloByPlayer[id] = initialELO
            }

            // Compute and update ELO for EVERY participant in this game
            let allParticipantIDs = game.homePlayerIDs + game.awayPlayerIDs
            let homeTeamIDs = Set(game.homePlayerIDs)
            let allGS = allParticipantIDs.compactMap { game.snapshot.statsByPlayerID[$0]?.gameScore }
            let avgGS = allGS.isEmpty ? 5.0 : allGS.reduce(0, +) / Double(allGS.count)
            let gameCount = sortedGames.count
            let K: Double
            if gameCount < 30 { K = 32 }
            else if gameCount < 100 { K = 24 }
            else { K = 16 }

            // First pass: compute all deltas using PRE-game ELOs
            var computedDeltas: [UUID: Double] = [:]
            var preELOs: [UUID: Double] = [:]
            var avgOppELOs: [UUID: Double] = [:]
            var expectedScores: [UUID: Double] = [:]
            var clampedFactors: [UUID: Double] = [:]
            let allWon = myScore > opponentScore
            let allDraw = myScore == opponentScore

            for pid in allParticipantIDs {
                let isPidHome = homeTeamIDs.contains(pid)
                let pidOpponentIDs = isPidHome ? game.awayPlayerIDs : game.homePlayerIDs

                let pidOppELOs = pidOpponentIDs.compactMap { eloByPlayer[$0] }
                let pidAvgOppELO = pidOppELOs.isEmpty ? initialELO : pidOppELOs.reduce(0, +) / Double(pidOppELOs.count)
                let pidPreELO = eloByPlayer[pid] ?? initialELO

                preELOs[pid] = pidPreELO
                avgOppELOs[pid] = pidAvgOppELO

                let pidExpected = 1.0 / (1.0 + pow(10, (pidAvgOppELO - pidPreELO) / 400.0))
                expectedScores[pid] = pidExpected

                let pidActual: Double
                if allWon { pidActual = isPidHome == isHome ? 1.0 : 0.0 }
                else if allDraw { pidActual = 0.5 }
                else { pidActual = isPidHome == isHome ? 0.0 : 1.0 }

                let pidStats = game.snapshot.statsByPlayerID[pid] ?? PlayerStats()
                let pidGS = pidStats.gameScore
                let pidRelativeGS = pidGS - avgGS
                let pidPerf = tanh(pidRelativeGS / 15.0)
                let gsFactor: Double
                if allWon {
                    gsFactor = (isPidHome == isHome) ? (1.0 + pidPerf * 0.5) : (1.0 - pidPerf * 0.5)
                } else if allDraw {
                    gsFactor = 1.0
                } else {
                    gsFactor = (isPidHome == isHome) ? (1.0 - pidPerf * 0.5) : (1.0 + pidPerf * 0.5)
                }
                let pidClampedFactor = max(0.3, min(2.0, gsFactor))
                clampedFactors[pid] = pidClampedFactor
                let pidDelta = K * (pidActual - pidExpected) * pidClampedFactor
                computedDeltas[pid] = pidDelta
            }

            // Second pass: apply all deltas
            for (pid, delta) in computedDeltas {
                eloByPlayer[pid] = (preELOs[pid] ?? initialELO) + delta
            }

            // Build history entry for the target player
            let preELO = preELOs[playerID] ?? initialELO
            let postELO = eloByPlayer[playerID] ?? initialELO
            let delta = computedDeltas[playerID] ?? 0
            let playerWon = myScore > opponentScore
            let isDraw = myScore == opponentScore
            let playerStats = game.snapshot.statsByPlayerID[playerID] ?? PlayerStats()
            let playerGS = playerStats.gameScore

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
                    avgOpponentELO: avgOppELOs[playerID] ?? initialELO,
                    expected: expectedScores[playerID] ?? 0.5,
                    actual: playerWon ? 1.0 : (isDraw ? 0.5 : 0.0),
                    playerGS: playerGS,
                    avgGS: avgGS,
                    relativeGS: playerGS - avgGS,
                    perf: tanh((playerGS - avgGS) / 15.0),
                    gsFactorRaw: playerWon ? (1.0 + tanh((playerGS - avgGS) / 15.0) * 0.5) : (1.0 - tanh((playerGS - avgGS) / 15.0) * 0.5),
                    gsFactorClamped: clampedFactors[playerID] ?? 1.0,
                    K: K,
                    won: playerWon,
                    isDraw: isDraw
                )
            ))
        }

        return history
    }
}
