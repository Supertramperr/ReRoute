#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUTDIR="$HOME/Documents"
TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$OUTDIR/ReRoute-handoff-$TS.tgz"

rm -f "$ARCHIVE"

tar -czf "$ARCHIVE" \
  -C "$ROOT" \
  --exclude="./.git" \
  --exclude="./DerivedData" \
  --exclude="./build" \
  --exclude="./.build" \
  --exclude="./**/xcuserdata" \
  --exclude="./**/*.xcuserstate" \
  --exclude="./**/.DS_Store" \
  --exclude="./ReRoute-handoff-*.tgz" \
  .

echo "ARCHIVE: $ARCHIVE"
echo -n "SIZE:    "; du -h "$ARCHIVE" | awk '{print $1}'
echo
echo "Top-level entries:"
tar -tzf "$ARCHIVE" | sed 's|^\./||' | awk -F/ 'NF{print $1}' | sort -u
