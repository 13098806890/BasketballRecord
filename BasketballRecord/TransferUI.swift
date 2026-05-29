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

struct AppNeutralProminentButtonStyle: ButtonStyle {
    private let background = Color(uiColor: .secondarySystemBackground)
    private let foreground = Color(red: 0.18, green: 0.20, blue: 0.22)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, 10)
            .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}

struct TransferCodePreview: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .textSelection(.enabled)
    }
}

struct TransferCodeInput: View {
    @Binding var text: String
    var placeholder: String = "粘贴分享编码"

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
    }
}
