import SwiftUI

struct VoiceLogView: View {
    @Binding var log: [VoiceLogEntry]

    var body: some View {
        List {
            if log.isEmpty {
                ContentUnavailableView("暂无语音记录", systemImage: "waveform")
            }

            ForEach(Array(log.enumerated()), id: \.element.id) { _, entry in
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
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("语音日志")
    }
}
