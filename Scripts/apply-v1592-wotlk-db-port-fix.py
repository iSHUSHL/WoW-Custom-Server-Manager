from pathlib import Path
import re

root = Path('.')
server = root / 'Sources/WoWServerControlCenter/ServerModel.swift'
s = server.read_text()

old = '''    private func repairCMaNGOSDatabaseConfigIfNeeded() throws {\n        guard selectedExpansion.serverFamily == .cmangos else { return }\n'''
new = '''    private func repairCMaNGOSDatabaseConfigIfNeeded() throws {\n        if selectedExpansion == .wotlk {\n            let fm = FileManager.default\n            let configs = [\n                profileRoot.appendingPathComponent("configs/authserver.conf"),\n                profileRoot.appendingPathComponent("configs/worldserver.conf")\n            ]\n            let databaseInfo: [(String, String)] = [\n                ("LoginDatabaseInfo", "acore_auth"),\n                ("WorldDatabaseInfo", "acore_world"),\n                ("CharacterDatabaseInfo", "acore_characters")\n            ]\n\n            for configURL in configs where fm.fileExists(atPath: configURL.path) {\n                var text = try String(contentsOf: configURL, encoding: .utf8)\n                for (key, database) in databaseInfo {\n                    let pattern = "(?m)^\\\\s*" + NSRegularExpression.escapedPattern(for: key) + "\\\\s*=.*$"\n                    let replacement = "\\(key) = \\\"127.0.0.1;\\(mysqlPort);wowcc;wowcc;\\(database)\\\""\n                    if let regex = try? NSRegularExpression(pattern: pattern) {\n                        let range = NSRange(text.startIndex..<text.endIndex, in: text)\n                        if regex.firstMatch(in: text, range: range) != nil {\n                            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)\n                        }\n                    }\n                }\n                try text.write(to: configURL, atomically: true, encoding: .utf8)\n            }\n            return\n        }\n\n        guard selectedExpansion.serverFamily == .cmangos else { return }\n'''
if old not in s:
    raise SystemExit('repairCMaNGOSDatabaseConfigIfNeeded anchor not found')
s = s.replace(old, new, 1)

s = s.replace('    func startAuth() throws { try startBinary(authBinaryName, process: auth, interactive: false, confName: authConfName) }',
'''    func startAuth() throws {\n        try repairCMaNGOSDatabaseConfigIfNeeded()\n        try startBinary(authBinaryName, process: auth, interactive: false, confName: authConfName)\n    }''', 1)
s = s.replace('    func startWorld() throws { try startBinary(worldBinaryName, process: world, interactive: true, confName: worldConfName) }',
'''    func startWorld() throws {\n        try repairCMaNGOSDatabaseConfigIfNeeded()\n        try startBinary(worldBinaryName, process: world, interactive: true, confName: worldConfName)\n    }''', 1)

server.write_text(s)

build = root / 'Build.command'
b = build.read_text()
b = b.replace('<string>1.5.91</string>', '<string>1.5.92</string>')
b = b.replace('<string>1591</string>', '<string>1592</string>')
build.write_text(b)

notes = root / 'RELEASE-NOTES.md'
n = notes.read_text()
notes.write_text('''# v1.5.92 — WotLK Managed MySQL Port Repair\n\n- Fixes WotLK world/auth startup attempting MySQL on port 3306 while WoWCC managed MySQL listens on 3307.\n- Auth and World launch now self-heal AzerothCore database connection strings before every start and watchdog restart.\n- Keeps Login/World/Character database connections aligned with WoWCC managed MySQL credentials and port.\n\n''' + n)
