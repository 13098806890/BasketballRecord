import SwiftUI

enum TeamBadgePalette {
    static let colors: [Color] = [
        Color(red: 0.00, green: 0.48, blue: 0.20),
        Color(red: 0.81, green: 0.07, blue: 0.25),
        Color(red: 0.00, green: 0.47, blue: 0.55),
        Color(red: 0.33, green: 0.15, blue: 0.51),
        Color(red: 0.90, green: 0.38, blue: 0.13),
        Color(red: 0.00, green: 0.42, blue: 0.71),
        Color(red: 0.60, green: 0.00, blue: 0.18),
        Color(red: 0.04, green: 0.04, blue: 0.05),
        Color(red: 0.88, green: 0.55, blue: 0.02),
        Color(red: 0.24, green: 0.42, blue: 0.78),
        Color(red: 0.58, green: 0.22, blue: 0.62),
        Color(red: 0.00, green: 0.56, blue: 0.42),
        Color(red: 0.82, green: 0.25, blue: 0.47),
        Color(red: 0.28, green: 0.32, blue: 0.38),
        Color(red: 0.43, green: 0.62, blue: 0.08),
        Color(red: 0.45, green: 0.18, blue: 0.08)
    ]

    static func color(for teamID: UUID?, name: String, paletteIndex: Int? = nil) -> Color {
        if let paletteIndex {
            return colors[paletteIndex % colors.count]
        }

        let source = teamID?.uuidString ?? name
        let hash = source.unicodeScalars.reduce(0) { partialResult, scalar in
            ((partialResult &* 31) &+ Int(scalar.value)) & 0x7fffffff
        }
        return colors[hash % colors.count]
    }
}

struct TeamBadgeView: View {
    @EnvironmentObject private var store: AppStore

    let teamID: UUID?
    let fallbackName: String
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let data = customIconData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                defaultBadge
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
        }
        .accessibilityLabel(Text(teamName))
    }

    private var teamName: String {
        store.team(for: teamID)?.name ?? fallbackName
    }

    private var customIconData: Data? {
        guard let data = store.team(for: teamID)?.iconData,
              !Dota1SkillIconCatalog.isLegacyIconData(data) else { return nil }
        return data
    }

    private var badgeColor: Color {
        let paletteIndex = teamID.flatMap { teamID in
            store.teams.firstIndex { $0.id == teamID }
        }
        return TeamBadgePalette.color(for: teamID, name: teamName, paletteIndex: paletteIndex)
    }

    private var defaultBadge: some View {
        Group {
            if let image = DefaultTeamIconCatalog.image(for: DefaultTeamIconCatalog.item(for: teamID, name: teamName, teams: store.teams)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.04)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [badgeColor.opacity(0.95), badgeColor.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "basketball.fill")
                        .font(.system(size: size * 0.68, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
    }
}
