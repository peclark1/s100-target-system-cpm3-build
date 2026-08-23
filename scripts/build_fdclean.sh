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
grep -q "END OF ASSEMBLY" "$BUILD/logs/fdclean.rmac.log" || {
  cat "$BUILD/logs/fdclean.rmac.log" >&2
  echo "RMAC failed for FDCLEAN" >&2
  exit 1
}
if grep -Eq '(^|[[:space:]])([BELOPRSUVD])([[:space:]]|$)' "$BUILD/logs/fdclean.rmac.log"; then
  cat "$BUILD/logs/fdclean.rmac.log" >&2
  echo "RMAC reported assembly diagnostics for FDCLEAN" >&2
  exit 1
fi

echo "LINK FDCLEAN.COM"
"$RUNNER" "$BUILD/LINK.COM" FDCLEAN >"$BUILD/logs/fdclean.link.log" 2>&1
if grep -qi "UNDEFINED" "$BUILD/logs/fdclean.link.log"; then
  cat "$BUILD/logs/fdclean.link.log" >&2
  echo "LINK reported undefined symbols" >&2
  exit 1
fi
if [[ ! -f "$BUILD/FDCLEAN.COM" ]]; then
  cat "$BUILD/logs/fdclean.link.log" >&2
  echo "LINK did not create FDCLEAN.COM" >&2
  exit 1
fi

cp "$BUILD/FDCLEAN.COM" "$DIST/FDCLEAN.COM"
sha256sum "$DIST/FDCLEAN.COM"
echo "SUCCESS: built $DIST/FDCLEAN.COM"
