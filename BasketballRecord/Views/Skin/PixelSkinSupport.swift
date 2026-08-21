import SwiftUI

enum AppSkin: String, CaseIterable, Identifiable {
    case classic
    case pixelEsports

    static let storageKey = "app_skin"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .classic:
            return LocalizedStringKey("skin_classic")
        case .pixelEsports:
            return LocalizedStringKey("skin_pixel_esports")
        }
    }
}

struct PixelTabBarModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .tint(Color(red: 0.3608, green: 0.8824, blue: 0.9020))
                .toolbarBackground(Color(red: 0.0275, green: 0.0627, blue: 0.1059), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        } else {
            content
        }
    }
}
