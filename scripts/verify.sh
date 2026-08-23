#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED_SYS="c2ad51aaf8638fb0faf939c0f15a971b7d5fb9a0e3846dce2a4aa3c665045b17"
EXPECTED_IMG="ee523fbab81dd4e2fe67637f76b8d3de10ae14311e838df37d4c7395259d2f77"

[[ -f "$ROOT/dist/CPM3.SYS" ]] || { echo "dist/CPM3.SYS missing; run make" >&2; exit 1; }
python3 "$ROOT/scripts/check_candidate.py"
sys="$(sha256sum "$ROOT/dist/CPM3.SYS" | awk '{print $1}')"
[[ "$sys" == "$EXPECTED_SYS" ]] || { echo "CPM3.SYS mismatch: $sys" >&2; exit 1; }
echo "FDC+3712 candidate CPM3.SYS exact match: $sys"

image="$ROOT/dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-candidate.img"
if [[ -f "$image" ]]; then
  python3 - "$image" "$ROOT/dist/CPM3.SYS" "$EXPECTED_IMG" <<'PY'
from pathlib import Path
import hashlib
import sys

image_path = Path(sys.argv[1])
system_path = Path(sys.argv[2])
expected_digest = sys.argv[3]
image = image_path.read_bytes()
system = system_path.read_bytes()

sector_size = 512
dir_lba = 64
dir_sectors = 64
block_size = 2048
expected_blocks = [16, 17, 18, 19, 20, 21]
directory = image[
    dir_lba * sector_size:(dir_lba + dir_sectors) * sector_size
]

blocks = None
record_count = None
for off in range(0, len(directory), 32):
    entry = directory[off:off + 32]
    if entry[0] == 0xE5 or entry[0] > 31:
        continue
    name = bytes(c & 0x7F for c in entry[1:9]).decode("ascii", "replace").rstrip()
    ext = bytes(c & 0x7F for c in entry[9:12]).decode("ascii", "replace").rstrip()
    if entry[0] == 0 and name == "CPM3" and ext == "SYS" and entry[12] == 0 and entry[14] == 0:
        record_count = entry[15]
        blocks = [
            entry[j] | (entry[j + 1] << 8)
            for j in range(16, 32, 2)
            if entry[j] or entry[j + 1]
        ]
        break

if blocks != expected_blocks:
    raise SystemExit(f"unexpected CPM3.SYS allocation chain: {blocks}")
if record_count != len(system) // 128:
    raise SystemExit(
        f"CPM3.SYS record count mismatch: directory={record_count}, "
        f"file={len(system) // 128}"
    )

embedded = bytearray()
for block in blocks:
    start = dir_lba * sector_size + block * block_size
    embedded += image[start:start + block_size]
if bytes(embedded[:len(system)]) != system:
    raise SystemExit("candidate image does not contain the rebuilt CPM3.SYS")

digest = hashlib.sha256(image).hexdigest()
if digest != expected_digest:
    raise SystemExit(
        f"candidate CF image mismatch: expected {expected_digest}, got {digest}"
    )
print(f"candidate CF image exact match and embeds exact CPM3.SYS: {digest}")
PY
fi
