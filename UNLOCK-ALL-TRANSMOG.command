#!/bin/bash
set -Eeuo pipefail
PORT="${WOWCC_MYSQL_PORT:-3307}"
MYSQL=""
for p in /opt/homebrew/opt/mysql@8.4/bin/mysql /opt/homebrew/bin/mysql /usr/local/bin/mysql /usr/bin/mysql; do
  [[ -x "$p" ]] && { MYSQL="$p"; break; }
done
[[ -n "$MYSQL" ]] || { echo "ERROR: MySQL client not found."; read -r; exit 1; }

echo "WoWCC — Enable full Transmog Collection for ALL accounts/characters"
echo "Every existing account receives every wearable WotLK armor/weapon appearance."
echo "Because the collection is account-wide, all current and future characters inherit it automatically."
echo

"$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc -pwowcc acore_characters <<'SQL'
CREATE TABLE IF NOT EXISTS custom_unlocked_appearances (
  account_id int(10) unsigned NOT NULL,
  item_template_id mediumint(8) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (account_id,item_template_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO custom_unlocked_appearances (account_id,item_template_id)
SELECT a.id, i.entry
FROM acore_auth.account a
CROSS JOIN acore_world.item_template i
WHERE i.class IN (2,4)
  AND i.InventoryType > 0
  AND i.Quality >= 1;
SQL

ACCOUNTS="$("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc -pwowcc -N -s acore_auth -e 'SELECT COUNT(*) FROM account;')"
ROWS="$("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc -pwowcc -N -s acore_characters -e 'SELECT COUNT(*) FROM custom_unlocked_appearances;')"
echo
echo "DONE — $ACCOUNTS account(s), $ROWS unlocked appearance rows."
echo "Restart worldserver once so mod-transmog reloads its collection cache."
echo "Future characters on these accounts inherit the same full collection automatically."
read -r -p "Press Return to close…" _
