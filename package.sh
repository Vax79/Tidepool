#!/bin/bash
# Builds a universal (Apple silicon + Intel) Tidepool.app and wraps it in a DMG.
# Usage: ./package.sh   ->  dist/Tidepool-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
swift build -c release --arch arm64 --arch x86_64
BIN=.build/apple/Products/Release/Tidepool

APP=dist/Tidepool.app
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tidepool"
cp Info.plist "$APP/Contents/Info.plist"

ICONSET=dist/AppIcon.iconset
mkdir -p "$ICONSET"
"$APP/Contents/MacOS/Tidepool" --icon dist/icon-1024.png
for s in 16 32 128 256 512; do
    sips -z $s $s dist/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) dist/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" dist/icon-1024.png

# Ad-hoc signature: not notarized, so first launch needs right-click > Open.
codesign --force --sign - "$APP"

STAGE=dist/stage
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/READ ME FIRST.txt" <<'TXT'
Tidepool - pixel-art sea creatures for your desktop

1. Drag Tidepool into the Applications folder.
2. The first time, RIGHT-CLICK Tidepool and choose Open, then Open again.
   (Tidepool isn't signed with an Apple developer certificate, so a normal
   double-click is blocked the first time. On macOS 15 you may instead need
   System Settings > Privacy & Security > "Open Anyway".)
3. Look for the fish icon in the menu bar. That's where every option lives.

Requires macOS 13 or later. Works on Apple silicon and Intel Macs.
TXT
DMG="dist/Tidepool-$VERSION.dmg"
hdiutil create -volname "Tidepool" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Built $DMG"
