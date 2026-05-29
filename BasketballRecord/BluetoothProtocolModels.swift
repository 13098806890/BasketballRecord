import Foundation
import MultipeerConnectivity

enum LocalNetworkPermissionStatus {
    case unknown
    case checking
    case authorized
    case denied
}

struct BluetoothStoreSyncPayload: Codable, Hashable {
    var players: [Player]
    var teams: [Team]
    var savedGames: [SavedGame]
}

struct BluetoothStoreSyncOfferPayload: Codable, Hashable {
    var transferID: UUID
    var snapshotVersion: Int
    var snapshotHash: String
    var includePlayers: Bool
    var includeTeams: Bool
    var includeSavedGames: Bool
    var playerCount: Int
    var teamCount: Int
    var gameCount: Int
    var playerNamesPreview: [String] = []
    var teamNamesPreview: [String] = []
    var gameTitlesPreview: [String] = []
    var totalChunks: Int
    var totalBytes: Int
}

struct BluetoothStoreSyncOfferResponsePayload: Codable, Hashable {
    var transferID: UUID
    var accepted: Bool
}

struct BluetoothStoreSyncChunkPayload: Codable, Hashable {
    var transferID: UUID
    var chunkIndex: Int
    var totalChunks: Int
    var totalBytes: Int
    var chunkData: Data
}

struct BluetoothStoreSyncCancelPayload: Codable, Hashable {
    var transferID: UUID
    var reason: String?
}

struct BluetoothStoreSyncReceiveAckPayload: Codable, Hashable {
    var transferID: UUID
    var received: Bool
    var reason: String?
}

struct BluetoothStoreSyncProgress: Identifiable {
    let id: UUID
    let peerName: String
    let transferredChunks: Int
    let totalChunks: Int
    let transferredBytes: Int
    let totalBytes: Int
    let isSending: Bool

    var fractionCompleted: Double {
        guard totalChunks > 0 else { return 0 }
        return min(1, Double(transferredChunks) / Double(totalChunks))
    }
}

struct BluetoothStoreSyncStatusAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct BluetoothLiveGameStatePayload: Codable, Hashable {
    var gameID: UUID?
    var snapshot: GameSnapshot
    var undoSnapshots: [GameSnapshot]
}

struct BluetoothLiveInvitePayload: Codable, Hashable {
    var sessionID: UUID
    var inviterName: String
    var hostDeviceID: String
    var stateVersion: Int
    var stateHash: String
    var players: [Player]
    var teams: [Team]
    var state: BluetoothLiveGameStatePayload
}

struct BluetoothLiveInviteResponsePayload: Codable, Hashable {
    var sessionID: UUID
    var accepted: Bool
    var responderName: String
}

struct BluetoothLiveSnapshotPayload: Codable, Hashable {
    var sessionID: UUID
    var hostDeviceID: String
    var version: Int
    var stateHash: String
    var reason: String?
    var state: BluetoothLiveGameStatePayload
}

enum BluetoothLiveSide: String, Codable, Hashable {
    case home
    case away
}

enum BluetoothLiveStatAction: String, Codable, Hashable {
    case twoMade
    case twoMissed
    case threeMade
    case threeMissed
    case bonusMade
    case bonusMissed
    case freeThrowMade
    case freeThrowMissed
    case foul
    case assist
    case rebound
    case block
    case steal
    case turnover
}

enum BluetoothLiveOperationPayload: Codable, Hashable {
    case record(action: BluetoothLiveStatAction, playerID: UUID, side: BluetoothLiveSide)
    case togglePeriod(at: Date)
    case togglePause(at: Date)
    case substitution(outgoingPlayerID: UUID, incomingPlayerID: UUID, side: BluetoothLiveSide, at: Date)
    case lateArrival(playerID: UUID, side: BluetoothLiveSide)
    case finishGame(at: Date)
    case resetGame
    case undo
    case redo
}

struct BluetoothLiveOperation: Codable, Hashable {
    var opID: UUID
    var deviceID: String
    var seq: Int
    var baseVersion: Int
    var payload: BluetoothLiveOperationPayload
}

struct BluetoothLiveOpRequestPayload: Codable, Hashable {
    var sessionID: UUID
    var op: BluetoothLiveOperation
}

struct BluetoothLiveOpCommitPayload: Codable, Hashable {
    var sessionID: UUID
    var op: BluetoothLiveOperation
    var newVersion: Int
    var stateHash: String
}

struct BluetoothLiveOpAckPayload: Codable, Hashable {
    var sessionID: UUID
    var opID: UUID
    var version: Int
    var deviceID: String
}

struct BluetoothLiveResyncRequestPayload: Codable, Hashable {
    var sessionID: UUID
    var expectedVersion: Int
    var reason: String
}

enum BluetoothSyncMessage: Codable {
    case storeSync(BluetoothStoreSyncPayload)
    case storeSyncOffer(BluetoothStoreSyncOfferPayload)
    case storeSyncOfferResponse(BluetoothStoreSyncOfferResponsePayload)
    case storeSyncChunk(BluetoothStoreSyncChunkPayload)
    case storeSyncCancel(BluetoothStoreSyncCancelPayload)
    case storeSyncReceiveAck(BluetoothStoreSyncReceiveAckPayload)
    case liveInvite(BluetoothLiveInvitePayload)
    case liveInviteResponse(BluetoothLiveInviteResponsePayload)
    case liveSnapshot(BluetoothLiveSnapshotPayload)
    case liveOpRequest(BluetoothLiveOpRequestPayload)
    case liveOpCommit(BluetoothLiveOpCommitPayload)
    case liveOpAck(BluetoothLiveOpAckPayload)
    case liveResyncRequest(BluetoothLiveResyncRequestPayload)
}

struct BluetoothReceivedStoreSync: Identifiable {
    let id = UUID()
    let fromPeerName: String
    let payload: BluetoothStoreSyncPayload
}

struct BluetoothReceivedStoreSyncOffer: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothStoreSyncOfferPayload
}

struct BluetoothReceivedLiveInvite: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothLiveInvitePayload
}

struct BluetoothReceivedLiveSnapshot: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothLiveSnapshotPayload
}

struct BluetoothReceivedInviteResponse: Identifiable {
    let id = UUID()
    let fromPeerName: String
    let payload: BluetoothLiveInviteResponsePayload
}

struct BluetoothReceivedLiveOpRequest: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothLiveOpRequestPayload
}

struct BluetoothReceivedLiveOpCommit: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothLiveOpCommitPayload
}

struct BluetoothReceivedLiveOpAck: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothLiveOpAckPayload
}

struct BluetoothReceivedLiveResyncRequest: Identifiable {
    let id = UUID()
    let fromPeerID: MCPeerID
    let fromPeerName: String
    let payload: BluetoothLiveResyncRequestPayload
}
