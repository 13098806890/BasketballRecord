import Foundation

enum StatAction {
    case twoMade, twoMissed, threeMade, threeMissed
    case bonusMade, bonusMissed, freeThrowMade, freeThrowMissed
    case foul, assist, rebound, offensiveRebound, defensiveRebound, block, steal, turnover
    case layupMade, layupMissed, midRangeMade, midRangeMissed, paintMade, paintMissed
    case putbackMade, putbackMissed
    case dunkMade, dunkMissed
    case assistTwoMade, assistThreeMade, stealTurnover

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

    var points: Int {
        switch self {
        case .twoMade, .layupMade, .midRangeMade, .paintMade, .putbackMade, .dunkMade, .assistTwoMade: return 2
        case .threeMade, .assistThreeMade: return 3
        case .bonusMade, .freeThrowMade: return 1
        default: return 0
        }
    }

    var relatedAction: StatAction? {
        switch self {
        case .assistTwoMade: return .twoMade
        case .assistThreeMade: return .threeMade
        case .stealTurnover: return .turnover
        default: return nil
        }
    }

    var isAssistableShot: Bool {
        switch self {
        case .twoMade, .threeMade, .layupMade, .midRangeMade, .paintMade, .putbackMade, .dunkMade:
            return true
        default:
            return false
        }
    }

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

    var suffixCandidates: [String] {
        [suffix, englishSuffix]
    }

    static let scoringEventCodes: Set<String> = [
        "stat.twoMade", "stat.threeMade", "stat.bonusMade", "stat.freeThrowMade",
        "stat.layupMade", "stat.midRangeMade", "stat.paintMade", "stat.putbackMade", "stat.dunkMade",
        "stat.assistTwoMade", "stat.assistThreeMade"
    ]

    static let pointMap: [String: Int] = [
        "stat.twoMade": 2, "stat.threeMade": 3, "stat.bonusMade": 1, "stat.freeThrowMade": 1,
        "stat.layupMade": 2, "stat.midRangeMade": 2, "stat.paintMade": 2, "stat.putbackMade": 2, "stat.dunkMade": 2,
        "stat.assistTwoMade": 2, "stat.assistThreeMade": 3
    ]

    func apply(to stats: inout PlayerStats) {
        switch self {
        case .twoMade:
            stats.twoMade += 1
            stats.twoAttempts += 1
        case .twoMissed:
            stats.twoAttempts += 1
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
        case .assistTwoMade, .assistThreeMade:
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
        case .stealTurnover:
            stats.steals += 1
        case .turnover:
            stats.turnovers += 1
        case .putbackMade:
            stats.offensiveRebounds += 1
            stats.twoMade += 1
            stats.twoAttempts += 1
        case .putbackMissed:
            stats.offensiveRebounds += 1
            stats.twoAttempts += 1
        case .dunkMade:
            stats.dunkMade += 1; stats.dunkAttempts += 1
            stats.twoMade += 1; stats.twoAttempts += 1
        case .dunkMissed:
            stats.dunkAttempts += 1; stats.twoAttempts += 1
        }
    }

