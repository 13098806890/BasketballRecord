import SwiftUI
import UIKit

private enum FilterDefaults {
    static let historyKey = "historyFilterGroupID"
    static let careerKey = "careerFilterGroupID"

    static func load(_ key: String) -> UUID? {
        UserDefaults.standard.string(forKey: key).flatMap { UUID(uuidString: $0) }
    }

    static func save(_ key: String, _ id: UUID?) {
        UserDefaults.standard.set(id?.uuidString ?? "", forKey: key)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager

    @State private var activeGlobalBluetoothAlert: GlobalBluetoothAlert?
    @State private var bluetoothAlertMessage: String?
    @State private var isShowingStoreSyncBusyAlert = false
    @State private var suppressBusyAlertUntilIdle = false
    @State private var storeSyncBusyAlertText = ""

    var body: some View {
        TabView {
            GameView()
                .tabItem {
                    Label(LocalizedStringKey("tab_score"), systemImage: "sportscourt")
                }

            HistoryView()
                .tabItem {
                    Label(LocalizedStringKey("tab_history"), systemImage: "clock.arrow.circlepath")
                }

            CareerView()
                .tabItem {
                    Label(LocalizedStringKey("tab_career"), systemImage: "trophy")
                }

            RosterView()
                .tabItem {
                    Label(LocalizedStringKey("tab_settings"), systemImage: "gearshape")
                }
        }
        .overlay(alignment: .top) {
            if let summary = globalStoreSyncSummary {
                globalStoreSyncBanner(summary)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: globalStoreSyncSummary?.id)
        .onAppear {
            refreshStoreSyncBusyAlertPresentation(force: true)
            presentNextGlobalAlertIfNeeded(force: true)
        }
        .onChange(of: bluetooth.isStoreSyncPreparing) { _, _ in
            refreshStoreSyncBusyAlertPresentation(force: true)
        }
        .onChange(of: bluetooth.isStoreSyncProcessing) { _, _ in
            refreshStoreSyncBusyAlertPresentation(force: true)
        }
        .onChange(of: bluetooth.storeSyncPreparationMessage) { _, _ in
            refreshStoreSyncBusyAlertPresentation(force: false)
        }
        .onChange(of: bluetooth.storeSyncProcessingMessage) { _, _ in
            refreshStoreSyncBusyAlertPresentation(force: false)
        }
        .onChange(of: storeSyncProgressRefreshKey) { _, _ in
            refreshStoreSyncBusyAlertPresentation(force: false)
        }
        .onChange(of: bluetooth.pendingStoreSyncOffer?.id) { _, _ in
            presentNextGlobalAlertIfNeeded(force: true)
        }
        .onChange(of: bluetooth.pendingStoreSync?.id) { _, _ in
            presentNextGlobalAlertIfNeeded(force: true)
        }
        .onChange(of: bluetooth.pendingStoreSyncStatusAlert?.id) { _, _ in
            presentNextGlobalAlertIfNeeded(force: true)
        }
        .onChange(of: bluetooth.pendingLiveInvite?.id) { _, _ in
            presentNextGlobalAlertIfNeeded(force: true)
        }
        .onChange(of: bluetoothAlertMessage) { _, _ in
            presentNextGlobalAlertIfNeeded(force: true)
        }
        .onChange(of: activeGlobalBluetoothAlert?.id) { _, value in
            if value == nil {
                presentNextGlobalAlertIfNeeded(force: false)
            }
        }
        .alert(item: $activeGlobalBluetoothAlert) { alert in
            switch alert {
            case let .storeSyncOffer(offer):
                Alert(
                    title: Text(LocalizedStringKey("alert_store_sync_offer_title")),
                    message: Text(storeSyncOfferAlertMessage(for: offer)),
                    primaryButton: .default(Text(LocalizedStringKey("alert_accept_and_receive")), action: {
                        let ok = bluetooth.respondToStoreSyncOffer(offer, accepted: true)
                        if !ok {
                            bluetoothAlertMessage = NSLocalizedString("alert_confirm_failed", comment: "Confirm failed message")
                        }
                    }),
                    secondaryButton: .destructive(Text(LocalizedStringKey("alert_reject")), action: {
                        _ = bluetooth.respondToStoreSyncOffer(offer, accepted: false)
                    })
                )

            case let .storeSyncImport(sync):
                Alert(
                    title: Text(LocalizedStringKey("alert_import_available_title")),
                    message: Text(storeSyncImportAlertMessage(for: sync)),
                    primaryButton: .default(Text(LocalizedStringKey("alert_import")), action: {
                        importReceivedStoreSync(sync)
                    }),
                    secondaryButton: .destructive(Text(LocalizedStringKey("alert_ignore")), action: {
                        bluetooth.clearPendingStoreSync()
                    })
                )

            case let .liveInvite(invite):
                Alert(
                    title: Text(LocalizedStringKey("alert_collaboration_invite_title")),
                    message: Text(String(format: NSLocalizedString("alert_collaboration_invite_message", comment: "Invite message"), invite.fromPeerName)),
                    primaryButton: .default(Text(LocalizedStringKey("alert_accept")), action: {
                        acceptLiveInviteGlobally(invite)
                    }),
                    secondaryButton: .cancel(Text(LocalizedStringKey("alert_reject")), action: {
                        _ = bluetooth.respondToLiveInvite(invite, accepted: false)
                        bluetooth.clearPendingLiveInvite()
                    })
                )

            case let .status(status):
                Alert(
                    title: Text(status.title),
                    message: Text(status.message),
                    dismissButton: .default(Text(LocalizedStringKey("alert_ok")), action: {
                        bluetooth.clearPendingStoreSyncStatusAlert()
                    })
                )

            case let .message(message):
                Alert(
                    title: Text(LocalizedStringKey("alert_notice_title")),
                    message: Text(message),
                    dismissButton: .default(Text(LocalizedStringKey("alert_ok")), action: {
                        bluetoothAlertMessage = nil
                    })
                )
            }
        }
        .sheet(isPresented: $isShowingStoreSyncBusyAlert) {
            NavigationStack {
                VStack(spacing: 16) {
                    let outgoing = bluetooth.outgoingStoreSyncProgress
                    let incoming = bluetooth.incomingStoreSyncProgress
                    let progress = outgoing ?? incoming

                    if let progress {
                        VStack(spacing: 8) {
                            ProgressView(value: progress.fractionCompleted)
                                .tint(.blue)

                            Text(loadingTitle)
                                .font(.subheadline.weight(.semibold))

                            Text(loadingSubtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)

                            Text(storeSyncBusyAlertText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .navigationTitle(LocalizedStringKey("alert_store_sync_processing"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(LocalizedStringKey("button_continue_in_background")) {
                            suppressBusyAlertUntilIdle = true
                            isShowingStoreSyncBusyAlert = false
                        }
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button(LocalizedStringKey("button_cancel_sync"), role: .destructive) {
                            _ = bluetooth.cancelCurrentStoreSyncTask()
                            suppressBusyAlertUntilIdle = false
                            isShowingStoreSyncBusyAlert = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var loadingTitle: String {
        if let outgoing = bluetooth.outgoingStoreSyncProgress {
            return String(format: NSLocalizedString("status_transferring_format", comment: "Transferring chunks"), outgoing.transferredChunks, outgoing.totalChunks)
        }
        if let incoming = bluetooth.incomingStoreSyncProgress {
            return String(format: NSLocalizedString("status_receiving_format", comment: "Receiving chunks"), incoming.transferredChunks, incoming.totalChunks)
        }
        if bluetooth.isStoreSyncPreparing {
            return bluetooth.storeSyncPreparationMessage ?? NSLocalizedString("status_preparing_sync", comment: "Preparing sync data")
        }
        return bluetooth.storeSyncProcessingMessage ?? NSLocalizedString("status_processing_sync", comment: "Processing sync data")
    }

    private var storeSyncProgressRefreshKey: String {
        if let outgoing = bluetooth.outgoingStoreSyncProgress {
            return "out-\(outgoing.id.uuidString)-\(outgoing.transferredChunks)-\(outgoing.totalChunks)"
        }
        if let incoming = bluetooth.incomingStoreSyncProgress {
            return "in-\(incoming.id.uuidString)-\(incoming.transferredChunks)-\(incoming.totalChunks)"
        }
        return "idle"
    }

    private var loadingSubtitle: String {
        if let outgoing = bluetooth.outgoingStoreSyncProgress {
            let percent = Int((outgoing.fractionCompleted * 100).rounded())
            return "\(percent)% · \(byteString(outgoing.transferredBytes))/\(byteString(outgoing.totalBytes))"
        }
        if let incoming = bluetooth.incomingStoreSyncProgress {
            let percent = Int((incoming.fractionCompleted * 100).rounded())
            return "\(percent)% · \(byteString(incoming.transferredBytes))/\(byteString(incoming.totalBytes))"
        }
        if bluetooth.isStoreSyncPreparing {
            return NSLocalizedString("status_preparing_sync_hint", comment: "Preparing data hint")
        }
        return NSLocalizedString("status_background_processing_hint", comment: "Background processing hint")
    }

    private var globalStoreSyncSummary: GlobalStoreSyncSummary? {
        if let incoming = bluetooth.incomingStoreSyncProgress {
            let percent = Int((incoming.fractionCompleted * 100).rounded())
            return GlobalStoreSyncSummary(
                id: "incoming-\(incoming.id.uuidString)-\(incoming.transferredChunks)",
                icon: "arrow.down.circle.fill",
                title: String(format: NSLocalizedString("transfer_receiving_title_format", comment: "Receiving title"), incoming.peerName),
                detail: "\(percent)% · \(incoming.transferredChunks)/\(incoming.totalChunks) · \(byteString(incoming.transferredBytes))/\(byteString(incoming.totalBytes))",
                progress: incoming.fractionCompleted
            )
        }

        if let outgoing = bluetooth.outgoingStoreSyncProgress {
            let percent = Int((outgoing.fractionCompleted * 100).rounded())
            return GlobalStoreSyncSummary(
                id: "outgoing-\(outgoing.id.uuidString)-\(outgoing.transferredChunks)",
                icon: "arrow.up.circle.fill",
                title: String(format: NSLocalizedString("transfer_sending_title_format", comment: "Sending title"), outgoing.peerName),
                detail: "\(percent)% · \(outgoing.transferredChunks)/\(outgoing.totalChunks) · \(byteString(outgoing.transferredBytes))/\(byteString(outgoing.totalBytes))",
                progress: outgoing.fractionCompleted
            )
        }

        if bluetooth.isStoreSyncPreparing || bluetooth.isStoreSyncProcessing {
            return GlobalStoreSyncSummary(
                id: "busy-\(loadingTitle)",
                icon: "arrow.triangle.2.circlepath.circle.fill",
                title: loadingTitle,
                detail: loadingSubtitle,
                progress: nil
            )
        }

        return nil
    }

    @ViewBuilder
    private func globalStoreSyncBanner(_ summary: GlobalStoreSyncSummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: summary.icon)
                .foregroundStyle(.blue)
                .font(.title3)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let progress = summary.progress {
                    ProgressView(value: progress)
                        .tint(.blue)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func byteString(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    private func refreshStoreSyncBusyAlertPresentation(force: Bool) {
        let isBusy = bluetooth.isStoreSyncPreparing || bluetooth.isStoreSyncProcessing

        if !isBusy {
            suppressBusyAlertUntilIdle = false
            isShowingStoreSyncBusyAlert = false
            return
        }

        storeSyncBusyAlertText = "\(loadingTitle)\n\n\(loadingSubtitle)"

        if force || (!isShowingStoreSyncBusyAlert && !suppressBusyAlertUntilIdle) {
            isShowingStoreSyncBusyAlert = true
        }
    }

    private func presentNextGlobalAlertIfNeeded(force: Bool) {
        if !force, activeGlobalBluetoothAlert != nil {
            return
        }

        if let offer = bluetooth.pendingStoreSyncOffer {
            activeGlobalBluetoothAlert = .storeSyncOffer(offer)
            return
        }

        if let sync = bluetooth.pendingStoreSync {
            activeGlobalBluetoothAlert = .storeSyncImport(sync)
            return
        }

        if let invite = bluetooth.pendingLiveInvite {
            activeGlobalBluetoothAlert = .liveInvite(invite)
            return
        }

        if let status = bluetooth.pendingStoreSyncStatusAlert {
            activeGlobalBluetoothAlert = .status(status)
            return
        }

        if let message = bluetoothAlertMessage,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeGlobalBluetoothAlert = .message(message)
            return
        }

        activeGlobalBluetoothAlert = nil
    }

    private func acceptLiveInviteGlobally(_ invite: BluetoothReceivedLiveInvite) {
        let ok = bluetooth.respondToLiveInvite(invite, accepted: true)
        guard ok else {
            bluetoothAlertMessage = NSLocalizedString("alert_confirmation_failed_retry", comment: "Confirmation failed")
            return
        }

        let existingPlayerIDs = Set(store.players.map(\.id))
        let existingTeamIDs = Set(store.teams.map(\.id))

        let missingPlayers = invite.payload.players.filter { !existingPlayerIDs.contains($0.id) }
        let missingTeams = invite.payload.teams.filter { !existingTeamIDs.contains($0.id) }

        if !missingPlayers.isEmpty {
            _ = store.upsertPlayers(missingPlayers)
        }
        if !missingTeams.isEmpty {
            _ = store.upsertTeams(missingTeams)
        }

        let snapshotPayload = BluetoothLiveSnapshotPayload(
            sessionID: invite.payload.sessionID,
            hostDeviceID: invite.payload.hostDeviceID,
            version: invite.payload.stateVersion,
            stateHash: invite.payload.stateHash,
            reason: "accepted_live_invite",
            state: invite.payload.state
        )
        bluetooth.latestLiveSnapshot = BluetoothReceivedLiveSnapshot(
            fromPeerID: invite.fromPeerID,
            fromPeerName: invite.fromPeerName,
            payload: snapshotPayload
        )
        bluetooth.noteAcceptedLiveSession(sessionID: invite.payload.sessionID, with: invite.fromPeerName)
        bluetooth.postGlobalBluetoothAlert(title: NSLocalizedString("alert_bluetooth_collab_title", comment: "Bluetooth collab title"), message: String(format: NSLocalizedString("alert_joined_collab_format", comment: "Joined collab"), invite.fromPeerName))
        bluetooth.clearPendingLiveInvite()
    }

    private func importReceivedStoreSync(_ sync: BluetoothReceivedStoreSync) {
        let playerSummary = store.upsertPlayers(sync.payload.players)
        let teamSummary = store.upsertTeams(sync.payload.teams)
        let gameSummary = store.upsertSavedGames(sync.payload.savedGames)
        bluetooth.clearPendingStoreSync()
        bluetoothAlertMessage = String(format: NSLocalizedString("import_summary_format", comment: "Import summary"), playerSummary.inserted, playerSummary.updated, teamSummary.inserted, teamSummary.updated, gameSummary.inserted, gameSummary.updated)
    }

    private func storeSyncOfferAlertMessage(for offer: BluetoothReceivedStoreSyncOffer) -> String {
        var lines: [String] = [
            String(format: NSLocalizedString("import_offer_from_format", comment: "Offer from"), offer.fromPeerName),
            String(format: NSLocalizedString("import_offer_counts_format", comment: "Offer counts"), offer.payload.playerCount, offer.payload.teamCount, offer.payload.gameCount)
        ]

        let previewLines = [
            previewLine(title: NSLocalizedString("preview_category_players", comment: "Players"), items: offer.payload.playerNamesPreview, total: offer.payload.playerCount),
            previewLine(title: NSLocalizedString("preview_category_teams", comment: "Teams"), items: offer.payload.teamNamesPreview, total: offer.payload.teamCount),
            previewLine(title: NSLocalizedString("preview_category_games", comment: "Games"), items: offer.payload.gameTitlesPreview, total: offer.payload.gameCount)
        ].compactMap { $0 }

        lines.append(contentsOf: previewLines)
        return lines.joined(separator: "\n")
    }

    private func storeSyncImportAlertMessage(for sync: BluetoothReceivedStoreSync) -> String {
        let from = String(format: NSLocalizedString("import_offer_from_format", comment: "Offer from"), sync.fromPeerName)
        let counts = String(format: NSLocalizedString("import_offer_counts_format", comment: "Offer counts"), sync.payload.players.count, sync.payload.teams.count, sync.payload.savedGames.count)
        return "\(from)\n\(counts)"
    }

    private func previewLine(title: String, items: [String], total: Int) -> String? {
        guard total > 0 else { return nil }
        let shown = Array(items.prefix(3))
        guard !shown.isEmpty else {
            return String(format: NSLocalizedString("preview_line_title_format", comment: "Preview line title"), title, total)
        }

        let suffix = total > shown.count ? String(format: NSLocalizedString("preview_line_suffix_format", comment: "Preview line suffix"), total) : ""
        return "\(title)：\(shown.joined(separator: "、"))\(suffix)"
    }
}

private struct GlobalStoreSyncSummary: Equatable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let progress: Double?
}

private enum GlobalBluetoothAlert: Identifiable {
    case storeSyncOffer(BluetoothReceivedStoreSyncOffer)
    case storeSyncImport(BluetoothReceivedStoreSync)
    case liveInvite(BluetoothReceivedLiveInvite)
    case status(BluetoothStoreSyncStatusAlert)
    case message(String)

    var id: String {
        switch self {
        case let .storeSyncOffer(offer):
            return "offer-\(offer.id.uuidString)"
        case let .storeSyncImport(sync):
            return "import-\(sync.id.uuidString)"
        case let .liveInvite(invite):
            return "live-\(invite.id.uuidString)"
        case let .status(status):
            return "status-\(status.id.uuidString)"
        case let .message(message):
            return "message-\(message)"
        }
    }
}

private enum CareerBoardKind: String, CaseIterable, Identifiable {
    case team = "enum_team"
    case player = "enum_player"

    var id: String { rawValue }
}

struct CareerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var boardKind: CareerBoardKind = .team
    @State private var selectedGroupID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker(LocalizedStringKey("tab_career"), selection: $boardKind) {
                    ForEach(CareerBoardKind.allCases) { kind in
                        Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: { selectedGroupID = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                if boardKind == .team {
                    TeamCareerBoardView(selectedGroupID: $selectedGroupID)
                } else {
                    PlayerCareerBoardView(selectedGroupID: $selectedGroupID)
                }
            }
            .navigationTitle(LocalizedStringKey("tab_career"))
            .toolbar {
                if store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                    }
                }
            }
        }
        .onAppear {
            selectedGroupID = FilterDefaults.load(FilterDefaults.careerKey)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            FilterDefaults.save(FilterDefaults.careerKey, newValue)
        }
    }
}

private struct TeamCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if summaries.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("empty_no_team_data"), systemImage: "person.3.sequence")
                        .padding(.top, 80)
                }

                ForEach(summaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(summary.teamName)
                                .font(.headline)
                            Spacer()
                            Text("\(summary.wins)-\(summary.losses)")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            teamTile(LocalizedStringKey("career_tile_games"), "\(summary.games)")
                            teamTile(LocalizedStringKey("career_tile_win_rate"), summary.winRateText)
                            teamTile(LocalizedStringKey("career_tile_net"), summary.diffText)
                        }

                        HStack(spacing: 8) {
                            teamTile(LocalizedStringKey("career_tile_avg_points"), summary.avgForText)
                            teamTile(LocalizedStringKey("career_tile_avg_points_against"), summary.avgAgainstText)
                            teamTile(LocalizedStringKey("career_tile_total_score"), "\(summary.pointsFor)-\(summary.pointsAgainst)")
                        }
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.06), lineWidth: 1))
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.99))
    }

