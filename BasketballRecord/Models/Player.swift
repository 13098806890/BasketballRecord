import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var height: String = ""
    var weight: String = ""
    var number: String = ""
    var position: String = ""
    var photoData: Data?
    var playerGroupIDs: [UUID] = []
    var badges: [PlayerBadge] = []
    var nicknames: [String] = []

    init(
        id: UUID = UUID(),
        name: String,
        height: String = "",
        weight: String = "",
        number: String = "",
        position: String = "",
        photoData: Data? = nil,
        playerGroupIDs: [UUID] = [],
        badges: [PlayerBadge] = [],
        nicknames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.number = number
        self.position = position
        self.photoData = photoData
        self.playerGroupIDs = playerGroupIDs
        self.badges = badges
        self.nicknames = nicknames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        height = try container.decodeIfPresent(String.self, forKey: .height) ?? ""
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        position = try container.decodeIfPresent(String.self, forKey: .position) ?? ""
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        playerGroupIDs = try container.decodeIfPresent([UUID].self, forKey: .playerGroupIDs) ?? []
        badges = try container.decodeIfPresent([PlayerBadge].self, forKey: .badges) ?? []
        nicknames = try container.decodeIfPresent([String].self, forKey: .nicknames) ?? []
    }
}

enum PlayerPosition: String, CaseIterable, Identifiable {
    case pointGuard = "PG"
    case shootingGuard = "SG"
    case smallForward = "SF"
    case powerForward = "PF"
    case center = "C"

    var id: String { rawValue }
}

struct PlayerGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var playerIDs: [UUID] = []

    init(id: UUID = UUID(), name: String, playerIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        playerIDs = try container.decodeIfPresent([UUID].self, forKey: .playerIDs) ?? []
    }
}

struct Team: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var playerIDs: [UUID] = []

    init(id: UUID = UUID(), name: String, playerIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        playerIDs = try container.decodeIfPresent([UUID].self, forKey: .playerIDs) ?? []
    }
}

struct ExportPlayer: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var height: String
    var weight: String
    var number: String
    var position: String
    var photoData: Data?
    var nicknames: [String]

    init(player: Player) {
        id = player.id
        name = player.name
        height = player.height
        weight = player.weight
        number = player.number
        position = player.position
        photoData = player.photoData
        nicknames = player.nicknames
    }

    init(id: UUID, name: String, height: String = "", weight: String = "", number: String = "", position: String = "", photoData: Data? = nil, nicknames: [String] = []) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.number = number
        self.position = position
        self.photoData = photoData
        self.nicknames = nicknames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        height = try container.decode(String.self, forKey: .height)
        weight = try container.decode(String.self, forKey: .weight)
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        position = try container.decodeIfPresent(String.self, forKey: .position) ?? ""
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        nicknames = try container.decodeIfPresent([String].self, forKey: .nicknames) ?? []
    }

    var playerWithoutPhoto: Player {
        Player(id: id, name: name, height: height, weight: weight, number: number, position: position, nicknames: nicknames)
    }
}

struct ExportTeam: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var playerIDs: [UUID]

    init(team: Team) {
        id = team.id
        name = team.name
        playerIDs = team.playerIDs
    }

    init(id: UUID, name: String, playerIDs: [UUID]) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
    }

    var team: Team {
        Team(id: id, name: name, playerIDs: playerIDs)
    }
}

extension Player {
    var playerExportOptions: Player? {
        guard photoData != nil else { return nil }
        return self
    }

    var photoBase64: String {
        photoData!.base64EncodedString()
   }
}
