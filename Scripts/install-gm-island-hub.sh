#!/bin/bash
set -euo pipefail

PORT="${WOWCC_MYSQL_PORT:-3307}"
MYSQL=""
for p in /opt/homebrew/opt/mysql@8.4/bin/mysql /usr/local/opt/mysql@8.4/bin/mysql /opt/homebrew/bin/mysql /usr/local/bin/mysql; do
  [[ -x "$p" ]] && MYSQL="$p" && break
done
[[ -n "$MYSQL" ]] || { echo "WoWCC GM HUB ERROR: mysql client not found"; exit 1; }

export MYSQL_PWD=wowcc
DB="acore_world"
Q=("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc --batch --skip-column-names "$DB")

echo "WoWCC GM HUB: validating AzerothCore world database..."
"${Q[@]}" -e "SELECT 1 FROM creature_template LIMIT 1;" >/dev/null
"${Q[@]}" -e "SELECT 1 FROM npc_vendor LIMIT 1;" >/dev/null
"${Q[@]}" -e "SELECT 1 FROM item_template LIMIT 1;" >/dev/null

# Custom range reserved by WoWCC.
BASE=990100
SOURCE_VENDOR=$("${Q[@]}" -e "SELECT ct.entry FROM creature_template ct JOIN creature_template_model m ON m.CreatureID=ct.entry WHERE (ct.npcflag & 128)<>0 LIMIT 1;")
SOURCE_SPAWN=$("${Q[@]}" -e "SELECT guid FROM creature WHERE id IN (SELECT entry FROM creature_template WHERE (npcflag & 128)<>0) LIMIT 1;")
[[ -n "$SOURCE_VENDOR" && -n "$SOURCE_SPAWN" ]] || { echo "WoWCC GM HUB ERROR: could not locate a source vendor/spawn to clone."; exit 1; }

sql_escape() { printf "%s" "$1" | sed "s/'/''/g"; }

clone_template() {
  local entry="$1" name="$2" sub="$3"
  local cols selects col
  rawcols=$("${Q[@]}" -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB' AND TABLE_NAME='creature_template' ORDER BY ORDINAL_POSITION;" | paste -sd, -)
  cols=""
  selects=""
  IFS=',' read -ra arr <<< "$rawcols"
  for col in "${arr[@]}"; do
    cols+="${cols:+,}\`$col\`"
  done
  for col in "${arr[@]}"; do
    local expr="\`$col\`"
    case "$col" in
      entry) expr="$entry";;
      name) expr="'$(sql_escape "$name")'";;
      subname) expr="'$(sql_escape "$sub")'";;
      npcflag) expr="129";;
      faction|Faction) expr="35";;
      IconName|iconname) expr="'Buy'";;
      gossip_menu_id|GossipMenuId) expr="0";;
      unit_flags|unitflags) expr="8194";;
      unit_flags2|unitflags2|unit_flags3|unitflags3|dynamicflags|dynamic_flags) expr="0";;
      flags_extra|flagsExtra) expr="8194";;
      minlevel|maxlevel) expr="80";;
      VerifiedBuild) expr="0";;
    esac
    selects+="${selects:+,}$expr"
  done
  "${Q[@]}" -e "DELETE FROM creature_template WHERE entry=$entry; INSERT INTO creature_template ($cols) SELECT $selects FROM creature_template WHERE entry=$SOURCE_VENDOR LIMIT 1;"
  "${Q[@]}" -e "DELETE FROM creature_template_model WHERE CreatureID=$entry; INSERT INTO creature_template_model (CreatureID,Idx,CreatureDisplayID,DisplayScale,Probability,VerifiedBuild) SELECT $entry,Idx,CreatureDisplayID,DisplayScale,Probability,0 FROM creature_template_model WHERE CreatureID=$SOURCE_VENDOR;"
}

clone_spawn() {
  local entry="$1" x="$2" y="$3" z="$4" o="$5"
  local cols selects col
  rawcols=$("${Q[@]}" -e "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB' AND TABLE_NAME='creature' AND COLUMN_NAME<>'guid' ORDER BY ORDINAL_POSITION;" | paste -sd, -)
  cols=""
  selects=""
  IFS=',' read -ra arr <<< "$rawcols"
  for col in "${arr[@]}"; do
    cols+="${cols:+,}\`$col\`"
  done
  for col in "${arr[@]}"; do
    local expr="\`$col\`"
    case "$col" in
      id) expr="$entry";;
      map) expr="1";;
      zoneId|areaId) expr="0";;
      spawnMask|phaseMask) expr="1";;
      equipment_id) expr="0";;
      position_x) expr="$x";;
      position_y) expr="$y";;
      position_z) expr="$z";;
      orientation) expr="$o";;
      spawntimesecs) expr="30";;
      wander_distance|spawndist) expr="0";;
      currentwaypoint) expr="0";;
      MovementType) expr="0";;
      npcflag|npcFlag) expr="0";;
      unit_flags|unitflags) expr="0";;
      unit_flags2|unitflags2|unit_flags3|unitflags3|dynamicflags|dynamic_flags) expr="0";;
      ScriptName) expr="''";;
      VerifiedBuild) expr="0";;
    esac
    selects+="${selects:+,}$expr"
  done
  "${Q[@]}" -e "DELETE FROM creature WHERE id=$entry; INSERT INTO creature ($cols) SELECT $selects FROM creature WHERE guid=$SOURCE_SPAWN LIMIT 1;"
}

