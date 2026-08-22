#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-abonly"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }

mkdir -p "$ROOT/tools" "$DIST"
cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"

rm -rf "$BUILD"
mkdir -p "$BUILD/logs"
cp "$ROOT"/src/* "$BUILD/"
cp "$ROOT"/tools/cpm/*.COM "$BUILD/"

# Assemble the A/B-only diagnostic table under the proven module filename.
cp "$ROOT/src/HDRVTBLAB.ASM" "$BUILD/HDRVTBL3.ASM"

modules=(BIOSKRNL SCB3 HBOOT3 CHARIO3 MOVE3 HDRVTBL3 HIDE3)
for m in "${modules[@]}"; do
  echo "RMAC $m"
  "$RUNNER" "$BUILD/RMAC.COM" "$m.ASM" >"$BUILD/logs/$m.rmac.log" 2>&1
  grep -q "END OF ASSEMBLY" "$BUILD/logs/$m.rmac.log" || {
    cat "$BUILD/logs/$m.rmac.log" >&2
    echo "RMAC failed for $m" >&2
    exit 1
  }
done

echo "LINK BIOS3 (Dual CF A/B only diagnostic)"
"$RUNNER" "$BUILD/LINK.COM" \
  'BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3' \
  >"$BUILD/logs/link.log" 2>&1
if grep -qi "UNDEFINED" "$BUILD/logs/link.log"; then
  cat "$BUILD/logs/link.log" >&2
  echo "LINK reported undefined symbols" >&2
  exit 1
fi

echo "GENCPM AUTO"
"$RUNNER" "$BUILD/GENCPM.COM" AUTO >"$BUILD/logs/gencpm.log" 2>&1
grep -q 'CP/M 3.0 SYSTEM GENERATION DONE' "$BUILD/logs/gencpm.log" || {
  cat "$BUILD/logs/gencpm.log" >&2
  echo "GENCPM did not report successful generation" >&2
  exit 1
}

cp "$BUILD/CPM3.SYS" "$DIST/CPM3-ABONLY.SYS"
cp "$BUILD/BIOS3.SPR" "$DIST/BIOS3-ABONLY.SPR"
cp "$BUILD/BIOS3.SYM" "$DIST/BIOS3-ABONLY.SYM"

sys_sha="$(sha256sum "$DIST/CPM3-ABONLY.SYS" | awk '{print $1}')"
sys_size="$(stat -c %s "$DIST/CPM3-ABONLY.SYS")"

echo
echo "SUCCESS: built Dual-CF A/B-only diagnostic CP/M 3"
printf 'CPM3-ABONLY.SYS: %s bytes\nSHA256: %s\n' "$sys_size" "$sys_sha"
echo "NOTE: C: through P: are intentionally absent in this diagnostic build."
