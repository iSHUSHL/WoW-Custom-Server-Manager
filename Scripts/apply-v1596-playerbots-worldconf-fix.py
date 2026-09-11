from pathlib import Path

server = Path('Sources/WoWServerControlCenter/ServerModel.swift')
s = server.read_text()
old = '''            let databaseInfo: [(String, String)] = [
                ("LoginDatabaseInfo", "acore_auth"),
                ("WorldDatabaseInfo", "acore_world"),
                ("CharacterDatabaseInfo", "acore_characters")
            ]
'''
new = '''            let databaseInfo: [(String, String)] = [
                ("LoginDatabaseInfo", "acore_auth"),
                ("WorldDatabaseInfo", "acore_world"),
                ("CharacterDatabaseInfo", "acore_characters"),
                ("PlayerbotsDatabaseInfo", "acore_playerbots")
            ]
'''
if old not in s:
    raise SystemExit('WotLK databaseInfo block not found')
s = s.replace(old, new, 1)
server.write_text(s)

build = Path('Build.command')
b = build.read_text()
b = b.replace('<string>1.5.95</string>', '<string>1.5.96</string>', 1)
b = b.replace('<string>1595</string>', '<string>1596</string>', 1)
build.write_text(b)

notes = Path('RELEASE-NOTES.md')
r = notes.read_text()
r = '''# v1.5.96 — WotLK PlayerBots worldserver.conf DB Fix\n\n- Fixes the remaining WotLK PlayerBots startup failure on MySQL 127.0.0.1:3306.\n- The PlayerBots database pool reads `PlayerbotsDatabaseInfo` from `worldserver.conf`; WoWCC now self-heals that core setting to managed MySQL 3307 before every start.\n- Keeps the all-playerbots.conf repair and clean titlebar changes from 1.5.95.\n- No core rebuild, client preparation, or PlayerBots repopulation required.\n\n''' + r
notes.write_text(r)
