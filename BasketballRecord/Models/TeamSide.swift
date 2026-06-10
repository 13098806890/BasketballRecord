import Foundation

enum TeamSide: String {
    case home = "主队"
    case away = "客队"
}

extension TeamSide: CaseIterable, Identifiable {
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home:
            return NSLocalizedString("team_home_default", comment: "Home team")
        case .away:
            return NSLocalizedString("team_away_default", comment: "Away team")
        }
    }
}

enum LiveCollaborationRole {
    case host
    case participant
}

extension TeamSide {
    init(liveSide: BluetoothLiveSide) {
        switch liveSide {
        case .home:
            self = .home
        case .away:
            self = .away
        }
    }

    var liveSide: BluetoothLiveSide {
        switch self {
        case .home:
            return .home
        case .away:
            return .away
        }
    }
}
