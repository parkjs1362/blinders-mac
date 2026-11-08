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
# Ad-hoc. An Apple Development signature asks for Developer Tools and makes
# the privacy page open again beside Accessibility.
codesign --force --sign - --identifier com.joonit.blinders "$APP/Contents/MacOS/Blinders"
codesign --force --sign - --identifier com.joonit.blinders "$APP"
echo "$APP"
