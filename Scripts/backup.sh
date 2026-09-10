#!/bin/bash
set -Eeuo pipefail
PROFILE="${1:-wotlk}"; PORT="${2:-3307}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
OUT="$ROOT/runtime/backups/${PROFILE}-$(date +%Y%m%d-%H%M%S).sql.gz"
DUMP="$(command -v mysqldump || true)"; [[ -z "$DUMP" && -x /opt/homebrew/opt/mysql@8.4/bin/mysqldump ]] && DUMP=/opt/homebrew/opt/mysql@8.4/bin/mysqldump
[[ -n "$DUMP" ]] || { echo "mysqldump not found"; exit 2; }
case "$PROFILE" in
  wotlk) DBS=(acore_auth acore_characters acore_world) ;;
  vanilla|tbc) DBS=(realmd characters mangos) ;;
  cataclysm|mop) DBS=(auth characters world) ;;
  *) echo "No automatic backup schema assigned to $PROFILE" >&2; exit 3 ;;
esac
MYSQL_PWD=wowcc "$DUMP" --protocol=TCP -h127.0.0.1 -P"$PORT" -uwowcc --single-transaction --routines --events --databases "${DBS[@]}" 2>/dev/null | gzip > "$OUT"
echo "$OUT"
