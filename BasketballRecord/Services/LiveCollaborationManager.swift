import Foundation
import MultipeerConnectivity
import CryptoKit

@MainActor
final class LiveCollaborationManager: ObservableObject {
    weak var bluetooth: BluetoothSyncManager?
    weak var store: AppStore?

    var activeLiveSessionID: UUID?
    var liveRole: LiveCollaborationRole?
    var liveVersion = 0
    var liveStateHash = ""
    var liveHostPeerName: String?
    var liveHostPeerID: MCPeerID?
    var liveParticipantNames: Set<String> = []
    var localLiveOpSeq = 0
    var liveCommitHistory: [BluetoothLiveOpCommitPayload] = []
    var peerAckVersionByDeviceID: [String: Int] = [:]
    var isApplyingRemoteSnapshot = false

    var onBuildStatePayload: (() -> (snapshot: GameSnapshot, undoStack: [GameSnapshot], gameID: UUID?))?
    var onApplyOperation: ((BluetoothLiveOperationPayload) -> Bool)?
    var onStateChanged: ((GameSnapshot, _ undoStack: [GameSnapshot], _ redo: [GameSnapshot], _ gameID: UUID?) -> Void)?
    var onAlert: ((String) -> Void)?

    init() {}

    var isLiveSessionActive: Bool {
        activeLiveSessionID != nil && liveRole != nil
    }

    func sendLiveInvite(to peers: [MCPeerID]) {
        guard let bluetooth, let store else {
            onAlert?(NSLocalizedString("collab_invite_send_failed", comment: "Invite send failed message"))
            return
        }
        let payload = buildLiveStatePayload()
        liveVersion = 0
        liveStateHash = stateHash(for: payload)
        liveRole = .host
        liveHostPeerName = nil
        liveHostPeerID = nil
        liveParticipantNames.removeAll()
        localLiveOpSeq = 0
        liveCommitHistory.removeAll()
        peerAckVersionByDeviceID.removeAll()

        guard let sessionID = bluetooth.sendLiveInvite(
            players: store.players,
            teams: store.teams,
            state: payload,
            stateVersion: liveVersion,
            stateHash: liveStateHash,
            to: peers
        ) else {
            onAlert?(NSLocalizedString("collab_invite_send_failed", comment: "Invite send failed message"))
            return
        }

        activeLiveSessionID = sessionID
        onAlert?(NSLocalizedString("collab_invite_sent_waiting", comment: "Invite sent, waiting message"))
    }

    func handleInviteResponse(_ response: BluetoothReceivedInviteResponse) {
        guard let bluetooth else { return }
        guard response.payload.sessionID == activeLiveSessionID else { return }
        if response.payload.accepted {
            bluetooth.noteAcceptedLiveSession(sessionID: response.payload.sessionID, with: response.fromPeerName)
            liveParticipantNames.insert(response.fromPeerName)
            sendAuthoritativeSnapshot(reason: "New device joined")
        } else {
            liveParticipantNames.remove(response.fromPeerName)
        }
    }

    func applyRemoteLiveSnapshot(_ incoming: BluetoothReceivedLiveSnapshot) {
        guard let bluetooth else { return }
        let isNewSession = activeLiveSessionID != incoming.payload.sessionID
        let needsParticipantBootstrap = liveRole != .participant
        if isNewSession || needsParticipantBootstrap {
            activeLiveSessionID = incoming.payload.sessionID
            liveRole = .participant
            liveParticipantNames.removeAll()
            localLiveOpSeq = 0
            liveCommitHistory.removeAll()
            peerAckVersionByDeviceID.removeAll()
        }
        guard incoming.payload.sessionID == activeLiveSessionID else { return }
        liveHostPeerName = incoming.fromPeerName
        liveHostPeerID = incoming.fromPeerID
        bluetooth.noteAcceptedLiveSession(sessionID: incoming.payload.sessionID, with: incoming.fromPeerName)
        applyAuthoritativeState(
            incoming.payload.state,
            version: incoming.payload.version,
            hash: incoming.payload.stateHash
        )
    }

    func applyAuthoritativeState(_ state: BluetoothLiveGameStatePayload, version: Int, hash: String) {
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }

        let remoteSnapshot = snapshotForLocalClock(fromRemote: state.snapshot)
        liveVersion = version
        liveStateHash = hash

