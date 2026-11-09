#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/Blinders.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Blinders "$APP/Contents/MacOS/Blinders"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/Blinders"
# Ad-hoc. An Apple Development signature asks for Developer Tools and makes
# the privacy page open again beside Accessibility.
codesign --force --sign - --identifier com.joonit.blinders "$APP/Contents/MacOS/Blinders"
codesign --force --sign - --identifier com.joonit.blinders "$APP"
echo "$APP"
