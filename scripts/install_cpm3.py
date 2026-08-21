#!/usr/bin/env python3
"""Install a rebuilt CPM3.SYS into the verified working dual-CF base image.

This script is deliberately strict. It refuses to patch an unexpected image.
The known image uses the ZSOS/S100 64-sector no-holes layout:
  * 512-byte IDE sectors
  * directory begins at LBA 64
  * 2 KiB allocation blocks
  * CPM3.SYS is user 0, extent 0, blocks 16..21
"""
from pathlib import Path
import argparse, hashlib

BASE_SHA256 = "a51b3220f793059ab6653d64ec94cce540d0bb68b5c0ede754d82877e6154cc9"
SECTOR_SIZE = 512
DIR_LBA = 64
DIR_SECTORS = 64
BLOCK_SIZE = 2048
EXPECTED_BLOCKS = [16,17,18,19,20,21]

def sha256(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def block_offset(block: int) -> int:
    return DIR_LBA * SECTOR_SIZE + block * BLOCK_SIZE

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base_image", type=Path)
    ap.add_argument("cpm3_sys", type=Path)
    ap.add_argument("output_image", type=Path)
    args = ap.parse_args()

    image = bytearray(args.base_image.read_bytes())
    system = args.cpm3_sys.read_bytes()

    got = sha256(bytes(image))
    if got != BASE_SHA256:
        raise SystemExit(
            f"Refusing unexpected base image.\n"
            f"expected SHA256 {BASE_SHA256}\n"
            f"got             {got}"
        )

    if len(system) % 128:
        raise SystemExit("CPM3.SYS size is not a whole number of 128-byte CP/M records")
    if len(system) > len(EXPECTED_BLOCKS) * BLOCK_SIZE:
        raise SystemExit("CPM3.SYS no longer fits the six allocation blocks reserved in the gold image")

    ds = DIR_LBA * SECTOR_SIZE
    directory = image[ds:ds + DIR_SECTORS * SECTOR_SIZE]
    entry_off = None
    blocks = None
    for off in range(0, len(directory), 32):
        e = directory[off:off+32]
        if e[0] == 0xE5 or e[0] > 31:
            continue
        name = bytes(c & 0x7f for c in e[1:9]).decode("ascii", "replace").rstrip()
        ext = bytes(c & 0x7f for c in e[9:12]).decode("ascii", "replace").rstrip()
        if e[0] == 0 and name == "CPM3" and ext == "SYS" and e[12] == 0 and e[14] == 0:
            entry_off = off
            blocks = []
            for j in range(16,32,2):
                n = e[j] | (e[j+1] << 8)
                if n:
                    blocks.append(n)
            break

    if entry_off is None:
        raise SystemExit("Could not find user-0 CPM3.SYS extent 0")
    if blocks != EXPECTED_BLOCKS:
        raise SystemExit(f"Unexpected CPM3.SYS allocation chain: {blocks}")

    area = bytearray([0x1A] * (len(EXPECTED_BLOCKS) * BLOCK_SIZE))
    area[:len(system)] = system
    for i, block in enumerate(EXPECTED_BLOCKS):
        bo = block_offset(block)
        image[bo:bo+BLOCK_SIZE] = area[i*BLOCK_SIZE:(i+1)*BLOCK_SIZE]

    # RC: number of 128-byte records in extent 0. V3.0 is 90 records.
    image[ds + entry_off + 15] = len(system) // 128
    args.output_image.write_bytes(image)

    # Read it back from the allocation blocks as a verification.
    chk = bytearray()
    for block in EXPECTED_BLOCKS:
        bo = block_offset(block)
        chk += image[bo:bo+BLOCK_SIZE]
    assert bytes(chk[:len(system)]) == system

    print(f"wrote {args.output_image}")
    print(f"CPM3.SYS: {len(system)} bytes, SHA256 {sha256(system)}")
    print(f"image:    {len(image)} bytes, SHA256 {sha256(bytes(image))}")

if __name__ == "__main__":
    main()
