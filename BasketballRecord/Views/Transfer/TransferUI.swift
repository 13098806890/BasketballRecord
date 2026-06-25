import SwiftUI

enum TransferSymbol {
    static let importData = "tray.and.arrow.down.fill"
    static let exportData = "tray.and.arrow.up.fill"
}

struct AppSoftProminentButtonStyle: ButtonStyle {
    private let background = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.30, blue: 0.48, alpha: 1) : UIColor(red: 0.80, green: 0.90, blue: 0.99, alpha: 1)
    })

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .background(background.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}

struct AppNeutralProminentButtonStyle: ButtonStyle {
    private let background = Color(uiColor: .secondarySystemBackground)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
    }
}

struct TransferCodePreview: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .textSelection(.enabled)
    }
}

enum ExportShareMode: String, CaseIterable {
    case text
    case cloud
}

struct CloudShareSection: View {
    let uploadAction: () async throws -> String
    let persistenceKey: String?
    @State private var cloudShareUUID: String?
    @State private var remainingSeconds: Int = 0
    @State private var isVerifying = true
    @State private var isCloudUploading = false
    @State private var cloudError: String?
    @State private var cloudCopied = false

    init(persistenceKey: String? = nil, uploadAction: @escaping () async throws -> String) {
        self.persistenceKey = persistenceKey
        self.uploadAction = uploadAction
    }

    var body: some View {
        Group {
            if isVerifying {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(LocalizedStringKey("cloudshare_uploading"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } header: {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label"))
                }
            } else if let uuid = cloudShareUUID {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)

                        Text(LocalizedStringKey("cloudshare_uuid_title"))
                            .font(.headline)

                        Text(uuid)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        if remainingSeconds > 0 {
                            Text(String(format: NSLocalizedString("cloudshare_expires_format", comment: "Expires format"), formatRemainingTime(remainingSeconds)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            UIPasteboard.general.string = uuid
                            cloudCopied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.2))
                                cloudCopied = false
                            }
                        } label: {
                            Label(
                                cloudCopied ? NSLocalizedString("cloudshare_copied", comment: "") : NSLocalizedString("cloudshare_copy_button", comment: ""),
                                systemImage: cloudCopied ? "checkmark.circle.fill" : "doc.on.doc"
                            )
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label"))
                }
            } else if let error = cloudError {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.icloud.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            cloudError = nil
                            cloudShareUUID = nil
                            isVerifying = false
                        } label: {
                            Text(LocalizedStringKey("button_retry"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label"))
                }
            } else {
                Section {
                    VStack(spacing: 16) {
                        if isCloudUploading {
                            ProgressView()
                                .scaleEffect(1.5)

                            Text(LocalizedStringKey("cloudshare_uploading"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)

                            Text(LocalizedStringKey("cloudshare_upload_button"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isCloudUploading else { return }
                        Task { await upload() }
                    }
                } header: {
                    Text(LocalizedStringKey("cloudshare_picker_cloud_label"))
                }
            }
        }
        .task {
            await checkExistingShare()
        }
    }

    private func checkExistingShare() async {
        guard let key = persistenceKey else {
            isVerifying = false
            return
        }
        let defaults = UserDefaults.standard
        guard let savedUUID = defaults.string(forKey: key) else {
            isVerifying = false
            return
        }
        do {
            let (exists, remaining) = try await CloudShareManager.check(uuid: savedUUID)
            if exists {
                cloudShareUUID = savedUUID
                remainingSeconds = remaining
            } else {
                defaults.removeObject(forKey: key)
            }
        } catch {
            cloudError = error.localizedDescription
        }
        isVerifying = false
    }

    private func upload() async {
        isCloudUploading = true
        cloudError = nil
        do {
            let uuid = try await uploadAction()
            cloudShareUUID = uuid
            remainingSeconds = 72 * 3600

            if let key = persistenceKey {
                UserDefaults.standard.set(uuid, forKey: key)
            }
        } catch {
            cloudError = error.localizedDescription
        }
        isCloudUploading = false
    }

    private func formatRemainingTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct TransferCodeInput: View {
    @Binding var text: String
    var placeholder: String = NSLocalizedString("transfer_placeholder_paste_code", comment: "Paste share code")

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
    }
}
