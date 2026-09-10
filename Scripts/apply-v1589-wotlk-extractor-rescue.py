from pathlib import Path

root = Path(__file__).resolve().parents[1]
install = root / 'Scripts/install-profile.sh'
prep = root / 'Scripts/prepare-client.sh'
build = root / 'Build.command'
notes = root / 'RELEASE-NOTES.md'

s = install.read_text()
old = '''if [[ "$PROFILE" == "wotlk" ]]; then
  log "Verifying WotLK extractor targets before install…"
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    candidate="$(find "$BUILD" -type f -name "$tool" -perm -111 -print 2>/dev/null | head -n1 || true)"
    [[ -n "$candidate" ]] || fail "WotLK build completed without extractor target '$tool'. See $BUILD_LOG"
    log "Extractor built: $tool -> $candidate"
  done
fi

'''
if old not in s:
    raise SystemExit('pre-install extractor verification block not found')
s = s.replace(old, '', 1)

old2 = '''# WotLK extractor recovery. The Playerbot fork builds the standard AzerothCore
# map/vmap/mmap tools, but some CMake install layouts can leave them in the
# build tree instead of PROFILE_ROOT/bin. Prepare Client must never depend on
# that install-layout detail. Copy the verified executables into our stable
# managed bin path after every WotLK rebuild.
if [[ "$PROFILE" == "wotlk" ]]; then
  log "Verifying WotLK client-data extractors…"
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    if [[ ! -x "$PROFILE_ROOT/bin/$tool" ]]; then
      FOUND_TOOL="$(find "$BUILD" -type f -name "$tool" -perm -111 -print 2>/dev/null | head -n 1 || true)"
      if [[ -n "$FOUND_TOOL" ]]; then
        cp -f "$FOUND_TOOL" "$PROFILE_ROOT/bin/$tool"
        chmod +x "$PROFILE_ROOT/bin/$tool"
        log "Recovered extractor $tool from build tree."
      fi
    fi
    [[ -x "$PROFILE_ROOT/bin/$tool" ]] || fail "WotLK build completed but required extractor '$tool' was not produced. See $BUILD_LOG"
  done
  if [[ -f "$BUILD/bin/mmaps-config.yaml" && ! -f "$PROFILE_ROOT/bin/mmaps-config.yaml" ]]; then
    cp -f "$BUILD/bin/mmaps-config.yaml" "$PROFILE_ROOT/bin/mmaps-config.yaml"
  fi
  log "WotLK extractors ready: mapextractor, vmap4extractor, vmap4assembler, mmaps_generator"
fi
'''
new2 = '''# WotLK extractor recovery. The Playerbot fork can expose extractor targets
# under different target/output names depending on branch/CMake generation.
# First normalize anything already produced. If maps tools were omitted from
# the main build, configure a dedicated maps-only build and install them.
if [[ "$PROFILE" == "wotlk" ]]; then
  log "Resolving WotLK client-data extractors…"

  find_extractor() {
    local canonical="$1"; shift
    local name found search_root
    for search_root in "$PROFILE_ROOT/bin" "$BUILD"; do
      for name in "$canonical" "$@"; do
        found="$(find "$search_root" -type f -name "$name" -perm -111 -print 2>/dev/null | head -n 1 || true)"
        if [[ -n "$found" ]]; then printf '%s\\n' "$found"; return 0; fi
      done
    done
    return 1
  }

  normalize_wotlk_extractors() {
    local canonical aliases found
    while IFS='|' read -r canonical aliases; do
      IFS=',' read -r -a alias_array <<< "$aliases"
      if [[ ! -x "$PROFILE_ROOT/bin/$canonical" ]]; then
        found="$(find_extractor "$canonical" "${alias_array[@]}" || true)"
        if [[ -n "$found" ]]; then
          cp -f "$found" "$PROFILE_ROOT/bin/$canonical"
          chmod +x "$PROFILE_ROOT/bin/$canonical"
          log "Normalized extractor $canonical from $(basename "$found")."
        fi
      fi
    done <<'EOF_WOWCC_TOOLS'
mapextractor|map_extractor
vmap4extractor|vmap4_extractor,vmapextractor,vmap_extractor
vmap4assembler|vmap4_assembler,vmapassembler,vmap_assembler
mmaps_generator|mmaps-generator,mmap_generator
EOF_WOWCC_TOOLS
  }

  normalize_wotlk_extractors

  missing=0
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    [[ -x "$PROFILE_ROOT/bin/$tool" ]] || missing=1
  done

  if (( missing )); then
    EXTRACT_BUILD="$ROOT/sources/$PROFILE/extractor-build"
    EXTRACT_LOG="$PROFILE_ROOT/logs/cmake-wotlk-extractors.log"
    log "Main PlayerBots build did not install every maps tool; creating dedicated maps-only extractor build…"
    rm -rf "$EXTRACT_BUILD"
    mkdir -p "$EXTRACT_BUILD"

    EXTRACT_ARGS=("${CMAKE_ARGS[@]}")
    EXTRACT_ARGS+=( -B "$EXTRACT_BUILD" -DTOOLS_BUILD=maps-only -DCMAKE_INSTALL_PREFIX="$PROFILE_ROOT" )
    if ! cmake "${EXTRACT_ARGS[@]}" 2>&1 | tee "$EXTRACT_LOG"; then
      fail "WotLK maps-only extractor configure failed. See $EXTRACT_LOG in WoWCC Logs."
    fi
    if ! cmake --build "$EXTRACT_BUILD" --config Release --parallel "$JOBS" 2>&1 | tee -a "$EXTRACT_LOG"; then
      fail "WotLK maps-only extractor build failed. See $EXTRACT_LOG in WoWCC Logs."
    fi
    cmake --install "$EXTRACT_BUILD" --config Release 2>&1 | tee -a "$EXTRACT_LOG"

    # Search both the dedicated build and installed profile, accepting upstream
    # underscore/non-underscore output variants, then normalize for Prepare Client.
    BUILD_ORIGINAL="$BUILD"
    BUILD="$EXTRACT_BUILD"
    normalize_wotlk_extractors
    BUILD="$BUILD_ORIGINAL"
  fi

  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    [[ -x "$PROFILE_ROOT/bin/$tool" ]] || fail "WotLK extractor '$tool' is still missing after dedicated maps-only build. See cmake-wotlk-extractors.log in WoWCC Logs."
  done

  for candidate in "$BUILD/bin/mmaps-config.yaml" "$ROOT/sources/$PROFILE/extractor-build/bin/mmaps-config.yaml"; do
    if [[ -f "$candidate" ]]; then cp -f "$candidate" "$PROFILE_ROOT/bin/mmaps-config.yaml"; break; fi
  done
  log "WotLK extractors ready: mapextractor, vmap4extractor, vmap4assembler, mmaps_generator"
fi
'''
if old2 not in s:
    raise SystemExit('extractor recovery block not found')
