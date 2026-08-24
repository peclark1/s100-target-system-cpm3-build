#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-ldrpatch"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"
SRC="$ROOT/utils/LDRPATCH.ASM"

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }

mkdir -p "$ROOT/tools" "$DIST"
if [[ ! -x "$RUNNER" ]]; then
    cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD"
cp "$SRC" "$BUILD/LDRPATCH.ASM"
cp "$ROOT/tools/cpm/RMAC.COM" "$BUILD/"
cp "$ROOT/tools/cpm/LINK.COM" "$BUILD/"

# RMAC expects CR/LF source records.
python3 - "$BUILD/LDRPATCH.ASM" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
p.write_bytes(data.replace(b"\n", b"\r\n"))
PY

echo "RMAC LDRPATCH"
"$RUNNER" "$BUILD/RMAC.COM" "$BUILD/LDRPATCH.ASM" >"$BUILD/LDRPATCH.rmac.log" 2>&1
if ! grep -q "END OF ASSEMBLY" "$BUILD/LDRPATCH.rmac.log" || \
   grep -Eq '^[A-Z][[:space:]]{2,}$' "$BUILD/LDRPATCH.rmac.log" || \
   [[ ! -s "$BUILD/LDRPATCH.REL" ]]; then
    cat "$BUILD/LDRPATCH.rmac.log" >&2
    echo "RMAC failed for LDRPATCH" >&2
    exit 1
fi

echo "LINK LDRPATCH"
(
    cd "$BUILD"
    "$RUNNER" "$BUILD/LINK.COM" 'LDRPATCH[L100]=LDRPATCH' >"$BUILD/LDRPATCH.link.log" 2>&1
)
if grep -qi "UNDEFINED" "$BUILD/LDRPATCH.link.log" || [[ ! -s "$BUILD/LDRPATCH.COM" ]]; then
    cat "$BUILD/LDRPATCH.link.log" >&2
    echo "LINK failed for LDRPATCH" >&2
    exit 1
fi

cp "$BUILD/LDRPATCH.COM" "$DIST/LDRPATCH.COM"
[[ -f "$BUILD/LDRPATCH.SYM" ]] && cp "$BUILD/LDRPATCH.SYM" "$DIST/LDRPATCH.SYM"

size="$(wc -c < "$DIST/LDRPATCH.COM")"
sha="$(sha256sum "$DIST/LDRPATCH.COM" | awk '{print $1}')"
printf '\nSUCCESS: built dist/LDRPATCH.COM\nSize: %s bytes\nSHA256: %s\n' "$size" "$sha"
