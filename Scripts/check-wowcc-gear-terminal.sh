#!/bin/bash
set -euo pipefail
ROOT="${1:-}"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  echo "WoWCC Gear Terminal: AzerothCore root not supplied/found."
  exit 2
fi
MOD="$ROOT/modules/mod-wowcc-gear-terminal"
if [[ ! -f "$MOD/src/WoWCCGearTerminal.cpp" ]]; then
  echo "WoWCC Gear Terminal: module source NOT installed."
  exit 3
fi
echo "WoWCC Gear Terminal: module source installed."
if find "$ROOT" -type f -name worldserver -perm -111 2>/dev/null | head -1 | grep -q .; then
  echo "WoWCC Gear Terminal: worldserver binary exists. Rebuild is required after module install, then restart World Server."
else
  echo "WoWCC Gear Terminal: no built worldserver binary found yet."
fi
