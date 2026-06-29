import SwiftUI
import UIKit
import StoreKit
import WebKit

func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: localized(key), locale: Locale.current, arguments: args)
}

struct RosterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingRosterImport = false
    @State private var showingCloudUpload = false
    @State private var showingMergeEntry = false
    @State private var showingDeepSeekConfig = false
    @State private var showingSettingsDocument: SettingsDocument?
    @State private var isShowingPurchase = false

    @AppStorage(UnitSettings.heightUnitKey) private var heightRaw: String = ""
    @AppStorage(UnitSettings.weightUnitKey) private var weightRaw: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section(LocalizedStringKey("settings_section_game_prefs")) {
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max")
                            .font(.subheadline.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)

                        Text(LocalizedStringKey("settings_keep_screen_awake"))
                            .font(.body.weight(.medium))

                        Spacer()

                        Toggle("", isOn: $store.keepsScreenAwake)
                            .labelsHidden()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.subheadline.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)

                        Text(LocalizedStringKey("settings_show_bluetooth_button"))
                            .font(.body.weight(.medium))

                        Spacer()

                        Toggle("", isOn: $store.showsBluetoothGamesButton)
                            .labelsHidden()
                    }

                    NavigationLink {
                        VoiceSettingsView(store: store)
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_voice"),
                            systemImage: "waveform.circle.fill",
                            countText: nil
                        )
                    }

                    NavigationLink {
                        CloudStorageView()
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_cloud_storage"),
                            systemImage: "icloud.fill",
                            countText: "\(store.cloudEnabledGameIDs.count)"
                        )
                    }
                    .disabled(!store.isPro)
                    .overlay {
                        if !store.isPro {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingPurchase = true }
                        }
                }
                }

                Section(LocalizedStringKey("settings_section_units")) {
                    let heightBinding = Binding(
                        get: { HeightUnit(rawValue: heightRaw) ?? UnitSettings.defaultHeightUnit },
                        set: { heightRaw = $0.rawValue }
                    )
                    let weightBinding = Binding(
                        get: { WeightUnit(rawValue: weightRaw) ?? UnitSettings.defaultWeightUnit },
                        set: { weightRaw = $0.rawValue }
                    )

                    Picker(selection: heightBinding) {
                        ForEach(HeightUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    } label: {
                        Label(LocalizedStringKey("label_height"), systemImage: "ruler")
                            .foregroundStyle(.primary)
                    }

                    Picker(selection: weightBinding) {
                        ForEach(WeightUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    } label: {
                        Label(LocalizedStringKey("label_weight"), systemImage: "dumbbell.fill")
                            .foregroundStyle(.primary)
                    }
                }

                Section {
                    Button {
                        isShowingPurchase = true
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("section_pro"),
                            systemImage: "crown.fill",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(LocalizedStringKey("settings_section_sync_import")) {
                    NavigationLink {
                        BluetoothSyncSettingsView()
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_bluetooth_sync"),
                            systemImage: "dot.radiowaves.left.and.right",
                            countText: nil
                        )
                    }
                    .disabled(!store.isPro)
                    .overlay {
                        if !store.isPro {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingPurchase = true }
                        }
                    }

                    Button {
                        showingCloudUpload = true
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("cloudshare_upload_button"),
                            systemImage: "icloud.and.arrow.up.fill",
                            countText: nil
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingRosterImport = true
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_import"),
                            systemImage: TransferSymbol.importData,
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingMergeEntry = true
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_merge"),
                            systemImage: "arrow.triangle.merge",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(LocalizedStringKey("settings_section_ai")) {
                    Button {
                        showingDeepSeekConfig = true
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_ai"),
                            systemImage: "sparkles",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.isPro)
                    .overlay {
                        if !store.isPro {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingPurchase = true }
                        }
                    }
                }

                Section(LocalizedStringKey("settings_section_help_about")) {
                    Button {
                        showingSettingsDocument = .terms
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_help"),
                            systemImage: "doc.text.fill",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingSettingsDocument = .privacy
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_privacy"),
                            systemImage: "hand.raised.fill",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AboutDeveloperView()
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_contact_developer"),
                            systemImage: "envelope.fill",
                            countText: nil
                        )
                    }

                    settingsRow(
                        title: LocalizedStringKey("settings_version"),
                        systemImage: "info.circle.fill",
                        countText: appVersionText
                    )
                }
            }

            .navigationTitle(LocalizedStringKey("settings_nav_title"))
            .sheet(isPresented: $showingCloudUpload) {
                CloudShareUploadView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingRosterImport) {
                ImportRosterPackageView()
            }
            .sheet(isPresented: $showingMergeEntry) {
                MergeRosterUUIDView()
            }
            .sheet(isPresented: $showingDeepSeekConfig) {
                AISettingsView()
            }
            .sheet(isPresented: $isShowingPurchase) {
                ProSubscriptionStoreView()
            }
            .onChange(of: PurchaseManager.shared.isPro) { _, isPro in
                if isPro { isShowingPurchase = false }
            }
            .sheet(item: $showingSettingsDocument) { document in
                SettingsDocumentView(document: document)
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version).\(build)"
    }

    private func settingsRow(
        title: LocalizedStringKey,
        systemImage: String,
        countText: String?,
        iconColor: Color = .secondary,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body.weight(.medium))

            Spacer()

            if let countText {
                Text(countText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct TeamManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingTeam: Team?
    @State private var editingTeam: Team?

    var body: some View {
        List {
            if store.teams.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_teams"), systemImage: "person.3.fill")
            }

            ForEach(store.teams) { team in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(team.name)
                            .font(.headline)
                        Text(ListFormatter.localizedString(byJoining: team.playerIDs.compactMap { store.player(for: $0)?.name }))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        editingTeam = team
                    } label: {
                        RosterActionIcon(symbol: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button {
                        exportingTeam = team
                    } label: {
                        RosterActionIcon(symbol: TransferSymbol.exportData)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: store.deleteTeams)
        }
        .navigationTitle(LocalizedStringKey("settings_teams"))
        .sheet(item: $editingTeam) { team in
            TeamEditorView(team: team)
        }
        .sheet(item: $exportingTeam) { team in
            ExportTeamPackageView(team: team)
        }
    }
}

struct PlayerManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingPlayer: Player?
    @State private var editingPlayer: Player?
    @State private var selectedPlayerGroupID: UUID?

    private var filteredPlayers: [Player] {
        let nonTutorial = store.players.filter { !AppStore.tutorialPlayerIDs.contains($0.id) }
        guard store.isPro, let groupID = selectedPlayerGroupID else { return nonTutorial }
        return nonTutorial.filter { $0.playerGroupIDs.contains(groupID) }
    }

    var body: some View {
        List {
            if filteredPlayers.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_players"), systemImage: "person.crop.circle.badge.plus")
            }

            ForEach(filteredPlayers) { player in
                HStack(spacing: 12) {
                    PlayerAvatarView(player: player, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name)
                            .font(.headline)
                        Text(rosterPlayerSubtitle(player))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        editingPlayer = player
                    } label: {
                        RosterActionIcon(symbol: "pencil")
                    }
                    .buttonStyle(.plain)
                    Button {
                        exportingPlayer = player
                    } label: {
                        RosterActionIcon(symbol: TransferSymbol.exportData)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: store.deletePlayers)
        }
        .navigationTitle(LocalizedStringKey("settings_players"))
        .toolbar {
            if store.isPro {
                ToolbarItem(placement: .topBarTrailing) {
                    PlayerGroupPicker(store: store, selectedGroupID: $selectedPlayerGroupID)
                }
            }
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditorView(player: player)
        }
        .sheet(item: $exportingPlayer) { player in
            ExportPlayerPackageView(player: player)
        }
    }
}

private struct RosterActionIcon: View {
    var symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
    }
}

