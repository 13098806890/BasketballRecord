import SwiftUI

struct GameGroupManagementView: View {
    @ObservedObject var store: AppStore
    @State private var showingAddGroup = false
    @State private var groupToDelete: GameGroup?
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if store.gameGroups.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(NSLocalizedString("game_group_no_groups", comment: "No groups yet"))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(store.gameGroups, id: \.id) { group in
                        NavigationLink {
                            GameGroupEditView(store: store, group: group)
                        } label: {
                            GameGroupRowView(group: group, gameCount: store.gamesInGroup(group.id).count)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                groupToDelete = group
                                showingDeleteConfirm = true
                            } label: {
                                Label(NSLocalizedString("game_group_delete_button", comment: "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("game_group_nav_title", comment: "Game Groups"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddGroup = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            NavigationStack {
                GameGroupEditView(store: store, group: nil)
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            NSLocalizedString("game_group_delete_confirm_title", comment: "Delete group?"),
            isPresented: $showingDeleteConfirm,
            presenting: groupToDelete,
            actions: { group in
                Button(role: .destructive) {
                    store.deleteGameGroup(group.id)
                } label: {
                    Text(NSLocalizedString("game_group_delete_button", comment: "Delete"))
                }
            },
            message: { _ in
                Text(NSLocalizedString("game_group_delete_confirm_message", comment: "This will not delete the games, only the group."))
            }
        )
    }
}

struct GameGroupRowView: View {
    let group: GameGroup
    let gameCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)

                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller")
                        .font(.caption)
                    Text(String(format: NSLocalizedString("game_group_games_count", comment: "%d games"), gameCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct GameGroupEditView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let group: GameGroup?

    @State private var name = ""
    @State private var description = ""
    @State private var selectedGameIDs: Set<UUID> = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var allGames: [SavedGame] {
        store.savedGames.sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        Form {
            Section {
                TextField(NSLocalizedString("game_group_name_placeholder", comment: "Group name"), text: $name)

                TextField(NSLocalizedString("game_group_description_placeholder", comment: "Description"), text: $description)
            }

            if group != nil {
                Section(NSLocalizedString("game_group_games_section", comment: "Games")) {
                    if allGames.isEmpty {
                        Text(NSLocalizedString("game_group_no_games_available", comment: "No games available"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allGames, id: \.id) { game in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.displayTitle)
                                        .font(.subheadline)
                                    HStack(spacing: 6) {
                                        Text(dateFormatter.string(from: game.savedAt))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(scoreLine(for: game))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: selectedGameIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedGameIDs.contains(game.id) ? .blue : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedGameIDs.contains(game.id) {
                                    selectedGameIDs.remove(game.id)
                                } else {
                                    selectedGameIDs.insert(game.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(group == nil ? NSLocalizedString("game_group_add_button", comment: "New Group") : NSLocalizedString("game_group_edit_button", comment: "Edit Group"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(NSLocalizedString("common_cancel", comment: "Cancel")) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(NSLocalizedString("common_save", comment: "Save")) {
                    saveGroup()
                }
                .disabled(!isValid)
            }
        }
        .onAppear {
            if let group = group {
                name = group.name
                description = group.description ?? ""
                selectedGameIDs = Set(group.gameIDs)
            }
        }
    }

    private func saveGroup() {
        if let group = group {
            var updatedGroup = group
            updatedGroup.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedGroup.description = description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedGroup.gameIDs = Array(selectedGameIDs)
            store.syncGameGroupMembership(groupID: group.id, gameIDs: Array(selectedGameIDs))
            store.updateGameGroup(updatedGroup)
        } else {
            let newGroup = store.addGameGroup(name.trimmingCharacters(in: .whitespacesAndNewlines), description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines))
            store.syncGameGroupMembership(groupID: newGroup.id, gameIDs: Array(selectedGameIDs))
        }
        dismiss()
    }

    private func scoreLine(for game: SavedGame) -> String {
        let homeScore = game.homePlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
        let awayScore = game.awayPlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
        return "\(homeScore) - \(awayScore)"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

#Preview {
    let store = AppStore()
    _ = store.addGameGroup("Spring League", description: "Games from spring season")
    _ = store.addGameGroup("Fall League")

    return GameGroupManagementView(store: store)
}
