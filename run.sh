#!/bin/zsh
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="Spaceman"
CONFIG="Debug"

echo "🔨 Building $SCHEME..."
xcodebuild \
  -project "$PROJECT_DIR/Spaceman.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)"

BUILT_APP="$(xcodebuild \
  -project "$PROJECT_DIR/Spaceman.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  CODE_SIGNING_ALLOWED=NO \
  -showBuildSettings 2>/dev/null \
  | grep '  BUILT_PRODUCTS_DIR' \
  | awk '{print $3}')/Spaceman.app"

echo "🛑 Stopping existing Spaceman..."
pkill -x Spaceman 2>/dev/null || true
sleep 0.3

echo "🚀 Launching $BUILT_APP"
open "$BUILT_APP"
echo "✅ Done"