private func rosterPlayerSubtitle(_ player: Player) -> String {
    var parts: [String] = []
    if !player.number.isEmpty { parts.append("No. \(player.number)") }
    if !player.height.isEmpty { parts.append(UnitSettings.displayHeight(player.height)) }
    if !player.weight.isEmpty { parts.append(UnitSettings.displayWeight(player.weight)) }
    return parts.isEmpty ? NSLocalizedString("player_profile_missing_basic", comment: "Missing player basics") : parts.joined(separator: " · ")
}

struct CreateRosterItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RosterImportKind = .player
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_create_type")) {
                    Picker(LocalizedStringKey("section_create_type"), selection: $kind) {
                        ForEach([RosterImportKind.player, .team]) { kind in
                            Text(kind.localizedTitle).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        if kind == .player {
                            showingPlayerEditor = true
                        } else {
                            showingTeamEditor = true
                        }
                    } label: {
                        Label(kind == .player ? LocalizedStringKey("button_create_player") : LocalizedStringKey("button_create_team"), systemImage: kind == .player ? "person.crop.circle.badge.plus" : "person.3.fill")
                            .symbolRenderingMode(.monochrome)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppNeutralProminentButtonStyle())
                }
            }
            .navigationTitle(LocalizedStringKey("settings_new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_close")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingPlayerEditor) {
                PlayerEditorView(player: nil)
            }
            .sheet(isPresented: $showingTeamEditor) {
                TeamEditorView(team: nil)
            }
        }
    }
}

