#!/bin/bash
set -euo pipefail
CLIENT="${1:-}"
[[ -n "$CLIENT" && -d "$CLIENT" ]] || { echo "Usage: $0 /path/to/WotLK-client" >&2; exit 2; }
ADDONS="$CLIENT/Interface/AddOns"
mkdir -p "$ADDONS"
TMP="$(mktemp -d /tmp/wowcc-transmog-ui.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
SRC=""
export GIT_TERMINAL_PROMPT=0
if command -v git >/dev/null 2>&1; then
  if git -c http.version=HTTP/1.1 clone --depth 1 --single-branch https://github.com/ZhengPeiRu21/transmog-addons.git "$REPO" </dev/null; then SRC="$REPO"; fi
fi
if [[ -z "$SRC" ]] && command -v curl >/dev/null 2>&1; then
  if curl -fL --connect-timeout 15 --max-time 120 --retry 2 -o "$TMP/addons.zip" https://codeload.github.com/ZhengPeiRu21/transmog-addons/zip/refs/heads/master &&
    /usr/bin/ditto -x -k "$TMP/addons.zip" "$TMP/extract"; then
    SRC="$(find "$TMP/extract" -maxdepth 1 -type d -name 'transmog-addons-*' -print -quit)"
  fi
fi
[[ -n "$SRC" && -d "$SRC/MogIt" ]] || { echo "ERROR: Could not download MogIt collection UI" >&2; exit 10; }
addons=(MogIt MogIt_Accessories MogIt_Cloth MogIt_Leather MogIt_Mail MogIt_OneHanded MogIt_Other MogIt_Plate MogIt_Ranged MogIt_TwoHanded transmogTip)
for addon in "${addons[@]}"; do
  [[ -d "$SRC/$addon" ]] || { echo "ERROR: Missing $addon" >&2; exit 11; }
done
for addon in "${addons[@]}"; do
  /usr/bin/ditto "$SRC/$addon" "$ADDONS/$addon"
done
echo "Installed ${#addons[@]} addon components to $ADDONS"
echo "Enable MogIt in the WoW character-selection AddOns menu."
