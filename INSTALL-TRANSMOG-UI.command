#!/bin/bash
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
echo "=== WoWCC Transmog Collection UI Installer ==="
echo "This does NOT rebuild the core or re-extract maps."
echo
printf "Drag your WotLK 3.3.5a client folder here, then press Return: "
IFS= read -r CLIENT
CLIENT="${CLIENT#\'}"; CLIENT="${CLIENT%\'}"; CLIENT="${CLIENT#\"}"; CLIENT="${CLIENT%\"}"
CLIENT="${CLIENT//\\ / }"
"$ROOT/Scripts/install-transmog-ui.sh" "$CLIENT"
rc=$?
echo
if [[ $rc -eq 0 ]]; then
  echo "SUCCESS. Start WoW, enable MogIt addons, then run: .transmog sync"
else
  echo "FAILED (code $rc). Server transmog is unaffected."
fi
read -r -p "Press Return to close…" _
exit $rc
