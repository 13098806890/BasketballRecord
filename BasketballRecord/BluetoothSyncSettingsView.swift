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
            Section("本机") {
                HStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)

                    Text(bluetooth.localPeerName)
                        .font(.body.weight(.medium))
                }

                TextField("设备昵称", text: $editablePeerName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("保存设备昵称") {
                    bluetooth.updateLocalPeerName(editablePeerName)
                    editablePeerName = bluetooth.localPeerName
                }
                .disabled(editablePeerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editablePeerName == bluetooth.localPeerName)

                Text("系统可能只返回 iPhone / iPad，建议设置昵称方便区分设备。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("权限") {
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

                Button("重新检测本地网络权限") {
                    bluetooth.refreshLocalNetworkPermission()
                }

                if bluetooth.localNetworkPermissionStatus == .denied {
                    Button("前往系统设置") {
                        openSystemSettings()
                    }
                    .foregroundStyle(.blue)
                }
            }

            Section("连接") {
                HStack(spacing: 12) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)

                    Text("允许被发现")
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

                    Text("搜索附近设备")
                        .font(.body.weight(.medium))

                    Spacer()

                    Toggle("", isOn: $browsingEnabled)
                        .labelsHidden()
                }

                if bluetooth.connectedPeers.isEmpty {
                    Text("暂无已连接设备")
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
                            Text("已连接")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        bluetooth.disconnect()
                    } label: {
                        Label("断开所有连接", systemImage: "xmark.circle")
                    }
                }
            }

            Section("附近设备") {
                if bluetooth.discoveredPeers.isEmpty {
                    Text("未发现设备，请确认双方都开启了蓝牙协同")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bluetooth.discoveredPeers, id: \.self) { peer in
                        HStack {
                            Text(peer.displayName)
                                .font(.body)
                            Spacer()
                            Button("连接") {
                                bluetooth.inviteConnection(to: peer)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("数据同步") {
                NavigationLink {
                    BluetoothStoreSyncComposerView()
                        .environmentObject(store)
                        .environmentObject(bluetooth)
                } label: {
                    Label("选择并发送数据", systemImage: "arrow.left.arrow.right.circle")
                }
                .disabled(bluetooth.connectedPeers.isEmpty || bluetooth.isStoreSyncPreparing || bluetooth.isStoreSyncSending)

                Text("可按需选择球员、球队、比赛记录。接收方确认后才会开始传输。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if bluetooth.isStoreSyncPreparing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(bluetooth.storeSyncPreparationMessage ?? "正在准备同步数据")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if bluetooth.isStoreSyncSending {
                    Text(bluetooth.outgoingStoreSyncProgress == nil
                         ? "已发送请求，等待对方确认（尚未开始传输）。"
                         : "同步进行中，暂时不可重复发起。")
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
                        Label("取消当前同步", systemImage: "xmark.circle")
                    }
                }
            }

            if let outgoing = bluetooth.outgoingStoreSyncProgress {
                Section("发送进度") {
                    ProgressView(value: outgoing.fractionCompleted)
                    Text("发送给 \(outgoing.peerName)：\(progressDetailText(outgoing))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let incoming = bluetooth.incomingStoreSyncProgress {
                Section("接收进度") {
                    ProgressView(value: incoming.fractionCompleted)
                    Text("来自 \(incoming.peerName)：\(progressDetailText(incoming))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let status = bluetooth.statusMessage, !status.isEmpty {
                Section("状态") {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("清除状态") {
                        bluetooth.clearStatus()
                    }
                    .font(.footnote)
                }
            }
        }
        .navigationTitle("蓝牙协同")
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
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("好的") { alertMessage = nil }
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
            return "本地网络权限已允许"
        case .denied:
            return "本地网络权限未允许"
        case .checking:
            return "正在检测本地网络权限"
        case .unknown:
            return "本地网络权限状态未知"
        }
    }

    private var permissionStatusHint: String {
        switch bluetooth.localNetworkPermissionStatus {
        case .authorized:
            return "可以正常发现并连接附近设备。"
        case .denied:
            return "请在系统设置中打开“本地网络”，否则无法广播或搜索设备。"
        case .checking:
            return "首次检测可能会触发系统权限提示。"
        case .unknown:
            return "点击“重新检测本地网络权限”进行检查。"
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
