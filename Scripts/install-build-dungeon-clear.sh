#!/bin/bash
set -euo pipefail
BASE="${HOME}/Library/Application Support/WoWServerControlCenter"
LOG="$BASE/runtime/dungeon-clear-build.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1
echo "=== WoWCC Dungeon Bot Leader build ==="; date

find_core() {
  for d in "${WOWCC_WOTLK_SOURCE:-}" "$BASE/sources/wotlk/core" "$BASE/cores/wotlk"; do
    [[ -n "$d" && -f "$d/CMakeLists.txt" && -d "$d/src/server" ]] && { echo "$d"; return; }
  done
  return 1
}
CORE="$(find_core || true)"
[[ -n "$CORE" ]] || { echo "ERROR: WotLK AzerothCore source not found."; exit 20; }
echo "[1/6] WotLK core found: $CORE"

# Requirement: mod-playerbots must already be present.
[[ -d "$CORE/modules/mod-playerbots" ]] || {
  echo "ERROR: mod-playerbots is not present at $CORE/modules/mod-playerbots"
  echo "Dungeon Clear requires mod-playerbots."
  exit 21
}

DST="$CORE/modules/mod-dungeon-clear"
if [[ -d "$DST/.git" ]]; then
  echo "[2/6] Updating Dungeon Clear module..."
  git -C "$DST" fetch --depth 1 origin master
  git -C "$DST" reset --hard origin/master
else
  echo "[2/6] Downloading Dungeon Clear module..."
  rm -rf "$DST"
  git clone --depth 1 https://github.com/jrad7/mod-dungeon-clear.git "$DST"
fi

BUILD="${WOWCC_WOTLK_BUILD:-$CORE/build-wowcc}"
INSTALL="${WOWCC_WOTLK_INSTALL:-$CORE/env/dist}"
CMAKE="$(command -v cmake || true)"; [[ -x "$CMAKE" ]] || CMAKE=/opt/homebrew/bin/cmake
[[ -x "$CMAKE" ]] || { echo "ERROR: cmake missing"; exit 22; }

echo "[readline] Locating GNU Readline required by AzerothCore CLI…"
READLINE_PREFIX=""
if command -v brew >/dev/null 2>&1; then
  READLINE_PREFIX="$(brew --prefix readline 2>/dev/null || true)"
fi
for candidate in "$READLINE_PREFIX" /opt/homebrew/opt/readline /usr/local/opt/readline; do
  if [[ -n "$candidate" && -f "$candidate/include/readline/readline.h" ]]; then
    READLINE_PREFIX="$candidate"
    break
  fi
done
if [[ -z "$READLINE_PREFIX" || ! -f "$READLINE_PREFIX/include/readline/readline.h" ]]; then
  echo "ERROR: GNU Readline was not found. Install Homebrew readline and retry."
  exit 24
fi
READLINE_LIB=""
for candidate in "$READLINE_PREFIX/lib/libreadline.dylib" "$READLINE_PREFIX/lib/libreadline.a"; do
  if [[ -f "$candidate" ]]; then READLINE_LIB="$candidate"; break; fi
done
[[ -n "$READLINE_LIB" ]] || { echo "ERROR: GNU Readline library not found under $READLINE_PREFIX/lib"; exit 25; }
echo "[readline] Using: $READLINE_PREFIX"
grep -E 'rl_done|rl_event_hook' "$READLINE_PREFIX/include/readline/readline.h" | head -4 || true

CMAKE_COMMON=(
  -DCMAKE_BUILD_TYPE=Release
  "-DCMAKE_INSTALL_PREFIX=$INSTALL"
  -DTOOLS_BUILD=none
  -DSCRIPTS=static
  -DMODULES=static
  "-DREADLINE_INCLUDE_DIR=$READLINE_PREFIX/include"
  "-DREADLINE_LIBRARY=$READLINE_LIB"
  "-DCMAKE_PREFIX_PATH=$READLINE_PREFIX"
  "-DCMAKE_INCLUDE_PATH=$READLINE_PREFIX/include"
  "-DCMAKE_LIBRARY_PATH=$READLINE_PREFIX/lib"
)

echo "[3/6] Configuring AzerothCore build…"
# Purge stale Readline detection before reconfigure.
rm -f "$BUILD/CMakeCache.txt"
rm -rf "$BUILD/CMakeFiles"

