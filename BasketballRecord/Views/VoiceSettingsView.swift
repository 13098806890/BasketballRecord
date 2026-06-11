import SwiftUI

struct VoiceSettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List {
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
