import Foundation
import MultipeerConnectivity
import Network
import UIKit
import CryptoKit

final class BluetoothSyncManager: NSObject, ObservableObject {
    private enum Constants {
        static let serviceType = "bskrecord-sync"
        static let bonjourType = "_bskrecord-sync._tcp"
        static let peerNameDefaultsKey = "bluetooth_peer_display_name"
        static let localDeviceIDKey = "bluetooth_local_device_id"
        static let storeSyncChunkSize = 32 * 1024
        static let offerPreviewCount = 6
        static let storeSyncProgressUpdateInterval: TimeInterval = 0.08
        static let storeSyncChunkFlushInterval: TimeInterval = 0.02
    }

    private static let offerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    private struct OutgoingStoreSyncTransfer {
        var targetPeer: MCPeerID
        var offer: BluetoothStoreSyncOfferPayload
        var chunks: [Data]
        var sentChunks: Int = 0
        var sentBytes: Int = 0
        var hasSentAllChunks: Bool = false
    }

    private struct IncomingStoreSyncTransfer {
        var sourcePeer: MCPeerID
        var offer: BluetoothStoreSyncOfferPayload
        var chunkBuffer: [Data?]
        var receivedChunks: Int = 0
        var receivedBytes: Int = 0
    }

    private struct PreparedStoreSyncTransfer {
        var targetPeer: MCPeerID
        var offer: BluetoothStoreSyncOfferPayload
        var chunks: [Data]
    }

    private struct StoreSyncPreparationError: Error {
        var message: String
    }

    @Published private(set) var localPeerName: String
    @Published private(set) var localDeviceID: String
    @Published private(set) var discoveredPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var isAdvertising = false
    @Published private(set) var isBrowsing = false
    @Published private(set) var localNetworkPermissionStatus: LocalNetworkPermissionStatus = .unknown
    @Published var statusMessage: String?

    @Published var pendingStoreSync: BluetoothReceivedStoreSync?
    @Published var pendingStoreSyncOffer: BluetoothReceivedStoreSyncOffer?
    @Published var pendingStoreSyncStatusAlert: BluetoothStoreSyncStatusAlert?
    @Published private(set) var isStoreSyncPreparing = false
    @Published private(set) var storeSyncPreparationMessage: String?
    @Published private(set) var isStoreSyncProcessing = false
    @Published private(set) var storeSyncProcessingMessage: String?
    @Published var outgoingStoreSyncProgress: BluetoothStoreSyncProgress?
    @Published var incomingStoreSyncProgress: BluetoothStoreSyncProgress?
    @Published private(set) var isStoreSyncSending = false
    @Published var pendingLiveInvite: BluetoothReceivedLiveInvite?
    @Published var latestLiveSnapshot: BluetoothReceivedLiveSnapshot?
    @Published var latestInviteResponse: BluetoothReceivedInviteResponse?
    @Published var pendingLiveOpRequest: BluetoothReceivedLiveOpRequest?
    @Published var latestLiveOpCommit: BluetoothReceivedLiveOpCommit?
    @Published var latestLiveOpAck: BluetoothReceivedLiveOpAck?
    @Published var latestLiveResyncRequest: BluetoothReceivedLiveResyncRequest?

    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let permissionProbeQueue = DispatchQueue(label: "com.basketballrecord.permission-probe")
    private let storeSyncPrepareQueue = DispatchQueue(label: "com.basketballrecord.store-sync-prepare", qos: .userInitiated)
    private let storeSyncTransferQueue = DispatchQueue(label: "com.basketballrecord.store-sync-transfer", qos: .userInitiated)
    private let outgoingTransferCancellationLock = NSLock()
    private var permissionBrowser: NWBrowser?
    private var wantsAdvertising = true
    private var wantsBrowsing = true
    private var storeSyncPreparingID: UUID?
    private var lastOutgoingProgressUpdateAt: Date?
    private var lastIncomingProgressUpdateAt: Date?
    private var pendingIncomingChunkEvents: [(payload: BluetoothStoreSyncChunkPayload, peer: MCPeerID)] = []
    private var isChunkFlushScheduled = false
    private var cancelledOutgoingTransferIDs: Set<UUID> = []

    private var liveSessionParticipants: [UUID: Set<String>] = [:]
    private var outgoingStoreSyncTransfers: [UUID: OutgoingStoreSyncTransfer] = [:]
    private var incomingStoreSyncTransfers: [UUID: IncomingStoreSyncTransfer] = [:]

    override init() {
        let initialName = Self.normalizedPeerName(UserDefaults.standard.string(forKey: Constants.peerNameDefaultsKey))
        let deviceID = Self.storedLocalDeviceID()
        let local = MCPeerID(displayName: initialName)
        peerID = local
        session = MCSession(peer: local, securityIdentity: nil, encryptionPreference: .required)
        localPeerName = initialName
        localDeviceID = deviceID
        super.init()

        session.delegate = self
        startAdvertising()
        startBrowsing()
    }

    func updateLocalPeerName(_ candidateName: String) {
        let normalized = Self.normalizedPeerName(candidateName)
        guard normalized != localPeerName else { return }

        UserDefaults.standard.set(normalized, forKey: Constants.peerNameDefaultsKey)
        reconnectAsPeer(named: normalized)
        statusMessage = String(format: NSLocalizedString("status_local_name_updated", comment: "Local name updated"), normalized)
    }

    func setAdvertising(_ enabled: Bool) {
        wantsAdvertising = enabled
        enabled ? startAdvertising() : stopAdvertising()
    }

    func setBrowsing(_ enabled: Bool) {
        wantsBrowsing = enabled
        enabled ? startBrowsing() : stopBrowsing()
    }

    func inviteConnection(to peer: MCPeerID) {
        guard isBrowsing else {
            statusMessage = NSLocalizedString("error_enable_device_search", comment: "Please enable device search first")
            return
        }
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
        statusMessage = String(format: NSLocalizedString("status_invited_connection", comment: "Invited a peer to connect"), peer.displayName)
    }

    func disconnect() {
        session.disconnect()
        discoveredPeers.removeAll()
        connectedPeers.removeAll()
        clearSessionRuntimeState()
        statusMessage = NSLocalizedString("status_disconnected_bluetooth", comment: "Bluetooth collaboration disconnected")
    }

    func clearStatus() {
        statusMessage = nil
    }

    func clearPendingStoreSync() {
        pendingStoreSync = nil
    }

    func clearPendingStoreSyncOffer() {
        pendingStoreSyncOffer = nil
    }

    func clearPendingStoreSyncStatusAlert() {
        pendingStoreSyncStatusAlert = nil
    }

    func postGlobalBluetoothAlert(title: String, message: String) {
        statusMessage = message
        pendingStoreSyncStatusAlert = BluetoothStoreSyncStatusAlert(title: title, message: message)
    }

    func clearPendingLiveInvite() {
        pendingLiveInvite = nil
    }

    func clearPendingLiveOpRequest() {
        pendingLiveOpRequest = nil
    }