s = s.replace(old2, new2, 1)
install.write_text(s)

p = prep.read_text()
oldp = '''  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    [[ -x "$PR/bin/$tool" ]] || { echo "ERROR: Missing WotLK extractor '$tool'. Core binaries exist, but the extractor target was not produced. Use WotLK → Rebuild Core + PlayerBots once with WoWCC 1.5.87 or newer. See Core Build log in WoWCC Logs." >&2; exit 41; }
    cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"
    chmod +x "$CLIENTDIR/$tool"
  done
'''
newp = '''  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.
  # 1.5.89+ accepts both canonical WoWCC names and Playerbot-fork underscore variants.
  resolve_wotlk_tool() {
    local canonical="$1"; shift
    local name
    for name in "$canonical" "$@"; do
      [[ -x "$PR/bin/$name" ]] && { printf '%s\\n' "$PR/bin/$name"; return 0; }
    done
    return 1
  }
  while IFS='|' read -r tool aliases; do
    IFS=',' read -r -a alias_array <<< "$aliases"
    source_tool="$(resolve_wotlk_tool "$tool" "${alias_array[@]}" || true)"
    [[ -n "$source_tool" ]] || { echo "ERROR: Missing WotLK extractor '$tool'. Run WotLK → Rebuild Core + PlayerBots with WoWCC 1.5.89+. If it still fails, open cmake-wotlk-extractors.log in WoWCC Logs." >&2; exit 41; }
    cp -f "$source_tool" "$CLIENTDIR/$tool"
    chmod +x "$CLIENTDIR/$tool"
  done <<'EOF_WOWCC_TOOLS'
mapextractor|map_extractor
vmap4extractor|vmap4_extractor,vmapextractor,vmap_extractor
vmap4assembler|vmap4_assembler,vmapassembler,vmap_assembler
mmaps_generator|mmaps-generator,mmap_generator
EOF_WOWCC_TOOLS
'''
if oldp not in p:
    raise SystemExit('prepare-client extractor block not found')
p = p.replace(oldp, newp, 1)
prep.write_text(p)

b = build.read_text().replace('<string>1.5.88</string>', '<string>1.5.89</string>').replace('<string>1588</string>', '<string>1589</string>')
if b == build.read_text():
    raise SystemExit('Build.command version marker not updated')
build.write_text(b)

n = notes.read_text()
notes.write_text('# v1.5.89 — WotLK Extractor Target Rescue\n\n- Detects Playerbot fork extractor output aliases instead of assuming one filename.\n- If the main WotLK PlayerBots build omits maps tools, WoWCC performs a dedicated `TOOLS_BUILD=maps-only` build and installs the extractors automatically.\n- `Prepare Client` accepts upstream underscore aliases but normalizes to the stable WoWCC names.\n- Extractor configure/build diagnostics are available as `cmake-wotlk-extractors.log` in WoWCC Logs.\n\n' + n)
print('Applied v1.5.89 WotLK extractor rescue')
