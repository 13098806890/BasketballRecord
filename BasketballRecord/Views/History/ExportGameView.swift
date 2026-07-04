import SwiftUI

struct ExportGameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager
    @Environment(\.dismiss) private var dismiss
    var game: SavedGame

    @State private var shareMode: ExportShareMode = .cloud
    @State private var base64 = ""
    @State private var transferID = GameShareChunkCodec.generateTransferID()
    @State private var segmentCount = 4
    @State private var chunkLines: [String] = []
    @State private var isGenerating = true
    @State private var copiedChunkIndex: Int?
    @State private var copiedChunkFeedbackTask: Task<Void, Never>?
    @State private var uploadProgress: Double = 0
    @State private var uploadPhase: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $shareMode) {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label")).tag(ExportShareMode.cloud)
                    Text(LocalizedStringKey("cloudshare_picker_text_label")).tag(ExportShareMode.text)
                }
                .pickerStyle(.segmented)

                if isGenerating && shareMode == .text {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(LocalizedStringKey("transfer_generating_compressed"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if shareMode == .text {
                    textShareContent
                } else {
                    CloudShareSection(
                        persistenceKey: "cloud_share_game_\(game.id.uuidString)",
                        uploadProgress: $uploadProgress,
                        uploadPhase: $uploadPhase,
                        uploadAction: { try await performGameCloudUpload() })
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
                transferID = GameShareChunkCodec.generateTransferID()
                if shareMode == .text {
                    await generateBase64()
                } else {
                    isGenerating = false
                }
            }
            .onChange(of: shareMode) { _, newMode in
                if newMode == .text && base64.isEmpty {
                    isGenerating = true
                    base64 = ""
                    chunkLines = []
                    transferID = GameShareChunkCodec.generateTransferID()
                    Task { await generateBase64() }
                }
            }
            .onChange(of: segmentCount) { _, _ in
                rebuildChunkLines()
            }
            .onDisappear {
                copiedChunkFeedbackTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private var textShareContent: some View {
        if base64.isEmpty {
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

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        chunkLines = []
        transferID = GameShareChunkCodec.generateTransferID()
        await Task.yield()

        let playerIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
        let allPlayers = playerIDs.compactMap { store.player(for: $0) }
        let gameCopy = game

        let result = await Task.detached(priority: .background) {
            let exportedPlayers: [ExportPlayer] = playerIDs.map { pid in
                if let player = allPlayers.first(where: { $0.id == pid }) {
                    var ep = ExportPlayer(player: player)
                    ep.photoData = nil
                    return ep
                }
                return ExportPlayer(id: pid, name: gameCopy.playerNamesByID[pid] ?? NSLocalizedString("player_unknown_default", comment: ""))
            }
            let exportedTeams = [
                ExportTeam(id: gameCopy.snapshot.homeTeamID ?? UUID(), name: gameCopy.homeTeamName, playerIDs: gameCopy.homePlayerIDs),
                ExportTeam(id: gameCopy.snapshot.awayTeamID ?? UUID(), name: gameCopy.awayTeamName, playerIDs: gameCopy.awayPlayerIDs)
            ]
            let legacyPackage = ExportedGamePackage(players: exportedPlayers, teams: exportedTeams, game: ExportGameRecord(savedGame: gameCopy))
            return TransferCodec.encode(ExportedGamePackageV2(legacy: legacyPackage))
        }.value

        base64 = result ?? ""
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

    private func performGameCloudUpload() async throws -> String {
        uploadProgress = 0
        uploadPhase = NSLocalizedString("cloudshare_uploading_metadata", comment: "")

        let playerIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
        let allPlayers = playerIDs.compactMap { store.player(for: $0) }
        let gameCopy = game

        let metadata = try await Task.detached(priority: .background) {
            let exportedPlayers: [ExportPlayer] = playerIDs.map { pid in
                if let player = allPlayers.first(where: { $0.id == pid }) {
                    var ep = ExportPlayer(player: player)
                    ep.photoData = nil
                    return ep
                }
                return ExportPlayer(id: pid, name: gameCopy.playerNamesByID[pid] ?? NSLocalizedString("player_unknown_default", comment: ""))
            }

            let exportedTeams = [
                ExportTeam(id: gameCopy.snapshot.homeTeamID ?? UUID(), name: gameCopy.homeTeamName, playerIDs: gameCopy.homePlayerIDs),
                ExportTeam(id: gameCopy.snapshot.awayTeamID ?? UUID(), name: gameCopy.awayTeamName, playerIDs: gameCopy.awayPlayerIDs)
            ]

            let legacyPackage = ExportedGamePackage(players: exportedPlayers, teams: exportedTeams, game: ExportGameRecord(savedGame: gameCopy))
            let bundle = CloudShareBundle(players: exportedPlayers, teams: exportedTeams, games: [ExportedGamePackageV2(legacy: legacyPackage)])
            return try JSONEncoder().encode(bundle)
        }.value

        let uuid = try await CloudShareManager.upload(data: metadata)
        uploadProgress = 1
        return uuid
    }
}
