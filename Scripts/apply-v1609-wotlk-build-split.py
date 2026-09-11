#!/usr/bin/env python3
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
install = root / 'Scripts/install-profile.sh'
s = install.read_text()

# WotLK server build: do not compile map/vmap/mmaps tools with the main server.
# Those dependencies (Recast/Detour/g3dlite) were where Apple Silicon builds repeatedly
# appeared to freeze at 0-3%. WoWCC already has a dedicated maps-only extractor phase.
if '-DTOOLS_BUILD=all' not in s and '-DTOOLS_BUILD=none' not in s:
    raise SystemExit('Could not locate WotLK TOOLS_BUILD setting')
s = s.replace('-DTOOLS_BUILD=all', '-DTOOLS_BUILD=none', 1)

# Use Ninja for the WotLK PlayerBots fork. It has substantially clearer dependency
# scheduling than Unix Makefiles and avoids the early make jobserver stalls seen on M4.
needle = 'if [[ "$PROFILE" == "wotlk" ]]; then\n  MYSQL_INCLUDE=""'
replacement = '''if [[ "$PROFILE" == "wotlk" ]]; then
  command -v ninja >/dev/null 2>&1 || fail "Ninja is required for the WotLK PlayerBots build. Run Install Dependencies first."
  log "WotLK build backend: Ninja (server first, extractors isolated afterward)"
  MYSQL_INCLUDE=""'''
if needle in s:
    s = s.replace(needle, replacement, 1)
elif 'WotLK build backend: Ninja' not in s:
    raise SystemExit('Could not locate WotLK configure block')

needle = '''  CMAKE_ARGS=(
    -S "$SRC_ROOT" -B "$BUILD"'''
replacement = '''  CMAKE_ARGS=(
    -G Ninja
    -S "$SRC_ROOT" -B "$BUILD"'''
if needle in s:
    s = s.replace(needle, replacement, 1)
elif '-G Ninja\n    -S "$SRC_ROOT" -B "$BUILD"' not in s:
    raise SystemExit('Could not add Ninja generator to WotLK CMake args')

# Cap WotLK server/extractor builds to two compile jobs. Replace any previous 8/4 cap.
s, n = re.subn(
    r'if \[\[ "\$PROFILE" == "wotlk" && "\$JOBS" -gt \d+ \]\]; then JOBS=\d+; fi',
    'if [[ "$PROFILE" == "wotlk" && "$JOBS" -gt 2 ]]; then JOBS=2; fi',
    s,
    count=1,
)
if n == 0 and 'then JOBS=2; fi' not in s:
    raise SystemExit('Could not locate WotLK job cap')

# Make the extractor phase use the same live watchdog instead of an opaque direct build.
old = '''    if ! cmake --build "$EXTRACT_BUILD" --config Release --parallel "$JOBS" 2>&1 | tee -a "$EXTRACT_LOG"; then
      fail "WotLK maps-only extractor build failed. See $EXTRACT_LOG in WoWCC Logs."
    fi'''
new = '''    log "Building isolated WotLK map extractors with Ninja ($JOBS job(s))…"
    WATCHDOG="$(cd "$(dirname "$0")" && pwd)/run-core-build-watchdog.py"
    if ! python3 "$WATCHDOG" --build "$EXTRACT_BUILD" --jobs "$JOBS" --log "$EXTRACT_LOG" --label "wotlk-extractors"; then
      fail "WotLK maps-only extractor build failed or stalled. See $EXTRACT_LOG in WoWCC Logs."
    fi'''
if old in s:
    s = s.replace(old, new, 1)
elif 'label "wotlk-extractors"' not in s:
    raise SystemExit('Could not locate extractor build block')

install.write_text(s)

# Ensure local Build.command provisions Ninja too, and bump the bundle version.
build = root / 'Build.command'
b = build.read_text()
if 'brew list ninja' not in b:
    b = b.replace('  brew list pkgconf >/dev/null 2>&1 || brew install pkgconf\n',
                  '  brew list pkgconf >/dev/null 2>&1 || brew install pkgconf\n  brew list ninja >/dev/null 2>&1 || brew install ninja\n', 1)
b = b.replace('<key>CFBundleShortVersionString</key><string>1.6.8</string>',
              '<key>CFBundleShortVersionString</key><string>1.6.9</string>', 1)
b = b.replace('<key>CFBundleVersion</key><string>1608</string>',
              '<key>CFBundleVersion</key><string>1609</string>', 1)
build.write_text(b)

# Make watchdog heartbeats look like build progress even when Ninja/Make is silent,
# so WoWCC's status bar visibly changes instead of leaving one .cpp line forever.
watchdog = root / 'Scripts/run-core-build-watchdog.py'
w = watchdog.read_text()
w = w.replace(
    "heartbeat=f'[build:{args.label}] BUILDING {progress} | elapsed {elapsed//60}m{elapsed%60:02d}s | no-output {silent}s | child CPU {cpu:.1f}% | {active_short}\\n'",
    "heartbeat=f'[ {progress:>4}] WoWCC BUILDING {args.label} | elapsed {elapsed//60}m{elapsed%60:02d}s | no-output {silent}s | child CPU {cpu:.1f}% | {active_short}\\n'",
    1,
)
watchdog.write_text(w)

notes = root / 'RELEASE-NOTES.md'
r = notes.read_text()
header = '''# v1.6.9 — WotLK Server/Extractor Build Split

- Fixes repeated WotLK rebuild stalls at 0–3% in Recast, Detour and g3dlite by removing map extractor tools from the main authserver/worldserver + PlayerBots build.
- Main WotLK build now uses `TOOLS_BUILD=none`, which is the AzerothCore-supported server-only configuration.
- Uses Ninja for WotLK builds and caps Apple Silicon compilation to 2 jobs for stable memory/CPU scheduling.
- Required map/vmap/mmap extractors are still built automatically afterward in a separate `TOOLS_BUILD=maps-only` phase.
- The isolated extractor build also uses the live WoWCC watchdog and writes to `cmake-wotlk-extractors.log` in WoWCC Logs.
- Existing PlayerBots, WrathSilicon preparation and mounted-flying-everywhere changes remain intact.

'''
if not r.startswith('# v1.6.9'):
    notes.write_text(header + r)

print('v1.6.9 WotLK build split applied')
