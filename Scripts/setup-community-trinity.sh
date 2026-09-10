#!/bin/bash
set -Eeuo pipefail
PROFILE="${1:?profile required}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PORT="${WOWCC_MYSQL_PORT:-3307}"
PR="$ROOT/runtime/profiles/$PROFILE"
SRC="$ROOT/sources/$PROFILE/core"
CACHE="$ROOT/sources/$PROFILE/database-release"
MYSQL="$(command -v mysql || true)"
[[ -z "$MYSQL" && -x /opt/homebrew/opt/mysql@8.4/bin/mysql ]] && MYSQL=/opt/homebrew/opt/mysql@8.4/bin/mysql
[[ -z "$MYSQL" && -x /usr/local/opt/mysql@8.4/bin/mysql ]] && MYSQL=/usr/local/opt/mysql@8.4/bin/mysql
[[ -n "$MYSQL" ]] || { echo "ERROR: mysql client not found" >&2; exit 2; }
export MYSQL_PWD="wowcc"
M=("$MYSQL" --protocol=TCP -h 127.0.0.1 -P "$PORT" -u wowcc)
mkdir -p "$PR"/{configs,data,logs} "$CACHE"

case "$PROFILE" in
  cataclysm)
    API="https://api.github.com/repos/The-Cataclysm-Preservation-Project/TrinityCore/releases?per_page=20"
    BUILD=15595
    LABEL="Cataclysm 4.3.4"
    ;;
  mop)
    API="https://api.github.com/repos/ProjectSkyfire/SkyFire_548/releases?per_page=20"
    BUILD=18414
    LABEL="Mists of Pandaria 5.4.8"
    ;;
  *) echo "ERROR: unsupported community Trinity-style profile: $PROFILE" >&2; exit 3 ;;
esac

log(){ printf '[realm:%s] %s\n' "$PROFILE" "$*"; }
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

copy_conf(){
  local name="$1" found=""
  found="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$SRC" -type f -name "$name.conf.dist" 2>/dev/null | head -n1 || true)"
  [[ -z "$found" ]] && found="$(find "$PR" "$ROOT/sources/$PROFILE/build" "$SRC" -type f -name "$name.conf" 2>/dev/null | head -n1 || true)"
  [[ -n "$found" ]] || return 1
  cp -f "$found" "$PR/configs/$name.conf"
}

log "Creating isolated auth / characters / world schemas…"
"${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
if [[ "$PROFILE" == "cataclysm" ]]; then
  log "Creating Cataclysm hotfixes schema…"
  "${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS hotfixes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
fi

# Import source-provided base auth and characters schemas if they are not already present.
import_first_match(){
  local db="$1" pattern="$2" file=""
  file="$(find "$SRC/sql" -type f -iname "$pattern" 2>/dev/null | grep -Ei '/base/|create' | head -n1 || true)"
  [[ -z "$file" ]] && file="$(find "$SRC/sql" -type f -iname "$pattern" 2>/dev/null | head -n1 || true)"
  if [[ -n "$file" ]]; then
    log "Importing base $db schema: $(basename "$file")"
    "${M[@]}" "$db" < "$file"
  fi
}

has_table(){
  local db="$1" table="$2"
  local c
  c="$("${M[@]}" --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';" 2>/dev/null || echo 0)"
  [[ "$c" == "1" ]]
}

has_table auth account || import_first_match auth '*auth*.sql'
has_table auth account || import_first_match auth '*login*.sql'
has_table characters characters || import_first_match characters '*characters*.sql'

if [[ "$PROFILE" == "cataclysm" ]] && { ! has_table hotfixes item || ! has_table hotfixes item_sparse; }; then
  HOTFIX_BASE="$SRC/sql/base/dev/hotfixes_database.sql"
  [[ -f "$HOTFIX_BASE" ]] || fail "Cataclysm hotfixes base schema not found: $HOTFIX_BASE"
  log "Importing Cataclysm hotfixes database schema…"
  "${M[@]}" hotfixes < "$HOTFIX_BASE"
fi

# Cataclysm 4.3.4 intentionally does not use a WotLK-style world.item_template.
# MoP/community branches may still expose it. World download is therefore keyed
# to creature_template for Cata, and creature+item_template for MoP.
world_missing=0
has_table world creature_template || world_missing=1
if [[ "$PROFILE" == "mop" ]]; then has_table world item_template || world_missing=1; fi
if (( world_missing )); then
  log "World DB is missing. Locating latest database release…"
  ASSET_INFO="$(python3 - "$API" <<'PY'
import json,sys,urllib.request
api=sys.argv[1]
req=urllib.request.Request(api,headers={'User-Agent':'WoWServerControlCenter/1.4'})
try:
    data=json.load(urllib.request.urlopen(req,timeout=30))
except Exception as e:
    print('ERROR\t'+str(e)); raise SystemExit
releases=data if isinstance(data,list) else [data]
assets=[]
for rel in releases:
    for a in (rel.get('assets') or []):
        a=dict(a); a['_release_url']=rel.get('html_url',''); assets.append(a)
def score(a):
    n=a.get('name','').lower()
    ext=any(n.endswith(x) for x in ('.zip','.7z','.tar.gz','.tgz','.gz','.sql','.sql.gz','.bz2','.xz'))
    if not ext:return -999
    s=0
    if 'world' in n:s+=80
    if 'database' in n or 'db' in n:s+=60
    if 'full' in n:s+=30
    s+=min(int(a.get('size',0))/1000000,40)
    return s
assets=sorted(assets,key=score,reverse=True)
if not assets or score(assets[0]) < 0:
    print('NONE\t'+str(releases[0].get('html_url','') if releases else ''))
else:
    a=assets[0]; print('OK\t'+a.get('browser_download_url','')+'\t'+a.get('name','database'))
