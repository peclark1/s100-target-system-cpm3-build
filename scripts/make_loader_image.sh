#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
BASE="$ROOT/reference/S100-cpm3-nonbanked-prop-working-dualcf.img"
SYSTEM="$DIST/CPM3.SYS"
LOADER="$DIST/CPMLDR.COM"
TMP="$DIST/.front-panel-loader-base.img"
OUT="$DIST/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img"

[[ -f "$SYSTEM" ]] || "$ROOT/scripts/build.sh"
[[ -f "$LOADER" ]] || bash "$ROOT/scripts/build_loader.sh"

rm -f "$TMP" "$OUT"
python3 "$ROOT/scripts/install_cpm3.py" "$BASE" "$SYSTEM" "$TMP"
python3 "$ROOT/scripts/install_loader.py" "$TMP" "$LOADER" "$OUT"
rm -f "$TMP"

echo
echo "Front-panel-aware CP/M loader test image ready:"
echo "  $OUT"