    private var summaries: [TeamCareerSummary] {
        store.teams.map { team in
            var games = 0
            var wins = 0
            var losses = 0
            var pointsFor = 0
            var pointsAgainst = 0

            let relevantGames = selectedGroupID.map { store.gamesInGroup($0) } ?? store.savedGames

            for game in relevantGames {
                if game.snapshot.homeTeamID == team.id {
                    let home = score(for: .home, in: game)
                    let away = score(for: .away, in: game)
                    games += 1
                    pointsFor += home
                    pointsAgainst += away
                    if home > away { wins += 1 } else if home < away { losses += 1 }
                } else if game.snapshot.awayTeamID == team.id {
                    let home = score(for: .home, in: game)
                    let away = score(for: .away, in: game)
                    games += 1
                    pointsFor += away
                    pointsAgainst += home
                    if away > home { wins += 1 } else if away < home { losses += 1 }
                }
            }

            return TeamCareerSummary(
                id: team.id,
                teamName: team.name,
                games: games,
                wins: wins,
                losses: losses,
                pointsFor: pointsFor,
                pointsAgainst: pointsAgainst
            )
        }
        .sorted {
            if $0.games == 0 && $1.games > 0 { return false }
            if $1.games == 0 && $0.games > 0 { return true }
            if $0.winRate == $1.winRate { return $0.games > $1.games }
            return $0.winRate > $1.winRate
        }
    }

