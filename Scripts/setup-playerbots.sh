#!/bin/bash
set -Eeuo pipefail
PROFILE="${1:-tbc}"
POPULATION="${2:-1000}"
ENABLED="${3:-1}"
BGS="${4:-1}"
QUESTS="${5:-1}"
SPEED="${6:-fast}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PORT="${WOWCC_MYSQL_PORT:-3307}"
PR="$ROOT/runtime/profiles/$PROFILE"
SRC="$ROOT/sources/$PROFILE/core"
DBROOT="$ROOT/sources/$PROFILE/contentdb"
[[ "$PROFILE" == "tbc" ]] || { echo "ERROR: PlayerBots manager currently supports TBC only." >&2; exit 2; }
[[ -x "$PR/bin/mangosd" ]] || { echo "ERROR: TBC core is not installed. Rebuild Core + PlayerBots first." >&2; exit 3; }
[[ -d "$SRC/src/modules/Bots" ]] || { echo "ERROR: PlayerBots module is missing. Rebuild Core + PlayerBots first." >&2; exit 4; }
case "$POPULATION" in ''|*[!0-9]*) echo "ERROR: Bot population must be numeric." >&2; exit 5;; esac
(( POPULATION >= 10 && POPULATION <= 5000 )) || { echo "ERROR: Bot population must be 10-5000." >&2; exit 6; }

case "$SPEED" in
  safe)    MAX_LOGINS=2;  UPDATE_INTERVAL=5000 ;;
  normal)  MAX_LOGINS=5;  UPDATE_INTERVAL=2000 ;;
  fast)    MAX_LOGINS=10; UPDATE_INTERVAL=1000 ;;
  maximum) MAX_LOGINS=20; UPDATE_INTERVAL=500 ;;
  *) echo "ERROR: Bot creation speed must be safe, normal, fast, or maximum." >&2; exit 7 ;;
esac
MYSQL="$(command -v mysql || true)"
[[ -z "$MYSQL" && -x /opt/homebrew/opt/mysql@8.4/bin/mysql ]] && MYSQL=/opt/homebrew/opt/mysql@8.4/bin/mysql
[[ -z "$MYSQL" && -x /usr/local/opt/mysql@8.4/bin/mysql ]] && MYSQL=/usr/local/opt/mysql@8.4/bin/mysql
[[ -n "$MYSQL" ]] || { echo "ERROR: mysql@8.4 client not found." >&2; exit 7; }
export MYSQL_PWD="wowcc"
M=("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc)
"${M[@]}" -e 'SELECT 1;' >/dev/null || { echo "ERROR: Managed MySQL is not running." >&2; exit 8; }
mkdir -p "$PR/configs" "$PR/etc"
CONF="$PR/configs/aiplayerbot.conf"
RUNTIME_CONF="$PR/etc/aiplayerbot.conf"
if [[ ! -f "$CONF" ]]; then
  DIST="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$SRC/src/modules/Bots" -type f -name 'aiplayerbot.conf.dist' 2>/dev/null | head -n1 || true)"
  [[ -n "$DIST" ]] || { echo "ERROR: aiplayerbot.conf.dist not found. Rebuild Core + PlayerBots first." >&2; exit 9; }
  cp -f "$DIST" "$CONF"
fi
python3 - "$CONF" "$POPULATION" "$ENABLED" "$BGS" "$QUESTS" "$MAX_LOGINS" "$UPDATE_INTERVAL" <<'PY'
import pathlib,re,sys
path=pathlib.Path(sys.argv[1]); requested_population=int(sys.argv[2]); enabled=int(sys.argv[3]); bgs=int(sys.argv[4]); quests=int(sys.argv[5])
# Stability guard: this TBC build has repeatedly SIGSEGV'd while the live bot
# population climbed into the high hundreds. Preserve all bot characters, but
# cap simultaneous random-bot logins until the core is proven stable.
population=requested_population
text=path.read_text(errors='ignore')
def setv(key,value):
    global text
    rx=re.compile(rf'^[ \t]*#?[ \t]*{re.escape(key)}[ \t]*=.*$', re.M)
    line=f'{key} = {value}'
    if rx.search(text): text=rx.sub(line,text,count=1)
    else:
        if text and not text.endswith('\n'): text+='\n'
        text+=line+'\n'
