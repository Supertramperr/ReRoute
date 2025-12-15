#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== PWD =="; pwd; echo

echo "== Detecting Xcode project =="
PROJ_DIR="$(find . -maxdepth 1 -type d -name '*.xcodeproj' -print | sort | head -n1 | sed 's|^\./||')"
if [[ -z "${PROJ_DIR:-}" ]]; then
  echo "ERROR: No *.xcodeproj directory found at repo root."
  echo "Repo root entries:"; ls -la
  exit 1
fi
echo "Project: $PROJ_DIR"
echo

echo "== Project listing =="
xcodebuild -list -project "$PROJ_DIR"
echo

SCHEME="$(xcodebuild -list -project "$PROJ_DIR" | awk '/Schemes:/{f=1;next} f && NF{print $1; exit}')"
if [[ -z "${SCHEME:-}" ]]; then
  SCHEME="$(basename "$PROJ_DIR" .xcodeproj)"
fi
echo "Scheme: $SCHEME"
echo

echo "== Clean build =="
xcodebuild -project "$PROJ_DIR" -scheme "$SCHEME" -destination "platform=macOS" -configuration Debug clean build
echo

echo "== Grep for old folder name/path (should be empty or only backup scripts) =="
grep -RIn --exclude-dir=Build --exclude-dir=DerivedData --exclude-dir=.git "RouterRebootMenubar|/Users/sunkeynar/Documents/RouterRebootMenubar" . || true
echo

echo "== Quick secret scan (tracked) =="
git grep -nEI "routerPassword:\s*String\s*=\s*\"|loginPassword\s*=|Authorization:|Basic |bearer " -- . || true
