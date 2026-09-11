#!/bin/bash
set -Eeuo pipefail

PROFILE="${1:-wotlk}"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PROFILE_ROOT="$ROOT/runtime/profiles/$PROFILE"
SRC_ROOT="$ROOT/sources/$PROFILE/core"
BUILD="$ROOT/sources/$PROFILE/build"
mkdir -p "$PROFILE_ROOT"/{bin,configs,data,logs} "$ROOT/sources/$PROFILE" "$ROOT/runtime"

log() { printf '[core:%s] %s\n' "$PROFILE" "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'fail "Core install failed at line $LINENO while running: $BASH_COMMAND"' ERR

# GUI applications do not inherit the user's interactive shell environment.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

BRANCH=""
case "$PROFILE" in
  wotlk) REPO="https://github.com/mod-playerbots/azerothcore-wotlk.git"; BRANCH="Playerbot" ;;
  vanilla) REPO="https://github.com/cmangos/mangos-classic.git" ;;
  tbc) REPO="https://github.com/cmangos/mangos-tbc.git" ;;
  cataclysm) REPO="https://github.com/The-Cataclysm-Preservation-Project/TrinityCore.git" ;;
  mop) REPO="https://github.com/brian8544/TrinityCore-5.4.8.git" ;;
  *) echo "No maintained one-click core assigned to $PROFILE. Use Import Custom Core in the GUI."; exit 20 ;;
esac

for x in git cmake; do command -v "$x" >/dev/null 2>&1 || fail "$x is missing. Click Install Dependencies first."; done

BREW_PREFIX=""
if command -v brew >/dev/null 2>&1; then BREW_PREFIX="$(brew --prefix)"; fi
OPENSSL_PREFIX="$(brew --prefix openssl@3 2>/dev/null || true)"
READLINE_PREFIX="$(brew --prefix readline 2>/dev/null || true)"
MYSQL_PREFIX="$(brew --prefix mysql@8.4 2>/dev/null || brew --prefix mysql 2>/dev/null || true)"

[[ -n "$OPENSSL_PREFIX" ]] || fail "OpenSSL 3 not found. Click Install Dependencies."
[[ -n "$MYSQL_PREFIX" ]] || fail "MySQL 8.4 not found. Click Install Dependencies."

log "Source: $REPO"

# If the profile's maintained upstream changes, do not keep updating the old
# repository in-place. Source/build are disposable; runtime/profile data is not.
if [[ -d "$SRC_ROOT/.git" ]]; then
  CURRENT_ORIGIN="$(git -C "$SRC_ROOT" remote get-url origin 2>/dev/null || true)"
  normalize_git_url() {
    printf '%s' "$1" | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##'
  }
  if [[ "$(normalize_git_url "$CURRENT_ORIGIN")" != "$(normalize_git_url "$REPO")" ]]; then
    log "Core upstream changed for $PROFILE."
    log "Old: $CURRENT_ORIGIN"
    log "New: $REPO"
    log "Replacing source/build only; realm data and selected client are preserved."
    rm -rf "$SRC_ROOT" "$BUILD"
  fi
fi

if [[ ! -d "$SRC_ROOT/.git" ]]; then
  rm -rf "$SRC_ROOT"
  if [[ -n "$BRANCH" ]]; then
    git clone --depth 1 --single-branch --branch "$BRANCH" --recursive "$REPO" "$SRC_ROOT"
  else
    git clone --depth 1 --recursive "$REPO" "$SRC_ROOT"
  fi
else
  if [[ -n "$BRANCH" ]]; then
    git -C "$SRC_ROOT" fetch --depth 1 origin "$BRANCH"
    git -C "$SRC_ROOT" reset --hard "origin/$BRANCH"
  else
    git -C "$SRC_ROOT" fetch --depth 1 origin
    git -C "$SRC_ROOT" reset --hard origin/HEAD
  fi
  git -C "$SRC_ROOT" submodule update --init --recursive
fi

