#!/usr/bin/env python3
from pathlib import Path

ROOT = Path('.')

def replace(path, old, new, count=1):
    p = ROOT / path
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'MARKER NOT FOUND in {path}: {old[:120]!r}')
    s2 = s.replace(old, new, count)
    p.write_text(s2)
    print(f'patched {path}')

# -----------------------------------------------------------------------------
# install-profile.sh: WotLK must use the Playerbot fork and module.
# -----------------------------------------------------------------------------
replace('Scripts/install-profile.sh',
'''case "$PROFILE" in
  wotlk) REPO="https://github.com/azerothcore/azerothcore-wotlk.git" ;;
  vanilla) REPO="https://github.com/cmangos/mangos-classic.git" ;;''',
'''BRANCH=""
case "$PROFILE" in
  wotlk) REPO="https://github.com/mod-playerbots/azerothcore-wotlk.git"; BRANCH="Playerbot" ;;
  vanilla) REPO="https://github.com/cmangos/mangos-classic.git" ;;''')

replace('Scripts/install-profile.sh',
'''if [[ ! -d "$SRC_ROOT/.git" ]]; then
  rm -rf "$SRC_ROOT"
  git clone --depth 1 --recursive "$REPO" "$SRC_ROOT"
else
  git -C "$SRC_ROOT" fetch --depth 1 origin
  git -C "$SRC_ROOT" reset --hard origin/HEAD
  git -C "$SRC_ROOT" submodule update --init --recursive
fi

# Official CMaNGOS PlayerBots module.''',
'''if [[ ! -d "$SRC_ROOT/.git" ]]; then
  rm -rf "$SRC_ROOT"
  if [[ -n "$BRANCH" ]]; then
    git clone --depth 1 --single-branch --branch "$BRANCH" --recursive "$REPO" "$SRC_ROOT"
  else
    git clone --depth 1 --recursive "$REPO" "$SRC_ROOT"
  fi
else
  if [[ -n "$BRANCH" ]]; then
    git -C "$SRC_ROOT" fetch --depth 1 origin "$BRANCH"
    git -C "$SRC_ROOT" reset --hard "origin/$BRANCH"
  else
    git -C "$SRC_ROOT" fetch --depth 1 origin
    git -C "$SRC_ROOT" reset --hard origin/HEAD
  fi
  git -C "$SRC_ROOT" submodule update --init --recursive
fi

# WotLK PlayerBots requires the maintained Playerbot AzerothCore fork plus the module.
if [[ "$PROFILE" == "wotlk" ]]; then
  WOTLK_BOTS_DIR="$SRC_ROOT/modules/mod-playerbots"
  WOTLK_BOTS_REPO="https://github.com/mod-playerbots/mod-playerbots.git"
  log "Preparing WotLK mod-playerbots module…"
  if [[ -d "$WOTLK_BOTS_DIR/.git" ]]; then
    git -C "$WOTLK_BOTS_DIR" fetch --depth 1 origin master
    git -C "$WOTLK_BOTS_DIR" reset --hard origin/master
  else
    rm -rf "$WOTLK_BOTS_DIR"
    git clone --depth 1 --single-branch --branch master "$WOTLK_BOTS_REPO" "$WOTLK_BOTS_DIR"
  fi
  [[ -f "$WOTLK_BOTS_DIR/CMakeLists.txt" ]] || fail "WotLK mod-playerbots clone is incomplete: $WOTLK_BOTS_DIR"
  log "WotLK PlayerBots source ready (Playerbot fork + mod-playerbots)."
fi

# Official CMaNGOS PlayerBots module.''')

replace('Scripts/install-profile.sh',
'''if [[ "$PROFILE" == "tbc" ]]; then
  BOT_DIST="$(find "$PROFILE_ROOT" "$BUILD" "$SRC_ROOT/src/modules/Bots" -type f -name 'aiplayerbot.conf.dist' 2>/dev/null | head -n1 || true)"''',
'''if [[ "$PROFILE" == "wotlk" ]]; then
  BOT_DIST="$(find "$PROFILE_ROOT" "$BUILD" "$SRC_ROOT/modules/mod-playerbots" -type f -name 'playerbots.conf.dist' 2>/dev/null | head -n1 || true)"
  if [[ -n "$BOT_DIST" ]]; then
    mkdir -p "$PROFILE_ROOT/configs" "$PROFILE_ROOT/etc/modules"
    [[ -f "$PROFILE_ROOT/configs/playerbots.conf" ]] || cp -f "$BOT_DIST" "$PROFILE_ROOT/configs/playerbots.conf"
    cp -f "$PROFILE_ROOT/configs/playerbots.conf" "$PROFILE_ROOT/etc/modules/playerbots.conf"
    log "Installed WotLK playerbots.conf; use the PlayerBots page to tune population."
  fi
  [[ -f "$PROFILE_ROOT/configs/playerbots.conf" ]] || fail "WotLK PlayerBots built but playerbots.conf was not found after install"
fi

if [[ "$PROFILE" == "tbc" ]]; then
  BOT_DIST="$(find "$PROFILE_ROOT" "$BUILD" "$SRC_ROOT/src/modules/Bots" -type f -name 'aiplayerbot.conf.dist' 2>/dev/null | head -n1 || true)"''')

