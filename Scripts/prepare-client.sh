#!/bin/bash
set -Eeuo pipefail
PROFILE="${1:-wotlk}"; CLIENT="${2:-}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PR="$ROOT/runtime/profiles/$PROFILE"
ROOT_ALIAS="$HOME/.wowcc"
if [[ -L "$ROOT_ALIAS" ]]; then
  CURRENT_TARGET="$(readlink "$ROOT_ALIAS" || true)"
  if [[ "$CURRENT_TARGET" != "$ROOT" ]]; then
    rm -f "$ROOT_ALIAS"
    ln -s "$ROOT" "$ROOT_ALIAS"
  fi
elif [[ ! -e "$ROOT_ALIAS" ]]; then
  ln -s "$ROOT" "$ROOT_ALIAS"
fi
[[ -n "$CLIENT" && -e "$CLIENT" ]] || { echo "Client path is missing"; exit 2; }
CLIENTDIR="$CLIENT"
[[ -f "$CLIENT" ]] && CLIENTDIR="$(dirname "$CLIENT")"

# Resolve the real WoW client root. The CMaNGOS container expects the CONTENTS
# of the client root at /opt/cmangos/storage/client-data, with Data/ directly
# underneath that mount. Users may select Wow.exe, a wrapper folder, or another
# directory one or two levels above the actual client.
find_client_root() {
  local candidate="$1"
  local found=""

  # Exact selection or executable parent.
  if [[ -d "$candidate/Data" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  # macOS app wrappers are not valid CMaNGOS TBC Windows clients, but do not
  # blindly dive into Contents/Resources; search for a real Data directory.
  found="$(find "$candidate" -maxdepth 3 -type d -name Data -print 2>/dev/null | head -n 1 || true)"
  if [[ -n "$found" ]]; then
    dirname "$found"
    return 0
  fi

  return 1
}

if ! CLIENTROOT="$(find_client_root "$CLIENTDIR")"; then
  echo "ERROR: Could not find the WoW client root under '$CLIENTDIR'. Select the TBC 2.4.3 client folder that directly contains Data/ and Wow.exe." >&2
  exit 67
fi

CLIENTDIR="$CLIENTROOT"

[[ -d "$CLIENTDIR/Data" ]] || {
  echo "ERROR: Detected client root does not contain Data/: $CLIENTDIR" >&2
  exit 68
}

# At least one normal WoW executable marker should be present. Do not require
# exact case because old client distributions differ.
WOW_EXE=""
for exe in Wow.exe WoW.exe wow.exe "World of Warcraft.exe"; do
  if [[ -f "$CLIENTDIR/$exe" ]]; then
    WOW_EXE="$CLIENTDIR/$exe"
    break
  fi
done

if [[ "$PROFILE" == "tbc" && -z "$WOW_EXE" ]]; then
  echo "ERROR: '$CLIENTDIR' has Data/ but no WoW executable. Select the root of a complete TBC 2.4.3 client, not only its Data folder." >&2
  exit 69
fi

echo "[client:$PROFILE] Detected client root: $CLIENTDIR"

# Configure local realm wherever the classic clients expose realmlist.wtf.
while IFS= read -r f; do printf 'set realmlist 127.0.0.1\n' > "$f"; done < <(find "$CLIENTDIR" -type f -name 'realmlist.wtf' 2>/dev/null || true)

if [[ "$PROFILE" == "wotlk" ]]; then
  echo "[client:wotlk] Preparing AzerothCore client/server data…"
  mkdir -p "$PR/data"

  # These are the AzerothCore tools required for a complete 3.3.5a data extraction.
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
    [[ -x "$PR/bin/$tool" ]] || { echo "ERROR: Missing extractor $PR/bin/$tool. Reinstall the WotLK core first." >&2; exit 41; }
    cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"
    chmod +x "$CLIENTDIR/$tool"
  done

  cd "$CLIENTDIR"

  echo "[client:wotlk] Extracting DBC and maps…"
  ./mapextractor

  echo "[client:wotlk] Extracting VMap source…"
  ./vmap4extractor

  [[ -d Buildings ]] || { echo "ERROR: vmap4extractor completed but Buildings/ was not created." >&2; exit 42; }
  rm -rf vmaps
  mkdir -p vmaps
  echo "[client:wotlk] Assembling VMAPs…"
  ./vmap4assembler Buildings vmaps

  rm -rf mmaps
  mkdir -p mmaps
  echo "[client:wotlk] Generating MMAPs (this can take a long time)…"
  ./mmaps_generator

  # Validate actual content, not just directory existence.
  count_files() { find "$1" -type f 2>/dev/null | wc -l | tr -d ' '; }

  [[ -d dbc ]] || { echo "ERROR: dbc/ was not created by mapextractor." >&2; exit 43; }
  [[ -d maps ]] || { echo "ERROR: maps/ was not created by mapextractor." >&2; exit 44; }
  [[ -d vmaps ]] || { echo "ERROR: vmaps/ was not created." >&2; exit 45; }
  [[ -d mmaps ]] || { echo "ERROR: mmaps/ was not created." >&2; exit 46; }

  DBC_COUNT="$(count_files dbc)"
  MAP_COUNT="$(count_files maps)"
  VMAP_COUNT="$(count_files vmaps)"
  MMAP_COUNT="$(count_files mmaps)"

  echo "[client:wotlk] DBC files: $DBC_COUNT"
  echo "[client:wotlk] Map files: $MAP_COUNT"
  echo "[client:wotlk] VMap files: $VMAP_COUNT"
  echo "[client:wotlk] MMap files: $MMAP_COUNT"

  [[ "$DBC_COUNT" -ge 100 ]] || { echo "ERROR: DBC extraction looks incomplete ($DBC_COUNT files)." >&2; exit 47; }
  [[ "$MAP_COUNT" -ge 100 ]] || { echo "ERROR: map extraction looks incomplete ($MAP_COUNT files)." >&2; exit 48; }
  [[ "$VMAP_COUNT" -ge 10 ]] || { echo "ERROR: VMap extraction looks incomplete ($VMAP_COUNT files)." >&2; exit 49; }
  [[ "$MMAP_COUNT" -ge 10 ]] || { echo "ERROR: MMap extraction looks incomplete ($MMAP_COUNT files)." >&2; exit 50; }

  for d in dbc maps vmaps mmaps Cameras cameras; do
    if [[ -d "$CLIENTDIR/$d" ]]; then
      rm -rf "$PR/data/$d"
      cp -R "$CLIENTDIR/$d" "$PR/data/$d"
    fi
  done

  # Final validation at the exact DataDir used by worldserver.
  for d in dbc maps vmaps mmaps; do
    [[ -d "$PR/data/$d" ]] || { echo "ERROR: DataDir is missing $d after copy." >&2; exit 51; }
    COPIED_COUNT="$(count_files "$PR/data/$d")"
    [[ "$COPIED_COUNT" -gt 0 ]] || { echo "ERROR: DataDir/$d is empty after copy." >&2; exit 52; }
  done

  echo "[client:wotlk] READY — DBC/maps/vmaps/mmaps extracted and copied to server DataDir."
  echo "WotLK server data extracted and realmlist configured."
elif [[ "$PROFILE" == "cataclysm" || "$PROFILE" == "mop" ]]; then
  # Trinity/SkyFire community branches normally ship extractor binaries with the core.
  # Copy whichever tools the selected branch actually built, then run the compatible ones.
  for tool in mapextractor vmap4extractor vmap4assembler mmaps_generator vmapextractor; do
    [[ -x "$PR/bin/$tool" ]] && cp -f "$PR/bin/$tool" "$CLIENTDIR/$tool"
  done
  cd "$CLIENTDIR"
  [[ -x ./mapextractor ]] && ./mapextractor || true
  [[ -x ./vmap4extractor ]] && ./vmap4extractor || true
  [[ -x ./vmapextractor ]] && ./vmapextractor || true
  if [[ -x ./vmap4assembler && -d Buildings ]]; then mkdir -p vmaps; ./vmap4assembler Buildings vmaps || true; fi
  [[ -x ./mmaps_generator ]] && { mkdir -p mmaps; ./mmaps_generator || true; }
  for d in dbc db2 maps vmaps mmaps gt Cameras cameras; do
    [[ -d "$CLIENTDIR/$d" ]] && { rm -rf "$PR/data/$d"; cp -R "$CLIENTDIR/$d" "$PR/data/$d"; }
  done
  echo "$PROFILE client realmlist configured and available extractor output copied."
elif [[ "$PROFILE" == "vanilla" || "$PROFILE" == "tbc" ]]; then
  echo "[client:$PROFILE] Preparing CMaNGOS client/server data…"
  mkdir -p "$PR/data"

  count_files() {
    find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
  }

  copy_extracted_data() {
    local d
    for d in dbc maps vmaps mmaps; do
      if [[ -d "$CLIENTDIR/$d" ]]; then
        rm -rf "$PR/data/$d"
        cp -R "$CLIENTDIR/$d" "$PR/data/$d"
      fi
    done
  }

  data_ready() {
    local d count
    for d in dbc maps vmaps; do
      [[ -d "$PR/data/$d" ]] || return 1
      count="$(count_files "$PR/data/$d")"
      [[ "${count:-0}" -gt 0 ]] || return 1
    done
    return 0
  }

  copy_extracted_data
  if data_ready; then
    echo "[client:$PROFILE] READY — existing dbc/maps/vmaps copied to the managed DataDir."
    exit 0
  fi

  if [[ -x "$PR/bin/ad" && -x "$PR/bin/vmap_extractor" && -x "$PR/bin/vmap_assembler" ]]; then
    echo "[client:$PROFILE] Found CMaNGOS extractors. Running DBC/maps/vmaps extraction…"
    cp -f "$PR/bin/ad" "$CLIENTDIR/ad"
    cp -f "$PR/bin/vmap_extractor" "$CLIENTDIR/vmap_extractor"
    cp -f "$PR/bin/vmap_assembler" "$CLIENTDIR/vmap_assembler"
    chmod +x "$CLIENTDIR/ad" "$CLIENTDIR/vmap_extractor" "$CLIENTDIR/vmap_assembler"

    cd "$CLIENTDIR"
    ./ad
    ./vmap_extractor

    [[ -d Buildings ]] || {
      echo "ERROR: vmap_extractor finished but Buildings/ was not created." >&2
      exit 61
    }

    rm -rf vmaps
    mkdir -p vmaps
    ./vmap_assembler Buildings vmaps

    copy_extracted_data
    if data_ready; then
      echo "[client:$PROFILE] READY — DBC/maps/vmaps extracted and copied to the managed DataDir."
      exit 0
    fi

    echo "ERROR: CMaNGOS extractors finished, but managed dbc/maps/vmaps are still incomplete." >&2
    exit 62
  fi

  ARCH="$(uname -m)"
  if [[ "$ARCH" == "arm64" ]]; then
    # CMaNGOS forces BUILD_EXTRACTORS=OFF on ARM. Use the maintained amd64
    # CMaNGOS container image locally through Docker/Colima emulation instead.
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      IMAGE="ghcr.io/mserajnik/cmangos-server-tbc"
      [[ "$PROFILE" == "vanilla" ]] && IMAGE="ghcr.io/mserajnik/cmangos-server-classic"

      echo "[client:$PROFILE] Apple Silicon detected — using local amd64 CMaNGOS extractor container."
      echo "[client:$PROFILE] Pulling/using $IMAGE …"
      echo "[client:$PROFILE] Extraction can take a long time; keep Control Center open."

      mkdir -p "$PR/data"

      # cmangos-deploy expects a dedicated client-data directory containing the
      # CONTENTS of the WoW client root. Stage it inside Control Center instead
      # of depending on an arbitrary external path being mounted correctly by
      # the Colima VM.
      STAGING="$ROOT/runtime/profiles/$PROFILE/extractor-client-data"
      rm -rf "$STAGING"
      mkdir -p "$STAGING"

      echo "[client:$PROFILE] Staging client files for the extractor…"
      if cp -cR "$CLIENTDIR/." "$STAGING/" 2>/dev/null; then
        :
      else
        cp -R "$CLIENTDIR/." "$STAGING/"
      fi

      [[ -d "$STAGING/Data" ]] || {
        echo "ERROR: Staging failed: Data/ is missing from $STAGING" >&2
        exit 70
      }

      STAGED_EXE=""
      for exe in Wow.exe WoW.exe wow.exe "World of Warcraft.exe"; do
        if [[ -f "$STAGING/$exe" ]]; then
          STAGED_EXE="$STAGING/$exe"
          break
        fi
      done
      [[ -n "$STAGED_EXE" ]] || {
        echo "ERROR: Staging failed: WoW executable is missing from $STAGING" >&2
        exit 71
      }

      echo "[client:$PROFILE] Staged client root validated: Data/ + $(basename "$STAGED_EXE")"

      docker run \
        -i \
        --rm \
        --platform linux/amd64 \
        -v "$STAGING:/opt/cmangos/storage/client-data" \
        -v "$PR/data:/opt/cmangos/storage/data" \
        "$IMAGE" \
        extract-client-data --force

      if data_ready; then
        echo "[client:$PROFILE] READY — local amd64 container created dbc/maps/vmaps in managed DataDir."
        exit 0
      fi

      echo "ERROR: Local container extraction finished but dbc/maps/vmaps are still incomplete. Check the installer log for extractor output." >&2
      exit 66
    fi

    echo "ERROR: TBC extractors are unavailable natively on Apple Silicon and no local Docker engine is running. In Setup Guide click 'Install Local TBC Extractor Engine', then run Prepare Client Data again." >&2
    exit 63
  fi

  echo "ERROR: Missing CMaNGOS extractor binaries (ad, vmap_extractor, vmap_assembler). Reinstall the core with BUILD_EXTRACTORS=ON or import already-extracted dbc/maps/vmaps." >&2
  exit 64
else
  echo "ERROR: Prepare Client Data is not implemented for profile '$PROFILE'." >&2
  exit 65
fi