# WotLK PlayerBots requires the maintained Playerbot AzerothCore fork plus the module.
if [[ "$PROFILE" == "wotlk" ]]; then
  WOTLK_BOTS_DIR="$SRC_ROOT/modules/mod-playerbots"
  WOTLK_BOTS_REPO="https://github.com/mod-playerbots/mod-playerbots.git"
  log "Preparing WotLK mod-playerbots module…"

  playerbots_tree_valid() {
    [[ -f "$WOTLK_BOTS_DIR/README.md" ]] && \
    [[ -f "$WOTLK_BOTS_DIR/src/PlayerbotAIConfig.cpp" ]] && \
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

# Official CMaNGOS PlayerBots module. Keep it inside the core tree where
# CMaNGOS CMake expects src/modules/Bots.
if [[ "$PROFILE" == "tbc" ]]; then
  BOTS_DIR="$SRC_ROOT/src/modules/Bots"
  BOTS_REPO="https://github.com/cmangos/playerbots.git"
  log "Preparing official CMaNGOS PlayerBots module…"
  if [[ -d "$BOTS_DIR/.git" ]]; then
    git -C "$BOTS_DIR" fetch --depth 1 origin
    git -C "$BOTS_DIR" reset --hard origin/HEAD
  else
    rm -rf "$BOTS_DIR"
    git clone --depth 1 "$BOTS_REPO" "$BOTS_DIR"
  fi
  [[ -f "$BOTS_DIR/CMakeLists.txt" ]] || fail "PlayerBots module clone is incomplete: $BOTS_DIR"
fi

# WoWCC TBC custom gameplay extensions are source patches and must be
# reapplied after every upstream reset/update before CMake builds mangosd.
if [[ "$PROFILE" == "tbc" ]]; then
  log "Applying WoWCC TBC gameplay patches: Warrior dual-2H + unrestricted mount zones…"
  python3 "$(cd "$(dirname "$0")" && pwd)/apply-tbc-gameplay-patches.py" "$SRC_ROOT"
  log "Applying confirmed GameObject::Use PlayerBots crash fix…"
  python3 "$(cd "$(dirname "$0")" && pwd)/apply-tbc-gameobject-crash-fix.py" "$SRC_ROOT"
fi

# The MoP 5.4.8 fork contains several doubly-mojibaked Russian wchar
# character literals in ObjectMgr.cpp (for declined-name handling). Modern
# Apple Clang rejects them as multi-character wide literals. Replace only the
# four affected single-character comparisons with encoding-independent Unicode
# escape literals. Keep the surrounding declined-name logic intact.
if [[ "$PROFILE" == "mop" ]]; then
  log "Applying MoP modern Clang Unicode compatibility patch…"
  python3 - "$SRC_ROOT" <<'PY'
import pathlib, sys

root = pathlib.Path(sys.argv[1])
obj = root / "src/server/game/Globals/ObjectMgr.cpp"
if not obj.exists():
    raise SystemExit("ERROR: MoP ObjectMgr.cpp not found; Unicode patch cannot continue.")

s = obj.read_text(errors="strict")

# These are double-mojibaked forms of the Russian characters:
#   ь U+044C, е U+0435, о U+043E, ё U+0451
replacements = {
    "L'Ã‘Å’'": r"L'\u044C'",
    "L'ÃÂµ'": r"L'\u0435'",
    "L'ÃÂ¾'": r"L'\u043E'",
    "L'Ã‘â€˜'": r"L'\u0451'",
}

changed = 0
for bad, good in replacements.items():
    count = s.count(bad)
    if count:
        s = s.replace(bad, good)
        changed += count

obj.write_text(s)

# Do not silently continue if one of the known broken literals remains.
remaining = [bad for bad in replacements if bad in s]
if remaining:
    raise SystemExit("ERROR: MoP Unicode patch incomplete: " + ", ".join(remaining))

# The upstream source currently contains six affected comparisons. Requiring
# at least one replacement keeps the patch future-safe without tying it to an
# exact line number that may move between commits.
if changed == 0:
    # A future upstream may already be fixed. Accept that only if the intended
    # Unicode comparisons are already present.
    expected = (r"L'\u044C'", r"L'\u0435'", r"L'\u043E'", r"L'\u0451'")
    if not all(token in s for token in expected):
        raise SystemExit("ERROR: MoP ObjectMgr.cpp layout changed; Unicode patch could not be verified.")

print(f"[core:mop] Unicode patch: repaired {changed} invalid wide-character literal(s)")
PY

  OBJMGR="$SRC_ROOT/src/server/game/Globals/ObjectMgr.cpp"
  if grep -Fq "L'Ã‘Å’'" "$OBJMGR" || \
     grep -Fq "L'ÃÂµ'" "$OBJMGR" || \
     grep -Fq "L'ÃÂ¾'" "$OBJMGR" || \
     grep -Fq "L'Ã‘â€˜'" "$OBJMGR"; then
    fail "MoP Unicode source patch verification failed"
  fi
  log "MoP ObjectMgr Unicode literals are compatible with modern Apple Clang."
fi

if [[ "$PROFILE" == "cataclysm" && "$(uname -m)" == "arm64" ]]; then
  log "Applying Cataclysm Apple Silicon compatibility patch…"
  python3 - "$SRC_ROOT" "$READLINE_PREFIX" <<'PY'
import pathlib, sys

root = pathlib.Path(sys.argv[1])
readline_prefix = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None

cmake = root / "dep/argon2/CMakeLists.txt"
if cmake.exists():
    s = cmake.read_text(errors="ignore")
    old = 'if(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")'
    new = 'if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")'
    if old in s:
        s = s.replace(old, new, 1)
        cmake.write_text(s)
    elif new not in s:
        raise SystemExit("ERROR: Unexpected Argon2 CMake layout; ARM64 patch could not be applied.")

pcg = root / "src/common/Utilities/PCGRand.cpp"
if not pcg.exists():
    raise SystemExit("ERROR: PCGRand.cpp not found; Cata ARM64 patch cannot continue.")

s = pcg.read_text(errors="ignore")

if '#include <emmintrin.h>' in s and 'TCAlignedAlloc16' not in s:
    helper = '''#if defined(__x86_64__) || defined(__i386__)
#include <emmintrin.h>
#else
#include <cstdlib>
#endif

namespace
{
    void* TCAlignedAlloc16(size_t size)
    {
#if defined(__x86_64__) || defined(__i386__)
        return _mm_malloc(size, 16);
#else
        void* ptr = nullptr;
        if (posix_memalign(&ptr, 16, size) != 0)
            return nullptr;
        return ptr;
#endif
    }

    void TCAlignedFree16(void* ptr)
    {
#if defined(__x86_64__) || defined(__i386__)
        _mm_free(ptr);
#else
        std::free(ptr);
#endif
    }
}'''
    s = s.replace('#include <emmintrin.h>', helper, 1)
    s = s.replace('return _mm_malloc(size, 16);', 'return TCAlignedAlloc16(size);')
    s = s.replace('_mm_free(ptr);', 'TCAlignedFree16(ptr);')
    # Restore the x86 implementation inside the helper itself.
    s = s.replace(
        '#if defined(__x86_64__) || defined(__i386__)\n        return TCAlignedAlloc16(size);\n#else',
        '#if defined(__x86_64__) || defined(__i386__)\n        return _mm_malloc(size, 16);\n#else',
        1
    )
    s = s.replace(
        '#if defined(__x86_64__) || defined(__i386__)\n        TCAlignedFree16(ptr);\n#else',
        '#if defined(__x86_64__) || defined(__i386__)\n        _mm_free(ptr);\n#else',
        1
    )
elif 'TCAlignedAlloc16' not in s:
    raise SystemExit("ERROR: Unexpected PCGRand layout; ARM64 patch could not be applied.")

pcg.write_text(s)

# --- g3dlite FileSystem: modern macOS uses stat(), which is already 64-bit safe.
fs = root / "dep/g3dlite/source/FileSystem.cpp"
if not fs.exists():
    raise SystemExit("ERROR: g3dlite FileSystem.cpp not found; Cata macOS patch cannot continue.")

s = fs.read_text(errors="ignore")
if "stat64" in s:
    s = s.replace("struct stat64", "struct stat")
    s = s.replace("::stat64(", "::stat(")
    s = s.replace(" stat64(", " stat(")
    s = s.replace("\tstat64(", "\tstat(")
    fs.write_text(s)

if "struct stat64" in s or "::stat64(" in s:
    raise SystemExit("ERROR: g3dlite stat64 patch did not fully apply.")

# --- CliRunnable: force the real Homebrew GNU Readline header on macOS.
cli = root / "src/server/worldserver/CommandLine/CliRunnable.cpp"
if not cli.exists():
    raise SystemExit("ERROR: Cata CliRunnable.cpp not found.")

if readline_prefix is None:
    raise SystemExit("ERROR: Homebrew GNU Readline prefix was not supplied.")

rl_header = readline_prefix / "include/readline/readline.h"
hist_header = readline_prefix / "include/readline/history.h"
if not rl_header.exists() or not hist_header.exists():
    raise SystemExit(f"ERROR: GNU Readline headers not found under {readline_prefix}/include/readline")

# Verify this really is GNU Readline and exposes the API the Cata source uses.
hdr = rl_header.read_text(errors="ignore")
required = ("rl_abort", "rl_done", "rl_event_hook")
missing = [name for name in required if name not in hdr]
if missing:
    raise SystemExit("ERROR: Selected Readline header does not expose: " + ", ".join(missing))

s = cli.read_text(errors="ignore")
s = s.replace("#include <readline/readline.h>", f'#include "{rl_header}"')
s = s.replace("#include <readline/history.h>", f'#include "{hist_header}"')
cli.write_text(s)

print("[core:cataclysm] ARM64 patch: Argon2 processor detection fixed")
print("[core:cataclysm] ARM64 patch: PCGRand SSE allocation replaced with portable aligned allocation")
print("[core:cataclysm] macOS patch: g3dlite stat64 replaced with stat")
print(f"[core:cataclysm] Readline patch: forced GNU headers from {readline_prefix}")
PY

  grep -q 'MATCHES "^(aarch64|arm64)$"' "$SRC_ROOT/dep/argon2/CMakeLists.txt" || fail "Cata ARM64 Argon2 patch verification failed"
  grep -q 'TCAlignedAlloc16' "$SRC_ROOT/src/common/Utilities/PCGRand.cpp" || fail "Cata ARM64 PCGRand patch verification failed"
  if grep -Eq 'struct[[:space:]]+stat64|::stat64\(' "$SRC_ROOT/dep/g3dlite/source/FileSystem.cpp"; then
    fail "Cata macOS g3dlite stat64 patch verification failed"
  fi
  grep -Fq "$READLINE_PREFIX/include/readline/readline.h" "$SRC_ROOT/src/server/worldserver/CommandLine/CliRunnable.cpp" || fail "Cata GNU Readline source patch verification failed"
  log "Cataclysm source patched for native arm64 / modern macOS / GNU Readline."
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"

JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
ARCH="$(uname -m)"
log "Configuring for macOS $ARCH"

if [[ "$PROFILE" == "wotlk" ]]; then
  MYSQL_INCLUDE=""
  MYSQL_LIBRARY=""
  for p in "$MYSQL_PREFIX/include/mysql" "$BREW_PREFIX/include/mysql"; do [[ -d "$p" ]] && MYSQL_INCLUDE="$p" && break; done
  for p in "$MYSQL_PREFIX/lib/libmysqlclient.dylib" "$BREW_PREFIX/lib/libmysqlclient.dylib"; do [[ -f "$p" ]] && MYSQL_LIBRARY="$p" && break; done
  [[ -n "$MYSQL_INCLUDE" ]] || fail "MySQL headers were not found under $MYSQL_PREFIX"
  [[ -n "$MYSQL_LIBRARY" ]] || fail "libmysqlclient.dylib was not found under $MYSQL_PREFIX"

  CMAKE_ARGS=(
    -S "$SRC_ROOT" -B "$BUILD"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$PROFILE_ROOT"
    -DTOOLS_BUILD=all
    -DSCRIPTS=static
    -DMYSQL_ADD_INCLUDE_PATH="$MYSQL_INCLUDE"
    -DMYSQL_LIBRARY="$MYSQL_LIBRARY"
    -DOPENSSL_INCLUDE_DIR="$OPENSSL_PREFIX/include"
    -DOPENSSL_SSL_LIBRARIES="$OPENSSL_PREFIX/lib/libssl.dylib"
    -DOPENSSL_CRYPTO_LIBRARIES="$OPENSSL_PREFIX/lib/libcrypto.dylib"
  )
  if [[ -n "$READLINE_PREFIX" ]]; then
    CMAKE_ARGS+=(
      -DREADLINE_INCLUDE_DIR="$READLINE_PREFIX/include"
      -DREADLINE_LIBRARY="$READLINE_PREFIX/lib/libreadline.dylib"
    )
  fi
  cmake "${CMAKE_ARGS[@]}"
elif [[ "$PROFILE" == "vanilla" || "$PROFILE" == "tbc" ]]; then
  # Current CMaNGOS requires C++20, Boost >= 1.70, ICU on macOS,
  # MySQL and OpenSSL >= 3. Explicit Homebrew roots are required when
  # the installer is launched from a GUI app with a minimal environment.
  MYSQL_INCLUDE=""
  MYSQL_LIBRARY=""
  for p in "$MYSQL_PREFIX/include/mysql" "$BREW_PREFIX/include/mysql"; do [[ -d "$p" ]] && MYSQL_INCLUDE="$p" && break; done
  for p in "$MYSQL_PREFIX/lib/libmysqlclient.dylib" "$BREW_PREFIX/lib/libmysqlclient.dylib"; do [[ -f "$p" ]] && MYSQL_LIBRARY="$p" && break; done

  BOOST_PREFIX="$(brew --prefix boost 2>/dev/null || true)"
  ICU_PREFIX="$(brew --prefix icu4c 2>/dev/null || true)"
  if [[ -z "$ICU_PREFIX" ]]; then
    # Homebrew may expose ICU only as a versioned formula.
    for f in icu4c@78 icu4c@77 icu4c@76; do
      ICU_PREFIX="$(brew --prefix "$f" 2>/dev/null || true)"
      [[ -n "$ICU_PREFIX" ]] && break
    done
  fi

  [[ -n "$BOOST_PREFIX" ]] || fail "Boost was not found. Run Install Dependencies first."
  [[ -n "$ICU_PREFIX" ]] || fail "ICU was not found. Run Install Dependencies first."
  [[ -n "$OPENSSL_PREFIX" ]] || fail "OpenSSL 3 was not found. Run Install Dependencies first."
  [[ -n "$MYSQL_INCLUDE" ]] || fail "MySQL headers were not found under $MYSQL_PREFIX"
  [[ -n "$MYSQL_LIBRARY" ]] || fail "libmysqlclient.dylib was not found under $MYSQL_PREFIX"

  log "$PROFILE CMaNGOS dependencies:"
  log "  Boost:   $BOOST_PREFIX"
  log "  ICU:     $ICU_PREFIX"
  log "  OpenSSL: $OPENSSL_PREFIX"
  log "  MySQL:   $MYSQL_PREFIX"

  PREFIX_PATH="$BOOST_PREFIX;$ICU_PREFIX;$OPENSSL_PREFIX;$MYSQL_PREFIX"

  export BOOST_ROOT="$BOOST_PREFIX"
  export BOOST_LIBRARYDIR="$BOOST_PREFIX/lib"
  export CPPFLAGS="-I$BOOST_PREFIX/include -I$ICU_PREFIX/include -I$OPENSSL_PREFIX/include -I$MYSQL_INCLUDE ${CPPFLAGS:-}"
  export LDFLAGS="-L$BOOST_PREFIX/lib -L$ICU_PREFIX/lib -L$OPENSSL_PREFIX/lib -L$MYSQL_PREFIX/lib ${LDFLAGS:-}"
  export PKG_CONFIG_PATH="$ICU_PREFIX/lib/pkgconfig:$OPENSSL_PREFIX/lib/pkgconfig:$MYSQL_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

  CMAKE_ARGS=(
    -S "$SRC_ROOT" -B "$BUILD"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$PROFILE_ROOT"
    -DBUILD_GAME_SERVER=ON
    -DBUILD_LOGIN_SERVER=ON
    -DBUILD_PLAYERBOTS=$([[ "$PROFILE" == "tbc" ]] && echo ON || echo OFF)
    -DBUILD_DOCS=OFF
    -DCMAKE_PREFIX_PATH="$PREFIX_PATH"
    -DBOOST_ROOT="$BOOST_PREFIX"
    -DBoost_ROOT="$BOOST_PREFIX"
    -DICU_ROOT="$ICU_PREFIX"
    -DOPENSSL_ROOT_DIR="$OPENSSL_PREFIX"
    -DOPENSSL_INCLUDE_DIR="$OPENSSL_PREFIX/include"
    -DOPENSSL_SSL_LIBRARY="$OPENSSL_PREFIX/lib/libssl.dylib"
    -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_PREFIX/lib/libcrypto.dylib"
    -DMYSQL_INCLUDE_DIR="$MYSQL_INCLUDE"
    -DMYSQL_LIBRARY="$MYSQL_LIBRARY"
  )

  # Extractors are disabled on Apple Silicon in current CMaNGOS sources.
  if [[ "$ARCH" == "arm64" ]]; then
    CMAKE_ARGS+=( -DBUILD_EXTRACTORS=OFF -DCMAKE_OSX_ARCHITECTURES=arm64 )
  else
    CMAKE_ARGS+=( -DBUILD_EXTRACTORS=ON )
  fi

  CMAKE_LOG="$PROFILE_ROOT/logs/cmake-$PROFILE-configure.log"
  mkdir -p "$(dirname "$CMAKE_LOG")"
  log "Configuring $PROFILE core with CMake…"
  if ! cmake "${CMAKE_ARGS[@]}" 2>&1 | tee "$CMAKE_LOG"; then
    log "CMake configure failed. Relevant package diagnostics:"
    grep -Ei 'Could NOT find|NOTFOUND|Could not find|missing:|required|Boost|ICU|OpenSSL|MySQL|FindPackageHandleStandardArgs' "$CMAKE_LOG" | tail -n 40 || true
    log "Last CMake lines:"
    tail -n 50 "$CMAKE_LOG" || true
    fail "CMake configure failed for $PROFILE. See $CMAKE_LOG"
  fi
else
  # Cataclysm Preservation and the MoP TrinityCore fork use Trinity-style authserver/worldserver layouts.
  # Keep this generic because community forks change optional CMake flags over time.
  MYSQL_INCLUDE=""
  MYSQL_LIBRARY=""
  for p in "$MYSQL_PREFIX/include/mysql" "$BREW_PREFIX/include/mysql"; do [[ -d "$p" ]] && MYSQL_INCLUDE="$p" && break; done
  for p in "$MYSQL_PREFIX/lib/libmysqlclient.dylib" "$BREW_PREFIX/lib/libmysqlclient.dylib"; do [[ -f "$p" ]] && MYSQL_LIBRARY="$p" && break; done
  BOOST_PREFIX="$(brew --prefix boost 2>/dev/null || true)"
  READLINE_PREFIX="$(brew --prefix readline 2>/dev/null || true)"
  ZLIB_PREFIX="$(brew --prefix zlib 2>/dev/null || true)"

  CMAKE_ARGS=(
    -S "$SRC_ROOT" -B "$BUILD"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$PROFILE_ROOT"
    -DTOOLS=1
    -DSERVERS=1
    -DOPENSSL_ROOT_DIR="$OPENSSL_PREFIX"
  )

  # The Cata fork uses GNU Readline-only symbols such as rl_abort, rl_done
  # and rl_event_hook. macOS may otherwise satisfy <readline/readline.h>
  # through libedit compatibility headers, which do not expose all of them.
  if [[ "$PROFILE" == "cataclysm" ]]; then
    [[ -n "$READLINE_PREFIX" ]] || fail "GNU Readline was not found. Run Install Dependencies first."
    READLINE_INCLUDE="$READLINE_PREFIX/include"
    READLINE_LIBRARY="$READLINE_PREFIX/lib/libreadline.dylib"
    [[ -f "$READLINE_INCLUDE/readline/readline.h" ]] || fail "GNU Readline headers not found under $READLINE_INCLUDE"
    [[ -f "$READLINE_LIBRARY" ]] || fail "GNU Readline library not found at $READLINE_LIBRARY"

    CMAKE_ARGS+=(
      -DREADLINE_INCLUDE_DIR="$READLINE_INCLUDE"
      -DREADLINE_LIBRARY="$READLINE_LIBRARY"
      -DCMAKE_PREFIX_PATH="$READLINE_PREFIX;$OPENSSL_PREFIX;$MYSQL_PREFIX"
      -DCMAKE_C_FLAGS="-I$READLINE_INCLUDE"
      -DCMAKE_CXX_FLAGS="-I$READLINE_INCLUDE"
      -DCMAKE_EXE_LINKER_FLAGS="-L$READLINE_PREFIX/lib -Wl,-rpath,$READLINE_PREFIX/lib"
    )
    log "Cata GNU Readline (forced header+link): $READLINE_PREFIX"
  fi
  if [[ "$PROFILE" == "cataclysm" && "$ARCH" == "arm64" ]]; then
    CMAKE_ARGS+=( -DCMAKE_OSX_ARCHITECTURES=arm64 )
    log "Cata target architecture: native arm64"
  fi

  if [[ "$PROFILE" == "mop" ]]; then
    # TrinityCore-5.4.8 fork supports macOS AArch64 and OpenSSL 3.x.
    CMAKE_ARGS+=(
      -DOPENSSL_ROOT_DIR="$OPENSSL_PREFIX"
      -DOPENSSL_INCLUDE_DIR="$OPENSSL_PREFIX/include"
      -DOPENSSL_SSL_LIBRARY="$OPENSSL_PREFIX/lib/libssl.dylib"
      -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_PREFIX/lib/libcrypto.dylib"
    )
    if [[ "$ARCH" == "arm64" ]]; then
      CMAKE_ARGS+=( -DCMAKE_OSX_ARCHITECTURES=arm64 )
      log "MoP target architecture: native arm64"
    fi
    log "MoP OpenSSL 3: $OPENSSL_PREFIX"
  fi
  [[ -n "$BOOST_PREFIX" ]] && CMAKE_ARGS+=( -DBOOST_ROOT="$BOOST_PREFIX" )
  [[ -n "$MYSQL_INCLUDE" ]] && CMAKE_ARGS+=( -DMYSQL_INCLUDE_DIR="$MYSQL_INCLUDE" -DMYSQL_ADD_INCLUDE_PATH="$MYSQL_INCLUDE" )
  [[ -n "$MYSQL_LIBRARY" ]] && CMAKE_ARGS+=( -DMYSQL_LIBRARY="$MYSQL_LIBRARY" )
  if [[ "$PROFILE" == "mop" ]] && command -v ninja >/dev/null 2>&1; then
    CMAKE_ARGS+=( -G Ninja )
  fi
  if [[ "$PROFILE" == "cataclysm" && -n "$READLINE_PREFIX" ]]; then
    export CPPFLAGS="-I$READLINE_PREFIX/include ${CPPFLAGS:-}"
    export LDFLAGS="-L$READLINE_PREFIX/lib ${LDFLAGS:-}"
    export PKG_CONFIG_PATH="$READLINE_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  fi

  log "Community core configure: $PROFILE"
  if ! {
    CMAKE_LOG="$PROFILE_ROOT/logs/cmake-$PROFILE-configure.log"
    mkdir -p "$(dirname "$CMAKE_LOG")"
    log "Configuring $PROFILE core with CMake…"
    if ! cmake "${CMAKE_ARGS[@]}" 2>&1 | tee "$CMAKE_LOG"; then
      log "CMake configure failed. Relevant dependency errors:"
      grep -Ei 'Could NOT find|NOTFOUND|Could not find|missing:|required package|FindPackageHandleStandardArgs|OPENSSL|Boost|MySQL|Readline|ZLIB' "$CMAKE_LOG" | tail -n 30 || true
      log "Last CMake lines:"
      tail -n 40 "$CMAKE_LOG" || true
      fail "CMake configure failed for $PROFILE. See $CMAKE_LOG"
    fi
  }; then
    log "Retrying with minimal CMake options for this community fork"
    rm -rf "$BUILD"; mkdir -p "$BUILD"
    MIN_ARGS=( -S "$SRC_ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PROFILE_ROOT" )
    [[ "$PROFILE" == "cataclysm" && "$ARCH" == "arm64" ]] && MIN_ARGS+=( -DCMAKE_OSX_ARCHITECTURES=arm64 )
    if [[ "$PROFILE" == "mop" ]]; then
      MIN_ARGS+=(
        -DOPENSSL_ROOT_DIR="$OPENSSL_PREFIX"
        -DOPENSSL_INCLUDE_DIR="$OPENSSL_PREFIX/include"
        -DOPENSSL_SSL_LIBRARY="$OPENSSL_PREFIX/lib/libssl.dylib"
        -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_PREFIX/lib/libcrypto.dylib"
      )
      [[ "$ARCH" == "arm64" ]] && MIN_ARGS+=( -DCMAKE_OSX_ARCHITECTURES=arm64 )
    fi
    if [[ "$PROFILE" == "cataclysm" ]]; then
      [[ -n "$READLINE_PREFIX" ]] || fail "GNU Readline was not found for Cata fallback configure."
      MIN_ARGS+=(
        -DREADLINE_INCLUDE_DIR="$READLINE_PREFIX/include"
        -DREADLINE_LIBRARY="$READLINE_PREFIX/lib/libreadline.dylib"
        -DCMAKE_PREFIX_PATH="$READLINE_PREFIX;$OPENSSL_PREFIX;$MYSQL_PREFIX"
        -DCMAKE_C_FLAGS="-I$READLINE_PREFIX/include"
        -DCMAKE_CXX_FLAGS="-I$READLINE_PREFIX/include"
        -DCMAKE_EXE_LINKER_FLAGS="-L$READLINE_PREFIX/lib -Wl,-rpath,$READLINE_PREFIX/lib"
      )
    fi
    [[ "$PROFILE" == "mop" && -x "$(command -v ninja 2>/dev/null || true)" ]] && MIN_ARGS+=( -G Ninja )
    cmake "${MIN_ARGS[@]}"
  fi
fi

BUILD_LOG="$ROOT/runtime/${PROFILE}-core-build.log"
mkdir -p "$(dirname "$BUILD_LOG")"
: > "$BUILD_LOG"

# Older community Cata/MoP forks can hide the real compiler diagnostic behind
# GNU make/Ninja parallel output on modern macOS. Build them conservatively.
if [[ "$PROFILE" == "cataclysm" || "$PROFILE" == "mop" ]]; then
  COMMUNITY_JOBS=1
  log "Building community core in compatibility mode (1 job)"
  if ! cmake --build "$BUILD" --config Release --parallel "$COMMUNITY_JOBS" 2>&1 | tee -a "$BUILD_LOG"; then
    log "Build failed. Re-running verbosely to capture the first real compiler error…"
    if ! cmake --build "$BUILD" --config Release --parallel 1 --verbose 2>&1 | tee -a "$BUILD_LOG"; then
      DIAG="$(grep -E -i '(^|: )(fatal error:|error:|undefined symbols|ld: |clang: error|cmake error)' "$BUILD_LOG" | tail -n 8 || true)"
      [[ -z "$DIAG" ]] && DIAG="$(tail -n 30 "$BUILD_LOG" || true)"
      printf '\nBUILD_DIAGNOSTIC_BEGIN\n%s\nBUILD_DIAGNOSTIC_END\n' "$DIAG" >&2
      fail "Community core compilation failed. See $BUILD_LOG"
    fi
  fi
else
  log "Building with $JOBS parallel job(s)"
  if ! cmake --build "$BUILD" --config Release --parallel "$JOBS" 2>&1 | tee -a "$BUILD_LOG"; then
    log "Parallel build failed. Re-running one job verbosely to expose the real error…"
    if ! cmake --build "$BUILD" --config Release --parallel 1 --verbose 2>&1 | tee -a "$BUILD_LOG"; then
      DIAG="$(grep -E -i '(^|: )(fatal error:|error:|undefined symbols|ld: |clang: error|cmake error)' "$BUILD_LOG" | tail -n 8 || true)"
      [[ -z "$DIAG" ]] && DIAG="$(tail -n 30 "$BUILD_LOG" || true)"
      printf '\nBUILD_DIAGNOSTIC_BEGIN\n%s\nBUILD_DIAGNOSTIC_END\n' "$DIAG" >&2
      fail "Core compilation failed. See $BUILD_LOG"
    fi
  fi
fi

log "Installing core into $PROFILE_ROOT"
cmake --install "$BUILD" --config Release

# WotLK extractor recovery. The Playerbot fork can expose extractor targets
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
        if [[ -n "$found" ]]; then printf '%s\n' "$found"; return 0; fi
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

  for candidate in \
    "$BUILD/bin/mmaps-config.yaml" \
    "$ROOT/sources/$PROFILE/extractor-build/bin/mmaps-config.yaml" \
    "$SRC_ROOT/src/tools/mmaps_generator/mmaps-config.yaml"; do
    if [[ -s "$candidate" ]]; then cp -f "$candidate" "$PROFILE_ROOT/bin/mmaps-config.yaml"; break; fi
  done
  [[ -s "$PROFILE_ROOT/bin/mmaps-config.yaml" ]] || fail "WotLK mmaps-config.yaml was not installed. See cmake-wotlk-extractors.log in WoWCC Logs."
  log "WotLK extractors ready: mapextractor, vmap4extractor, vmap4assembler, mmaps_generator"
fi

# Normalize common install layouts into the Control Center layout.
find "$PROFILE_ROOT" -type f \( -name authserver -o -name worldserver -o -name realmd -o -name mangosd -o -name dbimport -o -name mapextractor -o -name vmap4extractor -o -name vmap4assembler -o -name mmaps_generator \) -perm -111 2>/dev/null | while IFS= read -r f; do
  [[ "$f" == "$PROFILE_ROOT/bin/$(basename "$f")" ]] || cp -f "$f" "$PROFILE_ROOT/bin/$(basename "$f")"
done

# Config files may be generated as .conf.dist, .conf.dist.in, or installed into etc/.
for base in authserver worldserver realmd mangosd; do
  found="$(find "$PROFILE_ROOT" "$BUILD" "$SRC_ROOT" -type f \( -name "$base.conf.dist" -o -name "$base.conf" \) 2>/dev/null | head -n1 || true)"
  [[ -n "$found" ]] && cp -f "$found" "$PROFILE_ROOT/configs/$base.conf"
done

if [[ "$PROFILE" == "wotlk" ]]; then
  BOT_DIST="$(find "$PROFILE_ROOT" "$BUILD" "$SRC_ROOT/modules/mod-playerbots" -type f -name 'playerbots.conf.dist' 2>/dev/null | head -n1 || true)"
  if [[ -n "$BOT_DIST" ]]; then
    mkdir -p "$PROFILE_ROOT/configs" "$PROFILE_ROOT/etc/modules"
    [[ -f "$PROFILE_ROOT/configs/playerbots.conf" ]] || cp -f "$BOT_DIST" "$PROFILE_ROOT/configs/playerbots.conf"
    cp -f "$PROFILE_ROOT/configs/playerbots.conf" "$PROFILE_ROOT/etc/modules/playerbots.conf"
    log "Installed WotLK playerbots.conf; use the PlayerBots page to tune population."
  fi
  [[ -f "$PROFILE_ROOT/configs/playerbots.conf" ]] || fail "WotLK PlayerBots built but playerbots.conf was not found after install"
fi

if [[ "$PROFILE" == "tbc" ]]; then
  BOT_DIST="$(find "$PROFILE_ROOT" "$BUILD" "$SRC_ROOT/src/modules/Bots" -type f -name 'aiplayerbot.conf.dist' 2>/dev/null | head -n1 || true)"
  if [[ -n "$BOT_DIST" && ! -f "$PROFILE_ROOT/configs/aiplayerbot.conf" ]]; then
    cp -f "$BOT_DIST" "$PROFILE_ROOT/configs/aiplayerbot.conf"
    log "Installed default aiplayerbot.conf; use the PlayerBots page to tune population."
  fi
  [[ -f "$PROFILE_ROOT/configs/aiplayerbot.conf" ]] || fail "PlayerBots built but aiplayerbot.conf was not found after install"
fi

if [[ "$PROFILE" == "vanilla" || "$PROFILE" == "tbc" ]]; then
  [[ -x "$PROFILE_ROOT/bin/realmd" ]] || fail "Build finished but realmd was not installed. See runtime/installer.log"
  [[ -x "$PROFILE_ROOT/bin/mangosd" ]] || fail "Build finished but mangosd was not installed. See runtime/installer.log"
else
  [[ -x "$PROFILE_ROOT/bin/authserver" ]] || fail "Build finished but authserver was not installed. See runtime/installer.log"
  [[ -x "$PROFILE_ROOT/bin/worldserver" ]] || fail "Build finished but worldserver was not installed. See runtime/installer.log"
fi

printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PROFILE_ROOT/.core-installed"
log "CORE READY"
log "Next: Select Client -> Prepare Client Data -> Setup Realm"
