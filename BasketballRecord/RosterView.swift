import SwiftUI
import UIKit

struct RosterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingCreateEntry = false
    @State private var showingRosterImport = false
    @State private var showingMergeEntry = false
    @State private var showingDeepSeekConfig = false
    @State private var showingSettingsDocument: SettingsDocument?

    var body: some View {
        NavigationStack {
            List {
                Section("数据管理") {
                    NavigationLink {
                        TeamManagementView()
                    } label: {
                        settingsRow(
                            title: "球队",
                            systemImage: "person.3.fill",
                            countText: "\(store.teams.count)",
                            tint: Color(red: 0.10, green: 0.45, blue: 0.78)
                        )
                    }

                    NavigationLink {
                        PlayerManagementView()
                    } label: {
                        settingsRow(
                            title: "球员",
                            systemImage: "person.crop.circle.fill",
                            countText: "\(store.players.count)",
                            tint: Color(red: 0.22, green: 0.56, blue: 0.28)
                        )
                    }
                }

                Section("操作") {
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max")
                            .font(.subheadline.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)

                        Text("保持屏幕常亮")
                            .font(.body.weight(.medium))

                        Spacer()

                        Toggle("", isOn: $store.keepsScreenAwake)
                            .labelsHidden()
                    }

                    NavigationLink {
                        CareerStatDisplaySettingsView()
                    } label: {
                        settingsRow(
                            title: "生涯数据显示",
                            systemImage: "slider.horizontal.3",
                            countText: nil,
                            tint: Color(red: 0.32, green: 0.46, blue: 0.86),
                            showsDisclosure: true
                        )
                    }

                    Button {
                        showingCreateEntry = true
                    } label: {
                        settingsRow(
                            title: "新建",
                            systemImage: "plus.circle.fill",
                            countText: nil,
                            tint: Color(red: 0.12, green: 0.50, blue: 0.92),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingRosterImport = true
                    } label: {
                        settingsRow(
                            title: "导入",
                            systemImage: TransferSymbol.importData,
                            countText: nil,
                            tint: Color(red: 0.10, green: 0.62, blue: 0.58),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingMergeEntry = true
                    } label: {
                        settingsRow(
                            title: "合并",
                            systemImage: "arrow.triangle.merge",
                            countText: nil,
                            tint: Color(red: 0.86, green: 0.38, blue: 0.25),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingDeepSeekConfig = true
                    } label: {
                        settingsRow(
                            title: "DeepSeek API Key",
                            systemImage: "sparkles",
                            countText: nil,
                            tint: Color(red: 0.54, green: 0.45, blue: 0.88),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("关于") {
                    settingsRow(
                        title: "版本",
                        systemImage: "number.circle.fill",
                        countText: appVersionText,
                        tint: Color(red: 0.38, green: 0.41, blue: 0.48)
                    )

                    Button {
                        showingSettingsDocument = .privacy
                    } label: {
                        settingsRow(
                            title: "隐私说明",
                            systemImage: "hand.raised.fill",
                            countText: nil,
                            tint: Color(red: 0.36, green: 0.49, blue: 0.78),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingSettingsDocument = .terms
                    } label: {
                        settingsRow(
                            title: "使用说明",
                            systemImage: "doc.text.fill",
                            countText: nil,
                            tint: Color(red: 0.18, green: 0.56, blue: 0.48),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingSettingsDocument = .dataPolicy
                    } label: {
                        settingsRow(
                            title: "数据与备份",
                            systemImage: "externaldrive.fill",
                            countText: nil,
                            tint: Color(red: 0.82, green: 0.46, blue: 0.25),
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showingCreateEntry) {
                CreateRosterItemView()
            }
            .sheet(isPresented: $showingRosterImport) {
                ImportRosterPackageView()
            }
            .sheet(isPresented: $showingMergeEntry) {
                MergeRosterUUIDView()
            }
            .sheet(isPresented: $showingDeepSeekConfig) {
                DeepSeekAPISettingsView()
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

    private func settingsRow(title: String, systemImage: String, countText: String?, tint _: Color, showsDisclosure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
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

private struct DeepSeekAPISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testedKey: String?
    @State private var hasSavedKey = false
    @State private var statusMessage = ""
    @State private var statusKind: StatusKind = .neutral

    private enum StatusKind {
        case neutral
        case success
        case error
    }

    private var normalizedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedKey.isEmpty && testedKey == normalizedKey
    }

    private var statusColor: Color {
        switch statusKind {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("请输入 DeepSeek API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, _ in
                            if testedKey != normalizedKey {
                                testedKey = nil
                            }
                        }

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                            }
                            Text(isTesting ? "测试连接中..." : "测试连接")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isTesting || normalizedKey.isEmpty)

                    Button {
                        saveKey()
                    } label: {
                        Label("保存到钥匙串", systemImage: "key")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)

                    Button("删除已保存 Key", role: .destructive) {
                        removeSavedKey()
                    }
                    .disabled(!hasSavedKey)
                } header: {
                    Text("DeepSeek API Key")
                } footer: {
                    Text("必须先“测试连接”成功，才可保存到钥匙串。")
                }

                Section("状态") {
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(statusColor)
                    }
                }
            }
            .navigationTitle("DeepSeek 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSavedKey()
            }
        }
    }

    private var statusIcon: String {
        switch statusKind {
        case .neutral:
            return hasSavedKey ? "checkmark.seal" : "info.circle"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        if !statusMessage.isEmpty {
            return statusMessage
        }
        return hasSavedKey ? "已检测到已保存 Key，可直接用于 AI 总结。" : "尚未配置 API Key。"
    }

    private func loadSavedKey() {
        if let saved = DeepSeekKeychain.shared.loadAPIKey(), !saved.isEmpty {
            apiKey = saved
            hasSavedKey = true
            statusMessage = "已读取已保存 Key；如要更新，请重新测试后保存。"
            statusKind = .neutral
        } else {
            hasSavedKey = false
            statusMessage = ""
            statusKind = .neutral
        }
    }

    private func testConnection() {
        let key = normalizedKey
        guard !key.isEmpty else {
            statusKind = .error
            statusMessage = "请先输入 API Key。"
            return
        }

        isTesting = true
        statusKind = .neutral
        statusMessage = ""

        Task {
            do {
                try await DeepSeekService.shared.testConnection(apiKey: key)
                await MainActor.run {
                    testedKey = key
                    statusKind = .success
                    statusMessage = "连接测试成功，可以保存。"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testedKey = nil
                    statusKind = .error
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? "测试连接失败，请稍后重试。"
                    isTesting = false
                }
            }
        }
    }

    private func saveKey() {
        do {
            try DeepSeekKeychain.shared.saveAPIKey(normalizedKey)
            hasSavedKey = true
            statusKind = .success
            statusMessage = "已保存到钥匙串。"
        } catch {
            statusKind = .error
            statusMessage = (error as? LocalizedError)?.errorDescription ?? "保存失败，请重试。"
        }
    }

    private func removeSavedKey() {
        do {
            try DeepSeekKeychain.shared.removeAPIKey()
            hasSavedKey = false
            testedKey = nil
            apiKey = ""
            statusKind = .success
            statusMessage = "已删除已保存 Key。"
        } catch {
            statusKind = .error
            statusMessage = (error as? LocalizedError)?.errorDescription ?? "删除失败，请重试。"
        }
    }
}

private enum SettingsDocument: String, Identifiable {
    case privacy
    case terms
    case dataPolicy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy:
            return "隐私说明"
        case .terms:
            return "使用说明"
        case .dataPolicy:
            return "数据与备份"
        }
    }

    var subtitle: String {
        switch self {
        case .privacy:
            return "说明应用如何处理隐私与个人数据。"
        case .terms:
            return "快速上手与完整功能说明。"
        case .dataPolicy:
            return "说明本地存储、备份与导入前注意事项。"
        }
    }

    var symbol: String {
        switch self {
        case .privacy:
            return "hand.raised"
        case .terms:
            return "book"
        case .dataPolicy:
            return "externaldrive"
        }
    }

    var accentColor: Color {
        switch self {
        case .privacy:
            return Color(red: 0.34, green: 0.51, blue: 0.80)
        case .terms:
            return Color(red: 0.19, green: 0.57, blue: 0.48)
        case .dataPolicy:
            return Color(red: 0.83, green: 0.48, blue: 0.26)
        }
    }

    var featureSections: [SettingsFeatureSection]? {
        switch self {
        case .privacy:
            return [
                SettingsFeatureSection(
                    icon: "lock.shield",
                    title: "数据收集与使用",
                    items: [
                        SettingsFeatureItem("默认不采集身份信息", "应用不会主动收集你的姓名、手机号、身份证号等个人身份信息。"),
                        SettingsFeatureItem("不做广告跟踪", "应用不用于广告追踪，也不会将你的数据用于广告定向。"),
                        SettingsFeatureItem("仅用于核心功能", "你在应用内录入的数据仅用于比赛记录、统计、导入导出等功能本身。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "iphone",
                    title: "本地存储",
                    items: [
                        SettingsFeatureItem("默认保存在本机", "比赛、球队、球员等数据默认保存在本机应用沙盒，不会自动上传到云端服务器。"),
                        SettingsFeatureItem("由你决定分享", "通过导入/导出/分享发送的数据，接收方与传输渠道均由你主动选择。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "exclamationmark.triangle",
                    title: "使用提醒",
                    items: [
                        SettingsFeatureItem("删除通常不可恢复", "执行删除、覆盖等操作前，建议先导出备份后再处理。"),
                        SettingsFeatureItem("更换设备前先备份", "更换手机、卸载应用或清理系统数据前，请先导出关键数据。")
                    ]
                )
            ]
        case .terms:
            return [
                SettingsFeatureSection(
                    icon: "play.rectangle",
                    title: "快速上手",
                    items: [
                        SettingsFeatureItem("先建球员与球队", "在“设置”里先新建球员，再新建球队并把球员加入球队。至少准备两支有球员的球队。"),
                        SettingsFeatureItem("新建比赛", "进入“记分”页面，点击右上角“新比赛”，选择主客队、节数、上场人数和统计按钮。"),
                        SettingsFeatureItem("开始第一节", "第一节点击“开始”的瞬间，在场球员会被记录为首发；开节后才能记录得分和技术统计。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "basketball",
                    title: "比赛记录",
                    items: [
                        SettingsFeatureItem("记分统计", "支持2分、3分、罚球、篮板、助攻、犯规，并自动汇总球队与个人数据。"),
                        SettingsFeatureItem("首发 / 替补判定", "仅以第一节开始瞬间在场球员为首发；其他后续加入并上场的球员计为替补。"),
                        SettingsFeatureItem("换人与晚到球员", "可随时换人；晚到球员先通过“新增上场”加入本场，再参与换人与统计。"),
                        SettingsFeatureItem("比赛日志", "关键事件会写入日志，便于赛后回看比赛过程。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "chart.bar",
                    title: "历史与生涯",
                    items: [
                        SettingsFeatureItem("自动保存", "比赛进行中会自动保存，降低中断导致的数据丢失风险。"),
                        SettingsFeatureItem("历史详情", "历史页可按场查看比分、日志与每位球员单场表现。"),
                        SettingsFeatureItem("生涯统计", "球员页支持累计与场均数据，并支持首发 / 替补场次统计。"),
                        SettingsFeatureItem("显示设置", "可在“设置 > 生涯数据显示”中自定义展示统计项。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "square.and.arrow.down",
                    title: "导入导出",
                    items: [
                        SettingsFeatureItem("导出分享", "球员、球队、比赛支持导出编码，便于跨设备备份或分享。"),
                        SettingsFeatureItem("导入预览", "导入前会先解析，建议确认内容无误后再执行导入。"),
                        SettingsFeatureItem("映射合并", "导入比赛支持球员 / 球队映射；合并功能可处理重复数据并同步历史关联。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "lock.shield",
                    title: "数据与备份",
                    items: [
                        SettingsFeatureItem("本地存储", "比赛、球队、球员数据默认保存在本机应用沙盒。"),
                        SettingsFeatureItem("备份建议", "更换设备、卸载应用或清理系统数据前，请先导出备份。"),
                        SettingsFeatureItem("操作提醒", "删除通常不可恢复，建议定期导出关键比赛与核心球队数据。")
                    ]
                )
            ]
        case .dataPolicy:
            return [
                SettingsFeatureSection(
                    icon: "externaldrive",
                    title: "备份建议",
                    items: [
                        SettingsFeatureItem("定期导出", "建议定期导出关键比赛与核心球队数据，避免误删或设备异常造成损失。"),
                        SettingsFeatureItem("重要节点备份", "赛季结束、设备迁移、系统升级前，建议额外执行一次完整导出备份。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "square.and.arrow.down",
                    title: "导入前检查",
                    items: [
                        SettingsFeatureItem("先解析后导入", "导入前先核对解析结果，确认球队、球员和比赛信息无误再继续。"),
                        SettingsFeatureItem("确认来源可信", "请仅导入来自可信来源的数据，避免错误或异常内容覆盖现有数据。")
                    ]
                ),
                SettingsFeatureSection(
                    icon: "shield",
                    title: "安全与恢复",
                    items: [
                        SettingsFeatureItem("保留多份备份", "建议将导出文件保存到不同位置（如本机与云盘），提升可恢复性。"),
                        SettingsFeatureItem("先备份再合并", "执行导入映射、合并球员/球队等批量操作前，建议先做一次备份快照。")
                    ]
                )
            ]
        }
    }

    var content: String {
        switch self {
        case .privacy:
            return """
            1. 本应用默认将数据仅保存在本机设备，不会自动上传到云端服务器。
            2. 应用不会主动收集你的个人身份信息，也不会用于广告跟踪。
            3. 你通过导入/导出/分享功能发送的数据，由你自行决定接收方和传输渠道。
            """
        case .terms:
            return """
            欢迎使用「篮球生涯」。

            一、快速上手
            • 先建球员与球队：在“设置”里先新建球员，再新建球队并把球员加入球队；至少准备两支有球员的球队。
            • 新建比赛：进入“记分”页面，点击右上角“新比赛”，选择主客队、节数、上场人数和统计按钮。
            • 开始第一节：第一节点击“开始”的瞬间，在场球员会被记录为首发；开节后才能记录得分和技术统计。
            • 比赛中操作：可进行2分/3分/罚球记分、换人、暂停/继续、结束单节、结束整场。
            • 结束与保存：可点击“存到历史”保存快照，结束比赛后可在历史页查看完整数据。

            二、比赛记录
            • 记分统计：支持2分、3分、罚球、篮板、助攻、犯规，且会自动汇总球队与个人数据。
            • 首发/替补判定：仅以第一节开始瞬间在场球员为首发；其他后续加入并上场的球员计为替补。
            • 晚到球员：先通过“新增上场”加入本场名单，再参与换人与统计。
            • 比赛日志：关键事件会写入日志，便于赛后回看比赛过程。

            三、历史与生涯
            • 自动保存：比赛进行中会自动保存，降低中断导致的数据丢失风险。
            • 历史详情：历史页可按场查看比分、日志与每位球员单场表现。
            • 生涯统计：球员页支持累计与场均数据，并支持首发/替补场次统计。
            • 显示设置：可在“设置 > 生涯数据显示”中自定义展示哪些统计项。

            四、导入导出
            • 导出分享：球员、球队、比赛支持导出编码，便于跨设备备份或分享。
            • 导入预览：导入前会先解析，建议确认内容后再执行导入。
            • 映射合并：导入比赛支持球员/球队映射；合并功能可处理重复数据并同步历史关联。

            五、数据说明
            • 本地存储：比赛、球队、球员数据默认保存在本机应用沙盒。
            • 备份建议：更换设备、卸载应用或清理系统数据前，请先导出备份。
            • 操作提醒：删除通常不可恢复，建议定期导出关键比赛与核心球队数据。
            """
        case .dataPolicy:
            return """
            1. 比赛、球队、球员数据保存在本机应用沙盒内。
            2. 更换设备、卸载应用或清理数据前，请先使用导出功能备份。
            3. 导入数据前请确认来源可信，并核对解析预览后再执行导入。
            """
        }
    }
}

private struct SettingsDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: SettingsDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    if let featureSections = document.featureSections {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(featureSections) { section in
                                featureSection(section)
                            }
                        }
                    } else {
                        ForEach(Array(parsedSections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 10) {
                                if let title = section.title {
                                    Text(title)
                                        .font(.headline)
                                        .foregroundStyle(document.accentColor)
                                }

                                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(document.accentColor.opacity(0.22))
                                            .frame(width: 7, height: 7)
                                            .padding(.top, 6)

                                        Text(item)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
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
                                    .stroke(document.accentColor.opacity(0.14), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: document.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(document.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                Text(document.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(document.accentColor.opacity(0.10))
        )
    }

    @ViewBuilder
    private func featureSection(_ section: SettingsFeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(section.title, systemImage: section.icon)
                .font(.headline)
                .foregroundStyle(document.accentColor)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(document.accentColor.opacity(0.18))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.bold())
                            Text(item.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.leading, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(document.accentColor.opacity(0.14), lineWidth: 1)
        )
    }

    private var parsedSections: [SettingsDocumentSection] {
        document.content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(parseSection)
    }

    private func parseSection(_ block: String) -> SettingsDocumentSection? {
        let lines = block
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        if lines.count > 1, isSectionTitle(lines[0]) {
            return SettingsDocumentSection(
                title: lines[0],
                items: lines.dropFirst().map(normalizedItemText)
            )
        }

        return SettingsDocumentSection(title: nil, items: lines.map(normalizedItemText))
    }

    private func isSectionTitle(_ line: String) -> Bool {
        if line.hasPrefix("【"), line.hasSuffix("】") {
            return true
        }

        guard let separatorIndex = line.firstIndex(of: "、") else {
            return false
        }

        let prefix = line[..<separatorIndex]
        let numerals = "一二三四五六七八九十"
        return !prefix.isEmpty && prefix.allSatisfy { numerals.contains($0) }
    }

    private func normalizedItemText(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("•") {
            text.removeFirst()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let dotIndex = text.firstIndex(of: ".") {
            let prefix = text[..<dotIndex]
            if !prefix.isEmpty && prefix.allSatisfy({ $0.isNumber }) {
                let restStart = text.index(after: dotIndex)
                return text[restStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return text
    }
}

private struct SettingsDocumentSection {
    let title: String?
    let items: [String]
}

private struct SettingsFeatureSection: Identifiable {
    let id: String
    let icon: String
    let title: String
    let items: [SettingsFeatureItem]

    init(icon: String, title: String, items: [SettingsFeatureItem]) {
        self.id = title
        self.icon = icon
        self.title = title
        self.items = items
    }
}

private struct SettingsFeatureItem: Identifiable {
    let id: String
    let title: String
    let description: String

    init(_ title: String, _ description: String) {
        self.id = "\(title)-\(description)"
        self.title = title
        self.description = description
    }
}

private struct CareerStatDisplaySettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                Button("全部显示") {
                    store.setAllCareerStatVisibility(visible: true)
                }

                Button("全部隐藏") {
                    store.setAllCareerStatVisibility(visible: false)
                }
            }

            ForEach(CareerStatSection.allCases) { section in
                Section(section.title) {
                    ForEach(sectionItems(for: section)) { item in
                        Toggle(isOn: binding(for: item)) {
                            Text(item.title)
                        }
                    }
                }
            }
        }
        .navigationTitle("生涯数据显示")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionItems(for section: CareerStatSection) -> [CareerStatItem] {
        CareerStatItem.allCases.filter { $0.section == section }
    }

    private func binding(for item: CareerStatItem) -> Binding<Bool> {
        Binding(
            get: { store.isCareerStatVisible(item) },
            set: { store.setCareerStatVisible(item, visible: $0) }
        )
    }
}

private struct TeamManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingTeam: Team?
    @State private var editingTeam: Team?

    var body: some View {
        List {
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
                    .buttonStyle(.plain)

                    Button {
                        exportingTeam = team
                    } label: {
                        RosterActionIcon(
                            symbol: TransferSymbol.exportData
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: store.deleteTeams)
        }
        .navigationTitle("球队")
        .sheet(item: $editingTeam) { team in
            TeamEditorView(team: team)
        }
        .sheet(item: $exportingTeam) { team in
            ExportTeamPackageView(team: team)
        }
    }
}

private struct PlayerManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingPlayer: Player?
    @State private var editingPlayer: Player?

    var body: some View {
        List {
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
                                Text(rosterPlayerSubtitle(player))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        editingPlayer = player
                    } label: {
                        RosterActionIcon(
                            symbol: "pencil"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        exportingPlayer = player
                    } label: {
                        RosterActionIcon(
                            symbol: TransferSymbol.exportData
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete(perform: store.deletePlayers)
        }
        .navigationTitle("球员")
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
    if !player.height.isEmpty { parts.append("\(player.height)cm") }
    if !player.weight.isEmpty { parts.append("\(player.weight)kg") }
    return parts.isEmpty ? "未填写号码、身高、体重" : parts.joined(separator: " · ")
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("合并类型", selection: $kind) {
                    ForEach(RosterImportKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
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
            .navigationTitle("合并")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
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
    @State private var copyFeedbackTask: Task<Void, Never>?

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
            .onDisappear {
                copyFeedbackTask?.cancel()
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
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
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
    @State private var isShowingClipboardAutoFillAlert = false
    @State private var hasCheckedClipboard = false
    @State private var isProgrammaticKindSwitch = false
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
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppNeutralProminentButtonStyle())
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
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppNeutralProminentButtonStyle())
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
            .alert("已自动识别", isPresented: $isShowingClipboardAutoFillAlert) {
                Button("知道了") { }
            } message: {
                Text("已从剪贴板识别到可导入数据，并自动粘贴解析成功。")
            }
            .onAppear {
                guard !hasCheckedClipboard else { return }
                hasCheckedClipboard = true
                tryAutoFillFromClipboard()
            }
            .onChange(of: importKind) { _, _ in
                if isProgrammaticKindSwitch {
                    isProgrammaticKindSwitch = false
                    return
                }
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
            applyTeamPackage(decoded)

        case .player:
            guard let decoded = store.decodePlayerPackage(from: base64) else {
                teamPackage = nil
                playerPackage = nil
                parseSucceeded = false
                parseResultText = "解析失败\n类型: 球员\n请确认粘贴的是完整 Base64 球员数据。"
                return
            }
            applyPlayerPackage(decoded)
        }
    }

    private func tryAutoFillFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            return
        }

        if let decodedTeam = store.decodeTeamPackage(from: clipboardText) {
            base64 = clipboardText
            if importKind != .team {
                isProgrammaticKindSwitch = true
                importKind = .team
            }
            applyTeamPackage(decodedTeam)
            isShowingClipboardAutoFillAlert = true
            return
        }

        if let decodedPlayer = store.decodePlayerPackage(from: clipboardText) {
            base64 = clipboardText
            if importKind != .player {
                isProgrammaticKindSwitch = true
                importKind = .player
            }
            applyPlayerPackage(decodedPlayer)
            isShowingClipboardAutoFillAlert = true
        }
    }

    private func applyTeamPackage(_ decoded: ExportedTeamPackage) {
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
    }

    private func applyPlayerPackage(_ decoded: ExportedPlayerPackage) {
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
    @State private var copyFeedbackTask: Task<Void, Never>?

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
            .onDisappear {
                copyFeedbackTask?.cancel()
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
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            copyButtonTitle = "复制编码"
        }
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
                        .navigationTitle("合并并统一UUID")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { dismiss() }
                            }
                        }
                    }
                }
        }
    }

    private var content: some View {
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
                        .navigationTitle("合并球队并统一UUID")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { dismiss() }
                            }
                        }
                    }
                }
        }
    }

    private var content: some View {
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
            if values.isEmpty {
                Text("该分组暂无可显示数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            } else {
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

    private var starterGameCount: Int {
        filteredGames.reduce(0) { count, game in
            count + (game.role(of: playerID) == .starter ? 1 : 0)
        }
    }

    private var benchGameCount: Int {
        filteredGames.reduce(0) { count, game in
            count + (game.role(of: playerID) == .bench ? 1 : 0)
        }
    }

    private var totalValues: [(String, String)] {
        let stats = totalStats
        let items: [(CareerStatItem, String)] = [
            (.totalPoints, "\(stats.points)  \(percent(stats.fieldGoalRate))"),
            (.totalRebounds, "\(stats.rebounds)"),
            (.totalAssists, "\(stats.assists)"),
            (.totalFouls, "\(stats.fouls)"),
            (.totalStarterGames, "\(starterGameCount)"),
            (.totalBenchGames, "\(benchGameCount)"),
            (.totalMinutes, String(format: "%.1f", totalMinutes)),
            (.totalPlusMinus, totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"),
            (.totalTwoPoint, madeAttemptRate(made: stats.twoMade, attempts: stats.twoAttempts, rate: stats.twoPointRate)),
            (.totalThreePoint, madeAttemptRate(made: stats.threeMade, attempts: stats.threeAttempts, rate: stats.threePointRate)),
            (.totalFreeThrow, madeAttemptRate(made: stats.allFreeThrowMade, attempts: stats.allFreeThrowAttempts, rate: stats.freeThrowRate))
        ]
        return items.compactMap { item, value in
            store.isCareerStatVisible(item) ? (item.title, value) : nil
        }
    }

    private var averageValues: [(String, String)] {
        let games = max(1, filteredGames.count)
        let stats = totalStats
        let items: [(CareerStatItem, String)] = [
            (.averagePoints, average(stats.points, games)),
            (.averageRebounds, average(stats.rebounds, games)),
            (.averageAssists, average(stats.assists, games)),
            (.averageFouls, average(stats.fouls, games)),
            (.averageMinutes, String(format: "%.1f", totalMinutes / Double(games))),
            (.averagePlusMinus, String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
            (.averageTwoMade, average(stats.twoMade, games)),
            (.averageThreeMade, average(stats.threeMade, games)),
            (.averageFreeThrowMade, average(stats.allFreeThrowMade, games)),
            (.averageThreePointRate, percent(stats.threePointRate)),
            (.averageFreeThrowRate, percent(stats.freeThrowRate))
        ]
        return items.compactMap { item, value in
            store.isCareerStatVisible(item) ? (item.title, value) : nil
        }
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
        if !player.number.isEmpty { parts.append("No. \(player.number)") }
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
