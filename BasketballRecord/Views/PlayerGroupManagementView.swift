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
                    ContentUnavailableView(LocalizedStringKey("player_group_no_groups"), systemImage: "person.2.badge.plus")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(store.playerGroups, id: \.id) { group in
                        NavigationLink {
                            PlayerGroupEditView(store: store, group: group)
                        } label: {
                            PlayerGroupRowView(group: group, playerCount: store.players.filter { $0.playerGroupIDs.contains(group.id) }.count)
                                .contentShape(Rectangle())
                        }
                        .listRowBackground(EditorialDesign.card)
                        .listRowSeparator(.hidden)
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
            .editorialListStyle()
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
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EditorialDesign.orange)
                .frame(width: 34, height: 34)
                .background(EditorialDesign.paleOrange, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(group.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(EditorialDesign.navy)

            Spacer(minLength: 8)

            Text(String(format: NSLocalizedString("player_group_player_count", comment: "%d players"), playerCount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(EditorialDesign.blue)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(EditorialDesign.paleBlue, in: Capsule())
        }
        .padding(.vertical, 5)
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
        List {
            Section {
                TextField(NSLocalizedString("player_group_name_placeholder", comment: "Group name"), text: $name)
            }
            .listRowBackground(EditorialDesign.card)

            if group != nil {
                Section(NSLocalizedString("player_group_section_players", comment: "Players")) {
                    if store.players.isEmpty {
                        Text(NSLocalizedString("player_group_no_players_available", comment: "No players available"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.players) { player in
                            Button {
                                if selectedPlayerIDs.contains(player.id) {
                                    selectedPlayerIDs.remove(player.id)
                                } else {
                                    selectedPlayerIDs.insert(player.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    PlayerAvatarView(player: player, size: 40)
                                    Text(player.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(EditorialDesign.navy)
                                    Spacer(minLength: 8)
                                    Image(systemName: selectedPlayerIDs.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedPlayerIDs.contains(player.id) ? EditorialDesign.blue : EditorialDesign.divider)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(EditorialDesign.card)
            }
        }
        .editorialListStyle()
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
