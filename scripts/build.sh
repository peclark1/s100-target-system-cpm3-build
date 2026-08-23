#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"
EXPECTED_SYS_SHA="5231b2f3959b7825eded5f12630751f4ce066c15b7e9b398f68eae3696546b19"

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }

mkdir -p "$ROOT/tools" "$DIST"
cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"

rm -rf "$BUILD"
mkdir -p "$BUILD/logs"
cp "$ROOT"/src/* "$BUILD/"
cp "$ROOT"/tools/cpm/*.COM "$BUILD/"

# CP/M RMAC expects CR/LF source records. GitHub and modern editors can
# normalize edited .ASM files to LF-only, which RMAC then treats as malformed
# input (typically reporting a bare "S" syntax error at address 0000). Make
# the build reproducible by converting the temporary build copies to CR/LF.
python3 - "$BUILD" <<'PY'
from pathlib import Path
import sys

build = Path(sys.argv[1])
for path in build.glob("*.ASM"):
    data = path.read_bytes()
    data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    path.write_bytes(data.replace(b"\n", b"\r\n"))
PY

modules=(BIOSKRNL SCB3 HBOOT3 CHARIO3 MOVE3 HDRVTBL3 HIDE3 FDC3712)
for m in "${modules[@]}"; do
  echo "RMAC $m"
  "$RUNNER" "$BUILD/RMAC.COM" "$m.ASM" >"$BUILD/logs/$m.rmac.log" 2>&1
  if ! grep -q "END OF ASSEMBLY" "$BUILD/logs/$m.rmac.log" || \
     grep -Eq '^[A-Z][[:space:]]{2,}$' "$BUILD/logs/$m.rmac.log" || \
     [[ ! -s "$BUILD/$m.REL" ]]; then
    cat "$BUILD/logs/$m.rmac.log" >&2
    echo "RMAC failed for $m" >&2
    exit 1
  fi
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
  if [[ "${ALLOW_CHANGED_SYS:-0}" == "1" ]]; then
    echo "WARNING: experimental build differs from the hardware-tested front-panel candidate" >&2
    echo "expected: $EXPECTED_SYS_SHA" >&2
    echo "got:      $got" >&2
  else
    echo "ERROR: build completed but CPM3.SYS does not match the hardware-tested front-panel candidate" >&2
    echo "expected: $EXPECTED_SYS_SHA" >&2
    echo "got:      $got" >&2
    exit 1
  fi
fi

echo
if [[ "${ALLOW_CHANGED_SYS:-0}" == "1" && "$got" != "$EXPECTED_SYS_SHA" ]]; then
  printf 'SUCCESS: built experimental CPM3.SYS\nSHA256: %s\n' "$got"
else
  printf 'SUCCESS: reproduced hardware-tested front-panel CPM3.SYS\nSHA256: %s\n' "$got"
fi
