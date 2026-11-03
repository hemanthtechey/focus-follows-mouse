#!/bin/sh
# Builds "Focus Follows Mouse.app" next to this script. ./build.sh --install also copies it to /Applications and opens it.
set -e
cd "$(dirname "$0")"
APP="Focus Follows Mouse.app"
ID=local.focus-follows-mouse
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift make-icon.swift "$APP/Contents/Resources"
swiftc -O -swift-version 5 -target arm64-apple-macos13 focus.swift -o "$APP/Contents/MacOS/FocusFollowsMouse"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleName</key><string>Focus Follows Mouse</string>
  <key>CFBundleExecutable</key><string>FocusFollowsMouse</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppSleepDisabled</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign -s - --force "$APP"
if [ "$1" = "--install" ]; then
  pkill -x FocusFollowsMouse || true
  rm -rf "/Applications/$APP" && cp -R "$APP" /Applications/
  # Each ad-hoc build has a new signature, so the old permission no longer matches: clear it so macOS asks again.
  tccutil reset Accessibility $ID || true
  open "/Applications/$APP"
  echo "Installed. Allow it in the permission prompt; the menu bar icon turns from ⚠ to the cursor icon once allowed."
fi
