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

private struct HistorySectionHeader: View {
    let title: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(EditorialDesign.orange)
                    .frame(width: 5, height: 20)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

private struct HistoryListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background(EditorialBackground())
            .tint(EditorialDesign.blue)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var embedInNavigation: Bool = true
    @State private var selectedGroupID: UUID?
    @State private var isShowingImport = false
    @State private var isShowingDelete = false
    @State private var displayedGames: [SavedGame] = []
    @State private var isLoadingGames = true
    @State private var loadTask: Task<Void, Never>?
    @State private var pendingSwipeDeleteGame: SavedGame?
    @State private var expandedSections: Set<String> = []
    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if embedInNavigation {
                    NavigationStack {
                        List {
                        if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                            Section {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(group.name)
                                            .font(.headline)
                                    }
                                    Spacer()
                                    Button(action: { selectedGroupID = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }

                        if !isLoadingGames, filteredGames.isEmpty {
                            ContentUnavailableView(LocalizedStringKey("empty_no_game_history"), systemImage: "clock.badge.questionmark")
                        }

                            ForEach(monthGroups) { group in
                                Section {
                                    if expandedSections.contains(group.id) {
                                        ForEach(group.games) { game in
                                            HistoryGameLink(game: game, pendingSwipeDeleteGame: $pendingSwipeDeleteGame)
                                        }
                                        historySectionBottomAnchor(group.id)
                                    }
                                } header: {
                                    HistorySectionHeader(
                                        title: group.title,
                                        isExpanded: expandedSections.contains(group.id),
                                        action: { toggleSection(group.id, scrollProxy: proxy) }
                                    )
                                    .id(historySectionHeaderID(group.id))
                                }
                            }
                        }
                        .modifier(HistoryListModifier())
                        .navigationTitle(LocalizedStringKey("nav_game_history"))
                        .overlay {
                            if isLoadingGames {
                                VStack(spacing: 10) {
                                    ProgressView()
                                    Text(LocalizedStringKey("loading_games"))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                if store.isPro {
                                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                                }

                                BasketballExcelExportButton(
                                    isEnabled: isLoadingGames || !store.isPro || !store.savedGames.isEmpty,
                                    isLoadingGames: $isLoadingGames,
                                    loadsAllGamesFromStore: true,
                                    selectedGamesExportFile: { games in
                                        BasketballExcelReportBuilder.historyArchive(games, players: store.players)
                                    },
                                    makeExportFile: {
                                        BasketballExcelReportBuilder.historyArchive(store.savedGames, players: store.players)
                                    }
                                )

                                Button {
                                    isShowingDelete = true
                                } label: {
                                    Label(LocalizedStringKey("label_delete"), systemImage: "trash")
                                }

                                Button {
                                    isShowingImport = true
                                } label: {
                                    Label(LocalizedStringKey("label_import"), systemImage: TransferSymbol.importData)
                                }
                            }
                        }
                    }
                } else {
                    List {
                    if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(group.name)
                                        .font(.headline)
                                }
                                Spacer()
                                Button(action: { selectedGroupID = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    if !isLoadingGames, filteredGames.isEmpty {
                        ContentUnavailableView(LocalizedStringKey("empty_no_game_history"), systemImage: "clock.badge.questionmark")
                    }

                        ForEach(monthGroups) { group in
                            Section {
                                if expandedSections.contains(group.id) {
                                    ForEach(group.games) { game in
                                        HistoryGameLink(game: game, pendingSwipeDeleteGame: $pendingSwipeDeleteGame)
                                    }
                                    historySectionBottomAnchor(group.id)
                                }
                            } header: {
                                HistorySectionHeader(
                                    title: group.title,
                                    isExpanded: expandedSections.contains(group.id),
                                    action: { toggleSection(group.id, scrollProxy: proxy) }
                                )
                                .id(historySectionHeaderID(group.id))
                            }
                        }
                    }
                    .modifier(HistoryListModifier())
                    .overlay {
                        if isLoadingGames {
                            VStack(spacing: 10) {
                                ProgressView()
                                Text(LocalizedStringKey("loading_games"))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if store.isPro {
                                GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                            }

                            BasketballExcelExportButton(
                                isEnabled: isLoadingGames || !store.isPro || !store.savedGames.isEmpty,
                                isLoadingGames: $isLoadingGames,
                                loadsAllGamesFromStore: true,
                                selectedGamesExportFile: { games in
                                    BasketballExcelReportBuilder.historyArchive(games, players: store.players)
                                },
                                makeExportFile: {
                                    BasketballExcelReportBuilder.historyArchive(store.savedGames, players: store.players)
                                }
                            )

                            Button {
                                isShowingDelete = true
                            } label: {
                                Label(LocalizedStringKey("label_delete"), systemImage: "trash")
                            }

                            Button {
                                isShowingImport = true
                            } label: {
                                Label(LocalizedStringKey("label_import"), systemImage: TransferSymbol.importData)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDelete) {
            DeleteSavedGamesView()
        }
        .sheet(isPresented: $isShowingImport) {
            ImportGameView()
        }
        .onAppear {
            selectedGroupID = store.isPro ? FilterDefaults.load(FilterDefaults.historyKey) : nil
            loadGamesAsync(showLoading: displayedGames.isEmpty)
        }
        .onChange(of: store.savedGames) { _, _ in
            loadGamesAsync(showLoading: false)
            let validIDs = Set(monthGroups.map(\.id))
            if expandedSections != expandedSections.intersection(validIDs) {
                expandedSections = expandedSections.intersection(validIDs)
            }
        }
        .onChange(of: selectedGroupID) { _, newValue in
            guard store.isPro else { return }
            FilterDefaults.save(FilterDefaults.historyKey, newValue)
            let validIDs = Set(monthGroups.map(\.id))
            if expandedSections != expandedSections.intersection(validIDs) {
                expandedSections = expandedSections.intersection(validIDs)
            }
        }
        .onChange(of: expandedSections) { _, newValue in
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "expanded_sections")
            }
        }
            .alert(LocalizedStringKey("alert_confirm_delete_game_title"), isPresented: Binding(
                get: { pendingSwipeDeleteGame != nil },
                set: { if !$0 { pendingSwipeDeleteGame = nil } }
            )) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) {
                    pendingSwipeDeleteGame = nil
                }
                Button(LocalizedStringKey("label_delete"), role: .destructive) {
                    if let gameID = pendingSwipeDeleteGame?.id {
                        deleteGame(id: gameID)
                    }
                    pendingSwipeDeleteGame = nil
                }
            } message: {
                Text(LocalizedStringKey("text_irreversible_deletion"))
        }
    }

    private var filteredGames: [SavedGame] {
        var games = displayedGames
        if store.isPro, let selectedGroupID = selectedGroupID {
            games = games.filter { $0.groupIDs.contains(selectedGroupID) }
        }
        return games
    }

    private var monthGroups: [GameMonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredGames) { game in
            let components = calendar.dateComponents([.year, .month], from: game.savedAt)
            return GameMonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }
        return grouped.keys.sorted(by: >).map { key in
            GameMonthGroup(key: key, games: grouped[key, default: []].sorted { $0.savedAt > $1.savedAt })
        }
    }

    private func deleteGame(id: UUID) {
        store.deleteSavedGames(ids: Set([id]))
    }

    private func toggleSection(_ id: String, scrollProxy: ScrollViewProxy) {
        let isExpanded = expandedSections.contains(id)
        withAnimation(accordionAnimation) {
            if isExpanded {
                expandedSections.remove(id)
                scrollProxy.scrollTo(historySectionHeaderID(id), anchor: .top)
            } else {
                expandedSections.insert(id)
                scrollProxy.scrollTo(historySectionBottomID(id), anchor: .bottom)
            }
        }
    }

    private var accordionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    }

