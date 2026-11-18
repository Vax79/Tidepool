#!/bin/bash
# Builds build/Tidepool.app. Usage: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Tidepool.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Tidepool "$APP/Contents/MacOS/Tidepool"
cp Info.plist "$APP/Contents/Info.plist"

# The app draws its own icon from the pufferfish sprite.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
"$APP/Contents/MacOS/Tidepool" --icon build/icon-1024.png
for s in 16 32 128 256 512; do
    sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"
