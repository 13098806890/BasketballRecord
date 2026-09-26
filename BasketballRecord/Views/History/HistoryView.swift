import SwiftUI

private struct HistorySectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(EditorialDesign.orange)
                .frame(width: 5, height: 20)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(EditorialDesign.navy)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct CareerHistoryListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .tint(EditorialDesign.blue)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    var embedInNavigation: Bool = true
    @State private var searchText = ""
    @State private var selectedGroupID: UUID?
    @State private var isShowingImport = false
    @State private var isShowingDelete = false
    @State private var displayedGames: [SavedGame] = []
    @State private var isLoadingGames = true
    @State private var loadTask: Task<Void, Never>?
    @State private var pendingSwipeDeleteGame: SavedGame?
    @State private var expandedSections: Set<String> = []
    @AppStorage(AppSkin.storageKey) private var appSkinRaw = AppSkin.classic.rawValue

    private var usesPixelSkin: Bool { AppSkin(rawValue: appSkinRaw) == .pixelEsports }

    var body: some View {
        Group {
            if usesPixelSkin {
                HistoryPixelView(
                    embedInNavigation: embedInNavigation,
                    searchText: $searchText,
                    selectedGroupID: $selectedGroupID,
                    isShowingImport: $isShowingImport,
                    isShowingDelete: $isShowingDelete,
                    pendingSwipeDeleteGame: $pendingSwipeDeleteGame,
                    expandedSections: $expandedSections,
                    isLoadingGames: $isLoadingGames,
                    hasNoGames: filteredGames.isEmpty,
                    monthGroups: monthGroups
                )
            } else if embedInNavigation {
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
                            DisclosureGroup(isExpanded: Binding(
                                get: { expandedSections.contains(group.id) },
                                set: { expanded in
                                    if expanded { expandedSections.insert(group.id) }
                                    else { expandedSections.remove(group.id) }
                                }
                            )) {
                                ForEach(group.games) { game in
                                    HistoryGameLink(game: game, pendingSwipeDeleteGame: $pendingSwipeDeleteGame)
                                }
                        } label: {
                                HistorySectionHeader(title: group.title)
                            }
                        }
                    }
                    .editorialListStyle()
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
                    .searchable(text: $searchText, prompt: LocalizedStringKey("search_player_prompt"))
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
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedSections.contains(group.id) },
                            set: { expanded in
                                if expanded { expandedSections.insert(group.id) }
                                else { expandedSections.remove(group.id) }
                            }
                        )) {
                            ForEach(group.games) { game in
                                HistoryGameLink(game: game, pendingSwipeDeleteGame: $pendingSwipeDeleteGame)
                            }
                    } label: {
                            HistorySectionHeader(title: group.title)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .modifier(CareerHistoryListModifier())
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
                .searchable(text: $searchText, prompt: LocalizedStringKey("search_player_prompt"))
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
        filterGames(displayedGames)
    }

    private func filterGames(_ source: [SavedGame]) -> [SavedGame] {
        var games = source

        // Filter by group if selected (Pro only)
        if store.isPro, let selectedGroupID = selectedGroupID {
            games = games.filter { $0.groupIDs.contains(selectedGroupID) }
        }

        // Filter by search text
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return games }
        return games.filter { game in
            game.playerNamesByID.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
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
    @EnvironmentObject private var store: AppStore
    var game: SavedGame

    init(game: SavedGame) {
        self.game = game
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                historyTeamMark(name: game.homeTeamName, color: EditorialDesign.orange)

                Spacer(minLength: 4)

                VStack(spacing: 4) {
                    Text(LocalizedStringKey("section_result"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(scoreLine)
                        .font(.title2.monospacedDigit().weight(.black))
                        .foregroundStyle(EditorialDesign.navy)
                    Text(gameDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(resultTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(resultColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(resultColor.opacity(0.12), in: Capsule())
                }

                Spacer(minLength: 4)

                historyTeamMark(name: game.awayTeamName, color: EditorialDesign.blue)
            }

            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                if game.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(EditorialDesign.orange)
                }
                Text(game.gameTimeText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(EditorialDesign.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(EditorialDesign.orange)
                .frame(width: 4, height: 58)
                .padding(.leading, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(EditorialDesign.divider.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: EditorialDesign.navy.opacity(0.05), radius: 10, y: 5)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }

    private func historyTeamMark(name: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "tshirt.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EditorialDesign.navy)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        game.displayTitle
    }

    private var scoreLine: String {
        "\(score(for: game.snapshot.homeTeamID)) - \(score(for: game.snapshot.awayTeamID))"
    }

    private func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private var gameDateText: String {
        game.savedAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var resultTitle: LocalizedStringKey {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        if homeScore == awayScore { return LocalizedStringKey("excel_result_draw") }
        return homeScore > awayScore ? LocalizedStringKey("elo_outcome_win") : LocalizedStringKey("elo_outcome_loss")
    }

    private var resultColor: Color {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        if homeScore == awayScore { return .secondary }
        return homeScore > awayScore ? EditorialDesign.orange : EditorialDesign.blue
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
        ZStack(alignment: .bottomTrailing) {
            Button {
                isShowingDetail = true
            } label: {
                HistoryView.SavedGameRow(game: game)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.isPro {
                Button {
                    store.toggleCloudStorage(for: game.id)
                } label: {
                    Image(systemName: store.cloudEnabledGameIDs.contains(game.id) ? "icloud.fill" : "icloud.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.cloudEnabledGameIDs.contains(game.id) ? EditorialDesign.blue : EditorialDesign.orange)
                        .frame(width: 34, height: 34)
                        .background(
                            store.cloudEnabledGameIDs.contains(game.id) ? EditorialDesign.paleBlue : EditorialDesign.paleOrange,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey("label_cloud"))
                .padding(.trailing, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
                    store.savedGames[idx].isLocked.toggle()
                    store.markSavedGameModified(game.id)
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
        .navigationDestination(isPresented: $isShowingDetail) {
            SavedGameDetailView(game: game)
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
