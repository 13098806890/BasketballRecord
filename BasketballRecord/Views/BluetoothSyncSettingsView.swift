import SwiftUI
import UIKit

struct BluetoothSyncSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager

    @State private var advertisingEnabled = false
    @State private var browsingEnabled = false
    @State private var editablePeerName = ""
    @State private var alertMessage: String?

    var body: some View {
        List {
            Section(LocalizedStringKey("section_device")) {
                HStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)

                    Text(bluetooth.localPeerName)
                        .font(.body.weight(.medium))
                }

                TextField(LocalizedStringKey("placeholder_device_name"), text: $editablePeerName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button(action: {
                    bluetooth.updateLocalPeerName(editablePeerName)
                    editablePeerName = bluetooth.localPeerName
                }) {
                    Text(LocalizedStringKey("button_save_device_name"))
                }
                .disabled(editablePeerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editablePeerName == bluetooth.localPeerName)

                Text(LocalizedStringKey("note_device_naming"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(LocalizedStringKey("section_permissions")) {
                HStack(spacing: 10) {
                    Image(systemName: permissionStatusIcon)
                        .foregroundStyle(permissionStatusColor)
                    Text(permissionStatusText)
                        .font(.body.weight(.medium))
                    Spacer()
                    if bluetooth.localNetworkPermissionStatus == .checking {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text(permissionStatusHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(action: { bluetooth.refreshLocalNetworkPermission() }) {
                    Text(LocalizedStringKey("button_check_local_network_permission"))
                }

                if bluetooth.localNetworkPermissionStatus == .denied {
                    Button(action: { openSystemSettings() }) {
                        Text(LocalizedStringKey("button_open_system_settings"))
                    }
                    .foregroundStyle(.blue)
                }
            }

            Section(LocalizedStringKey("section_connection")) {
                HStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)

                    Text(LocalizedStringKey("label_discoverable"))
                        .font(.body.weight(.medium))

                    Spacer()

                    Toggle("", isOn: $advertisingEnabled)
                        .labelsHidden()
                }

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)

                    Text(LocalizedStringKey("label_search_nearby"))
                        .font(.body.weight(.medium))

                    Spacer()

                    Toggle("", isOn: $browsingEnabled)
                        .labelsHidden()
                }

                if bluetooth.connectedPeers.isEmpty {
                    Text(LocalizedStringKey("text_no_connected_devices"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bluetooth.connectedPeers, id: \.self) { peer in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.blue)
                            Text(peer.displayName)
                                .font(.body)
                            Spacer()
                            Text(LocalizedStringKey("label_connected"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        bluetooth.disconnect()
                    } label: {
                        Label(LocalizedStringKey("button_disconnect_all"), systemImage: "xmark.circle")
                    }
                }
            }

            Section(LocalizedStringKey("section_nearby_devices")) {
                if bluetooth.discoveredPeers.isEmpty {
                    Text(LocalizedStringKey("text_no_discovered_devices"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bluetooth.discoveredPeers, id: \.self) { peer in
                        HStack {
                            Text(peer.displayName)
                                .font(.body)
                            Spacer()
                            Button(action: { bluetooth.inviteConnection(to: peer) }) {
                                Text(LocalizedStringKey("button_connect"))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section(LocalizedStringKey("section_store_sync")) {
                NavigationLink {
                    BluetoothStoreSyncComposerView()
                        .environmentObject(store)
                        .environmentObject(bluetooth)
                } label: {
                    Label(LocalizedStringKey("label_select_and_send_data"), systemImage: "arrow.left.arrow.right.circle")
                }
                .disabled(bluetooth.connectedPeers.isEmpty || bluetooth.isStoreSyncPreparing || bluetooth.isStoreSyncSending)

                Text(LocalizedStringKey("note_selective_send"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if bluetooth.isStoreSyncPreparing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(bluetooth.storeSyncPreparationMessage ?? NSLocalizedString("preparing_store_sync", comment: "Preparing store sync"))
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if bluetooth.isStoreSyncSending {
                    Text(bluetooth.outgoingStoreSyncProgress == nil
                         ? NSLocalizedString("sync_request_sent_waiting_confirmation", comment: "Request sent, waiting for recipient confirmation (transfer not started).")
                         : NSLocalizedString("sync_in_progress_cannot_restart", comment: "Sync in progress, cannot restart"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if bluetooth.isStoreSyncPreparing
                    || bluetooth.isStoreSyncSending
                    || bluetooth.incomingStoreSyncProgress != nil
                    || bluetooth.pendingStoreSyncOffer != nil {
                    Button(role: .destructive) {
                        _ = bluetooth.cancelCurrentStoreSyncTask()
                    } label: {
                        Label(LocalizedStringKey("label_cancel_current_sync"), systemImage: "xmark.circle")
                    }
                }
            }

            if let outgoing = bluetooth.outgoingStoreSyncProgress {
                Section(LocalizedStringKey("section_send_progress")) {
                    ProgressView(value: outgoing.fractionCompleted)
                    Text("\(outgoing.peerName) · \(progressDetailText(outgoing))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let incoming = bluetooth.incomingStoreSyncProgress {
                Section(LocalizedStringKey("section_receive_progress")) {
                    ProgressView(value: incoming.fractionCompleted)
                    Text("\(incoming.peerName) · \(progressDetailText(incoming))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let status = bluetooth.statusMessage, !status.isEmpty {
                Section(LocalizedStringKey("section_status")) {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(action: { bluetooth.clearStatus() }) {
                        Text(LocalizedStringKey("button_clear_status"))
                    }
                    .font(.footnote)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("nav_bluetooth_sync"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            advertisingEnabled = bluetooth.isAdvertising
            browsingEnabled = bluetooth.isBrowsing
            editablePeerName = bluetooth.localPeerName
            bluetooth.refreshLocalNetworkPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            bluetooth.refreshLocalNetworkPermission()
        }
        .onChange(of: advertisingEnabled) { _, enabled in
            bluetooth.setAdvertising(enabled)
        }
        .onChange(of: browsingEnabled) { _, enabled in
            bluetooth.setBrowsing(enabled)
        }
        .onChange(of: bluetooth.isAdvertising) { _, enabled in
            if advertisingEnabled != enabled {
                advertisingEnabled = enabled
            }
        }
        .onChange(of: bluetooth.isBrowsing) { _, enabled in
            if browsingEnabled != enabled {
                browsingEnabled = enabled
            }
        }
        .onChange(of: bluetooth.localPeerName) { _, newName in
            editablePeerName = newName
        }
        .alert(LocalizedStringKey("alert_notice_title"), isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button(LocalizedStringKey("alert_ok")) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func progressDetailText(_ progress: BluetoothStoreSyncProgress) -> String {
        let percent = Int((progress.fractionCompleted * 100).rounded())
        let bytes = "\(byteString(progress.transferredBytes))/\(byteString(progress.totalBytes))"
        return "\(percent)% · \(progress.transferredChunks)/\(progress.totalChunks) · \(bytes)"
    }

    private func byteString(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    private var permissionStatusIcon: String {
        switch bluetooth.localNetworkPermissionStatus {
        case .authorized:
            return "checkmark.shield"
        case .denied:
            return "xmark.shield"
        case .checking:
            return "hourglass"
        case .unknown:
            return "questionmark.shield"
        }
    }

    private var permissionStatusColor: Color {
        switch bluetooth.localNetworkPermissionStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .checking:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var permissionStatusText: String {
        switch bluetooth.localNetworkPermissionStatus {
        case .authorized:
            return NSLocalizedString("permission_status_authorized", comment: "Local network permission authorized")
        case .denied:
            return NSLocalizedString("permission_status_denied", comment: "Local network permission denied")
        case .checking:
            return NSLocalizedString("permission_status_checking", comment: "Checking local network permission")
        case .unknown:
            return NSLocalizedString("permission_status_unknown", comment: "Local network permission unknown")
        }
    }

    private var permissionStatusHint: String {
        switch bluetooth.localNetworkPermissionStatus {
        case .authorized:
            return NSLocalizedString("permission_hint_authorized", comment: "Can discover and connect nearby devices")
        case .denied:
            return NSLocalizedString("permission_hint_denied", comment: "Please enable Local Network in system settings")
        case .checking:
            return NSLocalizedString("permission_hint_checking", comment: "First check may prompt system permission dialog")
        case .unknown:
            return NSLocalizedString("permission_hint_unknown", comment: "Click re-check to inspect local network permission")
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
