import SwiftUI

struct PlayerGroupPicker: View {
    @ObservedObject var store: AppStore
    @Binding var selectedGroupID: UUID?
    var iconName: String? = nil

    var body: some View {
        Menu {
            Button(action: { selectedGroupID = nil }) {
                HStack {
                    if selectedGroupID == nil {
                        Image(systemName: "checkmark")
                    }
                    Text(NSLocalizedString("player_group_all_players", comment: "All Players"))
                }
            }

            if !store.playerGroups.isEmpty {
                Divider()

                ForEach(store.playerGroups, id: \.id) { group in
                    Button(action: { selectedGroupID = group.id }) {
                        HStack {
                            if selectedGroupID == group.id {
                                Image(systemName: "checkmark")
                            }
                            Text(group.name)
                        }
                    }
                }
            }
        } label: {
            Label(
                selectedGroupID.flatMap { id in store.playerGroups.first(where: { $0.id == id })?.name }
                    ?? NSLocalizedString("player_group_all_players", comment: "All Players"),
                systemImage: iconName ?? (selectedGroupID != nil ? "person.2.fill" : "person.2")
            )
        }
    }
}
