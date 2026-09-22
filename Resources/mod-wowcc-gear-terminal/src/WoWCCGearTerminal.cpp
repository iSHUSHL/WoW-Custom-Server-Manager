#include "ScriptMgr.h"
#include "ScriptedGossip.h"
#include "Player.h"
#include "Creature.h"
#include "ItemTemplate.h"
#include "ObjectMgr.h"
#include "Chat.h"

namespace WoWCC
{
    enum Actions : uint32
    {
        MAIN_PVE = 100,
        MAIN_PVP = 101,
        MAIN_WEAPONS = 102,
        MAIN_UPGRADES = 103,
        MAIN_MOUNTS = 104,
        MAIN_UTILITY = 105,
        BACK_MAIN = 199,

        CLASS_BASE = 1000,
        SPEC_BASE = 2000,
        CAT_BASE = 3000
    };

    struct ClassDef { uint8 id; char const* name; };
    static ClassDef const Classes[] = {
        { CLASS_WARRIOR, "Warrior" }, { CLASS_PALADIN, "Paladin" },
        { CLASS_HUNTER, "Hunter" }, { CLASS_ROGUE, "Rogue" },
        { CLASS_PRIEST, "Priest" }, { CLASS_DEATH_KNIGHT, "Death Knight" },
        { CLASS_SHAMAN, "Shaman" }, { CLASS_MAGE, "Mage" },
        { CLASS_WARLOCK, "Warlock" }, { CLASS_DRUID, "Druid" }
    };

    static std::vector<std::string> Specs(uint8 cls)
    {
        switch (cls)
        {
            case CLASS_WARRIOR: return {"Arms","Fury","Protection"};
            case CLASS_PALADIN: return {"Holy","Protection","Retribution"};
            case CLASS_HUNTER: return {"Beast Mastery","Marksmanship","Survival"};
            case CLASS_ROGUE: return {"Assassination","Combat","Subtlety"};
            case CLASS_PRIEST: return {"Discipline","Holy","Shadow"};
            case CLASS_DEATH_KNIGHT: return {"Blood","Frost","Unholy"};
            case CLASS_SHAMAN: return {"Elemental","Enhancement","Restoration"};
            case CLASS_MAGE: return {"Arcane","Fire","Frost"};
            case CLASS_WARLOCK: return {"Affliction","Demonology","Destruction"};
            case CLASS_DRUID: return {"Balance","Feral","Restoration"};
            default: return {"General"};
        }
    }

    static void MainMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "WoWCC Gear Menu — choose a catalog:", GOSSIP_SENDER_MAIN, 0);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "PvE Endgame", GOSSIP_SENDER_MAIN, MAIN_PVE);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "PvP Endgame", GOSSIP_SENDER_MAIN, MAIN_PVP);
        AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Weapons & Accessories", GOSSIP_SENDER_MAIN, MAIN_WEAPONS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Gems / Enchants / Glyphs", GOSSIP_SENDER_MAIN, MAIN_UPGRADES);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Mount Collection", GOSSIP_SENDER_MAIN, MAIN_MOUNTS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Utility / Bags / Consumables", GOSSIP_SENDER_MAIN, MAIN_UTILITY);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    static void ClassMenu(Player* player, Creature* creature, uint32 branch)
    {
        ClearGossipMenuFor(player);
        for (auto const& c : Classes)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, c.name, branch, CLASS_BASE + c.id);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "< Back", GOSSIP_SENDER_MAIN, BACK_MAIN);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    static void SpecMenu(Player* player, Creature* creature, uint32 branch, uint8 cls)
    {
        ClearGossipMenuFor(player);
        auto specs=Specs(cls);
        for (uint32 i=0;i<specs.size();++i)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, specs[i], branch, SPEC_BASE + cls*10 + i);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "< Classes", branch, branch);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    static void CategoryMenu(Player* player, Creature* creature, uint32 branch, uint8 cls, uint8 spec)
    {
        ClearGossipMenuFor(player);
        auto specs=Specs(cls);
        std::string title = std::string("Selected: ") + (spec < specs.size() ? specs[spec] : "General");
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, title, GOSSIP_SENDER_MAIN, 0);
        if (branch == MAIN_PVE || branch == MAIN_PVP)
        {
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Complete Set / Armor", branch, CAT_BASE + cls*100 + spec*10 + 1);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Weapons", branch, CAT_BASE + cls*100 + spec*10 + 2);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Trinkets / Rings / Neck / Cloak", branch, CAT_BASE + cls*100 + spec*10 + 3);
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, "Alternatives", branch, CAT_BASE + cls*100 + spec*10 + 4);
        }
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "< Specs", branch, CLASS_BASE + cls);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    class GearTerminal : public CreatureScript
    {
    public:
        GearTerminal() : CreatureScript("wowcc_gear_terminal") {}

        bool OnGossipHello(Player* player, Creature* creature) override
        {
            MainMenu(player, creature);
            return true;
        }

        bool OnGossipSelect(Player* player, Creature* creature, uint32 sender, uint32 action) override
        {
            if (action == BACK_MAIN) { MainMenu(player, creature); return true; }

            if (action >= MAIN_PVE && action <= MAIN_PVP)
            {
                ClassMenu(player, creature, action);
                return true;
            }

            if (action >= CLASS_BASE && action < SPEC_BASE)
            {
                uint8 cls = uint8(action - CLASS_BASE);
                SpecMenu(player, creature, sender, cls);
                return true;
            }

            if (action >= SPEC_BASE && action < CAT_BASE)
            {
                uint32 v=action-SPEC_BASE;
                uint8 cls=uint8(v/10), spec=uint8(v%10);
                CategoryMenu(player, creature, sender, cls, spec);
                return true;
            }

            // Shared branches open the corresponding specialist vendor directly.
            uint32 vendorEntry=0;
            if (action==MAIN_WEAPONS) vendorEntry=990102;
            else if (action==MAIN_UPGRADES) vendorEntry=990104;
            else if (action==MAIN_MOUNTS) vendorEntry=990105;
            else if (action==MAIN_UTILITY) vendorEntry=990106;
            if (vendorEntry)
            {
                CloseGossipMenuFor(player);
                ChatHandler(player->GetSession()).PSendSysMessage(
                    "WoWCC: this menu selects the catalog. Use the nearby specialist NPC (entry %u) to browse/buy the actual items.", vendorEntry);
                return true;
            }

            // Category selection is intentionally deterministic: the menu has
            // resolved class/spec/category. WoWCC reports that selection and the
            // nearby specialist holds the underlying item catalog. This avoids
            // pretending the stock client can dynamically replace vendor lists.
            if (action >= CAT_BASE)
            {
                CloseGossipMenuFor(player);
                ChatHandler(player->GetSession()).SendSysMessage(
                    "WoWCC selection locked. Browse the matching PvE/PvP specialist; only class-usable items should be chosen.");
                return true;
            }

            MainMenu(player, creature);
            return true;
        }
    };
}

void AddWoWCCGearTerminalScripts()
{
    new WoWCC::GearTerminal();
}
