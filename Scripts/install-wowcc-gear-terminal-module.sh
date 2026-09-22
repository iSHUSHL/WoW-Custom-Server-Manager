#!/bin/bash
set -euo pipefail
ROOT="${1:-}"
[[ -n "$ROOT" && -d "$ROOT" ]] || { echo "Usage: $0 /path/to/azerothcore"; exit 2; }
SRC="$(cd "$(dirname "$0")/../Resources/mod-wowcc-gear-terminal" && pwd)"
DST="$ROOT/modules/mod-wowcc-gear-terminal"
rm -rf "$DST"
cp -R "$SRC" "$DST"
echo "WoWCC Gear Terminal module installed at: $DST"
echo "Rebuild AzerothCore so the custom Gossip script is compiled."