        onStateChanged?(remoteSnapshot, state.undoSnapshots, [], state.gameID)
    }

    func snapshotForLiveSync(_ source: GameSnapshot) -> GameSnapshot {
        var synced = source
        let now = Date()

        if synced.periodIsRunning && !synced.isPaused && !synced.isComplete {
            if let activeSince = synced.matchActiveSince {
                synced.matchElapsedSeconds += max(0, now.timeIntervalSince(activeSince))
            }
            synced.matchActiveSince = now

            if let activeSince = synced.periodActiveSince {
                synced.periodElapsedSeconds += max(0, now.timeIntervalSince(activeSince))
            }
            synced.periodActiveSince = now

            for (playerID, startedAt) in synced.activeSinceByPlayerID {
                synced.playingSecondsByPlayerID[playerID, default: 0] += max(0, now.timeIntervalSince(startedAt))
            }

            let onCourtIDs = Self.deduped(synced.homeOnCourtPlayerIDs + synced.awayOnCourtPlayerIDs)
            synced.activeSinceByPlayerID = Dictionary(uniqueKeysWithValues: onCourtIDs.map { ($0, now) })
        } else {
            synced.matchActiveSince = nil
            synced.periodActiveSince = nil
            synced.activeSinceByPlayerID = [:]
        }

        return synced
    }

    func snapshotForLocalClock(fromRemote source: GameSnapshot) -> GameSnapshot {
        var adjusted = source
        let now = Date()

        if adjusted.periodIsRunning && !adjusted.isPaused && !adjusted.isComplete {
            adjusted.matchActiveSince = now
            adjusted.periodActiveSince = now
            let onCourtIDs = Self.deduped(adjusted.homeOnCourtPlayerIDs + adjusted.awayOnCourtPlayerIDs)
            adjusted.activeSinceByPlayerID = Dictionary(uniqueKeysWithValues: onCourtIDs.map { ($0, now) })
        } else {
            adjusted.matchActiveSince = nil
            adjusted.periodActiveSince = nil
            adjusted.activeSinceByPlayerID = [:]
        }

        return adjusted
    }

    private static func deduped<T: Hashable>(_ elements: [T]) -> [T] {
        var seen: Set<T> = []
        return elements.filter { seen.insert($0).inserted }
    }

    func buildLiveStatePayload() -> BluetoothLiveGameStatePayload {
        guard let state = onBuildStatePayload?() else {
            return BluetoothLiveGameStatePayload(
                gameID: nil,
                snapshot: GameSnapshot(),
                undoSnapshots: []
            )
        }
        return BluetoothLiveGameStatePayload(
            gameID: state.gameID,
            snapshot: snapshotForLiveSync(state.snapshot),
            undoSnapshots: state.undoStack
        )
    }

    func stateHash(for payload: BluetoothLiveGameStatePayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func sendAuthoritativeSnapshot(reason: String, to peers: [MCPeerID]? = nil) {
        guard let bluetooth,
              liveRole == .host,
              let sessionID = activeLiveSessionID else {
            return
        }

        let payload = buildLiveStatePayload()
        liveStateHash = stateHash(for: payload)
        bluetooth.sendLiveSnapshot(
            sessionID: sessionID,
            state: payload,
            version: liveVersion,
            stateHash: liveStateHash,
            reason: reason,
            to: peers
        )
    }

    func requestLiveResync(reason: String) {
        guard let bluetooth,
              let sessionID = activeLiveSessionID else { return }
        bluetooth.sendLiveResyncRequest(
            sessionID: sessionID,
            expectedVersion: liveVersion,
            reason: reason,
            to: liveHostPeerID
        )
    }

    func handleIncomingLiveOpRequest(_ incoming: BluetoothReceivedLiveOpRequest) {
        guard let bluetooth else { return }
        bluetooth.clearPendingLiveOpRequest()
        guard liveRole == .host,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        liveParticipantNames.insert(incoming.fromPeerName)

        guard incoming.payload.op.baseVersion == liveVersion else {
            sendAuthoritativeSnapshot(reason: "Version mismatch, triggering resync", to: [incoming.fromPeerID])
            return
        }

        guard let apply = onApplyOperation else { return }
        let applied = apply(incoming.payload.op.payload)
        guard applied else {
            sendAuthoritativeSnapshot(reason: "Operation could not be applied, triggering resync", to: [incoming.fromPeerID])
            return
        }

        liveVersion += 1
        let payload = buildLiveStatePayload()
        liveStateHash = stateHash(for: payload)
        let commit = BluetoothLiveOpCommitPayload(
            sessionID: sessionID,
            op: incoming.payload.op,
            newVersion: liveVersion,
            stateHash: liveStateHash
        )
        appendLiveCommitHistory(commit)
        bluetooth.sendLiveOpCommit(sessionID: sessionID, commit: commit)
    }

    func handleIncomingLiveOpCommit(_ incoming: BluetoothReceivedLiveOpCommit) {
        guard let bluetooth else { return }
        guard liveRole == .participant,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        liveHostPeerName = incoming.fromPeerName
        liveHostPeerID = incoming.fromPeerID

        guard incoming.payload.op.baseVersion == liveVersion,
              incoming.payload.newVersion == liveVersion + 1 else {
            requestLiveResync(reason: "Commit version mismatch")
            return
        }

        guard let apply = onApplyOperation else { return }
        let applied = apply(incoming.payload.op.payload)
        guard applied else {
            requestLiveResync(reason: "Commit could not be applied locally")
            return
        }

        liveVersion = incoming.payload.newVersion
        let computedHash = stateHash(for: buildLiveStatePayload())
        guard computedHash == incoming.payload.stateHash else {
            requestLiveResync(reason: "Hash mismatch after commit")
            return
        }

        liveStateHash = incoming.payload.stateHash
        bluetooth.sendLiveOpAck(
            sessionID: sessionID,
            opID: incoming.payload.op.opID,
            version: liveVersion,
            to: liveHostPeerID
        )
    }

    func handleIncomingLiveOpAck(_ incoming: BluetoothReceivedLiveOpAck) {
        guard let bluetooth else { return }
        bluetooth.clearLatestLiveOpAck()
        guard liveRole == .host,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        let currentVersion = peerAckVersionByDeviceID[incoming.payload.deviceID] ?? -1
        if incoming.payload.version > currentVersion {
            peerAckVersionByDeviceID[incoming.payload.deviceID] = incoming.payload.version
        }
    }

    func handleIncomingResyncRequest(_ incoming: BluetoothReceivedLiveResyncRequest) {
        guard let bluetooth else { return }
        guard liveRole == .host,
              let sessionID = activeLiveSessionID,
              incoming.payload.sessionID == sessionID else {
            return
        }

        liveParticipantNames.insert(incoming.fromPeerName)

        if let commits = missingCommits(after: incoming.payload.expectedVersion), !commits.isEmpty {
            for commit in commits {
                bluetooth.sendLiveOpCommit(sessionID: sessionID, commit: commit, to: [incoming.fromPeerID])
            }
            return
        }

        sendAuthoritativeSnapshot(reason: "Resync request received", to: [incoming.fromPeerID])
    }

    private func appendLiveCommitHistory(_ commit: BluetoothLiveOpCommitPayload) {
        liveCommitHistory.append(commit)
        if liveCommitHistory.count > 300 {
            liveCommitHistory.removeFirst(liveCommitHistory.count - 300)
        }
    }

    private func missingCommits(after version: Int) -> [BluetoothLiveOpCommitPayload]? {
        guard version < liveVersion else { return [] }
        let expectedRange = (version + 1)...liveVersion
        let commits = liveCommitHistory.filter { expectedRange.contains($0.newVersion) }
            .sorted { $0.newVersion < $1.newVersion }
        let versions = commits.map(\.newVersion)
        let expected = Array(expectedRange)
        return versions == expected ? commits : nil
    }

    @discardableResult
    func submitLiveOperation(_ payload: BluetoothLiveOperationPayload, applyLocal: () -> Bool) -> Bool {
        guard let bluetooth else { return applyLocal() }
        guard let sessionID = activeLiveSessionID,
              let role = liveRole else {
            return applyLocal()
        }

        localLiveOpSeq += 1
        let operation = BluetoothLiveOperation(
            opID: UUID(),
            deviceID: bluetooth.localDeviceID,
            seq: localLiveOpSeq,
            baseVersion: liveVersion,
            payload: payload
        )

        switch role {
        case .host:
            let changed = applyLocal()
            guard changed else { return false }
            liveVersion += 1
            liveStateHash = stateHash(for: buildLiveStatePayload())
            let commit = BluetoothLiveOpCommitPayload(
                sessionID: sessionID,
                op: operation,
                newVersion: liveVersion,
                stateHash: liveStateHash
            )
            appendLiveCommitHistory(commit)
            bluetooth.sendLiveOpCommit(sessionID: sessionID, commit: commit)
            return true

        case .participant:
            let sent = bluetooth.sendLiveOpRequest(
                sessionID: sessionID,
                op: operation,
                toHost: liveHostPeerID,
                hostName: liveHostPeerName
            )
            if !sent {
                onAlert?(NSLocalizedString("collab_operation_send_failed", comment: "Operation send failed"))
            }
            return false
        }
    }

    func resetSession() {
        activeLiveSessionID = nil
        liveRole = nil
        liveHostPeerName = nil
        liveHostPeerID = nil
        liveParticipantNames.removeAll()
        liveVersion = 0
        liveStateHash = ""
        localLiveOpSeq = 0
        liveCommitHistory.removeAll()
        peerAckVersionByDeviceID.removeAll()
    }
}
