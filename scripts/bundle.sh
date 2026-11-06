#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Blinders.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Blinders "$APP/Contents/MacOS/Blinders"
cp Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/Blinders"
codesign --force --sign - "$APP/Contents/MacOS/Blinders"
codesign --force --sign - "$APP"
echo "$APP"
