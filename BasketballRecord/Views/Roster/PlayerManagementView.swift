import SwiftUI

struct PlayerManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingPlayer: Player?
    @State private var editingPlayer: Player?
    @State private var selectedPlayerGroupID: UUID?
    @State private var searchText = ""
    @State private var displayedPlayers: [Player] = []
    @State private var searchTask: Task<Void, Never>?

    private var basePlayers: [Player] {
        let nonTutorial = store.players.filter { !AppStore.tutorialPlayerIDs.contains($0.id) }
        if store.isPro, let groupID = selectedPlayerGroupID {
            return nonTutorial.filter { $0.playerGroupIDs.contains(groupID) }
        }
        return nonTutorial
    }

    private func filterPlayers(_ query: String, from all: [Player]) -> [Player] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        let q = query.lowercased()
        return all.filter { player in
            player.name.lowercased().contains(q) ||
            player.nicknames.contains { $0.lowercased().contains(q) } ||
            player.number.lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            if displayedPlayers.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_players"), systemImage: "person.crop.circle.badge.plus")
            }

            ForEach(displayedPlayers) { player in
                HStack(spacing: 12) {
                    PlayerAvatarView(player: player, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name)
                            .font(.headline)
                        Text(rosterPlayerSubtitle(player))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        editingPlayer = player
                    } label: {
                        RosterActionIcon(symbol: "pencil")
                    }
                    .buttonStyle(.plain)
                    Button {
                        exportingPlayer = player
                    } label: {
                        RosterActionIcon(symbol: TransferSymbol.exportData)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: store.deletePlayers)
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: LocalizedStringKey("search_players"))
        .onChange(of: searchText) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                if !Task.isCancelled {
                    let all = basePlayers
                    displayedPlayers = filterPlayers(searchText, from: all)
                }
            }
        }
        .onChange(of: selectedPlayerGroupID) { _, _ in
            displayedPlayers = filterPlayers(searchText, from: basePlayers)
        }
        .onAppear {
            displayedPlayers = basePlayers
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .navigationTitle(LocalizedStringKey("settings_players"))
        .toolbar {
            if store.isPro {
                ToolbarItem(placement: .topBarTrailing) {
                    PlayerGroupPicker(store: store, selectedGroupID: $selectedPlayerGroupID)
                }
            }
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditorView(player: player)
        }
        .sheet(item: $exportingPlayer) { player in
            ExportPlayerPackageView(player: player)
        }
    }
}
