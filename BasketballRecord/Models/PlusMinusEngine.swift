import Foundation

enum PlusMinusEngine {

    static func apply(
        points: Int,
        scoringSide: TeamSide,
        homeTeamStatsMode: Bool,
        awayTeamStatsMode: Bool,
        homeOnCourt: Set<UUID>,
        awayOnCourt: Set<UUID>,
        to dict: inout [UUID: Int]
    ) {
        let isHomeScoring = scoringSide == .home
        let scoringMode = isHomeScoring ? homeTeamStatsMode : awayTeamStatsMode
        let defendingMode = isHomeScoring ? awayTeamStatsMode : homeTeamStatsMode

        if !scoringMode {
            let scoringIDs = isHomeScoring ? homeOnCourt : awayOnCourt
            for id in scoringIDs { dict[id, default: 0] += points }
        }
        if !defendingMode {
            let defendingIDs = isHomeScoring ? awayOnCourt : homeOnCourt
            for id in defendingIDs { dict[id, default: 0] -= points }
        }
    }

    static func scoringSide(
        for playerID: UUID,
        homeTeamID: UUID?,
        awayTeamID: UUID?,
        homePlayerIDs: [UUID],
        awayPlayerIDs: [UUID]
    ) -> TeamSide? {
        if playerID == homeTeamID { return .home }
        if playerID == awayTeamID { return .away }
        if homePlayerIDs.contains(playerID) { return .home }
        if awayPlayerIDs.contains(playerID) { return .away }
        return nil
    }
}
