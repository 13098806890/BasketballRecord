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
    @State private var showingDeepSeekConfig = false
    @State private var showingSettingsDocument: SettingsDocument?
    @State private var isShowingPurchase = false
    @State private var isShowingLanguageInfo = false
#if DEBUG
    @State private var rosterRecoveryMessage: String?
#endif

    @AppStorage(UnitSettings.heightUnitKey) private var heightRaw: String = ""
    @AppStorage(UnitSettings.weightUnitKey) private var weightRaw: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                EditorialBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey("settings_nav_title"))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialDesign.navy)
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)

                        settingsSectionHeader("settings_section_game_prefs")
                        settingsCard {
                            settingsToggleRow(
                                title: LocalizedStringKey("settings_keep_screen_awake"),
                                systemImage: "sun.max",
                                isOn: $store.keepsScreenAwake
                            )
                            settingsDivider()
                            settingsToggleRow(
                                title: LocalizedStringKey("settings_show_bluetooth_button"),
                                systemImage: "dot.radiowaves.left.and.right",
                                isOn: $store.showsBluetoothGamesButton
                            )
                            settingsDivider()
                            NavigationLink {
                                VoiceSettingsView(store: store)
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_voice"),
                                    systemImage: "waveform.circle.fill",
                                    countText: nil,
                                    iconColor: EditorialDesign.orange,
                                    showsDisclosure: true
                                )
                            }
                            .buttonStyle(.plain)
                            settingsDivider()
                            NavigationLink {
                                CloudStorageView()
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_cloud_storage"),
                                    systemImage: "icloud.fill",
                                    countText: "\(store.cloudEnabledGameIDs.count)",
                                    iconColor: EditorialDesign.paleOrange,
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

                        settingsSectionHeader("settings_section_units")
                        settingsCard {
                            let heightBinding = Binding(
                                get: { HeightUnit(rawValue: heightRaw) ?? UnitSettings.defaultHeightUnit },
                                set: { heightRaw = $0.rawValue }
                            )
                            let weightBinding = Binding(
                                get: { WeightUnit(rawValue: weightRaw) ?? UnitSettings.defaultWeightUnit },
                                set: { weightRaw = $0.rawValue }
                            )

                            HStack(spacing: 12) {
                                Image(systemName: "ruler")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(EditorialDesign.navy)
                                    .frame(width: 28, height: 28)

                                Text(LocalizedStringKey("label_height"))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(EditorialDesign.navy)

                                Spacer()

                                Picker("", selection: heightBinding) {
                                    ForEach(HeightUnit.allCases, id: \.rawValue) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(EditorialDesign.blue)
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .contentShape(Rectangle())
                            settingsDivider()
                            HStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(EditorialDesign.navy)
                                    .frame(width: 28, height: 28)

                                Text(LocalizedStringKey("label_weight"))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(EditorialDesign.navy)

                                Spacer()

                                Picker("", selection: weightBinding) {
                                    ForEach(WeightUnit.allCases, id: \.rawValue) { unit in
                                        Text(unit.displayName).tag(unit)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(EditorialDesign.blue)
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .contentShape(Rectangle())
                        }

                        settingsCard {
                            Button {
                                isShowingPurchase = true
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("section_pro"),
                                    systemImage: "crown.fill",
                                    countText: nil,
                                    iconColor: EditorialDesign.orange,
                                    showsDisclosure: true
                                )
                            }
                            .buttonStyle(.plain)
                            settingsDivider()
                            NavigationLink {
                                SettingsSyncImportView()
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_section_sync_import"),
                                    systemImage: "arrow.up.arrow.down",
                                    countText: nil,
                                    iconColor: EditorialDesign.orange,
                                    showsDisclosure: true
                                )
                            }
                            .buttonStyle(.plain)
                            settingsDivider()
                            Button {
                                isShowingLanguageInfo = true
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_language"),
                                    systemImage: "globe",
                                    countText: nil,
                                    iconColor: EditorialDesign.navy,
                                    showsDisclosure: true
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        settingsSectionHeader("settings_section_ai")
                        settingsCard {
                            Button {
                                showingDeepSeekConfig = true
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_ai"),
                                    systemImage: "sparkles",
                                    countText: nil,
                                    iconColor: EditorialDesign.blue,
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

                        settingsSectionHeader("settings_section_help_about")
                        settingsCard {
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
                            settingsDivider()
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
                            settingsDivider()
                            NavigationLink {
                                AboutDeveloperView()
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_contact_developer"),
                                    systemImage: "envelope.fill",
                                    countText: nil,
                                    showsDisclosure: true
                                )
                            }
                            .buttonStyle(.plain)
                            settingsDivider()
                            Button {
                                requestAppReview()
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_rate_app"),
                                    systemImage: "star.fill",
                                    countText: nil,
                                    iconColor: EditorialDesign.orange,
                                    showsDisclosure: false
                                )
                            }
                            .buttonStyle(.plain)
                            settingsDivider()
                            settingsRow(
                                title: LocalizedStringKey("settings_version"),
                                systemImage: "info.circle.fill",
                                countText: appVersionText,
                                showsDisclosure: false
                            )
                        }

#if DEBUG
                        settingsSectionHeader("settings_section_debug")
                        settingsCard {
                            Button {
                                let playerCountBefore = store.players.count
                                let teamCountBefore = store.teams.count
                                store.recoverRosterFromSavedGames()
                                let playersAdded = max(0, store.players.count - playerCountBefore)
                                let teamsAdded = max(0, store.teams.count - teamCountBefore)
                                rosterRecoveryMessage = localizedFormat(
                                    "settings_recover_roster_result",
                                    playersAdded,
                                    teamsAdded,
                                    store.players.count,
                                    store.teams.count
                                )
                            } label: {
                                settingsRow(
                                    title: LocalizedStringKey("settings_recover_roster_from_games"),
                                    systemImage: "arrow.triangle.2.circlepath",
                                    countText: nil,
                                    iconColor: EditorialDesign.orange,
                                    showsDisclosure: false
                                )
                            }
                            .buttonStyle(.plain)

                            if let rosterRecoveryMessage {
                                Text(rosterRecoveryMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 14)
                            }
                        }
#endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .safeAreaPadding(.bottom, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
            .alert(LocalizedStringKey("settings_language_alert_title"), isPresented: $isShowingLanguageInfo) {
                Button(LocalizedStringKey("button_ok"), role: .cancel) { }
            } message: {
                Text(LocalizedStringKey("settings_language_alert_message"))
            }
        }
    }

    private func settingsSectionHeader(_ key: String) -> some View {
        Text(LocalizedStringKey(key))
            .font(.title3.weight(.bold))
            .foregroundStyle(EditorialDesign.navy.opacity(0.62))
            .padding(.top, 8)
            .padding(.horizontal, 12)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 2)
            .editorialCard(tint: Color.white.opacity(0.94), radius: 24)
    }

    private func settingsDivider() -> some View {
        Divider()
            .padding(.leading, 64)
            .overlay(EditorialDesign.divider.opacity(0.45))
    }

    private func settingsToggleRow(
        title: LocalizedStringKey,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(EditorialDesign.navy)

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(EditorialDesign.blue)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version).\(build)"
    }

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
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
                .foregroundStyle(iconColor == .secondary ? EditorialDesign.orange : iconColor)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(EditorialDesign.navy)

            Spacer()

            if let countText {
                Text(countText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(EditorialDesign.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(EditorialDesign.paleBlue, in: Capsule())
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SettingsSyncImportView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingCloudUpload = false
    @State private var showingRosterImport = false
    @State private var showingMergeEntry = false
    @State private var isShowingPurchase = false

    var body: some View {
        List {
            Section(LocalizedStringKey("settings_section_sync_import")) {
                NavigationLink {
                    BluetoothSyncSettingsView()
                } label: {
                    syncImportRow(
                        title: LocalizedStringKey("settings_bluetooth_sync"),
                        systemImage: "dot.radiowaves.left.and.right",
                        showsDisclosure: true
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
                    syncImportRow(
                        title: LocalizedStringKey("cloudshare_upload_button"),
                        systemImage: "icloud.and.arrow.up.fill",
                        showsDisclosure: false
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showingRosterImport = true
                } label: {
                    syncImportRow(
                        title: LocalizedStringKey("settings_import"),
                        systemImage: TransferSymbol.importData,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showingMergeEntry = true
                } label: {
                    syncImportRow(
                        title: LocalizedStringKey("settings_merge"),
                        systemImage: "arrow.triangle.merge",
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .editorialSettingsListStyle()
        .navigationTitle(LocalizedStringKey("settings_section_sync_import"))
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
        .sheet(isPresented: $isShowingPurchase) {
            ProSubscriptionStoreView()
        }
    }

    private func syncImportRow(
        title: LocalizedStringKey,
        systemImage: String,
        showsDisclosure: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(EditorialDesign.orange)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(EditorialDesign.navy)

            Spacer()

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .frame(minHeight: 58)
    }
}

struct RosterActionIcon: View {
    var symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
    }
}

func rosterPlayerSubtitle(_ player: Player) -> String {
    var parts: [String] = []
    if !player.number.isEmpty { parts.append("No. \(player.number)") }
    if !player.height.isEmpty { parts.append(UnitSettings.displayHeight(player.height)) }
    if !player.weight.isEmpty { parts.append(UnitSettings.displayWeight(player.weight)) }
    return parts.isEmpty ? NSLocalizedString("player_profile_missing_basic", comment: "Missing player basics") : parts.joined(separator: " · ")
}
