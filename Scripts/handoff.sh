#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TS="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/ReRoute-handoff-$TS.tgz"

# If this repo uses XcodeGen (project.yml present), exclude generated *.xcodeproj
EXTRA_EXCLUDES=()
if [[ -f "project.yml" || -f "project.yaml" ]]; then
  EXTRA_EXCLUDES+=(--exclude='*.xcodeproj')
fi

tar -czf "$OUT" \
  --exclude='.git' \
  --exclude='DerivedData' \
  --exclude='build' \
  --exclude='.build' \
  --exclude='*.xcuserstate' \
  --exclude='*.xcuserdata' \
  --exclude='*.DS_Store' \
  "${EXTRA_EXCLUDES[@]}" \
  .

echo "ARCHIVE: $OUT"
echo "SIZE:    $(du -h "$OUT" | awk '{print $1}')"
echo
echo "Top-level entries:"
tar -tzf "$OUT" | awk -F/ 'NF{print $1}' | sort -u
