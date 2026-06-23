import SwiftUI
import StoreKit

struct AboutDeveloperView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .padding(.top, 24)

                let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
                Text(String(format: NSLocalizedString("settings_about_content", comment: ""), appName))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("settings_contact_developer"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct ProSubscriptionStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    private let features: [SettingsFeatureSection] = [
        SettingsFeatureSection(icon: "folder.fill", title: LocalizedStringKey("game_group_nav_title"), items: [
            SettingsFeatureItem(LocalizedStringKey("pro_feature_groups_1"), LocalizedStringKey("")),
        ]),
        SettingsFeatureSection(icon: "dot.radiowaves.left.and.right", title: LocalizedStringKey("settings_bluetooth_sync"), items: [
            SettingsFeatureItem(LocalizedStringKey("pro_feature_bluetooth_1"), LocalizedStringKey("")),
            SettingsFeatureItem(LocalizedStringKey("pro_feature_bluetooth_2"), LocalizedStringKey("")),
        ]),
        SettingsFeatureSection(icon: "icloud.fill", title: LocalizedStringKey("settings_cloud_storage"), items: [
            SettingsFeatureItem(LocalizedStringKey("pro_feature_cloud_1"), LocalizedStringKey("")),
            SettingsFeatureItem(LocalizedStringKey("pro_feature_cloud_2"), LocalizedStringKey("")),
        ]),
        SettingsFeatureSection(icon: "sparkles", title: LocalizedStringKey("settings_ai"), items: [
            SettingsFeatureItem(LocalizedStringKey("pro_feature_ai_1"), LocalizedStringKey("")),
            SettingsFeatureItem(LocalizedStringKey("pro_feature_ai_2"), LocalizedStringKey("")),
        ]),
    ]

    var body: some View {
        let products = [PurchaseManager.shared.yearlyProduct, PurchaseManager.shared.monthlyProduct].compactMap { $0 }
        if products.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text(LocalizedStringKey("text_loading_products"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            SubscriptionStoreView(subscriptions: products) {
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
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(features) { section in
                                featureSectionView(section)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .policies)
            .subscriptionStoreControlStyle(.picker)
            .subscriptionStoreButtonLabel(.multiline)
            .subscriptionStorePolicyDestination(for: .privacyPolicy) {
                SafariWebView(url: URL(string: "https://13098806890.github.io/BasketballRecord/appstore/privacy-policy.html")!)
            }
            .subscriptionStorePolicyDestination(for: .termsOfService) {
                SafariWebView(url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .task { await PurchaseManager.shared.checkSubscriptionStatus() }
        }
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
enum SettingsDocument: String, Identifiable {
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
                    title: LocalizedStringKey("settings_doc_privacy_storage_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_storage_item1_title"), LocalizedStringKey("settings_doc_privacy_storage_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_storage_item2_title"), LocalizedStringKey("settings_doc_privacy_storage_item2_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "network",
                    title: LocalizedStringKey("settings_doc_privacy_network_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_network_item1_title"), LocalizedStringKey("settings_doc_privacy_network_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_network_item2_title"), LocalizedStringKey("settings_doc_privacy_network_item2_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_network_item3_title"), LocalizedStringKey("settings_doc_privacy_network_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "exclamationmark.triangle",
                    title: LocalizedStringKey("settings_doc_privacy_notice_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_notice_item1_title"), LocalizedStringKey("settings_doc_privacy_notice_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_privacy_notice_item2_title"), LocalizedStringKey("settings_doc_privacy_notice_item2_desc"))
                    ]
                )
            ]
        case .terms:
            return [
                SettingsFeatureSection(
                    icon: "play.rectangle",
                    title: LocalizedStringKey("settings_doc_help_quickstart_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_quickstart_item1_title"), LocalizedStringKey("settings_doc_help_quickstart_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_quickstart_item2_title"), LocalizedStringKey("settings_doc_help_quickstart_item2_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_quickstart_item3_title"), LocalizedStringKey("settings_doc_help_quickstart_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "folder.fill",
                    title: LocalizedStringKey("settings_doc_help_groups_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_groups_item1_title"), LocalizedStringKey("settings_doc_help_groups_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_groups_item2_title"), LocalizedStringKey("settings_doc_help_groups_item2_desc")),
                    ]
                ),
                SettingsFeatureSection(
                    icon: "basketball",
                    title: LocalizedStringKey("settings_doc_help_gamelog_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_gamelog_item1_title"), LocalizedStringKey("settings_doc_help_gamelog_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_gamelog_item2_title"), LocalizedStringKey("settings_doc_help_gamelog_item2_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_gamelog_item3_title"), LocalizedStringKey("settings_doc_help_gamelog_item3_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_gamelog_item4_title"), LocalizedStringKey("settings_doc_help_gamelog_item4_desc")),
                    ]
                ),
                SettingsFeatureSection(
                    icon: "dot.radiowaves.left.and.right",
                    title: LocalizedStringKey("settings_doc_help_sync_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_sync_item1_title"), LocalizedStringKey("settings_doc_help_sync_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_sync_item2_title"), LocalizedStringKey("settings_doc_help_sync_item2_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_sync_item3_title"), LocalizedStringKey("settings_doc_help_sync_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "icloud.fill",
                    title: LocalizedStringKey("settings_doc_help_cloud_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_cloud_item1_title"), LocalizedStringKey("settings_doc_help_cloud_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_cloud_item2_title"), LocalizedStringKey("settings_doc_help_cloud_item2_desc")),
                    ]
                ),
                SettingsFeatureSection(
                    icon: "sparkles",
                    title: LocalizedStringKey("settings_doc_help_ai_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_ai_item1_title"), LocalizedStringKey("settings_doc_help_ai_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_ai_item2_title"), LocalizedStringKey("settings_doc_help_ai_item2_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_ai_item3_title"), LocalizedStringKey("settings_doc_help_ai_item3_desc"))
                    ]
                ),
                SettingsFeatureSection(
                    icon: "crown.fill",
                    title: LocalizedStringKey("settings_doc_help_pro_title"),
                    items: [
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_pro_item1_title"), LocalizedStringKey("settings_doc_help_pro_item1_desc")),
                        SettingsFeatureItem(LocalizedStringKey("settings_doc_help_pro_item2_title"), LocalizedStringKey("settings_doc_help_pro_item2_desc")),
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
struct SettingsDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
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
struct SettingsFeatureSection: Identifiable {
    let id: String
    let icon: String
    let title: LocalizedStringKey
    let items: [SettingsFeatureItem]

    init(icon: String, title: LocalizedStringKey, items: [SettingsFeatureItem]) {
        self.id = UUID().uuidString
        self.icon = icon
        self.title = title
        self.items = items
    }
}
struct SettingsFeatureItem: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    init(_ title: LocalizedStringKey, _ description: LocalizedStringKey) {
        self.id = UUID().uuidString
        self.title = title
        self.description = description
    }
}
