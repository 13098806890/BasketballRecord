import SwiftUI
import UIKit

struct RosterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingCreateEntry = false
    @State private var showingRosterImport = false
    @State private var exportingTeam: Team?
    @State private var exportingPlayer: Player?
    @State private var showingMergeEntry = false
    @State private var editingPlayer: Player?
    @State private var editingTeam: Team?

    var body: some View {
        NavigationStack {
            List {
                Section("球队") {
                    if store.teams.isEmpty {
                        ContentUnavailableView("还没有球队", systemImage: "person.3.fill")
                    }

                    ForEach(store.teams) { team in
                        HStack(spacing: 10) {
                            Button {
                                editingTeam = team
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(team.name)
                                        .font(.headline)
                                    Text(team.playerIDs.compactMap { store.player(for: $0)?.name }.joined(separator: "、"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                exportTeam(team)
                            } label: {
                                rosterActionIcon(
                                    symbol: TransferSymbol.exportData,
                                    tint: Color(red: 0.08, green: 0.54, blue: 0.52)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete(perform: store.deleteTeams)
                }

                Section("球员") {
                    if store.players.isEmpty {
                        ContentUnavailableView("还没有球员", systemImage: "person.crop.circle.badge.plus")
                    }

                    ForEach(store.players) { player in
                        HStack(spacing: 8) {
                            NavigationLink {
                                PlayerProfileView(playerID: player.id)
                            } label: {
                                HStack(spacing: 12) {
                                    PlayerAvatarView(player: player, size: 44)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(player.name)
                                            .font(.headline)
                                        Text(playerSubtitle(player))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("UUID: \(player.id.uuidString)")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                            }

                            Button {
                                editingPlayer = player
                            } label: {
                                rosterActionIcon(
                                    symbol: "pencil",
                                    tint: Color(red: 0.16, green: 0.43, blue: 0.83)
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                exportPlayer(player)
                            } label: {
                                rosterActionIcon(
                                    symbol: TransferSymbol.exportData,
                                    tint: Color(red: 0.08, green: 0.54, blue: 0.52)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete(perform: store.deletePlayers)
                }
            }
            .navigationTitle("配置")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingMergeEntry = true
                    } label: {
                        Label("合并", systemImage: "arrow.triangle.merge")
                    }

                    Button {
                        showingRosterImport = true
                    } label: {
                        Label("导入数据", systemImage: TransferSymbol.importData)
                    }

                    Button {
                        showingCreateEntry = true
                    } label: {
                        Label("新建", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditorView(player: player)
            }
            .sheet(item: $editingTeam) { team in
                TeamEditorView(team: team)
            }
            .sheet(isPresented: $showingCreateEntry) {
                CreateRosterItemView()
            }
            .sheet(isPresented: $showingRosterImport) {
                ImportRosterPackageView()
            }
            .sheet(item: $exportingTeam) { team in
                ExportTeamPackageView(team: team)
            }
            .sheet(item: $exportingPlayer) { player in
                ExportPlayerPackageView(player: player)
            }
            .sheet(isPresented: $showingMergeEntry) {
                MergeRosterUUIDView()
            }
        }
    }

    private func playerSubtitle(_ player: Player) -> String {
        var parts: [String] = []
        if !player.number.isEmpty { parts.append("#\(player.number)") }
        if !player.height.isEmpty { parts.append("\(player.height)cm") }
        if !player.weight.isEmpty { parts.append("\(player.weight)kg") }
        return parts.isEmpty ? "未填写号码、身高、体重" : parts.joined(separator: " · ")
    }

    private func exportTeam(_ team: Team) {
        exportingTeam = team
    }

    private func exportPlayer(_ player: Player) {
        exportingPlayer = player
    }

    private func rosterActionIcon(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(0.14), in: Circle())
    }
}

private struct CreateRosterItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RosterImportKind = .player
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section("新建类型") {
                    Picker("新建类型", selection: $kind) {
                        ForEach(RosterImportKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
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
                        Label(kind == .player ? "新建球员" : "新建球队", systemImage: kind == .player ? "person.crop.circle.badge.plus" : "person.3.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                }
            }
            .navigationTitle("新建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
    @State private var showingPlayerMerge = false
    @State private var showingTeamMerge = false

    var body: some View {
        NavigationStack {
            Form {
                Section("合并类型") {
                    Picker("合并类型", selection: $kind) {
                        ForEach(RosterImportKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive) {
                        if kind == .player {
                            showingPlayerMerge = true
                        } else {
                            showingTeamMerge = true
                        }
                    } label: {
                        Label(kind == .player ? "合并球员" : "合并球队", systemImage: "arrow.triangle.merge")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("合并")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPlayerMerge) {
                MergePlayerUUIDView()
            }
            .sheet(isPresented: $showingTeamMerge) {
                MergeTeamUUIDView()
            }
        }
    }
}

private struct ExportTeamPackageView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var team: Team

    @State private var base64 = ""
    @State private var isGenerating = true
    @State private var copyButtonTitle = "复制编码"

    var body: some View {
        NavigationStack {
            Form {
                Section("球队") {
                    Text(team.name)
                }

                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在生成 Base64 编码…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if base64.isEmpty {
                    Section {
                        Text("编码生成失败，请重试。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Base64 球队数据") {
                        TextEditor(text: .constant(base64))
                            .font(.caption.monospaced())
                            .frame(minHeight: 220)
                    }

                    Section {
                        Button {
                            UIPasteboard.general.string = base64
                            showCopyFeedback()
                        } label: {
                            Label(copyButtonTitle, systemImage: copyButtonTitle == "复制编码" ? "doc.on.doc" : "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())

                        ShareLink(item: base64) {
                            Label("分享编码", systemImage: TransferSymbol.exportData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
                    }
                }
            }
            .navigationTitle("导出球队")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task(id: team.id) {
                await generateBase64()
            }
        }
    }

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        await Task.yield()
        base64 = store.exportTeamBase64(team) ?? ""
        isGenerating = false
    }

    private func showCopyFeedback() {
        copyButtonTitle = "已复制"
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copyButtonTitle = "复制编码"
        }
    }
}

private enum RosterImportKind: String, CaseIterable, Identifiable {
    case team = "球队"
    case player = "球员"

    var id: String { rawValue }
}

private struct ImportRosterPackageView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var importKind: RosterImportKind = .team
    @State private var base64 = ""
    @State private var teamPackage: ExportedTeamPackage?
    @State private var playerPackage: ExportedPlayerPackage?
    @State private var parseResultText: String?
    @State private var parseSucceeded = false
    @State private var isParsing = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("导入类型") {
                    Picker("导入类型", selection: $importKind) {
                        ForEach(RosterImportKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("粘贴 Base64") {
                    TextEditor(text: $base64)
                        .font(.caption.monospaced())
                        .frame(height: 112)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                    Button(importKind == .team ? "解析球队数据" : "解析球员数据") {
                        isInputFocused = false
                        Task {
                            await decode()
                        }
                    }
                    .disabled(base64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)

                    if isParsing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("解析中…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parseResultText {
                    Section("解析结果") {
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

                if importKind == .team, let teamPackage {
                    Section("导入预览") {
                        LabeledContent("球队", value: teamPackage.team.name)
                        LabeledContent("球员", value: "\(teamPackage.players.count) 人")
                        Text("导入后会保留原 UUID，不做同名自动合并。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("球员名单") {
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
                            Label("导入球队", systemImage: TransferSymbol.importData)
                        }
                    }
                }

                if importKind == .player, let playerPackage {
                    Section("导入预览") {
                        LabeledContent("球员", value: playerPackage.player.name)
                        LabeledContent("号码", value: playerPackage.player.number.isEmpty ? "未填写" : playerPackage.player.number)
                        LabeledContent("身高", value: playerPackage.player.height.isEmpty ? "未填写" : "\(playerPackage.player.height)cm")
                        LabeledContent("体重", value: playerPackage.player.weight.isEmpty ? "未填写" : "\(playerPackage.player.weight)kg")
                        Text("导入后会保留原 UUID。若 UUID 已存在，会用导入数据覆盖本机该球员。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button {
                            _ = store.importPlayerPackage(playerPackage)
                            dismiss()
                        } label: {
                            Label("导入球员", systemImage: TransferSymbol.importData)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("导入数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: importKind) { _, _ in
                clearDecodeState()
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

        switch importKind {
        case .team:
            guard let decoded = store.decodeTeamPackage(from: base64) else {
                teamPackage = nil
                playerPackage = nil
                parseSucceeded = false
                parseResultText = "解析失败\n类型: 球队\n请确认粘贴的是完整 Base64 球队数据。"
                return
            }
            teamPackage = decoded
            playerPackage = nil
            parseSucceeded = true
            parseResultText = """
            解析成功
            类型: 球队
            球队: \(decoded.team.name)
            球队UUID: \(decoded.team.id.uuidString)
            球员数量: \(decoded.players.count)
            """

        case .player:
            guard let decoded = store.decodePlayerPackage(from: base64) else {
                teamPackage = nil
                playerPackage = nil
                parseSucceeded = false
                parseResultText = "解析失败\n类型: 球员\n请确认粘贴的是完整 Base64 球员数据。"
                return
            }
            playerPackage = decoded
            teamPackage = nil
            parseSucceeded = true
            parseResultText = """
            解析成功
            类型: 球员
            球员: \(decoded.player.name)
            球员UUID: \(decoded.player.id.uuidString)
            """
        }
    }

    private func clearDecodeState() {
        teamPackage = nil
        playerPackage = nil
        parseResultText = nil
        parseSucceeded = false
    }
}

private struct ExportPlayerPackageView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var player: Player

    @State private var base64 = ""
    @State private var isGenerating = true
    @State private var copyButtonTitle = "复制编码"

    var body: some View {
        NavigationStack {
            Form {
                Section("球员") {
                    Text(player.name)
                }

                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("正在生成 Base64 编码…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if base64.isEmpty {
                    Section {
                        Text("编码生成失败，请重试。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Base64 球员数据") {
                        TextEditor(text: .constant(base64))
                            .font(.caption.monospaced())
                            .frame(minHeight: 220)
                    }

                    Section {
                        Button {
                            UIPasteboard.general.string = base64
                            showCopyFeedback()
                        } label: {
                            Label(copyButtonTitle, systemImage: copyButtonTitle == "复制编码" ? "doc.on.doc" : "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())

                        ShareLink(item: base64) {
                            Label("分享编码", systemImage: TransferSymbol.exportData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
                    }
                }
            }
            .navigationTitle("导出球员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task(id: player.id) {
                await generateBase64()
            }
        }
    }

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        await Task.yield()
        base64 = store.exportPlayerBase64(player) ?? ""
        isGenerating = false
    }

    private func showCopyFeedback() {
        copyButtonTitle = "已复制"
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            copyButtonTitle = "复制编码"
        }
    }
}

private struct MergePlayerUUIDView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sourceID: UUID?
    @State private var targetID: UUID?
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("选择合并对象") {
                    Picker("被合并球员", selection: $sourceID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(store.players) { player in
                            Text(label(for: player)).tag(Optional(player.id))
                        }
                    }

                    Picker("保留 UUID 球员", selection: $targetID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(targetCandidates) { player in
                            Text(label(for: player)).tag(Optional(player.id))
                        }
                    }
                }

                Section {
                    Text("执行后会把历史比赛、球队名单中的被合并球员 UUID 全部替换为保留 UUID，并删除被合并球员。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        merge()
                    } label: {
                        Label("执行合并", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(!canMerge)
                }

                if let resultMessage {
                    Section("结果") {
                        Text(resultMessage)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("合并并统一UUID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
            resultMessage = "合并失败：请确认两个球员都存在且 UUID 不同。"
            return
        }
        resultMessage = "已完成：更新球队 \(summary.updatedTeams) 支，更新历史比赛 \(summary.updatedGames) 场。"
        self.sourceID = nil
        self.targetID = nil
    }
}

private struct MergeTeamUUIDView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sourceID: UUID?
    @State private var targetID: UUID?
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("选择合并对象") {
                    Picker("被合并球队", selection: $sourceID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(store.teams) { team in
                            Text(label(for: team)).tag(Optional(team.id))
                        }
                    }

                    Picker("保留 UUID 球队", selection: $targetID) {
                        Text("请选择").tag(UUID?.none)
                        ForEach(targetCandidates) { team in
                            Text(label(for: team)).tag(Optional(team.id))
                        }
                    }
                }

                Section {
                    Text("执行后会把历史比赛中的球队 UUID 迁移到保留 UUID，并删除被合并球队；目标球队会并入被合并球队里缺失的球员。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        merge()
                    } label: {
                        Label("执行合并", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(!canMerge)
                }

                if let resultMessage {
                    Section("结果") {
                        Text(resultMessage)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("合并球队并统一UUID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
            resultMessage = "合并失败：请确认两个球队都存在且 UUID 不同。"
            return
        }
        resultMessage = "已完成：并入球员 \(summary.mergedPlayers) 名，更新历史比赛 \(summary.updatedGames) 场。"
        self.sourceID = nil
        self.targetID = nil
    }
}

struct PlayerProfileView: View {
    @EnvironmentObject private var store: AppStore
    var playerID: UUID
    var fixedGame: SavedGame? = nil
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var hasInitializedGameSelection = false

    private var player: Player? { store.player(for: playerID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if fixedGame == nil {
                    NavigationLink {
                        PlayerGameSelectionView(games: allPlayerGames, selectedIDs: $selectedGameIDs)
                    } label: {
                        HStack {
                            Label("选择比赛", systemImage: "list.bullet.rectangle")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(selectionSummaryText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                        .padding(.horizontal)

                    statSection("场均", values: averageValues)
                }

                statSection(fixedGame == nil ? "总数据" : "本场数据", values: totalValues)
            }
            .padding(.vertical)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .navigationTitle(player?.name ?? "球员")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncSelectedGamesIfNeeded)
        .onChange(of: store.savedGames) { _, _ in syncSelectedGamesIfNeeded() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            if let player {
                PlayerAvatarView(player: player, size: 76)
                VStack(alignment: .leading, spacing: 8) {
                    Text(player.name)
                        .font(.title2.weight(.bold))
                    Text(profileSubtitle(player))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("UUID: \(player.id.uuidString)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("比赛 \(filteredGames.count) 场")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.7), in: Capsule())
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.82, green: 0.88, blue: 0.82), Color(red: 0.90, green: 0.84, blue: 0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .padding(.horizontal)
    }

    private func statSection(_ title: String, values: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(values, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.headline.monospacedDigit().weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal)
    }

    private var allPlayerGames: [SavedGame] {
        store.savedGames
            .filter { containsPlayer(in: $0) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var selectionSummaryText: String {
        "\(selectedGameIDs.count)/\(allPlayerGames.count)"
    }

    private var filteredGames: [SavedGame] {
        if let fixedGame {
            return containsPlayer(in: fixedGame) ? [fixedGame] : []
        }

        return allPlayerGames.filter { game in
            selectedGameIDs.contains(game.id)
        }
    }

    private var totalStats: PlayerStats {
        filteredGames.reduce(PlayerStats()) { partial, game in
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            var total = partial
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
            return total
        }
    }

    private var totalMinutes: Double {
        filteredGames.reduce(0) { $0 + ($1.snapshot.playingSecondsByPlayerID[playerID, default: 0] / 60) }
    }

    private var totalPlusMinus: Int {
        filteredGames.reduce(0) { $0 + $1.snapshot.plusMinusByPlayerID[playerID, default: 0] }
    }

    private var totalValues: [(String, String)] {
        let stats = totalStats
        return [
            ("得分", "\(stats.points)  \(percent(stats.fieldGoalRate))"),
            ("篮板", "\(stats.rebounds)"),
            ("助攻", "\(stats.assists)"),
            ("犯规", "\(stats.fouls)"),
            ("时间", String(format: "%.1f", totalMinutes)),
            ("正负值", totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"),
            ("2分投篮", madeAttemptRate(made: stats.twoMade, attempts: stats.twoAttempts, rate: stats.twoPointRate)),
            ("3分投篮", madeAttemptRate(made: stats.threeMade, attempts: stats.threeAttempts, rate: stats.threePointRate)),
            ("罚球", madeAttemptRate(made: stats.allFreeThrowMade, attempts: stats.allFreeThrowAttempts, rate: stats.freeThrowRate))
        ]
    }

    private var averageValues: [(String, String)] {
        let games = max(1, filteredGames.count)
        let stats = totalStats
        return [
            ("场均得分", average(stats.points, games)),
            ("场均篮板", average(stats.rebounds, games)),
            ("场均助攻", average(stats.assists, games)),
            ("场均犯规", average(stats.fouls, games)),
            ("场均时间", String(format: "%.1f", totalMinutes / Double(games))),
            ("场均正负值", String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
            ("场均2分命中", average(stats.twoMade, games)),
            ("场均3分命中", average(stats.threeMade, games)),
            ("场均罚球命中", average(stats.allFreeThrowMade, games)),
            ("三分命中率", percent(stats.threePointRate)),
            ("罚球命中率", percent(stats.freeThrowRate))
        ]
    }

    private func madeAttemptRate(made: Int, attempts: Int, rate: Double) -> String {
        "\(made)/\(attempts)  \(percent(rate))"
    }

    private func average(_ value: Int, _ games: Int) -> String {
        String(format: "%.1f", Double(value) / Double(games))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func profileSubtitle(_ player: Player) -> String {
        var parts: [String] = []
        if !player.number.isEmpty { parts.append("#\(player.number)") }
        if !player.height.isEmpty { parts.append("\(player.height)cm") }
        if !player.weight.isEmpty { parts.append("\(player.weight)kg") }
        return parts.isEmpty ? "未填写基础资料" : parts.joined(separator: " · ")
    }

    private func containsPlayer(in game: SavedGame) -> Bool {
        game.homePlayerIDs.contains(playerID)
            || game.awayPlayerIDs.contains(playerID)
            || game.snapshot.statsByPlayerID[playerID] != nil
    }

    private func syncSelectedGamesIfNeeded() {
        guard fixedGame == nil else { return }
        let availableIDs = Set(allPlayerGames.map(\.id))

        if !hasInitializedGameSelection {
            selectedGameIDs = availableIDs
            hasInitializedGameSelection = true
            return
        }

        selectedGameIDs = selectedGameIDs.intersection(availableIDs)
    }
}

private struct PlayerGameSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    var games: [SavedGame]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView("没有可选比赛", systemImage: "clock.badge.questionmark")
            }

            ForEach(monthGroups) { group in
                DisclosureGroup {
                    HStack {
                        Button(allSelected(in: group.games) ? "清空本月" : "全选本月") {
                            toggleMonthSelection(for: group.games)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()
                        Text("\(selectedCount(in: group.games))/\(group.games.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    ForEach(group.games) { game in
                        Button {
                            toggle(game.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(game.id) ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("\(game.homeTeamName) vs \(game.awayTeamName)")
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
                } label: {
                    HStack {
                        Text(group.title)
                            .font(.headline)
                        Spacer()
                        Text("\(selectedCount(in: group.games))/\(group.games.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("选择比赛")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("全清") {
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("全选") {
                    selectedIDs = Set(games.map(\.id))
                }
                .disabled(games.isEmpty || selectedIDs.count == games.count)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }

    private var monthGroups: [PlayerGameMonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: games) { game in
            let components = calendar.dateComponents([.year, .month], from: game.savedAt)
            return PlayerGameMonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }

        return grouped.keys.sorted(by: >).map { key in
            PlayerGameMonthGroup(key: key, games: grouped[key, default: []].sorted { $0.savedAt > $1.savedAt })
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleMonthSelection(for games: [SavedGame]) {
        if allSelected(in: games) {
            games.forEach { selectedIDs.remove($0.id) }
        } else {
            games.forEach { selectedIDs.insert($0.id) }
        }
    }

    private func allSelected(in games: [SavedGame]) -> Bool {
        !games.isEmpty && games.allSatisfy { selectedIDs.contains($0.id) }
    }

    private func selectedCount(in games: [SavedGame]) -> Int {
        games.reduce(0) { count, game in
            count + (selectedIDs.contains(game.id) ? 1 : 0)
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

private struct PlayerGameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: PlayerGameMonthKey, rhs: PlayerGameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

private struct PlayerGameMonthGroup: Identifiable {
    var key: PlayerGameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { "\(key.year)年 \(key.month)月" }
}
