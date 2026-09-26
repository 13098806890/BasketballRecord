import PhotosUI
import SwiftUI

struct TeamEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let team: Team?

    @State private var name: String
    @State private var selectedPlayerIDs: Set<UUID>
    @State private var selectedPlayerGroupID: UUID?
    @State private var iconData: Data?
    @State private var selectedIcon: PhotosPickerItem?

    init(team: Team?) {
        self.team = team
        _name = State(initialValue: team?.name ?? "")
        _selectedPlayerIDs = State(initialValue: Set(team?.playerIDs ?? []))
        _iconData = State(initialValue: team?.iconData)
    }

    private var filteredPlayers: [Player] {
        guard store.isPro, let groupID = selectedPlayerGroupID else { return store.players }
        return store.players.filter { $0.playerGroupIDs.contains(groupID) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("label_team")) {
                    TextField(LocalizedStringKey("team_name_placeholder"), text: $name)
                }

                Section(LocalizedStringKey("label_team_icon")) {
                    HStack(spacing: 16) {
                        iconPreview
                        PhotosPicker(selection: $selectedIcon, matching: .images) {
                            Label(LocalizedStringKey("label_select_team_icon"), systemImage: "photo.badge.plus")
                        }
                    }

                    if iconData != nil {
                        Button(role: .destructive) {
                            iconData = nil
                            selectedIcon = nil
                        } label: {
                            Label(LocalizedStringKey("label_remove_team_icon"), systemImage: "trash")
                        }
                    }
                }

                Section(LocalizedStringKey("team_select_players")) {
                    if store.players.isEmpty {
                        ContentUnavailableView(LocalizedStringKey("team_no_players_hint"), systemImage: "person.crop.circle.badge.plus")
                    }

                    ForEach(filteredPlayers) { player in
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
                if store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        PlayerGroupPicker(store: store, selectedGroupID: $selectedPlayerGroupID)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: selectedIcon) {
                guard let selectedIcon,
                      let data = try? await selectedIcon.loadTransferable(type: Data.self) else { return }
                iconData = compressedIconData(from: data)
            }
        }
    }

    private var iconPreview: some View {
        Group {
            if let iconData, let image = UIImage(data: iconData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.quaternary)
                    Image(systemName: "shield.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            playerIDs: orderedIDs,
            iconData: iconData
        )
        if team == nil {
            store.addTeam(next)
        } else {
            store.updateTeam(next)
        }
        dismiss()
    }

    private func compressedIconData(from data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }

        let maxDimension: CGFloat = 720
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.8) ?? data
        }

        let ratio = maxDimension / longestSide
        let targetSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }
}
