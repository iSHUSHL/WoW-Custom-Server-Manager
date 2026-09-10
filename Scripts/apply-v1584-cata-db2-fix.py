from pathlib import Path

# ---- ServerModel.swift ----
p = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = p.read_text()

old = '''    var requiredClientDataDirectories: [String] {
        switch selectedExpansion {
        case .wotlk: return ["dbc","maps","vmaps","mmaps"]
        case .vanilla, .tbc, .cataclysm, .mop: return ["dbc","maps","vmaps"]
        default: return []
        }
    }
'''
new = '''    var requiredClientDataDirectories: [String] {
        switch selectedExpansion {
        case .wotlk: return ["dbc","maps","vmaps","mmaps"]
        case .cataclysm: return ["dbc","db2","maps","vmaps"]
        case .vanilla, .tbc, .mop: return ["dbc","maps","vmaps"]
        default: return []
        }
    }
'''
if old not in s: raise SystemExit('requiredClientDataDirectories marker not found')
s = s.replace(old, new, 1)

old = '''    private var worldDatabaseName: String {
        switch selectedExpansion {
        case .wotlk: return "acore_world"
        case .vanilla, .tbc: return "mangos"
        default: return "world"
        }
    }
'''
new = '''    private var worldDatabaseName: String {
        switch selectedExpansion {
        case .wotlk: return "acore_world"
        case .vanilla, .tbc: return "mangos"
        default: return "world"
        }
    }
    private var catalogTableName: String {
        selectedExpansion == .cataclysm ? "wowcc_item_template" : "item_template"
    }
'''
if old not in s: raise SystemExit('worldDatabaseName marker not found')
s = s.replace(old, new, 1)

# Inventory name lookup.
s = s.replace('''let nr = try client.query(database: worldDB, sql: "SELECT entry,name FROM item_template WHERE entry IN (\\(list));")''', '''let nr = try client.query(database: worldDB, sql: "SELECT entry,name FROM \\(catalogTableName) WHERE entry IN (\\(list));")''', 1)

# Tooltip query needs stable table snapshot before background operation.
old = '''        let expansion = selectedExpansion
        let database = worldDatabaseName
        let port = mysqlPort
'''
new = '''        let expansion = selectedExpansion
        let database = worldDatabaseName
        let table = catalogTableName
        let port = mysqlPort
'''
if old not in s: raise SystemExit('tooltip snapshot marker not found')
s = s.replace(old, new, 1)
s = s.replace('''let columnRaw = try client.query(database: database, sql: "SHOW COLUMNS FROM item_template;")''', '''let columnRaw = try client.query(database: database, sql: "SHOW COLUMNS FROM \\(table);")''', 1)
s = s.replace('''let rowRaw = try client.query(database: database, sql: "SELECT * FROM item_template WHERE entry=\\(id) LIMIT 1;")''', '''let rowRaw = try client.query(database: database, sql: "SELECT * FROM \\(table) WHERE entry=\\(id) LIMIT 1;")''', 1)

# Catalog query uses selected era table.
old = '''        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let db = worldDatabaseName
        guard let mysqlExecutable = locateMySQL("mysql") else {
'''
new = '''        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let db = worldDatabaseName
        let table = catalogTableName
        guard let mysqlExecutable = locateMySQL("mysql") else {
'''
if old not in s: raise SystemExit('catalog table snapshot marker not found')
s = s.replace(old, new, 1)
s = s.replace('''let columnRaw = try client.query(database: db, sql: "SHOW COLUMNS FROM item_template;")''', '''let columnRaw = try client.query(database: db, sql: "SHOW COLUMNS FROM \\(table);")''', 1)
s = s.replace('''let totalTableRaw = try client.query(database: db, sql: "SELECT COUNT(*) FROM item_template;")''', '''let totalTableRaw = try client.query(database: db, sql: "SELECT COUNT(*) FROM \\(table);")''', 1)
s = s.replace('''let countSQL = "SELECT COUNT(*) FROM item_template WHERE \\(whereClause);"''', '''let countSQL = "SELECT COUNT(*) FROM \\(table) WHERE \\(whereClause);"''', 1)
s = s.replace('''                FROM item_template
                WHERE \\(whereClause)''', '''                FROM \\(table)
                WHERE \\(whereClause)''', 1)

# Gear sets use selected era catalog table.
old = '''        let db = worldDatabaseName
        let port = mysqlPort
        let expansion = selectedExpansion
'''
new = '''        let db = worldDatabaseName
        let table = catalogTableName
        let port = mysqlPort
        let expansion = selectedExpansion
'''
if old not in s: raise SystemExit('gear set snapshot marker not found')
s = s.replace(old, new, 1)
s = s.replace('''                FROM item_template
                WHERE itemset > 0 AND \\(expansionClause)''', '''                FROM \\(table)
                WHERE itemset > 0 AND \\(expansionClause)''', 1)

