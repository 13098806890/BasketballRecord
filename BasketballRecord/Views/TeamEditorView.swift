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
    @State private var selectedBuiltinIconID: Int?
    @State private var isShowingDefaultIconPicker = false

    init(team: Team?) {
        self.team = team
        _name = State(initialValue: team?.name ?? "")
        _selectedPlayerIDs = State(initialValue: Set(team?.playerIDs ?? []))
        let existingIconData = Dota1SkillIconCatalog.isLegacyIconData(team?.iconData) ? nil : team?.iconData
        _iconData = State(initialValue: existingIconData)
        _selectedBuiltinIconID = State(initialValue: DefaultTeamIconCatalog.matchingID(for: existingIconData))
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
                        Menu {
                            PhotosPicker(selection: $selectedIcon, matching: .images) {
                                Label(LocalizedStringKey("label_select_photo"), systemImage: "photo")
                            }
                            Button {
                                isShowingDefaultIconPicker = true
                            } label: {
                                Label(LocalizedStringKey("label_select_default_team_icon"), systemImage: "basketball.fill")
                            }
                        } label: {
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
                selectedBuiltinIconID = nil
                iconData = compressedIconData(from: data)
            }
            .sheet(isPresented: $isShowingDefaultIconPicker) {
                NavigationStack {
                    ScrollView {
                        defaultIconGrid
                            .padding()
                    }
                    .navigationTitle(LocalizedStringKey("label_default_team_icons"))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(LocalizedStringKey("button_done")) {
                                isShowingDefaultIconPicker = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var defaultIconGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
            ForEach(DefaultTeamIconCatalog.items) { item in
                Button {
                    selectedIcon = nil
                    selectedBuiltinIconID = item.id
                    iconData = DefaultTeamIconCatalog.data(for: item)
                    isShowingDefaultIconPicker = false
                } label: {
                    builtinIconThumbnail(for: item)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel(LocalizedStringKey("label_default_team_icon"))
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
                TeamBadgeView(teamID: team?.id, fallbackName: name, size: 72)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func builtinIconThumbnail(for item: DefaultTeamIconCatalog.Item) -> some View {
        Group {
            if let image = DefaultTeamIconCatalog.image(for: item) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selectedBuiltinIconID == item.id ? EditorialDesign.orange : .clear, lineWidth: 3)
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
