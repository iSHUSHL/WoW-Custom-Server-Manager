#!/bin/bash
set -u
CLIENT="${1:-}"
[[ -n "$CLIENT" ]] || { echo "ERROR: WoW client folder is required." >&2; exit 2; }
[[ -d "$CLIENT" ]] || { echo "ERROR: Client folder not found: $CLIENT" >&2; exit 2; }
ADDONS_DIR="$CLIENT/Interface/AddOns"
mkdir -p "$ADDONS_DIR"
TMP="$(mktemp -d /tmp/wowcc-transmog-ui.XXXXXX)" || exit 3
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
ARCHIVE="$TMP/transmog.zip"
SRC=""
export GIT_TERMINAL_PROMPT=0
# First try a bounded shallow clone. Force HTTP/1.1 because some macOS/proxy
# combinations stall during GitHub HTTP/2 negotiation.
if command -v git >/dev/null 2>&1; then
  git -c http.version=HTTP/1.1 clone --depth 1 --single-branch \
    https://github.com/ZhengPeiRu21/transmog-addons.git "$REPO" </dev/null && SRC="$REPO"
fi
# Fallback to GitHub's archive endpoint; this avoids git transport entirely.
if [[ -z "$SRC" ]] && command -v curl >/dev/null 2>&1; then
  rm -rf "$REPO"
  if curl -fL --connect-timeout 15 --max-time 120 --retry 2 --retry-delay 2 \
      -o "$ARCHIVE" https://codeload.github.com/ZhengPeiRu21/transmog-addons/zip/refs/heads/master; then
    if /usr/bin/ditto -x -k "$ARCHIVE" "$TMP/unzip" 2>/dev/null; then
      SRC="$(find "$TMP/unzip" -maxdepth 1 -type d -name 'transmog-addons-*' -print -quit)"
    fi
  fi
fi
[[ -n "$SRC" && -d "$SRC/MogIt" ]] || {
  echo "ERROR: Could not download the Transmog Collection UI from GitHub." >&2
  exit 10
}
addons=(MogIt MogIt_Accessories MogIt_Cloth MogIt_Leather MogIt_Mail MogIt_OneHanded MogIt_Other MogIt_Plate MogIt_Ranged MogIt_TwoHanded transmogTip)
installed=0
for addon in "${addons[@]}"; do
  if [[ -d "$SRC/$addon" ]]; then
    rm -rf "$ADDONS_DIR/$addon"
    /usr/bin/ditto "$SRC/$addon" "$ADDONS_DIR/$addon"
    installed=$((installed+1))
  fi
done
[[ "$installed" -ge 10 ]] || { echo "ERROR: Incomplete addon package ($installed components)." >&2; exit 11; }
echo "Installed $installed Transmog UI components to: $ADDONS_DIR"
echo "In game: enable the MogIt addons, then use .transmog sync"
