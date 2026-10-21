#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/build/Draft Coach.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc Sources/*.swift -target arm64-apple-macos14.0 -o "$APP/Contents/MacOS/DraftCoach" -framework Cocoa -framework SwiftUI -framework Carbon -framework ScreenCaptureKit -O
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DraftCoach</string>
<key>CFBundleIdentifier</key><string>local.sritej.draftcoach</string>
<key>CFBundleName</key><string>Draft Coach</string>
<key>CFBundleDisplayName</key><string>Draft Coach</string>
<key>CFBundleIconFile</key><string>DraftCoach.icns</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleShortVersionString</key><string>1.4</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Capture your Chrome window for draft coaching in Codex or Claude.</string>
<key>NSAppleEventsUsageDescription</key><string>Read the active Chrome tab URL to identify the current 17Lands pack and pick.</string>
</dict></plist>
PLIST
cp "$PWD/Assets/DraftCoach.icns" "$APP/Contents/Resources/DraftCoach.icns"
cp "$PWD/Assets/DraftCoachMenu.png" "$APP/Contents/Resources/DraftCoachMenu.png"
codesign --force --sign - --requirements '=designated => identifier "local.sritej.draftcoach"' "$APP"
"$APP/Contents/MacOS/DraftCoach" --self-test
printf '%s\n' "Built $APP"
# Install where Spotlight and the README expect it, replacing any running copy.
INSTALL="$HOME/Applications/Draft Coach.app"
pkill -x DraftCoach 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$INSTALL"
ditto "$APP" "$INSTALL"
printf '%s\n' "Installed $INSTALL"
