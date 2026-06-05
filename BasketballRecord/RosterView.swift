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
    @State private var isShowingPurchase = false

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

                Section(LocalizedStringKey("settings_section_data_management")) {
                    NavigationLink {
                        GameGroupManagementView(store: store)
                    } label: {
                        settingsRow(
                            title: LocalizedStringKey("game_group_nav_title"),
                            systemImage: "folder.fill",
                            countText: "\(store.gameGroups.count)"
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
                    .disabled(!store.isPro)
                    .overlay {
                        if !store.isPro {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { isShowingPurchase = true }
                        }
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

                    settingsRow(
                        title: LocalizedStringKey("settings_version"),
                        systemImage: "info.circle.fill",
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
                AISettingsView()
            }
            .sheet(isPresented: $isShowingPurchase) {
                ProSubscribeView()
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

private struct ProSubscribeView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [SettingsFeatureSection] = [
        SettingsFeatureSection(icon: "folder.fill", title: localized("game_group_nav_title"), items: [
            SettingsFeatureItem(localized("pro_feature_groups_1"), ""),
        ]),
        SettingsFeatureSection(icon: "dot.radiowaves.left.and.right", title: localized("settings_bluetooth_sync"), items: [
            SettingsFeatureItem(localized("pro_feature_bluetooth_1"), ""),
            SettingsFeatureItem(localized("pro_feature_bluetooth_2"), ""),
        ]),
        SettingsFeatureSection(icon: "icloud.fill", title: localized("settings_cloud_storage"), items: [
            SettingsFeatureItem(localized("pro_feature_cloud_1"), ""),
            SettingsFeatureItem(localized("pro_feature_cloud_2"), ""),
        ]),
        SettingsFeatureSection(icon: "sparkles", title: localized("settings_ai"), items: [
            SettingsFeatureItem(localized("pro_feature_ai_1"), ""),
            SettingsFeatureItem(localized("pro_feature_ai_2"), ""),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey("section_pro"))
                                .font(.headline)
                            Text(LocalizedStringKey("pro_description"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(features) { section in
                            featureSectionView(section)
                        }
                    }
                    .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        if let product = PurchaseManager.shared.yearlyProduct {
                            Button {
                                Task { try? await PurchaseManager.shared.purchase(product) }
                            } label: {
                                HStack {
                                    Text(LocalizedStringKey("button_subscribe_yearly"))
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(product.displayPrice)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.large)
                        }

                        if let product = PurchaseManager.shared.monthlyProduct {
                            Button {
                                Task { try? await PurchaseManager.shared.purchase(product) }
                            } label: {
                                HStack {
                                    Text(LocalizedStringKey("button_subscribe_monthly"))
                                    Spacer()
                                    Text(product.displayPrice)
                                }
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            .controlSize(.large)
                        }

                        Button(LocalizedStringKey("button_restore")) {
                            Task { await PurchaseManager.shared.restore() }
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)

                        Text(LocalizedStringKey("subscription_auto_renew_info"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        HStack(spacing: 16) {
                            Link(destination: URL(string: "https://github.com/13098806890/BasketballRecord/blob/main/docs/appstore/privacy-policy.html")!) {
                                Text(LocalizedStringKey("link_privacy_policy"))
                                    .font(.caption)
                            }
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Link(destination: URL(string: "https://github.com/13098806890/BasketballRecord/blob/main/docs/appstore/terms-of-use.html")!) {
                                Text(LocalizedStringKey("link_terms_of_eula"))
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle(LocalizedStringKey("section_pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("button_close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func featureSectionView(_ section: SettingsFeatureSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 22)

                Text(section.title)
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(section.items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)

                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 30)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ai_selected_provider") private var selectedProviderRaw = AIProvider.deepseek.rawValue
    @AppStorage("ai_selected_model_id") private var selectedModelID = AIProvider.defaultModel.id

    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var hasSavedKey = false
    @State private var statusMessage = ""
    @State private var statusKind: StatusKind = .neutral

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .deepseek
    }

    private var availableModels: [AIModel] {
        selectedProvider.models
    }

    private var selectedModel: AIModel {
        availableModels.first { $0.id == selectedModelID } ?? availableModels.first ?? AIProvider.defaultModel
    }

    private enum StatusKind {
        case neutral, success, error
    }

    private var normalizedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedKey.isEmpty && testedKey == normalizedKey
    }

    @State private var testedKey: String?

    private var statusColor: Color {
        switch statusKind {
        case .neutral: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(LocalizedStringKey("label_ai_provider"), selection: $selectedProviderRaw) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .onChange(of: selectedProviderRaw) { _, newValue in
                        let provider = AIProvider(rawValue: newValue) ?? .deepseek
                        if !provider.models.contains(where: { $0.id == selectedModelID }) {
                            selectedModelID = provider.models.first?.id ?? ""
                        }
                        loadSavedKey()
                    }

                    Picker(LocalizedStringKey("label_ai_model"), selection: $selectedModelID) {
                        ForEach(availableModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }

                    SecureField(LocalizedStringKey("field_ai_api_key"), text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, _ in
                            if testedKey != normalizedKey { testedKey = nil }
                        }

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting { ProgressView() }
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
                    Text(LocalizedStringKey("settings_section_ai_config"))
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
            .navigationTitle(LocalizedStringKey("settings_ai"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .onAppear { loadSavedKey() }
        }
    }

    private var statusIcon: String {
        switch statusKind {
        case .neutral: return hasSavedKey ? "checkmark.seal" : "info.circle"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        if !statusMessage.isEmpty { return statusMessage }
        return hasSavedKey
            ? NSLocalizedString("deepseek_status_has_saved_key", comment: "Saved key")
            : NSLocalizedString("deepseek_status_no_saved_key", comment: "No key")
    }

    private func loadSavedKey() {
        if let saved = AIKeychain.shared.loadAPIKey(for: selectedProvider), !saved.isEmpty {
            apiKey = saved
            hasSavedKey = true
            statusMessage = NSLocalizedString("deepseek_status_loaded_saved_key", comment: "Loaded saved key")
            statusKind = .neutral
        } else {
            apiKey = ""
            hasSavedKey = false
            statusMessage = ""
            statusKind = .neutral
        }
    }

    private func testConnection() {
        guard !normalizedKey.isEmpty else { return }
        isTesting = true
        statusMessage = NSLocalizedString("deepseek_testing", comment: "Testing")
        statusKind = .neutral
        Task {
            do {
                try await AIService.shared.testConnection(model: selectedModel, apiKey: normalizedKey)
                await MainActor.run {
                    testedKey = normalizedKey
                    isTesting = false
                    statusMessage = NSLocalizedString("deepseek_test_success", comment: "Success")
                    statusKind = .success
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    statusKind = .error
                }
            }
        }
    }

    private func saveKey() {
        do {
            try AIKeychain.shared.saveAPIKey(normalizedKey, for: selectedProvider)
            hasSavedKey = true
            statusMessage = NSLocalizedString("deepseek_key_saved", comment: "Saved")
            statusKind = .success
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusKind = .error
        }
    }

    private func removeSavedKey() {
        do {
            try AIKeychain.shared.removeAPIKey(for: selectedProvider)
            apiKey = ""
            hasSavedKey = false
            testedKey = nil
            statusMessage = NSLocalizedString("deepseek_key_removed", comment: "Removed")
            statusKind = .neutral
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusKind = .error
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
                    icon: "folder.fill",
                    title: localized("settings_doc_help_groups_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_groups_item1_title"), localized("settings_doc_help_groups_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_groups_item2_title"), localized("settings_doc_help_groups_item2_desc")),
                    ]
                ),
                SettingsFeatureSection(
                    icon: "basketball",
                    title: localized("settings_doc_help_gamelog_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item1_title"), localized("settings_doc_help_gamelog_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item2_title"), localized("settings_doc_help_gamelog_item2_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item3_title"), localized("settings_doc_help_gamelog_item3_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_gamelog_item4_title"), localized("settings_doc_help_gamelog_item4_desc")),
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
                    icon: "icloud.fill",
                    title: localized("settings_doc_help_cloud_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_cloud_item1_title"), localized("settings_doc_help_cloud_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_cloud_item2_title"), localized("settings_doc_help_cloud_item2_desc")),
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
                ),
                SettingsFeatureSection(
                    icon: "crown.fill",
                    title: localized("settings_doc_help_pro_title"),
                    items: [
                        SettingsFeatureItem(localized("settings_doc_help_pro_item1_title"), localized("settings_doc_help_pro_item1_desc")),
                        SettingsFeatureItem(localized("settings_doc_help_pro_item2_title"), localized("settings_doc_help_pro_item2_desc")),
                    ]
                ),
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
    @Binding var selectedGroupID: UUID?
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

                    if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(group.name)
                                    .font(.headline)
                            }
                            Spacer()
                            Button(action: { selectedGroupID = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }

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


                if fixedGame != nil {
                    statSection(localized("label_this_game_stats"), rows: buildGameStatRows())
                } else {
                    statSection(localized("label_career_stats"), rows: buildCareerStatRows())
                    statSection(localized("label_average_stats"), rows: buildAverageStatRows())
                }

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
                    if let fg = fixedGame, let role = fg.role(of: playerID) {
                        Text(role.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.7), in: Capsule())
                    } else {
                        Text(localizedFormat("count_games_format", filteredGames.count))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.7), in: Capsule())
                    }
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

    private struct StatCell: Identifiable {
        var id: String { label }
        var label: String
        var value: String
    }

    private struct StatRow: Identifiable {
        var id: String
        var left: StatCell
        var leftSplit: StatCell? = nil
        var right: StatCell? = nil
        var rightSplit: StatCell? = nil
    }

    private func makeStatCard(_ cell: StatCell) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(cell.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(cell.value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.black)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private func statSection(_ title: String, rows: [StatRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if rows.isEmpty {
                Text(LocalizedStringKey("text_no_stats_in_group"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            if let split = row.leftSplit {
                                HStack(spacing: 8) {
                                    makeStatCard(row.left)
                                    makeStatCard(split)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                makeStatCard(row.left)
                                    .frame(maxWidth: .infinity)
                            }
                            if let split = row.rightSplit {
                                HStack(spacing: 8) {
                                    makeStatCard(split)
                                    if let right = row.right {
                                        makeStatCard(right)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            } else if let right = row.right {
                                makeStatCard(right)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private enum StatCardStyle {
        case game, career, average
    }

    private func buildStatRows(style: StatCardStyle) -> [StatRow] {
        let s = totalStats
        let games = max(1, filteredGames.count)
        let pct = { percent($0) }

        let mins: String
        let pm: String
        let avg: ((Int) -> String)?

        switch style {
        case .game:
            mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
            pm = isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")
            avg = nil
        case .career:
            mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
            pm = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
            avg = nil
        case .average:
            mins = String(format: "%.1f", totalMinutes / Double(games))
            pm = String(format: "%.1f", Double(totalPlusMinus) / Double(games))
            avg = { v in String(format: "%.1f", Double(v) / Double(games)) }
        }

        let pts = StatCell(label: localized("stats_points_format_short"), value: avg?(s.points) ?? "\(s.points)")
        let min = StatCell(label: localized("stats_minutes"), value: mins)
        let reb = StatCell(label: localized("stats_rebound_assist_steal_block"), value: "\(avg?(s.rebounds) ?? "\(s.rebounds)") / \(avg?(s.assists) ?? "\(s.assists)") / \(avg?(s.steals) ?? "\(s.steals)") / \(avg?(s.blocks) ?? "\(s.blocks)")")
        let foul = StatCell(label: localized("stats_foul_turnover") + " / " + localized("stats_plus_minus"), value: "\(avg?(s.fouls) ?? "\(s.fouls)") / \(avg?(s.turnovers) ?? "\(s.turnovers)") / \(pm)")
        let fg = StatCell(label: localized("stats_shooting"), value: "\(avg?(s.made) ?? "\(s.made)")/\(avg?(s.attempts) ?? "\(s.attempts)")\n\(pct(s.fieldGoalRate))")
        let ft = StatCell(label: localized("stat_label_free_throw"), value: "\(avg?(s.allFreeThrowMade) ?? "\(s.allFreeThrowMade)")/\(avg?(s.allFreeThrowAttempts) ?? "\(s.allFreeThrowAttempts)")\n\(pct(s.freeThrowRate))")
        let two = StatCell(label: localized("stat_label_2pt"), value: "\(avg?(s.twoMade) ?? "\(s.twoMade)")/\(avg?(s.twoAttempts) ?? "\(s.twoAttempts)")\n\(pct(s.twoPointRate))")
        let three = StatCell(label: localized("stat_label_3pt"), value: "\(avg?(s.threeMade) ?? "\(s.threeMade)")/\(avg?(s.threeAttempts) ?? "\(s.threeAttempts)")\n\(pct(s.threePointRate))")
        let efg = StatCell(label: "eFG / TS", value: "\(pct(s.effectiveFieldGoalRate)) / \(pct(s.trueShootingRate))")
        let pps = StatCell(label: NSLocalizedString("stats_points_per_shot", comment: "PTS/FGA"), value: String(format: "%.2f", s.pointsPerShot))

        switch style {
        case .game:
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, right: reb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: foul, right: pps, rightSplit: efg),
            ]
        case .career:
            let sb = StatCell(label: "\(localized("stats_games")) / \(localized("stat_label_starter")) / \(localized("stat_label_bench"))", value: "\(filteredGames.count) / \(starterGameCount) / \(benchGameCount)")
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, rightSplit: sb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: reb, right: foul),
                StatRow(id: "row4", left: efg, leftSplit: pps),
            ]
        case .average:
            let sb = StatCell(label: "\(localized("stats_games")) / \(localized("stat_label_starter")) / \(localized("stat_label_bench"))", value: "\(filteredGames.count) / \(starterGameCount) / \(benchGameCount)")
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, rightSplit: sb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: reb, right: foul),
            ]
        }
    }

    private func buildGameStatRows() -> [StatRow] { buildStatRows(style: .game) }
    private func buildCareerStatRows() -> [StatRow] { buildStatRows(style: .career) }
    private func buildAverageStatRows() -> [StatRow] { buildStatRows(style: .average) }

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
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredPlayerLogs) { log in
                            Text(GameLogFormatter.lineText(for: log))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(GameLogFormatter.isScoring(log) ? Color.blue : Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(.horizontal)
    }

    private var allPlayerGames: [SavedGame] {
        let games = store.savedGames
            .filter { containsPlayer(in: $0) }
            .sorted { $0.savedAt > $1.savedAt }

        if store.isPro, let selectedGroupID = selectedGroupID {
            return games.filter { $0.groupIDs.contains(selectedGroupID) }
        }
        return games
    }

    private var selectionSummaryText: String {
        "\(selectedGameIDs.count)/\(allPlayerGames.count)"
    }

    private var filteredGames: [SavedGame] {
        if let fixedGame {
            let participates = containsPlayer(in: fixedGame)
            return participates ? [fixedGame] : []
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

    private struct PlayerStatsGroup {
        let totalStats: PlayerStats
        let totalMinutes: Double
        let totalPlusMinus: Int
        let starterGameCount: Int
        let benchGameCount: Int
    }

    private var statsGroup: PlayerStatsGroup {
        computeStatsGroup(for: filteredGames)
    }

    private func computeStatsGroup(for games: [SavedGame]) -> PlayerStatsGroup {
        if let selectedPeriod, fixedGame != nil {
            let stats = fixedGameAnalysis.statsByPlayerID(for: selectedPeriod)[playerID, default: PlayerStats()]
            return PlayerStatsGroup(totalStats: stats, totalMinutes: 0, totalPlusMinus: 0, starterGameCount: 0, benchGameCount: 0)
        }

        var total = PlayerStats()
        var minutes: Double = 0
        var plusMinus: Int = 0
        var starter = 0
        var bench = 0

        for game in games {
            let raw = game.snapshot.statsByPlayerID[playerID] ?? PlayerStats()
            total.twoMade += raw.twoMade
            total.twoAttempts += raw.twoAttempts
            total.threeMade += raw.threeMade
            total.threeAttempts += raw.threeAttempts
            total.bonusFreeThrowMade += raw.bonusFreeThrowMade
            total.bonusFreeThrowAttempts += raw.bonusFreeThrowAttempts
            total.freeThrowMade += raw.freeThrowMade
            total.freeThrowAttempts += raw.freeThrowAttempts
            total.rebounds += raw.rebounds
            total.assists += raw.assists
            total.fouls += raw.fouls
            total.blocks += raw.blocks
            total.steals += raw.steals
            total.turnovers += raw.turnovers
            minutes += game.snapshot.playingSecondsByPlayerID[playerID, default: 0] / 60
            plusMinus += game.snapshot.plusMinusByPlayerID[playerID, default: 0]
            let role = game.role(of: playerID)
            if role == .starter { starter += 1 }
            else if role == .bench { bench += 1 }
        }

        return PlayerStatsGroup(totalStats: total, totalMinutes: minutes, totalPlusMinus: plusMinus, starterGameCount: starter, benchGameCount: bench)
    }

    private var totalStats: PlayerStats { statsGroup.totalStats }
    private var totalMinutes: Double { isFixedPeriodMode ? 0 : statsGroup.totalMinutes }
    private var totalPlusMinus: Int { isFixedPeriodMode ? 0 : statsGroup.totalPlusMinus }
    private var starterGameCount: Int { statsGroup.starterGameCount }
    private var benchGameCount: Int { statsGroup.benchGameCount }

    private var totalValues: [(String, String)] {
        let stats = totalStats
        let misc = "\(stats.rebounds) / \(stats.assists) / \(stats.steals) / \(stats.blocks)"
        let fouls = "\(stats.fouls) / \(stats.turnovers)"
        let mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
        let items: [(String, String)] = [
            (localized("stats_pts_min"), "\(stats.points) / \(mins)"),
            (localized("stats_rebound_assist_steal_block"), misc),
            (localized("stats_foul_turnover"), fouls),
            (localized("stats_starter_bench"), "\(starterGameCount) / \(benchGameCount)"),
            (localized("stats_plus_minus"), isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")),
            (localized("stats_shooting"), "\(stats.made)/\(stats.attempts)  \(percent(stats.fieldGoalRate))"),
            (localized("stat_label_2pt"), "\(stats.twoMade)/\(stats.twoAttempts)  \(percent(stats.twoPointRate))"),
            (localized("stat_label_3pt"), "\(stats.threeMade)/\(stats.threeAttempts)  \(percent(stats.threePointRate))"),
            (localized("stat_label_free_throw"), "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  \(percent(stats.freeThrowRate))"),
            ("eFG / TS", "\(percent(stats.effectiveFieldGoalRate)) / \(percent(stats.trueShootingRate))"),
        ]
        return items
    }

    private var careerSummaryValues: [(String, String)] {
        let stats = totalStats
        let games = filteredGames.count
        let mins = isFixedPeriodMode ? "--" : String(format: "%.1f", totalMinutes)
        let pmText = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
        return [
            ("\(localized("label_games_count"))", "\(games) (\(localized("stat_label_starter")) \(starterGameCount)/\(localized("stat_label_bench")) \(benchGameCount))"),
            ("\(localized("stats_pts_min"))", "\(stats.points) / \(mins)"),
            ("\(localized("stats_field_goal"))", "\(stats.made)/\(stats.attempts)  \(percent(stats.fieldGoalRate))"),
            ("\(localized("stat_label_2pt"))", "\(stats.twoMade)/\(stats.twoAttempts)  \(percent(stats.twoPointRate))"),
            ("\(localized("stat_label_3pt"))", "\(stats.threeMade)/\(stats.threeAttempts)  \(percent(stats.threePointRate))"),
            ("\(localized("stat_label_free_throw"))", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  \(percent(stats.freeThrowRate))"),
            ("\(localized("stats_plus_minus"))", pmText),
            ("\(localized("stats_rebound_assist_steal_block"))", "\(stats.rebounds) / \(stats.assists) / \(stats.steals) / \(stats.blocks)"),
            ("\(localized("stats_foul_turnover"))", "\(stats.fouls) / \(stats.turnovers)"),
        ]
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

    private var averageCardValues: [(String, String)] {
        let stats = totalStats
        let games = max(1, filteredGames.count)
        let avg = { (val: Int) -> String in String(format: "%.1f", Double(val) / Double(games)) }
        let misc = "\(avg(stats.rebounds)) / \(avg(stats.assists)) / \(avg(stats.steals)) / \(avg(stats.blocks))"
        let fouls = "\(avg(stats.fouls)) / \(avg(stats.turnovers))"
        let avgMin = String(format: "%.1f", totalMinutes / Double(games))
        return [
            (localized("stats_pts_min"), "\(avg(stats.points)) / \(avgMin)"),
            (localized("stats_rebound_assist_steal_block"), misc),
            (localized("stats_foul_turnover"), fouls),
            (localized("stats_shooting"), "\(avg(stats.made))/\(avg(stats.attempts))  \(percent(stats.fieldGoalRate))"),
            (localized("stat_label_2pt"), "\(avg(stats.twoMade))/\(avg(stats.twoAttempts))  \(percent(stats.twoPointRate))"),
            (localized("stat_label_3pt"), "\(avg(stats.threeMade))/\(avg(stats.threeAttempts))  \(percent(stats.threePointRate))"),
            (localized("stat_label_free_throw"), "\(avg(stats.allFreeThrowMade))/\(avg(stats.allFreeThrowAttempts))  \(percent(stats.freeThrowRate))"),
            (localized("stats_plus_minus"), String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
        ]
    }

    private var advancedValues: [(String, String)] {
        let stats = totalStats
        let efg = percent(stats.effectiveFieldGoalRate)
        let ts = percent(stats.trueShootingRate)
        return [
            ("eFG / TS", "\(efg) / \(ts)"),
            (NSLocalizedString("stats_points_per_shot", comment: "PTS/FGA"), String(format: "%.2f", stats.pointsPerShot))
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
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var games: [SavedGame]
    @Binding var selectedIDs: Set<UUID>
    @State private var selectedGroupID: UUID? = nil

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(LocalizedStringKey("text_no_selectable_games"), systemImage: "clock.badge.questionmark")
            }

            if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: { selectedGroupID = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
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
            if store.isPro {
                ToolbarItem(placement: .topBarLeading) {
                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                }
            }

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
        
        // Filter games by selected group if any (Pro only)
        let filteredGames = (store.isPro ? selectedGroupID.map { groupID in
            games.filter { $0.groupIDs.contains(groupID) }
        } : nil) ?? games
        
        let grouped = Dictionary(grouping: filteredGames) { game in
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


struct CollaborativeGameListView: View {
    @EnvironmentObject private var store: AppStore

    private var games: [SavedGame] {
        store.savedGames.filter { $0.snapshot.wasBluetoothCollaborated }
            .sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_bluetooth_games"), systemImage: "dot.radiowaves.left.and.right")
            }
            ForEach(games) { game in
                NavigationLink {
                    SavedGameDetailView(game: game)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(game.homeTeamName) vs \(game.awayTeamName)")
                            .font(.headline)
                        Text(Self.dateFormatter.string(from: game.savedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_bluetooth_games"))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

struct CloudStorageView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var isSyncing = false
    @State private var expandedCloudSections: Set<String> = []
    @State private var expandedLocalSections: Set<String> = []
    @State private var cloudOnlyGames: [SavedGame] = []

    private var cloudGames: [SavedGame] {
        store.savedGames.filter { store.cloudEnabledGameIDs.contains($0.id) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var localOnlyGames: [SavedGame] {
        store.savedGames.filter { !store.cloudEnabledGameIDs.contains($0.id) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var allGroups: [GameGroup] { store.gameGroups }

    var body: some View {
        List {
            Section {
                Text(LocalizedStringKey("cloud_storage_description"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    sync()
                } label: {
                    HStack {
                        if isSyncing || cloudKit.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(LocalizedStringKey(isSyncing ? "cloud_syncing" : "cloud_sync_now"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSyncing || cloudKit.isSyncing)

                if let error = cloudKit.lastSyncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            let cloudSubs = buildGroupedSections(games: cloudGames)
            if !cloudSubs.isEmpty {
                Section(LocalizedStringKey("section_cloud_enabled")) {
                    ForEach(cloudSubs, id: \.name) { sub in
                        DisclosureGroup(sub.name, isExpanded: Binding(
                            get: { expandedCloudSections.contains(sub.name) },
                            set: { if $0 { expandedCloudSections.insert(sub.name) } else { expandedCloudSections.remove(sub.name) } }
                        )) {
                            ForEach(sub.games) { game in
                                gameRow(game: game, isCloud: true)
                            }
                        }
                    }
                }
            }

            let localSubs = buildGroupedSections(games: localOnlyGames)
            if !localSubs.isEmpty {
                Section(LocalizedStringKey("section_local_only")) {
                    ForEach(localSubs, id: \.name) { sub in
                        DisclosureGroup(sub.name, isExpanded: Binding(
                            get: { expandedLocalSections.contains(sub.name) },
                            set: { if $0 { expandedLocalSections.insert(sub.name) } else { expandedLocalSections.remove(sub.name) } }
                        )) {
                            ForEach(sub.games) { game in
                                gameRow(game: game, isCloud: false)
                            }
                        }
                    }
                }
            }

            if let error = cloudKit.lastSyncError, cloudOnlyGames.isEmpty {
                Section(LocalizedStringKey("section_cloud_only")) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(LocalizedStringKey("cloud_unavailable_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !cloudOnlyGames.isEmpty {
                Section(LocalizedStringKey("section_cloud_only")) {
                    ForEach(cloudOnlyGames) { game in
                        HStack {
                            gameRow(game: game, isCloud: true)
                            Button {
                                store.downloadFromCloud(game)
                                refreshCloudOnly()
                            } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_cloud_storage"))
        .onAppear { refreshCloudOnly() }
        .onChange(of: store.savedGames.count) { _, _ in refreshCloudOnly() }
    }

    private func refreshCloudOnly() {
        Task {
            let allCloud = await CloudKitManager.shared.fetchGames(ids: store.cloudEnabledGameIDs)
            let localIDs = Set(store.savedGames.map(\.id))
            cloudOnlyGames = allCloud.filter { !localIDs.contains($0.id) }
        }
    }

    private struct GameSubSection {
        var name: String
        var games: [SavedGame]
    }

    private func buildGroupedSections(games: [SavedGame]) -> [GameSubSection] {
        var remaining = Set(games.map(\.id))
        var subs: [GameSubSection] = []

        for group in allGroups {
            let groupGames = games.filter { $0.groupIDs.contains(group.id) }
            if !groupGames.isEmpty {
                subs.append(GameSubSection(name: group.name, games: groupGames))
                for g in groupGames { remaining.remove(g.id) }
            }
        }

        let ungrouped = games.filter { remaining.contains($0.id) }
        if !ungrouped.isEmpty {
            subs.append(GameSubSection(name: NSLocalizedString("game_group_ungrouped", comment: "Ungrouped"), games: ungrouped))
        }

        return subs
    }

    private func gameRow(game: SavedGame, isCloud: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayTitle)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: game.savedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(scoreLine(for: game))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: isCloud ? "icloud.fill" : "icloud.slash")
                .foregroundStyle(isCloud ? .blue : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.toggleCloudStorage(for: game.id)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        let homeScore = game.homePlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
        let awayScore = game.awayPlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
        return "\(homeScore) - \(awayScore)"
    }

    private func sync() {
        isSyncing = true
        Task {
            await store.syncCloudGames()
            refreshCloudOnly()
            isSyncing = false
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}
