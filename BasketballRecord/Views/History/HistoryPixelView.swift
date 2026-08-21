import SwiftUI

struct GameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: GameMonthKey, rhs: GameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

struct GameMonthGroup: Identifiable {
    var key: GameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { String(format: NSLocalizedString("month_title_format", comment: "Month title"), key.year, key.month) }
}

private struct HistoryPixelPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut = min(7, min(rect.width, rect.height) / 5)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private enum HistoryPixelDesign {
    static let ink = Color(red: 0.9569, green: 0.9686, blue: 0.9843)
    static let muted = Color(red: 0.5529, green: 0.6078, blue: 0.6784)
    static let background = Color(red: 0.0275, green: 0.0627, blue: 0.1059)
    static let panel = Color(red: 0.0510, green: 0.1020, blue: 0.1647)
    static let panelStrong = Color(red: 0.0667, green: 0.1216, blue: 0.1922)
    static let line = Color(red: 0.5373, green: 0.6941, blue: 0.8196, opacity: 0.28)
    static let cyan = Color(red: 0.3608, green: 0.8824, blue: 0.9020)
    static let amber = Color(red: 1.0, green: 0.7843, blue: 0.3412)
    static let lime = Color(red: 0.6549, green: 0.8902, blue: 0.3647)
}

private struct HistoryPixelBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(HistoryPixelDesign.background))

            let gridStep: CGFloat = 16
            var x: CGFloat = 0
            while x <= size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(HistoryPixelDesign.cyan.opacity(0.035)), lineWidth: 1)
                x += gridStep
            }

            var y: CGFloat = 0
            while y <= size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(HistoryPixelDesign.cyan.opacity(0.035)), lineWidth: 1)
                y += gridStep
            }
        }
        .ignoresSafeArea()
    }
}

struct HistoryPixelView: View {
    @EnvironmentObject private var store: AppStore
    var embedInNavigation: Bool
    @Binding var searchText: String
    @Binding var selectedGroupID: UUID?
    @Binding var isShowingImport: Bool
    @Binding var isShowingDelete: Bool
    @Binding var pendingSwipeDeleteGame: SavedGame?
    @Binding var expandedSections: Set<String>
    var isLoadingGames: Bool
    var hasNoGames: Bool
    var monthGroups: [GameMonthGroup]

    var body: some View {
        Group {
            if embedInNavigation {
                NavigationStack {
                    pixelHistoryList
                }
            } else {
                pixelHistoryList
            }
        }
    }

