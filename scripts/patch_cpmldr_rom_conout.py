#!/usr/bin/env python3
"""Patch the proven CP/M 3 loader in-place to use the 4K ROM CONOUT.

The target ROM loads 12 sectors beginning at CF LBA 1 to 0100H.  The
known-good S100Computers non-banked Propeller CPMLDR has its loader BIOS
at 0B00H and CONOUT at 0B78H.  CPMLDR passes the character in C, while
the target ROM's fixed F006H CONOUT entry expects it in A.

Only four bytes are changed:

    0B78:  MOV A,C       79
    0B79:  JMP F006H     C3 06 F0

The ROM routine's RET returns directly to CPMLDR because CPMLDR called
loader-BIOS CONOUT in the normal way.  All IDE/CF loader code is left
byte-for-byte unchanged.
"""

from pathlib import Path
import argparse
import hashlib

SECTOR_SIZE = 512
LOADER_LBA = 1
LOADER_LOAD_ADDR = 0x0100
LDRBIOS_ADDR = 0x0B00
CONOUT_ADDR = 0x0B78
ROM_CONOUT_ADDR = 0xF006

# The original linked HLDRBIOS v1.4 routine, confirmed from the matching
# S100Computers non-banked Propeller CPMLDR.COM / HLDRBIOS.PRN provenance.
ORIGINAL_CONOUT = bytes.fromhex("CD 84 0B 28 FB 79 FE 00 C8 D3 01 C9")
ORIGINAL_VECTOR = bytes.fromhex("C3 78 0B")
PATCH = bytes.fromhex("79 C3 06 F0")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def image_offset(addr: int) -> int:
    return LOADER_LBA * SECTOR_SIZE + (addr - LOADER_LOAD_ADDR)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("input_image", type=Path)
    ap.add_argument("output_image", type=Path)
    args = ap.parse_args()

    original = args.input_image.read_bytes()
    image = bytearray(original)

    vector_off = image_offset(LDRBIOS_ADDR + 0x0C)
    conout_off = image_offset(CONOUT_ADDR)

    if image[vector_off:vector_off + len(ORIGINAL_VECTOR)] != ORIGINAL_VECTOR:
        got = bytes(image[vector_off:vector_off + len(ORIGINAL_VECTOR)])
        raise SystemExit(
            "refusing to patch: CPMLDR loader-BIOS CONOUT vector signature "
            f"does not match at image offset {vector_off:04X}H; got {got.hex(' ')}"
        )

    if image[conout_off:conout_off + len(ORIGINAL_CONOUT)] != ORIGINAL_CONOUT:
        got = bytes(image[conout_off:conout_off + len(ORIGINAL_CONOUT)])
        raise SystemExit(
            "refusing to patch: known-good CPMLDR CONOUT signature does not "
            f"match at image offset {conout_off:04X}H; got {got.hex(' ')}"
        )

    image[conout_off:conout_off + len(PATCH)] = PATCH

    # Strong safety check: exactly four bytes in the entire image changed,
    # and they are exactly the intended four bytes.
    changed = [i for i, (a, b) in enumerate(zip(original, image)) if a != b]
    expected = list(range(conout_off, conout_off + len(PATCH)))
    if changed != expected:
        raise SystemExit(f"unexpected changed byte offsets: {changed}")

    args.output_image.write_bytes(image)

    check = args.output_image.read_bytes()
    if check[conout_off:conout_off + len(PATCH)] != PATCH:
        raise SystemExit("post-write verification of CPMLDR CONOUT patch failed")

    print(f"input image:  {sha256(original)}")
    print(f"output image: {sha256(check)}")
    print(f"LDRBIOS base: {LDRBIOS_ADDR:04X}H")
    print(f"CONOUT:       {CONOUT_ADDR:04X}H (image offset {conout_off:04X}H)")
    print(f"old bytes:    {ORIGINAL_CONOUT[:len(PATCH)].hex(' ').upper()}")
    print(f"new bytes:    {PATCH.hex(' ').upper()}  ; MOV A,C / JMP {ROM_CONOUT_ADDR:04X}H")
    print("verified: exactly four bytes changed; all loader disk code is unchanged")


if __name__ == "__main__":
    main()
