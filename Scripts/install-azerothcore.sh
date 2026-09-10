#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.buildsrc/azerothcore"
BUILD="$SRC/build"
INSTALL="$ROOT/runtime/acore-install"
ARCH="$(uname -m)"

command -v brew >/dev/null || { echo "Homebrew missing. Run Scripts/bootstrap-macos.sh first."; exit 1; }
command -v git >/dev/null || { echo "git missing"; exit 1; }
command -v cmake >/dev/null || { echo "cmake missing"; exit 1; }

mkdir -p "$ROOT/.buildsrc" "$ROOT/runtime/bin" "$ROOT/runtime/configs" "$ROOT/runtime/data"
if [[ ! -d "$SRC/.git" ]]; then
  git clone https://github.com/azerothcore/azerothcore-wotlk.git --branch master --single-branch --depth 1 "$SRC"
else
  git -C "$SRC" pull --ff-only
fi

rm -rf "$BUILD" && mkdir -p "$BUILD"
cd "$BUILD"
export OPENSSL_ROOT_DIR="$(brew --prefix openssl@3)"
BREW_PREFIX="$(brew --prefix)"
MYSQL_PREFIX="$(brew --prefix mysql@8.4 2>/dev/null || brew --prefix mysql)"
READLINE_PREFIX="$(brew --prefix readline)"

cmake ../ \
  -DCMAKE_INSTALL_PREFIX="$INSTALL" \
  -DTOOLS_BUILD=all \
  -DSCRIPTS=static \
  -DMYSQL_ADD_INCLUDE_PATH="$MYSQL_PREFIX/include/mysql" \
  -DMYSQL_LIBRARY="$MYSQL_PREFIX/lib/libmysqlclient.dylib" \
  -DREADLINE_INCLUDE_DIR="$READLINE_PREFIX/include" \
  -DREADLINE_LIBRARY="$READLINE_PREFIX/lib/libreadline.dylib" \
  -DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT_DIR/include" \
  -DOPENSSL_SSL_LIBRARIES="$OPENSSL_ROOT_DIR/lib/libssl.dylib" \
  -DOPENSSL_CRYPTO_LIBRARIES="$OPENSSL_ROOT_DIR/lib/libcrypto.dylib"

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
cmake --build . --parallel "$JOBS"
cmake --install .

AUTH="$(find "$INSTALL" -type f -name authserver -perm +111 | head -1 || true)"
WORLD="$(find "$INSTALL" -type f -name worldserver -perm +111 | head -1 || true)"
[[ -n "$AUTH" && -n "$WORLD" ]] || { echo "Build finished but server binaries were not found."; exit 1; }
cp "$AUTH" "$ROOT/runtime/bin/authserver"
cp "$WORLD" "$ROOT/runtime/bin/worldserver"
chmod +x "$ROOT/runtime/bin/authserver" "$ROOT/runtime/bin/worldserver"

for DIST in $(find "$INSTALL" -type f \( -name authserver.conf.dist -o -name worldserver.conf.dist \)); do
  NAME="$(basename "$DIST" .dist)"
  cp "$DIST" "$ROOT/runtime/configs/$NAME"
done

echo
printf 'AzerothCore built successfully for %s.\n' "$ARCH"
printf 'Binaries: %s/runtime/bin\n' "$ROOT"
printf 'Configs:  %s/runtime/configs\n' "$ROOT"
printf 'Next required step: add WoW client data (dbc/maps, plus vmaps/mmaps recommended) under runtime/data.\n'
