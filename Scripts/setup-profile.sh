#!/bin/bash
set -Eeuo pipefail
PROFILE="${1:-wotlk}"
CLIENT="${2:-}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PORT="${WOWCC_MYSQL_PORT:-3307}"
PR="$ROOT/runtime/profiles/$PROFILE"
SRC="$ROOT/sources/$PROFILE/core"

# Some community core config parsers split paths containing spaces even when quoted.
# Keep macOS data in Application Support, but expose a stable no-space alias for
# dbimport/core configs and other command-line tools.
ROOT_ALIAS="$HOME/.wowcc"
if [[ -L "$ROOT_ALIAS" ]]; then
  CURRENT_TARGET="$(readlink "$ROOT_ALIAS" || true)"
  if [[ "$CURRENT_TARGET" != "$ROOT" ]]; then
    rm -f "$ROOT_ALIAS"
    ln -s "$ROOT" "$ROOT_ALIAS"
  fi
elif [[ -e "$ROOT_ALIAS" ]]; then
  echo "ERROR: $ROOT_ALIAS exists and is not a symlink. Rename/remove it, then retry." >&2
  exit 29
else
  ln -s "$ROOT" "$ROOT_ALIAS"
fi
PR_ALIAS="$ROOT_ALIAS/runtime/profiles/$PROFILE"
SRC_ALIAS="$ROOT_ALIAS/sources/$PROFILE/core"
MYSQL="$(command -v mysql || true)"
[[ -z "$MYSQL" && -x /opt/homebrew/opt/mysql@8.4/bin/mysql ]] && MYSQL=/opt/homebrew/opt/mysql@8.4/bin/mysql
[[ -z "$MYSQL" && -x /usr/local/opt/mysql@8.4/bin/mysql ]] && MYSQL=/usr/local/opt/mysql@8.4/bin/mysql
[[ -n "$MYSQL" ]] || { echo "mysql@8.4 client not found"; exit 2; }
export MYSQL_PWD="wowcc"
M=("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc)
mkdir -p "$PR"/{configs,etc,data,logs}

copy_conf() {
  local name="$1" found
  found="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$SRC" -type f -name "$name.conf.dist" 2>/dev/null | head -n1 || true)"
  [[ -z "$found" ]] && found="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$SRC" -type f -name "$name.conf" 2>/dev/null | head -n1 || true)"
  [[ -n "$found" ]] && cp -f "$found" "$PR/configs/$name.conf"
}

if [[ "$PROFILE" == "wotlk" ]]; then
  rm -f "$PR/.realm-db-ready"
  echo "[realm:wotlk] Creating AzerothCore databases…"
  "${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS acore_auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS acore_characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS acore_world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'

  copy_conf authserver
  copy_conf worldserver

  # dbimport is the supported non-interactive AzerothCore database bootstrap tool.
  DBIMPORT="$PR/bin/dbimport"
  [[ -x "$DBIMPORT" ]] || { echo "ERROR: dbimport was not installed with the core. Re-run Install Core." >&2; exit 31; }
  DBIMPORT_DIST="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$SRC" -type f -name 'dbimport.conf.dist' 2>/dev/null | head -n1 || true)"
  [[ -n "$DBIMPORT_DIST" ]] || { echo "ERROR: dbimport.conf.dist was not found in the AzerothCore source/build." >&2; exit 32; }
  cp -f "$DBIMPORT_DIST" "$PR/configs/dbimport.conf"
  # AzerothCore dbimport may fall back to <install>/etc/dbimport.conf if the
  # --config override is rejected by an older config parser. Keep an identical
  # compatibility copy there so Setup/Repair remains deterministic.
  cp -f "$PR/configs/dbimport.conf" "$PR/etc/dbimport.conf"

  python3 - "$PR/configs/authserver.conf" "$PR/configs/worldserver.conf" "$PR/configs/dbimport.conf" "$PR/etc/dbimport.conf" "$PR_ALIAS/data" "$PORT" "$SRC_ALIAS" "$MYSQL" "$PR_ALIAS/logs" <<'PY'
