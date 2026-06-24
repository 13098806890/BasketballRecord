import Foundation
import SwiftUI

enum StatAction {
    case twoMade, twoMissed, threeMade, threeMissed
    case bonusMade, bonusMissed, freeThrowMade, freeThrowMissed
    case foul, assist, rebound, offensiveRebound, defensiveRebound, block, steal, turnover
    case layupMade, layupMissed, midRangeMade, midRangeMissed, paintMade, paintMissed
    case putbackMade, putbackMissed
    case dunkMade, dunkMissed

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
        }
    }

    var messageKey: String {
        switch self {
        case .twoMade: return "action_two_made"
        case .twoMissed: return "action_two_missed"
        case .threeMade: return "action_three_made"
        case .threeMissed: return "action_three_missed"
        case .bonusMade: return "action_bonus_made"
        case .bonusMissed: return "action_bonus_missed"
        case .freeThrowMade: return "action_free_made"
        case .freeThrowMissed: return "action_free_missed"
        case .foul: return "action_foul"
        case .assist: return "action_assist"
        case .rebound: return "action_rebound"
        case .offensiveRebound: return "action_offensive_rebound"
        case .defensiveRebound: return "action_defensive_rebound"
        case .block: return "action_block"
        case .steal: return "action_steal"
        case .turnover: return "action_turnover"
        case .layupMade: return "action_layup_made"
        case .layupMissed: return "action_layup_missed"
        case .midRangeMade: return "action_mid_range_made"
        case .midRangeMissed: return "action_mid_range_missed"
        case .paintMade: return "action_paint_made"
        case .paintMissed: return "action_paint_missed"
        case .putbackMade: return "action_putback_made"
        case .putbackMissed: return "action_putback_missed"
        case .dunkMade: return "action_dunk_made"
        case .dunkMissed: return "action_dunk_missed"
        }
    }

    var message: String {
        NSLocalizedString(messageKey, comment: "")
    }

    var points: Int {
        switch self {
        case .twoMade, .layupMade, .midRangeMade, .paintMade, .putbackMade, .dunkMade: return 2
        case .threeMade: return 3
        case .bonusMade, .freeThrowMade: return 1
        default: return 0
        }
    }

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
        case .putbackMade:
            stats.rebounds += 1
            stats.twoMade += 1
            stats.twoAttempts += 1
        case .putbackMissed:
            stats.rebounds += 1
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
            guard stats.rebounds > 0, stats.twoMade > 0, stats.twoAttempts > 0 else { return false }
            stats.rebounds -= 1
            stats.twoMade -= 1
            stats.twoAttempts -= 1
        case .putbackMissed:
            guard stats.rebounds > 0, stats.twoAttempts > 0 else { return false }
            stats.rebounds -= 1
            stats.twoAttempts -= 1
        }
        return true
    }

    static func parseLog(_ message: String, eventCode: String? = nil) -> (playerName: String, action: StatAction)? {
        if let eventCode = eventCode ?? GameLogFormatter.extractEventCode(from: message),
           let action = allCases.first(where: { $0.eventCode == eventCode }) {
            let normalized = GameLogFormatter.normalizedMessage(message)
            guard normalized.hasSuffix(action.message) else { return nil }
            let name = String(normalized.dropLast(action.message.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, action)
        }

        let normalized = GameLogFormatter.normalizedMessage(message)
        for action in allCases {
            guard normalized.hasSuffix(action.message) else { continue }
            let name = String(normalized.dropLast(action.message.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, action)
        }
        return nil
    }
}

extension StatAction {
    init?(liveAction: BluetoothLiveStatAction) {
        switch liveAction {
        case .twoMade: self = .twoMade
        case .twoMissed: self = .twoMissed
        case .threeMade: self = .threeMade
        case .threeMissed: self = .threeMissed
        case .bonusMade: self = .bonusMade
        case .bonusMissed: self = .bonusMissed
        case .freeThrowMade: self = .freeThrowMade
        case .freeThrowMissed: self = .freeThrowMissed
        case .foul: self = .foul
        case .assist: self = .assist
        case .rebound: self = .rebound
        case .offensiveRebound: self = .offensiveRebound
        case .defensiveRebound: self = .defensiveRebound
        case .block: self = .block
        case .steal: self = .steal
        case .turnover: self = .turnover
        case .putbackMade: self = .putbackMade
        case .putbackMissed: self = .putbackMissed
        case .layupMade: self = .layupMade
        case .layupMissed: self = .layupMissed
        case .midRangeMade: self = .midRangeMade
        case .midRangeMissed: self = .midRangeMissed
        case .paintMade: self = .paintMade
        case .paintMissed: self = .paintMissed
        case .dunkMade: self = .dunkMade
        case .dunkMissed: self = .dunkMissed
        }
    }

    var liveAction: BluetoothLiveStatAction {
        switch self {
        case .twoMade: return .twoMade
        case .twoMissed: return .twoMissed
        case .threeMade: return .threeMade
        case .threeMissed: return .threeMissed
        case .bonusMade: return .bonusMade
        case .bonusMissed: return .bonusMissed
        case .freeThrowMade: return .freeThrowMade
        case .freeThrowMissed: return .freeThrowMissed
        case .foul: return .foul
        case .assist: return .assist
        case .rebound: return .rebound
        case .offensiveRebound: return .offensiveRebound
        case .defensiveRebound: return .defensiveRebound
        case .block: return .block
        case .steal: return .steal
        case .turnover: return .turnover
        case .layupMade: return .layupMade
        case .layupMissed: return .layupMissed
        case .midRangeMade: return .midRangeMade
        case .midRangeMissed: return .midRangeMissed
        case .paintMade: return .paintMade
        case .paintMissed: return .paintMissed
        case .dunkMade: return .dunkMade
        case .dunkMissed: return .dunkMissed
        case .putbackMade: return .putbackMade
        case .putbackMissed: return .putbackMissed
        }
    }
}

extension StatAction: Equatable {}

extension StatAction: CaseIterable {
    static var allCases: [StatAction] {
        [.twoMade, .twoMissed, .threeMade, .threeMissed, .bonusMade, .bonusMissed, .freeThrowMade, .freeThrowMissed, .foul, .assist, .rebound, .offensiveRebound, .defensiveRebound, .block, .steal, .turnover, .layupMade, .layupMissed, .midRangeMade, .midRangeMissed, .paintMade, .paintMissed, .putbackMade, .putbackMissed, .dunkMade, .dunkMissed]
    }
}

