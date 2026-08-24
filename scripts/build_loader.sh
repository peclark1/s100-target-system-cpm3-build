#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-loader"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"
CPMLDR_REL="${CPMLDR_REL:-$ROOT/tools/cpm/CPMLDR.REL}"
MAX_BYTES=$((12 * 512))

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }

if [[ ! -f "$CPMLDR_REL" ]]; then
  cat >&2 <<EOF
error: CPMLDR.REL was not found.

CP/M 3 supplies CPMLDR.REL as the machine-independent loader module.
Place a copy at:
  $ROOT/tools/cpm/CPMLDR.REL

or point this build at another copy with:
  CPMLDR_REL=/path/to/CPMLDR.REL make loader
EOF
  exit 1
fi

mkdir -p "$ROOT/tools" "$DIST"
if [[ ! -x "$RUNNER" ]]; then
  cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD/logs"
cp "$ROOT/src/LDRBIOS.ASM" "$BUILD/"
cp "$ROOT/tools/cpm/RMAC.COM" "$ROOT/tools/cpm/LINK.COM" "$BUILD/"
cp "$CPMLDR_REL" "$BUILD/CPMLDR.REL"

# RMAC expects CP/M-style CR/LF source records.
python3 - "$BUILD/LDRBIOS.ASM" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
p.write_bytes(data.replace(b"\n", b"\r\n"))
PY

echo "RMAC LDRBIOS"
"$RUNNER" "$BUILD/RMAC.COM" LDRBIOS.ASM >"$BUILD/logs/LDRBIOS.rmac.log" 2>&1
if ! grep -q "END OF ASSEMBLY" "$BUILD/logs/LDRBIOS.rmac.log" || \
   grep -Eq '^[A-Z][[:space:]]{2,}$' "$BUILD/logs/LDRBIOS.rmac.log" || \
   [[ ! -s "$BUILD/LDRBIOS.REL" ]]; then
  cat "$BUILD/logs/LDRBIOS.rmac.log" >&2
  echo "RMAC failed for LDRBIOS" >&2
  exit 1
fi

echo "LINK CPMLDR"
"$RUNNER" "$BUILD/LINK.COM" 'CPMLDR[L100]=CPMLDR,LDRBIOS' \
  >"$BUILD/logs/CPMLDR.link.log" 2>&1
if grep -qi "UNDEFINED" "$BUILD/logs/CPMLDR.link.log" || [[ ! -s "$BUILD/CPMLDR.COM" ]]; then
  cat "$BUILD/logs/CPMLDR.link.log" >&2
  echo "LINK failed for CPMLDR" >&2
  exit 1
fi

python3 - "$BUILD/CPMLDR.COM" "$MAX_BYTES" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
limit = int(sys.argv[2])
data = p.read_bytes()
if not data:
    raise SystemExit("error: linked CPMLDR.COM is empty")
if data[0] != 0x31:
    raise SystemExit(
        f"error: CPMLDR.COM first byte is {data[0]:02X}H, but the current 4K ROM "
        "expects 31H at 0100H"
    )
sectors = (len(data) + 511) // 512
if len(data) > limit:
    raise SystemExit(
        f"error: CPMLDR.COM is {len(data)} bytes ({sectors} sectors), exceeding the "
        f"current ROM loader window of {limit} bytes (12 sectors)"
    )
print(f"CPMLDR.COM size: {len(data)} bytes ({sectors} 512-byte sectors)")
print(f"ROM loader capacity: {limit} bytes (12 sectors)")
PY

cp "$BUILD/CPMLDR.COM" "$DIST/CPMLDR.COM"
[[ -f "$BUILD/CPMLDR.SYM" ]] && cp "$BUILD/CPMLDR.SYM" "$DIST/CPMLDR.SYM" || true
[[ -f "$BUILD/LDRBIOS.PRN" ]] && cp "$BUILD/LDRBIOS.PRN" "$DIST/LDRBIOS.PRN" || true

sha="$(sha256sum "$DIST/CPMLDR.COM" | awk '{print $1}')"
printf 'SUCCESS: built front-panel-aware CPMLDR.COM\nSHA256: %s\n' "$sha"
