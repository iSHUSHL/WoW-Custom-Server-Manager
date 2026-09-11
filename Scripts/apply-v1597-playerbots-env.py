from pathlib import Path

p = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = p.read_text()
old = '''        try process.start(\n            executable: aliasBin,\n            arguments: arguments,\n            currentDirectory: aliasProfile.appendingPathComponent("bin"),\n            interactive: interactive\n        )\n'''
new = '''        var environment: [String: String]? = nil\n        if selectedExpansion == .wotlk && name == "worldserver" {\n            environment = [\n                "AC_PLAYERBOTS_DATABASE_INFO": "127.0.0.1;\\(mysqlPort);wowcc;wowcc;acore_playerbots",\n                "AC_PLAYERBOTS_DATABASE_WORKERTHREADS": "1",\n                "AC_PLAYERBOTS_DATABASE_SYNCHTHREADS": "1"\n            ]\n        }\n\n        try process.start(\n            executable: aliasBin,\n            arguments: arguments,\n            currentDirectory: aliasProfile.appendingPathComponent("bin"),\n            environment: environment,\n            interactive: interactive\n        )\n'''
if old not in s:
    raise SystemExit('startBinary process.start block not found')
s = s.replace(old, new, 1)
p.write_text(s)

b = Path('Build.command')
bt = b.read_text().replace('<string>1.5.96</string>','<string>1.5.97</string>').replace('<string>1596</string>','<string>1597</string>')
b.write_text(bt)

rn = Path('RELEASE-NOTES.md')
r = rn.read_text()
rn.write_text('''# v1.5.97 — WotLK PlayerBots DB Environment Override\n\n- Forces the PlayerBots database connection through AzerothCore's highest-priority `AC_PLAYERBOTS_DATABASE_INFO` environment override.\n- World Server now receives `127.0.0.1;3307;wowcc;wowcc;acore_playerbots` directly at process launch.\n- Also pins PlayerBots DB worker/sync threads to 1.\n- This bypasses any stale worldserver/module config that still contains port 3306.\n- Keeps the clean in-app titlebar from 1.5.95.\n\n''' + r)
