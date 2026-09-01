#!/usr/bin/env bash
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Build the app using the build_app.sh script
./build_app.sh

# 2. Install and launch
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.derived_data}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Runner.app"
BUNDLE_ID="com.example.funSheetMusic"

if ! xcrun simctl list devices booted | grep -q "(Booted)"; then
    echo "No booted simulator found. Open Simulator and boot a device, then run this script again."
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Build finished, but app was not found at:"
    echo "$APP_PATH"
    exit 1
fi

echo "Installing $APP_PATH into the booted simulator..."
xcrun simctl install booted "$APP_PATH"

echo "Launching $BUNDLE_ID..."
xcrun simctl launch booted "$BUNDLE_ID"

echo "Done."