    private func historySectionHeaderID(_ groupID: String) -> String {
        "history-section-header-\(groupID)"
    }

    private func historySectionBottomID(_ groupID: String) -> String {
        "history-section-bottom-\(groupID)"
    }

    private func historySectionBottomAnchor(_ groupID: String) -> some View {
        Color.clear
            .frame(height: 1)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .id(historySectionBottomID(groupID))
    }

    private func loadGamesAsync(showLoading: Bool) {
        let currentGames = store.savedGames
        loadTask?.cancel()
        if showLoading {
            isLoadingGames = true
        }

        loadTask = Task {
            if showLoading {
                try? await Task.sleep(nanoseconds: 120_000_000)
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled else { return }

            let sortedGames = currentGames.sorted { $0.savedAt > $1.savedAt }
            await MainActor.run {
                displayedGames = sortedGames
                isLoadingGames = false
                if let data = UserDefaults.standard.data(forKey: "expanded_sections"),
                   let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
                    let validIDs = Set(sortedGames.map { "\(Calendar.current.component(.year, from: $0.savedAt))-\(Calendar.current.component(.month, from: $0.savedAt))" })
                    expandedSections = ids.intersection(validIDs)
                }
            }
        }
    }
private struct DeleteSavedGamesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if orderedGames.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("empty_no_game_history"), systemImage: "clock.badge.questionmark")
                }

                ForEach(orderedGames) { game in
                    Button {
                        toggle(game.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(game.id) ? .red : .secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(String(format: NSLocalizedString("game_vs_format", comment: "Team vs"), game.homeTeamName, game.awayTeamName))
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(scoreLine(for: game))
.font(.subheadline.monospacedDigit().weight(.bold))
                                }

                Text(game.gameTimeText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(LocalizedStringKey("nav_delete_games"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(format: NSLocalizedString("button_delete_count", comment: "Delete count"), selectedIDs.count)) {
                        isShowingDeleteConfirmation = true
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .alert(LocalizedStringKey("alert_confirm_delete_games_title"), isPresented: $isShowingDeleteConfirmation) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("label_delete"), role: .destructive) {
                    store.deleteSavedGames(ids: selectedIDs)
                    selectedIDs.removeAll()
                    if store.savedGames.isEmpty {
                        dismiss()
                    }
                }
            } message: {
                Text(LocalizedStringKey("text_irreversible_deletion"))
            }
        }
    }

    private var orderedGames: [SavedGame] {
        store.savedGames.sorted { $0.savedAt > $1.savedAt }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        "\(score(for: game.snapshot.homeTeamID, in: game)) - \(score(for: game.snapshot.awayTeamID, in: game))"
    }

    private func score(for teamID: UUID?, in game: SavedGame) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

}

