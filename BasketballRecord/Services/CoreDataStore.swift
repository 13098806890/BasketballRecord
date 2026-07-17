import CoreData
import UIKit

@MainActor
struct CoreDataStore {
    let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    var context: NSManagedObjectContext { stack.context }

    // MARK: - Player

    func fetchAllPlayers() -> [Player] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayer")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> Player? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String else { return nil }
            let groupIDsData = obj.value(forKey: "playerGroupIDsData") as? Data
            let playerGroupIDs = groupIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? []
            let nicknamesData = obj.value(forKey: "nicknamesData") as? Data
            let nicknames = nicknamesData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
            return Player(
                id: id,
                name: name,
                height: obj.value(forKey: "height") as? String ?? "",
                weight: obj.value(forKey: "weight") as? String ?? "",
                number: obj.value(forKey: "number") as? String ?? "",
                photoData: nil,
                playerGroupIDs: playerGroupIDs,
                nicknames: nicknames
            )
        }
    }

    func savePlayers(_ players: [Player]) {
        let existingIDs = Set((try? context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDPlayer")))?.compactMap { $0.value(forKey: "id") as? UUID } ?? [])
        let newIDs = Set(players.map(\.id))
        let toDelete = existingIDs.subtracting(newIDs)
        for player in players {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayer")
            request.predicate = NSPredicate(format: "id == %@", player.id as CVarArg)
            let obj = (try? context.fetch(request).first) ?? NSEntityDescription.insertNewObject(forEntityName: "CDPlayer", into: context)
            obj.setValue(player.id, forKey: "id")
            obj.setValue(player.name, forKey: "name")
            obj.setValue(player.height, forKey: "height")
            obj.setValue(player.weight, forKey: "weight")
            obj.setValue(player.number, forKey: "number")
            obj.setValue(try? JSONEncoder().encode(player.playerGroupIDs), forKey: "playerGroupIDsData")
            obj.setValue(try? JSONEncoder().encode(player.nicknames), forKey: "nicknamesData")
        }
        for id in toDelete {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayer")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let obj = try? context.fetch(request).first {
                context.delete(obj)
            }
        }
    }

    // MARK: - Team

    func fetchAllTeams() -> [Team] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDTeam")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> Team? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String else { return nil }
            let idsData = obj.value(forKey: "playerIDsData") as? Data
            let playerIDs = idsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? []
            return Team(id: id, name: name, playerIDs: playerIDs)
        }
    }

    func saveTeams(_ teams: [Team]) {
        let existingIDs = Set((try? context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTeam")))?.compactMap { $0.value(forKey: "id") as? UUID } ?? [])
        let newIDs = Set(teams.map(\.id))
        let toDelete = existingIDs.subtracting(newIDs)
        for team in teams {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDTeam")
            request.predicate = NSPredicate(format: "id == %@", team.id as CVarArg)
            let obj = (try? context.fetch(request).first) ?? NSEntityDescription.insertNewObject(forEntityName: "CDTeam", into: context)
            obj.setValue(team.id, forKey: "id")
            obj.setValue(team.name, forKey: "name")
            obj.setValue(try? JSONEncoder().encode(team.playerIDs), forKey: "playerIDsData")
        }
        for id in toDelete {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDTeam")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let obj = try? context.fetch(request).first {
                context.delete(obj)
            }
        }
    }

    // MARK: - GameGroup

    func fetchAllGameGroups() -> [GameGroup] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDGameGroup")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> GameGroup? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String,
                  let createdAt = obj.value(forKey: "createdAt") as? Date else { return nil }
            return GameGroup(
                id: id,
                name: name,
                description: obj.value(forKey: "desc") as? String,
                createdAt: createdAt,
                color: obj.value(forKey: "colorValue") as? String
            )
        }
    }

    func saveGameGroups(_ groups: [GameGroup]) {
        let existingIDs = Set((try? context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDGameGroup")))?.compactMap { $0.value(forKey: "id") as? UUID } ?? [])
        let newIDs = Set(groups.map(\.id))
        let toDelete = existingIDs.subtracting(newIDs)
        for group in groups {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDGameGroup")
            request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
            let obj = (try? context.fetch(request).first) ?? NSEntityDescription.insertNewObject(forEntityName: "CDGameGroup", into: context)
            obj.setValue(group.id, forKey: "id")
            obj.setValue(group.name, forKey: "name")
            obj.setValue(group.description, forKey: "desc")
            obj.setValue(group.color, forKey: "colorValue")
            obj.setValue(group.createdAt, forKey: "createdAt")
        }
        for id in toDelete {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDGameGroup")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let obj = try? context.fetch(request).first {
                context.delete(obj)
            }
        }
    }

    // MARK: - PlayerGroup

    func fetchAllPlayerGroups() -> [PlayerGroup] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayerGroup")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> PlayerGroup? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String else { return nil }
            let idsData = obj.value(forKey: "playerIDsData") as? Data
            let playerIDs = idsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? []
            return PlayerGroup(id: id, name: name, playerIDs: playerIDs)
        }
    }

    func savePlayerGroups(_ groups: [PlayerGroup]) {
        let existingIDs = Set((try? context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDPlayerGroup")))?.compactMap { $0.value(forKey: "id") as? UUID } ?? [])
        let newIDs = Set(groups.map(\.id))
        let toDelete = existingIDs.subtracting(newIDs)
        for group in groups {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayerGroup")
            request.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)
            let obj = (try? context.fetch(request).first) ?? NSEntityDescription.insertNewObject(forEntityName: "CDPlayerGroup", into: context)
            obj.setValue(group.id, forKey: "id")
            obj.setValue(group.name, forKey: "name")
            obj.setValue(try? JSONEncoder().encode(group.playerIDs), forKey: "playerIDsData")
        }
        for id in toDelete {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayerGroup")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let obj = try? context.fetch(request).first {
                context.delete(obj)
            }
        }
    }

    // MARK: - SavedGame

    func fetchAllSavedGames() -> [SavedGame] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]
        let results: [NSManagedObject]
        do {
            results = try context.fetch(request)
        } catch {
            print("[CoreData] Failed to fetch saved games: \(error)")
            return []
        }
        return results.compactMap { obj -> SavedGame? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let savedAt = obj.value(forKey: "savedAt") as? Date else {
                print("[CoreData] Skipping saved game with missing id or savedAt")
                return nil
            }
            let snapshotData = obj.value(forKey: "snapshotData") as? Data
            let snapshot: GameSnapshot
            if let data = snapshotData {
                do {
                    snapshot = try JSONDecoder().decode(GameSnapshot.self, from: data)
                } catch {
                    print("[CoreData] Failed to decode GameSnapshot for game \(id): \(error)")
                    snapshot = GameSnapshot()
                }
            } else {
                snapshot = GameSnapshot()
            }
            let homePlayerIDsData = obj.value(forKey: "homePlayerIDsData") as? Data
            let awayPlayerIDsData = obj.value(forKey: "awayPlayerIDsData") as? Data
            let playerNamesData = obj.value(forKey: "playerNamesData") as? Data
            let groupIDsData = obj.value(forKey: "groupIDsData") as? Data
            let undoData = obj.value(forKey: "undoSnapshotsData") as? Data
            return SavedGame(
                id: id,
                savedAt: savedAt,
                snapshot: snapshot,
                aiSummary: obj.value(forKey: "aiSummary") as? String,
                undoSnapshots: undoData.flatMap { try? JSONDecoder().decode([GameSnapshot].self, from: $0) } ?? [],
                homeTeamName: obj.value(forKey: "homeTeamName") as? String ?? "",
                awayTeamName: obj.value(forKey: "awayTeamName") as? String ?? "",
                homePlayerIDs: homePlayerIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                awayPlayerIDs: awayPlayerIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                playerNamesByID: playerNamesData.flatMap { try? JSONDecoder().decode([UUID: String].self, from: $0) } ?? [:],
                groupIDs: groupIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                displayName: obj.value(forKey: "displayName") as? String ?? ""
            )
        }
    }

    func upsertSavedGame(_ game: SavedGame) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.predicate = NSPredicate(format: "id == %@", game.id as CVarArg)
        request.fetchLimit = 1
        let existing = try? context.fetch(request).first
        let obj = existing ?? NSEntityDescription.insertNewObject(forEntityName: "CDSavedGame", into: context)
        obj.setValue(game.id, forKey: "id")
        obj.setValue(game.savedAt, forKey: "savedAt")
        let encodedSnap = try? JSONEncoder().encode(game.snapshot)
        obj.setValue(encodedSnap, forKey: "snapshotData")
        obj.setValue(game.homeTeamName, forKey: "homeTeamName")
        obj.setValue(game.awayTeamName, forKey: "awayTeamName")
        obj.setValue(try? JSONEncoder().encode(game.homePlayerIDs), forKey: "homePlayerIDsData")
        obj.setValue(try? JSONEncoder().encode(game.awayPlayerIDs), forKey: "awayPlayerIDsData")
        obj.setValue(try? JSONEncoder().encode(game.playerNamesByID), forKey: "playerNamesData")
        obj.setValue(try? JSONEncoder().encode(game.groupIDs), forKey: "groupIDsData")
        obj.setValue(game.isLocked, forKey: "isLocked")
        obj.setValue(game.displayName.isEmpty ? nil : game.displayName, forKey: "displayName")
        obj.setValue(game.aiSummary, forKey: "aiSummary")
        obj.setValue(try? JSONEncoder().encode(game.undoSnapshots), forKey: "undoSnapshotsData")
    }

    func deleteSavedGame(id: UUID) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let obj = try? context.fetch(request).first {
            context.delete(obj)
            stack.save()
        }
    }

    // MARK: - Query

    func savedGames(containingPlayer playerID: UUID) -> [SavedGame] {
        let all = fetchAllSavedGames()
        return all.filter { game in
            game.homePlayerIDs.contains(playerID) || game.awayPlayerIDs.contains(playerID)
        }
    }

    // MARK: - Migration

    func hasData() -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        return (try? context.count(for: request)) ?? 0 > 0
    }

    func fetchAllSavedGameIDs() -> Set<UUID> {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.propertiesToFetch = ["id"]
        guard let results = try? context.fetch(request) else { return [] }
        return Set(results.compactMap { $0.value(forKey: "id") as? UUID })
    }

    func deleteAllSavedGames() {
        deleteAll("CDSavedGame")
    }

    func clearAll() {
        deleteAll("CDPlayer")
        deleteAll("CDTeam")
        deleteAll("CDGameGroup")
        deleteAll("CDPlayerGroup")
        deleteAll("CDSavedGame")
    }

    func flush() {
        stack.save()
    }

    // MARK: - Private

    private func deleteAll(_ entity: String) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        let batch = NSBatchDeleteRequest(fetchRequest: request)
        batch.resultType = .resultTypeObjectIDs
        guard let result = try? context.execute(batch) as? NSBatchDeleteResult,
              let ids = result.result as? [NSManagedObjectID] else { return }
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [context])
        context.refreshAllObjects()
    }
}
