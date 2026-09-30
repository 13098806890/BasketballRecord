import Foundation

enum PrototypeTab: String {
    case management
    case score
    case career
    case settings
}

struct PrototypeManagementItem: Identifiable {
    let id = UUID()
    let title: String
    let count: Int?
    let icon: String
    let enabled: Bool
}

struct PrototypeTeamSummary: Identifiable {
    let id = UUID()
    let name: String
    let record: String
    let metrics: [(String, String)]
}

struct PrototypeSettingsSection {
    let title: String
    let items: [String]
}

struct AdaptiveMockData {
    let managementItems: [PrototypeManagementItem] = [
        PrototypeManagementItem(title: "New", count: nil, icon: "plus", enabled: true),
        PrototypeManagementItem(title: "Players", count: 6, icon: "person.fill", enabled: true),
        PrototypeManagementItem(title: "Teams", count: 2, icon: "person.3.fill", enabled: true),
        PrototypeManagementItem(title: "Game Groups", count: 0, icon: "folder.fill", enabled: false),
        PrototypeManagementItem(title: "Player Groups", count: 0, icon: "person.2.fill", enabled: false)
    ]

    let teams: [PrototypeTeamSummary] = [
        PrototypeTeamSummary(name: "Shohoku", record: "1-0", metrics: [("Games", "1"), ("Win %", "100%"), ("Net", "+4"), ("Avg Pts", "9.0"), ("Avg Allowed", "5.0"), ("Total Score", "9-5")]),
        PrototypeTeamSummary(name: "Ryonan", record: "0-1", metrics: [("Games", "1"), ("Win %", "0%"), ("Net", "-4"), ("Avg Pts", "5.0"), ("Avg Allowed", "9.0"), ("Total Score", "5-9")])
    ]

    let settingsSections: [PrototypeSettingsSection] = [
        PrototypeSettingsSection(title: "Game Preferences", items: ["Keep screen awake", "Show Bluetooth Collaboration", "Voice", "iCloud Storage"]),
        PrototypeSettingsSection(title: "Units", items: ["Height", "Weight"]),
        PrototypeSettingsSection(title: "", items: ["Basketball Record Pro"]),
        PrototypeSettingsSection(title: "Sync & Import", items: ["Upload to iCloud", "Import Game"])
    ]
}