    @discardableResult
    func cancelCurrentStoreSyncTask() -> Bool {
        if isStoreSyncPreparing {
            storeSyncPreparingID = nil
            isStoreSyncPreparing = false
            storeSyncPreparationMessage = nil
            setStoreSyncProcessing(active: false, message: nil)
            updateStoreSyncStatus(NSLocalizedString("update_sync_preparation_cancelled", comment: "Sync preparation cancelled"))
            return true
        }

        if let outgoingID = outgoingStoreSyncTransfers.keys.first {
            return cancelOutgoingStoreSyncTransfer(id: outgoingID, reason: NSLocalizedString("sync_reason_sender_cancelled", comment: "Sender cancelled"), notifyPeer: true)
        }

        if let incoming = incomingStoreSyncTransfers.first {
            let payload = BluetoothStoreSyncCancelPayload(
                transferID: incoming.key,
                reason: NSLocalizedString("sync_reason_receiver_cancelled", comment: "Receiver cancelled")
            )
            _ = send(.storeSyncCancel(payload), to: [incoming.value.sourcePeer])
            incomingStoreSyncTransfers.removeValue(forKey: incoming.key)
            if incomingStoreSyncProgress?.id == incoming.key {
                incomingStoreSyncProgress = nil
            }
            lastIncomingProgressUpdateAt = nil
            refreshStoreSyncSendingState()
            setStoreSyncProcessing(active: false, message: nil)
            updateStoreSyncStatus(NSLocalizedString("update_sync_receive_cancelled", comment: "Receive sync cancelled"))
            return true
        }

        if let offer = pendingStoreSyncOffer {
            let ok = respondToStoreSyncOffer(offer, accepted: false)
            if ok {
                updateStoreSyncStatus(NSLocalizedString("update_sync_offer_cancelled_pending", comment: "Cancelled pending sync offer"))
            }
            return ok
        }

        updateStoreSyncStatus(NSLocalizedString("update_no_cancelable_sync_tasks", comment: "No cancelable sync tasks"))
        return false
    }

    func clearLatestLiveOpAck() {
        latestLiveOpAck = nil
    }

    func refreshLocalNetworkPermission() {
        permissionBrowser?.cancel()
        permissionBrowser = nil
        localNetworkPermissionStatus = .checking

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(type: Constants.bonjourType, domain: nil),
            using: parameters
        )
        permissionBrowser = browser

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.localNetworkPermissionStatus = .authorized
                    if self.wantsAdvertising {
                        self.startAdvertising()
                    }
                    if self.wantsBrowsing {
                        self.startBrowsing()
                    }
                    self.permissionBrowser?.cancel()
                    self.permissionBrowser = nil

                case .failed(let error):
                    self.localNetworkPermissionStatus = self.isLocalPermissionDenied(error) ? .denied : .unknown
                    self.permissionBrowser?.cancel()
                    self.permissionBrowser = nil

                case .waiting(let error):
                    if self.isLocalPermissionDenied(error) {
                        self.localNetworkPermissionStatus = .denied
                        self.permissionBrowser?.cancel()
                        self.permissionBrowser = nil
                    }