import sys,re,pathlib
auth,world,dbimp,dbimp_fallback,data,port,src,mysql,logs=sys.argv[1:]
for f in [auth,world,dbimp,dbimp_fallback]:
 p=pathlib.Path(f)
 if not p.exists(): continue
 s=p.read_text(errors='ignore')
 s=re.sub(r'^LoginDatabaseInfo\s*=.*$',f'LoginDatabaseInfo = "127.0.0.1;{port};wowcc;wowcc;acore_auth"',s,flags=re.M)
 s=re.sub(r'^WorldDatabaseInfo\s*=.*$',f'WorldDatabaseInfo = "127.0.0.1;{port};wowcc;wowcc;acore_world"',s,flags=re.M)
 s=re.sub(r'^CharacterDatabaseInfo\s*=.*$',f'CharacterDatabaseInfo = "127.0.0.1;{port};wowcc;wowcc;acore_characters"',s,flags=re.M)
 if p.name=='worldserver.conf':
  s=re.sub(r'^DataDir\s*=.*$',f'DataDir = "{data}"',s,flags=re.M)
 if p.name=='dbimport.conf':
  s=re.sub(r'^SourceDirectory\s*=.*$',f'SourceDirectory = "{src}"',s,flags=re.M)
  s=re.sub(r'^MySQLExecutable\s*=.*$',f'MySQLExecutable = "{mysql}"',s,flags=re.M)
  s=re.sub(r'^LogsDir\s*=.*$',f'LogsDir = "{logs}"',s,flags=re.M)
  s=re.sub(r'^Updates\.EnableDatabases\s*=.*$', 'Updates.EnableDatabases = 7', s, flags=re.M)
  s=re.sub(r'^Updates\.AutoSetup\s*=.*$', 'Updates.AutoSetup = 1', s, flags=re.M)
 p.write_text(s)
PY

  echo "[realm:wotlk] Populating/updating Auth, Characters and World databases…"
  echo "[realm:wotlk] dbimport config: $PR_ALIAS/configs/dbimport.conf"

  # Ensure both explicit and compiled-in fallback locations exist through the
  # no-space alias before invoking dbimport.
  [[ -f "$PR_ALIAS/configs/dbimport.conf" ]] || { echo "ERROR: Missing alias config $PR_ALIAS/configs/dbimport.conf" >&2; exit 34; }
  [[ -f "$PR_ALIAS/etc/dbimport.conf" ]] || { echo "ERROR: Missing fallback config $PR_ALIAS/etc/dbimport.conf" >&2; exit 35; }

  # Use the long form explicitly. The argument contains no spaces.
  # dbimport exits only after all enabled DBs are created/populated/updated.
  (cd "$PR_ALIAS/bin" && "$PR_ALIAS/bin/dbimport" --config "$PR_ALIAS/configs/dbimport.conf")

  echo "[realm:wotlk] Verifying required AzerothCore tables…"
  required=(
    "acore_auth.account"
    "acore_auth.realmlist"
    "acore_characters.characters"
    "acore_characters.item_instance"
    "acore_characters.character_inventory"
    "acore_world.item_template"
    "acore_world.creature_template"
  )
  for spec in "${required[@]}"; do
    db="${spec%%.*}"; table="${spec#*.}"
    count="$("${M[@]}" --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';" 2>/dev/null || echo 0)"
    [[ "$count" == "1" ]] || { echo "ERROR: Database bootstrap incomplete: missing ${spec}" >&2; exit 33; }
  done

  # Ensure the local realm exists and points back to this Mac.
  "${M[@]}" acore_auth -e "INSERT INTO realmlist (id,name,address,localAddress,localSubnetMask,port,icon,flag,timezone,allowedSecurityLevel,population,gamebuild) VALUES (1,'WoW Control Center','127.0.0.1','127.0.0.1','255.255.255.0',8085,0,0,1,0,0,12340) ON DUPLICATE KEY UPDATE name=VALUES(name),address=VALUES(address),localAddress=VALUES(localAddress),port=VALUES(port),gamebuild=VALUES(gamebuild);"

  touch "$PR/.realm-db-ready"
  echo "[realm:wotlk] REALM DATABASE READY"

