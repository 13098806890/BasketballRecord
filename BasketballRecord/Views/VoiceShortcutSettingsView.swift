import SwiftUI

struct VoiceShortcutSettingsView: View {
    @ObservedObject var store: AppStore
    @State private var newPhrase = ""
    @State private var newEvent = StatAction.twoMade
    @State private var showingAdd = false
    @State private var editingPhrase = ""
    @State private var showingEdit = false

    private let shotActions: [StatAction] = [
        .twoMade, .twoMissed, .threeMade, .threeMissed,
        .layupMade, .layupMissed, .midRangeMade, .midRangeMissed,
        .paintMade, .paintMissed, .freeThrowMade, .freeThrowMissed,
        .bonusMade, .bonusMissed,
    ]

    private let statActions: [StatAction] = [
        .foul, .assist, .rebound, .block, .steal, .turnover,
    ]

    private func icon(for action: StatAction) -> String {
        switch action {
        case .twoMade, .twoMissed: return "2.circle"
        case .threeMade, .threeMissed: return "3.circle"
        case .layupMade, .layupMissed: return "arrow.up.forward.circle"
        case .midRangeMade, .midRangeMissed: return "circle.dotted"
        case .paintMade, .paintMissed: return "square.filled.on.square"
        case .freeThrowMade, .freeThrowMissed: return "1.circle"
        case .bonusMade, .bonusMissed: return "plus.circle"
        case .foul: return "exclamationmark.triangle"
        case .assist: return "hand.raised"
        case .rebound: return "arrow.up.circle"
        case .block: return "shield.lefthalf.filled"
        case .steal: return "hand.raised.fill"
        case .turnover: return "arrow.triangle.2.circlepath"
        }
    }

    var body: some View {
        List {
            if store.customVoiceMappings.isEmpty {
                Section {
                    ContentUnavailableView(
                        LocalizedStringKey("voice_shortcuts_empty"),
                        systemImage: "waveform.and.mic",
                        description: Text(LocalizedStringKey("voice_shortcuts_empty_desc"))
                    )
                }
            }

            Section(LocalizedStringKey("voice_shortcuts_custom")) {
                ForEach(Array(store.customVoiceMappings.sorted(by: { $0.key < $1.key })), id: \.key) { phrase, code in
                    Button {
                        editingPhrase = phrase
                        newPhrase = phrase
                        newEvent = StatAction(eventCode: code) ?? .twoMade
                        showingEdit = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: StatAction(eventCode: code) ?? .twoMade))
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(phrase)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(actionLabel(for: code))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.customVoiceMappings.removeValue(forKey: phrase)
                        } label: {
                            Label(LocalizedStringKey("common_delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_voice_shortcuts"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newPhrase = ""
                    newEvent = .twoMade
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            editSheet(title: LocalizedStringKey("voice_shortcuts_add_title"), isNew: true)
        }
        .sheet(isPresented: $showingEdit) {
            editSheet(title: LocalizedStringKey("voice_shortcuts_edit_title"), isNew: false)
        }
    }

    private func editSheet(title: LocalizedStringKey, isNew: Bool) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LocalizedStringKey("voice_shortcuts_phrase_placeholder"), text: $newPhrase)
                } footer: {
                    Text(LocalizedStringKey("voice_shortcuts_phrase_footer"))
                }

                Section(LocalizedStringKey("voice_shortcuts_shot_section")) {
                    Picker(LocalizedStringKey("voice_shortcuts_action"), selection: $newEvent) {
                        ForEach(shotActions, id: \.self) { action in
                            Text(NSLocalizedString(action.messageKey, comment: "")).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(LocalizedStringKey("voice_shortcuts_stat_section")) {
                    Picker(LocalizedStringKey("voice_shortcuts_action"), selection: $newEvent) {
                        ForEach(statActions, id: \.self) { action in
                            Text(NSLocalizedString(action.messageKey, comment: "")).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common_cancel")) {
                        showingAdd = false
                        showingEdit = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("common_save")) {
                        let trimmed = newPhrase.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        if !isNew, editingPhrase != trimmed {
                            store.customVoiceMappings.removeValue(forKey: editingPhrase)
                        }
                        store.customVoiceMappings[trimmed] = newEvent.eventCode
                        showingAdd = false
                        showingEdit = false
                    }
                    .disabled(newPhrase.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func actionLabel(for code: String) -> String {
        if let action = StatAction.allCases.first(where: { $0.eventCode == code }) {
            return NSLocalizedString(action.messageKey, comment: "")
        }
        return code
    }
}

extension StatAction {
    init?(eventCode: String) {
        for action in StatAction.allCases where action.eventCode == eventCode {
            self = action
            return
        }
        return nil
    }
}
