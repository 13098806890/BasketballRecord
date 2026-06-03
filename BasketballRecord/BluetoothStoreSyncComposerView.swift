import SwiftUI
import MultipeerConnectivity

enum BluetoothStoreSyncComposerPreset: Equatable {
    case all
    case player(UUID)
    case team(UUID)
    case game(UUID)
}

struct BluetoothStoreSyncComposerView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager

    private let preset: BluetoothStoreSyncComposerPreset

    @State private var includePlayers = true
    @State private var includeTeams = true
    @State private var includeSavedGames = true
    @State private var selectedPeerIndex = 0
    @State private var selectedPlayerIDs: Set<UUID> = []
    @State private var selectedTeamIDs: Set<UUID> = []
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var alertMessage: String?
    @State private var didApplyPreset = false
    @AppStorage("bluetooth_include_photos") private var includePhotos = true

    init(preset: BluetoothStoreSyncComposerPreset = .all) {
        self.preset = preset

        switch preset {
        case .all:
            _includePlayers = State(initialValue: true)
            _includeTeams = State(initialValue: true)
            _includeSavedGames = State(initialValue: true)

        case .player:
            _includePlayers = State(initialValue: true)
            _includeTeams = State(initialValue: false)
            _includeSavedGames = State(initialValue: false)

        case .team:
            _includePlayers = State(initialValue: false)
            _includeTeams = State(initialValue: true)
            _includeSavedGames = State(initialValue: false)

        case .game:
            _includePlayers = State(initialValue: false)
            _includeTeams = State(initialValue: false)
            _includeSavedGames = State(initialValue: true)
        }
    }

    private var connectedPeers: [MCPeerID] {
        bluetooth.connectedPeers
    }

    private var sortedPlayers: [Player] {
        store.players.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var sortedTeams: [Team] {
        store.teams.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var sortedSavedGames: [SavedGame] {
        store.savedGames.sorted { $0.savedAt > $1.savedAt }
    }

    private var filteredPlayers: [Player] {
        guard includePlayers else { return [] }
        return sortedPlayers.filter { selectedPlayerIDs.contains($0.id) }
    }

    private var filteredTeams: [Team] {
        guard includeTeams else { return [] }
        return sortedTeams.filter { selectedTeamIDs.contains($0.id) }
    }

    private var filteredSavedGames: [SavedGame] {
        guard includeSavedGames else { return [] }
        return sortedSavedGames.filter { selectedGameIDs.contains($0.id) }
    }

    private var teamLinkedPlayers: [Player] {
        guard includeTeams else { return [] }
        let selectedTeams = sortedTeams.filter { selectedTeamIDs.contains($0.id) }
        let linkedIDs = Set(selectedTeams.flatMap(\.playerIDs))
        guard !linkedIDs.isEmpty else { return [] }
        return sortedPlayers.filter { linkedIDs.contains($0.id) }
    }

    private var hasSelectedData: Bool {
        !filteredPlayers.isEmpty || !filteredTeams.isEmpty || !filteredSavedGames.isEmpty
    }

    var body: some View {
        Form {
            Section(LocalizedStringKey("section_receiving_devices")) {
                if connectedPeers.isEmpty {
                    Text(LocalizedStringKey("no_connected_devices"))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(LocalizedStringKey("picker_send_to"), selection: $selectedPeerIndex) {
                        ForEach(Array(connectedPeers.enumerated()), id: \.offset) { index, peer in
                            Text(peer.displayName).tag(index)
                        }
                    }
                }
            }

            Section(LocalizedStringKey("section_players")) {
                Toggle(isOn: $includePlayers) {
                    Text(String(format: NSLocalizedString("toggle_send_players_count", comment: "Send players with count"), store.players.count))
                }

                if includePlayers {
                    selectionActionBar(
                        selectedCount: selectedPlayerIDs.count,
                        totalCount: sortedPlayers.count,
                        onSelectAll: {
                            selectedPlayerIDs = Set(sortedPlayers.map(\.id))
                        },
                        onClear: {
                            selectedPlayerIDs.removeAll()
                        }
                    )

                    if sortedPlayers.isEmpty {
                        Text(LocalizedStringKey("no_player_data"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedPlayers) { player in
                            selectableRow(
                                title: player.name,
                                subtitle: player.number.isEmpty ? nil : String(format: NSLocalizedString("player_number_prefix", comment: "Player number prefix"), player.number),
                                isSelected: selectedPlayerIDs.contains(player.id)
                            ) {
                                togglePlayerSelection(player.id)
                            }
                        }
                    }
                }
            }

            Section(LocalizedStringKey("section_teams")) {
                Toggle(isOn: $includeTeams) {
                    Text(String(format: NSLocalizedString("toggle_send_teams_count", comment: "Send teams with count"), store.teams.count))
                }

                if includeTeams {
                    selectionActionBar(
                        selectedCount: selectedTeamIDs.count,
                        totalCount: sortedTeams.count,
                        onSelectAll: {
                            selectedTeamIDs = Set(sortedTeams.map(\.id))
                        },
                        onClear: {
                            selectedTeamIDs.removeAll()
                        }
                    )

                    if sortedTeams.isEmpty {
                        Text(LocalizedStringKey("no_team_data"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTeams) { team in
                            selectableRow(
                                title: team.name,
                                subtitle: String(format: NSLocalizedString("team_player_count", comment: "Number of players in team"), team.playerIDs.count),
                                isSelected: selectedTeamIDs.contains(team.id)
                            ) {
                                toggleTeamSelection(team.id)
                            }
                        }
                    }
                }
            }

            Section(LocalizedStringKey("section_saved_games")) {
                Toggle(isOn: $includeSavedGames) {
                    Text(String(format: NSLocalizedString("toggle_send_savedgames_count", comment: "Send saved games with count"), store.savedGames.count))
                }

                if includeSavedGames {
                    selectionActionBar(
                        selectedCount: selectedGameIDs.count,
                        totalCount: sortedSavedGames.count,
                        onSelectAll: {
                            selectedGameIDs = Set(sortedSavedGames.map(\.id))
                        },
                        onClear: {
                            selectedGameIDs.removeAll()
                        }
                    )

                    if sortedSavedGames.isEmpty {
                        Text(LocalizedStringKey("no_savedgames_data"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedSavedGames) { game in
                            selectableRow(
                                title: String(format: NSLocalizedString("game_vs_format", comment: "Home vs Away"), game.homeTeamName, game.awayTeamName),
                                subtitle: gameSubtitle(for: game),
                                isSelected: selectedGameIDs.contains(game.id)
                            ) {
                                toggleGameSelection(game.id)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: $includePhotos) {
                    Label(LocalizedStringKey("label_include_photos_in_sync"), systemImage: "photo")
                }
            }

            Section {
                Button {
                    sendRequest()
                } label: {
                    Label(LocalizedStringKey("button_send_store_sync_request"), systemImage: "paperplane.fill")
                }
                .disabled(connectedPeers.isEmpty || bluetooth.isStoreSyncPreparing || bluetooth.isStoreSyncSending || !hasSelectedData)

                if bluetooth.isStoreSyncPreparing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(bluetooth.storeSyncPreparationMessage ?? NSLocalizedString("preparing_store_sync", comment: "Preparing store sync"))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if !hasSelectedData {
                    Text(LocalizedStringKey("must_select_at_least_one_item"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if bluetooth.isStoreSyncSending, bluetooth.outgoingStoreSyncProgress == nil {
                    Text(LocalizedStringKey("sync_request_sent_waiting_confirmation"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if bluetooth.isStoreSyncPreparing || bluetooth.isStoreSyncSending {
                    Button(role: .destructive) {
                        _ = bluetooth.cancelCurrentStoreSyncTask()
                    } label: {
                        Label(LocalizedStringKey("label_cancel_current_sync"), systemImage: "xmark.circle")
                    }
                }
            }

            if let outgoing = bluetooth.outgoingStoreSyncProgress {
                Section(LocalizedStringKey("section_send_progress")) {
                    ProgressView(value: outgoing.fractionCompleted)
                    Text("\(progressDetailText(outgoing))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let status = bluetooth.statusMessage, !status.isEmpty {
                Section(LocalizedStringKey("section_status")) {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("nav_select_sync_content"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if store.players.isEmpty { includePlayers = false }
            if store.teams.isEmpty { includeTeams = false }
            if store.savedGames.isEmpty { includeSavedGames = false }
            normalizeSelectedPeerIndex()
            applyPresetIfNeeded()
            initializeSelectionsIfNeeded()
        }
        .onChange(of: bluetooth.connectedPeers.count) { _, _ in
            normalizeSelectedPeerIndex()
        }
        .onChange(of: store.players) { _, players in
            selectedPlayerIDs = selectedPlayerIDs.intersection(Set(players.map(\.id)))
        }
        .onChange(of: store.teams) { _, teams in
            selectedTeamIDs = selectedTeamIDs.intersection(Set(teams.map(\.id)))
        }
        .onChange(of: store.savedGames) { _, games in
            selectedGameIDs = selectedGameIDs.intersection(Set(games.map(\.id)))
        }
        .alert(LocalizedStringKey("alert_notice_title"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(LocalizedStringKey("alert_ok")) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @ViewBuilder
    private func selectionActionBar(
        selectedCount: Int,
        totalCount: Int,
        onSelectAll: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(String(format: NSLocalizedString("text_selected_count", comment: "Selected count"), selectedCount, totalCount))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onSelectAll) {
                Text(LocalizedStringKey("button_select_all"))
            }
            .font(.footnote)

            Button(action: onClear) {
                Text(LocalizedStringKey("button_clear"))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func selectableRow(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    if let subtitle, !subtitle.isEmpty {
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

    private func normalizeSelectedPeerIndex() {
        guard !connectedPeers.isEmpty else {
            selectedPeerIndex = 0
            return
        }
        if !connectedPeers.indices.contains(selectedPeerIndex) {
            selectedPeerIndex = 0
        }
    }

    private func initializeSelectionsIfNeeded() {
        if selectedPlayerIDs.isEmpty, !sortedPlayers.isEmpty {
            selectedPlayerIDs = Set(sortedPlayers.map(\.id))
        }
        if selectedTeamIDs.isEmpty, !sortedTeams.isEmpty {
            selectedTeamIDs = Set(sortedTeams.map(\.id))
        }
        if selectedGameIDs.isEmpty, !sortedSavedGames.isEmpty {
            selectedGameIDs = Set(sortedSavedGames.map(\.id))
        }
    }

    private func applyPresetIfNeeded() {
        guard !didApplyPreset else { return }
        didApplyPreset = true

        switch preset {
        case .all:
            break
        case .player(let id):
            selectedPlayerIDs = [id]
            selectedTeamIDs.removeAll()
            selectedGameIDs.removeAll()
        case .team(let id):
            selectedPlayerIDs.removeAll()
            selectedTeamIDs = [id]
            selectedGameIDs.removeAll()
        case .game(let id):
            selectedPlayerIDs.removeAll()
            selectedTeamIDs.removeAll()
            selectedGameIDs = [id]
        }
    }

    private func togglePlayerSelection(_ id: UUID) {
        if selectedPlayerIDs.contains(id) {
            selectedPlayerIDs.remove(id)
        } else {
            selectedPlayerIDs.insert(id)
        }
    }

    private func toggleTeamSelection(_ id: UUID) {
        if selectedTeamIDs.contains(id) {
            selectedTeamIDs.remove(id)
        } else {
            selectedTeamIDs.insert(id)
        }
    }

    private func toggleGameSelection(_ id: UUID) {
        if selectedGameIDs.contains(id) {
            selectedGameIDs.remove(id)
        } else {
            selectedGameIDs.insert(id)
        }
    }

    private func sendRequest() {
        guard connectedPeers.indices.contains(selectedPeerIndex) else {
            alertMessage = NSLocalizedString("error_no_connected_device", comment: "Please connect a receiving device")
            return
        }

        let playersForTransfer: [Player]
        if includePlayers {
            playersForTransfer = filteredPlayers
        } else {
            playersForTransfer = teamLinkedPlayers
        }

        let finalPlayers = includePhotos ? playersForTransfer : playersForTransfer.map { p in
            var copy = p
            copy.photoData = nil
            return copy
        }

        let payload = BluetoothStoreSyncPayload(
            players: finalPlayers,
            teams: filteredTeams,
            savedGames: filteredSavedGames
        )

        let hasData = !payload.players.isEmpty || !payload.teams.isEmpty || !payload.savedGames.isEmpty
        guard hasData else {
            alertMessage = NSLocalizedString("error_no_data_in_selected_category", comment: "No data in the selected categories to send")
            return
        }

        let targetPeer = connectedPeers[selectedPeerIndex]
        bluetooth.sendStoreSyncOfferAsync(payload: payload, to: targetPeer)
    }

    private func gameSubtitle(for game: SavedGame) -> String {
        let dateText = Self.dateFormatter.string(from: game.savedAt)
        let homeScore = score(for: game.snapshot.homeTeamID, in: game)
        let awayScore = score(for: game.snapshot.awayTeamID, in: game)
        return "\(dateText) · \(homeScore):\(awayScore)"
    }

    private func score(for teamID: UUID?, in game: SavedGame) -> Int {
        guard let teamID else { return 0 }

        let playerIDs: [UUID]
        if teamID == game.snapshot.homeTeamID {
            playerIDs = game.homePlayerIDs
        } else if teamID == game.snapshot.awayTeamID {
            playerIDs = game.awayPlayerIDs
        } else {
            playerIDs = []
        }

        return playerIDs.reduce(into: 0) { partialResult, playerID in
            partialResult += game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func progressDetailText(_ progress: BluetoothStoreSyncProgress) -> String {
        let percent = Int((progress.fractionCompleted * 100).rounded())
        let bytes = "\(byteString(progress.transferredBytes))/\(byteString(progress.totalBytes))"
        return String(format: NSLocalizedString("progress_sending_to_format", comment: "Sending to X: percent · chunks · bytes"), progress.peerName, percent, progress.transferredChunks, progress.totalChunks, bytes)
    }

    private func byteString(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
