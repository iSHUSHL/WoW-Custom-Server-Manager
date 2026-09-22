import Foundation

enum ExpansionID: String, CaseIterable, Codable, Identifiable {
    // Legacy values remain decodable for older preferences/profile data.\n    // Only the five supported expansions are exposed in the UI.\n    case vanilla, tbc, wotlk, cataclysm, mop\n    case wod, legion, bfa, shadowlands, dragonflight, warWithin\n\n    static let allCases: [ExpansionID] = [.vanilla, .tbc, .wotlk, .cataclysm, .mop]\n    var id: String { rawValue }

    var title: String {
        switch self {
        case .vanilla: return "Vanilla / Classic 1.12.x"
        case .tbc: return "The Burning Crusade 2.4.3"
        case .wotlk: return "Wrath of the Lich King 3.3.5a"
        case .cataclysm: return "Cataclysm 4.3.4 (15595)"
        case .mop: return "Mists of Pandaria 5.4.8 (18414)"\n        case .wod: return "Warlords of Draenor"\n        case .legion: return "Legion"\n        case .bfa: return "Battle for Azeroth"\n        case .shadowlands: return "Shadowlands"\n        case .dragonflight: return "Dragonflight"\n        case .warWithin: return "The War Within"\n        }
    }

    var shortTitle: String {
        switch self {
        case .vanilla: return "Vanilla"
        case .tbc: return "TBC"
        case .wotlk: return "WotLK"
        case .cataclysm: return "Cata"
        case .mop: return "MoP"\n        case .wod: return "WoD"\n        case .legion: return "Legion"\n        case .bfa: return "BfA"\n        case .shadowlands: return "SL"\n        case .dragonflight: return "DF"\n        case .warWithin: return "TWW"\n        }
    }

    var maturity: ProfileMaturity {
        switch self {
        case .vanilla, .tbc, .wotlk: return .supported
        case .cataclysm, .mop: return .community\n        default: return .experimental\n        }
    }

    var recommendedCore: String {
        switch self {
        case .vanilla: return "CMaNGOS Classic"
        case .tbc: return "CMaNGOS TBC"
        case .wotlk: return "AzerothCore Playerbot fork + mod-playerbots"
        case .cataclysm: return "Cataclysm Preservation TrinityCore 4.3.4"
        case .mop: return "Project SkyFire 5.4.8"\n        default: return "Imported compatible core"\n        }
    }

    var clientHint: String {
        switch self {
        case .vanilla: return "1.12.1 build 5875 client"
        case .tbc: return "2.4.3 build 8606 client"
        case .wotlk: return "3.3.5a build 12340 client"
        case .cataclysm: return "4.3.4 build 15595 client"
        case .mop: return "5.4.8 build 18414 client"\n        default: return "Client build matching the imported core"\n        }
    }

    var clientSearchQuery: String {
        switch self {
        case .vanilla: return "World of Warcraft 1.12.1 build 5875 client download"
        case .tbc: return "World of Warcraft 2.4.3 build 8606 client download"
        case .wotlk: return "World of Warcraft 3.3.5a build 12340 client download"
        case .cataclysm: return "World of Warcraft Cataclysm 4.3.4 build 15595 client download"
        case .mop: return "World of Warcraft Mists of Pandaria 5.4.8 build 18414 client download"\n        case .wod: return "World of Warcraft Warlords of Draenor compatible client download"\n        case .legion: return "World of Warcraft Legion compatible client download"\n        case .bfa: return "World of Warcraft Battle for Azeroth compatible client download"\n        case .shadowlands: return "World of Warcraft Shadowlands compatible client download"\n        case .dragonflight: return "World of Warcraft Dragonflight compatible client download"\n        case .warWithin: return "World of Warcraft The War Within compatible client download"\n        }
    }

    var serverFamily: ServerFamily {
        switch self {
        case .wotlk: return .azerothCore
        case .vanilla, .tbc: return .cmangos
        default: return .custom\n        }
    }
}

enum ServerFamily: String, Codable { case azerothCore, cmangos, custom }
enum ProfileMaturity: String, Codable { case supported = "SUPPORTED", community = "COMMUNITY CORE", experimental = "EXPERIMENTAL" }

struct CharacterSummary: Identifiable, Hashable {
    let id: Int
    let name: String
    let level: Int
    let race: String
    let playerClass: String
    let online: Bool
}

struct AccountSummary: Identifiable, Hashable {
    let id: Int
    let username: String
    let gmLevel: Int
}

