import SwiftUI

enum PrototypeTokens {
    static let navy = Color(red: 0.08, green: 0.14, blue: 0.22)
    static let blue = Color(red: 0.26, green: 0.54, blue: 0.78)
    static let paleBlue = Color(red: 0.91, green: 0.95, blue: 0.98)
    static let orange = Color(red: 0.96, green: 0.39, blue: 0.16)
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let inkSoft = Color(red: 0.35, green: 0.38, blue: 0.42)
    static let line = Color(red: 0.87, green: 0.88, blue: 0.89)
}

struct PrototypeCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypeTokens.line, lineWidth: 1))
    }
}

struct PrototypeSectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(PrototypeTokens.orange)
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PrototypeTokens.navy)
        }
    }
}
