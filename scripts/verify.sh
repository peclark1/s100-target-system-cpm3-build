#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED_SYS="d714ab2c4742154751ccf1f20af073fcfec0a286b5b4500aadd12f3237d37f7d"
EXPECTED_IMG="0232a9d0c17948eac6701cf5f703054824f610290a745983c71cb7fac4da088a"

[[ -f "$ROOT/dist/CPM3.SYS" ]] || { echo "dist/CPM3.SYS missing; run make" >&2; exit 1; }
sys="$(sha256sum "$ROOT/dist/CPM3.SYS" | awk '{print $1}')"
[[ "$sys" == "$EXPECTED_SYS" ]] || { echo "CPM3.SYS mismatch: $sys" >&2; exit 1; }
echo "CPM3.SYS exact match: $sys"

if [[ -f "$ROOT/dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img" ]]; then
  img="$(sha256sum "$ROOT/dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img" | awk '{print $1}')"
  [[ "$img" == "$EXPECTED_IMG" ]] || { echo "image mismatch: $img" >&2; exit 1; }
  echo "CF image exact match: $img"
fi
