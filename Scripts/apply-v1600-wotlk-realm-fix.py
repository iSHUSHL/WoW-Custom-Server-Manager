from pathlib import Path

server = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = server.read_text()

anchor = '''    private func waitForWorldReadyPlayerBotsAware() async throws {\n'''
if anchor not in s:
    raise SystemExit('waitForWorldReadyPlayerBotsAware anchor not found')

if 'private func repairWotLKRealmRegistration() throws' not in s:
    func = r'''    private func repairWotLKRealmRegistration() throws {
        guard selectedExpansion == .wotlk else { return }

        let client = try dbClient()
        // Keep WotLK realm registration isolated in AzerothCore's auth DB.
        // Old CMaNGOS/MaNGOS rows must never leak into the WotLK realm list.
        try client.execute(
            database: "acore_auth",
            sql: "DELETE FROM realmlist WHERE id <> 1 AND LOWER(name) LIKE '%mangos%';"
        )
        try client.execute(
            database: "acore_auth",
            sql: """
            INSERT INTO realmlist
                (id,name,address,localAddress,localSubnetMask,port,icon,flag,timezone,allowedSecurityLevel,population,gamebuild)
            VALUES
                (1,'WoWCC WotLK','127.0.0.1','127.0.0.1','255.255.255.0',8085,0,0,1,0,0,12340)
            ON DUPLICATE KEY UPDATE
                name=VALUES(name),
                address=VALUES(address),
                localAddress=VALUES(localAddress),
                localSubnetMask=VALUES(localSubnetMask),
                port=VALUES(port),
                icon=VALUES(icon),
                flag=0,
                timezone=VALUES(timezone),
                allowedSecurityLevel=0,
                population=0,
                gamebuild=12340;
            """
        )

        let logURL = logs.appendingPathComponent("realm-registration.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\\(stamp)] WotLK realm repaired: id=1 name=WoWCC WotLK address=127.0.0.1 port=8085 flag=0 build=12340\\n"
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: logURL.path), let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

'''
    s = s.replace(anchor, func + anchor, 1)

# Start All: repair after DB readiness is proven, before authserver starts.
needle = '''                realmDatabaseReady = probeRealmDatabaseReady()\n                guard realmDatabaseReady else {\n                    throw err("Realm database is not ready. Run Setup / Repair Realm first and wait for REALM DATABASE READY.")\n                }\n\n                statusMessage = "Checking DBC/maps/vmaps/mmaps…"\n'''
repl = '''                realmDatabaseReady = probeRealmDatabaseReady()\n                guard realmDatabaseReady else {\n                    throw err("Realm database is not ready. Run Setup / Repair Realm first and wait for REALM DATABASE READY.")\n                }\n                try repairWotLKRealmRegistration()\n\n                statusMessage = "Checking DBC/maps/vmaps/mmaps…"\n'''
if needle not in s:
    raise SystemExit('startAll realm readiness block not found')
s = s.replace(needle, repl, 1)

# Direct World start also keeps realm registration healthy.
needle = '''                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL must be running before World Server.") }\n                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }\n                try validateClientDataForStart()\n'''
repl = '''                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL must be running before World Server.") }\n                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }\n                try repairWotLKRealmRegistration()\n                try validateClientDataForStart()\n'''
if needle not in s:
    raise SystemExit('startWorldServer realm readiness block not found')
s = s.replace(needle, repl, 1)

# Direct Auth/Realm start must repair before authserver exposes the list.
needle = '''                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL must be running before Realm Server.") }\n                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }\n                if !portOpen(authPort) {\n'''
repl = '''                guard portOpen(Int32(mysqlPort)) else { throw err("MySQL must be running before Realm Server.") }\n                guard realmDatabaseReady || probeRealmDatabaseReady() else { throw err("Realm database is not ready.") }\n                try repairWotLKRealmRegistration()\n                if !portOpen(authPort) {\n'''
if needle not in s:
    raise SystemExit('startRealmServer realm readiness block not found')
s = s.replace(needle, repl, 1)

server.write_text(s)

# Make Setup / Repair Realm reset every realm-status field, not only name/address.
setup = Path('Scripts/setup-profile.sh')
t = setup.read_text()
old = '''  "${M[@]}" acore_auth -e "INSERT INTO realmlist (id,name,address,localAddress,localSubnetMask,port,icon,flag,timezone,allowedSecurityLevel,population,gamebuild) VALUES (1,'WoW Control Center','127.0.0.1','127.0.0.1','255.255.255.0',8085,0,0,1,0,0,12340) ON DUPLICATE KEY UPDATE name=VALUES(name),address=VALUES(address),localAddress=VALUES(localAddress),port=VALUES(port),gamebuild=VALUES(gamebuild);"\n'''
new = '''  "${M[@]}" acore_auth -e "DELETE FROM realmlist WHERE id <> 1 AND LOWER(name) LIKE '%mangos%'; INSERT INTO realmlist (id,name,address,localAddress,localSubnetMask,port,icon,flag,timezone,allowedSecurityLevel,population,gamebuild) VALUES (1,'WoWCC WotLK','127.0.0.1','127.0.0.1','255.255.255.0',8085,0,0,1,0,0,12340) ON DUPLICATE KEY UPDATE name=VALUES(name),address=VALUES(address),localAddress=VALUES(localAddress),localSubnetMask=VALUES(localSubnetMask),port=VALUES(port),icon=0,flag=0,timezone=VALUES(timezone),allowedSecurityLevel=0,population=0,gamebuild=12340;"\n'''
if old not in t:
    raise SystemExit('setup-profile WotLK realmlist SQL not found')
setup.write_text(t.replace(old, new, 1))

build = Path('Build.command')
b = build.read_text().replace('<string>1.5.99</string>', '<string>1.6.0</string>').replace('<string>1599</string>', '<string>1600</string>')
build.write_text(b)

notes = Path('RELEASE-NOTES.md')
n = notes.read_text()
header = '''# v1.6.0 — WotLK Realm Registration Fix\n\n- Repairs `acore_auth.realmlist` automatically before WotLK Auth/World startup.\n- Forces realm ID 1 to `WoWCC WotLK`, port 8085, build 12340, `flag=0` (enabled), and security level 0.\n- Removes stale MaNGOS-named rows from the WotLK AzerothCore auth database only; Vanilla/TBC realm databases are untouched.\n- Setup / Repair Realm now resets all realm status fields so an old disabled flag cannot survive.\n- Adds `realm-registration.log`, visible automatically in WoWCC Logs.\n\n'''
if not n.startswith('# v1.6.0'):
    notes.write_text(header+n)

print('Applied v1.6.0 WotLK realm registration fix')