fill_vendor() {
  local entry="$1" where="$2"
  "${Q[@]}" -e "DELETE FROM npc_vendor WHERE entry=$entry;"
  # Hard safety: 145 items, below AzerothCore's hard 150-item vendor limit.
  "${Q[@]}" -e "INSERT IGNORE INTO npc_vendor (entry,slot,item,maxcount,incrtime,ExtendedCost,VerifiedBuild)
    SELECT $entry,0,entry,0,0,0,0 FROM item_template
    WHERE $where
    ORDER BY ItemLevel DESC, Quality DESC, entry DESC LIMIT 145;"
}

# GM Island / Designer Island area. Vendors are arranged in rows around the hub.
X0=16222.0; Y0=16252.0; Z0=14.0
classes=("Warrior:1" "Paladin:2" "Hunter:4" "Rogue:8" "Priest:16" "Death Knight:32" "Shaman:64" "Mage:128" "Warlock:256" "Druid:1024")

echo "WoWCC GM HUB: installing clean specialist layout..."

# Clean every WoWCC GM Hub spawn/template from earlier versions first.
"${Q[@]}" -e "DELETE FROM npc_vendor WHERE entry BETWEEN 990100 AND 990299;"
"${Q[@]}" -e "DELETE FROM creature WHERE id BETWEEN 990100 AND 990299;"
"${Q[@]}" -e "DELETE FROM creature_template_model WHERE CreatureID BETWEEN 990100 AND 990299;"
"${Q[@]}" -e "DELETE FROM creature_template WHERE entry BETWEEN 990100 AND 990299;"

# Standard vendors cannot provide a native class/spec dropdown. Instead of dozens
# of class NPCs, WoWCC installs a small specialist hub. Each specialist is curated
# by category and the server/client's normal item usability rules apply.
install_vendor() {
  local entry="$1" label="$2" sub="$3" where="$4" x="$5" y="$6" o="$7"
  clone_template "$entry" "WoWCC — $label" "$sub"
  clone_spawn "$entry" "$x" "$y" "$Z0" "$o"
  "${Q[@]}" -e "DELETE FROM npc_vendor WHERE entry=$entry;"
  "${Q[@]}" -e "INSERT IGNORE INTO npc_vendor (entry,slot,item,maxcount,incrtime,ExtendedCost,VerifiedBuild)
    SELECT $entry,0,entry,0,0,0,0 FROM item_template
    WHERE $where
    ORDER BY ItemLevel DESC, Quality DESC, entry DESC LIMIT 145;"
  local n
  n=$("${Q[@]}" -e "SELECT COUNT(*) FROM npc_vendor WHERE entry=$entry;")
  echo "WoWCC GM HUB: $label = $n items."
}

# Clean hexagonal layout around the center point.
# Center: terminal-like PvE specialist. Right: PvP. Rear specialists: upgrades,
# collections, utility, weapons/accessories.
install_vendor 990100 "PvE Endgame" "ICC / Ruby Sanctum / T10" \
  "Quality>=4 AND RequiredLevel<=80 AND ItemLevel>=251 AND InventoryType IN (1,3,5,6,7,8,9,10,20)" \
  "$X0" "$Y0" "3.14"

install_vendor 990101 "PvP Endgame" "Wrathful Gladiator / PvP Endgame" \
  "Quality>=4 AND RequiredLevel<=80 AND name LIKE '%Wrathful Gladiator%' AND InventoryType IN (1,3,5,6,7,8,9,10,20)" \
  "$(awk "BEGIN{print $X0+8}")" "$Y0" "3.14"

install_vendor 990102 "Weapons" "PvE + PvP Endgame Weapons" \
  "Quality>=4 AND RequiredLevel<=80 AND ((ItemLevel>=251) OR name LIKE '%Wrathful Gladiator%') AND InventoryType IN (13,14,15,17,21,22,23,25,26,28)" \
  "$(awk "BEGIN{print $X0-8}")" "$Y0" "3.14"

install_vendor 990103 "Accessories" "Trinkets / Rings / Necks / Cloaks" \
  "Quality>=4 AND RequiredLevel<=80 AND ((ItemLevel>=251) OR name LIKE '%Gladiator%' OR name LIKE '%Battlemaster%') AND InventoryType IN (2,11,12,16)" \
  "$(awk "BEGIN{print $X0-6}")" "$(awk "BEGIN{print $Y0+8}")" "4.3"

