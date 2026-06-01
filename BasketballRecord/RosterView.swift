import SwiftUI
import UIKit

private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: localized(key), locale: Locale.current, arguments: args)
}

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
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)

                        Text(LocalizedStringKey("settings_show_simulation_button"))
                            .font(.body.weight(.medium))

                        Spacer()

                        Toggle("", isOn: $store.showsSimulationButton)
                            .labelsHidden()
                    }

                    NavigationLink {
                        CareerStatDisplaySettingsView()
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_career_display"),
                            systemImage: "slider.horizontal.3",
                            countText: nil
                        )
                    }
                }

                Section(LocalizedStringKey("settings_section_data_management")) {
                    NavigationLink {
                        TeamManagementView()
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_teams"),
                            systemImage: "person.3.fill",
                            countText: "\(store.teams.count)"
                        )
                    }

                    NavigationLink {
                        PlayerManagementView()
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_players"),
                            systemImage: "person.crop.circle.fill",
                            countText: "\(store.players.count)"
                        )
                    }

                    Button {
                        showingCreateEntry = true
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_new"),
                            systemImage: "plus.circle.fill",
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
                            title: LocalizedStringKey("settings_deepseek_api_key"),
                            systemImage: "sparkles",
                            countText: nil,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(LocalizedStringKey("settings_section_help_about")) {
                    Button {
                        showingSettingsDocument = .terms
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("settings_help"),
                            systemImage: "doc.text.fill",
                            countText: nil,
                            iconColor: .blue,
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
                            iconColor: .blue,
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)

                    settingsRow(
                        title: LocalizedStringKey("settings_version"),
                        systemImage: "number.circle.fill",
                        countText: appVersionText
                    )
                }
            }
            .navigationTitle(LocalizedStringKey("settings_nav_title"))
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
                    SecureField(LocalizedStringKey("deepseek_enter_api_key"), text: $apiKey)
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
                            Text(isTesting ? LocalizedStringKey("deepseek_testing") : LocalizedStringKey("deepseek_test"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isTesting || normalizedKey.isEmpty)

                    Button {
                        saveKey()
                    } label: {
                        Label(LocalizedStringKey("deepseek_save_key"), systemImage: "key")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)

                    Button(LocalizedStringKey("deepseek_remove_saved_key"), role: .destructive) {
                        removeSavedKey()
                    }
                    .disabled(!hasSavedKey)
                } header: {
                    Text(LocalizedStringKey("settings_deepseek_api_key"))
                } footer: {
                    Text(LocalizedStringKey("deepseek_test_before_save_hint"))
                }

                Section(LocalizedStringKey("section_status")) {
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(statusColor)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("deepseek_settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) {
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
        return hasSavedKey
            ? NSLocalizedString("deepseek_status_has_saved_key", comment: "DeepSeek key saved status")
            : NSLocalizedString("deepseek_status_no_saved_key", comment: "DeepSeek no key status")
    }

    private func loadSavedKey() {
        if let saved = DeepSeekKeychain.shared.loadAPIKey(), !saved.isEmpty {
            apiKey = saved
            hasSavedKey = true
            statusMessage = NSLocalizedString("deepseek_status_loaded_saved_key", comment: "DeepSeek loaded saved key")
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
            statusMessage = NSLocalizedString("deepseek_error_enter_key_first", comment: "DeepSeek empty key error")
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
                    statusMessage = NSLocalizedString("deepseek_status_test_success", comment: "DeepSeek test success")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testedKey = nil
                    statusKind = .error
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? NSLocalizedString("deepseek_error_test_failed", comment: "DeepSeek test failed")
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
            statusMessage = NSLocalizedString("deepseek_status_saved_to_keychain", comment: "DeepSeek key saved")
        } catch {
            statusKind = .error
            statusMessage = (error as? LocalizedError)?.errorDescription ?? NSLocalizedString("deepseek_error_save_failed", comment: "DeepSeek save failed")
        }
    }

    private func removeSavedKey() {
        do {
            try DeepSeekKeychain.shared.removeAPIKey()
            hasSavedKey = false
            testedKey = nil
            apiKey = ""
            statusKind = .success
            statusMessage = NSLocalizedString("deepseek_status_removed", comment: "DeepSeek key removed")
        } catch {
            statusKind = .error
            statusMessage = (error as? LocalizedError)?.errorDescription ?? NSLocalizedString("deepseek_error_remove_failed", comment: "DeepSeek remove failed")
        }
    }
}

