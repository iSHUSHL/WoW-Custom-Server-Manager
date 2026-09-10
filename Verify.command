#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")"

PASS=0; WARN=0; FAIL=0
ok(){ printf "✅ PASS  %s\n" "$1"; PASS=$((PASS+1)); }
warn(){ printf "⚠️  WARN  %s\n" "$1"; WARN=$((WARN+1)); }
bad(){ printf "❌ FAIL  %s\n" "$1"; FAIL=$((FAIL+1)); }
check_cmd(){ if command -v "$1" >/dev/null 2>&1; then ok "$1: $(command -v "$1")"; else bad "$1 not found"; fi; }

echo "WoW Server Control Center — Full Source / Build Verification"
echo "==========================================================="

# Apple build environment
if command -v xcrun >/dev/null 2>&1; then ok "Apple xcrun available"; else bad "xcrun missing (Command Line Tools required)"; fi
if xcrun --find swift >/dev/null 2>&1; then ok "Swift compiler available"; else bad "Swift compiler missing"; fi
if xcrun --find clang >/dev/null 2>&1; then ok "Clang compiler available"; else bad "Clang compiler missing"; fi

# Source/package integrity
for f in Package.swift Build.command Sources/WoWServerControlCenter/ServerModel.swift Sources/WoWServerControlCenter/ContentView.swift Sources/WoWServerControlCenter/Models.swift Scripts/install-profile.sh Scripts/setup-profile.sh Scripts/prepare-client.sh Scripts/bootstrap-macos.sh; do
  [[ -s "$f" ]] && ok "Present: $f" || bad "Missing: $f"
done

for f in Scripts/*.sh Build.command Verify.command; do
  if bash -n "$f"; then ok "Shell syntax: $f"; else bad "Shell syntax: $f"; fi
done

if command -v swiftc >/dev/null 2>&1; then
  if swiftc -frontend -parse Sources/WoWServerControlCenter/*.swift; then ok "Swift source parser"; else bad "Swift source parser"; fi
else
  warn "swiftc not on PATH; xcrun Swift may still be usable by Build.command"
fi

# Runtime tools. Missing ones are fixable by Build/App dependency installer.
for t in git cmake make; do
  if command -v "$t" >/dev/null 2>&1; then ok "Runtime build tool $t"; else warn "$t not installed yet — Install Dependencies will add it"; fi
done

MYSQL=""
for p in /opt/homebrew/opt/mysql@8.4/bin/mysql /usr/local/opt/mysql@8.4/bin/mysql /opt/homebrew/bin/mysql /usr/local/bin/mysql; do [[ -x "$p" ]] && MYSQL="$p" && break; done
[[ -n "$MYSQL" ]] && ok "MySQL client: $MYSQL" || warn "MySQL 8.4 not installed yet — app can install it"

MYSQLD=""
for p in /opt/homebrew/opt/mysql@8.4/bin/mysqld /usr/local/opt/mysql@8.4/bin/mysqld /opt/homebrew/bin/mysqld /usr/local/bin/mysqld; do [[ -x "$p" ]] && MYSQLD="$p" && break; done
[[ -n "$MYSQLD" ]] && ok "MySQL server: $MYSQLD" || warn "MySQL 8.4 server not installed yet — app can install it"

# Built bundle checks
APP="Build/WoW Server Control Center.app"
if [[ -d "$APP" ]]; then
  ok "Built app bundle exists"
  [[ -x "$APP/Contents/MacOS/WoWServerControlCenter" ]] && ok "App executable exists" || bad "App executable missing"
  [[ -f "$APP/Contents/Info.plist" ]] && ok "Info.plist exists" || bad "Info.plist missing"
  [[ -d "$APP/Contents/Resources/WoWCC/Scripts" ]] && ok "Bundled management scripts exist" || bad "Bundled management scripts missing"
  if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then ok "App bundle signature verifies"; else warn "Ad-hoc signature could not be verified"; fi
else
  warn "App not built yet — double-click Build.command"
fi

echo
echo "Summary: $PASS passed • $WARN warnings • $FAIL failed"
if [[ "$FAIL" -eq 0 ]]; then
  echo "Source/build verification completed successfully. Runtime realm readiness is checked inside Health Checks in the app."
else
  echo "Resolve failed checks before using this build."
fi
read -r -p "Press Return to close…" _ || true
[[ "$FAIL" -eq 0 ]]


if [[ -d "$ROOT/Build/WoW Server Control Center.app" ]]; then
  APP="$ROOT/Build/WoW Server Control Center.app"
  if [[ -s "$APP/Contents/Resources/AppIcon.icns" ]]; then
    echo "✓ App icon: embedded"
  else
    echo "❌ App icon missing: $APP/Contents/Resources/AppIcon.icns"
    FAILURES=$((FAILURES+1))
  fi
  ICON_KEY="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$ICON_KEY" == "AppIcon.icns" ]]; then
    echo "✓ Info.plist icon key: AppIcon.icns"
  else
    echo "❌ Info.plist icon key incorrect: ${ICON_KEY:-missing}"
    FAILURES=$((FAILURES+1))
  fi
fi


if [[ -f "$ROOT/Resources/AppIcon-1024.png" ]]; then
  echo "✓ Full-bleed master icon present"
else
  echo "❌ Full-bleed master icon missing"
  FAILURES=$((FAILURES+1))
fi
