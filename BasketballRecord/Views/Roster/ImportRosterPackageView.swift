import SwiftUI

struct ImportRosterPackageView: View {
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

