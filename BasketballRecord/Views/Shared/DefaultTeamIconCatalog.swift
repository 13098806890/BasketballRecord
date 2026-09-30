import UIKit

enum DefaultTeamIconCatalog {
    struct Item: Identifiable {
        let id: Int
        let assetName: String
    }

    static let items: [Item] = [1, 2, 3, 4, 5, 8, 9].map { id in
        Item(id: id, assetName: String(format: "TeamDefaultIcon%02d", id))
    }

    static func image(for item: Item) -> UIImage? {
        UIImage(named: item.assetName)
    }

    static func data(for item: Item) -> Data? {
        image(for: item)?.pngData()
    }

    static func matchingID(for data: Data?) -> Int? {
        guard let data else { return nil }
        return items.first(where: { self.data(for: $0) == data })?.id
    }

    static func item(for teamID: UUID?, name: String, teams: [Team] = []) -> Item {
        if let teamID {
            let defaultTeams = teams
                .filter { team in
                    guard let iconData = team.iconData else { return true }
                    return Dota1SkillIconCatalog.isLegacyIconData(iconData)
                }
                .sorted { $0.id.uuidString < $1.id.uuidString }

            if let index = defaultTeams.firstIndex(where: { $0.id == teamID }) {
                return items[index % items.count]
            }
        }

        let source = teamID?.uuidString ?? name
        let hash = source.unicodeScalars.reduce(0) { partialResult, scalar in
            ((partialResult &* 31) &+ Int(scalar.value)) & 0x7fffffff
        }
        return items[hash % items.count]
    }
}
