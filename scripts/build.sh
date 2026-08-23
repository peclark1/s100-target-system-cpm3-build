#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"
EXPECTED_SYS_SHA="c2ad51aaf8638fb0faf939c0f15a971b7d5fb9a0e3846dce2a4aa3c665045b17"

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }

mkdir -p "$ROOT/tools" "$DIST"
cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"

rm -rf "$BUILD"
mkdir -p "$BUILD/logs"
cp "$ROOT"/src/* "$BUILD/"
cp "$ROOT"/tools/cpm/*.COM "$BUILD/"

modules=(BIOSKRNL SCB3 HBOOT3 CHARIO3 MOVE3 HDRVTBL3 HIDE3 FDC3712)
for m in "${modules[@]}"; do
  echo "RMAC $m"
  "$RUNNER" "$BUILD/RMAC.COM" "$m.ASM" >"$BUILD/logs/$m.rmac.log" 2>&1
  grep -q "END OF ASSEMBLY" "$BUILD/logs/$m.rmac.log" || {
    cat "$BUILD/logs/$m.rmac.log" >&2
    echo "RMAC failed for $m" >&2
    exit 1
  }
done

echo "LINK BIOS3"
"$RUNNER" "$BUILD/LINK.COM" \
  'BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,FDC3712' \
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

cp "$BUILD/CPM3.SYS" "$DIST/CPM3.SYS"
cp "$BUILD/BIOS3.SPR" "$DIST/BIOS3.SPR"
cp "$BUILD/BIOS3.SYM" "$DIST/BIOS3.SYM"

got="$(sha256sum "$DIST/CPM3.SYS" | awk '{print $1}')"
if [[ "$got" != "$EXPECTED_SYS_SHA" ]]; then
  echo "ERROR: build completed but CPM3.SYS does not match the reproducible FDC+3712 candidate" >&2
  echo "expected: $EXPECTED_SYS_SHA" >&2
  echo "got:      $got" >&2
  exit 1
fi

echo
printf 'SUCCESS: reproduced FDC+3712 candidate CPM3.SYS\nSHA256: %s\n' "$got"
