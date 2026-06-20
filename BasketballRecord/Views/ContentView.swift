import SwiftUI
import UIKit

enum FilterDefaults {
    static let historyKey = "historyFilterGroupID"
    static let careerKey = "careerFilterGroupID"
    static let careerPlayerGroupKey = "careerPlayerGroupFilterID"

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
    @State private var selectedTab: Int = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            TeamManagementHomeView()
                .tabItem {
                    Label(LocalizedStringKey("tab_management"), systemImage: "folder.fill")
                }
                .tag(0)

            GameView()
                .tabItem {
                    Label(LocalizedStringKey("tab_score"), systemImage: "sportscourt")
                }
                .tag(1)

            CareerView()
                .tabItem {
                    Label(LocalizedStringKey("tab_career"), systemImage: "trophy")
                }
                .tag(2)

            RosterView()
                .tabItem {
                    Label(LocalizedStringKey("tab_settings"), systemImage: "gearshape")
                }
                .tag(3)
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
            if store.players.isEmpty && store.teams.isEmpty {
                selectedTab = 0
            }
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
                .stroke(Color(.separator).opacity(0.15), lineWidth: 1)
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
        return "\(title): \(ListFormatter.localizedString(byJoining: shown))\(suffix)"
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

enum CareerBoardKind: String, CaseIterable, Identifiable {
    case history = "nav_game_history"
    case team = "enum_team"
    case player = "enum_player"

    var id: String { rawValue }
}