private enum SettingsDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy:
            return localized("settings_privacy")
        case .terms:
            return localized("settings_help")
        }
    }

    var subtitle: String {
        switch self {
        case .privacy:
            return localized("settings_doc_privacy_subtitle")
        case .terms:
            return localized("settings_doc_terms_subtitle")
        }
    }

    var symbol: String {
        switch self {
        case .privacy:
            return "hand.raised"
        case .terms:
            return "book"
        }
    }

    var accentColor: Color {
        Color.blue
    }

    var featureSections: [SettingsFeatureSection]? {
        switch self {
        case .privacy:
            return [
                SettingsFeatureSection(
                    icon: "lock.shield",
                    title: localized("settings_doc_privacy_storage_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_privacy_storage_item1_title"), localized("settings_doc_privacy_storage_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_privacy_storage_item2_title"), localized("settings_doc_privacy_storage_item2_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "network",
                    title: localized("settings_doc_privacy_network_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_privacy_network_item1_title"), localized("settings_doc_privacy_network_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_privacy_network_item2_title"), localized("settings_doc_privacy_network_item2_desc")),
                        SettingsFeatureItem(localized("settings_doc_privacy_network_item3_title"), localized("settings_doc_privacy_network_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "exclamationmark.triangle",
                    title: localized("settings_doc_privacy_notice_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_privacy_notice_item1_title"), localized("settings_doc_privacy_notice_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_privacy_notice_item2_title"), localized("settings_doc_privacy_notice_item2_desc"))
                    ]
                )
            ]
        case .terms:
            return [
                SettingsFeatureSection(
                    icon: "play.rectangle",
                    title: localized("settings_doc_help_quickstart_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_quickstart_item1_title"), localized("settings_doc_help_quickstart_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_quickstart_item2_title"), localized("settings_doc_help_quickstart_item2_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_quickstart_item3_title"), localized("settings_doc_help_quickstart_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "basketball",
                    title: localized("settings_doc_help_gamelog_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item1_title"), localized("settings_doc_help_gamelog_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item2_title"), localized("settings_doc_help_gamelog_item2_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item3_title"), localized("settings_doc_help_gamelog_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "dot.radiowaves.left.and.right",
                    title: localized("settings_doc_help_sync_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_sync_item1_title"), localized("settings_doc_help_sync_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_sync_item2_title"), localized("settings_doc_help_sync_item2_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_sync_item3_title"), localized("settings_doc_help_sync_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "sparkles",
                    title: localized("settings_doc_help_ai_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_ai_item1_title"), localized("settings_doc_help_ai_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_ai_item2_title"), localized("settings_doc_help_ai_item2_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_ai_item3_title"), localized("settings_doc_help_ai_item3_desc"))
                    ]
                )
            ]
        }
    }

    var content: String {
        switch self {
        case .privacy:
            return localized("settings_doc_privacy_content")
        case .terms:
            return localized("settings_doc_help_content")
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
                    Button(LocalizedStringKey("button_done")) { dismiss() }
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
                Button(LocalizedStringKey("button_show_all")) {
                    store.setAllCareerStatVisibility(visible: true)
                }

                Button(LocalizedStringKey("button_hide_all")) {
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
        .navigationTitle(LocalizedStringKey("settings_career_display"))
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
                ContentUnavailableView(LocalizedStringKey("empty_no_teams"), systemImage: "person.3.fill")
            }

            ForEach(store.teams) { team in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(team.name)
                            .font(.headline)
                        Text(team.playerIDs.compactMap { store.player(for: $0)?.name }.joined(separator: "、"))
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

private struct PlayerManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportingPlayer: Player?
    @State private var editingPlayer: Player?

    var body: some View {
        List {
            if store.players.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_players"), systemImage: "person.crop.circle.badge.plus")
            }

            ForEach(store.players) { player in
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
    return parts.isEmpty ? NSLocalizedString("player_profile_missing_basic", comment: "Missing player basics") : parts.joined(separator: " · ")
}

private struct CreateRosterItemView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: RosterImportKind = .player
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_create_type")) {
                    Picker(LocalizedStringKey("section_create_type"), selection: $kind) {
                        ForEach(RosterImportKind.allCases) { kind in
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
                Section(LocalizedStringKey("label_team")) {
                    Text(team.name)
                }

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
        base64 = store.exportTeamBase64(team) ?? ""
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
}

private enum RosterImportKind: String, CaseIterable, Identifiable {
    case team
    case player

    var id: String { rawValue }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .team:
            return LocalizedStringKey("label_team")
        case .player:
            return LocalizedStringKey("label_player")
        }
    }

    var localizedName: String {
        switch self {
        case .team:
            return localized("label_team")
        case .player:
            return localized("label_player")
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
    @FocusState private var isInputFocused: Bool

    private var chunkKeyword: String {
        switch importKind {
        case .team:
            return GameShareChunkCodec.teamKeyword
        case .player:
            return GameShareChunkCodec.playerKeyword
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
                Section(LocalizedStringKey("section_import_type")) {
                    Picker(LocalizedStringKey("section_import_type"), selection: $importKind) {
                        ForEach(RosterImportKind.allCases) { kind in
                            Text(kind.localizedTitle).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
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

                    Button(importKind == .team ? localized("button_parse_team_data") : localized("button_parse_player_data")) {
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
                        LabeledContent(localized("label_height"), value: playerPackage.player.height.isEmpty ? localized("text_not_set") : "\(playerPackage.player.height)cm")
                        LabeledContent(localized("label_weight"), value: playerPackage.player.weight.isEmpty ? localized("text_not_set") : "\(playerPackage.player.weight)kg")
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

        switch importKind {
        case .team:
            guard let decoded = store.decodeTeamPackage(from: sourceText) else {
                teamPackage = nil
                playerPackage = nil
                parseSucceeded = false
                parseResultText = localized("import_parse_failed_team_not_complete")
                return
            }
            applyTeamPackage(decoded)

        case .player:
            guard let decoded = store.decodePlayerPackage(from: sourceText) else {
                teamPackage = nil
                playerPackage = nil
                parseSucceeded = false
                parseResultText = localized("import_parse_failed_player_not_complete")
                return
            }
            applyPlayerPackage(decoded)
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
}

private struct ExportPlayerPackageView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager
    @Environment(\.dismiss) private var dismiss
    var player: Player

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
                Section(LocalizedStringKey("label_player")) {
                    Text(player.name)
                }

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
        base64 = store.exportPlayerBase64(player) ?? ""
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

struct PlayerProfileView: View {
    @EnvironmentObject private var store: AppStore
    var playerID: UUID
    var fixedGame: SavedGame? = nil
    @State private var selectedGameIDs: Set<UUID> = []
    @State private var hasInitializedGameSelection = false
    @State private var selectedPeriod: Int? = nil
    @State private var fixedGameAnalysis = SavedGamePeriodAnalysis()

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
                            Label(LocalizedStringKey("button_choose_games"), systemImage: "list.bullet.rectangle")
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

                    statSection(localized("label_average_stats"), values: averageValues)
                }

                if let fixedGame, fixedGame.snapshot.periodCount > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LocalizedStringKey("label_data_range"))
                            .font(.headline)
                        Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                            Text(LocalizedStringKey("label_full_game")).tag(Optional<Int>.none)
                            ForEach(1...fixedGame.snapshot.periodCount, id: \.self) { period in
                                Text(localizedFormat("label_period_number_format", period)).tag(Optional(period))
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                }

                statSection(fixedGame == nil ? localized("label_total_stats") : localized("label_this_game_stats"), values: totalValues)

                if fixedGame != nil {
                    eventSection
                }
            }
            .padding(.vertical)
        }
        .background(Color(red: 0.97, green: 0.96, blue: 0.93))
        .navigationTitle(player?.name ?? localized("label_player"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncSelectedGamesIfNeeded()
            rebuildFixedGameAnalysisIfNeeded()
        }
        .onChange(of: store.savedGames) { _, _ in
            syncSelectedGamesIfNeeded()
            rebuildFixedGameAnalysisIfNeeded()
        }
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
                    Text(localizedFormat("count_games_format", filteredGames.count))
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
                Text(LocalizedStringKey("text_no_stats_in_group"))
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

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("label_events"))
                .font(.headline)

            if filteredPlayerLogs.isEmpty {
                Text(LocalizedStringKey("text_no_player_events_for_range"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPlayerLogs) { log in
                            Text(GameLogFormatter.lineText(for: log))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(GameLogFormatter.isScoring(log) ? Color.blue : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: 220)
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

    private var isFixedPeriodMode: Bool {
        fixedGame != nil && selectedPeriod != nil
    }

    private var filteredPlayerLogs: [PeriodAwareLog] {
        guard fixedGame != nil else { return [] }
        return fixedGameAnalysis.playerLogs(for: playerID, period: selectedPeriod).reversed()
    }

    private var totalStats: PlayerStats {
        if let selectedPeriod, fixedGame != nil {
            return fixedGameAnalysis.statsByPlayerID(for: selectedPeriod)[playerID, default: PlayerStats()]
        }

        return filteredGames.reduce(PlayerStats()) { partial, game in
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
            total.blocks += stats.blocks
            total.steals += stats.steals
            total.turnovers += stats.turnovers
            return total
        }
    }

    private var totalMinutes: Double {
        if isFixedPeriodMode {
            return 0
        }
        return filteredGames.reduce(0) { $0 + ($1.snapshot.playingSecondsByPlayerID[playerID, default: 0] / 60) }
    }

    private var totalPlusMinus: Int {
        if isFixedPeriodMode {
            return 0
        }
        return filteredGames.reduce(0) { $0 + $1.snapshot.plusMinusByPlayerID[playerID, default: 0] }
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
            (.totalBlocks, "\(stats.blocks)"),
            (.totalSteals, "\(stats.steals)"),
            (.totalTurnovers, "\(stats.turnovers)"),
            (.totalStarterGames, "\(starterGameCount)"),
            (.totalBenchGames, "\(benchGameCount)"),
            (.totalMinutes, isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)),
            (.totalPlusMinus, isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")),
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
            (.averageBlocks, average(stats.blocks, games)),
            (.averageSteals, average(stats.steals, games)),
            (.averageTurnovers, average(stats.turnovers, games)),
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
        return parts.isEmpty ? localized("player_profile_missing_basic") : parts.joined(separator: " · ")
    }

    private func containsPlayer(in game: SavedGame) -> Bool {
        game.didParticipate(playerID)
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

    private func rebuildFixedGameAnalysisIfNeeded() {
        guard let fixedGame else {
            fixedGameAnalysis = SavedGamePeriodAnalysis()
            selectedPeriod = nil
            return
        }

        let analyzer = SavedGameAnalyzer(game: fixedGame) { name in
            if let localID = fixedGame.playerNamesByID.first(where: { $0.value == name })?.key {
                return localID
            }
            return store.players.first(where: { $0.name == name })?.id
        }
        fixedGameAnalysis = analyzer.analyze()
    }
}

private struct PlayerGameSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    var games: [SavedGame]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(LocalizedStringKey("text_no_selectable_games"), systemImage: "clock.badge.questionmark")
            }

            ForEach(monthGroups) { group in
                DisclosureGroup {
                    HStack {
                        Button(allSelected(in: group.games) ? localized("button_clear_month") : localized("button_select_month")) {
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
        .navigationTitle(LocalizedStringKey("button_choose_games"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizedStringKey("button_clear_all")) {
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("button_select_all")) {
                    selectedIDs = Set(games.map(\.id))
                }
                .disabled(games.isEmpty || selectedIDs.count == games.count)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(LocalizedStringKey("button_done")) { dismiss() }
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
    var title: String { localizedFormat("month_title_format", key.year, key.month) }
}