# -----------------------------------------------------------------------------
# Add dedicated WotLK PlayerBots setup script.
# -----------------------------------------------------------------------------
setup = r'''#!/bin/bash
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
'''
(ROOT / 'Scripts/setup-playerbots-wotlk.sh').write_text(setup)

# -----------------------------------------------------------------------------
# ServerModel.swift: support both TBC and WotLK.
# -----------------------------------------------------------------------------
replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''    var playerBotsReady: Bool { selectedExpansion == .tbc && FileManager.default.fileExists(atPath: profileRoot.appendingPathComponent(".playerbots-ready").path) && FileManager.default.fileExists(atPath: profileRoot.appendingPathComponent("configs/aiplayerbot.conf").path) }''',
'''    var playerBotsSupported: Bool { selectedExpansion == .tbc || selectedExpansion == .wotlk }
    var playerBotsReady: Bool {
        guard playerBotsSupported else { return false }
        let configName = selectedExpansion == .wotlk ? "configs/playerbots.conf" : "configs/aiplayerbot.conf"
        return FileManager.default.fileExists(atPath: profileRoot.appendingPathComponent(".playerbots-ready").path) &&
               FileManager.default.fileExists(atPath: profileRoot.appendingPathComponent(configName).path)
    }''')

replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''    func installOrRepairPlayerBots() {
        guard selectedExpansion == .tbc else { statusMessage = "PlayerBots world population is currently wired for TBC only"; return }
        guard profileInstalled else { statusMessage = "Build the TBC core first. Rebuild Core + PlayerBots compiles the module."; return }
        stopAll()
        Task {
            do {
                statusMessage = "Starting database for PlayerBots setup…"
                try await startMySQL()
                try configureDatabaseAccess()
                savePlayerBotSettings()
                let requestedBots = playerBotPopulation
                let stableBots = requestedBots
                if requestedBots > stableBots {
                    statusMessage = "Applying PlayerBots stability cap: \(requestedBots) requested → \(stableBots) simultaneous. Existing bot characters are preserved."
                }
                runScript("setup-playerbots.sh", args: ["tbc", "\(stableBots)", playerBotsEnabled ? "1" : "0", playerBotsBattlegrounds ? "1" : "0", playerBotsQuesting ? "1" : "0", playerBotCreationSpeed.lowercased()])
            } catch { statusMessage = "PlayerBots setup failed: \(error.localizedDescription)" }
        }
    }''',
'''    func installOrRepairPlayerBots() {
        guard playerBotsSupported else { statusMessage = "PlayerBots are available for TBC and WotLK."; return }
        guard profileInstalled else { statusMessage = "Build the \(selectedExpansion.shortTitle) core with PlayerBots first."; return }
        stopAll()
        Task {
            do {
                statusMessage = "Starting database for \(selectedExpansion.shortTitle) PlayerBots setup…"
                try await startMySQL()
                try configureDatabaseAccess()
                savePlayerBotSettings()
                let bots = min(5000, max(10, playerBotPopulation))
                if selectedExpansion == .wotlk {
                    runScript("setup-playerbots-wotlk.sh", args: ["wotlk", "\(bots)", playerBotsEnabled ? "1" : "0", playerBotsBattlegrounds ? "1" : "0", playerBotsQuesting ? "1" : "0", playerBotCreationSpeed.lowercased()])
                } else {
                    runScript("setup-playerbots.sh", args: ["tbc", "\(bots)", playerBotsEnabled ? "1" : "0", playerBotsBattlegrounds ? "1" : "0", playerBotsQuesting ? "1" : "0", playerBotCreationSpeed.lowercased()])
                }
            } catch { statusMessage = "PlayerBots setup failed: \(error.localizedDescription)" }
        }
    }''')

replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''    private func ensurePlayerBotRuntimeConfig() throws {
        guard selectedExpansion == .tbc else { return }
        let fm = FileManager.default
        let configDir = profileRoot.appendingPathComponent("configs", isDirectory: true)
        let etcDir = profileRoot.appendingPathComponent("etc", isDirectory: true)
        try fm.createDirectory(at: etcDir, withIntermediateDirectories: true)
        let configured = configDir.appendingPathComponent("aiplayerbot.conf")
        let runtime = etcDir.appendingPathComponent("aiplayerbot.conf")

        if fm.fileExists(atPath: configured.path) {
            // SYSCONFDIR is ../etc/ for CMaNGOS when mangosd runs from profile/bin.
            // Always synchronize before launch so GUI settings and runtime cannot diverge.
            if fm.fileExists(atPath: runtime.path) { try fm.removeItem(at: runtime) }
            try fm.copyItem(at: configured, to: runtime)
        } else if !fm.fileExists(atPath: runtime.path) {
            throw err("PlayerBots runtime config is missing. Run PlayerBots → Populate / Repair World once.")
        }
    }''',
'''    private func ensurePlayerBotRuntimeConfig() throws {
        guard playerBotsSupported && playerBotsReady else { return }
        let fm = FileManager.default
        let configDir = profileRoot.appendingPathComponent("configs", isDirectory: true)
        let configured: URL
        let runtime: URL
        if selectedExpansion == .wotlk {
            let modulesDir = profileRoot.appendingPathComponent("etc/modules", isDirectory: true)
            try fm.createDirectory(at: modulesDir, withIntermediateDirectories: true)
            configured = configDir.appendingPathComponent("playerbots.conf")
            runtime = modulesDir.appendingPathComponent("playerbots.conf")
        } else {
            let etcDir = profileRoot.appendingPathComponent("etc", isDirectory: true)
            try fm.createDirectory(at: etcDir, withIntermediateDirectories: true)
            configured = configDir.appendingPathComponent("aiplayerbot.conf")
            runtime = etcDir.appendingPathComponent("aiplayerbot.conf")
        }
        if fm.fileExists(atPath: configured.path) {
            if fm.fileExists(atPath: runtime.path) { try fm.removeItem(at: runtime) }
            try fm.copyItem(at: configured, to: runtime)
        } else if !fm.fileExists(atPath: runtime.path) {
            throw err("PlayerBots runtime config is missing. Run PlayerBots → Populate / Repair World once.")
        }
    }''')

replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''        let timeoutSeconds = selectedExpansion == .tbc ? 900 : 30''',
'''        let timeoutSeconds = playerBotsReady ? 900 : 30''')
replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''            if selectedExpansion == .tbc && tick % 4 == 0 {''',
'''            if playerBotsReady && tick % 4 == 0 {''')
replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''        if selectedExpansion == .tbc {''',
'''        if playerBotsReady {''', count=1)

replace('Sources/WoWServerControlCenter/ServerModel.swift',
'''    func refreshPlayerBotStats() {
        guard selectedExpansion == .tbc else {
            playerBotAccountsLive = 0; playerBotCharactersLive = 0; playerBotsOnlineLive = 0
            playerBotStatsStatus = "TBC only"
            return
        }
        do {
            let client = try dbClient()
            let accountsText = try client.query(database: authDatabaseName, sql: "SELECT COUNT(*) FROM account WHERE UPPER(username) LIKE 'RNDBOT%';")
            let charsText = try client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM characters c JOIN \(authDatabaseName).account a ON a.id=c.account WHERE UPPER(a.username) LIKE 'RNDBOT%';")
            let onlineText = try client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM characters c JOIN \(authDatabaseName).account a ON a.id=c.account WHERE UPPER(a.username) LIKE 'RNDBOT%' AND c.online=1;")
            playerBotAccountsLive = Int(accountsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            playerBotCharactersLive = Int(charsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            playerBotsOnlineLive = Int(onlineText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let runtimeConf = profileRoot.appendingPathComponent("etc/aiplayerbot.conf")
            let configuredConf = profileRoot.appendingPathComponent("configs/aiplayerbot.conf")
            let runtimeText = try? String(contentsOf: runtimeConf, encoding: .utf8)
            let configuredText = try? String(contentsOf: configuredConf, encoding: .utf8)
            let enabledPattern = #"(?m)^\s*AiPlayerbot\.Enabled\s*=\s*1\s*$"#
            playerBotRuntimeConfigOK =
                runtimeText?.range(of: enabledPattern, options: .regularExpression) != nil ||
                configuredText?.range(of: enabledPattern, options: .regularExpression) != nil
            let migrationText = try? client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM wowcc_playerbots_migrations;")
            playerBotModuleSQLCount = Int(migrationText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
            if !playerBotRuntimeConfigOK {
                playerBotStatsStatus = "Runtime config missing"
            } else if playerBotModuleSQLCount == 0 {
                playerBotStatsStatus = "PlayerBots SQL missing"
            } else if worldRunning && playerBotsOnlineLive == 0 {
                playerBotStatsStatus = "Ready, but 0 online — initialize bots"
            } else {
                playerBotStatsStatus = worldRunning ? "LIVE" : "World stopped"
            }
        } catch {
            playerBotStatsStatus = "Stats unavailable"
        }
    }

    func initializePlayerBots() {
        guard selectedExpansion == .tbc else { statusMessage = "PlayerBots initialization is TBC only."; return }
        guard worldRunning || world?.isRunning == true else { statusMessage = "Start World Server first."; return }

        // One-shot initialization only. Do NOT immediately issue rndbot update:
        // the random-bot manager already performs its own scheduled updates and
        // forcing an update after init can cause unnecessary population churn.
        statusMessage = "Initializing random PlayerBots once…"
        sendAdminCommand("rndbot init", success: "PlayerBots one-time initialization requested")
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { self.refreshPlayerBotStats() }
    }''',
'''    func refreshPlayerBotStats() {
        guard playerBotsSupported else {
            playerBotAccountsLive = 0; playerBotCharactersLive = 0; playerBotsOnlineLive = 0
            playerBotStatsStatus = "TBC / WotLK only"
            return
        }
        do {
            let client = try dbClient()
            let accountsText = try client.query(database: authDatabaseName, sql: "SELECT COUNT(*) FROM account WHERE UPPER(username) LIKE 'RNDBOT%';")
            let charsText = try client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM characters c JOIN \(authDatabaseName).account a ON a.id=c.account WHERE UPPER(a.username) LIKE 'RNDBOT%';")
            let onlineText = try client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM characters c JOIN \(authDatabaseName).account a ON a.id=c.account WHERE UPPER(a.username) LIKE 'RNDBOT%' AND c.online=1;")
            playerBotAccountsLive = Int(accountsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            playerBotCharactersLive = Int(charsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            playerBotsOnlineLive = Int(onlineText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let runtimeConf = selectedExpansion == .wotlk
                ? profileRoot.appendingPathComponent("etc/modules/playerbots.conf")
                : profileRoot.appendingPathComponent("etc/aiplayerbot.conf")
            let configuredConf = selectedExpansion == .wotlk
                ? profileRoot.appendingPathComponent("configs/playerbots.conf")
                : profileRoot.appendingPathComponent("configs/aiplayerbot.conf")
            let runtimeText = try? String(contentsOf: runtimeConf, encoding: .utf8)
            let configuredText = try? String(contentsOf: configuredConf, encoding: .utf8)
            let enabledPattern = #"(?m)^\s*AiPlayerbot\.Enabled\s*=\s*1\s*$"#
            playerBotRuntimeConfigOK = runtimeText?.range(of: enabledPattern, options: .regularExpression) != nil || configuredText?.range(of: enabledPattern, options: .regularExpression) != nil
            let migrationText = try? client.query(database: characterDatabaseName, sql: "SELECT COUNT(*) FROM wowcc_playerbots_migrations;")
            playerBotModuleSQLCount = Int(migrationText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
            if !playerBotRuntimeConfigOK { playerBotStatsStatus = "Runtime config missing" }
            else if playerBotModuleSQLCount == 0 { playerBotStatsStatus = "PlayerBots SQL missing" }
            else if worldRunning && playerBotsOnlineLive == 0 { playerBotStatsStatus = "Ready, but 0 online — initialize bots" }
            else { playerBotStatsStatus = worldRunning ? "LIVE" : "World stopped" }
        } catch { playerBotStatsStatus = "Stats unavailable" }
    }

    func initializePlayerBots() {
        guard playerBotsSupported else { statusMessage = "PlayerBots are available for TBC and WotLK."; return }
        guard playerBotsReady else { statusMessage = "Populate / Repair PlayerBots first."; return }
        guard worldRunning || world?.isRunning == true else { statusMessage = "Start World Server first."; return }
        statusMessage = "Initializing \(selectedExpansion.shortTitle) random PlayerBots once…"
        let command = selectedExpansion == .wotlk ? "playerbots rndbot init" : "rndbot init"
        sendAdminCommand(command, success: "\(selectedExpansion.shortTitle) PlayerBots initialization requested")
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { self.refreshPlayerBotStats() }
    }''')

# -----------------------------------------------------------------------------
# ContentView: TBC + WotLK UI, 10..5000, default remains 150.
# -----------------------------------------------------------------------------
replace('Sources/WoWServerControlCenter/ContentView.swift',
'''                    Text("Populate TBC with AI adventurers that quest, group, form guilds and join PvP.").foregroundStyle(.secondary)''',
'''                    Text(model.selectedExpansion == .wotlk ? "Populate WotLK with AI adventurers that quest, group, raid and join PvP." : "Populate TBC with AI adventurers that quest, group, form guilds and join PvP.").foregroundStyle(.secondary)''')
replace('Sources/WoWServerControlCenter/ContentView.swift',
'''            if model.selectedExpansion != .tbc {
                GroupBox("TBC PlayerBots") { Text("Select The Burning Crusade in Expansion Manager. WoWCC currently enables the official CMaNGOS PlayerBots module for TBC.").foregroundStyle(.secondary).padding(8) }
            } else {''',
'''            if !model.playerBotsSupported {
                GroupBox("PlayerBots") { Text("Select The Burning Crusade or Wrath of the Lich King. WoWCC manages CMaNGOS PlayerBots for TBC and mod-playerbots for WotLK.").foregroundStyle(.secondary).padding(8) }
            } else {''')
replace('Sources/WoWServerControlCenter/ContentView.swift',
'''                    statusCard("Core Module",model.profileInstalled,"BUILD_PLAYERBOTS=ON")''',
'''                    statusCard("Core Module",model.profileInstalled,model.selectedExpansion == .wotlk ? "AzerothCore Playerbot fork + mod-playerbots" : "BUILD_PLAYERBOTS=ON")''')
replace('Sources/WoWServerControlCenter/ContentView.swift',
'''                            ForEach([250,500,1000,2000,5000], id: \.self) { count in''',
'''                            ForEach([50,150,250,500,1000,2000,3000,5000], id: \.self) { count in''')
replace('Sources/WoWServerControlCenter/ContentView.swift',
'''                        Text("Rebuild the TBC core once to compile the official PlayerBots module, then populate the existing realm database and config.").foregroundStyle(.secondary)''',
'''                        Text(model.selectedExpansion == .wotlk ? "Rebuild WotLK once to switch to the compatible AzerothCore Playerbot fork and compile mod-playerbots, then populate its bot database/config. Existing WoWCC realm/client data is preserved." : "Rebuild the TBC core once to compile the official PlayerBots module, then populate the existing realm database and config.").foregroundStyle(.secondary)''')
replace('Sources/WoWServerControlCenter/ContentView.swift',
'''                        Text("After Populate / Repair World, restart World Server. First PlayerBots startup can be heavy; WoWCC keeps mangosd alive, treats the process itself as authoritative during load, and automatically restarts World up to 3 times if it truly exits unexpectedly. Existing accounts and characters are preserved.").font(.caption).foregroundStyle(.secondary)''',
'''                        Text("After Populate / Repair World, restart World Server and initialize bots once. First startup can be heavy. WoWCC allows up to 5,000 configured bots, defaults to 150, and preserves existing player accounts/characters. Increase large populations gradually.").font(.caption).foregroundStyle(.secondary)''')

# -----------------------------------------------------------------------------
# Models / version / release notes.
# -----------------------------------------------------------------------------
replace('Sources/WoWServerControlCenter/Models.swift',
'''        case .wotlk: return "AzerothCore"''',
'''        case .wotlk: return "AzerothCore Playerbot fork + mod-playerbots"''')
replace('Build.command','<key>CFBundleShortVersionString</key><string>1.5.85</string>','<key>CFBundleShortVersionString</key><string>1.5.86</string>')
replace('Build.command','<key>CFBundleVersion</key><string>1585</string>','<key>CFBundleVersion</key><string>1586</string>')

rn = ROOT / 'RELEASE-NOTES.md'
old = rn.read_text() if rn.exists() else ''
entry = '''# v1.5.86 — WotLK PlayerBots\n\n- Added managed WotLK PlayerBots using the compatible Playerbot AzerothCore fork plus `mod-playerbots`.\n- PlayerBots page now supports both TBC and WotLK.\n- Bot population range is 10–5,000 with a safe default of 150 and quick presets through 5,000.\n- Added WotLK `acore_playerbots` database bootstrap, repeatable SQL migrations, managed `playerbots.conf`, live bot counts, and one-click initialization.\n- WotLK PlayerBots setup logs are written to `playerbots-setup.log` and automatically appear in WoWCC Logs.\n- Existing WotLK realm/client data is preserved when rebuilding the compatible PlayerBots core.\n\n'''
if not old.startswith('# v1.5.86'):
    rn.write_text(entry + old)

print('1.5.86 WotLK PlayerBots patch complete')
