#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/fdclean"
DIST="$ROOT/dist"
RUNNER="$ROOT/tools/cpmrun"

command -v cc >/dev/null || { echo "error: C compiler (cc/gcc) is required" >&2; exit 1; }

mkdir -p "$ROOT/tools" "$DIST"
if [[ ! -x "$RUNNER" ]]; then
  cc -O2 -std=c99 -Wall -Wextra -o "$RUNNER" "$ROOT/tools/cpmrun.c"
fi

rm -rf "$BUILD"
mkdir -p "$BUILD/logs"
cp "$ROOT/utils/FDCLEAN.ASM" "$BUILD/"
cp "$ROOT/tools/cpm/RMAC.COM" "$BUILD/"
cp "$ROOT/tools/cpm/LINK.COM" "$BUILD/"

echo "RMAC FDCLEAN"
"$RUNNER" "$BUILD/RMAC.COM" FDCLEAN.ASM >"$BUILD/logs/fdclean.rmac.log" 2>&1
cat "$BUILD/logs/fdclean.rmac.log"
grep -q "END OF ASSEMBLY" "$BUILD/logs/fdclean.rmac.log" || {
  echo "RMAC failed for FDCLEAN" >&2
  exit 1
}

echo "LINK FDCLEAN.COM"
"$RUNNER" "$BUILD/LINK.COM" FDCLEAN >"$BUILD/logs/fdclean.link.log" 2>&1
cat "$BUILD/logs/fdclean.link.log"
if grep -qi "UNDEFINED" "$BUILD/logs/fdclean.link.log"; then
  echo "LINK reported undefined symbols" >&2
  exit 1
fi
if [[ ! -s "$BUILD/FDCLEAN.COM" ]]; then
  echo "LINK did not create a non-empty FDCLEAN.COM" >&2
  ls -l "$BUILD" >&2
  exit 1
fi

cp "$BUILD/FDCLEAN.COM" "$DIST/FDCLEAN.COM"
sha256sum "$DIST/FDCLEAN.COM"
echo "SUCCESS: built $DIST/FDCLEAN.COM"
