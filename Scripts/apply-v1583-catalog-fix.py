from pathlib import Path

p = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = p.read_text()

old = '''        let whereClause = catalogWhereClause(kind: kind, search: q)
        let offset = page * pageSize
        let countSQL = "SELECT COUNT(*) FROM item_template WHERE \\(whereClause);"
        let sql = """
        SELECT entry,name,Quality,class,subclass,InventoryType,ItemLevel,itemset,AllowableClass
        FROM item_template
        WHERE \\(whereClause)
        ORDER BY ItemLevel DESC, Quality DESC, name, entry
        LIMIT \\(pageSize) OFFSET \\(offset);
        """
'''
new = '''        let whereClause = catalogWhereClause(kind: kind, search: q)
        let offset = page * pageSize
'''
if old not in s:
    raise SystemExit('catalog SQL block not found')
s = s.replace(old, new, 1)

old2 = '''                let client = DatabaseClient(executable: mysqlExecutable, port: port)
                let totalRaw = try client.query(database: db, sql: countSQL)
                let total = Int(totalRaw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                let raw = try client.query(database: db, sql: sql)
'''
new2 = '''                let client = DatabaseClient(executable: mysqlExecutable, port: port)

                // Different emulator families/eras use slightly different item_template
                // column spelling/casing. Resolve the live schema first and project a
                // stable nine-column catalog shape instead of assuming one exact schema.
                let columnRaw = try client.query(database: db, sql: "SHOW COLUMNS FROM item_template;")
                let liveColumns = columnRaw.split(separator: "\\n").compactMap { line -> String? in
                    line.split(separator: "\\t", omittingEmptySubsequences: false).first.map(String.init)
                }
                let columnMap = Dictionary(uniqueKeysWithValues: liveColumns.map { ($0.lowercased(), $0) })
                func col(_ candidates: [String], fallback: String) -> String {
                    for candidate in candidates {
                        if let actual = columnMap[candidate.lowercased()] { return "`\\(actual)`" }
                    }
                    return fallback
                }

                let entryCol = col(["entry"], fallback: "0")
                let nameCol = col(["name","name1"], fallback: "''")
                let qualityCol = col(["Quality","quality"], fallback: "1")
                let classCol = col(["class"], fallback: "0")
                let subclassCol = col(["subclass"], fallback: "0")
                let inventoryCol = col(["InventoryType","inventorytype"], fallback: "0")
                let levelCol = col(["ItemLevel","itemlevel"], fallback: "0")
                let setCol = col(["itemset","ItemSet"], fallback: "0")
                let allowableClassCol = col(["AllowableClass","allowableclass"], fallback: "-1")

                guard entryCol != "0" else {
                    throw NSError(domain: "WoWCC.Catalog", code: 2, userInfo: [NSLocalizedDescriptionKey: "item_template has no entry column in \\(db)"])
                }

                let totalTableRaw = try client.query(database: db, sql: "SELECT COUNT(*) FROM item_template;")
                let totalTableItems = Int(totalTableRaw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                guard totalTableItems >= 1000 else {
                    throw NSError(domain: "WoWCC.Catalog", code: 3, userInfo: [NSLocalizedDescriptionKey: "\\(db).item_template contains only \\(totalTableItems) rows. Run Repair Realm to restore the full world database."])
                }

                // Existing filter SQL uses the common canonical names. All supported
                // realm schemas currently expose those names case-insensitively; schema
                // projection below handles display/select differences safely.
                let countSQL = "SELECT COUNT(*) FROM item_template WHERE \\(whereClause);"
                let sql = """
                SELECT \\(entryCol),\\(nameCol),\\(qualityCol),\\(classCol),\\(subclassCol),\\(inventoryCol),\\(levelCol),\\(setCol),\\(allowableClassCol)
                FROM item_template
                WHERE \\(whereClause)
                ORDER BY \\(levelCol) DESC, \\(qualityCol) DESC, \\(nameCol), \\(entryCol)
                LIMIT \\(pageSize) OFFSET \\(offset);
                """

                let totalRaw = try client.query(database: db, sql: countSQL)
                let total = Int(totalRaw.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                let raw = try client.query(database: db, sql: sql)
'''
if old2 not in s:
    raise SystemExit('catalog query execution block not found')
s = s.replace(old2, new2, 1)

old3 = '''                    self.catalogLoading = false
                    self.serverCatalog = BuiltInCatalog.entries(for: self.selectedExpansion)
                    self.catalogHasMore = false
                    self.catalogStatus = "Could not read selected realm DB — showing same-expansion examples only. \\(error.localizedDescription)"
                    self.statusMessage = self.catalogStatus
'''
new3 = '''                    self.catalogLoading = false
                    self.serverCatalog = []
                    self.catalogHasMore = false
                    self.catalogStatus = "Catalog database error: \\(error.localizedDescription)"
                    self.statusMessage = self.catalogStatus
                    self.appendCatalogDiagnostic("[catalog:\\(self.selectedExpansion.rawValue)] \\(error.localizedDescription)")
'''
if old3 not in s:
    raise SystemExit('catalog catch block not found')
