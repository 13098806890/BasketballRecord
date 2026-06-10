import SwiftUI

struct VoiceShortcutSettingsView: View {
    @ObservedObject var store: AppStore
    @State private var newPhrase = ""
    @State private var newEvent = "stat.twoMade"
    @State private var showingAdd = false

    let eventOptions: [(label: String, code: String)] = [
        ("两分命中", "stat.twoMade"), ("两分未中", "stat.twoMissed"),
        ("三分命中", "stat.threeMade"), ("三分未中", "stat.threeMissed"),
        ("罚球命中", "stat.freeThrowMade"), ("罚球未中", "stat.freeThrowMissed"),
        ("加罚命中", "stat.bonusMade"), ("加罚未中", "stat.bonusMissed"),
        ("上篮命中", "stat.layupMade"), ("上篮未中", "stat.layupMissed"),
        ("中投命中", "stat.midRangeMade"), ("中投未中", "stat.midRangeMissed"),
        ("篮下命中", "stat.paintMade"), ("篮下未中", "stat.paintMissed"),
        ("犯规", "stat.foul"), ("篮板", "stat.rebound"),
        ("助攻", "stat.assist"), ("盖帽", "stat.block"),
        ("抢断", "stat.steal"), ("失误", "stat.turnover"),
    ]

    var body: some View {
        List {
            if store.customVoiceMappings.isEmpty {
                ContentUnavailableView("暂无自定义指令", systemImage: "waveform.and.mic")
            }

            ForEach(Array(store.customVoiceMappings.sorted(by: { $0.key < $1.key })), id: \.key) { phrase, code in
                HStack {
                    Text(phrase)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(eventLabel(for: code))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.customVoiceMappings.removeValue(forKey: phrase)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("语音快捷指令")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newPhrase = ""
                    newEvent = "stat.twoMade"
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                Form {
                    Section {
                        TextField("说出的指令", text: $newPhrase)
                    }
                    Section {
                        Picker("对应动作", selection: $newEvent) {
                            ForEach(eventOptions, id: \.code) { opt in
                                Text(opt.label).tag(opt.code)
                            }
                        }
                    }
                }
                .navigationTitle("新增指令")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            guard !newPhrase.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            store.customVoiceMappings[newPhrase.trimmingCharacters(in: .whitespaces)] = newEvent
                            showingAdd = false
                        }
                        .disabled(newPhrase.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func eventLabel(for code: String) -> String {
        eventOptions.first(where: { $0.code == code })?.label ?? code
    }
}
