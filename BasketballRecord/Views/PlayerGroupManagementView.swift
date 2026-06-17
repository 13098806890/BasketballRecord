import SwiftUI

struct PlayerGroupManagementView: View {
    @ObservedObject var store: AppStore
    @State private var showingAddGroup = false
    @State private var groupToDelete: PlayerGroup?
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if store.playerGroups.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(NSLocalizedString("player_group_no_groups", comment: "No groups yet"))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(store.playerGroups, id: \.id) { group in
                        NavigationLink {
                            PlayerGroupEditView(store: store, group: group)
                        } label: {
                            PlayerGroupRowView(group: group, playerCount: store.players.filter { $0.playerGroupIDs.contains(group.id) }.count)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                groupToDelete = group
                                showingDeleteConfirm = true
                            } label: {
                                Label(NSLocalizedString("player_group_delete_button", comment: "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("player_group_nav_title", comment: "Player Groups"))
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
                PlayerGroupEditView(store: store, group: nil)
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            NSLocalizedString("player_group_delete_confirm_title", comment: "Delete group?"),
            isPresented: $showingDeleteConfirm,
            presenting: groupToDelete,
            actions: { group in
                Button(role: .destructive) {
                    store.deletePlayerGroup(group.id)
                } label: {
                    Text(NSLocalizedString("player_group_delete_button", comment: "Delete"))
                }
            },
            message: { _ in
                Text(NSLocalizedString("player_group_delete_confirm_message", comment: "This will not delete the players, only the group."))
            }
        )
    }
}

struct PlayerGroupRowView: View {
    let group: PlayerGroup
    let playerCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.headline)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "person.2")
                    .font(.caption)
                Text(String(format: NSLocalizedString("player_group_player_count", comment: "%d players"), playerCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlayerGroupEditView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    let group: PlayerGroup?

    @State private var name = ""
    @State private var selectedPlayerIDs: Set<UUID> = []

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField(NSLocalizedString("player_group_name_placeholder", comment: "Group name"), text: $name)
            }

            if group != nil {
                Section(NSLocalizedString("player_group_section_players", comment: "Players")) {
                    if store.players.isEmpty {
                        Text(NSLocalizedString("player_group_no_players_available", comment: "No players available"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.players) { player in
                            HStack {
                                PlayerAvatarView(player: player, size: 36)
                                Text(player.name)
                                Spacer()
                                Image(systemName: selectedPlayerIDs.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedPlayerIDs.contains(player.id) ? .blue : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedPlayerIDs.contains(player.id) {
                                    selectedPlayerIDs.remove(player.id)
                                } else {
                                    selectedPlayerIDs.insert(player.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(group == nil ? NSLocalizedString("player_group_add_button", comment: "New Player Group") : NSLocalizedString("player_group_edit_button", comment: "Edit Player Group"))
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
                selectedPlayerIDs = Set(store.players.filter { $0.playerGroupIDs.contains(group.id) }.map(\.id))
            }
        }
    }

    private func saveGroup() {
        if let group = group {
            store.syncPlayerGroupMembership(groupID: group.id, playerIDs: Array(selectedPlayerIDs))
            var updatedGroup = group
            updatedGroup.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedGroup.playerIDs = Array(selectedPlayerIDs)
            store.updatePlayerGroup(updatedGroup)
        } else {
            let newGroup = store.addPlayerGroup(name.trimmingCharacters(in: .whitespacesAndNewlines))
            store.syncPlayerGroupMembership(groupID: newGroup.id, playerIDs: Array(selectedPlayerIDs))
        }
        dismiss()
    }
}

#Preview {
    let store = AppStore()
    return PlayerGroupManagementView(store: store)
}