                default:
                    break
                }
            }
        }

        browser.start(queue: permissionProbeQueue)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            guard self.localNetworkPermissionStatus == .checking else { return }
            self.localNetworkPermissionStatus = .unknown
            self.permissionBrowser?.cancel()
            self.permissionBrowser = nil
        }
    }

    @discardableResult
    func sendStoreSync(players: [Player], teams: [Team], savedGames: [SavedGame]) -> Bool {
        guard let firstPeer = connectedPeers.first else {
            statusMessage = NSLocalizedString("status_no_available_connection", comment: "No available connected device")
            return false
        }

        // Strip local-only data from games before sending
        let cleanGames = savedGames.map { $0.strippedForTransfer() }

        return sendStoreSyncOffer(
            payload: BluetoothStoreSyncPayload(players: players, teams: teams, savedGames: cleanGames),
            to: firstPeer
        )
    }

    @discardableResult
    func sendStoreSyncOffer(payload: BluetoothStoreSyncPayload, to peer: MCPeerID) -> Bool {
        guard !isStoreSyncPreparing, outgoingStoreSyncTransfers.isEmpty else {
            statusMessage = NSLocalizedString("status_sync_in_progress_please_wait", comment: "A sync task is already in progress")
            return false
        }

        switch prepareStoreSyncTransfer(payload: payload, to: peer) {
        case let .success(prepared):
            return enqueuePreparedStoreSyncTransfer(prepared)
        case let .failure(error):
            statusMessage = error.message
            return false
        }
    }

    func sendStoreSyncOfferAsync(payload: BluetoothStoreSyncPayload, to peer: MCPeerID) {
        guard !isStoreSyncPreparing else {
            updateStoreSyncStatus(NSLocalizedString("update_preparing_store_sync_please_wait", comment: "Preparing store sync, please wait"))
            return
        }
        guard outgoingStoreSyncTransfers.isEmpty else {
            updateStoreSyncStatus(NSLocalizedString("update_sync_task_in_progress", comment: "A sync task is already in progress"))
            return
        }

        let preparingID = UUID()
        storeSyncPreparingID = preparingID
        isStoreSyncPreparing = true
        storeSyncPreparationMessage = NSLocalizedString("store_sync_preparing_local_processing", comment: "Preparing store sync (local processing)")

        storeSyncPrepareQueue.async { [weak self] in
            guard let self else { return }
            let result = self.prepareStoreSyncTransfer(payload: payload, to: peer)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard self.storeSyncPreparingID == preparingID else { return }

                self.storeSyncPreparingID = nil
                self.isStoreSyncPreparing = false
                self.storeSyncPreparationMessage = nil

                switch result {
                case let .success(prepared):
                    _ = self.enqueuePreparedStoreSyncTransfer(prepared)

                case let .failure(error):
                    self.updateStoreSyncStatus(error.message)
                }
            }
        }
    }

    @discardableResult
    func respondToStoreSyncOffer(_ offer: BluetoothReceivedStoreSyncOffer, accepted: Bool) -> Bool {
        let response = BluetoothStoreSyncOfferResponsePayload(
            transferID: offer.payload.transferID,
            accepted: accepted
        )
        let ok = send(.storeSyncOfferResponse(response), to: [offer.fromPeerID])
        if !ok {
            return false
        }

        if accepted {
            incomingStoreSyncTransfers[offer.payload.transferID] = IncomingStoreSyncTransfer(
                sourcePeer: offer.fromPeerID,
                offer: offer.payload,
                chunkBuffer: Array(repeating: nil, count: max(offer.payload.totalChunks, 0))
            )
            setStoreSyncProcessing(active: true, message: NSLocalizedString("processing_waiting_and_receiving", comment: "Waiting and receiving data"))
            lastIncomingProgressUpdateAt = nil
            incomingStoreSyncProgress = BluetoothStoreSyncProgress(
                id: offer.payload.transferID,
                peerName: offer.fromPeerName,
                transferredChunks: 0,
                totalChunks: offer.payload.totalChunks,
                transferredBytes: 0,
                totalBytes: offer.payload.totalBytes,
                isSending: false,
                isConfirmed: false
            )
            updateStoreSyncStatus(String(format: NSLocalizedString("update_confirmed_waiting_for_peer_start_transfer", comment: "Confirmed receive, waiting for peer to start transfer"), offer.fromPeerName))
        } else {
            incomingStoreSyncTransfers.removeValue(forKey: offer.payload.transferID)
            incomingStoreSyncProgress = nil
            lastIncomingProgressUpdateAt = nil
            setStoreSyncProcessing(active: false, message: nil)
            updateStoreSyncStatus(String(format: NSLocalizedString("update_rejected_peer_sync_request", comment: "Rejected peer sync request"), offer.fromPeerName))
        }

        pendingStoreSyncOffer = nil
        return true
    }

    @discardableResult
    func sendLiveInvite(
        players: [Player],
        teams: [Team],
        state: BluetoothLiveGameStatePayload,
        stateVersion: Int,
        stateHash: String,
        to peers: [MCPeerID]
    ) -> UUID? {
        let targets = peers.filter { candidate in
            session.connectedPeers.contains(where: { $0 == candidate })
        }
        guard !targets.isEmpty else {
            statusMessage = NSLocalizedString("status_no_invitable_devices", comment: "No connectable devices")
            return nil
        }

        let sessionID = UUID()
        let playersWithoutPhoto = players.map { player in
            var sanitized = player
            sanitized.photoData = nil
            return sanitized
        }
        let payload = BluetoothLiveInvitePayload(
            sessionID: sessionID,
            inviterName: localPeerName,
            hostDeviceID: localDeviceID,
            stateVersion: stateVersion,
            stateHash: stateHash,
            players: playersWithoutPhoto,
            teams: teams,
            state: state
        )
        let ok = send(.liveInvite(payload), to: targets)
        guard ok else { return nil }

        liveSessionParticipants[sessionID] = Set(targets.map(\.displayName))
        statusMessage = NSLocalizedString("status_collab_invite_sent", comment: "Collab invite sent")
        return sessionID
    }

    @discardableResult
    func respondToLiveInvite(_ invite: BluetoothReceivedLiveInvite, accepted: Bool) -> Bool {
        let payload = BluetoothLiveInviteResponsePayload(
            sessionID: invite.payload.sessionID,
            accepted: accepted,
            responderName: localPeerName
        )
        let ok = send(.liveInviteResponse(payload), to: [invite.fromPeerID])
        if accepted {
            liveSessionParticipants[invite.payload.sessionID, default: []].insert(invite.fromPeerName)
        }
        return ok
    }

    func noteAcceptedLiveSession(sessionID: UUID, with peerName: String) {
        liveSessionParticipants[sessionID, default: []].insert(peerName)
    }

    func sendLiveSnapshot(
        sessionID: UUID,
        state: BluetoothLiveGameStatePayload,
        version: Int,
        stateHash: String,
        reason: String? = nil,
        to peers: [MCPeerID]? = nil
    ) {
        let targets: [MCPeerID]
        if let peers {
            targets = peers.filter { candidate in
                session.connectedPeers.contains(where: { $0 == candidate })
            }
        } else {
            let preferredNames = liveSessionParticipants[sessionID] ?? []
            if preferredNames.isEmpty {
                targets = session.connectedPeers
            } else {
                targets = session.connectedPeers.filter { preferredNames.contains($0.displayName) }
            }
        }

        guard !targets.isEmpty else { return }

        let payload = BluetoothLiveSnapshotPayload(
            sessionID: sessionID,
            hostDeviceID: localDeviceID,
            version: version,
            stateHash: stateHash,
            reason: reason,
            state: state
        )
        _ = send(.liveSnapshot(payload), to: targets)
    }

    func sendLiveOpRequest(
        sessionID: UUID,
        op: BluetoothLiveOperation,
        toHost hostPeer: MCPeerID?,
        hostName: String?
    ) -> Bool {
        let payload = BluetoothLiveOpRequestPayload(sessionID: sessionID, op: op)
        if let hostPeer,
           session.connectedPeers.contains(where: { $0 == hostPeer }) {
            return send(.liveOpRequest(payload), to: [hostPeer])
        }
        if let hostName,
           let hostPeer = session.connectedPeers.first(where: { $0.displayName == hostName }) {
            return send(.liveOpRequest(payload), to: [hostPeer])
        }
        return send(.liveOpRequest(payload), to: session.connectedPeers)
    }

    func sendLiveOpCommit(sessionID: UUID, commit: BluetoothLiveOpCommitPayload, to peers: [MCPeerID]? = nil) {
        let targets: [MCPeerID]
        if let peers {
            targets = peers.filter { candidate in
                session.connectedPeers.contains(where: { $0 == candidate })
            }
        } else {
            let preferredNames = liveSessionParticipants[sessionID] ?? []
            if preferredNames.isEmpty {
                targets = session.connectedPeers
            } else {
                targets = session.connectedPeers.filter { preferredNames.contains($0.displayName) }
            }
        }
        guard !targets.isEmpty else { return }
        _ = send(.liveOpCommit(commit), to: targets)
    }

    func sendLiveOpAck(sessionID: UUID, opID: UUID, version: Int, to hostPeer: MCPeerID?) {
        let payload = BluetoothLiveOpAckPayload(sessionID: sessionID, opID: opID, version: version, deviceID: localDeviceID)
        if let hostPeer {
            _ = send(.liveOpAck(payload), to: [hostPeer])
        } else {
            _ = send(.liveOpAck(payload), to: session.connectedPeers)
        }
    }

    func sendLiveResyncRequest(sessionID: UUID, expectedVersion: Int, reason: String, to hostPeer: MCPeerID?) {
        let payload = BluetoothLiveResyncRequestPayload(sessionID: sessionID, expectedVersion: expectedVersion, reason: reason)
        if let hostPeer {
            _ = send(.liveResyncRequest(payload), to: [hostPeer])
        } else {
            _ = send(.liveResyncRequest(payload), to: session.connectedPeers)
        }
    }

    private func startAdvertising() {
        guard advertiser == nil else { return }
        let newAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Constants.serviceType)
        newAdvertiser.delegate = self
        newAdvertiser.startAdvertisingPeer()
        advertiser = newAdvertiser
        isAdvertising = true
    }

    private func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
    }

    private func startBrowsing() {
        guard browser == nil else { return }
        let newBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: Constants.serviceType)
        newBrowser.delegate = self
        newBrowser.startBrowsingForPeers()
        browser = newBrowser
        isBrowsing = true
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        discoveredPeers.removeAll()
    }

    @discardableResult
    private func send(_ message: BluetoothSyncMessage, to peers: [MCPeerID]) -> Bool {
        let connectedTargets = session.connectedPeers.filter { candidate in
            peers.contains(where: { $0 == candidate })
        }
        guard !connectedTargets.isEmpty else {
            setStatusMessage(NSLocalizedString("status_no_available_connection", comment: "No available connected device"))
            return false
        }
        let shouldCompress: Bool
        switch message {
        case .storeSyncChunk:
            shouldCompress = false
        default:
            shouldCompress = true
        }

        guard let encoded = encodeMessage(message, compress: shouldCompress) else {
            setStatusMessage(NSLocalizedString("status_bluetooth_message_encoding_failed", comment: "Bluetooth message encoding failed"))
            return false
        }

        do {
            try session.send(encoded, toPeers: connectedTargets, with: .reliable)
            return true
        } catch {
            setStatusMessage(String(format: NSLocalizedString("status_send_failed_with_error", comment: "Send failed: %@"), error.localizedDescription))
            return false
        }
    }

    private func startSendingStoreSyncTransfer(_ transferID: UUID) {
        guard let transfer = outgoingStoreSyncTransfers[transferID] else { return }
        setStoreSyncProcessing(active: true, message: NSLocalizedString("status_sending_data", comment: "Sending data"))
        lastOutgoingProgressUpdateAt = nil

        outgoingStoreSyncProgress = BluetoothStoreSyncProgress(
            id: transferID,
            peerName: transfer.targetPeer.displayName,
            transferredChunks: 0,
            totalChunks: transfer.offer.totalChunks,
            transferredBytes: 0,
            totalBytes: transfer.offer.totalBytes,
            isSending: true,
            isConfirmed: false
        )
        storeSyncTransferQueue.async { [weak self] in
            self?.performOutgoingStoreSyncTransfer(transferID: transferID, transfer: transfer)
        }
    }

    private func performOutgoingStoreSyncTransfer(transferID: UUID, transfer: OutgoingStoreSyncTransfer) {
        defer {
            clearOutgoingTransferCancellationMark(transferID)
        }

        var sentChunks = 0
        var sentBytes = 0
        var lastPublishedAt = Date.distantPast

        for (chunkIndex, chunk) in transfer.chunks.enumerated() {
            if isOutgoingTransferCancelled(transferID) {
                return
            }

            let chunkPayload = BluetoothStoreSyncChunkPayload(
                transferID: transferID,
                chunkIndex: chunkIndex,
                totalChunks: transfer.offer.totalChunks,
                totalBytes: transfer.offer.totalBytes,
                chunkData: chunk
            )

            let ok = send(.storeSyncChunk(chunkPayload), to: [transfer.targetPeer])
            if !ok {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.outgoingStoreSyncTransfers.removeValue(forKey: transferID)
                    self.clearOutgoingTransferCancellationMark(transferID)
                    self.refreshStoreSyncSendingState()
                    self.outgoingStoreSyncProgress = nil
                    self.lastOutgoingProgressUpdateAt = nil
                    self.setStoreSyncProcessing(active: false, message: nil)
                    self.updateStoreSyncStatus(NSLocalizedString("update_sync_send_interrupted", comment: "Sync send interrupted, please retry"))
                }
                return
            }

            sentChunks += 1
            sentBytes += chunk.count

            let now = Date()
            let isLastChunk = sentChunks >= transfer.offer.totalChunks
            let shouldPublish = isLastChunk
                || sentChunks == 1
                || now.timeIntervalSince(lastPublishedAt) >= Constants.storeSyncProgressUpdateInterval

            if shouldPublish {
                lastPublishedAt = now
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.outgoingStoreSyncTransfers[transferID] != nil else { return }
                    self.lastOutgoingProgressUpdateAt = now
                    self.outgoingStoreSyncProgress = BluetoothStoreSyncProgress(
                        id: transferID,
                        peerName: transfer.targetPeer.displayName,
                        transferredChunks: sentChunks,
                        totalChunks: transfer.offer.totalChunks,
                        transferredBytes: sentBytes,
                        totalBytes: transfer.offer.totalBytes,
                        isSending: true,
                        isConfirmed: false
                    )
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard var finalTransfer = self.outgoingStoreSyncTransfers[transferID] else { return }
            finalTransfer.sentChunks = transfer.offer.totalChunks
            finalTransfer.sentBytes = transfer.offer.totalBytes
            finalTransfer.hasSentAllChunks = true
            self.outgoingStoreSyncTransfers[transferID] = finalTransfer

            self.setStoreSyncProcessing(active: false, message: nil)
            self.outgoingStoreSyncProgress = BluetoothStoreSyncProgress(
                id: transferID,
                peerName: transfer.targetPeer.displayName,
                transferredChunks: transfer.offer.totalChunks,
                totalChunks: transfer.offer.totalChunks,
                transferredBytes: transfer.offer.totalBytes,
                totalBytes: transfer.offer.totalBytes,
                isSending: true,
                isConfirmed: false
            )
            self.updateStoreSyncStatus(String(format: NSLocalizedString("update_data_sent_waiting_peer_confirm", comment: "Data sent, waiting for peer to verify and confirm"), transfer.targetPeer.displayName), showGlobalAlert: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
                guard let self else { return }
                guard let pending = self.outgoingStoreSyncTransfers[transferID], pending.hasSentAllChunks else { return }
                self.outgoingStoreSyncTransfers.removeValue(forKey: transferID)
                self.clearOutgoingTransferCancellationMark(transferID)
                if self.outgoingStoreSyncProgress?.id == transferID {
                    self.outgoingStoreSyncProgress = nil
                }
                self.lastOutgoingProgressUpdateAt = nil
                self.refreshStoreSyncSendingState()
                self.setStoreSyncProcessing(active: false, message: nil)
                self.updateStoreSyncStatus(NSLocalizedString("update_sender_completed_but_no_confirmation_yet", comment: "Sender completed sending but no confirmation yet"))
            }
        }
    }

    private func receiveStoreSyncChunk(_ payload: BluetoothStoreSyncChunkPayload, from peer: MCPeerID) {
        guard var transfer = incomingStoreSyncTransfers[payload.transferID] else { return }
        guard transfer.sourcePeer == peer else { return }
        guard payload.chunkIndex >= 0 && payload.chunkIndex < transfer.chunkBuffer.count else { return }

        if transfer.chunkBuffer[payload.chunkIndex] == nil {
            transfer.chunkBuffer[payload.chunkIndex] = payload.chunkData
            transfer.receivedChunks += 1
            transfer.receivedBytes += payload.chunkData.count
            incomingStoreSyncTransfers[payload.transferID] = transfer
        }

        let now = Date()
        let isLastChunk = transfer.receivedChunks >= transfer.offer.totalChunks
        let shouldUpdateProgress: Bool
        if isLastChunk || transfer.receivedChunks == 1 {
            shouldUpdateProgress = true
        } else if let last = lastIncomingProgressUpdateAt {
            shouldUpdateProgress = now.timeIntervalSince(last) >= Constants.storeSyncProgressUpdateInterval
        } else {
            shouldUpdateProgress = true
        }

        if shouldUpdateProgress {
            lastIncomingProgressUpdateAt = now
            incomingStoreSyncProgress = BluetoothStoreSyncProgress(
                id: payload.transferID,
                peerName: peer.displayName,
                transferredChunks: transfer.receivedChunks,
                totalChunks: transfer.offer.totalChunks,
                transferredBytes: min(transfer.receivedBytes, transfer.offer.totalBytes),
                totalBytes: transfer.offer.totalBytes,
                isSending: false,
                isConfirmed: false
            )
        }

        guard transfer.receivedChunks >= transfer.offer.totalChunks else { return }

        let orderedChunks = transfer.chunkBuffer.compactMap { $0 }
        guard orderedChunks.count == transfer.offer.totalChunks else {
            sendStoreSyncReceiveAck(transferID: payload.transferID, to: peer, success: false, reason: NSLocalizedString("reason_data_incomplete", comment: "Data incomplete"))
            updateStoreSyncStatus(NSLocalizedString("update_received_data_incomplete", comment: "Received data incomplete, please retry"))
            incomingStoreSyncTransfers.removeValue(forKey: payload.transferID)
            incomingStoreSyncProgress = nil
            lastIncomingProgressUpdateAt = nil
            return
        }

        let transferID = payload.transferID
        let totalBytes = transfer.offer.totalBytes
        let snapshotHash = transfer.offer.snapshotHash
        incomingStoreSyncTransfers.removeValue(forKey: payload.transferID)
        setStoreSyncProcessing(active: true, message: NSLocalizedString("processing_validating_and_parsing_received_data", comment: "Validating and parsing received data"))

        storeSyncTransferQueue.async { [weak self] in
            guard let self else { return }

            var joinedData = Data(capacity: totalBytes)
            for chunk in orderedChunks {
                joinedData.append(chunk)
            }

            let computedHash = self.sha256Hex(joinedData)
            guard computedHash == snapshotHash else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.sendStoreSyncReceiveAck(transferID: transferID, to: peer, success: false, reason: NSLocalizedString("sync_reason_hash_failed", comment: "Hash check failed"))
                    self.updateStoreSyncStatus(NSLocalizedString("status_receive_hash_failed_retry", comment: "Receive hash failed retry"))
                    self.incomingStoreSyncProgress = nil
                    self.lastIncomingProgressUpdateAt = nil
                    self.setStoreSyncProcessing(active: false, message: nil)
                }
                return
            }

            guard let decodedPayload = self.decodeStoreSyncPayloadData(joinedData) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.sendStoreSyncReceiveAck(transferID: transferID, to: peer, success: false, reason: NSLocalizedString("reason_parse_failed", comment: "Parse failed"))
                    self.updateStoreSyncStatus(NSLocalizedString("update_parse_failed", comment: "Received but parse failed, please retry"))
                    self.incomingStoreSyncProgress = nil
                    self.lastIncomingProgressUpdateAt = nil
                    self.setStoreSyncProcessing(active: false, message: nil)
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sendStoreSyncReceiveAck(transferID: transferID, to: peer, success: true, reason: nil)
                self.pendingStoreSync = BluetoothReceivedStoreSync(fromPeerName: peer.displayName, payload: decodedPayload)
                self.updateStoreSyncStatus(NSLocalizedString("update_received_completed_confirm_import", comment: "Received complete, please confirm import"))
                self.setStoreSyncProcessing(active: false, message: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self else { return }
                    guard self.incomingStoreSyncProgress?.id == transferID else { return }
                    self.incomingStoreSyncProgress = nil
                    self.lastIncomingProgressUpdateAt = nil
                }
            }
        }
    }

    private func enqueueIncomingStoreSyncChunk(_ payload: BluetoothStoreSyncChunkPayload, from peer: MCPeerID) {
        pendingIncomingChunkEvents.append((payload: payload, peer: peer))
        guard !isChunkFlushScheduled else { return }

        isChunkFlushScheduled = true
        storeSyncTransferQueue.asyncAfter(deadline: .now() + Constants.storeSyncChunkFlushInterval) { [weak self] in
            guard let self else { return }

            let events = self.pendingIncomingChunkEvents
            self.pendingIncomingChunkEvents.removeAll(keepingCapacity: true)
            self.isChunkFlushScheduled = false

            guard !events.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for event in events {
                    self.receiveStoreSyncChunk(event.payload, from: event.peer)
                }
            }
        }
    }

    private func splitIntoChunks(_ data: Data, chunkSize: Int) -> [Data] {
        guard !data.isEmpty else { return [Data()] }
        let safeChunkSize = max(chunkSize, 1024)
        var chunks: [Data] = []
        chunks.reserveCapacity(Int(ceil(Double(data.count) / Double(safeChunkSize))))

        var offset = 0
        while offset < data.count {
            let end = min(offset + safeChunkSize, data.count)
            chunks.append(data.subdata(in: offset ..< end))
            offset = end
        }
        return chunks
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func encodeStoreSyncPayloadData(_ payload: BluetoothStoreSyncPayload) -> Data? {
        guard let raw = try? JSONEncoder().encode(payload) else { return nil }
        return (try? (raw as NSData).compressed(using: .lzfse) as Data) ?? raw
    }

    private func decodeStoreSyncPayloadData(_ data: Data) -> BluetoothStoreSyncPayload? {
        if looksLikeJSONObjectData(data),
           let decoded = try? JSONDecoder().decode(BluetoothStoreSyncPayload.self, from: data) {
            return decoded
        }

        if let decompressed = try? (data as NSData).decompressed(using: .lzfse) as Data,
           let decoded = try? JSONDecoder().decode(BluetoothStoreSyncPayload.self, from: decompressed) {
            return decoded
        }
        return try? JSONDecoder().decode(BluetoothStoreSyncPayload.self, from: data)
    }

    private func encodeMessage(_ message: BluetoothSyncMessage, compress: Bool = true) -> Data? {
        guard let raw = try? JSONEncoder().encode(message) else { return nil }
        guard compress else { return raw }
        return (try? (raw as NSData).compressed(using: .lzfse) as Data) ?? raw
    }

    private func decodeMessage(_ data: Data) -> BluetoothSyncMessage? {
        if looksLikeJSONObjectData(data),
           let decoded = try? JSONDecoder().decode(BluetoothSyncMessage.self, from: data) {
            return decoded
        }

        if let decompressed = try? (data as NSData).decompressed(using: .lzfse) as Data,
           let decoded = try? JSONDecoder().decode(BluetoothSyncMessage.self, from: decompressed) {
            return decoded
        }

        return try? JSONDecoder().decode(BluetoothSyncMessage.self, from: data)
    }

    private func looksLikeJSONObjectData(_ data: Data) -> Bool {
        guard let first = data.first else { return false }
        return first == 0x7B || first == 0x5B
    }

    private func isLocalPermissionDenied(_ error: Error) -> Bool {
        if let nwError = error as? NWError {
            switch nwError {
            case .posix(let code):
                if code == .EPERM || code == .EACCES {
                    return true
                }
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == Int(EPERM) || nsError.code == Int(EACCES) {
            return true
        }

        let lowerMessage = error.localizedDescription.lowercased()
        return lowerMessage.contains("not permitted")
            || lowerMessage.contains("permission denied")
            || lowerMessage.contains("policy denied")
    }

    private func reconnectAsPeer(named newName: String) {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
        session.delegate = nil

        let newPeer = MCPeerID(displayName: newName)
        let newSession = MCSession(peer: newPeer, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self

        peerID = newPeer
        session = newSession
        localPeerName = newName

        discoveredPeers.removeAll()
        connectedPeers.removeAll()
        clearSessionRuntimeState()

        if wantsAdvertising {
            startAdvertising()
        }
        if wantsBrowsing {
            startBrowsing()
        }
    }

    private static func normalizedPeerName(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = trimmed.isEmpty ? defaultPeerName() : trimmed
        let compacted = preferred.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(compacted.prefix(28))
    }

    private static func defaultPeerName() -> String {
        let systemName = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !systemName.isEmpty else { return NSLocalizedString("device_default_basketball", comment: "Basketball device default") }

        let genericNames = ["iphone", "ipad"]
        if genericNames.contains(systemName.lowercased()) {
            let suffix: String
            if let s = UIDevice.current.identifierForVendor?.uuidString.suffix(4) {
                suffix = String(s)
            } else {
                suffix = NSLocalizedString("device_default_name", comment: "Device default")
            }
            return "\(systemName)-\(suffix)"
        }

        return systemName
    }

    private static func storedLocalDeviceID() -> String {
        if let existing = UserDefaults.standard.string(forKey: Constants.localDeviceIDKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: Constants.localDeviceIDKey)
        return generated
    }

    private func refreshStoreSyncSendingState() {
        isStoreSyncSending = !outgoingStoreSyncTransfers.isEmpty
    }

    private func prepareStoreSyncTransfer(
        payload: BluetoothStoreSyncPayload,
        to peer: MCPeerID
    ) -> Result<PreparedStoreSyncTransfer, StoreSyncPreparationError> {
        var sanitizedPayload = payload
        if !sanitizedPayload.savedGames.isEmpty {
            let teamPlayerIDs = Set(sanitizedPayload.teams.flatMap(\.playerIDs))
            sanitizedPayload.players = sanitizedPayload.players.map { player in
                var copy = player
                if !teamPlayerIDs.contains(copy.id) {
                    copy.photoData = nil
                }
                return copy
            }
        }

        let includePlayers = !sanitizedPayload.players.isEmpty
        let includeTeams = !sanitizedPayload.teams.isEmpty
        let includeSavedGames = !sanitizedPayload.savedGames.isEmpty

        guard includePlayers || includeTeams || includeSavedGames else {
            return .failure(StoreSyncPreparationError(message: NSLocalizedString("error_no_data_in_selected_category", comment: "No data in selected categories to send")))
        }

        let localEncoder = JSONEncoder()
        guard let raw = try? localEncoder.encode(sanitizedPayload) else {
            return .failure(StoreSyncPreparationError(message: NSLocalizedString("error_sync_data_encoding_failed", comment: "Sync data encoding failed")))
        }
        let encodedPayload = (try? (raw as NSData).compressed(using: .lzfse) as Data) ?? raw

        let transferID = UUID()
        let chunks = splitIntoChunks(encodedPayload, chunkSize: Constants.storeSyncChunkSize)
        let snapshotVersion = Int(Date().timeIntervalSince1970)
        let snapshotHash = sha256Hex(encodedPayload)

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MM-dd HH:mm"

        let offer = BluetoothStoreSyncOfferPayload(
            transferID: transferID,
            snapshotVersion: snapshotVersion,
            snapshotHash: snapshotHash,
            includePlayers: includePlayers,
            includeTeams: includeTeams,
            includeSavedGames: includeSavedGames,
            playerCount: sanitizedPayload.players.count,
            teamCount: sanitizedPayload.teams.count,
            gameCount: sanitizedPayload.savedGames.count,
            playerNamesPreview: sanitizedPayload.players.prefix(Constants.offerPreviewCount).map(\.name),
            teamNamesPreview: sanitizedPayload.teams.prefix(Constants.offerPreviewCount).map(\.name),
            gameTitlesPreview: sanitizedPayload.savedGames
                .sorted { $0.savedAt > $1.savedAt }
                .prefix(Constants.offerPreviewCount)
                .map { game in
                    let dateText = formatter.string(from: game.savedAt)
                    return "\(game.homeTeamName) vs \(game.awayTeamName) · \(dateText)"
                },
            totalChunks: chunks.count,
            totalBytes: encodedPayload.count
        )

        let prepared = PreparedStoreSyncTransfer(targetPeer: peer, offer: offer, chunks: chunks)
        return .success(prepared)
    }

    private func enqueuePreparedStoreSyncTransfer(_ prepared: PreparedStoreSyncTransfer) -> Bool {
        guard !isStoreSyncPreparing, outgoingStoreSyncTransfers.isEmpty else {
            updateStoreSyncStatus(NSLocalizedString("update_sync_task_in_progress", comment: "A sync task is already in progress"))
            return false
        }

        outgoingStoreSyncTransfers[prepared.offer.transferID] = OutgoingStoreSyncTransfer(
            targetPeer: prepared.targetPeer,
            offer: prepared.offer,
            chunks: prepared.chunks
        )
        refreshStoreSyncSendingState()

        let ok = send(.storeSyncOffer(prepared.offer), to: [prepared.targetPeer])
        if ok {
            updateStoreSyncStatus(String(format: NSLocalizedString("status_request_sent_waiting_peer_format", comment: "Request sent waiting peer"), prepared.targetPeer.displayName))
        } else {
            outgoingStoreSyncTransfers.removeValue(forKey: prepared.offer.transferID)
            clearOutgoingTransferCancellationMark(prepared.offer.transferID)
            refreshStoreSyncSendingState()
            updateStoreSyncStatus(NSLocalizedString("status_send_request_failed", comment: "Send request failed"))
        }
        return ok
    }

    private func updateStoreSyncStatus(_ message: String, title: String = NSLocalizedString("title_sync_status", comment: "Sync status title"), showGlobalAlert: Bool = true) {
        let apply = {
            if showGlobalAlert {
                self.postGlobalBluetoothAlert(title: title, message: message)
            } else {
                self.statusMessage = message
            }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func sendStoreSyncReceiveAck(transferID: UUID, to peer: MCPeerID, success: Bool, reason: String?) {
        let payload = BluetoothStoreSyncReceiveAckPayload(
            transferID: transferID,
            received: success,
            reason: reason
        )
        _ = send(.storeSyncReceiveAck(payload), to: [peer])
    }

    private func setStoreSyncProcessing(active: Bool, message: String?) {
        let apply = {
            self.isStoreSyncProcessing = active
            self.storeSyncProcessingMessage = message
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func setStatusMessage(_ message: String?) {
        if Thread.isMainThread {
            statusMessage = message
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.statusMessage = message
            }
        }
    }

    private func markOutgoingTransferCancelled(_ transferID: UUID) {
        outgoingTransferCancellationLock.lock()
        cancelledOutgoingTransferIDs.insert(transferID)
        outgoingTransferCancellationLock.unlock()
    }

    private func clearOutgoingTransferCancellationMark(_ transferID: UUID) {
        outgoingTransferCancellationLock.lock()
        cancelledOutgoingTransferIDs.remove(transferID)
        outgoingTransferCancellationLock.unlock()
    }

    private func isOutgoingTransferCancelled(_ transferID: UUID) -> Bool {
        outgoingTransferCancellationLock.lock()
        let cancelled = cancelledOutgoingTransferIDs.contains(transferID)
        outgoingTransferCancellationLock.unlock()
        return cancelled
    }

    private func cancelOutgoingStoreSyncTransfer(id transferID: UUID, reason: String, notifyPeer: Bool) -> Bool {
        guard let transfer = outgoingStoreSyncTransfers[transferID] else { return false }
        let shouldMarkRunningLoop = outgoingStoreSyncProgress?.id == transferID
        if shouldMarkRunningLoop {
            markOutgoingTransferCancelled(transferID)
        }

        if notifyPeer {
            let payload = BluetoothStoreSyncCancelPayload(transferID: transferID, reason: reason)
            _ = send(.storeSyncCancel(payload), to: [transfer.targetPeer])
        }

        outgoingStoreSyncTransfers.removeValue(forKey: transferID)
        if !shouldMarkRunningLoop {
            clearOutgoingTransferCancellationMark(transferID)
        }
        if outgoingStoreSyncProgress?.id == transferID {
            outgoingStoreSyncProgress = nil
        }
        lastOutgoingProgressUpdateAt = nil
        refreshStoreSyncSendingState()
        setStoreSyncProcessing(active: false, message: nil)
        updateStoreSyncStatus(String(format: NSLocalizedString("status_outgoing_sync_cancelled_format", comment: "Outgoing sync cancelled"), transfer.targetPeer.displayName))
        return true
    }

    private func cleanupStoreSyncTransfers(for peer: MCPeerID) -> Bool {
        var removed = false

        let outgoingIDs = outgoingStoreSyncTransfers.compactMap { id, transfer in
            transfer.targetPeer == peer ? id : nil
        }
        for id in outgoingIDs {
            if outgoingStoreSyncProgress?.id == id {
                markOutgoingTransferCancelled(id)
            } else {
                clearOutgoingTransferCancellationMark(id)
            }
            outgoingStoreSyncTransfers.removeValue(forKey: id)
            if outgoingStoreSyncProgress?.id == id {
                outgoingStoreSyncProgress = nil
            }
            lastOutgoingProgressUpdateAt = nil
            removed = true
        }

        let incomingIDs = incomingStoreSyncTransfers.compactMap { id, transfer in
            transfer.sourcePeer == peer ? id : nil
        }
        for id in incomingIDs {
            incomingStoreSyncTransfers.removeValue(forKey: id)
            if incomingStoreSyncProgress?.id == id {
                incomingStoreSyncProgress = nil
            }
            lastIncomingProgressUpdateAt = nil
            removed = true
        }

        if pendingStoreSyncOffer?.fromPeerID == peer {
            pendingStoreSyncOffer = nil
            removed = true
        }

        refreshStoreSyncSendingState()
        setStoreSyncProcessing(active: false, message: nil)
        return removed
    }

    private func handleStoreSyncCancel(_ payload: BluetoothStoreSyncCancelPayload, from peer: MCPeerID) {
        var cancelledAnything = false

        if outgoingStoreSyncTransfers.removeValue(forKey: payload.transferID) != nil {
            markOutgoingTransferCancelled(payload.transferID)
            if outgoingStoreSyncProgress?.id == payload.transferID {
                outgoingStoreSyncProgress = nil
            }
            lastOutgoingProgressUpdateAt = nil
            cancelledAnything = true
        }

        if incomingStoreSyncTransfers.removeValue(forKey: payload.transferID) != nil {
            if incomingStoreSyncProgress?.id == payload.transferID {
                incomingStoreSyncProgress = nil
            }
            lastIncomingProgressUpdateAt = nil
            cancelledAnything = true
        }

        if pendingStoreSyncOffer?.payload.transferID == payload.transferID {
            pendingStoreSyncOffer = nil
            cancelledAnything = true
        }

        refreshStoreSyncSendingState()
        setStoreSyncProcessing(active: false, message: nil)
        guard cancelledAnything else { return }

        let reason = payload.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let reason, !reason.isEmpty {
            updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_cancelled_with_reason_format", comment: "Peer cancelled with reason"), peer.displayName, reason))
        } else {
            updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_cancelled_format", comment: "Peer cancelled"), peer.displayName))
        }
    }

    private func clearSessionRuntimeState() {
        liveSessionParticipants.removeAll()
        outgoingStoreSyncTransfers.removeAll()
        incomingStoreSyncTransfers.removeAll()
        pendingIncomingChunkEvents.removeAll(keepingCapacity: false)
        isChunkFlushScheduled = false
        outgoingTransferCancellationLock.lock()
        cancelledOutgoingTransferIDs.removeAll(keepingCapacity: false)
        outgoingTransferCancellationLock.unlock()
        storeSyncPreparingID = nil
        isStoreSyncPreparing = false
        storeSyncPreparationMessage = nil
        isStoreSyncProcessing = false
        storeSyncProcessingMessage = nil
        outgoingStoreSyncProgress = nil
        incomingStoreSyncProgress = nil
        lastOutgoingProgressUpdateAt = nil
        lastIncomingProgressUpdateAt = nil

        pendingStoreSync = nil
        pendingStoreSyncOffer = nil
        pendingStoreSyncStatusAlert = nil
        pendingLiveInvite = nil
        latestLiveSnapshot = nil
        latestInviteResponse = nil
        pendingLiveOpRequest = nil
        latestLiveOpCommit = nil
        latestLiveOpAck = nil
        latestLiveResyncRequest = nil

        refreshStoreSyncSendingState()
    }

    private func isBonjourConfigurationMissing(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NetService.errorDomain && nsError.code == -72008
    }

    private func localizedNetworkFailure(prefix: String, error: Error) -> String {
        if isBonjourConfigurationMissing(error) {
            return String(format: NSLocalizedString("network_error_bonjour_missing_format", comment: "Bonjour missing"), prefix)
        }

        if isLocalPermissionDenied(error) {
            return String(format: NSLocalizedString("network_error_local_permission_format", comment: "Local permission"), prefix)
        }

        return String(format: NSLocalizedString("network_error_other_format", comment: "Network other"), prefix, error.localizedDescription)
    }

    private func addDiscoveredPeer(_ peer: MCPeerID) {
        guard peer != peerID else { return }
        guard !discoveredPeers.contains(where: { $0 == peer }) else { return }
        discoveredPeers.append(peer)
        discoveredPeers.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func removeDiscoveredPeer(_ peer: MCPeerID) {
        discoveredPeers.removeAll { $0 == peer }
    }

    private func updateConnectedPeers() {
        connectedPeers = session.connectedPeers.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        discoveredPeers.removeAll { candidate in
            connectedPeers.contains(where: { $0 == candidate })
        }
        liveSessionParticipants = liveSessionParticipants.mapValues { names in
            names.intersection(Set(connectedPeers.map(\.displayName)))
        }
    }

    private func handleIncomingMessage(_ message: BluetoothSyncMessage, from peer: MCPeerID) {
        switch message {
        case let .storeSync(payload):
            pendingStoreSync = BluetoothReceivedStoreSync(fromPeerName: peer.displayName, payload: payload)
            statusMessage = String(format: NSLocalizedString("status_received_data_sync_format", comment: "Received data sync"), peer.displayName)

        case let .storeSyncOffer(payload):
            pendingStoreSyncOffer = BluetoothReceivedStoreSyncOffer(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )
            statusMessage = String(format: NSLocalizedString("status_received_sync_request_format", comment: "Received sync request"), peer.displayName)

        case let .storeSyncOfferResponse(payload):
            guard let transfer = outgoingStoreSyncTransfers[payload.transferID] else { return }
            if payload.accepted {
                setStoreSyncProcessing(active: true, message: NSLocalizedString("status_peer_confirmed_starting_transfer", comment: "Peer confirmed starting transfer"))
                updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_confirmed_receiving_format", comment: "Peer confirmed receiving"), peer.displayName), showGlobalAlert: false)
                startSendingStoreSyncTransfer(payload.transferID)
            } else {
                outgoingStoreSyncTransfers.removeValue(forKey: payload.transferID)
                clearOutgoingTransferCancellationMark(payload.transferID)
                refreshStoreSyncSendingState()
                outgoingStoreSyncProgress = nil
                lastOutgoingProgressUpdateAt = nil
                setStoreSyncProcessing(active: false, message: nil)
                updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_rejected_format", comment: "Peer rejected"), transfer.targetPeer.displayName))
            }

        case let .storeSyncChunk(payload):
            storeSyncTransferQueue.async { [weak self] in
                self?.enqueueIncomingStoreSyncChunk(payload, from: peer)
            }

        case let .storeSyncCancel(payload):
            handleStoreSyncCancel(payload, from: peer)

        case let .storeSyncReceiveAck(payload):
            guard let transfer = outgoingStoreSyncTransfers[payload.transferID] else { return }

            if payload.received {
                // Show confirmed progress briefly before clearing
                if outgoingStoreSyncProgress?.id == payload.transferID {
                    outgoingStoreSyncProgress = BluetoothStoreSyncProgress(
                        id: payload.transferID,
                        peerName: transfer.targetPeer.displayName,
                        transferredChunks: transfer.offer.totalChunks,
                        totalChunks: transfer.offer.totalChunks,
                        transferredBytes: transfer.offer.totalBytes,
                        totalBytes: transfer.offer.totalBytes,
                        isSending: true,
                        isConfirmed: true
                    )
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self else { return }
                    self.outgoingStoreSyncTransfers.removeValue(forKey: payload.transferID)
                    self.clearOutgoingTransferCancellationMark(payload.transferID)
                    if self.outgoingStoreSyncProgress?.id == payload.transferID {
                        self.outgoingStoreSyncProgress = nil
                    }
                    self.lastOutgoingProgressUpdateAt = nil
                    self.refreshStoreSyncSendingState()
                    self.setStoreSyncProcessing(active: false, message: nil)
                }
            } else {
                outgoingStoreSyncTransfers.removeValue(forKey: payload.transferID)
                clearOutgoingTransferCancellationMark(payload.transferID)
                if outgoingStoreSyncProgress?.id == payload.transferID {
                    outgoingStoreSyncProgress = nil
                }
                lastOutgoingProgressUpdateAt = nil
                refreshStoreSyncSendingState()
                setStoreSyncProcessing(active: false, message: nil)
            }

            if payload.received {
                updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_confirmed_complete_format", comment: "Peer confirmed complete"), transfer.targetPeer.displayName))
            } else {
                let reason = payload.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let reason, !reason.isEmpty {
                    updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_receive_failed_reason_format", comment: "Peer receive failed reason"), transfer.targetPeer.displayName, reason))
                } else {
                    updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_receive_failed_retry_format", comment: "Peer receive failed retry"), transfer.targetPeer.displayName))
                }
            }

        case let .liveInvite(payload):
            pendingLiveInvite = BluetoothReceivedLiveInvite(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )
            statusMessage = NSLocalizedString("status_received_collab_invite", comment: "Received collab invite")

        case let .liveInviteResponse(payload):
            if payload.accepted {
                liveSessionParticipants[payload.sessionID, default: []].insert(peer.displayName)
                statusMessage = String(format: NSLocalizedString("status_peer_joined_collab_format", comment: "Peer joined collab"), peer.displayName)
                postGlobalBluetoothAlert(title: NSLocalizedString("alert_bluetooth_collab_title", comment: "Bluetooth collab title"), message: String(format: NSLocalizedString("status_peer_joined_collab_format", comment: "Peer joined collab"), peer.displayName))
            } else {
                liveSessionParticipants[payload.sessionID, default: []].remove(peer.displayName)
                statusMessage = String(format: NSLocalizedString("status_peer_rejected_collab_format", comment: "Peer rejected collab"), peer.displayName)
                postGlobalBluetoothAlert(title: NSLocalizedString("alert_bluetooth_collab_title", comment: "Bluetooth collab title"), message: String(format: NSLocalizedString("status_peer_rejected_collab_format", comment: "Peer rejected collab"), peer.displayName))
            }
            latestInviteResponse = BluetoothReceivedInviteResponse(fromPeerName: peer.displayName, payload: payload)

        case let .liveSnapshot(payload):
            liveSessionParticipants[payload.sessionID, default: []].insert(peer.displayName)
            latestLiveSnapshot = BluetoothReceivedLiveSnapshot(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )

        case let .liveOpRequest(payload):
            pendingLiveOpRequest = BluetoothReceivedLiveOpRequest(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )

        case let .liveOpCommit(payload):
            latestLiveOpCommit = BluetoothReceivedLiveOpCommit(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )

        case let .liveOpAck(payload):
            latestLiveOpAck = BluetoothReceivedLiveOpAck(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )

        case let .liveResyncRequest(payload):
            latestLiveResyncRequest = BluetoothReceivedLiveResyncRequest(
                fromPeerID: peer,
                fromPeerName: peer.displayName,
                payload: payload
            )
        }
    }
}

extension BluetoothSyncManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        DispatchQueue.main.async {
            print("[Bluetooth] Auto-accepting invitation from \(peerID.displayName)")
            self.statusMessage = String(format: NSLocalizedString("status_peer_requesting_connection_format", comment: "Peer requesting connection"), peerID.displayName)
            invitationHandler(true, self.session)
        }
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: any Error
    ) {
        DispatchQueue.main.async {
            if self.isLocalPermissionDenied(error) {
                self.localNetworkPermissionStatus = .denied
            }
            self.statusMessage = self.localizedNetworkFailure(prefix: NSLocalizedString("bluetooth_broadcast", comment: "Bluetooth broadcast"), error: error)
            self.stopAdvertising()
        }
    }
}

extension BluetoothSyncManager: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        DispatchQueue.main.async {
            self.addDiscoveredPeer(peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.removeDiscoveredPeer(peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        DispatchQueue.main.async {
            if self.isLocalPermissionDenied(error) {
                self.localNetworkPermissionStatus = .denied
            }
            self.statusMessage = self.localizedNetworkFailure(prefix: NSLocalizedString("device_search", comment: "Device search"), error: error)
            self.stopBrowsing()
        }
    }
}

extension BluetoothSyncManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.updateConnectedPeers()
            switch state {
            case .connected:
                self.statusMessage = String(format: NSLocalizedString("status_peer_connected_format", comment: "Peer connected"), peerID.displayName)
            case .connecting:
                self.statusMessage = String(format: NSLocalizedString("status_connecting_to_format", comment: "Connecting to"), peerID.displayName)
            case .notConnected:
                let cleaned = self.cleanupStoreSyncTransfers(for: peerID)
                if cleaned {
                    self.updateStoreSyncStatus(String(format: NSLocalizedString("status_peer_disconnected_sync_cancelled_format", comment: "Peer disconnected sync cancelled"), peerID.displayName))
                } else {
                    self.statusMessage = String(format: NSLocalizedString("status_peer_disconnected_format", comment: "Peer disconnected"), peerID.displayName)
                }
            @unknown default:
                self.statusMessage = String(format: NSLocalizedString("status_connection_updated_format", comment: "Connection updated"), peerID.displayName)
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = decodeMessage(data) else {
            DispatchQueue.main.async {
                self.statusMessage = NSLocalizedString("status_received_unparseable_bluetooth", comment: "Received unparseable bluetooth")
            }
            return
        }

        if case let .storeSyncChunk(payload) = message {
            storeSyncTransferQueue.async { [weak self] in
                self?.enqueueIncomingStoreSyncChunk(payload, from: peerID)
            }
            return
        }

        DispatchQueue.main.async {
            self.handleIncomingMessage(message, from: peerID)
        }
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {
    }

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {
    }

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {
    }
}