if command -v ninja >/dev/null 2>&1; then
  "$CMAKE" -S "$CORE" -B "$BUILD" -G Ninja "${CMAKE_COMMON[@]}"
else
  "$CMAKE" -S "$CORE" -B "$BUILD" "${CMAKE_COMMON[@]}"
fi

echo "[4/6] Building worldserver + authserver…"
echo "This is the longest stage. CMake/Ninja output below is live:"
"$CMAKE" --build "$BUILD" --target worldserver authserver -- -j1
echo "[5/6] Installing rebuilt server…"
"$CMAKE" --install "$BUILD"

# Install default module config if dist exists.
CONF_SRC="$DST/conf/mod_dungeon_clear.conf.dist"
if [[ -f "$CONF_SRC" ]]; then
  for confdir in "$INSTALL/etc" "$INSTALL/etc/modules" "$INSTALL"; do
    if [[ -d "$confdir" ]]; then
      cp -f "$CONF_SRC" "$confdir/mod_dungeon_clear.conf"
      echo "Config installed: $confdir/mod_dungeon_clear.conf"
      break
    fi
  done
fi

WORLD="$(find "$INSTALL" "$BUILD" -type f -name worldserver -perm -111 2>/dev/null | head -1 || true)"
[[ -n "$WORLD" ]] || { echo "ERROR: rebuilt worldserver not found."; exit 23; }
echo "worldserver: $WORLD"
echo "[6/6] Deploying rebuilt Dungeon Clear server into WoWCC runtime…"

PROFILE="$BASE/runtime/profiles/wotlk"
mkdir -p "$PROFILE/bin" "$PROFILE/configs" "$PROFILE/etc/modules"

AUTH="$INSTALL/bin/authserver"
[[ -x "$WORLD" ]] || { echo "ERROR: rebuilt worldserver is not executable."; exit 26; }
[[ -x "$AUTH" ]] || { echo "ERROR: rebuilt authserver is not executable."; exit 27; }

# Stop is intentionally left to WoWCC/user. Atomic replacement means the next
# restart launches these exact module-enabled binaries.
cp -f "$WORLD" "$PROFILE/bin/worldserver.new"
chmod 755 "$PROFILE/bin/worldserver.new"
mv -f "$PROFILE/bin/worldserver.new" "$PROFILE/bin/worldserver"

cp -f "$AUTH" "$PROFILE/bin/authserver.new"
chmod 755 "$PROFILE/bin/authserver.new"
mv -f "$PROFILE/bin/authserver.new" "$PROFILE/bin/authserver"

# Keep runtime module config where WoWCC/AzerothCore config discovery can see it.
if [[ -f "$INSTALL/etc/modules/mod_dungeon_clear.conf.dist" ]]; then
  cp -f "$INSTALL/etc/modules/mod_dungeon_clear.conf.dist" "$PROFILE/etc/modules/mod_dungeon_clear.conf"
fi
if [[ -f "$INSTALL/etc/mod_dungeon_clear.conf" ]]; then
  cp -f "$INSTALL/etc/mod_dungeon_clear.conf" "$PROFILE/etc/modules/mod_dungeon_clear.conf"
fi

echo "WoWCC runtime worldserver: $PROFILE/bin/worldserver"
echo "WoWCC runtime authserver:  $PROFILE/bin/authserver"
echo "Runtime worldserver SHA256: $(shasum -a 256 "$PROFILE/bin/worldserver" | awk '{print $1}')"
echo "Built worldserver SHA256:   $(shasum -a 256 "$WORLD" | awk '{print $1}')"

RUNTIME_HASH="$(shasum -a 256 "$PROFILE/bin/worldserver" | awk '{print $1}')"
BUILT_HASH="$(shasum -a 256 "$WORLD" | awk '{print $1}')"
[[ "$RUNTIME_HASH" == "$BUILT_HASH" ]] || { echo "ERROR: WoWCC runtime binary verification failed."; exit 28; }

echo "COMPLETE: Dungeon Bot Leader installed AND deployed to WoWCC runtime."
echo "Restart World Server in WoWCC. The next start will use the verified module-enabled binary."
echo "Then enter a dungeon with a tank bot and use: .dc on"
