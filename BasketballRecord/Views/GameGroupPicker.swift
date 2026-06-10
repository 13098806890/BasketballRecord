import SwiftUI

struct GameGroupPicker: View {
    @ObservedObject var store: AppStore
    @Binding var selectedGroupID: UUID?
    var iconName: String? = nil
    var checkedGroupIDs: Set<UUID>? = nil

    var body: some View {
        Menu {
            Button(action: { selectedGroupID = nil }) {
                HStack {
                    if selectedGroupID == nil {
                        Image(systemName: "checkmark")
                    }
                    Text(NSLocalizedString("game_group_all_games", comment: "All Games"))
                }
            }

            if !store.gameGroups.isEmpty {
                Divider()

                ForEach(store.gameGroups, id: \.id) { group in
                    Button(action: { selectedGroupID = group.id }) {
                        HStack {
                            if selectedGroupID == group.id || checkedGroupIDs?.contains(group.id) == true {
                                Image(systemName: "checkmark")
                            }
                            Text(group.name)
                        }
                    }
                }
            }
        } label: {
            Label(
                selectedGroupID.flatMap { id in store.gameGroups.first(where: { $0.id == id })?.name }
                    ?? NSLocalizedString("game_group_select_prompt", comment: "Select a group"),
                systemImage: iconName ?? (selectedGroupID != nil ? "folder.fill" : "folder")
            )
        }
    }
}

struct GameGroupBadge: View {
    let groupName: String?

    var body: some View {
        if let name = groupName {
            Label(
                String(format: NSLocalizedString("game_group_assigned_to", comment: "Group: %@"), name),
                systemImage: "folder.fill"
            )
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(4)
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var selectedGroupID: UUID?
        let store: AppStore

        init() {
            let store = AppStore()
            _ = store.addGameGroup("Spring League")
            _ = store.addGameGroup("Fall League")
            self.store = store
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)

                GameGroupBadge(groupName: selectedGroupID.flatMap { id in
                    store.groups(for: .init()).first.map { $0.name }
                })

                Spacer()
            }
            .padding()
        }
    }

    return PreviewContainer()
}
