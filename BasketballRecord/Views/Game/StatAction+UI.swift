import Foundation
import SwiftUI

extension StatAction {
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
        case .assistTwoMade: return "action_assist_two_made"
        case .assistThreeMade: return "action_assist_three_made"
        case .stealTurnover: return "action_steal_turnover"
        }
    }

    var message: String {
        NSLocalizedString(messageKey, comment: "")
    }

    static func parseLog(_ message: String, eventCode: String? = nil) -> (playerName: String, action: StatAction)? {
        guard let code = eventCode ?? GameLogFormatter.extractEventCode(from: message),
              let action = allCases.first(where: { $0.eventCode == code }) else { return nil }
        let normalized = GameLogFormatter.normalizedMessage(message)
        let name = String(normalized.dropLast(action.message.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return (name, action)
    }

    static func parseFromSuffix(_ message: String) -> (playerName: String, action: StatAction)? {
        let normalized = GameLogFormatter.normalizedMessage(message)
        for action in allCases {
            let candidates = action.suffixCandidates
            for suffix in candidates where normalized.hasSuffix(suffix) {
                let name = String(normalized.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                return (name, action)
            }
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
        @unknown default: return nil
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
        case .assistTwoMade: return .twoMade
        case .assistThreeMade: return .threeMade
        case .stealTurnover: return .turnover
        }
    }
}
