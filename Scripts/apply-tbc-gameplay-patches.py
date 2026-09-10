#!/usr/bin/env python3
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
player = root / "src/game/Entities/Player.cpp"
spell = root / "src/game/Spells/Spell.cpp"
spellmgr = root / "src/game/Spells/SpellMgr.cpp"
auras = root / "src/game/Spells/SpellAuras.cpp"
for path in (player, spell, spellmgr, auras):
    if not path.exists():
        raise SystemExit(f"ERROR: TBC gameplay patch target missing: {path}")

p = player.read_text(errors="strict")
s = spell.read_text(errors="strict")
sm = spellmgr.read_text(errors="strict")
a = auras.read_text(errors="strict")

def sub_once(text, pattern, repl, label, flags=re.S):
    if repl.strip() in text:
        return text
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f"ERROR: {label}: compatible CMaNGOS code block not found. Refusing unsafe patch.")
    return out

# Match semantics, not exact indentation/comments. CMaNGOS frequently changes whitespace.
# Fix the earlier ViableEquipSlots free-slot gate too. Stock TBC rejects a 2H
# offhand here before the later CanEquipItem patches can help.
p = sub_once(p,
    r"if\s*\(\s*currentSlot\s*==\s*EQUIPMENT_SLOT_OFFHAND\s*&&\s*\(IsTwoHandUsed\(\)\s*\|\|\s*proto->InventoryType\s*==\s*INVTYPE_2HWEAPON\)\s*\)\s*continue\s*;",
    """if (currentSlot == EQUIPMENT_SLOT_OFFHAND &&
                        (IsTwoHandUsed() || proto->InventoryType == INVTYPE_2HWEAPON) &&
                        !(getClass() == CLASS_WARRIOR && CanDualWield()))
                    continue;""",
    "dual-2H viable offhand slot guard")

p = sub_once(p,
    r'''else\s+if\s*\(\s*type\s*==\s*INVTYPE_2HWEAPON\s*\)\s*\{\s*return\s+EQUIP_ERR_CANT_DUAL_WIELD\s*;\s*\}\s*if\s*\(\s*IsTwoHandUsed\(\)\s*\)\s*return\s+EQUIP_ERR_CANT_EQUIP_WITH_TWOHANDED\s*;''',
    '''else if (type == INVTYPE_2HWEAPON)\n                {\n                    // WoWCC TBC extension: Titan's Grip-style equipment for Warriors with Dual Wield.\n                    if (getClass() != CLASS_WARRIOR || !CanDualWield())\n                        return EQUIP_ERR_CANT_DUAL_WIELD;\n                }\n                if (IsTwoHandUsed() && !(getClass() == CLASS_WARRIOR && CanDualWield()))\n                    return EQUIP_ERR_CANT_EQUIP_WITH_TWOHANDED;''',
    "dual-2H offhand validation")

p = sub_once(p,
    r'''if\s*\(\s*type\s*==\s*INVTYPE_2HWEAPON\s*\)\s*\{\s*if\s*\(\s*eslot\s*!=\s*EQUIPMENT_SLOT_MAINHAND\s*\)\s*return\s+EQUIP_ERR_ITEM_CANT_BE_EQUIPPED\s*;\s*(?://[^\n]*\n\s*)?Item\*\s+offItem\s*=\s*GetItemByPos\(INVENTORY_SLOT_BAG_0,\s*EQUIPMENT_SLOT_OFFHAND\)\s*;\s*ItemPosCountVec\s+off_dest\s*;\s*uint8\s+bagSlot\s*=\s*0\s*;\s*if\s*\(\s*offItem\s*&&\s*\(\s*!direct_action\s*\|\|\s*CanUnequipItem\(uint16\(INVENTORY_SLOT_BAG_0\)\s*<<\s*8\s*\|\s*EQUIPMENT_SLOT_OFFHAND,\s*false\)\s*!=\s*EQUIP_ERR_OK\s*\|\|\s*CanStoreItem\(NULL_BAG,\s*NULL_SLOT,\s*off_dest,\s*offItem,\s*bagSlot,\s*false\)\s*!=\s*EQUIP_ERR_OK\s*\)\s*\)\s*return\s+swap\s*\?\s*EQUIP_ERR_ITEMS_CANT_BE_SWAPPED\s*:\s*EQUIP_ERR_INVENTORY_FULL\s*;\s*\}''',
    '''if (type == INVTYPE_2HWEAPON)\n            {\n                const bool wowccTitanGrip = getClass() == CLASS_WARRIOR && CanDualWield();\n                if (eslot != EQUIPMENT_SLOT_MAINHAND && !(wowccTitanGrip && eslot == EQUIPMENT_SLOT_OFFHAND))\n                    return EQUIP_ERR_ITEM_CANT_BE_EQUIPPED;\n\n                if (!wowccTitanGrip)\n                {\n                    Item* offItem = GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);\n                    ItemPosCountVec off_dest;\n                    uint8 bagSlot = 0;\n                    if (offItem && (!direct_action ||\n                                    CanUnequipItem(uint16(INVENTORY_SLOT_BAG_0) << 8 | EQUIPMENT_SLOT_OFFHAND, false) != EQUIP_ERR_OK ||\n                                    CanStoreItem(NULL_BAG, NULL_SLOT, off_dest, offItem, bagSlot, false) != EQUIP_ERR_OK))\n                        return swap ? EQUIP_ERR_ITEMS_CANT_BE_SWAPPED : EQUIP_ERR_INVENTORY_FULL;\n                }\n            }''',
    "dual-2H equipment slot validation")

