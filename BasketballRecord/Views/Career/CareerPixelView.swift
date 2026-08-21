import SwiftUI

struct CareerPixelPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut: CGFloat = min(8, min(rect.width, rect.height) / 5)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

enum CareerPixelDesign {
    static let ink = Color(red: 0.9569, green: 0.9686, blue: 0.9843)
    static let muted = Color(red: 0.5529, green: 0.6078, blue: 0.6784)
    static let background = Color(red: 0.0275, green: 0.0627, blue: 0.1059)
    static let panel = Color(red: 0.0510, green: 0.1020, blue: 0.1647)
    static let panelStrong = Color(red: 0.0667, green: 0.1216, blue: 0.1922)
    static let line = Color(red: 0.5373, green: 0.6941, blue: 0.8196, opacity: 0.30)
    static let cyan = Color(red: 0.3608, green: 0.8824, blue: 0.9020)
    static let amber = Color(red: 1.0, green: 0.7843, blue: 0.3412)
    static let lime = Color(red: 0.6549, green: 0.8902, blue: 0.3647)
}

struct CareerPixelBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(CareerPixelDesign.background))

            let gridStep: CGFloat = 16
            var x: CGFloat = 0
            while x <= size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(CareerPixelDesign.cyan.opacity(0.035)), lineWidth: 1)
                x += gridStep
            }

            var y: CGFloat = 0
            while y <= size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(CareerPixelDesign.cyan.opacity(0.035)), lineWidth: 1)
                y += gridStep
            }
        }
        .ignoresSafeArea()
    }
}

struct CareerPixelButtonStyle: ButtonStyle {
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .shadow(color: accent.opacity(configuration.isPressed ? 0.08 : 0.24), radius: 0, x: configuration.isPressed ? 0 : 3, y: configuration.isPressed ? 0 : 3)
    }
}

struct CareerNavigationBarSkin: ViewModifier {
    let isPixelSkin: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPixelSkin {
            content.toolbar(.hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

struct CareerPixelView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var boardKind: CareerBoardKind
    @Binding var selectedGroupID: UUID?
    @Binding var selectedPlayerGroupID: UUID?
    @Binding var playerSortField: PlayerSortField
    @Binding var playerSortAscending: Bool

    var body: some View {
        ZStack {
            CareerPixelBackground()

            VStack(spacing: 0) {
                pixelHeader
                pixelBoardPicker
                pixelFilters
                boardContent
            }
            .padding(.bottom, 16)
        }
    }

    private var pixelHeader: some View {
        HStack(spacing: 10) {
            Text(LocalizedStringKey(boardKind == .history ? "nav_game_history" : "tab_career"))
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPixelDesign.ink)
                .tracking(1.4)

            Spacer()

            if store.isPro {
                PlayerGroupPicker(store: store, selectedGroupID: $selectedPlayerGroupID)
                GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .tint(CareerPixelDesign.cyan)
    }

    private var pixelBoardPicker: some View {
        HStack(spacing: 0) {
            ForEach(CareerBoardKind.allCases) { kind in
                Button {
                    boardKind = kind
                } label: {
                    Text(LocalizedStringKey(kind.rawValue))
                        .font(.system(.caption, design: .monospaced).weight(.black))
                        .foregroundStyle(boardKind == kind ? CareerPixelDesign.cyan : CareerPixelDesign.muted)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(boardKind == kind ? CareerPixelDesign.panelStrong : CareerPixelDesign.panel.opacity(0.55))
                        .overlay {
                            if boardKind == kind {
                                CareerPixelPanelShape()
                                    .stroke(CareerPixelDesign.cyan, lineWidth: 2)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(CareerPixelButtonStyle(accent: CareerPixelDesign.cyan))
            }
        }
        .background(CareerPixelPanelShape().fill(CareerPixelDesign.panel))
        .overlay(CareerPixelPanelShape().stroke(CareerPixelDesign.line, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var pixelFilters: some View {
        if boardKind != .history, store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
            pixelFilterRow(title: NSLocalizedString("game_group_selected_filter", comment: "Filtering by"), name: group.name) {
                selectedGroupID = nil
            }
        }

        if boardKind != .history, store.isPro, let groupID = selectedPlayerGroupID, let group = store.playerGroups.first(where: { $0.id == groupID }) {
            pixelFilterRow(title: NSLocalizedString("player_group_selected_filter", comment: "Filtering by player group"), name: group.name) {
                selectedPlayerGroupID = nil
            }
        }
    }

    private func pixelFilterRow(title: String, name: String, clear: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(CareerPixelDesign.muted)
            Text(name)
                .font(.system(.caption2, design: .monospaced).weight(.black))
                .foregroundStyle(CareerPixelDesign.cyan)
            Spacer()
            Button(action: clear) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.black))
            }
            .buttonStyle(CareerPixelButtonStyle(accent: CareerPixelDesign.cyan))
        }
        .foregroundStyle(CareerPixelDesign.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 30)
        .background(CareerPixelPanelShape().fill(CareerPixelDesign.panel))
        .overlay(CareerPixelPanelShape().stroke(CareerPixelDesign.line, lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var boardContent: some View {
        if boardKind == .history {
            HistoryView(embedInNavigation: false)
        } else if boardKind == .team {
            TeamCareerBoardView(selectedGroupID: $selectedGroupID, usesPixelSkin: true)
        } else {
            PlayerCareerBoardView(
                selectedGroupID: $selectedGroupID,
                selectedPlayerGroupID: $selectedPlayerGroupID,
                sortField: $playerSortField,
                sortAscending: $playerSortAscending,
                usesPixelSkin: true
            )
        }
    }
}
