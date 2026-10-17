#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_PATH="$SCRIPT_DIR/SwitchSound.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/SwitchSound"

if [ ! -d "$APP_PATH" ]; then
    echo "SwitchSound.app was not found beside this script."
    exit 1
fi

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "The SwitchSound executable was not found inside SwitchSound.app."
    exit 1
fi

xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
if xattr -pr com.apple.quarantine "$APP_PATH" >/dev/null 2>&1; then
    echo "SwitchSound's quarantine attribute could not be removed."
    exit 1
fi

echo "SwitchSound is ready to open."
open "$APP_PATH"
