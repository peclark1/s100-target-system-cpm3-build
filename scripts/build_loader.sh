#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-loader"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"
MAX_BYTES=$((12 * 512))

# Digital Research CP/M 3.0 CPMLDR source, archived as an 8080/RMAC-compatible
# source file in the ANTLR 8080 grammar test corpus.  Pin the commit so this
# build cannot silently change underneath us.
CPMLDR_SOURCE_URL="https://raw.githubusercontent.com/antlr/grammars-v4/aca577d9e30e591eacbc414f1280f22645412af4/asm/asm8080/examples/cpm3_src/CPMLDR.ASM"
CPMLDR_SOURCE_GIT_SHA="ce64b1b0b47162e5db712ea86ab8df08db763c8f"

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "error: python3 is required" >&2; exit 1; }

mkdir -p "$ROOT/tools" "$DIST"
if [[ ! -x "$RUNNER" ]]; then
  cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD/logs"
cp "$ROOT/src/LDRBIOS.ASM" "$BUILD/"
cp "$ROOT/tools/cpm/RMAC.COM" "$ROOT/tools/cpm/LINK.COM" "$BUILD/"

# A caller can provide an original CPMLDR.REL explicitly.  Otherwise build
# the invariant loader module reproducibly from the pinned DRI 8080 source.
if [[ -n "${CPMLDR_REL:-}" ]]; then
  [[ -f "$CPMLDR_REL" ]] || { echo "error: CPMLDR_REL not found: $CPMLDR_REL" >&2; exit 1; }
  cp "$CPMLDR_REL" "$BUILD/CPMLDR.REL"
  echo "Using supplied CPMLDR.REL: $CPMLDR_REL"
else
  command -v curl >/dev/null || {
    echo "error: curl is required to fetch the pinned CPMLDR.ASM source" >&2
    echo "       (or set CPMLDR_REL=/path/to/original/CPMLDR.REL)" >&2
    exit 1
  }
  echo "Fetching pinned Digital Research CPMLDR.ASM"
  echo "  archive git blob: $CPMLDR_SOURCE_GIT_SHA"
  curl -fL --retry 3 --silent --show-error \
    "$CPMLDR_SOURCE_URL" -o "$BUILD/CPMLDR.ASM"

  # Both source files are fed to original CP/M RMAC under the local runner.
  # Normalize Unix files to CP/M-style CR/LF records first.
  python3 - "$BUILD/CPMLDR.ASM" "$BUILD/LDRBIOS.ASM" <<'PY'
from pathlib import Path
import sys
for name in sys.argv[1:]:
    p = Path(name)
    data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    p.write_bytes(data.replace(b"\n", b"\r\n"))
PY

  echo "RMAC CPMLDR"
  "$RUNNER" "$BUILD/RMAC.COM" CPMLDR.ASM >"$BUILD/logs/CPMLDR.rmac.log" 2>&1
  if ! grep -q "END OF ASSEMBLY" "$BUILD/logs/CPMLDR.rmac.log" || \
     grep -Eq '^[A-Z][[:space:]]{2,}$' "$BUILD/logs/CPMLDR.rmac.log" || \
     [[ ! -s "$BUILD/CPMLDR.REL" ]]; then
    cat "$BUILD/logs/CPMLDR.rmac.log" >&2
    echo "RMAC failed for CPMLDR" >&2
    exit 1
  fi
fi

# If CPMLDR.REL was supplied, LDRBIOS still needs CR/LF normalization.
if [[ -n "${CPMLDR_REL:-}" ]]; then
  python3 - "$BUILD/LDRBIOS.ASM" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
p.write_bytes(data.replace(b"\n", b"\r\n"))
PY
fi

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