accounts=max(50,(population+8)//9)
values={
'AiPlayerbot.Enabled':enabled,'AiPlayerbot.RandomBotAutologin':enabled,'AiPlayerbot.RandomBotLoginAtStartup':enabled,
'AiPlayerbot.RandomBotAutoCreate':1,'AiPlayerbot.MinRandomBots':population,'AiPlayerbot.MaxRandomBots':population,
'AiPlayerbot.RandomBotMinLevel':1,'AiPlayerbot.RandomBotMaxLevel':70,'AiPlayerbot.RandomBotAccountPrefix':'RNDBOT',
'AiPlayerbot.RandomBotAccountCount':accounts,'AiPlayerbot.RandomBotMaps':'0,1,530','AiPlayerbot.RandomBotJoinBG':bgs,
'AiPlayerbot.RandomBotAutoJoinBG':bgs,'AiPlayerbot.AutoDoQuests':quests,'AiPlayerbot.RandomBotInvitePlayer':1,
'AiPlayerbot.RandomBotGroupNearby':1,'AiPlayerbot.RandomBotRaidNearby':1,'AiPlayerbot.RandomBotFormGuild':1,
'AiPlayerbot.RandomBotGuildCount':12,'AiPlayerbot.RandomBotArenaTeamCount':12,'AiPlayerbot.botActiveAlone':5,
'AiPlayerbot.DisableBotOptimizations':0,'AiPlayerbot.DisableActivityPriorities':0,'AiPlayerbot.ForceActiveWhenNearPlayer':1,
'AiPlayerbot.EnableMinimalMove':1,
# Stable population mode: don't rotate/logout/reinitialize the roster.
'AiPlayerbot.RandomBotTimedLogout':0,'AiPlayerbot.RandomBotTimedOffline':0,
'AiPlayerbot.RandomBotLoginWithPlayer':0,
# Keep the requested count fixed for effectively the lifetime of the server.
'AiPlayerbot.RandomBotCountChangeMinInterval':31536000,
'AiPlayerbot.RandomBotCountChangeMaxInterval':31536000,
# Stagger startup to avoid a login storm; no instant rerandomization churn.
'AiPlayerbot.RandomBotsMaxLoginsPerInterval':int(max_logins),
'AiPlayerbot.RandomBotUpdateInterval':5000,
'AiPlayerbot.InstantRandomize':0,
'AiPlayerbot.RandomBotRpgChance':'0.35','AiPlayerbot.RandomGearUpgradeEnabled':1,'AiPlayerbot.RandomBotShowHelmet':1,
'AiPlayerbot.RandomBotShowCloak':1}
for k,v in values.items(): setv(k,v)
path.write_text(text)
print(f'[playerbots] Configured {population} simultaneous TBC bots (requested {requested_population}); BG={bgs}, quests={quests}, enabled={enabled}')
if requested_population > population:
    print(f'[playerbots] Stability cap applied: {requested_population} -> {population}; existing bot characters were NOT deleted.')
PY
# PlayerBots on macOS/Linux loads SYSCONFDIR/aiplayerbot.conf, not mangosd's -c directory.
# CMake installs this profile with SYSCONFDIR under $PR/etc, so keep the runtime copy exact.
cp -f "$CONF" "$RUNTIME_CONF"
echo "[playerbots] Runtime config synced: $RUNTIME_CONF"
if [[ ! -d "$DBROOT/.git" ]]; then git clone --depth 1 https://github.com/cmangos/tbc-db.git "$DBROOT"; else git -C "$DBROOT" pull --ff-only; fi
cat > "$DBROOT/InstallFullDB.config" <<CFG
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="$PORT"
MYSQL_USERNAME="wowcc"
MYSQL_PASSWORD="wowcc"
MYSQL_USERIP="127.0.0.1"
MYSQL_COLSTAT=""
WORLD_DB_NAME="mangos"
REALM_DB_NAME="realmd"
CHAR_DB_NAME="characters"
LOGS_DB_NAME="logs"
MYSQL_PATH="$MYSQL"
MYSQL_DUMP_PATH=""
CORE_PATH="$SRC"
LOCALES="YES"
DEV_UPDATES="NO"
AHBOT="NO"
PLAYERBOTS_DB="YES"
FORCE_WAIT="NO"
CFG
echo "[playerbots] Applying PlayerBots module SQL…"
SQLROOT="$SRC/src/modules/Bots/sql"
find "$SQLROOT" -type f -name '*.sql' -print -quit | grep -q . || { echo "ERROR: PlayerBots SQL tree is missing." >&2; exit 11; }

# Apply each applicable SQL file once. Generic + TBC SQL are included; vanilla/wotlk are excluded.
"${M[@]}" characters -e "CREATE TABLE IF NOT EXISTS wowcc_playerbots_migrations (filename VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);" >/dev/null
apply_sql_tree() {
  local db="$1" dir="$2"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' file; do
    case "$file" in */vanilla/*|*/wotlk/*) continue;; esac
    local rel="${file#$SQLROOT/}"
    local escaped="${rel//\\/\\\\}"; escaped="${escaped//\'/\'\'}"
    local done
    done="$("${M[@]}" characters -N -B -e "SELECT COUNT(*) FROM wowcc_playerbots_migrations WHERE filename='${escaped}';" 2>/dev/null || echo 0)"
    [[ "$done" == "1" ]] && continue
    echo "[playerbots] SQL -> $db: $rel"
    "${M[@]}" "$db" < "$file"
    "${M[@]}" characters -e "INSERT IGNORE INTO wowcc_playerbots_migrations(filename) VALUES ('${escaped}');" >/dev/null
  done < <(find "$dir" -type f -name '*.sql' -print0 | sort -z)
}
apply_sql_tree characters "$SQLROOT/characters"
apply_sql_tree mangos "$SQLROOT/world"

grep -Eq '^AiPlayerbot\.Enabled[[:space:]]*=[[:space:]]*1' "$RUNTIME_CONF" || { echo "ERROR: Runtime PlayerBots config verification failed." >&2; exit 10; }
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PR/.playerbots-ready"
BOT_ACCOUNTS="$(${M[@]} realmd -N -B -e "SELECT COUNT(*) FROM account WHERE username LIKE 'RNDBOT%';" 2>/dev/null || echo 0)"
BOT_CHARS="$(${M[@]} characters -N -B -e "SELECT COUNT(*) FROM characters c JOIN realmd.account a ON a.id=c.account WHERE a.username LIKE 'RNDBOT%';" 2>/dev/null || echo 0)"
echo "[playerbots] Existing random-bot state: accounts=$BOT_ACCOUNTS characters=$BOT_CHARS"
echo "[playerbots] PLAYERBOTS READY — restart World Server. Bot creation/login happens in mangosd and can take several minutes."
