import SwiftUI

struct ImportGameView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var base64: String
    @State private var isChunkedMode = false

    init(prefilledBase64: String = "") {
        _base64 = State(initialValue: prefilledBase64)
    }
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

    @State private var cloudImportUUID = ""
    @State private var isCloudImporting = false
    @State private var cloudImportError: String?

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
                            ProgressView()
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
                }

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
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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

    private func importFromCloud() async {
        isCloudImporting = true
        cloudImportError = nil
        do {
            let data = try await CloudShareManager.retrieve(uuid: cloudImportUUID.trimmingCharacters(in: .whitespacesAndNewlines))
            guard let base64 = String(data: data, encoding: .utf8) else {
                throw CloudShareError.invalidResponse
            }
            self.base64 = base64
            self.isChunkedMode = false
            await decode()
        } catch {
            if let shareError = error as? CloudShareError, case .notFound = shareError {
                cloudImportError = NSLocalizedString("cloudshare_error_not_found", comment: "")
            } else {
                cloudImportError = error.localizedDescription
            }
        }
        isCloudImporting = false
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

