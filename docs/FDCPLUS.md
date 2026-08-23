# Altair FDC+ Drive Type 8 — CP/M 3 integration notes

Status: **experimental / ROM-adapter build verified / awaiting physical IMSAI verification**

## Goal

Keep the proven Dual IDE/CF CP/M 3 path unchanged while replacing the Digital Systems C:/D: disk module in an alternate build:

- A: Dual IDE/CF #0
- B: Dual IDE/CF #1
- C: FDC+ physical drive 0
- D: FDC+ physical drive 1

The normal `make` target remains the exact DSI gold build. The FDC+ work uses `make fdcplus` or `make fdcplus-image`.

## Hardware and media basis

FDC+ Drive Type 8 emulates an iCOM/Pertec FD3712 using Shugart-compatible drives. The media format is IBM 3740:

- 77 tracks
- one side
- single density / FM
- 26 sectors per track
- 128 bytes per sector
- sector IDs 1 through 26

The existing DSI CP/M 3 module already used the same logical CP/M geometry and skew for its single-density format, so the experimental FDC+ module keeps:

```asm
DPB  128,26,77,1024,64,2
SKEW 26,6,0
```

## Why the design changed

The first experimental `FDCPLUS3.ASM` duplicated the FD3712 controller protocol inside the CP/M 3 BIOS. That was unnecessary and, during development, led to an incorrect port/interface interpretation even though this IMSAI already had working FDC+3712 code.

The target 4K master ROM contains a native FDC+3712 implementation at `F800H-FB91H`. That exact implementation has already been physically exercised on the IMSAI for:

- cold boot of the supplied 48K CP/M 2.2 disk;
- directory reads;
- file creation/write/readback on physical drive 0;
- reading a Digital Systems single-density disk in physical drive 1;
- copying a file from physical drive 1 to physical drive 0.

The CP/M 3 experiment therefore now reuses that resident implementation instead of maintaining another low-level driver.

## Stable master-ROM API

The 4K ROM build consumes 12 bytes of the former `FB92H-FB9FH` reserved gap as a stable public jump table:

| Address | Entry | Contract |
|---|---|---|
| `FB92H` | INIT | initialize/reset/restore the native FDC+3712 path |
| `FB95H` | SELDRV | select physical drive in register `C` (`0` or `1`) |
| `FB98H` | READ | read one 128-byte sector |
| `FB9BH` | WRITE | write one 128-byte sector |

The underlying 914-byte FDC module is not changed. The ROM build generates these four absolute `JP` vectors from `fdc3712rom.sym`, so the external ABI remains fixed even if an internal label moves.

`FDCPLUS3.ASM` checks that all four API addresses contain `C3H` before using them. If an older master ROM is still installed, C:/D: therefore return a CP/M disk error rather than jumping into the erased gap.

## Native ROM workspace

The resident driver intentionally preserves the original Mike-Douglas-compatible page-zero interface:

| Address | Meaning |
|---|---|
| `0040H` | physical drive number |
| `0041H` | track number |
| `0042H` | physical sector number (`1..26`) |
| `0043H-0044H` | DMA address |
| `0045H` | cached current track |
| `0046H-0047H` | BIOS pointer used by optional write-verify MODE check |

CP/M 3 cannot assume those bytes are free. The adapter therefore maintains two private eight-byte buffers:

1. save the real CP/M page-zero bytes `0040H-0047H`;
2. copy the persistent ROM-driver state into `0040H-0047H`;
3. fill drive/track/sector/DMA for the current CP/M request;
4. call the resident ROM READ or WRITE service;
5. capture the updated ROM-driver state, including its track cache;
6. restore the original CP/M page-zero bytes.

This allows the proven ROM code to run unchanged without permanently consuming CP/M page-zero memory.

## CP/M 3 interface

`src/HDRVTBLF.ASM` substitutes `FDP0` and `FDP1` for the former DSI XDPHs while retaining the existing IDE XDPHs as A: and B:.

`src/FDCPLUS3.ASM` now uses BIOSKRNL's published disk communication variables directly:

- `@RDRV` — relative physical drive (`0` or `1`)
- `@TRK` — track
- `@SECT` — translated CP/M sector
- `@DMA` — 128-byte DMA address

CP/M's `SKEW 26,6,0` leaves `@SECT` in the `0..25` domain. The adapter adds one before invoking the ROM so the native driver receives IBM-3740 sector IDs `1..26`.

No floppy hardware is touched during CP/M cold initialization. The ROM INIT call occurs lazily on the first actual C:/D: read or write, preserving the ability to boot and use A:/B: independently.

For WRITE, the adapter points the native driver's BIOS/MODE lookup at a private zero byte. That matches the physically-proven native CP/M image's normal MODE setting: write-CRC verification is disabled, while the native driver still performs its proven write-buffer, write-sector, and write-protect handling.

## Build verification history

The earlier direct-port candidate built and booted CP/M 3 but returned `CP/M Error On C: Disk I/O` with no physical drive activity. The drive, cable, FDC+, and disk were independently known good because the same configuration booted from the native ROM and had passed the standalone 3712 utilities.

The driver was then replaced by the resident-ROM adapter described above.

Current CI result for the ROM-adapter candidate:

- `CPM3-FDCPLUS.SYS`: 11,264 bytes
- SHA-256: `8480161675bd0701384ace789e36068778c8c821951c2b39fd028e008d695cbf`
- complete test CF image: 3,074,048 bytes
- image SHA-256: `1d3fdff39e0a9c5c7d7efd396c2f638f9faa4787b8426b5fe005dd37c1aa4144`

The build, RMAC link, GENCPM step, and complete image generation all pass CI. Hardware verification of this ROM-adapter candidate is still pending.

## Acceptance sequence

The API-enabled master ROM is a prerequisite for this candidate.

1. Build the `feature/fdc3712-native-boot` branch of `s100-target-system-4k-master-rom` with `make clean && make verify`.
2. Program the generated API-enabled 28C64 image and install it in the FDC+.
3. Smoke-test the normal monitor and native `C` floppy boot first. This confirms adding the API vectors did not disturb the already-proven FDC implementation.
4. Build this CP/M branch with `make fdcplus-image` and write the result to the spare/test CF.
5. Boot CP/M 3 from CF and confirm A: remains normal.
6. Insert the known-good IBM 3740 disk in physical drive 0 and run `DIR C:`.
7. Read and copy several files C: -> A:.
8. Repeat with D: / physical drive 1.
9. Exercise repeated seeks across low/high tracks.
10. Only then use a scratch disk for write testing and verify files independently if practical.
11. After successful physical testing, record the exact system/image hashes and promote a new gold reference.

## Source references

The design is now anchored first in the code physically proven on this IMSAI:

- `peclark1/s100-target-system-4k-master-rom`, native `fdc3712rom.asm` implementation;
- `peclark1/altair-fdcplus-software`, `3712boot.asm`, `3712test.asm`, and related transition work.

Historical/reference material remains useful for explaining the implementation:

- FDC+ User's Manual v2.0;
- Mike Douglas / DeRamp iCOM FD3712 software and recovered interface material;
- public `deltecent/icom-fds` FD3712 source reconstruction.

The current branch intentionally leaves the original DSI gold artifacts and normal build path untouched.
