import SwiftUI
import OSLog

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ai_selected_provider") private var selectedProviderRaw = AIProvider.deepseek.rawValue
    @AppStorage("ai_selected_model_id") private var selectedModelID = AIProvider.defaultModel.id

    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var hasSavedKey = false
    @State private var statusMessage = ""
    @State private var statusKind: StatusKind = .neutral

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .deepseek
    }

    private var availableModels: [AIModel] {
        selectedProvider.models
    }

    private var selectedModel: AIModel {
        availableModels.first { $0.id == selectedModelID } ?? availableModels.first ?? AIProvider.defaultModel
    }

    private enum StatusKind {
        case neutral, success, error
    }

    private var normalizedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedKey.isEmpty && testedKey == normalizedKey
    }

    @State private var testedKey: String?

    private var statusColor: Color {
        switch statusKind {
        case .neutral: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(LocalizedStringKey("label_ai_provider"), selection: $selectedProviderRaw) {
                        ForEach(AIProvider.availableProviders) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                    .onChange(of: selectedProviderRaw) { _, newValue in
                        let provider = AIProvider(rawValue: newValue) ?? .deepseek
                        if !provider.models.contains(where: { $0.id == selectedModelID }) {
                            selectedModelID = provider.models.first?.id ?? ""
                        }
                        loadSavedKey()
                    }
                    .onAppear {
                        if !AIProvider.availableProviders.contains(where: { $0.rawValue == selectedProviderRaw }) {
                            selectedProviderRaw = AIProvider.deepseek.rawValue
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("ai_service_description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)

                    Picker(LocalizedStringKey("label_ai_model"), selection: $selectedModelID) {
                        ForEach(availableModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }

                    SecureField(LocalizedStringKey("field_ai_api_key"), text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: apiKey) { _, _ in
                            if testedKey != normalizedKey { testedKey = nil }
                        }

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                            } else {
                                Image(systemName: "bolt.horizontal.circle")
                                    .frame(width: 16)
                            }
                            Text(isTesting ? LocalizedStringKey("deepseek_testing") : LocalizedStringKey("deepseek_test"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isTesting || normalizedKey.isEmpty)

                    Button {
                        saveKey()
                    } label: {
                        HStack {
                            Image(systemName: "key")
                                .frame(width: 16)
                            Text(LocalizedStringKey("deepseek_save_key"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)

                    Button(LocalizedStringKey("deepseek_remove_saved_key"), role: .destructive) {
                        removeSavedKey()
                    }
                    .disabled(!hasSavedKey)
                } header: {
                    Text(LocalizedStringKey("settings_section_ai_config"))
                } footer: {
                    Text(LocalizedStringKey("deepseek_test_before_save_hint"))
                }

                Section(LocalizedStringKey("section_status")) {
                    HStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(statusColor)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("settings_ai"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .onAppear { loadSavedKey() }
        }
    }

    private var statusIcon: String {
        switch statusKind {
        case .neutral: return hasSavedKey ? "checkmark.seal" : "info.circle"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var statusText: String {
        if !statusMessage.isEmpty { return statusMessage }
        return hasSavedKey
            ? NSLocalizedString("deepseek_status_has_saved_key", comment: "Saved key")
            : NSLocalizedString("deepseek_status_no_saved_key", comment: "No key")
    }

    private func loadSavedKey() {
        if let saved = AIKeychain.shared.loadAPIKey(for: selectedProvider), !saved.isEmpty {
            apiKey = saved
            hasSavedKey = true
            statusMessage = NSLocalizedString("deepseek_status_loaded_saved_key", comment: "Loaded saved key")
            statusKind = .neutral
        } else {
            apiKey = ""
            hasSavedKey = false
            statusMessage = ""
            statusKind = .neutral
        }
    }

    private func testConnection() {
        guard !normalizedKey.isEmpty else { return }
        isTesting = true
        statusMessage = NSLocalizedString("deepseek_testing", comment: "Testing")
        statusKind = .neutral
        Task {
            do {
                try await AIService.shared.testConnection(model: selectedModel, apiKey: normalizedKey)
                await MainActor.run {
                    testedKey = normalizedKey
                    isTesting = false
                    statusMessage = NSLocalizedString("deepseek_test_success", comment: "Success")
                    statusKind = .success
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    statusKind = .error
                }
            }
        }
    }

    private func saveKey() {
        do {
            try AIKeychain.shared.saveAPIKey(normalizedKey, for: selectedProvider)
            hasSavedKey = true
            statusMessage = NSLocalizedString("deepseek_key_saved", comment: "Saved")
            statusKind = .success
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusKind = .error
        }
    }

    private func removeSavedKey() {
        do {
            try AIKeychain.shared.removeAPIKey(for: selectedProvider)
            apiKey = ""
            hasSavedKey = false
            testedKey = nil
            statusMessage = NSLocalizedString("deepseek_key_removed", comment: "Removed")
            statusKind = .neutral
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusKind = .error
        }
    }
}