enum CatalogKind: String, CaseIterable, Identifiable {
    case raidSet = "Raid Sets"
    case weapon = "Weapons"
    case armor = "Armor"
    case legendary = "Legendaries"
    case bis = "BiS / Endgame"
    case bag = "Bags"
    case mount = "Mounts"
    case all = "All Items"
    var id: String { rawValue }
}

enum ItemQualityFilter: String, CaseIterable, Identifiable {
    case all = "All Qualities"
    case uncommon = "Uncommon+"
    case rare = "Rare+"
    case epic = "Epic+"
    case legendary = "Legendary"
    var id: String { rawValue }
    var minimum: Int {
        switch self {
        case .all: return 0
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 4
        case .legendary: return 5
        }
    }
}

enum EquipSlotFilter: String, CaseIterable, Identifiable {
    case all = "All Slots"
    case head = "Head"
    case neck = "Neck"
    case shoulder = "Shoulder"
    case chest = "Chest"
    case waist = "Waist"
    case legs = "Legs"
    case feet = "Feet"
    case wrist = "Wrist"
    case hands = "Hands"
    case finger = "Ring"
    case trinket = "Trinket"
    case back = "Back"
    case mainHand = "Main Hand"
    case offHand = "Off Hand"
    case ranged = "Ranged"
    var id: String { rawValue }

    var inventoryTypes: [Int] {
        switch self {
        case .all: return []
        case .head: return [1]
        case .neck: return [2]
        case .shoulder: return [3]
        case .chest: return [5,20]
        case .waist: return [6]
        case .legs: return [7]
        case .feet: return [8]
        case .wrist: return [9]
        case .hands: return [10]
        case .finger: return [11]
        case .trinket: return [12]
        case .back: return [16]
        case .mainHand: return [13,17,21]
        case .offHand: return [14,22,23]
        case .ranged: return [15,25,26,28]
        }
    }
}

struct CatalogEntry: Identifiable, Hashable {
    let id: Int
    let name: String
    let kind: CatalogKind
    let quality: String
    let subtitle: String
    let iconURL: URL?
    let spellID: Int?
    let itemLevel: Int?
    let itemSetID: Int?
    let displayID: Int?
    let allowableClass: Int

    init(id: Int, name: String, kind: CatalogKind, quality: String, subtitle: String,
         iconURL: URL?, spellID: Int?, itemLevel: Int?, itemSetID: Int?, displayID: Int? = nil,
         allowableClass: Int = -1) {
        self.id = id
        self.name = name
        self.kind = kind
        self.quality = quality
        self.subtitle = subtitle
        self.iconURL = iconURL
        self.spellID = spellID
        self.itemLevel = itemLevel
        self.itemSetID = itemSetID
        self.displayID = displayID
        self.allowableClass = allowableClass
    }
}

enum GearSetCategory: String, CaseIterable, Identifiable {
    case all = "All Sets"
    case raid = "Raid / PvE Sets"
    case pvp = "PvP Sets"
    var id: String { rawValue }
}

enum PlayerClassFilter: String, CaseIterable, Identifiable {
    case all = "All Classes"
    case warrior = "Warrior"
    case paladin = "Paladin"
    case hunter = "Hunter"
    case rogue = "Rogue"
    case priest = "Priest"
    case deathKnight = "Death Knight"
    case shaman = "Shaman"
    case mage = "Mage"
    case warlock = "Warlock"
    case druid = "Druid"

    var id: String { rawValue }

    var classID: Int? {
        switch self {
        case .all: return nil
        case .warrior: return 1
        case .paladin: return 2
        case .hunter: return 3
        case .rogue: return 4
        case .priest: return 5
        case .deathKnight: return 6
        case .shaman: return 7
        case .mage: return 8
        case .warlock: return 9
        case .druid: return 11
        }
    }

    var mask: Int? {
        guard let classID else { return nil }
        return 1 << (classID - 1)
    }
}

struct GearSetSummary: Identifiable, Hashable {
    let id: Int
    let name: String
    let category: GearSetCategory
    let itemLevel: Int
    let items: [CatalogEntry]
}

struct InventoryEntry: Identifiable, Hashable {
    let id: Int
    let itemEntry: Int
    let name: String
    let bag: Int
    let slot: Int
}

enum HealthCheckState: String, Codable, Hashable {
    case pass, warning, fail
}

enum HealthFixAction: String, Codable, Hashable {
    case none, installDependencies, installCore, selectClient, prepareClient, setupRealm, startDatabase, startRealm, createBackupFolder
}

struct HealthCheckResult: Identifiable, Hashable {
    let id: String
    let category: String
    let title: String
    let detail: String
    let state: HealthCheckState
    let fix: HealthFixAction
}
