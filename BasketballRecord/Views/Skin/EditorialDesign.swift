import SwiftUI

enum EditorialDesign {
    static let canvas = Color(red: 0.976, green: 0.965, blue: 0.932)
    static let navy = Color(red: 0.035, green: 0.105, blue: 0.185)
    static let orange = Color(red: 0.89, green: 0.245, blue: 0.075)
    static let blue = Color(red: 0.12, green: 0.48, blue: 0.95)
    static let paleBlue = Color(red: 0.93, green: 0.965, blue: 1.0)
    static let paleOrange = Color(red: 1.0, green: 0.93, blue: 0.88)
    static let card = Color.white.opacity(0.92)
    static let divider = Color(red: 0.78, green: 0.82, blue: 0.86)
}

struct EditorialBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Image("EditorialBackground")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct EditorialPlayerPanelBackground: View {
    var body: some View {
        ZStack {
            Image("EditorialBackground")
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [Color.white.opacity(0.78), Color.white.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipped()
    }
}

struct EditorialCardModifier: ViewModifier {
    var tint: Color = EditorialDesign.card
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(tint, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(EditorialDesign.divider.opacity(0.42), lineWidth: 1)
            }
    }
}

struct EditorialSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(EditorialDesign.orange)
                .frame(width: 5, height: 20)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(EditorialDesign.navy)
            Spacer()
        }
    }
}

struct EditorialListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(EditorialBackground())
            .tint(EditorialDesign.blue)
    }
}

struct EditorialTabBarModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .tint(EditorialDesign.blue)
                .toolbarBackground(Color.white.opacity(0.96), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.light, for: .tabBar)
        } else {
            content
        }
    }
}

extension View {
    func editorialCard(tint: Color = EditorialDesign.card, radius: CGFloat = 18) -> some View {
        modifier(EditorialCardModifier(tint: tint, radius: radius))
    }

    func editorialListStyle() -> some View {
        modifier(EditorialListModifier())
    }

}