PY
)"
  status="${ASSET_INFO%%$'\t'*}"
  if [[ "$status" == "ERROR" ]]; then fail "Could not query database release: ${ASSET_INFO#*$'\t'}"; fi
  if [[ "$status" == "NONE" ]]; then
    fail "No downloadable database asset was found in the latest project release. Open the project's Releases page and retry after a DB release is published."
  fi
  rest="${ASSET_INFO#*$'\t'}"; url="${rest%%$'\t'*}"; name="${rest#*$'\t'}"
  file="$CACHE/$name"
  if [[ ! -f "$file" ]]; then
    log "Downloading database release: $name"
    curl -fL --retry 3 --progress-bar "$url" -o "$file"
  else
    log "Using cached database release: $name"
  fi
  rm -rf "$CACHE/extracted"; mkdir -p "$CACHE/extracted"
  case "$file" in
    *.zip) unzip -oq "$file" -d "$CACHE/extracted" ;;
    *.7z) command -v 7z >/dev/null || fail "7z is missing. Run Install Runtime Dependencies."; 7z x -y -o"$CACHE/extracted" "$file" >/dev/null ;;
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$CACHE/extracted" ;;
    *.sql.gz|*.gz) gzip -dc "$file" > "$CACHE/extracted/database.sql" ;;
    *.bz2) bzip2 -dc "$file" > "$CACHE/extracted/database.sql" ;;
    *.xz) xz -dc "$file" > "$CACHE/extracted/database.sql" ;;
    *.sql) cp -f "$file" "$CACHE/extracted/database.sql" ;;
    *) fail "Unsupported database archive: $name" ;;
  esac

  sql_list="$CACHE/sql-files.txt"
  find "$CACHE/extracted" -type f -iname '*.sql' | sort > "$sql_list"
  [[ -s "$sql_list" ]] || fail "Database release contained no SQL files"
  while IFS= read -r sql; do
    lower="$(basename "$sql" | tr '[:upper:]' '[:lower:]')"
    db=world
    [[ "$lower" == *auth* || "$lower" == *login* ]] && db=auth
    [[ "$lower" == *character* ]] && db=characters
    log "Importing $(basename "$sql") -> $db"
    "${M[@]}" "$db" < "$sql"
  done < "$sql_list"
fi

copy_conf authserver || fail "authserver.conf.dist not found after core install"
copy_conf worldserver || fail "worldserver.conf.dist not found after core install"

python3 - "$PR/configs/authserver.conf" "$PR/configs/worldserver.conf" "$PR/data" "$PORT" <<'PY'
import pathlib,re,sys
auth,world,data,port=sys.argv[1:]
for fn in (auth,world):
    p=pathlib.Path(fn); s=p.read_text(errors='ignore')
    repl={
      'LoginDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;auth',
      'AuthDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;auth',
      'WorldDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;world',
      'CharacterDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;characters',
      'HotfixDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;hotfixes',
    }
    for key,val in repl.items():
      s=re.sub(rf'^{re.escape(key)}\s*=.*$',f'{key} = "{val}"',s,flags=re.M)
    if p.name=='worldserver.conf': s=re.sub(r'^DataDir\s*=.*$',f'DataDir = "{data}"',s,flags=re.M)
    p.write_text(s)
PY

if [[ "$PROFILE" == "cataclysm" ]]; then
  for spec in auth.account auth.realmlist characters.characters world.creature_template hotfixes.item hotfixes.item_sparse; do
    db="${spec%%.*}"; table="${spec#*.}"
    has_table "$db" "$table" || fail "Database bootstrap incomplete: missing $spec"
  done

  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CATA_SQL="$PR/logs/cata-catalog-build.sql"
  log "Building full Cataclysm item catalog from client Item.db2 + Item-sparse.db2…"
  python3 "$SCRIPT_DIR/build-cata-catalog.py" --data-root "$PR/data" --output "$CATA_SQL"
  "${M[@]}" < "$CATA_SQL"
  rm -f "$CATA_SQL"

  cata_items="$("${M[@]}" --batch --skip-column-names world -e "SELECT COUNT(*) FROM wowcc_item_template;" 2>/dev/null || echo 0)"
  log "Cataclysm DB2 catalog health: items=$cata_items"
  if (( ${cata_items:-0} < 10000 )); then
    fail "Cataclysm catalog build is incomplete: world.wowcc_item_template has only $cata_items rows. Run Prepare Client Data again with a complete 4.3.4 client, then Repair Realm."
  fi
else
  for spec in auth.account auth.realmlist characters.characters world.item_template world.creature_template; do
    db="${spec%%.*}"; table="${spec#*.}"
    has_table "$db" "$table" || fail "Database bootstrap incomplete: missing $spec"
  done

  world_items="$("${M[@]}" --batch --skip-column-names world -e "SELECT COUNT(*) FROM item_template;" 2>/dev/null || echo 0)"
  log "Catalog health: items=$world_items"
  if (( ${world_items:-0} < 10000 )); then
    fail "$LABEL world DB is incomplete: world.item_template has only $world_items rows. Remove the downloaded database cache in Storage & Cleanup, then run Repair Realm again so WoWCC downloads/imports a full database release."
  fi
fi

# Existing community DBs normally ship a realmlist row. Update all rows safely;
# if none exists, core-specific setup will show a clear Health Check instead of inventing a schema.
"${M[@]}" auth -e "UPDATE realmlist SET address='127.0.0.1', port=8085, gamebuild=$BUILD;" 2>/dev/null || \
"${M[@]}" auth -e "UPDATE realmlist SET address='127.0.0.1', port=8085;" 2>/dev/null || true

touch "$PR/.realm-db-ready"
log "$LABEL REALM DATABASE READY"