    private func score(for side: TeamSide, in game: SavedGame) -> Int {
        let ids = side == .home ? game.homePlayerIDs : game.awayPlayerIDs
        return ids.reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func teamTile(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(red: 0.95, green: 0.97, blue: 1.00), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PlayerCareerBoardView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedGroupID: UUID?

    var body: some View {
        List {
            if summaries.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_player_data"), systemImage: "person.crop.circle.badge.questionmark")
            }

            ForEach(summaries) { summary in
                NavigationLink {
                    PlayerProfileView(playerID: summary.id, selectedGroupID: $selectedGroupID)
                } label: {
                    HStack(spacing: 10) {
                        if let player = store.player(for: summary.id) {
                            PlayerAvatarView(player: player, size: 40)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(summary.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), summary.totalPoints))
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                            Text(String(format: NSLocalizedString("career_summary_format", comment: "Career summary"), summary.games, summary.avgPointsText, summary.avgReboundsText, summary.avgAssistsText, summary.avgMinutesText))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var summaries: [PlayerCareerSummary] {
        store.players.map { player in
            var games = 0
            var total = PlayerStats()
            var totalSeconds: TimeInterval = 0

            let relevantGames = selectedGroupID.map { store.gamesInGroup($0) } ?? store.savedGames

            for game in relevantGames {
                guard game.didParticipate(player.id) else { continue }

                games += 1
                let stats = game.snapshot.statsByPlayerID[player.id, default: PlayerStats()]
                total.twoMade += stats.twoMade
                total.twoAttempts += stats.twoAttempts
                total.threeMade += stats.threeMade
                total.threeAttempts += stats.threeAttempts
                total.bonusFreeThrowMade += stats.bonusFreeThrowMade
                total.bonusFreeThrowAttempts += stats.bonusFreeThrowAttempts
                total.freeThrowMade += stats.freeThrowMade
                total.freeThrowAttempts += stats.freeThrowAttempts
                total.rebounds += stats.rebounds
                total.assists += stats.assists
                total.fouls += stats.fouls
                total.blocks += stats.blocks
                total.steals += stats.steals
                total.turnovers += stats.turnovers
                totalSeconds += game.snapshot.playingSecondsByPlayerID[player.id, default: 0]
            }

            return PlayerCareerSummary(
                id: player.id,
                name: player.name,
                games: games,
                totalPoints: total.points,
                totalRebounds: total.rebounds,
                totalAssists: total.assists,
                totalSeconds: totalSeconds
            )
        }
        .sorted {
            if $0.games == 0 && $1.games > 0 { return false }
            if $1.games == 0 && $0.games > 0 { return true }
            if $0.avgPoints == $1.avgPoints { return $0.totalPoints > $1.totalPoints }
            return $0.avgPoints > $1.avgPoints
        }
    }
}

private struct TeamCareerSummary: Identifiable {
    var id: UUID
    var teamName: String
    var games: Int
    var wins: Int
    var losses: Int
    var pointsFor: Int
    var pointsAgainst: Int

    var winRate: Double {
        guard games > 0 else { return 0 }
        return Double(wins) / Double(games)
    }

    var winRateText: String { "\(Int((winRate * 100).rounded()))%" }
    var diffText: String {
        let diff = pointsFor - pointsAgainst
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    var avgForText: String {
        guard games > 0 else { return "0.0" }
        return String(format: "%.1f", Double(pointsFor) / Double(games))
    }

    var avgAgainstText: String {
        guard games > 0 else { return "0.0" }
        return String(format: "%.1f", Double(pointsAgainst) / Double(games))
    }
}

private struct PlayerCareerSummary: Identifiable {
    var id: UUID
    var name: String
    var games: Int
    var totalPoints: Int
    var totalRebounds: Int
    var totalAssists: Int
    var totalSeconds: TimeInterval

    var avgPoints: Double { games > 0 ? Double(totalPoints) / Double(games) : 0 }
    var avgPointsText: String { String(format: "%.1f", avgPoints) }
    var avgReboundsText: String { String(format: "%.1f", games > 0 ? Double(totalRebounds) / Double(games) : 0) }
    var avgAssistsText: String { String(format: "%.1f", games > 0 ? Double(totalAssists) / Double(games) : 0) }
    var avgMinutesText: String { String(format: "%.1f", games > 0 ? totalSeconds / 60 / Double(games) : 0) }
}

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var selectedGroupID: UUID?
    @State private var isShowingImport = false
    @State private var isShowingDelete = false
    @State private var displayedGames: [SavedGame] = []
    @State private var isLoadingGames = true
    @State private var loadTask: Task<Void, Never>?
    @State private var pendingSwipeDeleteGame: SavedGame?

    var body: some View {
        NavigationStack {
            List {
                if let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(group.name)
                                    .font(.headline)
                            }
                            Spacer()
                            Button(action: { selectedGroupID = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                if !isLoadingGames, filteredGames.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("empty_no_game_history"), systemImage: "clock.badge.questionmark")
                }

                ForEach(monthGroups) { group in
                    DisclosureGroup {
                        ForEach(group.games) { game in
                            NavigationLink {
                                SavedGameDetailView(game: game)
                            } label: {
                                SavedGameRow(game: game)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if store.isPro {
                                    Button {
                                        store.toggleCloudStorage(for: game.id)
                                    } label: {
                                        Label("iCloud", systemImage: store.cloudEnabledGameIDs.contains(game.id) ? "icloud.slash" : "icloud")
                                    }
                                    .tint(.blue)
                                }
                                Button {
                                    if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
                                        store.savedGames[idx].isLocked.toggle()
                                    }
                                } label: {
                                    Label(LocalizedStringKey(game.isLocked ? "label_unlock" : "label_lock"), systemImage: game.isLocked ? "lock.open" : "lock")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !game.isLocked {
                                    Button {
                                        pendingSwipeDeleteGame = game
                                    } label: {
                                        Label(LocalizedStringKey("label_delete"), systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    } label: {
                        Text(group.title)
                            .font(.headline)
                    }
                }
        }
        .navigationTitle(LocalizedStringKey("nav_game_history"))
        .overlay {
            if isLoadingGames {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(LocalizedStringKey("loading_games"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .searchable(text: $searchText, prompt: LocalizedStringKey("search_player_prompt"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if store.isPro {
                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                }

                Button {
                    isShowingDelete = true
                } label: {
                    Label(LocalizedStringKey("label_delete"), systemImage: "trash")
                }

                Button {
                    isShowingImport = true
                } label: {
                    Label(LocalizedStringKey("label_import"), systemImage: TransferSymbol.importData)
                }
            }
        }
        .sheet(isPresented: $isShowingDelete) {
            DeleteSavedGamesView()
        }
        .sheet(isPresented: $isShowingImport) {
            ImportGameView()
        }
        .onAppear {
            selectedGroupID = FilterDefaults.load(FilterDefaults.historyKey)
            loadGamesAsync(showLoading: displayedGames.isEmpty)
        }
        .onChange(of: store.savedGames) { _, _ in
            loadGamesAsync(showLoading: false)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            FilterDefaults.save(FilterDefaults.historyKey, newValue)
        }
            .alert(LocalizedStringKey("alert_confirm_delete_game_title"), isPresented: Binding(
                get: { pendingSwipeDeleteGame != nil },
                set: { if !$0 { pendingSwipeDeleteGame = nil } }
            )) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) {
                    pendingSwipeDeleteGame = nil
                }
                Button(LocalizedStringKey("label_delete"), role: .destructive) {
                    if let gameID = pendingSwipeDeleteGame?.id {
                        deleteGame(id: gameID)
                    }
                    pendingSwipeDeleteGame = nil
                }
            } message: {
                Text(LocalizedStringKey("text_irreversible_deletion"))
            }
        }
    }

    private var filteredGames: [SavedGame] {
        var games = displayedGames

        // Filter by group if selected
        if let selectedGroupID = selectedGroupID {
            games = games.filter { $0.groupIDs.contains(selectedGroupID) }
        }

        // Filter by search text
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return games }
        return games.filter { game in
            game.playerNamesByID.values.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var monthGroups: [GameMonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredGames) { game in
            let components = calendar.dateComponents([.year, .month], from: game.savedAt)
            return GameMonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }
        return grouped.keys.sorted(by: >).map { key in
            GameMonthGroup(key: key, games: grouped[key, default: []].sorted { $0.savedAt > $1.savedAt })
        }
    }

    private func deleteGame(id: UUID) {
        store.deleteSavedGames(ids: Set([id]))
    }

    private func loadGamesAsync(showLoading: Bool) {
        let currentGames = store.savedGames
        loadTask?.cancel()
        if showLoading {
            isLoadingGames = true
        }

        loadTask = Task {
            if showLoading {
                try? await Task.sleep(nanoseconds: 120_000_000)
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled else { return }

            let sortedGames = currentGames.sorted { $0.savedAt > $1.savedAt }
            await MainActor.run {
                displayedGames = sortedGames
                isLoadingGames = false
            }
        }
    }
}

private struct DeleteSavedGamesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<UUID> = []
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if orderedGames.isEmpty {
                    ContentUnavailableView(LocalizedStringKey("empty_no_game_history"), systemImage: "clock.badge.questionmark")
                }

                ForEach(orderedGames) { game in
                    Button {
                        toggle(game.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(game.id) ? .red : .secondary)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(String(format: NSLocalizedString("game_vs_format", comment: "Team vs"), game.homeTeamName, game.awayTeamName))
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(scoreLine(for: game))
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                }

                                Text(Self.dateFormatter.string(from: game.savedAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(LocalizedStringKey("nav_delete_games"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(format: NSLocalizedString("button_delete_count", comment: "Delete count"), selectedIDs.count)) {
                        isShowingDeleteConfirmation = true
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .alert(LocalizedStringKey("alert_confirm_delete_games_title"), isPresented: $isShowingDeleteConfirmation) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("label_delete"), role: .destructive) {
                    store.deleteSavedGames(ids: selectedIDs)
                    selectedIDs.removeAll()
                    if store.savedGames.isEmpty {
                        dismiss()
                    }
                }
            } message: {
                Text(LocalizedStringKey("text_irreversible_deletion"))
            }
        }
    }

    private var orderedGames: [SavedGame] {
        store.savedGames.sorted { $0.savedAt > $1.savedAt }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        "\(score(for: game.snapshot.homeTeamID, in: game)) - \(score(for: game.snapshot.awayTeamID, in: game))"
    }

    private func score(for teamID: UUID?, in game: SavedGame) -> Int {
        let ids = teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
        return ids.reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct GameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: GameMonthKey, rhs: GameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

private struct GameMonthGroup: Identifiable {
    var key: GameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { String(format: NSLocalizedString("month_title_format", comment: "Month title"), key.year, key.month) }
}

private struct SavedGameRow: View {
    @EnvironmentObject private var store: AppStore
    var game: SavedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(scoreLine)
                    .font(.headline.monospacedDigit())
            }

            HStack {
                if game.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(Self.dateFormatter.string(from: game.savedAt))
                Spacer()
                if store.cloudEnabledGameIDs.contains(game.id) {
                    Image(systemName: "icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        game.displayTitle
    }

    private var scoreLine: String {
        "\(score(for: game.snapshot.homeTeamID)) - \(score(for: game.snapshot.awayTeamID))"
    }

    private func score(for teamID: UUID?) -> Int {
        playerIDs(for: teamID).reduce(0) { total, playerID in
            total + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

struct SavedGameDetailView: View {
    enum DisplayMode {
        case history
        case live
    }

    @EnvironmentObject private var store: AppStore
    var game: SavedGame
    var displayMode: DisplayMode = .history
    @State private var isShowingExport = false
    @State private var selectedPeriod: Int? = nil
    @State private var isGeneratingAISummary = false
    @State private var aiSummary = ""
    @State private var aiSummaryError: String?
    @State private var periodAnalysis = SavedGamePeriodAnalysis()
    @State private var selectedGroupID: UUID?
    @State private var editDisplayName = ""

    init(game: SavedGame, displayMode: DisplayMode = .history) {
        self.game = game
        self.displayMode = displayMode

        _aiSummary = State(initialValue: game.aiSummary ?? "")
        _selectedGroupID = State(initialValue: game.groupIDs.first)

        let initialAnalyzer = SavedGameAnalyzer(game: game) { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        }
        _periodAnalysis = State(initialValue: initialAnalyzer.analyze())
    }

    var body: some View {
        List {
            groupAssignmentSection

            Section {
                HStack(spacing: 8) {
                    TextField(LocalizedStringKey("label_game_name"), text: $editDisplayName)
                        .font(.headline)
                        .onSubmit {
                            if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
                                store.savedGames[idx].displayName = editDisplayName
                            }
                        }
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    teamSummary(.home)
                    Spacer()
                    Text("VS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    teamSummary(.away)
                }
            }

            if game.snapshot.periodCount > 1, !availablePeriodOptions.isEmpty {
                Section(LocalizedStringKey("section_data_range")) {
                    Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                        Text(LocalizedStringKey("data_range_full")).tag(Optional<Int>.none)
                        ForEach(availablePeriodOptions, id: \.self) { period in
                            Text(String(format: NSLocalizedString("data_range_period", comment: "Data range period"), period)).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                TeamStatsDisclosureView(
                    homeName: game.homeTeamName,
                    awayName: game.awayTeamName,
                    homeStats: aggregateStats(for: game.snapshot.homeTeamID),
                    awayStats: aggregateStats(for: game.snapshot.awayTeamID),
                    homeFouls: fouls(for: game.snapshot.homeTeamID),
                    awayFouls: fouls(for: game.snapshot.awayTeamID),
                    style: .scoreboard
                )
                .padding(.horizontal, 12)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
            }

            Section(String(format: NSLocalizedString("section_team_players_data_format", comment: "Team players data"), game.homeTeamName)) {
                ForEach(game.homePlayerIDs, id: \.self) { playerID in
                    playerStatRow(for: playerID)
                }
            }

            Section(String(format: NSLocalizedString("section_team_players_data_format", comment: "Team players data"), game.awayTeamName)) {
                ForEach(game.awayPlayerIDs, id: \.self) { playerID in
                    playerStatRow(for: playerID)
                }
            }

            if displayMode == .history {
                Section(LocalizedStringKey("section_ai_game_summary")) {
                    Button {
                        generateAISummary()
                    } label: {
                        HStack(spacing: 8) {
                            if isGeneratingAISummary {
                                ProgressView()
                            }
                            Label(LocalizedStringKey(isGeneratingAISummary ? "button_ai_generating" : "button_ai_generate_summary"), systemImage: "sparkles")
                        }
                    }
                    .disabled(isGeneratingAISummary || !store.isPro || aiConfig == nil)

                    if let aiSummaryError {
                        Text(aiSummaryError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if aiSummary.isEmpty {
                        Text(LocalizedStringKey(!store.isPro ? "text_ai_pro_required" : (aiConfig == nil ? "text_ai_waiting_key" : "text_ai_will_generate")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        aiSummaryStyledView
                    }
                }
            }

        }
        .navigationTitle(LocalizedStringKey("nav_game_detail"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if displayMode == .history {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.isPro {
                        Button {
                            store.toggleCloudStorage(for: game.id)
                        } label: {
                            Label(LocalizedStringKey("label_cloud"), systemImage: store.cloudEnabledGameIDs.contains(game.id) ? "icloud.fill" : "icloud")
                        }
                    }
                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID, iconName: "folder.badge.plus", checkedGroupIDs: Set(store.groups(for: game.id).map(\.id)))
                    Button {
                        isShowingExport = true
                    } label: {
                        Label(LocalizedStringKey("button_export"), systemImage: TransferSymbol.exportData)
                    }
                }
            }
        }
        .onChange(of: store.cloudEnabledGameIDs) { _, _ in
            // UI refreshes automatically via @Published
        }
        .sheet(isPresented: $isShowingExport) {
            ExportGameView(game: game)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            if let groupID = newValue {
                store.toggleGameGroup(game.id, groupID: groupID)
                DispatchQueue.main.async {
                    selectedGroupID = nil
                }
            }
        }
        .onAppear {
            editDisplayName = game.displayName
            sanitizeSelectedPeriod()
            if displayMode == .history,
               aiSummary.isEmpty,
               let savedSummary = game.aiSummary,
               !savedSummary.isEmpty {
                let normalizedSummary = normalizeAISummary(savedSummary)
                aiSummary = normalizedSummary
                if normalizedSummary != savedSummary {
                    store.updateAISummary(normalizedSummary, for: game.id)
                }
            }
        }
    }

    private func teamSummary(_ side: TeamSide) -> some View {
        let teamID = side == .home ? game.snapshot.homeTeamID : game.snapshot.awayTeamID
        let teamName = side == .home ? game.homeTeamName : game.awayTeamName
        return VStack(spacing: 4) {
            Text(teamName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(score(for: teamID))")
                .font(.largeTitle.monospacedDigit().weight(.bold))
            Text(String(format: NSLocalizedString("foul_count_format", comment: "Foul count"), fouls(for: teamID)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
    }

    private func playerStatRow(for playerID: UUID) -> some View {
        let stats = displayStatsByPlayerID[playerID, default: PlayerStats()]
        let playingTime = selectedPeriod == nil
            ? GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
            : "--:--"

        return NavigationLink {
            if store.player(for: playerID) != nil {
                PlayerProfileView(playerID: playerID, fixedGame: game, selectedGroupID: .constant(nil))
            } else {
                PlayerGameDetailView(game: game, playerID: playerID)
            }
        } label: {
            HStack(spacing: 10) {
                playerAvatar(for: playerID)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(game.playerNamesByID[playerID] ?? NSLocalizedString("unknown_player", comment: "Unknown player"))
                            .font(.subheadline.weight(.semibold))
                        if let role = game.role(of: playerID) {
                            Text(role.title)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), stats.points))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    Text(String(format: NSLocalizedString("stats_line_format", comment: "Stats line"), playingTime, stats.made, stats.attempts, stats.allFreeThrowMade, stats.allFreeThrowAttempts, stats.rebounds, stats.assists, stats.fouls, stats.blocks, stats.steals, stats.turnovers))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var groupAssignmentSection: some View {
        let assignedGroups = store.groups(for: game.id)
        if !assignedGroups.isEmpty {
            Section {
                ForEach(assignedGroups) { group in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_assigned_label", comment: "Assigned to"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: {
                            store.toggleGameGroup(game.id, groupID: group.id)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }

    private func score(for teamID: UUID?) -> Int {
        playerIDs(for: teamID).reduce(0) { total, playerID in
            total + displayStatsByPlayerID[playerID, default: PlayerStats()].points
        }
    }

    private func fouls(for teamID: UUID?) -> Int {
        playerIDs(for: teamID).reduce(0) { total, playerID in
            total + displayStatsByPlayerID[playerID, default: PlayerStats()].fouls
        }
    }

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        playerIDs(for: teamID).reduce(PlayerStats()) { partial, playerID in
            var total = partial
            let stats = displayStatsByPlayerID[playerID, default: PlayerStats()]
            total.twoMade += stats.twoMade
            total.twoAttempts += stats.twoAttempts
            total.threeMade += stats.threeMade
            total.threeAttempts += stats.threeAttempts
            total.bonusFreeThrowMade += stats.bonusFreeThrowMade
            total.bonusFreeThrowAttempts += stats.bonusFreeThrowAttempts
            total.freeThrowMade += stats.freeThrowMade
            total.freeThrowAttempts += stats.freeThrowAttempts
            total.rebounds += stats.rebounds
            total.assists += stats.assists
            total.fouls += stats.fouls
            total.blocks += stats.blocks
            total.steals += stats.steals
            total.turnovers += stats.turnovers
            return total
        }
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private var displayStatsByPlayerID: [UUID: PlayerStats] {
        guard let selectedPeriod else {
            return game.snapshot.statsByPlayerID
        }
        return statsByPlayerID(for: selectedPeriod)
    }

    private var availablePeriodOptions: [Int] {
        guard maxAvailablePeriod > 0 else { return [] }
        return Array(1...maxAvailablePeriod)
    }

    private var maxAvailablePeriod: Int {
        let maxPeriod = max(game.snapshot.periodCount, 1)
        if game.snapshot.isComplete {
            return maxPeriod
        }

        let reachedByLogs = periodAnalysis.logs.compactMap(\.inferredPeriod).max() ?? 0
        if game.snapshot.periodIsRunning || game.snapshot.periodElapsedSeconds > 0 {
            return min(max(reachedByLogs, game.snapshot.currentPeriod), maxPeriod)
        }
        return min(reachedByLogs, maxPeriod)
    }

    private var eventListMaxHeight: CGFloat {
        20 * 22
    }

    private var periodAwareLogs: [PeriodAwareLog] {
        periodAnalysis.logs
    }

    private var filteredPeriodAwareLogs: [PeriodAwareLog] {
        periodAnalysis.logs(for: selectedPeriod)
    }

    private func statsByPlayerID(for period: Int) -> [UUID: PlayerStats] {
        periodAnalysis.statsByPlayerID(for: period)
    }

    private func rebuildPeriodAnalysis() {
        let analyzer = SavedGameAnalyzer(game: game) { name in
            resolvePlayerIDByName(name)
        }
        periodAnalysis = analyzer.analyze()
        sanitizeSelectedPeriod()
    }

    private func sanitizeSelectedPeriod() {
        guard let selectedPeriod else { return }
        if !availablePeriodOptions.contains(selectedPeriod) {
            self.selectedPeriod = nil
        }
    }

    private func resolvePlayerIDByName(_ name: String) -> UUID? {
        if let existing = game.playerNamesByID.first(where: { $0.value == name })?.key {
            return existing
        }
        return store.players.first(where: { $0.name == name })?.id
    }

    private func logLineText(for item: PeriodAwareLog) -> String {
        GameLogFormatter.lineText(for: item)
    }

    private var aiConfig: (provider: AIProvider, model: AIModel, apiKey: String)? {
        let raw = UserDefaults.standard.string(forKey: "ai_selected_provider") ?? AIProvider.deepseek.rawValue
        let provider = AIProvider(rawValue: raw) ?? .deepseek
        let modelID = UserDefaults.standard.string(forKey: "ai_selected_model_id") ?? AIProvider.defaultModel.id
        let model = provider.models.first { $0.id == modelID } ?? provider.models.first ?? AIProvider.defaultModel
        guard let key = AIKeychain.shared.loadAPIKey(for: provider)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return (provider, model, key)
    }

    private var aiSummaryStyledView: some View {
        let sections = aiSummarySections

        return Group {
            if sections.isEmpty {
                Text(stripMarkdownDecorations(from: normalizeAISummary(aiSummary)))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        let isMVP = isMVPSection(section.title)
                        let mvpID = isMVP ? mvpPlayerID(in: section.items.joined(separator: " ")) : nil

                        VStack(alignment: .leading, spacing: 12) {
                            if isMVP {
                                HStack(spacing: 8) {
                                    Image(systemName: "trophy.fill")
                                        .font(.headline)
                                        .foregroundStyle(Color.yellow)

                                    Text(stripMarkdownDecorations(from: section.title))
                                        .font(.headline)
                                        .foregroundStyle(aiSummaryAccentColor)

                                    Spacer(minLength: 0)

                                    if let mvpID {
                                        mvpPlayerAvatar(for: mvpID)
                                    }
                                }
                            } else {
                                Label(stripMarkdownDecorations(from: section.title), systemImage: iconForSummarySection(section.title))
                                    .font(.headline)
                                    .foregroundStyle(aiSummaryAccentColor)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                                    let cleanedItem = stripMarkdownDecorations(from: item)

                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: iconForSummaryItem(sectionTitle: section.title, item: item, index: index))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(aiSummaryAccentColor)
                                            .frame(width: 14, height: 14)
                                            .padding(.top, 2)

                                        Text(cleanedItem)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(aiSummaryAccentColor.opacity(0.14), lineWidth: 1)
                        )
                    }
                }
                .textSelection(.enabled)
            }
        }
    }

    private var aiSummarySections: [AISummarySection] {
        parseAISummarySections(from: normalizeAISummary(aiSummary))
    }

    private var aiSummaryAccentColor: Color {
        Color(red: 0.22, green: 0.52, blue: 0.90)
    }

    private func generateAISummary() {
        guard let config = aiConfig else {
            aiSummaryError = NSLocalizedString("alert_ai_no_api_key", comment: "AI no API key")
            return
        }

        let prompt = summaryPrompt()
        isGeneratingAISummary = true
        aiSummaryError = nil

        Task {
            do {
                let systemRole = NSLocalizedString("ai_system_role", comment: "AI system role")
                let summary = try await AIService.shared.sendChat(model: config.model, apiKey: config.apiKey, systemPrompt: systemRole, userPrompt: prompt)
                let normalizedSummary = normalizeAISummary(summary)
                await MainActor.run {
                    aiSummary = normalizedSummary
                    store.updateAISummary(normalizedSummary, for: game.id)
                    isGeneratingAISummary = false
                }
            } catch {
                await MainActor.run {
                    aiSummaryError = (error as? LocalizedError)?.errorDescription ?? NSLocalizedString("alert_ai_generate_failed", comment: "AI generate failed")
                    isGeneratingAISummary = false
                }
            }
        }
    }

    private func summaryPrompt() -> String {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let numericFacts = numericFactsText()

        let playerLines = allPlayerIDsForSummary().map { playerID in
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            let sideKey = game.homePlayerIDs.contains(playerID) ? "ai_prompt_side_home" : "ai_prompt_side_away"
            let side = NSLocalizedString(sideKey, comment: "Side")
            let roleUnmarked = NSLocalizedString("ai_prompt_role_unmarked", comment: "Unmarked role")
            let role = game.role(of: playerID)?.title ?? roleUnmarked
            let plusMinus = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
            let plusMinusText = plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
            let minutes = GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
            let playerUnknown = NSLocalizedString("unknown_player", comment: "Unknown player")
            let name = game.playerNamesByID[playerID] ?? playerUnknown

            let format = NSLocalizedString("ai_prompt_player_line_format", comment: "Player line format")
            return String(format: format, side, name, role, minutes, stats.points, stats.rebounds, stats.assists, stats.fouls, stats.blocks, stats.steals, stats.turnovers, stats.made, stats.attempts, stats.threeMade, stats.threeAttempts, stats.allFreeThrowMade, stats.allFreeThrowAttempts, plusMinusText)
        }

        let noPlayerDataKey = "ai_prompt_no_player_data"
        let playersText = playerLines.isEmpty ? NSLocalizedString(noPlayerDataKey, comment: "No player data") : playerLines.joined(separator: "\n")

        let taskDesc = NSLocalizedString("ai_prompt_task_description", comment: "Task description")
        let summaryTitle = NSLocalizedString("ai_prompt_section_summary", comment: "Summary title")
        let summaryDesc = NSLocalizedString("ai_prompt_section_summary_desc", comment: "Summary desc")
        let mvpTitle = NSLocalizedString("ai_prompt_section_mvp", comment: "MVP title")
        let mvpDesc = NSLocalizedString("ai_prompt_section_mvp_desc", comment: "MVP desc")
        let highlightsTitle = NSLocalizedString("ai_prompt_section_highlights", comment: "Highlights title")
        let highlightsDesc = NSLocalizedString("ai_prompt_section_highlights_desc", comment: "Highlights desc")
        let extraReq = NSLocalizedString("ai_prompt_extra_requirements", comment: "Extra requirements")
        let req1 = NSLocalizedString("ai_prompt_req_1", comment: "Req 1")
        let req2 = NSLocalizedString("ai_prompt_req_2", comment: "Req 2")
        let req3 = NSLocalizedString("ai_prompt_req_3", comment: "Req 3")
        let req4 = NSLocalizedString("ai_prompt_req_4", comment: "Req 4")
        let req5 = NSLocalizedString("ai_prompt_req_5", comment: "Req 5")
        let req6 = NSLocalizedString("ai_prompt_req_6", comment: "Req 6")
        let req7 = NSLocalizedString("ai_prompt_req_7", comment: "Req 7")
        let req8 = NSLocalizedString("ai_prompt_req_8", comment: "Req 8")
        let req9 = NSLocalizedString("ai_prompt_req_9", comment: "Req 9")
        let req10 = NSLocalizedString("ai_prompt_req_10", comment: "Req 10")
        let req11 = NSLocalizedString("ai_prompt_req_11", comment: "Req 11")
        let req12 = NSLocalizedString("ai_prompt_req_12", comment: "Req 12")
        let req13 = NSLocalizedString("ai_prompt_req_13", comment: "Req 13")

        let gameInfoLabel = NSLocalizedString("ai_prompt_game_info_label", comment: "Game info label")
        let dateLabel = NSLocalizedString("ai_prompt_date_label", comment: "Date label")
        let matchupLabel = NSLocalizedString("ai_prompt_matchup_label", comment: "Matchup label")
        let scoreLabel = NSLocalizedString("ai_prompt_score_label", comment: "Score label")
        let periodsLabel = NSLocalizedString("ai_prompt_periods_label", comment: "Periods label")
        let playersLabel = NSLocalizedString("ai_prompt_players_label", comment: "Players label")
        let numericFactsLabel = NSLocalizedString("ai_prompt_numeric_facts_label", comment: "Numeric facts label")

        let dateStr = Self.aiPromptDateFormatter.string(from: game.savedAt)
        let matchupStr = String(format: matchupLabel, game.homeTeamName, game.awayTeamName)
        let scoreStr = String(format: scoreLabel, game.homeTeamName, homeScore, awayScore, game.awayTeamName)
        let periodsStr = String(format: periodsLabel, game.snapshot.periodCount)
        let dateFormatted = String(format: dateLabel, dateStr)

        return """
        \(taskDesc)

        ### \(summaryTitle)
        \(summaryDesc)

        ### \(mvpTitle)
        \(mvpDesc)

        ### \(highlightsTitle)
        \(highlightsDesc)

        \(extraReq)
        \(req1)
        \(req2)
        \(req3)
        \(req4)
        \(req5)
        \(req6)
        \(req7)
        \(req8)
        \(req9)
        \(req10)
        \(req11)
        \(req12)
        \(req13)
        - Expand the game summary into a detailed, paragraph-by-paragraph analysis of each period's key plays, momentum shifts, and player contributions.

        \(gameInfoLabel)
        \(dateFormatted)
        \(matchupStr)
        \(scoreStr)
        \(periodsStr)

        \(playersLabel)
        \(playersText)

        \(numericFactsLabel)
        \(numericFacts)
        """
    }

    private func normalizeAISummary(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = stripOuterCodeFenceIfNeeded(text)

        if text.contains("\\n") {
            text = text.replacingOccurrences(of: "\\n", with: "\n")
        }
        if text.contains("\\t") {
            text = text.replacingOccurrences(of: "\\t", with: "\t")
        }

        var normalizedLines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("###") {
                if normalizedLines.last?.isEmpty == false {
                    normalizedLines.append("")
                }
                normalizedLines.append(trimmed)
                normalizedLines.append("")
                continue
            }

            if trimmed.hasPrefix("• ") {
                normalizedLines.append("- " + String(trimmed.dropFirst(2)))
                continue
            }

            normalizedLines.append(line)
        }

        let normalized = normalizedLines.joined(separator: "\n")
        return collapseExtraBlankLines(normalized)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripOuterCodeFenceIfNeeded(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") && trimmed.hasSuffix("```") else {
            return trimmed
        }

        var lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2 else { return trimmed }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collapseExtraBlankLines(_ text: String) -> String {
        let pattern = "\\n{3,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\n\n")
    }

    private func parseAISummarySections(from text: String) -> [AISummarySection] {
        guard !text.isEmpty else { return [] }

        var sections: [AISummarySection] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushCurrent() {
            let items = summaryItems(from: currentLines)
            guard !items.isEmpty else {
                currentLines.removeAll()
                return
            }
            sections.append(AISummarySection(title: currentTitle ?? "比赛总结", items: items))
            currentLines.removeAll()
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("###") {
                flushCurrent()
                currentTitle = line
                    .replacingOccurrences(of: "###", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentTitle = stripMarkdownDecorations(from: currentTitle ?? "")
                continue
            }

            if !line.isEmpty || !currentLines.isEmpty {
                currentLines.append(line)
            }
        }

        flushCurrent()

        if sections.isEmpty {
            let fallbackItems = summaryItems(from: text.components(separatedBy: "\n"))
            if !fallbackItems.isEmpty {
                sections = [AISummarySection(title: "比赛总结", items: fallbackItems)]
            }
        }

        return sections
    }

    private func summaryItems(from lines: [String]) -> [String] {
        var items: [String] = []
        var paragraph: [String] = []

        func flushParagraph() {
            let content = paragraph
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                items.append(stripMarkdownDecorations(from: content))
            }
            paragraph.removeAll()
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let bullet = summaryBulletText(from: line) {
                flushParagraph()
                items.append(stripMarkdownDecorations(from: bullet))
                continue
            }

            paragraph.append(line)
        }

        flushParagraph()
        return items
    }

    private func summaryBulletText(from line: String) -> String? {
        if line.hasPrefix("- ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if line.hasPrefix("• ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let range = line.range(of: #"^\d+[\.、]\s*"#, options: .regularExpression) {
            let content = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        }

        return nil
    }

    private func stripMarkdownDecorations(from text: String) -> String {
        var cleaned = text

        cleaned = replacing(#"(?m)^\s*#{1,6}\s*"#, in: cleaned, with: "")
        cleaned = replacing(#"(?m)^\s*>+\s*"#, in: cleaned, with: "")
        cleaned = replacing(#"!\[[^\]]*\]\([^\)]*\)"#, in: cleaned, with: "")
        cleaned = replacing(#"\[([^\]]+)\]\([^\)]*\)"#, in: cleaned, with: "$1")
        cleaned = replacing(#"`([^`]+)`"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\*\*([^*]+)\*\*"#, in: cleaned, with: "$1")
        cleaned = replacing(#"__([^_]+)__"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\*([^*]+)\*"#, in: cleaned, with: "$1")
        cleaned = replacing(#"_([^_]+)_"#, in: cleaned, with: "$1")
        cleaned = replacing(#"~~([^~]+)~~"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\"([^\"]+)\""#, in: cleaned, with: "$1")
        cleaned = replacing(#"[""]"#, in: cleaned, with: "")
        cleaned = replacing(#"[‘’]"#, in: cleaned, with: "")
        cleaned = replacing(#"(?<![A-Za-z])'([^']+)'(?![A-Za-z])"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\\([\*_`~\[\]\(\)])"#, in: cleaned, with: "$1")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isMVPSection(_ title: String) -> Bool {
        title.localizedCaseInsensitiveContains("mvp")
    }

    private func mvpPlayerID(in text: String) -> UUID? {
        let normalized = stripMarkdownDecorations(from: text)
        let candidates = game.playerNamesByID
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }

        return candidates.first(where: { normalized.contains($0.name) })?.id
    }

    private func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private func iconForSummarySection(_ title: String) -> String {
        if title.localizedCaseInsensitiveContains("mvp") {
            return "trophy.fill"
        }
        if title.contains("高亮") {
            return "sparkles"
        }
        if title.contains("总结") {
            return "text.quote"
        }
        return "doc.text"
    }

    private func iconForSummaryItem(sectionTitle: String, item: String, index: Int) -> String {
        if sectionTitle.localizedCaseInsensitiveContains("mvp") {
            return "person.crop.circle.badge.checkmark"
        }
        if sectionTitle.contains("高亮") {
            return "bolt.fill"
        }
        if item.contains("关键") {
            return "flag.fill"
        }
        if item.contains("比分") {
            return "chart.line.uptrend.xyaxis"
        }
        return index == 0 ? "circle.fill" : "smallcircle.filled.circle"
    }

    private struct AISummarySection {
        var title: String
        var items: [String]
    }




    private func side(for playerID: UUID?) -> TeamSide? {
        guard let playerID else { return nil }
        if game.homePlayerIDs.contains(playerID) { return .home }
        if game.awayPlayerIDs.contains(playerID) { return .away }
        return nil
    }

    private func playerName(_ playerID: UUID?) -> String {
        guard let playerID else { return "未知球员" }
        return game.playerNamesByID[playerID] ?? store.player(for: playerID)?.name ?? "未知球员"
    }

    private func numericFactsText() -> String {
        let participantIDs = allPlayerIDsForSummary().filter { game.didParticipate($0) }
        guard !participantIDs.isEmpty else {
            return "- 未找到可用于校验的出场球员统计。"
        }

        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let scoreTotal = homeScore + awayScore
        let playerScoreTotal = participantIDs.reduce(0) { partial, playerID in
            partial + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }

        var lines: [String] = []
        lines.append("比分总分：\(homeScore)+\(awayScore)=\(scoreTotal)，出场球员得分汇总 \(playerScoreTotal)")

        lines.append(metricLine("得分最高", among: participantIDs, unit: "分") {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].points
        })
        lines.append(metricLine("得分最低（出场球员）", among: participantIDs, order: .ascending, unit: "分") {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].points
        })
        lines.append(metricLine("篮板最多", among: participantIDs, unit: "个", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].rebounds
        })
        lines.append(metricLine("助攻最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].assists
        })
        lines.append(metricLine("封盖最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].blocks
        })
        lines.append(metricLine("抢断最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].steals
        })
        lines.append(metricLine("失误最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].turnovers
        })
        lines.append(metricLine("正负值最高", among: participantIDs, unit: "") {
            game.snapshot.plusMinusByPlayerID[$0, default: 0]
        })
        lines.append(metricLine("正负值最低", among: participantIDs, order: .ascending, unit: "") {
            game.snapshot.plusMinusByPlayerID[$0, default: 0]
        })

        if let longest = leadingPlayers(
            among: participantIDs,
            metric: { Int(game.snapshot.playingSecondsByPlayerID[$0, default: 0].rounded(.down)) },
            order: .descending,
            requirePositive: true
        ) {
            let duration = GameView.durationFormatter(TimeInterval(longest.value))
            lines.append("出场时间最长：\(playersText(for: longest.playerIDs))（\(duration)）")
        } else {
            lines.append("出场时间最长：暂无有效记录")
        }

        return lines.map { "- \($0)" }.joined(separator: "\n")
    }

    private enum RankingOrder {
        case ascending
        case descending
    }

    private func metricLine(
        _ title: String,
        among playerIDs: [UUID],
        order: RankingOrder = .descending,
        unit: String,
        requirePositive: Bool = false,
        metric: (UUID) -> Int
    ) -> String {
        guard let leader = leadingPlayers(
            among: playerIDs,
            metric: metric,
            order: order,
            requirePositive: requirePositive
        ) else {
            return "\(title)：暂无有效记录"
        }

        let valueText = unit.isEmpty
            ? signedNumberText(leader.value)
            : "\(leader.value)\(unit)"
        return "\(title)：\(playersText(for: leader.playerIDs))（\(valueText)）"
    }

    private func leadingPlayers(
        among playerIDs: [UUID],
        metric: (UUID) -> Int,
        order: RankingOrder,
        requirePositive: Bool
    ) -> (playerIDs: [UUID], value: Int)? {
        var pairs = playerIDs.map { ($0, metric($0)) }
        if requirePositive {
            pairs = pairs.filter { $0.1 > 0 }
        }

        guard !pairs.isEmpty else { return nil }

        let targetValue = order == .descending
            ? pairs.map { $0.1 }.max()
            : pairs.map { $0.1 }.min()

        guard let targetValue else { return nil }

        let leaders = pairs
            .filter { $0.1 == targetValue }
            .map { $0.0 }
            .sorted { playerName($0) < playerName($1) }

        return (leaders, targetValue)
    }

    private func playersText(for playerIDs: [UUID], maxCount: Int = 3) -> String {
        let names = playerIDs.map(playerName).sorted()
        guard names.count > maxCount else {
            return names.joined(separator: " / ")
        }

        let shown = names.prefix(maxCount).joined(separator: " / ")
        return "\(shown) 等\(names.count)人"
    }

    private func signedNumberText(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func allPlayerIDsForSummary() -> [UUID] {
        let allIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
        return allIDs.sorted { lhs, rhs in
            let lhsPoints = game.snapshot.statsByPlayerID[lhs, default: PlayerStats()].points
            let rhsPoints = game.snapshot.statsByPlayerID[rhs, default: PlayerStats()].points
            if lhsPoints != rhsPoints { return lhsPoints > rhsPoints }
            return (game.playerNamesByID[lhs] ?? "") < (game.playerNamesByID[rhs] ?? "")
        }
    }

    private static let aiPromptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    @ViewBuilder
    private func playerAvatar(for playerID: UUID) -> some View {
        if let player = store.player(for: playerID) {
            PlayerAvatarView(player: player, size: 36)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String((game.playerNamesByID[playerID] ?? "?").prefix(2)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }

    @ViewBuilder
    private func mvpPlayerAvatar(for playerID: UUID) -> some View {
        if let player = store.player(for: playerID) {
            PlayerAvatarView(player: player, size: 24)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(String((game.playerNamesByID[playerID] ?? "?").prefix(2)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }
}

private struct ExportGameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager
    @Environment(\.dismiss) private var dismiss
    var game: SavedGame

    @State private var base64 = ""
    @State private var transferID = GameShareChunkCodec.generateTransferID()
    @State private var segmentCount = 4
    @State private var chunkLines: [String] = []
    @State private var isGenerating = true
    @State private var copiedChunkIndex: Int?
    @State private var copiedChunkFeedbackTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(LocalizedStringKey("transfer_generating_compressed"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if base64.isEmpty {
                    Section {
                        Text(LocalizedStringKey("transfer_generate_failed_retry"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(LocalizedStringKey("section_bluetooth_transfer")) {
                        if bluetooth.connectedPeers.isEmpty {
                            Text(LocalizedStringKey("transfer_no_connected_devices_hint"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            NavigationLink {
                                BluetoothStoreSyncComposerView(preset: .game(game.id))
                                    .environmentObject(store)
                                    .environmentObject(bluetooth)
                            } label: {
                                Label(LocalizedStringKey("transfer_send_current_game_bluetooth"), systemImage: "dot.radiowaves.left.and.right")
                            }

                            Text(LocalizedStringKey("transfer_open_to_pick_device_progress_hint"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(LocalizedStringKey("section_export_settings")) {
                        Stepper(value: $segmentCount, in: 1...8) {
                            HStack {
                                Text(LocalizedStringKey("label_segment_count"))
                                Spacer(minLength: 8)
                                Text(String(format: NSLocalizedString("segment_count_value_format", comment: "Segment count value"), segmentCount))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(String(format: NSLocalizedString("transfer_total_segments_hint_format", comment: "Total segments hint"), chunkLines.count))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section(LocalizedStringKey("section_game_share_code")) {
                        ForEach(Array(chunkLines.enumerated()), id: \.offset) { index, line in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: NSLocalizedString("segment_progress_format", comment: "Segment progress"), index + 1, chunkLines.count))
                                    .font(.subheadline.weight(.semibold))

                                TransferCodePreview(text: line)

                                Button {
                                    UIPasteboard.general.string = line
                                    showChunkCopyFeedback(index)
                                } label: {
                                    Label(
                                        copiedChunkIndex == index ? NSLocalizedString("status_copied", comment: "Copied") : String(format: NSLocalizedString("button_copy_segment_format", comment: "Copy segment"), index + 1),
                                        systemImage: copiedChunkIndex == index ? "checkmark.circle.fill" : "doc.on.doc"
                                    )
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(AppSoftProminentButtonStyle())
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section {
                        ShareLink(item: chunkLines.joined(separator: "\n")) {
                            Label(LocalizedStringKey("button_share_all_segments"), systemImage: TransferSymbol.exportData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("nav_export_game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .task(id: game.id) {
                await generateBase64()
            }
            .onChange(of: segmentCount) { _, _ in
                rebuildChunkLines()
            }
            .onDisappear {
                copiedChunkFeedbackTask?.cancel()
            }
        }
    }

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        chunkLines = []
        transferID = GameShareChunkCodec.generateTransferID()
        await Task.yield()
        base64 = store.exportGameBase64(game) ?? ""
        rebuildChunkLines()
        isGenerating = false
    }

    private func rebuildChunkLines() {
        chunkLines = GameShareChunkCodec.makeChunkLines(
            payload: base64,
            preferredParts: segmentCount,
            transferID: transferID
        )
    }

    private func showChunkCopyFeedback(_ index: Int) {
        copiedChunkIndex = index
        copiedChunkFeedbackTask?.cancel()
        copiedChunkFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            copiedChunkIndex = nil
        }
    }
}

private struct ImportGameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var base64 = ""
    @State private var isChunkedMode = false
    @State private var chunkInputLines: [String] = []
    @State private var chunkTransferID: String?
    @State private var chunkTotalParts = 0
    @State private var package: ExportedGamePackage?
    @State private var playerMapping: [UUID: UUID] = [:]
    @State private var teamMapping: [UUID: UUID] = [:]
    @State private var parseResultText: String?
    @State private var parseSucceeded = false
    @State private var isShowingMissingRosterAlert = false
    @State private var isShowingClipboardAutoFillAlert = false
    @State private var clipboardAutoFillMessage = ""
    @State private var lastAutoFilledClipboardChangeCount = -1
    @State private var isShowingImportOverwriteAlert = false
    @State private var pendingImportDisposition: AppStore.GameImportDisposition?
    @State private var isShowingChunkReplaceAlert = false
    @State private var pendingIncomingChunks: [GameShareChunk] = []
    @State private var pendingIncomingPartCount = 0
    @State private var hasCheckedClipboard = false
    @State private var isParsing = false
    @FocusState private var isInputFocused: Bool

    private var filledChunkCount: Int {
        chunkInputLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    private var canParseInput: Bool {
        if isChunkedMode {
            return chunkTotalParts > 0 && filledChunkCount == chunkTotalParts
        }
        return !base64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_paste_share_code")) {
                    if isChunkedMode {
                        Text(String(format: NSLocalizedString("import_chunk_detected_progress_format", comment: "Chunk detected progress"), filledChunkCount, chunkTotalParts))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let chunkTransferID {
                            Text(String(format: NSLocalizedString("import_batch_id_format", comment: "Batch ID"), chunkTransferID))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        ForEach(0..<chunkTotalParts, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: NSLocalizedString("segment_progress_format", comment: "Segment progress"), index + 1, chunkTotalParts))
                                    .font(.caption.weight(.semibold))

                                TransferCodeInput(
                                    text: binding(forChunkIndex: index),
                                    placeholder: String(format: NSLocalizedString("placeholder_paste_segment_format", comment: "Paste segment placeholder"), index + 1)
                                )
                                    .focused($isInputFocused)
                            }
                            .padding(.vertical, 2)
                        }

                        HStack(spacing: 8) {
                            Button(LocalizedStringKey("button_read_segments_from_clipboard")) {
                                tryAutoFillFromClipboard(force: true)
                            }
                            .buttonStyle(AppSoftProminentButtonStyle())

                            Button(LocalizedStringKey("button_switch_single_import")) {
                                resetToSingleMode()
                            }
                            .buttonStyle(AppSoftProminentButtonStyle())
                        }
                    } else {
                        TransferCodeInput(text: $base64)
                            .focused($isInputFocused)
                    }

                    Button(LocalizedStringKey("button_parse_game_record")) {
                        isInputFocused = false
                        Task {
                            await decode()
                        }
                    }
                    .disabled(!canParseInput || isParsing)

                    if isParsing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(LocalizedStringKey("status_parsing"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parseResultText {
                    Section(LocalizedStringKey("section_parse_result")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(parseResultText)
                                .font(.footnote.monospaced())
                                .foregroundStyle(parseSucceeded ? Color.primary : Color.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                if let package {
                    Section(LocalizedStringKey("section_team_match")) {
                        ForEach(package.teams) { team in
                            Picker(team.name, selection: binding(forTeam: team.id)) {
                                Text(LocalizedStringKey("import_as_new_team")).tag(UUID?.none)
                                ForEach(store.teams) { localTeam in
                                    Text(localTeam.name).tag(Optional(localTeam.id))
                                }
                            }
                        }
                    }

                    Section(LocalizedStringKey("section_player_match")) {
                        ForEach(package.players) { player in
                            Picker(player.name, selection: binding(forPlayer: player.id)) {
                                Text(LocalizedStringKey("import_as_new_player")).tag(UUID?.none)
                                ForEach(store.players) { localPlayer in
                                    Text(localPlayer.name).tag(Optional(localPlayer.id))
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            triggerImport()
                        } label: {
                            Label(LocalizedStringKey("button_import_game"), systemImage: TransferSymbol.importData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppNeutralProminentButtonStyle())
                    }
                }

            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(LocalizedStringKey("nav_import_game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
            }
            .alert(LocalizedStringKey("alert_missing_roster_title"), isPresented: $isShowingMissingRosterAlert) {
                Button(LocalizedStringKey("button_continue_matching")) { }
            } message: {
                Text(LocalizedStringKey("alert_missing_roster_message"))
            }
            .alert(LocalizedStringKey("alert_auto_detected_title"), isPresented: $isShowingClipboardAutoFillAlert) {
                Button(LocalizedStringKey("button_got_it")) { }
            } message: {
                Text(clipboardAutoFillMessage)
            }
            .alert(LocalizedStringKey("alert_overwrite_game_title"), isPresented: $isShowingImportOverwriteAlert) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) { }
                Button(LocalizedStringKey("button_overwrite_import"), role: .destructive) {
                    performImportAndDismiss()
                }
            } message: {
                Text(overwriteImportMessage)
            }
            .alert(LocalizedStringKey("alert_new_chunk_title"), isPresented: $isShowingChunkReplaceAlert) {
                Button(LocalizedStringKey("button_cancel"), role: .cancel) {
                    pendingIncomingChunks = []
                    pendingIncomingPartCount = 0
                }
                Button(LocalizedStringKey("button_continue_import"), role: .destructive) {
                    replaceWithPendingIncomingChunks()
                }
            } message: {
                Text(chunkReplaceMessage)
            }
            .onAppear {
                guard !hasCheckedClipboard else { return }
                hasCheckedClipboard = true
                tryAutoFillFromClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
                tryAutoFillFromClipboard()
            }
        }
    }

    private var chunkReplaceMessage: String {
        String(format: NSLocalizedString("alert_new_chunk_message_format", comment: "New chunk message"), filledChunkCount, chunkTotalParts, pendingIncomingPartCount)
    }

    private var overwriteImportMessage: String {
        switch pendingImportDisposition {
        case .replacedSameID:
            return NSLocalizedString("alert_overwrite_same_uuid", comment: "Overwrite same UUID")
        case .replacedLikelyDuplicate:
            return NSLocalizedString("alert_overwrite_duplicate", comment: "Overwrite duplicate")
        case .inserted, .none:
            return NSLocalizedString("alert_overwrite_any", comment: "Overwrite any")
        }
    }

    private func decode() async {
        isParsing = true
        package = nil
        parseSucceeded = false
        parseResultText = nil
        await Task.yield()
        defer { isParsing = false }

        let sourceText: String
        if isChunkedMode {
            switch GameShareChunkCodec.assemblePayload(from: chunkInputLines) {
            case .success(let assembled):
                sourceText = assembled.payload
            case .failure(let message):
                package = nil
                parseSucceeded = false
                parseResultText = String(format: NSLocalizedString("parse_result_failed_chunk_format", comment: "Parse failed chunk"), message)
                return
            }
        } else {
            let trimmedInput = base64.trimmingCharacters(in: .whitespacesAndNewlines)
            let chunkCandidates = GameShareChunkCodec.parseChunks(in: trimmedInput)
            if !chunkCandidates.isEmpty {
                applyChunks(chunkCandidates)
                parseResultText = NSLocalizedString("parse_result_incomplete_chunks", comment: "Incomplete chunks")
                return
            }
            if let singleChunk = GameShareChunkCodec.parseChunkLine(trimmedInput) {
                applyChunks([singleChunk])
                parseResultText = NSLocalizedString("parse_result_incomplete_chunks", comment: "Incomplete chunks")
                return
            }
            sourceText = trimmedInput
        }

        guard let decoded = store.decodeGamePackage(from: sourceText) else {
            package = nil
            parseSucceeded = false
            parseResultText = NSLocalizedString("parse_result_failed_game", comment: "Parse failed game")
            return
        }
        applyDecodedPackage(decoded)
    }

    private func tryAutoFillFromClipboard(force: Bool = false) {
        let pasteboard = UIPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard force || currentChangeCount != lastAutoFilledClipboardChangeCount else {
            return
        }

        guard let clipboardText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            return
        }

        let chunks = GameShareChunkCodec.parseChunks(in: clipboardText)
        if !chunks.isEmpty,
           let selectedChunks = selectTargetChunks(from: chunks) {
            if shouldConfirmChunkReplacement(for: selectedChunks) {
                pendingIncomingChunks = selectedChunks
                pendingIncomingPartCount = selectedChunks.first?.totalParts ?? 0
                isShowingChunkReplaceAlert = true
                lastAutoFilledClipboardChangeCount = currentChangeCount
                return
            }

            applyChunks(selectedChunks)
            lastAutoFilledClipboardChangeCount = currentChangeCount
            return
        }

        if let chunk = GameShareChunkCodec.parseChunkLine(clipboardText),
           let selectedChunks = selectTargetChunks(from: [chunk]) {
            if shouldConfirmChunkReplacement(for: selectedChunks) {
                pendingIncomingChunks = selectedChunks
                pendingIncomingPartCount = selectedChunks.first?.totalParts ?? 0
                isShowingChunkReplaceAlert = true
                lastAutoFilledClipboardChangeCount = currentChangeCount
                return
            }

            applyChunks(selectedChunks)
            lastAutoFilledClipboardChangeCount = currentChangeCount
            return
        }

        guard let decoded = store.decodeGamePackage(from: clipboardText) else {
            return
        }

        isChunkedMode = false
        base64 = clipboardText
        applyDecodedPackage(decoded)
        lastAutoFilledClipboardChangeCount = currentChangeCount
        clipboardAutoFillMessage = NSLocalizedString("text_clipboard_recognized_game", comment: "Clipboard recognized game")
        isShowingClipboardAutoFillAlert = true
    }

    private func replaceWithPendingIncomingChunks() {
        guard !pendingIncomingChunks.isEmpty else { return }
        resetToSingleMode()
        applyChunks(pendingIncomingChunks)
        pendingIncomingChunks = []
        pendingIncomingPartCount = 0
    }

    private func shouldConfirmChunkReplacement(for incomingChunks: [GameShareChunk]) -> Bool {
        guard isChunkedMode,
              filledChunkCount > 0,
              let currentTransferID = chunkTransferID,
              let incomingSample = incomingChunks.first else {
            return false
        }

        let isSameTransfer = currentTransferID == incomingSample.transferID
        let isSamePartCount = chunkTotalParts == incomingSample.totalParts
        return !(isSameTransfer && isSamePartCount)
    }

    private func selectTargetChunks(from chunks: [GameShareChunk]) -> [GameShareChunk]? {
        guard !chunks.isEmpty else { return nil }

        let groupedByID = Dictionary(grouping: chunks, by: { $0.transferID })

        if let chunkTransferID,
           let sameBatch = groupedByID[chunkTransferID],
           !sameBatch.isEmpty {
            return sameBatch
        }

        return groupedByID.values.max(by: { $0.count < $1.count })
    }

    private func applyChunks(_ targetChunks: [GameShareChunk]) {
        guard let sample = targetChunks.first else { return }
        let previousTransferID = chunkTransferID

        isChunkedMode = true
        chunkTransferID = sample.transferID
        chunkTotalParts = sample.totalParts

        if chunkInputLines.count != sample.totalParts || previousTransferID != sample.transferID {
            chunkInputLines = Array(repeating: "", count: sample.totalParts)
        }

        for chunk in targetChunks where chunk.partIndex <= sample.totalParts {
            chunkInputLines[chunk.partIndex - 1] = chunk.rawLine
        }

        parseSucceeded = false
        parseResultText = nil
        package = nil

        clipboardAutoFillMessage = String(format: NSLocalizedString("import_clipboard_chunk_autofill_format", comment: "Clipboard chunk autofill"), "Game", filledChunkCount, chunkTotalParts)
        isShowingClipboardAutoFillAlert = true
    }

    private func resetToSingleMode() {
        isChunkedMode = false
        chunkInputLines = []
        chunkTransferID = nil
        chunkTotalParts = 0
        parseSucceeded = false
        parseResultText = nil
        package = nil
    }

    private func binding(forChunkIndex index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < chunkInputLines.count else { return "" }
                return chunkInputLines[index]
            },
            set: { newValue in
                guard index < chunkInputLines.count else { return }
                chunkInputLines[index] = newValue
            }
        )
    }

    private func applyDecodedPackage(_ decoded: ExportedGamePackage) {
        package = decoded
        playerMapping = [:]
        teamMapping = [:]
        for player in decoded.players {
            if store.players.contains(where: { $0.id == player.id }) {
                playerMapping[player.id] = player.id
            }
        }
        for team in decoded.teams {
            if store.teams.contains(where: { $0.id == team.id }) {
                teamMapping[team.id] = team.id
            }
        }
        parseSucceeded = true
        parseResultText = String(format: NSLocalizedString("parse_result_success_format", comment: "Parse success"), decoded.teams.count, decoded.players.count)
        isShowingMissingRosterAlert = decoded.players.contains { playerMapping[$0.id] == nil } || decoded.teams.contains { teamMapping[$0.id] == nil }
    }

    private func triggerImport() {
        guard let package else { return }

        let disposition = store.previewGameImportDisposition(
            package,
            playerMapping: playerMapping,
            teamMapping: teamMapping
        )

        if disposition.isOverwrite {
            pendingImportDisposition = disposition
            isShowingImportOverwriteAlert = true
            return
        }

        performImportAndDismiss()
    }

    private func performImportAndDismiss() {
        guard let package else { return }
        _ = store.importGamePackage(package, playerMapping: playerMapping, teamMapping: teamMapping)
        dismiss()
    }

    private func binding(forPlayer id: UUID) -> Binding<UUID?> {
        Binding(
            get: { playerMapping[id] },
            set: { playerMapping[id] = $0 }
        )
    }

    private func binding(forTeam id: UUID) -> Binding<UUID?> {
        Binding(
            get: { teamMapping[id] },
            set: { teamMapping[id] = $0 }
        )
    }
}

private struct PlayerGameDetailView: View {
    var game: SavedGame
    var playerID: UUID
    @State private var selectedPeriod: Int? = nil
    @State private var periodAnalysis = SavedGamePeriodAnalysis()

    private var displayStats: PlayerStats {
        guard let selectedPeriod else {
            return game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
        }
        return periodAnalysis.statsByPeriod[selectedPeriod]?[playerID] ?? PlayerStats()
    }

    private var displayLogs: [PeriodAwareLog] {
        periodAnalysis.playerLogs(for: playerID, period: selectedPeriod)
    }

    var body: some View {
        List {
            if game.snapshot.periodCount > 1 {
                Section(LocalizedStringKey("section_data_range")) {
                    Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                        Text(LocalizedStringKey("data_range_full")).tag(Optional<Int>.none)
                        ForEach(1...game.snapshot.periodCount, id: \.self) { period in
                            Text(String(format: NSLocalizedString("data_range_period", comment: "Data range period"), period)).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                HStack {
                    Text(playerName)
                        .font(.headline)
                    Spacer()
                    Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), displayStats.points))
                        .font(.title2.monospacedDigit().weight(.bold))
                }
                statLine("stat_label_role", roleText)
                statLine("stat_label_playing_time_value", playingTimeText)
            }

            Section(LocalizedStringKey("stats_field_goal")) {
                statLine("stats_field_goal", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.made, displayStats.attempts))
                statLine("stat_label_fg_rate", percent(displayStats.fieldGoalRate))
                statLine("stat_label_2pt", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.twoMade, displayStats.twoAttempts))
                statLine("stat_label_2pt_rate", percent(displayStats.twoPointRate))
                statLine("stat_label_3pt", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.threeMade, displayStats.threeAttempts))
                statLine("stat_label_3pt_rate", percent(displayStats.threePointRate))
            }

            Section(LocalizedStringKey("stats_free_throw")) {
                statLine("stats_free_throw", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.allFreeThrowMade, displayStats.allFreeThrowAttempts))
                statLine("stat_label_fg_rate", percent(displayStats.freeThrowRate))
                statLine("stat_label_bonus", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.bonusFreeThrowMade, displayStats.bonusFreeThrowAttempts))
            }

            Section(LocalizedStringKey("section_other_stats")) {
                statLine("stat_label_full_misc", String(format: NSLocalizedString("stat_format_full_misc", comment: "Full misc format"), displayStats.rebounds, displayStats.assists, displayStats.fouls, displayStats.blocks, displayStats.steals, displayStats.turnovers))
            }

            Section(LocalizedStringKey("section_advanced_stats")) {
                statLine("stats_plus_minus", plusMinusText)
                statLine("stat_label_efg_ts", "\(percent(displayStats.effectiveFieldGoalRate)) / \(percent(displayStats.trueShootingRate))")
                statLine("stats_points_per_shot", String(format: "%.2f", displayStats.pointsPerShot))
            }

        }
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: rebuildPeriodAnalysis)
    }

    private var playerName: String {
        game.playerNamesByID[playerID] ?? NSLocalizedString("unknown_player", comment: "Unknown player")
    }

    private func statLine(_ titleKey: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(titleKey))
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var playingTimeText: String {
        guard selectedPeriod == nil else { return "--:--" }
        return GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
    }

    private var plusMinusText: String {
        guard selectedPeriod == nil else { return "--" }
        let value = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private var roleText: String {
        game.role(of: playerID)?.title ?? NSLocalizedString("unrecorded_role", comment: "Unrecorded role")
    }

    private func rebuildPeriodAnalysis() {
        let analyzer = SavedGameAnalyzer(game: game) { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        }
        periodAnalysis = analyzer.analyze()
    }
}
