import SwiftUI

enum TransferSymbol {
    static let importData = "tray.and.arrow.down.fill"
    static let exportData = "tray.and.arrow.up.fill"
}

struct AppSoftProminentButtonStyle: ButtonStyle {
    private let background = Color(red: 0.80, green: 0.90, blue: 0.99)
    private let foreground = Color(red: 0.18, green: 0.20, blue: 0.22)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, 10)
            .background(background.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}
