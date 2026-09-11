#!/usr/bin/env python3
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

        # WoWSilicon/WrathSilicon 3.1 currently launches the selected executable
        # without arbitrary game arguments, so its normal Play button cannot add
        # WoW 3.3.5a's required -direct switch. Create a native macOS helper that
        # opens WoWSilicon and clearly records the required client mode. The loose
        # DBC itself is still installed automatically here.
        mac = client / 'WoWCC-WrathSilicon-Flying.command'
        mac.write_text(
            '#!/bin/zsh\n'
            'set -e\n'
            'CLIENT_DIR="$(cd "$(dirname "$0")" && pwd)"\n'
            'echo "WoWCC flying patch is installed in: $CLIENT_DIR/Data/DBFilesClient/AreaTable.dbc"\n'
            'echo "WrathSilicon 3.1 Play does not expose custom WoW.exe arguments."\n'
            'echo "The client must be launched with -direct for loose DBC loading."\nn'
            'open -a WoWSilicon 2>/dev/null || open -a WrathSilicon 2>/dev/null || true\n',
            encoding='utf-8'
        )
        mac.chmod(0o755)
        note = client / 'WoWCC-Fly-Everywhere.txt'
        note.write_text(
            'WoWCC old-world mounted flying client data is installed.\n'
            'Windows: use WoWCC-Fly-Everywhere.bat.\n'
            'WrathSilicon/WoWSilicon 3.1: the current launcher Play path does not expose arbitrary WoW.exe arguments, and WotLK loose DBC loading requires -direct. WoWCC therefore installs the DBC automatically but does not falsely claim the stock Play button enables -direct.\n',
            encoding='utf-8'
        )
        print(f'[flying:wotlk] Client loose DBC written: {loose}')
        print(f'[flying:wotlk] Windows -direct launcher written: {bat}')
        print(f'[flying:wotlk] WrathSilicon helper written: {mac}')

if __name__ == '__main__':
    main()