elif [[ "$PROFILE" == "vanilla" || "$PROFILE" == "tbc" ]]; then
  rm -f "$PR/.realm-db-ready"
  echo "[realm:$PROFILE] Checking CMaNGOS databases…"
  "${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS realmd CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS mangos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS logs CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'

  table_exists() {
    local db="$1" table="$2" count
    count="$("${M[@]}" --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';" 2>/dev/null || echo 0)"
    [[ "$count" == "1" ]]
  }

  import_base_if_missing() {
    local file="$1"
    local db="$2"
    local sentinel="$3"
    local sql="$SRC/sql/base/${file}.sql"
    if table_exists "$db" "$sentinel"; then
      echo "[realm:$PROFILE] $db base already present — skipping duplicate base import."
      return 0
    fi
    [[ -f "$sql" ]] || { echo "ERROR: Missing CMaNGOS base SQL: $sql" >&2; exit 41; }
    echo "[realm:$PROFILE] Importing $file.sql into $db…"
    "${M[@]}" "$db" < "$sql"
  }

  # Setup/Repair must be idempotent. Older Control Center builds imported these
  # files on every run, which caused ERROR 1050 on tables that already existed.
  import_base_if_missing realmd realmd account
  import_base_if_missing characters characters characters
  import_base_if_missing logs logs logs_db_version

  # The world base is also only imported once. If a previous interrupted run
  # left it genuinely incomplete, rebuild ONLY the world DB; accounts and
  # characters remain untouched.
  if ! table_exists mangos item_template || ! table_exists mangos creature_template; then
    existing_tables="$("${M[@]}" --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='mangos';" 2>/dev/null || echo 0)"
    if [[ "${existing_tables:-0}" != "0" ]]; then
      echo "[realm:$PROFILE] Incomplete world schema detected — rebuilding mangos only (accounts/characters are preserved)."
      "${M[@]}" -e 'DROP DATABASE IF EXISTS mangos; CREATE DATABASE mangos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    fi
    import_base_if_missing mangos mangos item_template
  else
    echo "[realm:$PROFILE] mangos base already present — skipping duplicate base import."
  fi

  DBROOT="$ROOT/sources/$PROFILE/contentdb"
  REPO="https://github.com/cmangos/classic-db.git"; [[ "$PROFILE" == "tbc" ]] && REPO="https://github.com/cmangos/tbc-db.git"
  if [[ ! -d "$DBROOT/.git" ]]; then git clone --depth 1 "$REPO" "$DBROOT"; else git -C "$DBROOT" pull --ff-only; fi
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
PLAYERBOTS_DB="$([[ "$PROFILE" == "tbc" ]] && echo YES || echo NO)"
FORCE_WAIT="NO"
CFG

  echo "[realm:$PROFILE] Installing/updating CMaNGOS world content…"
  # Explicit non-interactive world mode. Running with no argument enters the
  # InstallFullDB interactive menu and is not appropriate for a GUI task.
  (cd "$DBROOT" && bash ./InstallFullDB.sh -World)

  echo "[realm:$PROFILE] Verifying required CMaNGOS tables…"
  required=(
    "realmd.account"
    "realmd.realmlist"
    "characters.characters"
    "mangos.item_template"
    "mangos.creature_template"
  )
  for spec in "${required[@]}"; do
    db="${spec%%.*}"; table="${spec#*.}"
    table_exists "$db" "$table" || { echo "ERROR: CMaNGOS database incomplete: missing ${spec}" >&2; exit 42; }
  done

  copy_conf realmd; copy_conf mangosd

  # Never inherit upstream/example database names such as tbcrealmd,
  # tbcmangos or tbccharacters. Control Center deliberately uses the same
  # isolated schema names for Vanilla/TBC: realmd, mangos, characters, logs.
  python3 - "$PR/configs/realmd.conf" "$PR/configs/mangosd.conf" "$PR_ALIAS/data" "$PORT" <<'PY'
