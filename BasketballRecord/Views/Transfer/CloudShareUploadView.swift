import SwiftUI

private let recordsKey = "cloud_share_upload_records"

struct CloudShareUploadView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var includePlayers = true
    @State private var includeTeams = true
    @State private var includeSavedGames = true
    @State private var selectedPlayerIDs: Set<UUID> = []
    @State private var selectedTeamIDs: Set<UUID> = []
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var records: [CloudShareRecord] = []
    @State private var matchingRecord: CloudShareRecord?
    @State private var remainingSeconds: Int = 0
    @State private var isChecking = true
    @State private var isUploading = false
    @State private var uploadedUUID: String?
    @State private var cloudError: String?

    private var sortedPlayers: [Player] {
        store.players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var sortedTeams: [Team] {
        store.teams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var sortedSavedGames: [SavedGame] {
        store.savedGames.sorted { $0.savedAt > $1.savedAt }
    }

    private var currentSelection: (playerIDs: [UUID], teamIDs: [UUID], gameIDs: [UUID]) {
        (Array(selectedPlayerIDs).sorted { $0.uuidString < $1.uuidString },
         Array(selectedTeamIDs).sorted { $0.uuidString < $1.uuidString },
         Array(selectedGameIDs).sorted { $0.uuidString < $1.uuidString })
    }

    private var hasSelectedData: Bool {
        !selectedPlayerIDs.isEmpty || !selectedTeamIDs.isEmpty || !selectedGameIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if isChecking {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(LocalizedStringKey("cloudshare_uploading"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if let record = matchingRecord {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.green)

                            Text(LocalizedStringKey("cloudshare_uuid_title"))
                                .font(.headline)

                            Text(record.uuid)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            if remainingSeconds > 0 {
                                Text(String(format: NSLocalizedString("cloudshare_expires_format", comment: ""), formatRemainingTime(remainingSeconds)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                UIPasteboard.general.string = record.uuid
                                Task {
                                    try? await Task.sleep(for: .seconds(1.2))
                                }
                            } label: {
                                Label(NSLocalizedString("cloudshare_copy_button", comment: ""), systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AppSoftProminentButtonStyle())
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text(LocalizedStringKey("cloudshare_picker_cloud_label"))
                    }
                } else {
                    uploadFormContent
                }
            }
            .navigationTitle(LocalizedStringKey("cloudshare_upload_button"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if matchingRecord != nil || uploadedUUID != nil {
                        Button(LocalizedStringKey("button_done")) { dismiss() }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if matchingRecord == nil && uploadedUUID == nil {
                        Button(LocalizedStringKey("button_cancel")) { dismiss() }
                    }
                }
            }
        }
        .task {
            await loadAndVerifyRecords()
        }
        .onChange(of: selectedPlayerIDs) { _, _ in tryMatchSelection() }
        .onChange(of: selectedTeamIDs) { _, _ in tryMatchSelection() }
        .onChange(of: selectedGameIDs) { _, _ in tryMatchSelection() }

    }

    @ViewBuilder
    private var uploadFormContent: some View {
        if let uuid = uploadedUUID {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)

                    Text(LocalizedStringKey("cloudshare_uuid_title"))
                        .font(.headline)

                    Text(uuid)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        UIPasteboard.general.string = uuid
                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                        }
                    } label: {
                        Label(NSLocalizedString("cloudshare_copy_button", comment: ""), systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSoftProminentButtonStyle())
                }
                .padding(.vertical, 8)
            } header: {
                Text(LocalizedStringKey("cloudshare_picker_cloud_label"))
            }
        } else if let error = cloudError {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red)

                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        cloudError = nil
                    } label: {
                        Text(LocalizedStringKey("button_retry"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppSoftProminentButtonStyle())
                }
                .padding(.vertical, 8)
            }
        }

        Section {
            DisclosureGroup(isExpanded: $includePlayers) {
                selectionActionBar(
                    selectedCount: selectedPlayerIDs.count,
                    totalCount: sortedPlayers.count,
                    onSelectAll: { selectedPlayerIDs = Set(sortedPlayers.map(\.id)) },
                    onClear: { selectedPlayerIDs.removeAll() }
                )

                if sortedPlayers.isEmpty {
                    Text(LocalizedStringKey("no_player_data"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlayers) { player in
                        Button {
                            toggleSelection(&selectedPlayerIDs, id: player.id)
                        } label: {
                            HStack {
                                Image(systemName: selectedPlayerIDs.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedPlayerIDs.contains(player.id) ? .blue : .secondary)

                                PlayerAvatarView(player: player, size: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .foregroundStyle(.primary)
                                    if !player.number.isEmpty {
                                        Text(String(format: NSLocalizedString("player_number_prefix", comment: ""), player.number))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } label: {
                HStack {
                    Text(NSLocalizedString("section_players", comment: ""))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(selectedPlayerIDs.count)/\(store.players.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            DisclosureGroup(isExpanded: $includeTeams) {
                selectionActionBar(
                    selectedCount: selectedTeamIDs.count,
                    totalCount: sortedTeams.count,
                    onSelectAll: { selectedTeamIDs = Set(sortedTeams.map(\.id)) },
                    onClear: { selectedTeamIDs.removeAll() }
                )

                if sortedTeams.isEmpty {
                    Text(LocalizedStringKey("no_team_data"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedTeams) { team in
                        selectableRow(
                            title: team.name,
                            subtitle: String(format: NSLocalizedString("team_player_count", comment: ""), team.playerIDs.count),
                            isSelected: selectedTeamIDs.contains(team.id)
                        ) {
                            toggleSelection(&selectedTeamIDs, id: team.id)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(NSLocalizedString("section_teams", comment: ""))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(selectedTeamIDs.count)/\(store.teams.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            DisclosureGroup(isExpanded: $includeSavedGames) {
                selectionActionBar(
                    selectedCount: selectedGameIDs.count,
                    totalCount: sortedSavedGames.count,
                    onSelectAll: { selectedGameIDs = Set(sortedSavedGames.map(\.id)) },
                    onClear: { selectedGameIDs.removeAll() }
                )

                if sortedSavedGames.isEmpty {
                    Text(LocalizedStringKey("no_savedgames_data"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedSavedGames) { game in
                        let gameTitle = game.displayName.isEmpty
                            ? String(format: NSLocalizedString("game_vs_format", comment: ""), game.homeTeamName, game.awayTeamName)
                            : game.displayName
                        let gameSub = game.displayName.isEmpty
                            ? formattedDate(game.savedAt)
                            : "\(String(format: NSLocalizedString("game_vs_format", comment: ""), game.homeTeamName, game.awayTeamName)) · \(formattedDate(game.savedAt))"
                        selectableRow(
                            title: gameTitle,
                            subtitle: gameSub,
                            isSelected: selectedGameIDs.contains(game.id)
                        ) {
                            toggleSelection(&selectedGameIDs, id: game.id)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(NSLocalizedString("section_saved_games", comment: ""))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(selectedGameIDs.count)/\(store.savedGames.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Button {
                Task { await upload() }
            } label: {
                ZStack {
                    if isUploading {
                        ProgressView()
                    } else {
                        Text(hasSelectedData ? NSLocalizedString("cloudshare_upload_button", comment: "") : NSLocalizedString("cloudshare_error_empty_data", comment: ""))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppNeutralProminentButtonStyle())
            .disabled(!hasSelectedData || isUploading)
        }
    }

    private func loadAndVerifyRecords() async {
        isChecking = true
        defer { isChecking = false }

        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([CloudShareRecord].self, from: data) {
            var valid: [CloudShareRecord] = []
            for record in decoded {
                do {
                    let (exists, _) = try await CloudShareManager.check(uuid: record.uuid)
                    if exists {
                        valid.append(record)
                    }
                } catch {
                    valid.append(record)
                }
            }
            records = valid
            saveRecords(valid)
        }

        tryMatchSelection()
    }

    private func tryMatchSelection() {
        let sel = currentSelection
        let selPlayers = Set(sel.playerIDs)
        let selTeams = Set(sel.teamIDs)
        let selGames = Set(sel.gameIDs)

        for record in records {
            if Set(record.playerIDs) == selPlayers &&
               Set(record.teamIDs) == selTeams &&
               Set(record.gameIDs) == selGames {
                matchingRecord = record
                return
            }
        }
        matchingRecord = nil
    }

    private func upload() async {
        isUploading = true
        cloudError = nil
        do {
            let players = sortedPlayers.filter { selectedPlayerIDs.contains($0.id) }.map(ExportPlayer.init)
            let teams = sortedTeams.filter { selectedTeamIDs.contains($0.id) }.map { ExportTeam(team: $0) }
            let games = sortedSavedGames.filter { selectedGameIDs.contains($0.id) }.map { game in
                ExportedGamePackageV2(legacy: ExportedGamePackage(
                    players: exportPlayers(for: game),
                    teams: exportTeams(for: game),
                    game: ExportGameRecord(savedGame: game)
                ))
            }
            let bundle = CloudShareBundle(players: players, teams: teams, games: games)
            let uuid = try await CloudShareManager.uploadBundle(bundle)

            let record = CloudShareRecord(
                uuid: uuid,
                playerIDs: Array(selectedPlayerIDs),
                teamIDs: Array(selectedTeamIDs),
                gameIDs: Array(selectedGameIDs)
            )
            records.append(record)
            saveRecords(records)
            uploadedUUID = uuid
        } catch {
            cloudError = error.localizedDescription
        }
        isUploading = false
    }

    private func saveRecords(_ records: [CloudShareRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
    }

    private func exportPlayers(for game: SavedGame) -> [ExportPlayer] {
        let allIDs = Set(game.homePlayerIDs + game.awayPlayerIDs + game.snapshot.statsByPlayerID.keys)
        return allIDs.compactMap { id in
            if let player = store.players.first(where: { $0.id == id }) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: id, name: game.playerNamesByID[id] ?? "Unknown")
        }
    }

    private func exportTeams(for game: SavedGame) -> [ExportTeam] {
        var teams: [ExportTeam] = []
        if let tid = game.snapshot.homeTeamID {
            teams.append(ExportTeam(id: tid, name: game.homeTeamName, playerIDs: game.homePlayerIDs))
        } else {
            teams.append(ExportTeam(id: UUID(), name: game.homeTeamName, playerIDs: game.homePlayerIDs))
        }
        if let tid = game.snapshot.awayTeamID {
            teams.append(ExportTeam(id: tid, name: game.awayTeamName, playerIDs: game.awayPlayerIDs))
        } else {
            teams.append(ExportTeam(id: UUID(), name: game.awayTeamName, playerIDs: game.awayPlayerIDs))
        }
        return teams
    }

    private func toggleSelection(_ set: inout Set<UUID>, id: UUID) {
        if set.contains(id) { set.remove(id) }
        else { set.insert(id) }
    }

    private func selectionActionBar(selectedCount: Int, totalCount: Int, onSelectAll: @escaping () -> Void, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(NSLocalizedString("button_select_all", comment: "")) {
                onSelectAll()
            }
            .font(.caption)
            .buttonStyle(.bordered)

            Button(NSLocalizedString("button_clear", comment: "")) {
                onClear()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .disabled(selectedCount == 0)
        }
        .padding(.vertical, 4)
    }

    private func selectableRow(title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private func formatRemainingTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
