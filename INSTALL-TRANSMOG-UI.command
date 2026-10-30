#!/bin/bash
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
echo "WoWCC WotLK 3.3.5a Transmog Collection UI"
printf "Drag your WotLK client folder here and press Return: "
IFS= read -r CLIENT
CLIENT="${CLIENT#\'}"; CLIENT="${CLIENT%\'}"
CLIENT="${CLIENT#\"}"; CLIENT="${CLIENT%\"}"
CLIENT="${CLIENT//\\ / }"
bash "$ROOT/Scripts/install-transmog-ui.sh" "$CLIENT"
RESULT=$?
echo
read -r -p "Press Return to close… " _
exit "$RESULT"
