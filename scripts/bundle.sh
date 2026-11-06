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
IDENT="Apple Development: parkjs1362@kakao.com (7SZQD87LD8)"
if security find-identity -v -p codesigning | grep -q "$IDENT"; then
  SIGN=("$IDENT")
else
  SIGN=(-)
fi
codesign --force --sign "${SIGN[@]}" --identifier com.joonit.blinders "$APP/Contents/MacOS/Blinders"
codesign --force --sign "${SIGN[@]}" --identifier com.joonit.blinders "$APP"
echo "$APP"
