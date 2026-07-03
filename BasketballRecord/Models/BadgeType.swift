import Foundation

enum BadgeType: String, Codable, CaseIterable {
    case scoringKing
    case mvp
    case ironKing
    case reboundKing
    case assistKing
    case threeKing
    case efficiencyKing
    case threeStreak
    case turnoverKing
    case blockKing

    var title: String {
        switch self {
        case .scoringKing: return NSLocalizedString("badge_scoring_king", comment: "")
        case .mvp: return NSLocalizedString("badge_mvp", comment: "")
        case .ironKing: return NSLocalizedString("badge_iron_king", comment: "")
        case .reboundKing: return NSLocalizedString("badge_rebound_king", comment: "")
        case .assistKing: return NSLocalizedString("badge_assist_king", comment: "")
        case .threeKing: return NSLocalizedString("badge_three_king", comment: "")
        case .efficiencyKing: return NSLocalizedString("badge_efficiency_king", comment: "")
        case .threeStreak: return NSLocalizedString("badge_three_streak", comment: "")
        case .turnoverKing: return NSLocalizedString("badge_turnover_king", comment: "")
        case .blockKing: return NSLocalizedString("badge_block_king", comment: "")
        }
    }

    var assetName: String {
        switch self {
        case .scoringKing: return "badge_scoring_king"
        case .mvp: return "badge_mvp"
        case .ironKing: return "badge_iron_king"
        case .reboundKing: return "badge_rebound_king"
        case .assistKing: return "badge_assist_king"
        case .threeKing: return "badge_three_king"
        case .efficiencyKing: return "badge_efficiency_king"
        case .threeStreak: return "badge_three_streak"
        case .turnoverKing: return "badge_turnover_king"
        case .blockKing: return "badge_block_king"
        }
    }
}

struct PlayerBadge: Identifiable, Codable, Hashable {
    let id: UUID
    let type: BadgeType
    let gameID: UUID
    let awardedAt: Date

    init(type: BadgeType, gameID: UUID) {
        self.id = UUID()
        self.type = type
        self.gameID = gameID
        self.awardedAt = Date()
    }
}

