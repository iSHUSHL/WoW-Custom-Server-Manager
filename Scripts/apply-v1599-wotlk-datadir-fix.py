from pathlib import Path

server = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = server.read_text()

# Force WotLK DataDir in worldserver.conf alongside the DB self-heal.
anchor = '''        worldText = forcing(
            worldText,
            key: "CharacterDatabaseInfo",
            value: "127.0.0.1;\\(port);wowcc;wowcc;acore_characters"
        )
'''
if anchor in s and 'key: "DataDir"' not in s[s.find(anchor):s.find(anchor)+900]:
    s = s.replace(anchor, anchor + '''        worldText = forcing(
            worldText,
            key: "DataDir",
            value: profileRoot.appendingPathComponent("data").path
        )
''', 1)

# 1.5.97 already has a WotLK launch environment dictionary. Add DataDir there.
needle = '''                "AC_PLAYERBOTS_DATABASE_SYNCHTHREADS": "1"
'''
if 'AC_DATA_DIR' not in s:
    if needle not in s:
        raise SystemExit('Could not locate WotLK launch environment dictionary')
    s = s.replace(needle, '''                "AC_PLAYERBOTS_DATABASE_SYNCHTHREADS": "1",
                "AC_DATA_DIR": profileRoot.appendingPathComponent("data").path
''', 1)

server.write_text(s)

build = Path('Build.command')
b = build.read_text().replace('<string>1.5.98</string>', '<string>1.5.99</string>').replace('<string>1598</string>', '<string>1599</string>')
build.write_text(b)

notes = Path('RELEASE-NOTES.md')
n = notes.read_text()
header = '''# v1.5.99 — WotLK Absolute DataDir Fix\n\n- Fixes WotLK World startup using `DataDir ./` while WoWCC client data lives in the managed profile `data` directory.\n- Self-heals `worldserver.conf` DataDir to the absolute managed WotLK data path before every start.\n- Also passes AzerothCore `AC_DATA_DIR` at launch so stale/default relative paths cannot override the managed data location.\n- Keeps the PlayerBots DB bootstrap and port fixes from 1.5.98.\n\n'''
if not n.startswith('# v1.5.99'):
    notes.write_text(header+n)

print('Applied v1.5.99 WotLK DataDir fix')