    private var pixelHistoryList: some View {
        ZStack {
            HistoryPixelBackground()

            if !isLoadingGames, hasNoGames {
                ContentUnavailableView(
                    LocalizedStringKey("empty_no_game_history"),
                    systemImage: "clock.badge.questionmark"
                )
                .foregroundStyle(HistoryPixelDesign.ink)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                            pixelSelectedFilter(groupName: group.name)
                        }

                        ForEach(monthGroups) { group in
                            VStack(spacing: 0) {
                                pixelMonthHeader(group)

                                if expandedSections.contains(group.id) {
                                    ForEach(group.games) { game in
                                        pixelGameLink(game)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }

            if isLoadingGames {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(HistoryPixelDesign.cyan)
                    Text(LocalizedStringKey("loading_games"))
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(HistoryPixelDesign.muted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: HistoryPixelPanelShape())
                .overlay(HistoryPixelPanelShape().stroke(HistoryPixelDesign.line, lineWidth: 1))
            }
        }
        .navigationTitle(LocalizedStringKey("nav_game_history"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: LocalizedStringKey("search_player_prompt"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.isPro {
                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                }

                Button {
                    isShowingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(HistoryPixelDesign.amber)
                }
                .accessibilityLabel(LocalizedStringKey("label_delete"))

                Button {
                    isShowingImport = true
                } label: {
                    Image(systemName: TransferSymbol.importData)
                        .foregroundStyle(HistoryPixelDesign.cyan)
                }
                .accessibilityLabel(LocalizedStringKey("label_import"))
            }
        }
    }

    private func pixelSelectedFilter(groupName: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(HistoryPixelDesign.amber)
                .frame(width: 4, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey("game_group_selected_filter"))
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(HistoryPixelDesign.muted)
                Text(groupName)
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(HistoryPixelDesign.ink)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                selectedGroupID = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(HistoryPixelDesign.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(HistoryPixelDesign.panelStrong.opacity(0.75))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HistoryPixelDesign.line)
                .frame(height: 1)
        }
        .padding(.bottom, 8)
    }

    private func pixelMonthHeader(_ group: GameMonthGroup) -> some View {
        Button {
            if expandedSections.contains(group.id) {
                expandedSections.remove(group.id)
            } else {
                expandedSections.insert(group.id)
            }
        } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(HistoryPixelDesign.cyan)
                    .frame(width: 5, height: 16)
                Text(group.title)
                    .font(.system(.headline, design: .monospaced).weight(.black))
                    .foregroundStyle(HistoryPixelDesign.ink)
                Text(String(format: NSLocalizedString("game_group_games_count", comment: "Game count"), group.games.count))
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(HistoryPixelDesign.muted)
                Spacer()
                Image(systemName: expandedSections.contains(group.id) ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(HistoryPixelDesign.cyan)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pixelGameLink(_ game: SavedGame) -> some View {
        NavigationLink {
            SavedGameDetailView(game: game)
        } label: {
            PixelSavedGameRow(game: game)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if store.isPro {
                Button {
                    store.toggleCloudStorage(for: game.id)
                } label: {
                    Label("iCloud", systemImage: store.cloudEnabledGameIDs.contains(game.id) ? "icloud.slash" : "icloud")
                }
                .tint(.blue)
            }
            Button {
                if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
                    store.savedGames[idx].isLocked.toggle()
                }
            } label: {
                Label(LocalizedStringKey(game.isLocked ? "label_unlock" : "label_lock"), systemImage: game.isLocked ? "lock.open" : "lock")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !game.isLocked {
                Button {
                    pendingSwipeDeleteGame = game
                } label: {
                    Label(LocalizedStringKey("label_delete"), systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .padding(.bottom, 8)
    }
}

private struct PixelSavedGameRow: View {
    var game: SavedGame

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 1) {
                Text(dayText)
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .foregroundStyle(HistoryPixelDesign.amber)
                Text(monthText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(HistoryPixelDesign.muted)
            }
            .frame(width: 48)

            Rectangle()
                .fill(HistoryPixelDesign.cyan.opacity(0.7))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 5) {
                if !game.displayName.isEmpty {
                    Text(game.displayName)
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(HistoryPixelDesign.cyan)
                        .lineLimit(1)
                }

                Text(game.homeTeamName)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(HistoryPixelDesign.ink)
                    .lineLimit(1)
                Text(game.awayTeamName)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(HistoryPixelDesign.ink.opacity(0.8))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: game.snapshot.isComplete ? "checkmark.circle.fill" : "play.circle.fill")
                        .foregroundStyle(game.snapshot.isComplete ? HistoryPixelDesign.lime : HistoryPixelDesign.amber)
                    Text(NSLocalizedString(game.snapshot.isComplete ? "period_summary_finished" : "alert_unfinished_game_title", comment: "Game status"))
                    Text("·")
                    Text(String(format: NSLocalizedString("count_periods_format", comment: "Period count"), game.snapshot.periodCount))
                    Text("·")
                    Text(timeRange)
                }
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(HistoryPixelDesign.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(score(for: game.snapshot.homeTeamID))")
                    .font(.system(size: 23, weight: .black, design: .monospaced))
                    .foregroundStyle(scoreColor(for: game.snapshot.homeTeamID))
                Text("\(score(for: game.snapshot.awayTeamID))")
                    .font(.system(size: 23, weight: .black, design: .monospaced))
                    .foregroundStyle(scoreColor(for: game.snapshot.awayTeamID))
            }
            .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(HistoryPixelPanelShape().fill(HistoryPixelDesign.panel))
        .overlay(HistoryPixelPanelShape().stroke(HistoryPixelDesign.line, lineWidth: 1))
    }

    private var dayText: String {
        Self.dayFormatter.string(from: game.savedAt)
    }

    private var monthText: String {
        Self.monthFormatter.string(from: game.savedAt)
    }

    private var timeRange: String {
        let start = game.snapshot.logs.first?.timestamp ?? game.savedAt
        let end = game.savedAt
        return "\(Self.timeFormatter.string(from: start))–\(Self.timeFormatter.string(from: end))"
    }

    private func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private func scoreColor(for teamID: UUID?) -> Color {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        guard homeScore != awayScore else { return HistoryPixelDesign.ink }
        return score(for: teamID) == max(homeScore, awayScore) ? HistoryPixelDesign.amber : HistoryPixelDesign.muted
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
