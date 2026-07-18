import SwiftUI

struct PlayerManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingPlayer: Player?
    @State private var editingPlayer: Player?
    @State private var selectedPlayerGroupID: UUID?
    @State private var searchText = ""

    private var filteredPlayers: [Player] {
        let nonTutorial = store.players.filter { !AppStore.tutorialPlayerIDs.contains($0.id) }
        let grouped: [Player]
        if store.isPro, let groupID = selectedPlayerGroupID {
            grouped = nonTutorial.filter { $0.playerGroupIDs.contains(groupID) }
        } else {
            grouped = nonTutorial
        }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return grouped }
        let query = searchText.lowercased()
        return grouped.filter { player in
            player.name.lowercased().contains(query) ||
            player.nicknames.contains { $0.lowercased().contains(query) } ||
            player.number.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            if filteredPlayers.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_players"), systemImage: "person.crop.circle.badge.plus")
            }

            ForEach(filteredPlayers) { player in
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
