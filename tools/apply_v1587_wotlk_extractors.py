from pathlib import Path

repo = Path('.')
install = repo/'Scripts/install-profile.sh'
prepare = repo/'Scripts/prepare-client.sh'
build = repo/'Build.command'
notes = repo/'RELEASE-NOTES.md'

s = install.read_text()
needle = '''log "Installing core into $PROFILE_ROOT"\ncmake --install "$BUILD" --config Release\n\n# Normalize common install layouts into the Control Center layout.\nfind "$PROFILE_ROOT" -type f \\('''
replacement = '''log "Installing core into $PROFILE_ROOT"\ncmake --install "$BUILD" --config Release\n\n# WotLK extractor recovery. The Playerbot fork builds the standard AzerothCore\n# map/vmap/mmap tools, but some CMake install layouts can leave them in the\n# build tree instead of PROFILE_ROOT/bin. Prepare Client must never depend on\n# that install-layout detail. Copy the verified executables into our stable\n# managed bin path after every WotLK rebuild.\nif [[ "$PROFILE" == "wotlk" ]]; then\n  log "Verifying WotLK client-data extractors…"\n  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do\n    if [[ ! -x "$PROFILE_ROOT/bin/$tool" ]]; then\n      FOUND_TOOL="$(find "$BUILD" -type f -name "$tool" -perm -111 -print 2>/dev/null | head -n 1 || true)"\n      if [[ -n "$FOUND_TOOL" ]]; then\n        cp -f "$FOUND_TOOL" "$PROFILE_ROOT/bin/$tool"\n        chmod +x "$PROFILE_ROOT/bin/$tool"\n        log "Recovered extractor $tool from build tree."\n      fi\n    fi\n    [[ -x "$PROFILE_ROOT/bin/$tool" ]] || fail "WotLK build completed but required extractor '$tool' was not produced. See $BUILD_LOG"\n  done\n  if [[ -f "$BUILD/bin/mmaps-config.yaml" && ! -f "$PROFILE_ROOT/bin/mmaps-config.yaml" ]]; then\n    cp -f "$BUILD/bin/mmaps-config.yaml" "$PROFILE_ROOT/bin/mmaps-config.yaml"\n  fi\n  log "WotLK extractors ready: mapextractor, vmap4extractor, vmap4assembler, mmaps_generator"\nfi\n\n# Normalize common install layouts into the Control Center layout.\nfind "$PROFILE_ROOT" -type f \\('''
if needle not in s:
    raise SystemExit('install-profile anchor not found')
s = s.replace(needle, replacement, 1)
install.write_text(s)

s = prepare.read_text()
old = '''  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.\n  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do\n    [[ -x "$PR/bin/$tool" ]] || { echo "ERROR: Missing extractor $PR/bin/$tool. Reinstall the WotLK core first." >&2; exit 41; }\n    cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"\n    chmod +x "$CLIENTDIR/$tool"\n  done\n'''
new = '''  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.\n  # Self-heal older/partial installs: if cmake left a tool in the persistent\n  # WotLK build tree, recover it into the managed profile instead of falsely\n  # telling the user to rebuild a core that is already healthy.\n  WOTLK_BUILD="$ROOT/sources/wotlk/build"\n  resolve_wotlk_extractor() {\n    local tool="$1" found=""\n    if [[ -x "$PR/bin/$tool" ]]; then\n      printf '%s\\n' "$PR/bin/$tool"\n      return 0\n    fi\n    found="$(find "$WOTLK_BUILD" -type f -name "$tool" -perm -111 -print 2>/dev/null | head -n 1 || true)"\n    if [[ -n "$found" ]]; then\n      cp -f "$found" "$PR/bin/$tool"\n      chmod +x "$PR/bin/$tool"\n      echo "[client:wotlk] Recovered missing $tool from the existing core build." >&2\n      printf '%s\\n' "$PR/bin/$tool"\n      return 0\n    fi\n    return 1\n  }\n\n  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do\n    TOOL_PATH="$(resolve_wotlk_extractor "$tool" || true)"\n    if [[ -z "$TOOL_PATH" || ! -x "$TOOL_PATH" ]]; then\n      echo "ERROR: Missing WotLK extractor '$tool'. Core binaries exist, but the extractor target was not produced. Use WotLK → Rebuild Core + PlayerBots once with WoWCC 1.5.87 or newer. See Core Build log in WoWCC Logs." >&2\n      exit 41\n    fi\n    cp -f "$TOOL_PATH" "$CLIENTDIR/$tool"\n    chmod +x "$CLIENTDIR/$tool"\n  done\n'''
if old not in s:
    raise SystemExit('prepare-client anchor not found')
s = s.replace(old, new, 1)
prepare.write_text(s)

b = build.read_text().replace('<string>1.5.86</string>', '<string>1.5.87</string>').replace('<string>1586</string>', '<string>1587</string>')
build.write_text(b)

n = notes.read_text()
notes.write_text('''# v1.5.87 — WotLK Extractor Recovery\n\n- Fixes Prepare Client falsely reporting a missing `mapextractor` after a successful WotLK/PlayerBots core rebuild.\n- WotLK rebuild now verifies all four required extractor binaries and recovers them from the CMake build tree into the managed profile `bin/` directory when necessary.\n- Prepare Client can self-heal an existing WotLK installation by locating already-built extractors in the persistent build tree.\n- Missing extractor errors now point to the WoWCC Core Build log instead of simply asking to reinstall repeatedly.\n\n''' + n)

# sanity checks
assert 'resolve_wotlk_extractor' in prepare.read_text()
assert 'Recovered extractor' in install.read_text()
assert '1.5.87' in build.read_text()
print('1.5.87 WotLK extractor recovery patch applied')