s = s.replace(old3, new3, 1)

insert_before = '''    func loadMountCollection(resetFilters: Bool = false) {
'''
helper = '''    private func appendCatalogDiagnostic(_ message: String) {
        let url = logs.appendingPathComponent("catalog.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\\(stamp)] \\(message)\\n"
        do {
            try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path), let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            } else {
                try Data(line.utf8).write(to: url, options: .atomic)
            }
        } catch { }
    }

'''
if insert_before not in s:
    raise SystemExit('mount marker not found')
s = s.replace(insert_before, helper + insert_before, 1)
p.write_text(s)

# Strengthen WotLK DB validation: item_template existence is not enough.
sp = Path('Scripts/setup-profile.sh')
ss = sp.read_text()
needle = '''  for spec in "${required[@]}"; do
    db="${spec%%.*}"; table="${spec#*.}"
    count="$("${M[@]}" --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';" 2>/dev/null || echo 0)"
    [[ "$count" == "1" ]] || { echo "ERROR: Database bootstrap incomplete: missing ${spec}" >&2; exit 33; }
  done

  # Ensure the local realm exists and points back to this Mac.
'''
replace = '''  for spec in "${required[@]}"; do
    db="${spec%%.*}"; table="${spec#*.}"
    count="$("${M[@]}" --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}' AND table_name='${table}';" 2>/dev/null || echo 0)"
    [[ "$count" == "1" ]] || { echo "ERROR: Database bootstrap incomplete: missing ${spec}" >&2; exit 33; }
  done

  wotlk_items="$("${M[@]}" --batch --skip-column-names acore_world -e "SELECT COUNT(*) FROM item_template;" 2>/dev/null || echo 0)"
  echo "[realm:wotlk] Catalog health: items=$wotlk_items"
  if (( ${wotlk_items:-0} < 10000 )); then
    echo "ERROR: WotLK world DB is incomplete: acore_world.item_template has only $wotlk_items rows." >&2
    echo "ERROR: Re-run Repair Realm after clearing the incomplete world DB/database cache if dbimport cannot restore it." >&2
    exit 36
  fi

  # Ensure the local realm exists and points back to this Mac.
'''
if needle not in ss:
    raise SystemExit('wotlk verify marker not found')
ss = ss.replace(needle, replace, 1)
sp.write_text(ss)

cp = Path('Scripts/setup-community-trinity.sh')
cs = cp.read_text()
needle2 = '''for spec in auth.account auth.realmlist characters.characters world.item_template world.creature_template; do
  db="${spec%%.*}"; table="${spec#*.}"
  has_table "$db" "$table" || fail "Database bootstrap incomplete: missing $spec"
done

# Existing community DBs normally ship a realmlist row.
'''
replace2 = '''for spec in auth.account auth.realmlist characters.characters world.item_template world.creature_template; do
  db="${spec%%.*}"; table="${spec#*.}"
  has_table "$db" "$table" || fail "Database bootstrap incomplete: missing $spec"
done

world_items="$("${M[@]}" --batch --skip-column-names world -e "SELECT COUNT(*) FROM item_template;" 2>/dev/null || echo 0)"
log "Catalog health: items=$world_items"
if (( ${world_items:-0} < 10000 )); then
  fail "$LABEL world DB is incomplete: world.item_template has only $world_items rows. Remove the downloaded database cache in Storage & Cleanup, then run Repair Realm again so WoWCC downloads/imports a full database release."
fi

# Existing community DBs normally ship a realmlist row.
'''
if needle2 not in cs:
    raise SystemExit('community verify marker not found')
cs = cs.replace(needle2, replace2, 1)
cp.write_text(cs)

b = Path('Build.command')
bs = b.read_text()
bs = bs.replace('<string>1.5.80</string>', '<string>1.5.83</string>', 1)
bs = bs.replace('<string>1580</string>', '<string>1583</string>', 1)
b.write_text(bs)

rn = Path('RELEASE-NOTES.md')
notes = rn.read_text() if rn.exists() else ''
header = '''# v1.5.83 — WotLK / Cata / MoP Catalog Recovery\n\n- Adds live item_template schema introspection so Collection Browser no longer assumes one exact emulator column spelling/casing.\n- Rejects suspiciously empty world catalogs instead of silently showing zero items or tiny examples.\n- Adds catalog.log diagnostics, automatically visible in the WoWCC Logs UI.\n- WotLK Setup/Repair now validates acore_world.item_template row count after dbimport.\n- Cataclysm/MoP Setup/Repair now validates world.item_template row count after community DB import.\n- Keeps the restored pre-premium 1.5.80 UI and tooltip auto-fit behavior.\n\n'''
if not notes.startswith('# v1.5.83'):
    rn.write_text(header + notes)
