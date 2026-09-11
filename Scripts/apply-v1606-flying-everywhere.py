#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]

# 1) Add reusable WotLK DBC/client patch helper.
helper = root / 'Scripts' / 'enable-wotlk-flying-everywhere.py'
helper.write_text(r'''#!/usr/bin/env python3
import argparse, shutil, struct
from pathlib import Path

OUTLAND_FLAG = 0x00000400
NO_FLY_FLAG = 0x20000000

def patch_dbc(src: Path, dst: Path):
    data = bytearray(src.read_bytes())
    if len(data) < 20 or data[:4] != b'WDBC':
        raise SystemExit(f'ERROR: {src} is not a WotLK WDBC AreaTable.dbc')
    records, fields, record_size, strings = struct.unpack_from('<4I', data, 4)
    if fields < 5 or record_size < 20:
        raise SystemExit(f'ERROR: unsupported AreaTable layout: fields={fields}, record_size={record_size}')
    expected = 20 + records * record_size + strings
    if len(data) < expected:
        raise SystemExit('ERROR: truncated AreaTable.dbc')
    changed = 0
    for i in range(records):
        off = 20 + i * record_size
        map_id = struct.unpack_from('<I', data, off + 4)[0]
        if map_id in (0, 1):
            flags = struct.unpack_from('<I', data, off + 16)[0]
            new_flags = (flags | OUTLAND_FLAG) & ~NO_FLY_FLAG
            if new_flags != flags:
                struct.pack_into('<I', data, off + 16, new_flags)
                changed += 1
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    return changed

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--server-dbc', required=True)
    ap.add_argument('--client-root')
    args = ap.parse_args()
    src = Path(args.server_dbc)
    if not src.exists():
        raise SystemExit(f'ERROR: AreaTable.dbc not found: {src}')
    # Patch server copy too, so AzerothCore sees old-world areas as flyable.
    backup = src.with_suffix(src.suffix + '.wowcc-backup')
    if not backup.exists():
        shutil.copy2(src, backup)
    changed = patch_dbc(src, src)
    print(f'[flying:wotlk] Patched server AreaTable.dbc ({changed} old-world records changed).')

    if args.client_root:
        client = Path(args.client_root)
        loose = client / 'Data' / 'DBFilesClient' / 'AreaTable.dbc'
        patch_dbc(backup if backup.exists() else src, loose)
        bat = client / 'WoWCC-Fly-Everywhere.bat'
        bat.write_text('@echo off\r\ncd /d "%~dp0"\r\nstart "" "Wow.exe" -direct\r\n', encoding='ascii')
        note = client / 'WoWCC-Fly-Everywhere.txt'
        note.write_text('WoWCC old-world mounted flying is enabled. Launch WotLK with WoWCC-Fly-Everywhere.bat so the 3.3.5a client loads the patched loose AreaTable.dbc via -direct.\n', encoding='utf-8')
        print(f'[flying:wotlk] Client loose DBC written: {loose}')
        print(f'[flying:wotlk] Windows launcher written: {bat}')

if __name__ == '__main__':
    main()
''')
helper.chmod(0o755)

# 2) Patch WotLK core install: permit mounted-flight spell checks on maps 0/1.
install = root / 'Scripts' / 'install-profile.sh'
s = install.read_text()
anchor = '  log "WotLK PlayerBots source ready (Playerbot fork + mod-playerbots)."\nfi\n'
if anchor not in s:
    raise SystemExit('install-profile.sh WotLK anchor not found')
