#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYS="$ROOT/dist/CPM3-FDCPLUS.SYS"
OUT="$ROOT/dist/S100-cpm3-nonbanked-prop-dualcf-fdcplus-test.img"

[[ -f "$SYS" ]] || "$ROOT/scripts/build-fdcplus.sh"

python3 "$ROOT/scripts/install_cpm3.py" \
  "$ROOT/reference/S100-cpm3-nonbanked-prop-working-dualcf.img" \
  "$SYS" \
  "$OUT"

echo
echo "EXPERIMENTAL FDC+ test image ready:"
echo "$OUT"
sha256sum "$OUT"
