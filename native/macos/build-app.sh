#!/bin/sh
set -eu
cd "$(dirname "$0")"
rm -rf dist
swift build -c release --arch arm64 --arch x86_64
APP="$PWD/dist/SwitchSound.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/SwitchSound "$APP/Contents/MacOS/SwitchSound"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
