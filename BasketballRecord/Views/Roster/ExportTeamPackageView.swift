import SwiftUI

struct ExportTeamPackageView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager
    @Environment(\.dismiss) private var dismiss
    var team: Team
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
    @AppStorage("cloudshare_team_include_photos") private var includePhotos = true

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("label_team")) {
                    Text(team.name)
                }

                Picker("", selection: $shareMode) {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label")).tag(ExportShareMode.cloud)
                    Text(LocalizedStringKey("cloudshare_picker_text_label")).tag(ExportShareMode.text)
                }
                .pickerStyle(.segmented)

                if shareMode == .cloud {
                    CloudShareSection(
                        persistenceKey: "cloud_share_team_\(team.id.uuidString)",
                        uploadProgress: $uploadProgress,
                        uploadPhase: $uploadPhase,
                        uploadAction: { try await performTeamCloudUpload() })
                    Toggle(isOn: $includePhotos) {
                        Text(LocalizedStringKey("cloudshare_include_photos"))
                    }
                } else if isGenerating {
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
                                BluetoothStoreSyncComposerView(preset: .team(team.id))
                                    .environmentObject(store)
                                    .environmentObject(bluetooth)
                            } label: {
                                Label(LocalizedStringKey("transfer_send_current_team_bluetooth"), systemImage: "dot.radiowaves.left.and.right")
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
                                Text(localizedFormat("segment_count_value_format", segmentCount))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(LocalizedStringKey("export_segment_count_hint"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section(LocalizedStringKey("section_team_share_code")) {
                        ForEach(Array(chunkLines.enumerated()), id: \.offset) { index, line in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(localizedFormat("segment_progress_format", index + 1, chunkLines.count))
                                    .font(.subheadline.weight(.semibold))

                                TransferCodePreview(text: line)

                                Button {
                                    UIPasteboard.general.string = line
                                    showChunkCopyFeedback(index)
                                } label: {
                                    Label(
                                        copiedChunkIndex == index ? localized("status_copied") : localizedFormat("button_copy_segment_format", index + 1),
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
            .navigationTitle(LocalizedStringKey("nav_export_team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .task(id: team.id) {
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

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        chunkLines = []
        transferID = GameShareChunkCodec.generateTransferID()
        await Task.yield()

        let allPlayers = team.playerIDs.compactMap { store.player(for: $0) }
        let teamCopy = team

        let result = await Task.detached(priority: .background) {
            let exportedPlayers = teamCopy.playerIDs.map { pid in
                if let player = allPlayers.first(where: { $0.id == pid }) {
                    var ep = ExportPlayer(player: player)
                    ep.photoData = nil
                    return ep
                }
                return ExportPlayer(id: pid, name: NSLocalizedString("player_unknown_default", comment: "Unknown player"))
            }
            let package = ExportedTeamPackage(team: ExportTeam(team: teamCopy), players: exportedPlayers)
            return TransferCodec.encode(package)
        }.value

        base64 = result ?? ""
        rebuildChunkLines()
        isGenerating = false
    }

    private func rebuildChunkLines() {
        chunkLines = GameShareChunkCodec.makeChunkLines(
            payload: base64,
            preferredParts: segmentCount,
            transferID: transferID,
            keyword: GameShareChunkCodec.teamKeyword
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

    private func performTeamCloudUpload() async throws -> String {
        uploadProgress = 0
        uploadPhase = NSLocalizedString("cloudshare_uploading_metadata", comment: "")

        let teamPlayers = team.playerIDs.compactMap { store.player(for: $0) }
        let teamCopy = team

        let metadata = try await Task.detached(priority: .background) {
            let exportedPlayers = teamCopy.playerIDs.map { pid in
                if let player = teamPlayers.first(where: { $0.id == pid }) {
                    var ep = ExportPlayer(player: player)
                    ep.photoData = nil
                    return ep
                }
                return ExportPlayer(id: pid, name: NSLocalizedString("player_unknown_default", comment: "Unknown player"))
            }
            let bundle = CloudShareBundle(
                players: exportedPlayers,
                teams: [ExportTeam(team: teamCopy)],
                games: []
            )
            return try JSONEncoder().encode(bundle)
        }.value

        let uuid = try await CloudShareManager.upload(data: metadata)

        if includePhotos {
            uploadPhase = NSLocalizedString("cloudshare_compressing_photos", comment: "")
            let compressTask = Task(priority: .background) {
                var photoPlayers: [(UUID, String)] = []
                for pid in team.playerIDs {
                    if let player = store.player(for: pid)?.playerExportOptions {
                        photoPlayers.append((pid, player.photoBase64))
                    }
                }
                return photoPlayers
            }

            struct PhotoBundle: Codable {
                let uuid: String
                let photoPlayers: [(UUID, String)]

                enum CodingKeys: String, CodingKey {
                    case uuid, photoPlayers
                }

               func encode(to encoder: any Encoder) throws {
                   var container = encoder.container(keyedBy: CodingKeys.self)
                   try container.encode(uuid, forKey: .uuid)
                    try container.encode(photoPlayers.map { [$0.0.uuidString, $0.1] }, forKey: .photoPlayers)
               }

               init(uuid: String, photoPlayers: [(UUID, String)]) {
                   self.uuid = uuid
                   self.photoPlayers = photoPlayers
               }

               init(from decoder: any Decoder) throws {
                   let container = try decoder.container(keyedBy: CodingKeys.self)
                   uuid = try container.decode(String.self, forKey: .uuid)
                    let raw = try container.decode([[String]].self, forKey: .photoPlayers)
                    photoPlayers = raw.compactMap { arr in
                        guard arr.count >= 2, let id = UUID(uuidString: arr[0]) else { return nil }
                        return (id, arr[1])
                    }
               }
            }

            let photos = await compressTask.value
            if !photos.isEmpty {
                let photoBundle = PhotoBundle(uuid: uuid, photoPlayers: photos)
                uploadPhase = NSLocalizedString("cloudshare_uploading_photos", comment: "")
                let photoData = try JSONEncoder().encode(photoBundle)
                _ = try await CloudShareManager.upload(data: photoData)
            }
        }

        return uuid
    }
}
