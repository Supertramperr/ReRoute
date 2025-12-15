#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/Documents/ReRoute"
cp -f "Sources/_backups/20251215-094404-glasspanel/RootMenuView.swift" "Sources/Views/RootMenuView.swift"
cp -f "Sources/_backups/20251215-094404-glasspanel/MoreView.swift" "Sources/Views/MoreView.swift"
if [ -f "Sources/_backups/20251215-094404-glasspanel/GlassPanel.swift" ]; then
  cp -f "Sources/_backups/20251215-094404-glasspanel/GlassPanel.swift" "Sources/Views/GlassPanel.swift"
else
  rm -f "Sources/Views/GlassPanel.swift"
fi

PROJ="$(find . -maxdepth 2 -name "*.xcodeproj" -print -quit)"
SCHEME="$(xcodebuild -list -project "$PROJ" 2>/dev/null | awk '/Schemes:/ {f=1; next} f && NF {print $1; exit}')"
LOG="/tmp/reroute_build.log"
rm -f "$LOG"
xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "platform=macOS" -configuration Debug clean build >"$LOG" 2>&1 || {
  echo "** BUILD FAILED **"
  grep -n -E " error:|fatal error:" "$LOG" | tail -n 220 || true
  echo "Full log: $LOG"
  exit 1
}
TARGET_DIR="$(xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "platform=macOS" -configuration Debug -showBuildSettings 2>/dev/null | sed -n 's/^ *TARGET_BUILD_DIR = //p' | head -n1)"
PROD_NAME="$(xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "platform=macOS" -configuration Debug -showBuildSettings 2>/dev/null | sed -n 's/^ *FULL_PRODUCT_NAME = //p' | head -n1)"
APP_PATH="$TARGET_DIR/$PROD_NAME"
EXE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
pkill -x "$EXE_NAME" 2>/dev/null || true
open -n "$APP_PATH"
echo "Reverted + relaunched: $APP_PATH"