p = sub_once(p,
    r'''(?://\s*need unequip offhand for 2h-weapon\s*)?if\s*\(\s*\(CanDualWield\(\)\s*\|\|\s*itemProto->InventoryType\s*==\s*INVTYPE_SHIELD\s*\|\|\s*itemProto->InventoryType\s*==\s*INVTYPE_HOLDABLE\)\s*&&\s*!IsTwoHandUsed\(\)\s*\)\s*return\s*;''',
    '''// WoWCC TBC extension: keep a Warrior's second 2H weapon equipped.\n    if (getClass() == CLASS_WARRIOR && CanDualWield() && itemProto->InventoryType == INVTYPE_2HWEAPON)\n        return;\n\n    // need unequip offhand for 2h-weapon\n    if ((CanDualWield() || itemProto->InventoryType == INVTYPE_SHIELD || itemProto->InventoryType == INVTYPE_HOLDABLE) &&\n            !IsTwoHandUsed())\n        return;''',
    "dual-2H auto-unequip guard")

s = sub_once(s,
    r'''SpellCastResult\s+locRes\s*=\s*sSpellMgr\.GetSpellAllowedInLocationError\(m_spellInfo,\s*m_trueCaster->GetMapId\(\),\s*zone,\s*area,\s*m_caster\s*\?\s*m_caster->GetBeneficiaryPlayer\(\)\s*:\s*nullptr\)\s*;''',
    '''// WoWCC: actual mount auras ignore spell-specific zone/area restrictions.\n    const bool wowccUnrestrictedMount =
        IsSpellHaveAura(m_spellInfo, SPELL_AURA_MOUNTED) ||
        IsSpellHaveAura(m_spellInfo, SPELL_AURA_FLY) ||
        IsSpellHaveAura(m_spellInfo, SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED) ||
        IsSpellHaveAura(m_spellInfo, SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED_STACKING) ||
        IsSpellHaveAura(m_spellInfo, SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED_NOT_STACKING);\n    SpellCastResult locRes = wowccUnrestrictedMount\n        ? SPELL_CAST_OK\n        : sSpellMgr.GetSpellAllowedInLocationError(m_spellInfo, m_trueCaster->GetMapId(), zone, area,\n              m_caster ? m_caster->GetBeneficiaryPlayer() : nullptr);''',
    "mount spell location bypass")

s = sub_once(s,
    r'''(?://\s*Ignore map check[^\n]*\n\s*)?if\s*\(m_caster->GetTypeId\(\)\s*==\s*TYPEID_PLAYER\s*&&\s*!m_IsTriggeredSpell\s*&&\s*!m_spellInfo->AreaId\s*&&\s*\(m_caster->GetMap\(\)\s*&&\s*!m_caster->GetMap\(\)->IsMountAllowed\(\)\)\s*\)\s*\{\s*return\s+SPELL_FAILED_NO_MOUNTS_ALLOWED\s*;\s*\}\s*if\s*\(m_caster->GetAreaId\(\)\s*==\s*35\s*\)\s*return\s+SPELL_FAILED_NO_MOUNTS_ALLOWED\s*;''',
    '''// WoWCC: mount spells may be used outside their original zone/map.\n                // Water, transport and shapeshift safety checks remain stock.\n                const bool wowccMountAnywhere = IsSpellHaveAura(m_spellInfo, SPELL_AURA_MOUNTED);\n                if (!wowccMountAnywhere &&\n                        m_caster->GetTypeId() == TYPEID_PLAYER &&\n                        !m_IsTriggeredSpell &&\n                        !m_spellInfo->AreaId &&\n                        (m_caster->GetMap() && !m_caster->GetMap()->IsMountAllowed()))\n                {\n                    return SPELL_FAILED_NO_MOUNTS_ALLOWED;\n                }\n                if (!wowccMountAnywhere && m_caster->GetAreaId() == 35)\n                    return SPELL_FAILED_NO_MOUNTS_ALLOWED;''',
    "mount map/area bypass")