import sys,re,pathlib

realmd_path, mangosd_path, data_dir, port = sys.argv[1:]

def force_setting(text, key, value):
    pattern = rf'^[ \t]*{re.escape(key)}[ \t]*=.*$'
    replacement = f'{key} = "{value}"'
    if re.search(pattern, text, flags=re.M):
        return re.sub(pattern, replacement, text, count=1, flags=re.M)
    if text and not text.endswith('\n'):
        text += '\n'
    return text + replacement + '\n'

rp = pathlib.Path(realmd_path)
if not rp.exists():
    raise SystemExit(f"ERROR: Missing CMaNGOS realmd config: {rp}")
s = rp.read_text(errors='ignore')
s = force_setting(s, 'LoginDatabaseInfo', f'127.0.0.1;{port};wowcc;wowcc;realmd')
rp.write_text(s)

mp = pathlib.Path(mangosd_path)
if not mp.exists():
    raise SystemExit(f"ERROR: Missing CMaNGOS mangosd config: {mp}")
s = mp.read_text(errors='ignore')
s = force_setting(s, 'LoginDatabaseInfo',     f'127.0.0.1;{port};wowcc;wowcc;realmd')
s = force_setting(s, 'WorldDatabaseInfo',     f'127.0.0.1;{port};wowcc;wowcc;mangos')
s = force_setting(s, 'CharacterDatabaseInfo', f'127.0.0.1;{port};wowcc;wowcc;characters')
s = force_setting(s, 'LogsDatabaseInfo',      f'127.0.0.1;{port};wowcc;wowcc;logs')
s = force_setting(s, 'DataDir', data_dir)
mp.write_text(s)

expected = {
    rp: {
        'LoginDatabaseInfo': f'127.0.0.1;{port};wowcc;wowcc;realmd',
    },
    mp: {
        'LoginDatabaseInfo': f'127.0.0.1;{port};wowcc;wowcc;realmd',
        'WorldDatabaseInfo': f'127.0.0.1;{port};wowcc;wowcc;mangos',
        'CharacterDatabaseInfo': f'127.0.0.1;{port};wowcc;wowcc;characters',
        'LogsDatabaseInfo': f'127.0.0.1;{port};wowcc;wowcc;logs',
    }
}

for path, settings in expected.items():
    text = path.read_text(errors='ignore')
    for key, value in settings.items():
        wanted = f'{key} = "{value}"'
        if wanted not in text:
            raise SystemExit(f"ERROR: Config verification failed: {path.name} does not contain {wanted}")
    forbidden = ('tbcrealmd', 'tbcmangos', 'tbccharacters', 'tbclogs')
    bad = [name for name in forbidden if name in text]
    if bad:
        raise SystemExit(f"ERROR: Config verification failed: stale database name(s) in {path.name}: {', '.join(bad)}")

print(f"[realm-config] realmd -> 127.0.0.1:{port}/realmd")
print(f"[realm-config] mangosd login=realmd world=mangos characters=characters logs=logs")
PY
  "${M[@]}" realmd -e "UPDATE realmlist SET address='127.0.0.1', port=8085 WHERE id=1;" 2>/dev/null || true
  touch "$PR/.realm-db-ready"
  echo "[realm:$PROFILE] REALM DATABASE READY"
elif [[ "$PROFILE" == "cataclysm" || "$PROFILE" == "mop" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  exec "$SCRIPT_DIR/setup-community-trinity.sh" "$PROFILE"
else
  echo "Custom profile: binaries/configs are imported, but DB schema must match the chosen community core."
fi