# Cata readiness is not WotLK-style item_template; WoWCC builds a DB2 catalog table.
old = '''        case .cataclysm, .mop:
            requiredTables = [
                ("auth","account"),
                ("auth","realmlist"),
                ("characters","characters"),
                ("world","item_template"),
                ("world","creature_template")
            ]
'''
new = '''        case .cataclysm:
            requiredTables = [
                ("auth","account"),
                ("auth","realmlist"),
                ("characters","characters"),
                ("world","creature_template"),
                ("world","wowcc_item_template")
            ]
        case .mop:
            requiredTables = [
                ("auth","account"),
                ("auth","realmlist"),
                ("characters","characters"),
                ("world","item_template"),
                ("world","creature_template")
            ]
'''
if old not in s: raise SystemExit('background cata/mop readiness marker not found')
s = s.replace(old, new, 1)

p.write_text(s)

# ---- setup-community-trinity.sh ----
sp = Path('Scripts/setup-community-trinity.sh')
ss = sp.read_text()

old = '''log "Creating isolated auth / characters / world schemas…"
"${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
'''
new = '''log "Creating isolated auth / characters / world schemas…"
"${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS auth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS characters CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE DATABASE IF NOT EXISTS world CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
if [[ "$PROFILE" == "cataclysm" ]]; then
  log "Creating Cataclysm hotfixes schema…"
  "${M[@]}" -e 'CREATE DATABASE IF NOT EXISTS hotfixes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
fi
'''
if old not in ss: raise SystemExit('schema create marker not found')
ss = ss.replace(old, new, 1)

old = '''has_table auth account || import_first_match auth '*auth*.sql'
has_table auth account || import_first_match auth '*login*.sql'
has_table characters characters || import_first_match characters '*characters*.sql'

# World content is published as a release database by both community projects.
if ! has_table world creature_template || ! has_table world item_template; then
'''
new = '''has_table auth account || import_first_match auth '*auth*.sql'
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
'''
if old not in ss: raise SystemExit('world download condition marker not found')
ss = ss.replace(old, new, 1)

old = '''    repl={
      'LoginDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;auth',
      'AuthDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;auth',
      'WorldDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;world',
      'CharacterDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;characters',
    }
'''
new = '''    repl={
      'LoginDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;auth',
      'AuthDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;auth',
      'WorldDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;world',
      'CharacterDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;characters',
      'HotfixDatabaseInfo':f'127.0.0.1;{port};wowcc;wowcc;hotfixes',
    }
'''
if old not in ss: raise SystemExit('config repl marker not found')
ss = ss.replace(old, new, 1)

old = '''for spec in auth.account auth.realmlist characters.characters world.item_template world.creature_template; do
  db="${spec%%.*}"; table="${spec#*.}"
  has_table "$db" "$table" || fail "Database bootstrap incomplete: missing $spec"
done

world_items="$("${M[@]}" --batch --skip-column-names world -e "SELECT COUNT(*) FROM item_template;" 2>/dev/null || echo 0)"
log "Catalog health: items=$world_items"
if (( ${world_items:-0} < 10000 )); then
  fail "$LABEL world DB is incomplete: world.item_template has only $world_items rows. Remove the downloaded database cache in Storage & Cleanup, then run Repair Realm again so WoWCC downloads/imports a full database release."
fi
'''
new = '''if [[ "$PROFILE" == "cataclysm" ]]; then
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
'''
if old not in ss: raise SystemExit('community validation marker not found')
ss = ss.replace(old, new, 1)
sp.write_text(ss)

# ---- Build version ----
b = Path('Build.command')
bs = b.read_text()
if '<string>1.5.83</string>' not in bs: raise SystemExit('1.5.83 version marker missing')
bs = bs.replace('<string>1.5.83</string>', '<string>1.5.84</string>', 1)
bs = bs.replace('<string>1583</string>', '<string>1584</string>', 1)
b.write_text(bs)

# ---- Release notes ----
rn = Path('RELEASE-NOTES.md')
notes = rn.read_text() if rn.exists() else ''
header = '''# v1.5.84 — Cataclysm DB2 Realm + Catalog Fix\n\n- Fixes Cataclysm Repair Realm incorrectly requiring the WotLK-only `world.item_template`.\n- Creates/configures the Cataclysm `hotfixes` database required by the 4.3.4 Trinity branch.\n- Adds `HotfixDatabaseInfo` to the managed Cata worldserver configuration.\n- Requires/copies Cata `db2` client data as part of client-data readiness.\n- Builds a full WoWCC Cataclysm catalog table from `Item.db2` and `Item-sparse.db2`.\n- Collection Browser, Gear Sets, inventory names and tooltips use the generated Cata catalog while TBC/WotLK/MoP keep their existing tables.\n- Preserves the restored pre-premium UI and tooltip auto-fit.\n\n'''
if not notes.startswith('# v1.5.84'):
    rn.write_text(header + notes)
