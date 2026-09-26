import SwiftUI

enum AdaptiveTokens {
    static let paper = Color(red: 0.968, green: 0.952, blue: 0.918)
    static let card = Color.white.opacity(0.94)
    static let navy = Color(red: 0.06, green: 0.13, blue: 0.21)
    static let navySoft = Color(red: 0.30, green: 0.37, blue: 0.46)
    static let orange = Color(red: 0.95, green: 0.24, blue: 0.08)
    static let blue = Color(red: 0.19, green: 0.48, blue: 0.88)
    static let paleBlue = Color(red: 0.91, green: 0.95, blue: 1.0)
    static let divider = Color(red: 0.86, green: 0.86, blue: 0.84)
}

struct AdaptivePaperBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AdaptiveTokens.paper))
                var topRight = Path()
                topRight.addArc(center: CGPoint(x: size.width + 12, y: -10), radius: min(size.width, size.height) * 0.35, startAngle: .degrees(110), endAngle: .degrees(205), clockwise: false)
                context.stroke(topRight, with: .color(AdaptiveTokens.orange.opacity(0.8)), lineWidth: 5)
                var bottomLeft = Path()
                bottomLeft.addArc(center: CGPoint(x: -20, y: size.height + 20), radius: min(size.width, size.height) * 0.32, startAngle: .degrees(250), endAngle: .degrees(350), clockwise: false)
                context.stroke(bottomLeft, with: .color(AdaptiveTokens.orange.opacity(0.45)), lineWidth: 4)
                var navyBlock = Path()
                navyBlock.move(to: CGPoint(x: size.width * 0.72, y: size.height * 0.82))
                navyBlock.addLine(to: CGPoint(x: size.width, y: size.height * 0.72))
                navyBlock.addLine(to: CGPoint(x: size.width, y: size.height))
                navyBlock.addLine(to: CGPoint(x: size.width * 0.48, y: size.height))
                navyBlock.closeSubpath()
                context.fill(navyBlock, with: .color(AdaptiveTokens.navy.opacity(0.07)))
            }
        }
        .ignoresSafeArea()
    }
}

struct AdaptiveCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(AdaptiveTokens.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.85), lineWidth: 1))
    }
}
