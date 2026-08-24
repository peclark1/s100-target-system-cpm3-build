#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
BASE="$DIST/S100-cpm3-nonbanked-prop-dualcf-fdc3712-candidate.img"
OUT="$DIST/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img"

# Build the normal candidate image first.  That path installs only CPM3.SYS
# and deliberately preserves the known-good CPMLDR system-track bytes.
[[ -f "$BASE" ]] || make -C "$ROOT" image

rm -f "$OUT"
python3 "$ROOT/scripts/patch_cpmldr_rom_conout.py" "$BASE" "$OUT"

echo
echo "Four-byte CPMLDR ROM-CONOUT test image ready:"
echo "  $OUT"
