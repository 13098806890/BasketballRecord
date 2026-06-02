import SwiftUI

struct TeamEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let team: Team?

    @State private var name: String
    @State private var selectedPlayerIDs: Set<UUID>

    init(team: Team?) {
        self.team = team
        _name = State(initialValue: team?.name ?? "")
        _selectedPlayerIDs = State(initialValue: Set(team?.playerIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("label_team")) {
                    TextField(LocalizedStringKey("team_name_placeholder"), text: $name)
                }

                Section(LocalizedStringKey("team_select_players")) {
                    if store.players.isEmpty {
                        ContentUnavailableView(LocalizedStringKey("team_no_players_hint"), systemImage: "person.crop.circle.badge.plus")
                    }

                    ForEach(store.players) { player in
                        Button {
                            toggle(player.id)
                        } label: {
                            HStack {
                                PlayerAvatarView(player: player, size: 36)
                                Text(player.name)
                                Spacer()
                                if selectedPlayerIDs.contains(player.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey(team == nil ? "nav_new_team" : "nav_edit_team"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedPlayerIDs.contains(id) {
            selectedPlayerIDs.remove(id)
        } else {
            selectedPlayerIDs.insert(id)
        }
    }

    private func save() {
        let orderedIDs = store.players.map(\.id).filter { selectedPlayerIDs.contains($0) }
        let next = Team(
            id: team?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            playerIDs: orderedIDs
        )
        if team == nil {
            store.addTeam(next)
        } else {
            store.updateTeam(next)
        }
        dismiss()
    }
}
