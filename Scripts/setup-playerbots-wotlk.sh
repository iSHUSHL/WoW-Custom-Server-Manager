#!/bin/bash
set -Eeuo pipefail
PROFILE="${1:-wotlk}"
POPULATION="${2:-150}"
ENABLED="${3:-1}"
BGS="${4:-1}"
QUESTS="${5:-1}"
SPEED="${6:-fast}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PORT="${WOWCC_MYSQL_PORT:-3307}"
PR="$ROOT/runtime/profiles/$PROFILE"
SRC="$ROOT/sources/$PROFILE/core"
MOD="$SRC/modules/mod-playerbots"
LOG="$PR/logs/playerbots-setup.log"
mkdir -p "$PR/configs" "$PR/etc/modules" "$PR/logs"
exec > >(tee -a "$LOG") 2>&1

[[ "$PROFILE" == "wotlk" ]] || { echo "ERROR: WotLK PlayerBots setup received unsupported profile: $PROFILE"; exit 2; }
[[ -x "$PR/bin/worldserver" ]] || { echo "ERROR: WotLK PlayerBots core is not installed. Click Rebuild Core + PlayerBots first."; exit 3; }
[[ -d "$MOD" ]] || { echo "ERROR: WotLK mod-playerbots source is missing. Click Rebuild Core + PlayerBots first."; exit 4; }
case "$POPULATION" in ''|*[!0-9]*) echo "ERROR: Bot population must be numeric."; exit 5;; esac
(( POPULATION >= 10 && POPULATION <= 5000 )) || { echo "ERROR: Bot population must be 10-5000."; exit 6; }

MYSQL="$(command -v mysql || true)"
[[ -z "$MYSQL" && -x /opt/homebrew/opt/mysql@8.4/bin/mysql ]] && MYSQL=/opt/homebrew/opt/mysql@8.4/bin/mysql
[[ -z "$MYSQL" && -x /usr/local/opt/mysql@8.4/bin/mysql ]] && MYSQL=/usr/local/opt/mysql@8.4/bin/mysql
[[ -n "$MYSQL" ]] || { echo "ERROR: mysql@8.4 client not found."; exit 7; }
export MYSQL_PWD="wowcc"
M=("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc)
"${M[@]}" -e 'SELECT 1;' >/dev/null || { echo "ERROR: Managed MySQL is not running."; exit 8; }

# The module has its own DB; never execute create_mysql.sql because it hardcodes user 'acore'.
"${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS acore_playerbots CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;'

CONF="$PR/configs/playerbots.conf"
RUNTIME_CONF="$PR/etc/modules/playerbots.conf"
if [[ ! -f "$CONF" ]]; then
  DIST="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$MOD" -type f -name 'playerbots.conf.dist' 2>/dev/null | head -n1 || true)"
  [[ -n "$DIST" ]] || { echo "ERROR: playerbots.conf.dist not found. Click Rebuild Core + PlayerBots first."; exit 9; }
  cp -f "$DIST" "$CONF"
fi

python3 - "$CONF" "$POPULATION" "$ENABLED" "$BGS" "$QUESTS" "$PORT" "$SPEED" <<'PY'
import pathlib,re,sys
path=pathlib.Path(sys.argv[1])
population=int(sys.argv[2]); enabled=int(sys.argv[3]); bgs=int(sys.argv[4]); quests=int(sys.argv[5]); port=sys.argv[6]; speed=sys.argv[7]
text=path.read_text(errors='ignore')
def setv(key,value,quote=False):
    global text
    rx=re.compile(rf'^[ \t]*#?[ \t]*{re.escape(key)}[ \t]*=.*$', re.M)
    rendered=f'"{value}"' if quote else str(value)
    line=f'{key} = {rendered}'
    if rx.search(text): text=rx.sub(line,text,count=1)
    else:
        if text and not text.endswith('\n'): text+='\n'
        text += line+'\n'

