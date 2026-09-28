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
        Color(red: 0.04, green: 0.04, blue: 0.05)
    ]

    static func color(for teamID: UUID?, name: String) -> Color {
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
    var usesPixelSkin: Bool = false

    var body: some View {
        Group {
            if let data = store.team(for: teamID)?.iconData, let image = UIImage(data: data) {
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

    private var badgeColor: Color {
        TeamBadgePalette.color(for: teamID, name: teamName)
    }

    private var defaultBadge: some View {
        ZStack {
            LinearGradient(
                colors: [badgeColor.opacity(0.95), badgeColor.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: usesPixelSkin ? "shield.fill" : "basketball.fill")
                .font(.system(size: usesPixelSkin ? size * 0.42 : size * 0.56, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}
