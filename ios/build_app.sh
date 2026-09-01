#!/usr/bin/env bash
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Generate App Icons
SOURCE="../assets/images/store_icon.png"
IOS_ICON_DIR="Runner/Assets.xcassets/AppIcon.appiconset"
MACOS_ICON_DIR="../macos/Runner/Assets.xcassets/AppIcon.appiconset"

if [ -f "$SOURCE" ]; then
    if [ -d "$IOS_ICON_DIR" ]; then
        echo "Generating iOS app icons from $SOURCE..."
        while IFS= read -r icon; do
            name="$(basename "$icon")"
            # Extract points and scale from filename, e.g., Icon-App-20x20@2x.png -> 20 2
            pointsAndScale="$(printf '%s\n' "$name" | sed -E 's/Icon-App-([0-9.]+)x[0-9.]+@([0-9]+)x\.png/\1 \2/')"
            if [[ "$pointsAndScale" =~ ^([0-9.]+)[[:space:]]([0-9]+)$ ]]; then
                points="${BASH_REMATCH[1]}"
                scale="${BASH_REMATCH[2]}"
                pixels="$(awk -v points="$points" -v scale="$scale" 'BEGIN { printf "%d", points * scale }')"
                sips -z "$pixels" "$pixels" "$SOURCE" --out "$icon" >/dev/null
            fi
        done < <(find "$IOS_ICON_DIR" -maxdepth 1 -name 'Icon-App-*.png' -type f)
    fi

    if [ -d "$MACOS_ICON_DIR" ]; then
        echo "Generating macOS app icons from $SOURCE..."
        for pixels in 16 32 64 128 256 512 1024; do
            icon="$MACOS_ICON_DIR/app_icon_${pixels}.png"
            sips -z "$pixels" "$pixels" "$SOURCE" --out "$icon" >/dev/null
        done
    fi
fi

# 2. Build the App
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.gem/ruby/3.4.0/bin:$HOME/.gem/ruby/3.3.0/bin:$HOME/.gem/ruby/3.2.0/bin:$PATH"

WORKSPACE="Runner.xcworkspace"
PROJECT="Runner.xcodeproj"
SCHEME="Runner"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PWD/.derived_data}"

if [ -f "Podfile" ] && { [ ! -d "Pods" ] || [ ! -f "Pods/Manifest.lock" ]; }; then
    if command -v pod >/dev/null 2>&1; then
        echo "Installing iOS CocoaPods dependencies..."
        pod install
    fi
fi

echo "Building $SCHEME for iOS Simulator without code signing..."
XCODE_COMMAND=(
    xcodebuild
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -sdk iphonesimulator
    -destination "generic/platform=iOS Simulator"
    -derivedDataPath "$DERIVED_DATA_PATH"
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    build
)

if [ -d "$WORKSPACE" ]; then
    "${XCODE_COMMAND[@]}" -workspace "$WORKSPACE"
else
    "${XCODE_COMMAND[@]}" -project "$PROJECT"
fi

echo "Build complete."
