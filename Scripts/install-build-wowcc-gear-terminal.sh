#!/bin/bash
set -euo pipefail
LOG="${HOME}/Library/Application Support/WoWServerControlCenter/runtime/wowcc-gear-terminal-build.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "=== WoWCC Gear Menu module build ==="; date

APP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_SRC="$APP_ROOT/Resources/mod-wowcc-gear-terminal"

find_core() {
  for d in \
    "${WOWCC_WOTLK_SOURCE:-}" \
    "${HOME}/Library/Application Support/WoWServerControlCenter/cores/wotlk" \
    "${HOME}/Library/Application Support/WoWServerControlCenter/sources/wotlk" \
    "${HOME}/Library/Application Support/WoWServerControlCenter/wotlk/azerothcore-wotlk"; do
    [[ -n "$d" && -f "$d/CMakeLists.txt" && -d "$d/src/server" ]] && { echo "$d"; return; }
  done
  find "${HOME}/Library/Application Support/WoWServerControlCenter" -maxdepth 7 -type f -name CMakeLists.txt -path '*wotlk*' -print 2>/dev/null | head -1 | xargs -I{} dirname "{}"
}
CORE="$(find_core || true)"
[[ -n "$CORE" ]] || { echo "ERROR: WotLK AzerothCore source not found."; exit 20; }
echo "Core: $CORE"

DST="$CORE/modules/mod-wowcc-gear-terminal"
rm -rf "$DST"; mkdir -p "$CORE/modules"; cp -R "$MODULE_SRC" "$DST"
echo "Module copied to $DST"

BUILD="${WOWCC_WOTLK_BUILD:-$CORE/build-wowcc}"
INSTALL="${WOWCC_WOTLK_INSTALL:-$CORE/env/dist}"
CMAKE="$(command -v cmake || true)"; [[ -x "$CMAKE" ]] || CMAKE=/opt/homebrew/bin/cmake
[[ -x "$CMAKE" ]] || { echo "ERROR: cmake missing"; exit 22; }
if command -v ninja >/dev/null 2>&1; then
  echo "Generator: Ninja"
  "$CMAKE" -S "$CORE" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" -DTOOLS_BUILD=none -DSCRIPTS=static -DMODULES=static
else
  echo "Generator: CMake default"
  "$CMAKE" -S "$CORE" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL" -DTOOLS_BUILD=none -DSCRIPTS=static -DMODULES=static
fi
"$CMAKE" --build "$BUILD" --target worldserver authserver -- -j1
"$CMAKE" --install "$BUILD"

WORLD="$(find "$INSTALL" "$BUILD" -type f -name worldserver -perm -111 2>/dev/null | head -1 || true)"
[[ -n "$WORLD" ]] || { echo "ERROR: rebuilt worldserver not found"; exit 23; }
echo "worldserver: $WORLD"
strings "$WORLD" | grep -q wowcc_gear_terminal && echo "PASS: Gear Menu module marker found." || echo "WARNING: marker not visible in binary."
echo "COMPLETE: module build finished. Run GM Island Install/Repair and restart World Server."