insert = r'''  log "WotLK PlayerBots source ready (Playerbot fork + mod-playerbots)."

  # WoWCC custom realm feature: mounted flying in Eastern Kingdoms + Kalimdor.
  # The 3.3.5 client has its own AreaTable restriction, handled by
  # enable-wotlk-flying-everywhere.py during Prepare Client Data.
  log "Applying WoWCC WotLK mounted-flying-everywhere server patch…"
  python3 - "$SRC_ROOT" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]) / "src/server/game/Spells/SpellInfo.cpp"
if not p.exists():
    raise SystemExit("ERROR: WotLK SpellInfo.cpp not found")
s = p.read_text()
old = '''        if (!areaEntry || !areaEntry->IsFlyable() || (strict && (areaEntry->flags & AREA_FLAG_NO_FLY_ZONE) != 0) || !player->canFlyInZone(map_id, zone_id, this))
        {
            return SPELL_FAILED_INCORRECT_AREA;
        }'''
new = '''        // WoWCC: permit normal flying-mount spells in old Azeroth (maps 0/1).
        // Client AreaTable is patched separately by Prepare Client Data.
        bool const wowccOldWorldFlying = map_id == 0 || map_id == 1;
        if (!areaEntry ||
            (!wowccOldWorldFlying && !areaEntry->IsFlyable()) ||
            (!wowccOldWorldFlying && strict && (areaEntry->flags & AREA_FLAG_NO_FLY_ZONE) != 0) ||
            (!wowccOldWorldFlying && !player->canFlyInZone(map_id, zone_id, this)))
        {
            return SPELL_FAILED_INCORRECT_AREA;
        }'''
if new in s:
    print('[core:wotlk] Flying-everywhere server patch already present')
elif old in s:
    p.write_text(s.replace(old, new, 1))
    print('[core:wotlk] Flying-everywhere server patch applied')
else:
    raise SystemExit('ERROR: WotLK SpellInfo flight-check layout changed; refusing an unsafe patch')
PY
fi
'''
s = s.replace(anchor, insert, 1)
install.write_text(s)

# 3) Prepare-client integration. It patches extracted server DBC and writes a
# loose client DBC + -direct launcher when a Windows WotLK client folder exists.
prep = root / 'Scripts' / 'prepare-client.sh'
p = prep.read_text()
marker = '# WoWCC v1.6.6: WotLK mounted flying everywhere\n'
if marker not in p:
    p += r'''

# WoWCC v1.6.6: WotLK mounted flying everywhere
if [[ "$PROFILE" == "wotlk" ]]; then
  AREA_DBC="$PROFILE_ROOT/data/dbc/AreaTable.dbc"
  if [[ -f "$AREA_DBC" ]]; then
    FLY_ARGS=(--server-dbc "$AREA_DBC")
    if [[ -n "${CLIENTDIR:-}" && -d "$CLIENTDIR" ]]; then
      FLY_ARGS+=(--client-root "$CLIENTDIR")
    fi
    python3 "$(cd "$(dirname "$0")" && pwd)/enable-wotlk-flying-everywhere.py" "${FLY_ARGS[@]}"
    echo "[client:wotlk] Mounted flying everywhere prepared. For Windows clients launch WoWCC-Fly-Everywhere.bat."
  else
    echo "[client:wotlk] WARNING: AreaTable.dbc not found; flying-everywhere client patch was not generated." >&2
  fi
fi
'''
prep.write_text(p)

# 4) Version/release notes. Replace only obvious user-facing version strings.
for rel in ['README.md', 'RELEASE-NOTES.md']:
    f = root / rel
    if f.exists():
        t = f.read_text()
        t = t.replace('1.6.5', '1.6.6')
        if rel == 'RELEASE-NOTES.md':
            t = '# v1.6.6 — WotLK Mounted Flying Everywhere\n\n- WotLK flying mounts can be used in Eastern Kingdoms and Kalimdor after rebuilding the WotLK core and running Prepare Client Data.\n- Prepare Client Data patches AreaTable.dbc and creates `WoWCC-Fly-Everywhere.bat` for Windows 3.3.5a clients using `-direct`.\n- Server-side flight-area checks are patched during WotLK core installation.\n- Existing PlayerBots support remains intact for normal and Heroic dungeon groups.\n\n' + t
        f.write_text(t)

# App version constants/plist/package files: safely replace existing 1.6.5 / 1605 where present.
for rel in ['Sources/WoWServerControlCenter/AppVersion.swift','Sources/WoWServerControlCenter/WoWServerControlCenterApp.swift','Package.swift','Build.command']:
    f = root / rel
    if f.exists():
        t = f.read_text().replace('1.6.5','1.6.6').replace('1605','1606')
        f.write_text(t)

print('v1.6.6 patch applied')
