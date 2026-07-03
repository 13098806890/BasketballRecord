import SwiftUI

enum PlayerGameRole: String, Codable, Hashable {
    case starter
    case bench

    var title: String {
        switch self {
        case .starter:
            return NSLocalizedString("stat_label_starter", comment: "Starter")
        case .bench:
            return NSLocalizedString("stat_label_bench", comment: "Bench")
        }
    }
}

enum CareerStatSection: String, CaseIterable, Codable, Identifiable {
    case total
    case average

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total:
            return NSLocalizedString("stat_section_total", comment: "Total")
        case .average:
            return NSLocalizedString("stat_section_average", comment: "Average")
        }
    }
}

enum CareerStatItem: String, CaseIterable, Codable, Identifiable {
    case totalPoints
    case totalRebounds
    case totalAssists
    case totalFouls
    case totalBlocks
    case totalSteals
    case totalTurnovers
    case totalStarterGames
    case totalBenchGames
    case totalMinutes
    case totalPlusMinus
    case totalTwoPoint
    case totalThreePoint
    case totalFreeThrow
    case averagePoints
    case averageRebounds
    case averageAssists
    case averageFouls
    case averageBlocks
    case averageSteals
    case averageTurnovers
    case averageMinutes
    case averagePlusMinus
    case averageTwoMade
    case averageThreeMade
    case averageFreeThrowMade
    case averageThreePointRate
    case averageFreeThrowRate

    var id: String { rawValue }

    var section: CareerStatSection {
        switch self {
        case .totalPoints,
             .totalRebounds,
             .totalAssists,
             .totalFouls,
             .totalBlocks,
             .totalSteals,
             .totalTurnovers,
             .totalStarterGames,
             .totalBenchGames,
             .totalMinutes,
             .totalPlusMinus,
             .totalTwoPoint,
             .totalThreePoint,
             .totalFreeThrow:
            return .total
        case .averagePoints,
             .averageRebounds,
             .averageAssists,
             .averageFouls,
             .averageBlocks,
             .averageSteals,
             .averageTurnovers,
             .averageMinutes,
             .averagePlusMinus,
             .averageTwoMade,
             .averageThreeMade,
             .averageFreeThrowMade,
             .averageThreePointRate,
             .averageFreeThrowRate:
            return .average
        }
    }

    var title: String {
        switch self {
        case .totalPoints:
            return NSLocalizedString("stat_label_points", comment: "Points")
        case .totalRebounds:
            return NSLocalizedString("stat_label_rebounds", comment: "Rebounds")
        case .totalAssists:
            return NSLocalizedString("stat_label_assists", comment: "Assists")
        case .totalFouls:
            return NSLocalizedString("stat_label_fouls", comment: "Fouls")
        case .totalBlocks:
            return NSLocalizedString("stat_label_blocks", comment: "Blocks")
        case .totalSteals:
            return NSLocalizedString("stat_label_steals", comment: "Steals")
        case .totalTurnovers:
            return NSLocalizedString("stat_label_turnovers", comment: "Turnovers")
        case .totalStarterGames:
            return NSLocalizedString("stat_label_starter_games", comment: "Starter games")
        case .totalBenchGames:
            return NSLocalizedString("stat_label_bench_games", comment: "Bench games")
        case .totalMinutes:
            return NSLocalizedString("stat_label_minutes", comment: "Minutes")
        case .totalPlusMinus:
            return NSLocalizedString("stats_plus_minus", comment: "Plus/minus")
        case .totalTwoPoint:
            return NSLocalizedString("stat_label_2pt_attempts", comment: "2PT attempts")
        case .totalThreePoint:
            return NSLocalizedString("stat_label_3pt_attempts", comment: "3PT attempts")
        case .totalFreeThrow:
            return NSLocalizedString("stat_label_free_throw", comment: "Free throw")
        case .averagePoints:
            return NSLocalizedString("stat_label_avg_points", comment: "Avg points")
        case .averageRebounds:
            return NSLocalizedString("stat_label_avg_rebounds", comment: "Avg rebounds")
        case .averageAssists:
            return NSLocalizedString("stat_label_avg_assists", comment: "Avg assists")
        case .averageFouls:
            return NSLocalizedString("stat_label_avg_fouls", comment: "Avg fouls")
        case .averageBlocks:
            return NSLocalizedString("stat_label_avg_blocks", comment: "Avg blocks")
        case .averageSteals:
            return NSLocalizedString("stat_label_avg_steals", comment: "Avg steals")
        case .averageTurnovers:
            return NSLocalizedString("stat_label_avg_turnovers", comment: "Avg turnovers")
        case .averageMinutes:
            return NSLocalizedString("stat_label_avg_minutes", comment: "Avg minutes")
        case .averagePlusMinus:
            return NSLocalizedString("stat_label_avg_plus_minus", comment: "Avg plus/minus")
        case .averageTwoMade:
            return NSLocalizedString("stat_label_avg_2pt_made", comment: "Avg 2PT made")
        case .averageThreeMade:
            return NSLocalizedString("stat_label_avg_3pt_made", comment: "Avg 3PT made")
        case .averageFreeThrowMade:
            return NSLocalizedString("stat_label_avg_free_throw_made", comment: "Avg FT made")
        case .averageThreePointRate:
            return NSLocalizedString("stat_label_3pt_rate", comment: "3PT rate")
        case .averageFreeThrowRate:
            return NSLocalizedString("stat_label_free_throw_rate", comment: "FT rate")
        }
    }
}

enum PeriodEndCondition: String, Codable, CaseIterable, Identifiable {
    case manual
    case byTime
    case byScore
    var id: String { rawValue }
}


enum RosterImportKind: String, CaseIterable, Identifiable {
    case team
    case player
    case game

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .team:
            return LocalizedStringKey("label_team")
        case .player:
            return LocalizedStringKey("label_player")
        case .game:
            return LocalizedStringKey("label_game")
        }
    }

    var localizedName: String {
        switch self {
        case .team:
            return localized("label_team")
        case .player:
            return localized("label_player")
        case .game:
            return localized("label_game")
        }
    }
}
