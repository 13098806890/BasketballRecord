import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var selectedGroupID: UUID?
    @State private var isShowingImport = false
    @State private var isShowingDelete = false
    @State private var displayedGames: [SavedGame] = []
    @State private var isLoadingGames = true
    @State private var loadTask: Task<Void, Never>?
    @State private var pendingSwipeDeleteGame: SavedGame?

    var body: some View {
        NavigationStack {
            List {
                if let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
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
                    DisclosureGroup {
                        ForEach(group.games) { game in
                            NavigationLink {
                                SavedGameDetailView(game: game)
                            } label: {
                                SavedGameRow(game: game)
                            }
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
                        }
                    } label: {
                        Text(group.title)
                            .font(.headline)
                    }
                }
        }
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
        .sheet(isPresented: $isShowingDelete) {
            DeleteSavedGamesView()
        }
        .sheet(isPresented: $isShowingImport) {
            ImportGameView()
        }
        .onAppear {
            selectedGroupID = FilterDefaults.load(FilterDefaults.historyKey)
            loadGamesAsync(showLoading: displayedGames.isEmpty)
        }
        .onChange(of: store.savedGames) { _, _ in
            loadGamesAsync(showLoading: false)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            FilterDefaults.save(FilterDefaults.historyKey, newValue)
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
    }

    private var filteredGames: [SavedGame] {
        var games = displayedGames

        // Filter by group if selected
        if let selectedGroupID = selectedGroupID {
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

                                Text(Self.dateFormatter.string(from: game.savedAt))
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

private struct GameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: GameMonthKey, rhs: GameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

private struct GameMonthGroup: Identifiable {
    var key: GameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { String(format: NSLocalizedString("month_title_format", comment: "Month title"), key.year, key.month) }
}

private struct SavedGameRow: View {
    @EnvironmentObject private var store: AppStore
    var game: SavedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(scoreLine)
                    .font(.headline.monospacedDigit())
            }

            HStack {
                if game.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(Self.dateFormatter.string(from: game.savedAt))
                Spacer()
                if store.cloudEnabledGameIDs.contains(game.id) {
                    Image(systemName: "icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

