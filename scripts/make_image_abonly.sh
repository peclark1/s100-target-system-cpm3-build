#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SYS="$ROOT/dist/CPM3-ABONLY.SYS"
OUT="$ROOT/dist/S100-cpm3-nonbanked-prop-dualcf-abonly-test.img"

[[ -f "$SYS" ]] || "$ROOT/scripts/build-abonly.sh"

python3 "$ROOT/scripts/install_cpm3.py" \
  "$ROOT/reference/S100-cpm3-nonbanked-prop-working-dualcf.img" \
  "$SYS" \
  "$OUT"

echo
echo "A/B-ONLY diagnostic test image ready:"
echo "$OUT"
sha256sum "$OUT"
