#!/bin/bash
set -e
cd "$(dirname "$0")"
chmod +x ./*.command 2>/dev/null || true
find ./Scripts -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
xattr -dr com.apple.quarantine . 2>/dev/null || true
open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity' || open '/System/Applications/System Settings.app'
printf '\nWoWCC permissions repaired. Privacy & Security has been opened.\nIf macOS asks, allow the required access for WoW Server Control Center and Terminal.\n\nPress Return to close...'
read -r _
