import Foundation
import CloudKit

@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?

    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "GameRecord"

    private var isAvailable: Bool = true

    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }

    /// Check if iCloud + CloudKit are available. Returns nil on success, or an error string.
    func checkAvailability() async -> String? {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                isAvailable = true
                return nil
            case .noAccount:
                return NSLocalizedString("icloud_error_no_account", comment: "No iCloud account")
            case .restricted:
                return NSLocalizedString("icloud_error_restricted", comment: "iCloud restricted")
            case .couldNotDetermine:
                return NSLocalizedString("icloud_error_could_not_determine", comment: "Could not determine")
            @unknown default:
                return NSLocalizedString("icloud_error_unknown", comment: "Unknown iCloud status")
            }
        } catch {
            // "Could not get container configuration" - container not set up yet
            lastSyncError = error.localizedDescription
            return error.localizedDescription
        }
    }

    // MARK: - Public API

    func uploadGame(_ game: SavedGame) async {
        if let error = await checkAvailability() {
            lastSyncError = error
            return
        }

        do {
            let data = try JSONEncoder().encode(game)
            let recordID = CKRecord.ID(recordName: game.id.uuidString)

            do {
                let existing = try await database.record(for: recordID)
                existing["gameData"] = CKAsset(fileURL: writeTempFile(data))
                existing["version"] = (existing["version"] as? Int64 ?? 0) + 1
                existing["updatedAt"] = Date()
                _ = try await database.save(existing)
            } catch CKError.unknownItem {
                let record = CKRecord(recordType: recordType, recordID: recordID)
                record["homeTeamName"] = game.homeTeamName
                record["awayTeamName"] = game.awayTeamName
                record["savedAt"] = game.savedAt
                record["gameData"] = CKAsset(fileURL: writeTempFile(data))
                record["version"] = Int64(1)
                record["updatedAt"] = Date()
                _ = try await database.save(record)
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func deleteGame(_ gameID: UUID) async {
        if let error = await checkAvailability() {
            lastSyncError = error
            return
        }
        do {
            let recordID = CKRecord.ID(recordName: gameID.uuidString)
            try await database.deleteRecord(withID: recordID)
        } catch CKError.unknownItem {
            // Already deleted, ignore
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func fetchAllGames() async -> [SavedGame] {
        if let error = await checkAvailability() {
            lastSyncError = error
            return []
        }

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        var games: [SavedGame] = []

        do {
            let result = try await database.records(matching: query, desiredKeys: ["gameData"])
            for match in result.matchResults {
                guard let record = try? match.1.get(),
                      let asset = record["gameData"] as? CKAsset,
                      let fileURL = asset.fileURL,
                      let data = try? Data(contentsOf: fileURL),
                      let game = try? JSONDecoder().decode(SavedGame.self, from: data) else {
                    continue
                }
                games.append(game)
            }
        } catch {
            // "record type not found" means no games uploaded yet - not an error
            let err = error as NSError
            if err.domain == CKErrorDomain {
                let code = CKError.Code(rawValue: err.code) ?? .unknownItem
                if code == .unknownItem || code == .zoneNotFound || code == .userDeletedZone {
                    return []
                }
            }
            lastSyncError = error.localizedDescription
        }

        return games
    }

    /// Sync local games marked as cloud-enabled to CloudKit, and download any new games.
    /// Returns newly downloaded games that should be merged into local storage.
    func sync(cloudEnabledIDs: Set<UUID>, localGames: [SavedGame]) async -> [SavedGame] {
        isSyncing = true
        defer { isSyncing = false }

        // Upload local games marked for cloud (skip if already uploaded - uploadGame handles update)
        for game in localGames where cloudEnabledIDs.contains(game.id) {
            await uploadGame(game)
        }

        // Download all cloud games
        let cloudGames = await fetchAllGames()

        // Delete cloud games no longer locally marked
        for cloudGame in cloudGames {
            if !cloudEnabledIDs.contains(cloudGame.id) {
                await deleteGame(cloudGame.id)
            }
        }

        // Return new cloud games not in local storage
        let localIDs = Set(localGames.map(\.id))
        return cloudGames.filter { !localIDs.contains($0.id) }
    }

    // MARK: - Helpers

    private func writeTempFile(_ data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(UUID().uuidString)
        try? data.write(to: url)
        return url
    }
}