private struct MergeRosterUUIDView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RosterImportKind = .player

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(LocalizedStringKey("section_merge_type"), selection: $kind) {
                    ForEach(RosterImportKind.allCases) { kind in
                        Text(kind.localizedTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 4)

                if kind == .player {
                    MergePlayerUUIDView(embedded: true)
                } else {
                    MergeTeamUUIDView(embedded: true)
                }
            }
            .navigationTitle(LocalizedStringKey("settings_merge"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_close")) { dismiss() }
                }
            }
        }
    }
}

private struct ExportTeamPackageView: View {
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

        let result = try? await Task.detached(priority: .background) {
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
            let compressTask = Task.detached(priority: .background) {
                teamPlayers.compactMap { player -> (UUID, Data)? in
                    guard let compressed = Self.compressIfNeeded(player.photoData) else { return nil }
                    return (player.id, compressed)
                }
            }
            let photos = await compressTask.value
            let total = photos.count
            for (i, (pid, photoData)) in photos.enumerated() {
                uploadPhase = String(format: NSLocalizedString("cloudshare_uploading_photos_format", comment: ""), i + 1, total)
                uploadProgress = Double(i) / Double(max(total, 1))
                try await CloudShareManager.uploadPhoto(uuid: uuid, playerID: pid, data: photoData)
            }
            uploadProgress = 1
        }

        return uuid
    }

    private static func compressIfNeeded(_ data: Data?) -> Data? {
        guard let data = data, !data.isEmpty else { return nil }
        let maxSize = 200 * 1024
        guard data.count > maxSize else { return data }
        guard let image = UIImage(data: data) else { return data }
        guard let compressed = image.jpegData(compressionQuality: 0.6) else { return data }
        return compressed.count < data.count ? compressed : data
    }
}

private enum RosterImportKind: String, CaseIterable, Identifiable {
    case team
    case player
    case game

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .team:
            return LocalizedStringKey("label_team")
        case .player:
            return LocalizedStringKey("label_player")
        case .game:
            return LocalizedStringKey("label_game")
        }
    }

    var localizedName: String {
        switch self {
        case .team:
            return localized("label_team")
        case .player:
            return localized("label_player")
        case .game:
            return localized("label_game")
        }
    }
}

