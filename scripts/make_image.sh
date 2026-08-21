#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$ROOT/dist/CPM3.SYS" ]] || "$ROOT/scripts/build.sh"
python3 "$ROOT/scripts/install_cpm3.py" \
  "$ROOT/reference/S100-cpm3-nonbanked-prop-working-dualcf.img" \
  "$ROOT/dist/CPM3.SYS" \
  "$ROOT/dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img"
