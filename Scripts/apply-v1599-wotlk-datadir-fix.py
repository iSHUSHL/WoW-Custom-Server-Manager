from pathlib import Path
import re

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
    replacement = anchor + '''        worldText = forcing(
            worldText,
            key: "DataDir",
            value: profileRoot.appendingPathComponent("data").path
        )
'''
    s = s.replace(anchor, replacement, 1)

# Ensure startBinary explicitly passes AzerothCore DataDir through the environment.
# 1.5.97 already creates launchEnvironment for the PlayerBots DB override.
if 'AC_PLAYERBOTS_DATABASE_INFO' in s and 'AC_DATA_DIR' not in s:
    s = s.replace(
        'launchEnvironment["AC_PLAYERBOTS_DATABASE_INFO"] = "127.0.0.1;\\(mysqlPort);wowcc;wowcc;acore_playerbots"',
        'launchEnvironment["AC_PLAYERBOTS_DATABASE_INFO"] = "127.0.0.1;\\(mysqlPort);wowcc;wowcc;acore_playerbots"\n            launchEnvironment["AC_DATA_DIR"] = profileRoot.appendingPathComponent("data").path',
        1
    )

# Fallback: if launchEnvironment structure changed, inject before process.start.
if 'AC_DATA_DIR' not in s:
    needle = '''        try process.start(
            executable: aliasBin,
            arguments: arguments,
            currentDirectory: aliasProfile.appendingPathComponent("bin"),
'''
    if needle not in s:
        raise SystemExit('Could not locate startBinary process.start block')
    repl = '''        var wowccLaunchEnvironment: [String:String]? = nil
        if selectedExpansion == .wotlk && name == worldBinaryName {
            wowccLaunchEnvironment = [
                "AC_PLAYERBOTS_DATABASE_INFO": "127.0.0.1;\\(mysqlPort);wowcc;wowcc;acore_playerbots",
                "AC_DATA_DIR": profileRoot.appendingPathComponent("data").path
            ]
        }

        try process.start(
            executable: aliasBin,
            arguments: arguments,
            currentDirectory: aliasProfile.appendingPathComponent("bin"),
            environment: wowccLaunchEnvironment,
'''
    s = s.replace(needle, repl, 1)

# If an existing environment argument follows currentDirectory, avoid duplicate fallback arg.
s = s.replace('environment: wowccLaunchEnvironment,\n            environment: launchEnvironment,', 'environment: launchEnvironment ?? wowccLaunchEnvironment,')

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
