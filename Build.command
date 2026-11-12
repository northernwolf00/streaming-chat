#!/bin/bash
#
# Build.command — double-click in Finder to build & run StreamingChat
# in the iOS Simulator. No manual setup required.
#
set -euo pipefail

# Always run from the folder that contains this script.
cd "$(dirname "$0")"

SCHEME="StreamingChat"
BUNDLE_ID="com.northernwolf.streamingchat"
DERIVED="build"

echo "============================================"
echo "  StreamingChat — build & run"
echo "============================================"

# 1. Make sure XcodeGen is available (it generates the .xcodeproj).
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "==> xcodegen not found."
  if command -v brew >/dev/null 2>&1; then
    echo "==> Installing xcodegen via Homebrew..."
    brew install xcodegen
  else
    echo "ERROR: xcodegen is required. Install Homebrew (https://brew.sh) then: brew install xcodegen"
    read -r -p "Press Enter to close..."
    exit 1
  fi
fi

# 2. Generate the Xcode project from project.yml.
echo "==> Generating Xcode project (xcodegen)..."
xcodegen generate

# 3. Pick an iOS Simulator (prefer an already-booted one, else first available iPhone).
echo "==> Locating an iOS Simulator..."
UDID="$(xcrun simctl list devices booted | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || true)"
if [ -z "$UDID" ]; then
  UDID="$(xcrun simctl list devices available | grep -E 'iPhone' | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1 || true)"
fi
if [ -z "$UDID" ]; then
  echo "ERROR: No iPhone simulator found. Open Xcode > Settings > Components and install an iOS runtime."
  read -r -p "Press Enter to close..."
  exit 1
fi
echo "    Using simulator UDID: $UDID"

# 4. Build for the simulator.
echo "==> Building (xcodebuild)..."
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" \
  build

# 5. Boot the simulator and open the Simulator app.
echo "==> Booting simulator..."
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

# 6. Install and launch the app.
APP_PATH="$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)"
if [ -z "$APP_PATH" ]; then
  echo "ERROR: Built .app not found."
  read -r -p "Press Enter to close..."
  exit 1
fi
echo "==> Installing app: $APP_PATH"
xcrun simctl install "$UDID" "$APP_PATH"
echo "==> Launching $BUNDLE_ID"
xcrun simctl launch "$UDID" "$BUNDLE_ID" || true

echo ""
echo "============================================"
echo "  Done. The app should be running in the Simulator."
echo "============================================"
