#!/usr/bin/env python3
"""Install CPMLDR.COM into the raw CF system-track area used by the 4K ROM.

The target 4K master ROM currently reads 12 512-byte sectors beginning at
LBA 1 into 0100H, verifies byte 0100H is 31H, and jumps to 0100H.
LBA 0 is deliberately preserved.
"""

from pathlib import Path
import argparse
import hashlib

SECTOR_SIZE = 512
LOADER_LBA = 1
LOADER_SECTORS = 12
LOADER_OFFSET = LOADER_LBA * SECTOR_SIZE
LOADER_CAPACITY = LOADER_SECTORS * SECTOR_SIZE


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_image", type=Path)
    ap.add_argument("cpmldr_com", type=Path)
    ap.add_argument("output_image", type=Path)
    args = ap.parse_args()

    image = bytearray(args.input_image.read_bytes())
    loader = args.cpmldr_com.read_bytes()

    if len(image) < LOADER_OFFSET + LOADER_CAPACITY:
        raise SystemExit("input image is too small to contain the 12-sector loader area")
    if not loader:
        raise SystemExit("CPMLDR.COM is empty")
    if loader[0] != 0x31:
        raise SystemExit(
            f"CPMLDR.COM begins with {loader[0]:02X}H; current 4K ROM expects 31H at 0100H"
        )
    if len(loader) > LOADER_CAPACITY:
        sectors = (len(loader) + SECTOR_SIZE - 1) // SECTOR_SIZE
        raise SystemExit(
            f"CPMLDR.COM is {len(loader)} bytes ({sectors} sectors), but the current ROM reads "
            f"only {LOADER_SECTORS} sectors ({LOADER_CAPACITY} bytes)"
        )

    # Clear the complete area the ROM reads so stale bytes from the former
    # CPMLDR cannot remain after the end of a shorter new loader.
    area = bytearray(LOADER_CAPACITY)
    area[: len(loader)] = loader
    image[LOADER_OFFSET : LOADER_OFFSET + LOADER_CAPACITY] = area

    args.output_image.write_bytes(image)

    # Byte-for-byte verification of the loader region just written.
    check = args.output_image.read_bytes()[LOADER_OFFSET : LOADER_OFFSET + len(loader)]
    if check != loader:
        raise SystemExit("loader verification failed after writing output image")

    sectors = (len(loader) + SECTOR_SIZE - 1) // SECTOR_SIZE
    print(f"wrote {args.output_image}")
    print(f"CPMLDR.COM: {len(loader)} bytes, {sectors} sectors, SHA256 {sha256(loader)}")
    print(f"image:      {len(image)} bytes, SHA256 {sha256(bytes(image))}")
    print("preserved LBA 0; replaced LBA 1-12")


if __name__ == "__main__":
    main()
