#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$0")"
ROOT="$PWD"
BUILDROOT="$ROOT/Build"
APP="$BUILDROOT/WoW Server Control Center.app"
BUNDLE_ID="com.dualtonelab.wowcontrolcenter"
EXECUTABLE="WoWServerControlCenter"

banner() { printf '\n============================================================\n  %s\n============================================================\n' "$1"; }
fail() { echo "❌ $1"; echo; read -r -p "Press Return to close…" _ || true; exit 1; }

banner "WoW Server Control Center — Release Builder"

if ! command -v xcrun >/dev/null 2>&1; then
  fail "Apple Command Line Tools are missing. Run: xcode-select --install"
fi
if ! xcrun --find swift >/dev/null 2>&1; then
  fail "Swift compiler was not found. Install Apple Command Line Tools/Xcode once; Xcode does not need to be opened to build this project."
fi

MACOS_SDK="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
[[ -n "$MACOS_SDK" ]] || fail "macOS SDK was not found."

echo "✓ Swift: $(xcrun swift --version | head -n 1)"
echo "✓ SDK:   $MACOS_SDK"
echo "✓ Arch:  $(uname -m)"

banner "Provisioning build/runtime dependencies"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing it automatically..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || fail "Homebrew installation failed."
  if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
fi
if command -v brew >/dev/null 2>&1; then
  echo "Ensuring CMake, Boost, OpenSSL and MySQL 8.4 are available..."
  brew list cmake >/dev/null 2>&1 || brew install cmake
  brew list boost >/dev/null 2>&1 || brew install boost
  brew list openssl@3 >/dev/null 2>&1 || brew install openssl@3
  brew list mysql@8.4 >/dev/null 2>&1 || brew install mysql@8.4
  brew list git >/dev/null 2>&1 || brew install git
  brew list readline >/dev/null 2>&1 || brew install readline
  brew list pkgconf >/dev/null 2>&1 || brew install pkgconf
else
  fail "Homebrew is required to provision the server runtime."
fi

banner "Building release binary"
rm -rf "$BUILDROOT"
mkdir -p "$BUILDROOT"
xcrun swift build -c release

BIN_PATH="$(xcrun swift build -c release --show-bin-path)/$EXECUTABLE"
[[ -x "$BIN_PATH" ]] || fail "Build completed but $EXECUTABLE was not produced."

banner "Creating macOS application bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/WoWCC/Scripts" "$APP/Contents/Resources/WoWCC/runtime-template"
cp "$BIN_PATH" "$APP/Contents/MacOS/$EXECUTABLE"
cp -R "$ROOT/Scripts/." "$APP/Contents/Resources/WoWCC/Scripts/"
if [[ -d "$ROOT/runtime" ]]; then
  cp -R "$ROOT/runtime/." "$APP/Contents/Resources/WoWCC/runtime-template/"
else
  echo "ℹ️ No source runtime template directory found; continuing with an empty runtime-template."
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>WoW Server Control Center</string>
  <key>CFBundleDisplayName</key><string>WoW Server Control Center</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.6.8</string>
  <key>CFBundleVersion</key><string>1608</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
</dict>
</plist>
PLIST


banner "Embedding macOS Dock/Finder icon"
ICONSET="$ROOT/Resources/AppIcon.iconset"
ICON_ICNS="$ROOT/Resources/AppIcon.icns"
APP_RESOURCES="$APP/Contents/Resources"

[[ -d "$ICONSET" ]] || fail "AppIcon.iconset is missing from Resources."

rm -f "$ICON_ICNS"
iconutil -c icns "$ICONSET" -o "$ICON_ICNS" || fail "Could not create AppIcon.icns."
[[ -s "$ICON_ICNS" ]] || fail "AppIcon.icns was not created."

cp "$ICON_ICNS" "$APP_RESOURCES/AppIcon.icns"
[[ -s "$APP_RESOURCES/AppIcon.icns" ]] || fail "AppIcon.icns was not embedded into the app bundle."

# Validate the plist and force Finder/Dock to notice the completed bundle.
plutil -lint "$APP/Contents/Info.plist" >/dev/null || fail "Generated Info.plist is invalid."
touch "$APP"
echo "✓ Icon embedded: $APP_RESOURCES/AppIcon.icns"

chmod +x "$APP/Contents/MacOS/$EXECUTABLE"
find "$APP/Contents/Resources/WoWCC/Scripts" -type f -name '*.sh' -exec chmod +x {} \;

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

# Final icon sanity check.
ICON_PLIST_VALUE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP/Contents/Info.plist" 2>/dev/null || true)"
[[ "$ICON_PLIST_VALUE" == "AppIcon.icns" ]] || fail "Info.plist does not reference AppIcon.icns."
[[ -s "$APP/Contents/Resources/AppIcon.icns" ]] || fail "Final app bundle is missing AppIcon.icns."
echo "✓ Finder/Dock icon verification passed."

# Refresh LaunchServices/Finder icon cache for the newly built bundle.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true
fi
touch "$APP"



cat > "$BUILDROOT/README-FIRST.txt" <<'TXT'
WoW Server Control Center

1. Open "WoW Server Control Center.app".
2. Open Setup Guide and follow the numbered steps for the selected expansion.
3. In Expansion Manager click Install Selected Core.
4. Link your legally obtained compatible WoW client once.
5. Click Prepare Client Data, then Setup Realm.
6. Click Start & Play.
7. Use Characters / Items & Gear / Mounts / Accounts for administration.

The application stores writable server data under:
~/Library/Application Support/WoWServerControlCenter/

Blizzard game clients are not included.
TXT

banner "BUILD COMPLETE"
echo "App: $APP"
echo
echo "You can launch it now from the Build folder."
open "$BUILDROOT" 2>/dev/null || true
echo
read -r -p "Press Return to close…" _ || true
