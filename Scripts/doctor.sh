#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== PWD =="; pwd; echo

echo "== Project listing =="
if ls *.xcodeproj >/dev/null 2>&1; then
  PROJ="$(ls -1 *.xcodeproj | head -n1)"
  xcodebuild -list -project "$PROJ"
else
  echo "No .xcodeproj found in repo root."
fi
echo

echo "== Clean build =="
if [[ -n "${PROJ:-}" ]]; then
  SCHEME="$(xcodebuild -list -project "$PROJ" | sed -n 's/^    Schemes:$/__SCHEMES__/p;/^        /p' | awk 'NR==1{next} NR==2{print $0}' | xargs || true)"
  # fallback if parsing fails
  [[ -n "$SCHEME" ]] || SCHEME="$(basename "$PROJ" .xcodeproj)"
  xcodebuild -project "$PROJ" -scheme "$SCHEME" -destination "platform=macOS" -configuration Debug clean build
else
  echo "Skipping build (no .xcodeproj)."
fi
echo

echo "== Grep for old folder name/path (should be empty or only backup scripts) =="
grep -RIn --exclude-dir=Build --exclude-dir=DerivedData --exclude-dir=.git "RouterRebootMenubar|/Users/sunkeynar/Documents/RouterRebootMenubar" . || true
echo

echo "== Quick secret scan (tracked) =="
git grep -nEI "routerPassword:\s*String\s*=\s*\"|loginPassword\s*=|Authorization:|Basic |bearer " -- . || true
