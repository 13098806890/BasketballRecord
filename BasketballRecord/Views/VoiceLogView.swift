import SwiftUI

struct VoiceLogView: View {
    @Binding var log: [VoiceLogEntry]
    @State private var showDeleteAll = false

    var body: some View {
        List {
            if log.isEmpty {
                ContentUnavailableView(LocalizedStringKey("voice_log_empty"), systemImage: "waveform")
            }

            ForEach(log, id: \.id) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.isSuccess ? .green : .red)
                            .font(.caption)
                        Text(entry.text)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if entry.isSuccess {
                        HStack(spacing: 4) {
                            if let name = entry.playerName {
                                Text(name)
                                    .font(.caption.weight(.semibold))
                            }
                            if let action = entry.action {
                                Text(action)
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let pinyin = Optional(entry.textPinyin), !pinyin.isEmpty {
                            Text("拼音: \(pinyin)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let detail = entry.matchDetail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = copyText(entry)
                    } label: {
                        Label(LocalizedStringKey("voice_log_copy"), systemImage: "doc.on.doc")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        if let idx = log.firstIndex(where: { $0.id == entry.id }) {
                            log.remove(at: idx)
                        }
                    } label: {
                        Label(LocalizedStringKey("common_delete"), systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_voice_log"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !log.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAll = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .confirmationDialog(LocalizedStringKey("voice_log_delete_all_confirm"), isPresented: $showDeleteAll) {
                        Button(LocalizedStringKey("common_delete"), role: .destructive) {
                            log.removeAll()
                        }
                        Button(LocalizedStringKey("common_cancel"), role: .cancel) {}
                    }

                    Button {
                        let allText = log.map { copyText($0) }.joined(separator: "\n---\n")
                        UIPasteboard.general.string = allText
                    } label: {
                        Label(LocalizedStringKey("voice_log_copy_all"), systemImage: "doc.on.doc.fill")
                    }
                }
            }
        }
    }

    private func copyText(_ entry: VoiceLogEntry) -> String {
        var lines: [String] = []
        let icon = entry.isSuccess ? "✅" : "❌"
        lines.append("\(icon) \(entry.text)")
        lines.append("时间: \(entry.timestamp.formatted(date: .omitted, time: .standard))")
        lines.append("拼音: \(entry.textPinyin)")
        if let name = entry.playerName { lines.append("球员: \(name)") }
        if let action = entry.action { lines.append("动作: \(action)") }
        if let detail = entry.matchDetail { lines.append("详情: \(detail)") }
        return lines.joined(separator: "\n")
    }
}