private struct ImportRosterPackageView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var importKind: RosterImportKind = .team
    @State private var base64 = ""
    @State private var isChunkedMode = false
    @State private var chunkInputLines: [String] = []
    @State private var chunkTransferID: String?
    @State private var chunkTotalParts = 0
    @State private var teamPackage: ExportedTeamPackage?
    @State private var playerPackage: ExportedPlayerPackage?
    @State private var parseResultText: String?
    @State private var parseSucceeded = false
    @State private var isShowingClipboardAutoFillAlert = false
    @State private var clipboardAutoFillMessage = ""
    @State private var lastAutoFilledClipboardChangeCount = -1
    @State private var hasCheckedClipboard = false
    @State private var isProgrammaticKindSwitch = false
    @State private var isParsing = false
    @State private var cloudImportUUID = ""
    @State private var isCloudImporting = false
    @State private var cloudImportProgress: Double = 0
    @State private var cloudImportPhase: String = ""
    @State private var cloudImportError: String?
    @State private var cloudImportSuccessMessage: String?
    @State private var isShowingGameImport = false
    @State private var gamePackageForCloud: ExportedGamePackage?
    @FocusState private var isInputFocused: Bool

    private var chunkKeyword: String {
        switch importKind {
        case .team:
            return GameShareChunkCodec.teamKeyword
        case .player:
            return GameShareChunkCodec.playerKeyword
        case .game:
            return GameShareChunkCodec.keyword
        }
    }

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
                Section(LocalizedStringKey("cloudshare_picker_cloud_label")) {
                    HStack(spacing: 12) {
                        TextField(LocalizedStringKey("cloudshare_import_placeholder"), text: $cloudImportUUID)
                            .font(.body.monospaced())
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)

                        if isCloudImporting {
                            VStack(alignment: .trailing, spacing: 4) {
                                ProgressView(value: cloudImportProgress, total: 1)
                                    .progressViewStyle(.linear)
                                    .frame(width: 120)
                                Text(cloudImportPhase)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button(LocalizedStringKey("cloudshare_import_button")) {
                                Task { await importFromCloud() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(cloudImportUUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if let error = cloudImportError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if let msg = cloudImportSuccessMessage {
                        Text(msg)
                            .font(.footnote)
                    }
                }

                Section(LocalizedStringKey("section_paste_share_code")) {
                    if isChunkedMode {
                        Text(localizedFormat("import_chunk_detected_progress_format", filledChunkCount, chunkTotalParts))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let chunkTransferID {
                            Text(localizedFormat("import_batch_id_format", chunkTransferID))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        ForEach(0..<chunkTotalParts, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(localizedFormat("segment_progress_format", index + 1, chunkTotalParts))
                                    .font(.caption.weight(.semibold))

                                TransferCodeInput(
                                    text: binding(forChunkIndex: index),
                                    placeholder: localizedFormat("placeholder_paste_segment_format", index + 1)
                                )
                                    .focused($isInputFocused)
                            }
                            .padding(.vertical, 2)
                        }

                        HStack(spacing: 8) {
                            Button(LocalizedStringKey("button_read_segments_from_clipboard")) {
                                tryAutoFillFromClipboard()
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

                    Button(LocalizedStringKey("button_parse_team_data")) {
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
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                if importKind == .team, let teamPackage {
                    Section(LocalizedStringKey("section_import_preview")) {
                        LabeledContent(localized("label_team"), value: teamPackage.team.name)
                        LabeledContent(localized("label_player"), value: localizedFormat("count_players_people_format", teamPackage.players.count))
                        Text(LocalizedStringKey("import_team_preview_hint"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section(LocalizedStringKey("section_player_list")) {
                        ForEach(teamPackage.players) { player in
                            Text("\(player.name)  ·  \(player.id.uuidString)")
                                .font(.caption.monospaced())
                                .lineLimit(1)
                        }
                    }

                    Section {
                        Button {
                            _ = store.importTeamPackage(teamPackage)
                            dismiss()
                        } label: {
                            Label(LocalizedStringKey("button_import_team"), systemImage: TransferSymbol.importData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppNeutralProminentButtonStyle())
                    }
                }

                if importKind == .player, let playerPackage {
                    Section(LocalizedStringKey("section_import_preview")) {
                        LabeledContent(localized("label_player"), value: playerPackage.player.name)
                        LabeledContent(localized("label_number"), value: playerPackage.player.number.isEmpty ? localized("text_not_set") : playerPackage.player.number)
                        LabeledContent(localized("label_height"), value: playerPackage.player.height.isEmpty ? localized("text_not_set") : UnitSettings.displayHeight(playerPackage.player.height))
                        LabeledContent(localized("label_weight"), value: playerPackage.player.weight.isEmpty ? localized("text_not_set") : UnitSettings.displayWeight(playerPackage.player.weight))
                        Text(LocalizedStringKey("import_player_preview_hint"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button {
                            _ = store.importPlayerPackage(playerPackage)
                            dismiss()
                        } label: {
                            Label(LocalizedStringKey("button_import_player"), systemImage: TransferSymbol.importData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppNeutralProminentButtonStyle())
                    }
                }
            }
            .sheet(isPresented: $isShowingGameImport) {
                ImportGameView(prefilledBase64: base64)
                    .environmentObject(store)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(LocalizedStringKey("nav_import_data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
            }
            .alert(LocalizedStringKey("alert_auto_detected_title"), isPresented: $isShowingClipboardAutoFillAlert) {
                Button(LocalizedStringKey("button_ok")) { }
            } message: {
                Text(clipboardAutoFillMessage)
            }
            .onAppear {
                guard !hasCheckedClipboard else { return }
                hasCheckedClipboard = true
                tryAutoFillFromClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
                tryAutoFillFromClipboard()
            }
            .onChange(of: importKind) { _, _ in
                if isProgrammaticKindSwitch {
                    isProgrammaticKindSwitch = false
                    return
                }
                clearDecodeState()
                if isChunkedMode {
                    resetToSingleMode()
                }
            }
        }
    }

    private func decode() async {
        isParsing = true
        teamPackage = nil
        playerPackage = nil
        parseResultText = nil
        parseSucceeded = false
        await Task.yield()
        defer { isParsing = false }

        let sourceText: String
        if isChunkedMode {
            switch GameShareChunkCodec.assemblePayload(from: chunkInputLines, expectedKeyword: chunkKeyword) {
            case .success(let assembled):
                sourceText = assembled.payload
            case .failure(let message):
                teamPackage = nil
                playerPackage = nil
                parseSucceeded = false
                parseResultText = localizedFormat("import_parse_failed_chunked_detail_format", importKind.localizedName, message)
                return
            }
        } else {
            let trimmedInput = base64.trimmingCharacters(in: .whitespacesAndNewlines)
            if let (kind, chunks) = recognizedChunks(from: trimmedInput) {
                applyChunks(chunks, kind: kind)
                parseResultText = localized("import_parse_detected_chunk_need_all_parts")
                return
            }
            sourceText = trimmedInput
        }

        if let decoded = store.decodeGamePackage(from: sourceText) {
            base64 = sourceText
            gamePackageForCloud = decoded
            isShowingGameImport = true
        } else if let decoded = store.decodeTeamPackage(from: sourceText) {
            isProgrammaticKindSwitch = true
            importKind = .team
            applyTeamPackage(decoded)
        } else if let decoded = store.decodePlayerPackage(from: sourceText) {
            isProgrammaticKindSwitch = true
            importKind = .player
            applyPlayerPackage(decoded)
        } else {
            teamPackage = nil
            playerPackage = nil
            parseSucceeded = false
            parseResultText = localized("import_parse_failed_team_not_complete")
        }
    }

    private func tryAutoFillFromClipboard() {
        let pasteboard = UIPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastAutoFilledClipboardChangeCount else {
            return
        }

        guard let clipboardText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            return
        }

        if let (kind, chunks) = recognizedChunks(from: clipboardText) {
            applyChunks(chunks, kind: kind)
            lastAutoFilledClipboardChangeCount = currentChangeCount
            return
        }

        if let decodedTeam = store.decodeTeamPackage(from: clipboardText) {
            isChunkedMode = false
            base64 = clipboardText
            if importKind != .team {
                isProgrammaticKindSwitch = true
                importKind = .team
            }
            applyTeamPackage(decodedTeam)
            lastAutoFilledClipboardChangeCount = currentChangeCount
            clipboardAutoFillMessage = localized("import_clipboard_team_autofilled_success")
            isShowingClipboardAutoFillAlert = true
            return
        }

        if let decodedPlayer = store.decodePlayerPackage(from: clipboardText) {
            isChunkedMode = false
            base64 = clipboardText
            if importKind != .player {
                isProgrammaticKindSwitch = true
                importKind = .player
            }
            applyPlayerPackage(decodedPlayer)
            lastAutoFilledClipboardChangeCount = currentChangeCount
            clipboardAutoFillMessage = localized("import_clipboard_player_autofilled_success")
            isShowingClipboardAutoFillAlert = true
            return
        }

        if UUID(uuidString: clipboardText) != nil {
            cloudImportUUID = clipboardText
            lastAutoFilledClipboardChangeCount = currentChangeCount
            clipboardAutoFillMessage = NSLocalizedString("cloudshare_clipboard_detected_uuid", comment: "")
            isShowingClipboardAutoFillAlert = true
            return
        }
    }

    private func recognizedChunks(from text: String) -> (kind: RosterImportKind, chunks: [GameShareChunk])? {
        let teamChunks = GameShareChunkCodec.parseChunks(in: text, expectedKeyword: GameShareChunkCodec.teamKeyword)
        let playerChunks = GameShareChunkCodec.parseChunks(in: text, expectedKeyword: GameShareChunkCodec.playerKeyword)

        if !teamChunks.isEmpty || !playerChunks.isEmpty {
            if teamChunks.count >= playerChunks.count, !teamChunks.isEmpty {
                return (.team, teamChunks)
            }
            if !playerChunks.isEmpty {
                return (.player, playerChunks)
            }
        }

        if let teamChunk = GameShareChunkCodec.parseChunkLine(text, expectedKeyword: GameShareChunkCodec.teamKeyword) {
            return (.team, [teamChunk])
        }
        if let playerChunk = GameShareChunkCodec.parseChunkLine(text, expectedKeyword: GameShareChunkCodec.playerKeyword) {
            return (.player, [playerChunk])
        }

        return nil
    }

    private func applyChunks(_ chunks: [GameShareChunk], kind: RosterImportKind) {
        guard !chunks.isEmpty else { return }

        let groupedByID = Dictionary(grouping: chunks, by: { $0.transferID })
        let targetChunks: [GameShareChunk]

        if let chunkTransferID,
           importKind == kind,
           let sameBatch = groupedByID[chunkTransferID],
           !sameBatch.isEmpty {
            targetChunks = sameBatch
        } else if let firstGroup = groupedByID.values.max(by: { $0.count < $1.count }) {
            targetChunks = firstGroup
        } else {
            return
        }

        guard let sample = targetChunks.first else { return }
        let previousTransferID = chunkTransferID

        if importKind != kind {
            isProgrammaticKindSwitch = true
            importKind = kind
        }

        isChunkedMode = true
        chunkTransferID = sample.transferID
        chunkTotalParts = sample.totalParts

        if chunkInputLines.count != sample.totalParts || previousTransferID != sample.transferID {
            chunkInputLines = Array(repeating: "", count: sample.totalParts)
        }

        for chunk in targetChunks where chunk.partIndex <= sample.totalParts {
            chunkInputLines[chunk.partIndex - 1] = chunk.rawLine
        }

        clearDecodeState()
        clipboardAutoFillMessage = localizedFormat("import_clipboard_chunk_autofill_format", kind.localizedName, filledChunkCount, chunkTotalParts)
        isShowingClipboardAutoFillAlert = true
    }

    private func resetToSingleMode() {
        isChunkedMode = false
        chunkInputLines = []
        chunkTransferID = nil
        chunkTotalParts = 0
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

    private func applyTeamPackage(_ decoded: ExportedTeamPackage) {
        teamPackage = decoded
        playerPackage = nil
        parseSucceeded = true
        parseResultText = localizedFormat(
            "import_parse_success_team_detail_format",
            decoded.team.name,
            decoded.team.id.uuidString,
            decoded.players.count
        )
    }

    private func applyPlayerPackage(_ decoded: ExportedPlayerPackage) {
        playerPackage = decoded
        teamPackage = nil
        parseSucceeded = true
        parseResultText = localizedFormat(
            "import_parse_success_player_detail_format",
            decoded.player.name,
            decoded.player.id.uuidString
        )
    }

    private func clearDecodeState() {
        teamPackage = nil
        playerPackage = nil
        parseResultText = nil
        parseSucceeded = false
    }

    private func importFromCloud() async {
        isCloudImporting = true
        cloudImportProgress = 0
        cloudImportError = nil
        cloudImportSuccessMessage = nil
        do {
            cloudImportPhase = NSLocalizedString("cloudshare_downloading_metadata", comment: "")
            let data = try await CloudShareManager.retrieve(uuid: cloudImportUUID.trimmingCharacters(in: .whitespacesAndNewlines))

            if let bundle = try? JSONDecoder().decode(CloudShareBundle.self, from: data) {
                var importedPlayers = 0
                var importedTeams = 0
                var importedGames = 0

                for exportPlayer in bundle.players {
                    let pkg = ExportedPlayerPackage(player: exportPlayer)
                    store.importPlayerPackage(pkg)
                    importedPlayers += 1
                }
                for exportTeam in bundle.teams {
                    let pkg = ExportedTeamPackage(team: exportTeam, players: bundle.players.filter { exportTeam.playerIDs.contains($0.id) })
                    store.importTeamPackage(pkg)
                    importedTeams += 1
                }
                for gameV2 in bundle.games {
                    let legacy = gameV2.legacyPackage
                    let disposition = store.importGamePackage(legacy)
                    switch disposition {
                    case .inserted: importedGames += 1
                    case .replacedSameID, .replacedLikelyDuplicate: importedGames += 1
                    }
                }

                let uid = cloudImportUUID.trimmingCharacters(in: .whitespacesAndNewlines)
                let total = bundle.players.count
                for (i, exportPlayer) in bundle.players.enumerated() {
                    cloudImportPhase = String(format: NSLocalizedString("cloudshare_downloading_photos_format", comment: ""), i + 1, total)
                    cloudImportProgress = Double(i) / Double(max(total, 1))
                    guard let photoData = try? await CloudShareManager.retrievePhoto(uuid: uid, playerID: exportPlayer.id) else { continue }
                    if var player = store.players.first(where: { $0.id == exportPlayer.id }) {
                        player.photoData = photoData
                        store.updatePlayer(player)
                    }
                }
                cloudImportProgress = 1

                cloudImportUUID = ""
                cloudImportSuccessMessage = String(format: NSLocalizedString("cloudshare_import_summary_format", comment: "Import summary"), importedPlayers, importedTeams, importedGames)
            } else {
                guard let text = String(data: data, encoding: .utf8) else {
                    throw CloudShareError.invalidResponse
                }

                if let gamePackage = store.decodeGamePackage(from: text) {
                    self.base64 = text
                    isChunkedMode = false
                    gamePackageForCloud = gamePackage
                    isShowingGameImport = true
                } else if let teamPackage = store.decodeTeamPackage(from: text) {
                    self.base64 = text
                    isChunkedMode = false
                    self.teamPackage = teamPackage
                    self.playerPackage = nil
                    parseSucceeded = true
                    isProgrammaticKindSwitch = true
                    importKind = .team
                    parseResultText = localizedFormat(
                        "import_parse_success_team_detail_format",
                        teamPackage.team.name,
                        teamPackage.team.id.uuidString,
                        teamPackage.players.count
                    )
                } else if let playerPackage = store.decodePlayerPackage(from: text) {
                    self.base64 = text
                    isChunkedMode = false
                    self.playerPackage = playerPackage
                    self.teamPackage = nil
                    parseSucceeded = true
                    isProgrammaticKindSwitch = true
                    importKind = .player
                    parseResultText = localizedFormat(
                        "import_parse_success_player_detail_format",
                        playerPackage.player.name,
                        playerPackage.player.id.uuidString
                    )
                } else {
                    cloudImportError = NSLocalizedString("cloudshare_error_invalid_response", comment: "")
                }
            }
        } catch {
            if let shareError = error as? CloudShareError, case .notFound = shareError {
                cloudImportError = NSLocalizedString("cloudshare_error_not_found", comment: "")
            } else {
                cloudImportError = error.localizedDescription
            }
        }
        isCloudImporting = false
    }
}

private struct ExportPlayerPackageView: View {
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

        let result = try? await Task.detached(priority: .background) {
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

    private static func compressIfNeeded(_ data: Data) -> Data? {
        let maxSize = 200 * 1024
        guard data.count > maxSize else { return data }
        guard let image = UIImage(data: data) else { return data }
        guard let compressed = image.jpegData(compressionQuality: 0.6) else { return data }
        return compressed.count < data.count ? compressed : data
    }
}

private struct MergePlayerUUIDView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    @State private var sourceID: UUID?
    @State private var targetID: UUID?
    @State private var resultMessage: String?

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                NavigationStack {
                    content
                        .navigationTitle(LocalizedStringKey("nav_merge_players_uuid"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(LocalizedStringKey("button_close")) { dismiss() }
                            }
                        }
                    }
                }
        }
    }

    private var content: some View {
        Form {
            Section(LocalizedStringKey("section_select_merge_target")) {
                Picker(LocalizedStringKey("picker_player_to_merge"), selection: $sourceID) {
                    Text(LocalizedStringKey("text_please_select")).tag(UUID?.none)
                    ForEach(store.players) { player in
                        Text(label(for: player)).tag(Optional(player.id))
                    }
                }

                Picker(LocalizedStringKey("picker_player_keep_uuid"), selection: $targetID) {
                    Text(LocalizedStringKey("text_please_select")).tag(UUID?.none)
                    ForEach(targetCandidates) { player in
                        Text(label(for: player)).tag(Optional(player.id))
                    }
                }
            }

            Section {
                Text(LocalizedStringKey("merge_player_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    merge()
                } label: {
                    Label(LocalizedStringKey("button_execute_merge"), systemImage: "arrow.triangle.merge")
                }
                .disabled(!canMerge)
            }

            if let resultMessage {
                Section(LocalizedStringKey("section_result")) {
                    Text(resultMessage)
                        .font(.footnote)
                }
            }
        }
    }

    private var canMerge: Bool {
        guard let sourceID, let targetID else { return false }
        return sourceID != targetID
    }

    private var targetCandidates: [Player] {
        store.players.filter { $0.id != sourceID }
    }

    private func label(for player: Player) -> String {
        let shortID = String(player.id.uuidString.prefix(8))
        return "\(player.name) (\(shortID))"
    }

    private func merge() {
        guard let sourceID, let targetID else { return }
        guard let summary = store.mergePlayer(sourceID: sourceID, into: targetID) else {
            resultMessage = localized("merge_player_failed")
            return
        }
        resultMessage = localizedFormat("merge_player_success_format", summary.updatedTeams, summary.updatedGames)
        self.sourceID = nil
        self.targetID = nil
    }
}

private struct MergeTeamUUIDView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    @State private var sourceID: UUID?
    @State private var targetID: UUID?
    @State private var resultMessage: String?

    var body: some View {
        Group {
            if embedded {
                content
            } else {
                NavigationStack {
                    content
                        .navigationTitle(LocalizedStringKey("nav_merge_teams_uuid"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(LocalizedStringKey("button_close")) { dismiss() }
                            }
                        }
                    }
                }
        }
    }

    private var content: some View {
        Form {
            Section(LocalizedStringKey("section_select_merge_target")) {
                Picker(LocalizedStringKey("picker_team_to_merge"), selection: $sourceID) {
                    Text(LocalizedStringKey("text_please_select")).tag(UUID?.none)
                    ForEach(store.teams) { team in
                        Text(label(for: team)).tag(Optional(team.id))
                    }
                }

                Picker(LocalizedStringKey("picker_team_keep_uuid"), selection: $targetID) {
                    Text(LocalizedStringKey("text_please_select")).tag(UUID?.none)
                    ForEach(targetCandidates) { team in
                        Text(label(for: team)).tag(Optional(team.id))
                    }
                }
            }

            Section {
                Text(LocalizedStringKey("merge_team_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    merge()
                } label: {
                    Label(LocalizedStringKey("button_execute_merge"), systemImage: "arrow.triangle.merge")
                }
                .disabled(!canMerge)
            }

            if let resultMessage {
                Section(LocalizedStringKey("section_result")) {
                    Text(resultMessage)
                        .font(.footnote)
                }
            }
        }
    }

    private var canMerge: Bool {
        guard let sourceID, let targetID else { return false }
        return sourceID != targetID
    }

    private var targetCandidates: [Team] {
        store.teams.filter { $0.id != sourceID }
    }

    private func label(for team: Team) -> String {
        let shortID = String(team.id.uuidString.prefix(8))
        return "\(team.name) (\(shortID))"
    }

    private func merge() {
        guard let sourceID, let targetID else { return }
        guard let summary = store.mergeTeam(sourceID: sourceID, into: targetID) else {
            resultMessage = localized("merge_team_failed")
            return
        }
        resultMessage = localizedFormat("merge_team_success_format", summary.mergedPlayers, summary.updatedGames)
        self.sourceID = nil
        self.targetID = nil
    }
}