install_vendor 990104 "Enhancements" "Epic Gems / Glyphs / Enchants" \
  "RequiredLevel<=80 AND ((class=3 AND Quality>=3) OR class=16 OR name LIKE 'Scroll of Enchant%' OR name LIKE '%Armor Kit%' OR name LIKE '%Spellthread%' OR name LIKE '%Leg Armor%' OR name LIKE '%Eternal Belt Buckle%')" \
  "$(awk "BEGIN{print $X0+6}")" "$(awk "BEGIN{print $Y0+8}")" "2.0"

install_vendor 990105 "Collections" "Mount-learning items" \
  "class=15 AND subclass=5 AND spellid_1<>0" \
  "$(awk "BEGIN{print $X0-6}")" "$(awk "BEGIN{print $Y0-8}")" "5.2"

install_vendor 990106 "Utility" "Bags / Flasks / Potions / Food" \
  "RequiredLevel<=80 AND ((InventoryType=18 AND Quality>=3) OR name LIKE '%Flask%' OR name LIKE '%Potion%' OR name LIKE '%Elixir%' OR name LIKE '%Feast%')" \
  "$(awk "BEGIN{print $X0+6}")" "$(awk "BEGIN{print $Y0-8}")" "1.0"
# Central WoWCC Gear Terminal. It is a Gossip NPC, not another stock vendor.
clone_template 990120 "WoWCC — Gear Menu" "Talk to me — Class / Spec / PvE / PvP"
clone_spawn 990120 "$X0" "$(awk "BEGIN{print $Y0+16}")" "$Z0" "3.14"
"${Q[@]}" -e "UPDATE creature_template SET faction=35,npcflag=1,IconName='Speak',ScriptName='wowcc_gear_terminal',
 unit_flags=(2|256|8192),unit_flags2=0,dynamicflags=0 WHERE entry=990120;"
"${Q[@]}" -e "DELETE FROM npc_vendor WHERE entry=990120;"
echo "WoWCC GM HUB: central Gossip Gear Terminal installed (entry 990120)."
TERM_SCRIPT=$("${Q[@]}" -e "SELECT ScriptName FROM creature_template WHERE entry=990120;")
TERM_FLAG=$("${Q[@]}" -e "SELECT npcflag FROM creature_template WHERE entry=990120;")
echo "WoWCC GM HUB: Gear Menu ScriptName=$TERM_SCRIPT npcflag=$TERM_FLAG"
echo "WoWCC GM HUB: IMPORTANT — Gear Menu is a Gossip NPC, not a vendor. Its menu requires mod-wowcc-gear-terminal compiled into worldserver."



# Force/verify service-NPC state after all clones. This is deliberately explicit:
# spawn-level npcflag/unit_flags can override creature_template in AzerothCore.
"${Q[@]}" -e "UPDATE creature_template
  SET faction=35, npcflag=129, IconName='Buy',
      unit_flags=(2 | 256 | 8192),
      unit_flags2=0, dynamicflags=0,
      flags_extra=(flags_extra | 2 | 8192)
  WHERE entry BETWEEN 990100 AND 990299;"

# Normalize optional spawn override columns only if they exist in this schema.
for col in npcflag unit_flags dynamicflags; do
  EXISTS=$("${Q[@]}" -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$DB' AND TABLE_NAME='creature' AND COLUMN_NAME='$col';")
  if [[ "$EXISTS" == "1" ]]; then
    "${Q[@]}" -e "UPDATE creature SET \`$col\`=0 WHERE id BETWEEN 990100 AND 990299;"
  fi
done

echo "WoWCC GM HUB: verifying vendor flags/inventory..."
BAD=$("${Q[@]}" -e "SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 990100 AND 990106 AND ((npcflag & 128)=0 OR faction<>35);")
EMPTY=$("${Q[@]}" -e "SELECT COUNT(*) FROM creature_template ct LEFT JOIN npc_vendor nv ON nv.entry=ct.entry WHERE ct.entry BETWEEN 990100 AND 990106 GROUP BY ct.entry HAVING COUNT(nv.item)=0;" | wc -l | tr -d ' ')
[[ "$BAD" == "0" ]] || { echo "WoWCC GM HUB ERROR: $BAD vendor templates failed friendly/vendor verification."; exit 1; }
[[ "$EMPTY" == "0" ]] || { echo "WoWCC GM HUB ERROR: $EMPTY vendors have empty inventories."; exit 1; }

# Report exactly what was installed.
VCOUNT=$("${Q[@]}" -e "SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 990100 AND 990299;")
ICOUNT=$("${Q[@]}" -e "SELECT COUNT(*) FROM npc_vendor WHERE entry BETWEEN 990100 AND 990299;")
echo "WoWCC GM HUB COMPLETE: $VCOUNT vendors, $ICOUNT vendor items."
echo "Location: GM Island / Kalimdor map 1 near 16222, 16252, 14."
echo "Restart World Server (recommended) so all new templates/spawns are loaded."