# For 5,000 online bots we create enough bot accounts while keeping default conservative.
accounts=max(50,(population+8)//9)
setv('PlayerbotsDatabaseInfo',f'127.0.0.1;{port};wowcc;wowcc;acore_playerbots',True)
setv('AiPlayerbot.Enabled',enabled)
setv('AiPlayerbot.RandomBotAutologin',enabled)
setv('AiPlayerbot.MinRandomBots',population)
setv('AiPlayerbot.MaxRandomBots',population)
setv('AiPlayerbot.RandomBotAccountPrefix','RNDBOT',True)
setv('AiPlayerbot.RandomBotAccountCount',accounts)
setv('AiPlayerbot.RandomBotJoinBG',bgs)
setv('AiPlayerbot.RandomBotAutoJoinBG',bgs)
setv('AiPlayerbot.AutoDoQuests',quests)
# Keep bots spread across all WotLK continents/Outland.
setv('AiPlayerbot.RandomBotMaps','0,1,530,571',True)
# Avoid deleting an existing generated population when changing settings.
setv('AiPlayerbot.DeleteRandomBotAccounts',0)
# Stable fixed target population rather than constant count churn.
setv('AiPlayerbot.RandomBotCountChangeMinInterval',31536000)
setv('AiPlayerbot.RandomBotCountChangeMaxInterval',31536000)
# The current module expresses update interval in seconds. Use a gentler value at high populations.
interval={'safe':60,'normal':40,'fast':20,'maximum':10}.get(speed,20)
setv('AiPlayerbot.RandomBotUpdateInterval',interval)
path.write_text(text)
print(f'[playerbots:wotlk] Configured target={population}, accounts={accounts}, enabled={enabled}, BG={bgs}, quests={quests}, update={interval}s')
PY

cp -f "$CONF" "$RUNTIME_CONF"
echo "[playerbots:wotlk] Runtime config synced: $RUNTIME_CONF"

# Track every imported module SQL file to make setup repeatable/non-destructive.
"${M[@]}" acore_characters -e "CREATE TABLE IF NOT EXISTS wowcc_playerbots_migrations (scope VARCHAR(32) NOT NULL, filename VARCHAR(255) NOT NULL, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(scope,filename));" >/dev/null

apply_tree() {
  local scope="$1" db="$2" dir="$3"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' file; do
    case "$file" in */archive/*|*/custom/*|*/create/*) continue;; esac
    local rel="${file#$MOD/}"
    local escaped="${rel//\\/\\\\}"; escaped="${escaped//\'/\'\'}"
    local done
    done="$("${M[@]}" acore_characters -N -B -e "SELECT COUNT(*) FROM wowcc_playerbots_migrations WHERE scope='${scope}' AND filename='${escaped}';" 2>/dev/null || echo 0)"
    [[ "$done" == "1" ]] && continue
    echo "[playerbots:wotlk] SQL -> $db: $rel"
    "${M[@]}" "$db" < "$file"
    "${M[@]}" acore_characters -e "INSERT IGNORE INTO wowcc_playerbots_migrations(scope,filename) VALUES ('${scope}','${escaped}');" >/dev/null
  done < <(find "$dir" -type f -name '*.sql' -print0 | sort -z)
}

apply_tree playerbots acore_playerbots "$MOD/data/sql/playerbots/base"
apply_tree playerbots acore_playerbots "$MOD/data/sql/playerbots/updates"
apply_tree characters acore_characters "$MOD/data/sql/characters/base"
apply_tree characters acore_characters "$MOD/data/sql/characters/updates"
apply_tree world acore_world "$MOD/data/sql/world/base"
apply_tree world acore_world "$MOD/data/sql/world/updates"

# Validate a real playerbots DB, config and migration state before marking ready.
grep -Eq '^AiPlayerbot\.Enabled[[:space:]]*=[[:space:]]*[01]' "$RUNTIME_CONF" || { echo "ERROR: WotLK runtime PlayerBots config verification failed."; exit 10; }
PB_TABLES="$("${M[@]}" -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='acore_playerbots';" 2>/dev/null || echo 0)"
MIGRATIONS="$("${M[@]}" acore_characters -N -B -e "SELECT COUNT(*) FROM wowcc_playerbots_migrations;" 2>/dev/null || echo 0)"
(( ${PB_TABLES:-0} > 0 )) || { echo "ERROR: acore_playerbots contains no tables after module SQL import."; exit 11; }
(( ${MIGRATIONS:-0} > 0 )) || { echo "ERROR: no WotLK PlayerBots SQL migrations were applied."; exit 12; }
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PR/.playerbots-ready"
echo "[playerbots:wotlk] PLAYERBOTS READY — tables=$PB_TABLES migrations=$MIGRATIONS target=$POPULATION"
echo "[playerbots:wotlk] Restart World Server, then Initialize Bots once. Large populations may take a long time to create/login."