# CMaNGOS also applies mount/flying-area restrictions inside SpellMgr. Flying
# mounts can be composed of a mount aura plus triggered flight/fly components,
# so bypassing only the top-level mount spell is insufficient.
sm = sub_once(sm,
    r"SpellCastResult\s+SpellMgr::GetSpellAllowedInLocationError\(SpellEntry const\*\s*spellInfo,\s*uint32\s+map_id,\s*uint32\s+zone_id,\s*uint32\s+area_id,\s*Player const\*\s*player\)\s+const\s*\{",
    """SpellCastResult SpellMgr::GetSpellAllowedInLocationError(SpellEntry const* spellInfo, uint32 map_id, uint32 zone_id, uint32 area_id, Player const* player) const
{
    // WoWCC TBC Mount Anywhere: treat mounted/flying mount components as one family.
    const bool wowccMountRelated =
        IsSpellHaveAura(spellInfo, SPELL_AURA_MOUNTED) ||
        IsSpellHaveAura(spellInfo, SPELL_AURA_FLY) ||
        IsSpellHaveAura(spellInfo, SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED) ||
        IsSpellHaveAura(spellInfo, SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED_STACKING) ||
        IsSpellHaveAura(spellInfo, SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED_NOT_STACKING);""",
    "SpellMgr mount-family location hook", flags=re.S)

sm = sub_once(sm,
    r"if\s*\(\s*spellInfo->AreaId\s*>\s*0\s*&&\s*spellInfo->AreaId\s*!=\s*zone_id\s*&&\s*spellInfo->AreaId\s*!=\s*area_id\s*\)\s*return\s+SPELL_FAILED_REQUIRES_AREA\s*;",
    """if (!wowccMountRelated && spellInfo->AreaId > 0 && spellInfo->AreaId != zone_id && spellInfo->AreaId != area_id)
        return SPELL_FAILED_REQUIRES_AREA;""",
    "SpellMgr explicit AreaId bypass")

sm = sub_once(sm,
    r"if\s*\(\s*spellInfo->HasAttribute\(SPELL_ATTR_EX4_ONLY_FLYING_AREAS\)\s*&&\s*!\(player\s*&&\s*player->IsGameMaster\(\)\)\s*\)",
    "if (!wowccMountRelated && spellInfo->HasAttribute(SPELL_ATTR_EX4_ONLY_FLYING_AREAS) && !(player && player->IsGameMaster()))",
    "SpellMgr flying-continent bypass", flags=0)

sm = sub_once(sm,
    r"if\s*\(\s*saBounds\.first\s*!=\s*saBounds\.second\s*\)",
    "if (!wowccMountRelated && saBounds.first != saBounds.second)",
    "SpellMgr spell_area bypass", flags=0)

# Fly Anywhere: mounted flight-speed auras should enable actual flight mode on
# Azeroth as well as Outland. This is separate from mount cast-location checks.
a = sub_once(a,
    r"void\s+Aura::HandleAuraModIncreaseFlightSpeed\(bool\s+apply,\s*bool\s+Real\)\s*\{",
    """void Aura::HandleAuraModIncreaseFlightSpeed(bool apply, bool Real)
{
    // WoWCC TBC Fly Anywhere: mounted flying mounts enable real flight on every world map.
    if (Real && GetTarget()->GetTypeId() == TYPEID_PLAYER &&
            (m_modifier.m_auraname == SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED ||
             m_modifier.m_auraname == SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED_STACKING ||
             m_modifier.m_auraname == SPELL_AURA_MOD_FLIGHT_SPEED_MOUNTED_NOT_STACKING))
        GetTarget()->SetCanFly(apply);""",
    "flying mount flight-mode hook", flags=re.S)

player.write_text(p)
spell.write_text(s)
spellmgr.write_text(sm)
auras.write_text(a)
for path, marker in [(player,"!(getClass() == CLASS_WARRIOR && CanDualWield())"),(player,"Titan's Grip-style equipment"),(player,"const bool wowccTitanGrip"),(spell,"const bool wowccUnrestrictedMount"),(spell,"const bool wowccMountAnywhere"),(spellmgr,"const bool wowccMountRelated"),(spellmgr,"!wowccMountRelated && spellInfo->HasAttribute(SPELL_ATTR_EX4_ONLY_FLYING_AREAS)"),(auras,"WoWCC TBC Fly Anywhere")]:
    if marker not in path.read_text(errors="strict"):
        raise SystemExit(f"ERROR: TBC gameplay patch verification failed in {path.name}: {marker}")
print("[core:tbc] WoWCC dual-2H + true Mount/Fly Anywhere patches verified.")
