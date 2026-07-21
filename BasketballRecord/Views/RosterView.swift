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

    @AppStorage("show_badges") private var showBadges = true
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

                    HStack(spacing: 12) {
                        Image(systemName: "medal.fill")
                            .font(.subheadline.weight(.semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)

                        Text(LocalizedStringKey("settings_show_badges"))
                            .font(.body.weight(.medium))

                        Spacer()

                        Toggle("", isOn: $showBadges)
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

