import SwiftUI

let kVoiceLocaleKey = "voice_locale"

private let voiceLanguages: [(id: String, name: String)] = [
    ("zh-Hans", "简体中文"),
    ("zh-Hant-TW", "繁體中文"),
    ("en", "English"),
    ("ja", "日本語"),
    ("ko", "한국어"),
    ("de", "Deutsch"),
    ("es", "Español"),
    ("fr", "Français"),
    ("it", "Italiano"),
    ("ru", "Русский"),
]

struct VoiceSettingsView: View {
    @ObservedObject var store: AppStore
    @AppStorage(kVoiceLocaleKey) private var voiceLocale: String = ""

    private var effectiveLocale: String {
        voiceLocale.isEmpty ? (Bundle.main.preferredLocalizations.first ?? "en") : voiceLocale
    }

    var body: some View {
        List {
            Section {
                Picker(selection: $voiceLocale) {
                    Text(LocalizedStringKey("settings_voice_locale_follow_app"))
                        .tag("")
                    ForEach(voiceLanguages, id: \.id) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                } label: {
                    Label(LocalizedStringKey("settings_voice_locale"), systemImage: "globe")
                        .foregroundStyle(.primary)
                }
            } footer: {
                Text(LocalizedStringKey("settings_voice_locale_footer"))
            }

            Section {
                NavigationLink {
                    VoiceInstructionView()
                } label: {
                    settingsRow(
                        title: LocalizedStringKey("settings_voice_instruction"),
                        systemImage: "questionmark.circle",
                        countText: nil
                    )
                }

                NavigationLink {
                    VoiceTutorialView(store: store, voiceLocale: effectiveLocale)
                } label: {
                    settingsRow(
                        title: LocalizedStringKey("settings_voice_tutorial"),
                        systemImage: "graduationcap.fill",
                        countText: nil
                    )
                }
            }

            Section {
                Toggle(isOn: $store.showsVoiceButton) {
                    Label(LocalizedStringKey("settings_show_voice_button"), systemImage: "mic.fill")
                        .foregroundStyle(.primary)
                }
            } footer: {
                Text(LocalizedStringKey("settings_show_voice_button_footer"))
            }

            Section {
                Toggle(isOn: $store.voiceLogEnabled) {
                    Label(LocalizedStringKey("settings_voice_log_enable"), systemImage: "doc.text")
                        .foregroundStyle(.primary)
                }
            } footer: {
                Text(LocalizedStringKey("settings_voice_log_enable_footer"))
            }

            Section {
                NavigationLink {
                    VoiceLogView(log: $store.voiceLog)
                } label: {
                    settingsRow(
                        title: LocalizedStringKey("settings_voice_log"),
                        systemImage: "waveform",
                        countText: "\(store.voiceLog.count)"
                    )
                }

                NavigationLink {
                    VoiceShortcutSettingsView(store: store)
                } label: {
                    settingsRow(
                        title: LocalizedStringKey("settings_voice_shortcuts"),
                        systemImage: "waveform.and.mic",
                        countText: "\(store.customVoiceMappings.count)"
                    )
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_voice"))
    }

    private func settingsRow(title: LocalizedStringKey, systemImage: String, countText: String?) -> some View {
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(.systemGray6)))
            }
        }
    }
}
