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
        print("[CloudKit] Container: \(container.containerIdentifier ?? "nil")")
        print("[CloudKit] DB: privateCloudDatabase")
    }

    /// Check if iCloud + CloudKit are available. Returns nil on success, or an error string.
    func checkAvailability() async -> String? {
        print("[CloudKit] checkAvailability called")
        do {
            let status = try await container.accountStatus()
            print("[CloudKit] accountStatus: \(status.rawValue)")
            switch status {
            case .available:
                print("[CloudKit] iCloud account available")
                isAvailable = true
                return nil
            case .noAccount:
                print("[CloudKit] No iCloud account")
                return NSLocalizedString("icloud_error_no_account", comment: "No iCloud account")
            case .restricted:
                print("[CloudKit] iCloud restricted")
                return NSLocalizedString("icloud_error_restricted", comment: "iCloud restricted")
            case .couldNotDetermine:
                print("[CloudKit] Could not determine account status")
                return NSLocalizedString("icloud_error_could_not_determine", comment: "Could not determine")
            case .temporarilyUnavailable:
                print("[CloudKit] Temporarily unavailable")
                return NSLocalizedString("icloud_error_temporarily_unavailable", comment: "Temporarily unavailable")
            @unknown default:
                print("[CloudKit] Unknown account status: \(status.rawValue)")
                return NSLocalizedString("icloud_error_unknown", comment: "Unknown iCloud status")
            }
        } catch {
            print("[CloudKit] accountStatus error: \(error)")
            print("[CloudKit] error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            print("[CloudKit] error description: \(error.localizedDescription)")
            lastSyncError = error.localizedDescription
            return error.localizedDescription
        }
    }

    // MARK: - Public API

    func uploadGame(_ game: SavedGame) async {
        print("[CloudKit] uploadGame called for game \(game.id)")
        if let error = await checkAvailability() {
            print("[CloudKit] uploadGame skipped - availability check failed: \(error)")
            lastSyncError = error
            return
        }

        do {
            let data = try JSONEncoder().encode(game)
            print("[CloudKit] Encoded game: \(data.count) bytes")
            let recordID = CKRecord.ID(recordName: game.id.uuidString)
            let fileURL = writeTempFile(data)
            defer { try? FileManager.default.removeItem(at: fileURL) }

            do {
                print("[CloudKit] Checking for existing record: \(recordID.recordName)")
                let existing = try await database.record(for: recordID)
                let cloudUpdatedAt = (existing["updatedAt"] as? Date) ?? game.savedAt
                if cloudUpdatedAt > game.savedAt {
                    print("[CloudKit] Skipping upload - cloud newer (cloud=\(cloudUpdatedAt), local=\(game.savedAt))")
                    return
                }
                print("[CloudKit] Existing record found, updating...")
                existing["gameData"] = CKAsset(fileURL: fileURL)
                existing["version"] = (existing["version"] as? Int64 ?? 0) + 1
                existing["updatedAt"] = Date()
                let saved = try await database.save(existing)
                print("[CloudKit] Record updated: \(saved.recordID.recordName)")
            } catch CKError.unknownItem {
                print("[CloudKit] No existing record, creating new one...")
                let record = CKRecord(recordType: recordType, recordID: recordID)
                record["homeTeamName"] = game.homeTeamName
                record["awayTeamName"] = game.awayTeamName
                record["savedAt"] = game.savedAt
                record["gameData"] = CKAsset(fileURL: fileURL)
                record["version"] = Int64(1)
                record["updatedAt"] = Date()
                let saved = try await database.save(record)
                print("[CloudKit] Record created: \(saved.recordID.recordName)")
            }
        } catch {
            print("[CloudKit] uploadGame error: \(error)")
            print("[CloudKit] error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            lastSyncError = error.localizedDescription
        }
    }

    func deleteGame(_ gameID: UUID) async {
        print("[CloudKit] deleteGame called for \(gameID)")
        if let error = await checkAvailability() {
            print("[CloudKit] deleteGame skipped - availability check failed: \(error)")
            lastSyncError = error
            return
        }
        do {
            let recordID = CKRecord.ID(recordName: gameID.uuidString)
            try await database.deleteRecord(withID: recordID)
            print("[CloudKit] Record deleted: \(recordID.recordName)")
        } catch CKError.unknownItem {
            print("[CloudKit] Record not found, ignoring")
        } catch {
            print("[CloudKit] deleteGame error: \(error)")
            print("[CloudKit] error domain: \((error as NSError).domain), code: \((error as NSError).code)")
            lastSyncError = error.localizedDescription
        }
    }

    /// Fetch games from CloudKit using known record IDs (avoids CKQuery index requirement).
    func fetchGames(ids: Set<UUID>) async -> [SavedGame] {
        print("[CloudKit] fetchGames called with \(ids.count) IDs")
        if let error = await checkAvailability() {
            print("[CloudKit] fetchGames skipped - availability check failed: \(error)")
            lastSyncError = error
            return []
        }

        guard !ids.isEmpty else {
            print("[CloudKit] No IDs to fetch")
            return []
        }

        let recordIDs = ids.map { CKRecord.ID(recordName: $0.uuidString) }
        return await withCheckedContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            var games: [SavedGame] = []
            operation.perRecordResultBlock = { _, recordResult in
                switch recordResult {
                case .success(let record):
                    if let asset = record["gameData"] as? CKAsset,
                       let fileURL = asset.fileURL,
                       let data = try? Data(contentsOf: fileURL),
                       let game = try? JSONDecoder().decode(SavedGame.self, from: data) {
                        games.append(game)
                    }
                case .failure(let error):
                    print("[CloudKit] Fetch error: \(error)")
                }
            }
            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("[CloudKit] Fetched \(games.count)/\(ids.count) games")
                    continuation.resume(returning: games)
                case .failure(let error):
                    print("[CloudKit] Batch fetch error: \(error)")
                    continuation.resume(returning: [])
                }
            }
            database.add(operation)
        }
    }

    /// Sync local games marked as cloud-enabled to CloudKit, and download any new games.
    /// Returns newly downloaded games that should be merged into local storage.
    func sync(cloudEnabledIDs: Set<UUID>, localGames: [SavedGame]) async -> (newGames: [SavedGame], updatedGames: [SavedGame], aiSummaryUpdates: [SavedGame]) {
        print("[CloudKit] sync called with \(cloudEnabledIDs.count) enabled IDs, \(localGames.count) local games")
        isSyncing = true
        defer { isSyncing = false }

        for game in localGames where cloudEnabledIDs.contains(game.id) {
            print("[CloudKit] Uploading local game \(game.id)")
            await uploadGame(game)
        }

        let cloudGames = await fetchGames(ids: cloudEnabledIDs)
        print("[CloudKit] Fetched \(cloudGames.count) cloud games")

        let localByID = Dictionary(uniqueKeysWithValues: localGames.map { ($0.id, $0) })
        var newGames: [SavedGame] = []
        var updatedGames: [SavedGame] = []
        for cloudGame in cloudGames {
            guard let local = localByID[cloudGame.id] else {
                newGames.append(cloudGame)
                continue
            }
            if cloudGame.savedAt > local.savedAt {
                var updated = cloudGame
                updated.groupIDs = local.groupIDs
                if local.aiSummary != nil {
                    updated.aiSummary = local.aiSummary
                }
                updatedGames.append(updated)
                print("[CloudKit] Cloud game newer (cloud=\(cloudGame.savedAt), local=\(local.savedAt)), will update local")
            }
        }
        print("[CloudKit] \(newGames.count) new games, \(updatedGames.count) updated games to download")

        let localIDs = Set(localGames.map(\.id))
        let existingGameIDs = Set(newGames.map(\.id)).union(Set(updatedGames.map(\.id)))
        let aiSummaryUpdates = cloudGames.filter { cloudGame in
            !existingGameIDs.contains(cloudGame.id) &&
            localIDs.contains(cloudGame.id) &&
            cloudGame.aiSummary != nil &&
            localGames.first(where: { $0.id == cloudGame.id })?.aiSummary == nil
        }
        print("[CloudKit] \(aiSummaryUpdates.count) games need AI summary sync")
        return (newGames, updatedGames, aiSummaryUpdates)
    }

    // MARK: - Helpers

    private func writeTempFile(_ data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(UUID().uuidString)
        try? data.write(to: url)
        return url
    }
}
