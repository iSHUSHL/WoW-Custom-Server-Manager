#!/bin/bash
set -Eeuo pipefail
PROFILE="$1"; SOURCE="$2"
ROOT="${WOWCC_DATA_ROOT:-$HOME/Library/Application Support/WoWServerControlCenter}"
PR="$ROOT/runtime/profiles/$PROFILE"
mkdir -p "$PR"/{bin,configs,data,logs}
for n in authserver worldserver realmd mangosd; do f="$(find "$SOURCE" -type f -name "$n" -perm -111 2>/dev/null | head -n1 || true)"; [[ -n "$f" ]] && cp -f "$f" "$PR/bin/$n"; done
find "$SOURCE" -type f -name '*.conf*' 2>/dev/null | while read -r f; do cp -f "$f" "$PR/configs/$(basename "$f")" || true; done
echo "Custom core imported into $PROFILE profile."
