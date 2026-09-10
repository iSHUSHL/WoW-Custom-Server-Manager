from pathlib import Path

root = Path(__file__).resolve().parents[1]
prep = root/'Scripts/prepare-client.sh'
install = root/'Scripts/install-profile.sh'
build = root/'Build.command'
notes = root/'RELEASE-NOTES.md'

s = prep.read_text()
old = '''  rm -rf mmaps\n  mkdir -p mmaps\n  echo "[client:wotlk] Generating MMAPs (this can take a long time)…"\n  ./mmaps_generator\n'''
new = '''  rm -rf mmaps\n  mkdir -p mmaps\n\n  # Current Playerbot/AzerothCore mmaps_generator requires mmaps-config.yaml.\n  # Keep Prepare Client self-healing for existing cores by locating the config\n  # from the installed profile, main build, dedicated extractor build, or source tree.\n  MMAPS_CONFIG=""\n  for candidate in \\\n    "$PR/bin/mmaps-config.yaml" \\\n    "$ROOT/sources/wotlk/build/bin/mmaps-config.yaml" \\\n    "$ROOT/sources/wotlk/extractor-build/bin/mmaps-config.yaml" \\\n    "$ROOT/sources/wotlk/core/src/tools/mmaps_generator/mmaps-config.yaml"; do\n    if [[ -s "$candidate" ]]; then MMAPS_CONFIG="$candidate"; break; fi\n  done\n  [[ -n "$MMAPS_CONFIG" ]] || {\n    echo "ERROR: WotLK mmaps_generator was built, but mmaps-config.yaml is missing. Rebuild Core + PlayerBots with WoWCC 1.5.90+ and check cmake-wotlk-extractors.log in WoWCC Logs." >&2\n    exit 53\n  }\n  cp -f "$MMAPS_CONFIG" "$CLIENTDIR/mmaps-config.yaml"\n  echo "[client:wotlk] MMAP config: $MMAPS_CONFIG"\n  echo "[client:wotlk] Generating MMAPs (this can take a long time)…"\n  ./mmaps_generator --config "$CLIENTDIR/mmaps-config.yaml"\n'''
if old not in s: raise SystemExit('prepare mmap block not found')
prep.write_text(s.replace(old,new,1))

s = install.read_text()
needle = '''  for candidate in "$BUILD/bin/mmaps-config.yaml" "$ROOT/sources/$PROFILE/extractor-build/bin/mmaps-config.yaml"; do\n    if [[ -f "$candidate" ]]; then cp -f "$candidate" "$PROFILE_ROOT/bin/mmaps-config.yaml"; break; fi\n  done\n'''
repl = '''  for candidate in \\\n    "$BUILD/bin/mmaps-config.yaml" \\\n    "$ROOT/sources/$PROFILE/extractor-build/bin/mmaps-config.yaml" \\\n    "$SRC_ROOT/src/tools/mmaps_generator/mmaps-config.yaml"; do\n    if [[ -s "$candidate" ]]; then cp -f "$candidate" "$PROFILE_ROOT/bin/mmaps-config.yaml"; break; fi\n  done\n  [[ -s "$PROFILE_ROOT/bin/mmaps-config.yaml" ]] || fail "WotLK mmaps-config.yaml was not installed. See cmake-wotlk-extractors.log in WoWCC Logs."\n'''
if needle not in s: raise SystemExit('install config block not found')
install.write_text(s.replace(needle,repl,1))

b=build.read_text().replace('<string>1.5.89</string>','<string>1.5.90</string>').replace('<string>1589</string>','<string>1590</string>')
if b==build.read_text(): raise SystemExit('version markers not found')
build.write_text(b)

notes.write_text('# v1.5.90 — WotLK MMAP Config Fix\n\n- Fixes Prepare Client failure: `Failed to load configuration` from `mmaps_generator`.\n- Copies and validates `mmaps-config.yaml` during WotLK core install.\n- Prepare Client self-heals older installs by locating the config in profile/build/source paths.\n- Runs `mmaps_generator --config <absolute path>` explicitly.\n\n'+notes.read_text())
print('Applied v1.5.90 WotLK MMAP config fix')
