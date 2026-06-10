import SwiftUI

enum GamePalette {
    static let make = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.40, blue: 0.20, alpha: 1) : UIColor(red: 0.78, green: 0.93, blue: 0.78, alpha: 1)
    })
    static let miss = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.30, blue: 0.45, alpha: 1) : UIColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1)
    })
    static let assist = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.28, blue: 0.45, alpha: 1) : UIColor(red: 0.74, green: 0.86, blue: 0.98, alpha: 1)
    })
    static let rebound = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.32, blue: 0.48, alpha: 1) : UIColor(red: 0.80, green: 0.90, blue: 0.99, alpha: 1)
    })
    static let warning = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.45, green: 0.18, blue: 0.18, alpha: 1) : UIColor(red: 0.96, green: 0.80, blue: 0.80, alpha: 1)
    })
    static let period = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.40, blue: 0.70, alpha: 1) : UIColor(red: 0.36, green: 0.63, blue: 0.95, alpha: 1)
    })
    static let periodEnd = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.30, blue: 0.18, alpha: 1) : UIColor(red: 0.96, green: 0.72, blue: 0.63, alpha: 1)
    })
    static let substitution = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.20, green: 0.38, blue: 0.68, alpha: 1) : UIColor(red: 0.42, green: 0.67, blue: 0.95, alpha: 1)
    })
    static let pause = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.50, green: 0.38, blue: 0.12, alpha: 1) : UIColor(red: 0.98, green: 0.82, blue: 0.45, alpha: 1)
    })
    static let finish = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.18, blue: 0.12, alpha: 1) : UIColor(red: 0.95, green: 0.48, blue: 0.44, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1) : UIColor(red: 0.96, green: 0.98, blue: 1.00, alpha: 1)
    })
    static let selectedBorder = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.50, green: 0.70, blue: 0.95, alpha: 1) : UIColor(red: 0.25, green: 0.55, blue: 0.90, alpha: 1)
    })
    static let onCourtBorder = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.75, blue: 0.95, alpha: 1) : UIColor(red: 0.45, green: 0.69, blue: 0.93, alpha: 1)
    })
    static let text = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1) : UIColor(red: 0.18, green: 0.20, blue: 0.22, alpha: 1)
    })
}

enum ActionButtonStyle {
    case made, missed, assist, rebound, warning, substitution, pause, period, periodEnd, neutral

    var background: Color {
        switch self {
        case .made: return GamePalette.make
        case .missed: return GamePalette.miss
        case .assist: return GamePalette.assist
        case .rebound: return GamePalette.rebound
        case .warning: return GamePalette.warning
        case .substitution: return GamePalette.substitution
        case .pause: return GamePalette.pause
        case .period: return GamePalette.period
        case .periodEnd: return GamePalette.periodEnd
        case .neutral: return Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(red: 0.25, green: 0.26, blue: 0.30, alpha: 1) : UIColor(red: 0.88, green: 0.90, blue: 0.92, alpha: 1)
        })
        }
    }

    var foreground: Color { GamePalette.text }
}

struct PastelActionButtonStyle: ButtonStyle {
    var style: ActionButtonStyle
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(style.foreground)
            .background(style.background.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
