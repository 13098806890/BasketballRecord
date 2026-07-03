import SwiftUI

struct ExportPlayerPackageView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager
    @Environment(\.dismiss) private var dismiss
    var player: Player
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
    @AppStorage("cloudshare_player_include_photos") private var includePhotos = true

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("label_player")) {
                    Text(player.name)
                }

                Picker("", selection: $shareMode) {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label")).tag(ExportShareMode.cloud)
                    Text(LocalizedStringKey("cloudshare_picker_text_label")).tag(ExportShareMode.text)
                }
                .pickerStyle(.segmented)

                if shareMode == .cloud {
                    CloudShareSection(
                        persistenceKey: "cloud_share_player_\(player.id.uuidString)",
                        uploadProgress: $uploadProgress,
                        uploadPhase: $uploadPhase,
                        uploadAction: { try await performPlayerCloudUpload() })
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
                                BluetoothStoreSyncComposerView(preset: .player(player.id))
                                    .environmentObject(store)
                                    .environmentObject(bluetooth)
                            } label: {
                                Label(LocalizedStringKey("transfer_send_current_player_bluetooth"), systemImage: "dot.radiowaves.left.and.right")
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

                    Section(LocalizedStringKey("section_player_share_code")) {
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
            .navigationTitle(LocalizedStringKey("nav_export_player"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .task(id: player.id) {
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

        let playerCopy = player

        let result = await Task.detached(priority: .background) {
            var ep = ExportPlayer(player: playerCopy)
            ep.photoData = nil
            let package = ExportedPlayerPackage(player: ep)
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
            keyword: GameShareChunkCodec.playerKeyword
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

    private func performPlayerCloudUpload() async throws -> String {
        uploadProgress = 0
        uploadPhase = NSLocalizedString("cloudshare_uploading_metadata", comment: "")

        let playerCopy = player

        let metadata = try await Task.detached(priority: .background) {
            var ep = ExportPlayer(player: playerCopy)
            ep.photoData = nil
            let bundle = CloudShareBundle(
                players: [ep],
                teams: [],
                games: []
            )
            return try JSONEncoder().encode(bundle)
        }.value

        let uuid = try await CloudShareManager.upload(data: metadata)

        if includePhotos, let photoData = playerCopy.photoData, !photoData.isEmpty {
            uploadPhase = NSLocalizedString("cloudshare_compressing_photos", comment: "")
            let compressed = await Task.detached(priority: .background) {
                Self.compressIfNeeded(photoData)
            }.value
            if let compressed = compressed {
                uploadPhase = String(format: NSLocalizedString("cloudshare_uploading_photos_format", comment: ""), 1, 1)
                uploadProgress = 0.5
                try await CloudShareManager.uploadPhoto(uuid: uuid, playerID: playerCopy.id, data: compressed)
                uploadProgress = 1
            }
        }

        return uuid
    }

    nonisolated private static func compressIfNeeded(_ data: Data) -> Data? {
        let maxSize = 200 * 1024
        guard data.count > maxSize else { return data }
        guard let image = UIImage(data: data) else { return data }
        guard let compressed = image.jpegData(compressionQuality: 0.6) else { return data }
        return compressed.count < data.count ? compressed : data
    }
}