struct SavedGameRow: View {
    var game: SavedGame
    var lockAction: (() -> Void)?
    var lockIsEnabled: Bool = false
    var cloudAction: (() -> Void)?
    var cloudIsEnabled: Bool = false

    init(
        game: SavedGame,
        lockAction: (() -> Void)? = nil,
        lockIsEnabled: Bool = false,
        cloudAction: (() -> Void)? = nil,
        cloudIsEnabled: Bool = false
    ) {
        self.game = game
        self.lockAction = lockAction
        self.lockIsEnabled = lockIsEnabled
        self.cloudAction = cloudAction
        self.cloudIsEnabled = cloudIsEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !game.displayName.isEmpty {
                Text(game.displayTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                    .lineLimit(1)
            }

            HStack(alignment: .center, spacing: 8) {
                historyTeamMark(name: game.homeTeamName, teamID: game.snapshot.homeTeamID)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10)

                VStack(spacing: 2) {
                    Text(compactGameTimeText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        Text("\(score(for: game.snapshot.homeTeamID))")
                        Text("-")
                            .foregroundStyle(.secondary)
                        Text("\(score(for: game.snapshot.awayTeamID))")
                    }
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(EditorialDesign.navy)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                    gameActions
                }
                .frame(width: 124)

                historyTeamMark(name: game.awayTeamName, teamID: game.snapshot.awayTeamID)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 10)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(EditorialDesign.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EditorialDesign.divider.opacity(0.5), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var gameActions: some View {
        HStack(spacing: 4) {
            if let lockAction {
                Button(action: lockAction) {
                    Image(systemName: lockIsEnabled ? "lock.fill" : "lock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(lockIsEnabled ? EditorialDesign.orange : .secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey(lockIsEnabled ? "label_unlock" : "label_lock"))
            }

            if let cloudAction {
                Button(action: cloudAction) {
                    Image(systemName: cloudIsEnabled ? "icloud.fill" : "icloud.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(cloudIsEnabled ? EditorialDesign.blue : EditorialDesign.orange)
                        .frame(width: 28, height: 28)
                        .background(
                            cloudIsEnabled ? EditorialDesign.paleBlue : EditorialDesign.paleOrange,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey("label_cloud"))
            }
        }
    }

    private func historyTeamMark(name: String, teamID: UUID?) -> some View {
        return VStack(alignment: .center, spacing: 6) {
            TeamBadgeView(teamID: teamID, fallbackName: name, size: 56)
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EditorialDesign.navy)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minHeight: 68)
    }

    private func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private var compactGameTimeText: String {
        let start = game.snapshot.logs.first?.timestamp ?? game.savedAt
        let end = game.savedAt
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        if calendar.isDate(start, inSameDayAs: end) {
            dateFormatter.dateFormat = "M/d"
            timeFormatter.dateFormat = "HH:mm"
            return "\(dateFormatter.string(from: start)) \(timeFormatter.string(from: start))–\(timeFormatter.string(from: end))"
        }
        dateFormatter.dateFormat = "M/d HH:mm"
        return "\(dateFormatter.string(from: start))–\(dateFormatter.string(from: end))"
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
}

struct HistoryGameLink: View {
    @EnvironmentObject private var store: AppStore
    let game: SavedGame
    @Binding var pendingSwipeDeleteGame: SavedGame?
    @State private var isShowingDetail = false

    var body: some View {
        HistoryView.SavedGameRow(
            game: game,
            lockAction: { toggleLock() },
            lockIsEnabled: game.isLocked,
            cloudAction: store.isPro ? { store.toggleCloudStorage(for: game.id) } : nil,
            cloudIsEnabled: store.cloudEnabledGameIDs.contains(game.id)
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { isShowingDetail = true }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                toggleLock()
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
        .navigationDestination(isPresented: $isShowingDetail) {
            SavedGameDetailView(game: game)
        }
    }

    private func toggleLock() {
        if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
            store.savedGames[idx].isLocked.toggle()
            store.markSavedGameModified(game.id)
        }
    }
}

private extension SavedGame {
    var gameTimeText: String {
        let start = snapshot.logs.first?.timestamp ?? savedAt
        let end = savedAt
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(fmt.string(from: start)) - \(fmt.string(from: end))"
    }
}
