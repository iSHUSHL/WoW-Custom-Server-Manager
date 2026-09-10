import Foundation

enum BuiltInCatalog {
    static func entries(for expansion: ExpansionID) -> [CatalogEntry] {
        switch expansion {
        case .vanilla: return [item(19019, "Thunderfury, Blessed Blade of the Windseeker", .legendary, "One-Hand Sword", "inv_sword_39"), item(17182, "Sulfuras, Hand of Ragnaros", .legendary, "Two-Hand Mace", "inv_hammer_unique_sulfuras")]
        case .tbc: return [item(32837, "Warglaive of Azzinoth", .legendary, "Main Hand Sword", "inv_weapon_glave_01"), item(32838, "Warglaive of Azzinoth", .legendary, "Off Hand Sword", "inv_weapon_glave_01"), item(34334, "Thori'dal, the Stars' Fury", .legendary, "Bow", "inv_weapon_bow_39")]
        case .wotlk: return [item(49623, "Shadowmourne", .legendary, "Two-Hand Axe", "inv_axe_113"), item(46017, "Val'anyr, Hammer of Ancient Kings", .legendary, "One-Hand Mace", "inv_mace_99")]
        case .cataclysm: return [item(71086, "Dragonwrath, Tarecgosa's Rest", .legendary, "Staff", "inv_staff_39"), item(77949, "Golad, Twilight of Aspects", .legendary, "Dagger", "inv_knife_1h_deathwingraid_d_01")]
        case .mop: return [item(102245, "Qian-Le, Courage of Niuzao", .legendary, "Legendary Cloak", "inv_cape_pandaria_d_03")]
        default: return []
        }
    }

    static func iconForKnownItem(_ id: Int) -> URL? {
        [ExpansionID.vanilla,.tbc,.wotlk,.cataclysm,.mop].flatMap { entries(for: $0) }.first(where: { $0.id == id })?.iconURL
    }

    private static func item(_ id: Int, _ name: String, _ kind: CatalogKind, _ subtitle: String, _ icon: String, quality: String = "Legendary") -> CatalogEntry {
        CatalogEntry(id: id, name: name, kind: kind, quality: quality, subtitle: subtitle, iconURL: iconURL(icon), spellID: nil, itemLevel: nil, itemSetID: nil)
    }
    private static func mount(_ name: String, _ spell: Int, _ icon: String) -> CatalogEntry {
        CatalogEntry(id: -spell, name: name, kind: .mount, quality: "Epic", subtitle: "Mount Spell", iconURL: iconURL(icon), spellID: spell, itemLevel: nil, itemSetID: nil)
    }
    private static func iconURL(_ name: String) -> URL? { URL(string: "https://wow.zamimg.com/images/wow/icons/large/\(name).jpg") }
}

enum CatalogFormatting {
    static func qualityName(_ q: Int) -> String {
        switch q { case 0: "Poor"; case 1: "Common"; case 2: "Uncommon"; case 3: "Rare"; case 4: "Epic"; case 5: "Legendary"; case 6: "Artifact"; case 7: "Heirloom"; default: "Quality \(q)" }
    }
    static func kind(itemClass: Int, inventoryType: Int, quality: Int) -> CatalogKind {
        if itemClass == 1 { return .bag }
        if quality == 5 { return .legendary }
        if itemClass == 2 { return .weapon }
        return .armor
    }
    static func subtitle(itemClass: Int, subclass: Int, inventoryType: Int) -> String {
        let slots: [Int:String] = [1:"Head",2:"Neck",3:"Shoulders",4:"Shirt",5:"Chest",6:"Waist",7:"Legs",8:"Feet",9:"Wrists",10:"Hands",11:"Finger",12:"Trinket",13:"One-Hand",14:"Shield",15:"Ranged",16:"Back",17:"Two-Hand",18:"Bag",19:"Tabard",20:"Robe",21:"Main Hand",22:"Off Hand",23:"Held In Off-hand",26:"Ranged"]
        return slots[inventoryType] ?? "Class \(itemClass) / Subclass \(subclass)"
    }
}