    func revert(on stats: inout PlayerStats) -> Bool {
        switch self {
        case .twoMade:
            guard stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.twoMade -= 1
            stats.twoAttempts -= 1
        case .twoMissed:
            guard stats.twoAttempts > 0 else { return false }
            stats.twoAttempts -= 1
        case .threeMade:
            guard stats.threeMade > 0, stats.threeAttempts > 0 else { return false }
            stats.threeMade -= 1
            stats.threeAttempts -= 1
        case .threeMissed:
            guard stats.threeAttempts > 0 else { return false }
            stats.threeAttempts -= 1
        case .bonusMade:
            guard stats.bonusFreeThrowMade > 0, stats.bonusFreeThrowAttempts > 0 else { return false }
            stats.bonusFreeThrowMade -= 1
            stats.bonusFreeThrowAttempts -= 1
        case .bonusMissed:
            guard stats.bonusFreeThrowAttempts > 0 else { return false }
            stats.bonusFreeThrowAttempts -= 1
        case .freeThrowMade:
            guard stats.freeThrowMade > 0, stats.freeThrowAttempts > 0 else { return false }
            stats.freeThrowMade -= 1
            stats.freeThrowAttempts -= 1
        case .freeThrowMissed:
            guard stats.freeThrowAttempts > 0 else { return false }
            stats.freeThrowAttempts -= 1
        case .foul:
            guard stats.fouls > 0 else { return false }
            stats.fouls -= 1
        case .assist:
            guard stats.assists > 0 else { return false }
            stats.assists -= 1
        case .assistTwoMade, .assistThreeMade:
            guard stats.assists > 0 else { return false }
            stats.assists -= 1
        case .rebound:
            guard stats.rebounds > 0 else { return false }
            stats.rebounds -= 1
        case .offensiveRebound:
            guard stats.offensiveRebounds > 0 else { return false }
            stats.offensiveRebounds -= 1
        case .defensiveRebound:
            guard stats.defensiveRebounds > 0 else { return false }
            stats.defensiveRebounds -= 1
        case .block:
            guard stats.blocks > 0 else { return false }
            stats.blocks -= 1
        case .steal:
            guard stats.steals > 0 else { return false }
            stats.steals -= 1
        case .stealTurnover:
            guard stats.steals > 0 else { return false }
            stats.steals -= 1
        case .turnover:
            guard stats.turnovers > 0 else { return false }
            stats.turnovers -= 1
        case .layupMade:
            guard stats.layupMade > 0, stats.layupAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.layupMade -= 1; stats.layupAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .layupMissed:
            guard stats.layupAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.layupAttempts -= 1; stats.twoAttempts -= 1
        case .midRangeMade:
            guard stats.midRangeMade > 0, stats.midRangeAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.midRangeMade -= 1; stats.midRangeAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .midRangeMissed:
            guard stats.midRangeAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.midRangeAttempts -= 1; stats.twoAttempts -= 1
        case .paintMade:
            guard stats.paintMade > 0, stats.paintAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.paintMade -= 1; stats.paintAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .paintMissed:
            guard stats.paintAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.paintAttempts -= 1; stats.twoAttempts -= 1
        case .dunkMade:
            guard stats.dunkMade > 0, stats.dunkAttempts > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.dunkMade -= 1; stats.dunkAttempts -= 1
            stats.twoMade -= 1; stats.twoAttempts -= 1
        case .dunkMissed:
            guard stats.dunkAttempts > 0, stats.twoAttempts > 0 else { return false }
            stats.dunkAttempts -= 1; stats.twoAttempts -= 1
        case .putbackMade:
            guard stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            if stats.offensiveRebounds > 0 {
                stats.offensiveRebounds -= 1
            } else {
                guard stats.rebounds > 0 else { return false }
                stats.rebounds -= 1
            }
            stats.twoMade -= 1
            stats.twoAttempts -= 1
        case .putbackMissed:
            guard stats.twoAttempts > 0 else { return false }
            if stats.offensiveRebounds > 0 {
                stats.offensiveRebounds -= 1
            } else {
                guard stats.rebounds > 0 else { return false }
                stats.rebounds -= 1
            }
            stats.twoAttempts -= 1
        }
        return true
    }
}

extension StatAction: Equatable {}

extension StatAction: CaseIterable {
    static var allCases: [StatAction] {
        [.twoMade, .twoMissed, .threeMade, .threeMissed, .bonusMade, .bonusMissed, .freeThrowMade, .freeThrowMissed, .foul, .assist, .rebound, .offensiveRebound, .defensiveRebound, .block, .steal, .turnover, .layupMade, .layupMissed, .midRangeMade, .midRangeMissed, .paintMade, .paintMissed, .putbackMade, .putbackMissed, .dunkMade, .dunkMissed, .assistTwoMade, .assistThreeMade, .stealTurnover]
    }
}
