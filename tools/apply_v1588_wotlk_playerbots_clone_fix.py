from pathlib import Path

p = Path('Scripts/install-profile.sh')
s = p.read_text()
old = '''if [[ "$PROFILE" == "wotlk" ]]; then
  WOTLK_BOTS_DIR="$SRC_ROOT/modules/mod-playerbots"
  WOTLK_BOTS_REPO="https://github.com/mod-playerbots/mod-playerbots.git"
  log "Preparing WotLK mod-playerbots module…"
  if [[ -d "$WOTLK_BOTS_DIR/.git" ]]; then
    git -C "$WOTLK_BOTS_DIR" fetch --depth 1 origin master
    git -C "$WOTLK_BOTS_DIR" reset --hard origin/master
  else
    rm -rf "$WOTLK_BOTS_DIR"
    git clone --depth 1 --single-branch --branch master "$WOTLK_BOTS_REPO" "$WOTLK_BOTS_DIR"
  fi
  [[ -f "$WOTLK_BOTS_DIR/CMakeLists.txt" ]] || fail "WotLK mod-playerbots clone is incomplete: $WOTLK_BOTS_DIR"
  log "WotLK PlayerBots source ready (Playerbot fork + mod-playerbots)."
fi
'''
new = '''if [[ "$PROFILE" == "wotlk" ]]; then
  WOTLK_BOTS_DIR="$SRC_ROOT/modules/mod-playerbots"
  WOTLK_BOTS_REPO="https://github.com/mod-playerbots/mod-playerbots.git"
  log "Preparing WotLK mod-playerbots module…"

  playerbots_tree_valid() {
    [[ -f "$WOTLK_BOTS_DIR/README.md" ]] && \\
    [[ -f "$WOTLK_BOTS_DIR/src/PlayerbotAIConfig.cpp" ]] && \\
    [[ -f "$WOTLK_BOTS_DIR/conf/playerbots.conf.dist" ]]
  }

  # Current mod-playerbots intentionally has no root CMakeLists.txt. The
  # Playerbot AzerothCore fork discovers the module from modules/mod-playerbots.
  # Validate real module payload instead of requiring a nonexistent file.
  if [[ -d "$WOTLK_BOTS_DIR/.git" ]]; then
    if ! playerbots_tree_valid; then
      log "Existing mod-playerbots checkout is incomplete; recloning it cleanly…"
      rm -rf "$WOTLK_BOTS_DIR"
      git clone --depth 1 --single-branch --branch master "$WOTLK_BOTS_REPO" "$WOTLK_BOTS_DIR"
    else
      git -C "$WOTLK_BOTS_DIR" fetch --depth 1 origin master
      git -C "$WOTLK_BOTS_DIR" reset --hard origin/master
    fi
  else
    rm -rf "$WOTLK_BOTS_DIR"
    git clone --depth 1 --single-branch --branch master "$WOTLK_BOTS_REPO" "$WOTLK_BOTS_DIR"
  fi

  playerbots_tree_valid || fail "WotLK mod-playerbots clone is incomplete after clean clone: $WOTLK_BOTS_DIR"
  log "WotLK PlayerBots source ready (Playerbot fork + mod-playerbots)."
fi
'''
if old not in s:
    raise SystemExit('target WotLK PlayerBots block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Bump bundle version.
b = Path('Build.command')
bs = b.read_text().replace('<string>1.5.87</string>', '<string>1.5.88</string>').replace('<string>1587</string>', '<string>1588</string>')
b.write_text(bs)

# Also make the WotLK build explicitly verify that CMake generated the map tools
# before install normalization, producing a useful log instead of a later Prepare Client error.
p = Path('Scripts/install-profile.sh')
s = p.read_text()
needle = '''log "Installing core into $PROFILE_ROOT"
cmake --install "$BUILD" --config Release
'''
replacement = '''if [[ "$PROFILE" == "wotlk" ]]; then
  log "Verifying WotLK extractor targets before install…"
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    candidate="$(find "$BUILD" -type f -name "$tool" -perm -111 -print 2>/dev/null | head -n1 || true)"
    [[ -n "$candidate" ]] || fail "WotLK build completed without extractor target '$tool'. See $BUILD_LOG"
    log "Extractor built: $tool -> $candidate"
  done
fi

log "Installing core into $PROFILE_ROOT"
cmake --install "$BUILD" --config Release
'''
if needle not in s:
    raise SystemExit('install marker not found')
s = s.replace(needle, replacement, 1)
p.write_text(s)

r = Path('RELEASE-NOTES.md')
oldr = r.read_text() if r.exists() else ''
r.write_text('# v1.5.88 — WotLK PlayerBots Clone + Extractor Repair\n\n- Fixed false “mod-playerbots clone is incomplete” failure: current upstream module has no root CMakeLists.txt.\n- Validates the real PlayerBots payload and automatically reclones an interrupted checkout.\n- Verifies all four WotLK extractor binaries immediately after core compilation.\n- Keeps WotLK PlayerBots population range up to 5,000.\n\n' + oldr)
print('1.5.88 patch applied')
