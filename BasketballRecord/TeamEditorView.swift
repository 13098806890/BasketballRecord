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
                Section("球队") {
                    TextField("球队名称", text: $name)
                }

                Section("选择球员") {
                    if store.players.isEmpty {
                        ContentUnavailableView("先添加球员", systemImage: "person.crop.circle.badge.plus")
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
            .navigationTitle(team == nil ? "新建球队" : "编辑球队")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
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
