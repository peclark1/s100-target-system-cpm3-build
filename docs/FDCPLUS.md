# Altair FDC+ Drive Type 8 — CP/M 3 integration notes

Status: **experimental / awaiting physical IMSAI verification**

## Goal

Keep the proven Dual IDE/CF CP/M 3 path unchanged while replacing the Digital Systems C:/D: disk module in an alternate build:

- A: Dual IDE/CF #0
- B: Dual IDE/CF #1
- C: FDC+ physical drive 0
- D: FDC+ physical drive 1

The normal `make` target remains the exact DSI gold build. The FDC+ work uses `make fdcplus` or `make fdcplus-image`.

## Hardware and media basis

FDC+ Drive Type 8 emulates an iCOM/Pertec FD3712 using Shugart-compatible drives. The documented media format is IBM 3740:

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

## FDC+ register map

The FDC+ manual documents the default I/O decode as:

| Port | Read | Write |
|---|---|---|
| 08H | Drive/controller status | Drive select |
| 09H | Sector position | Drive command |
| 0AH | Read data | Write data |
| 0BH | Reserved | Reserved |

For Drive Type 8 the new BIOS module uses the FD3712 command protocol through the FDC+ command/data registers:

- status: 08H
- command: 09H
- data in/out: 0AH

The FD3712 command-level behavior is based on the recovered/disassembled iCOM interface software and public FD3712 emulator implementation. The FDC+ port placement is based on the FDC+ hardware manual. This combination must be confirmed by the real board before the build is promoted.

## Command protocol used

The module uses the FD3712 operations needed for CP/M:

- 03H read sector
- 05H write sector
- 07H read/check CRC
- 09H seek
- 0BH clear errors
- 11H set target track
- 15H load configuration
- 21H set unit and sector
- 31H load write buffer
- 40H expose read buffer
- 41H shift read buffer

The physical unit is encoded in bits 7:6 of the unit/sector byte. The sector number occupies the lower six bits.

## CP/M 3 integration

`src/HDRVTBLF.ASM` substitutes `FDP0` and `FDP1` for the former DSI XDPHs while retaining the existing IDE XDPHs as A: and B:.

`src/FDCPLUS3.ASM` uses the same CP/M 3 disk-module interface already proven by `DSIFDC2.ASM`:

- initialize
- login
- read
- write
- `@DMA`
- `@TRK`
- `@SECT`

No DSI DMA descriptor or bounce buffer is required. The FD3712/FDC+ buffers a complete 128-byte physical sector internally and the Z80 transfers it through the data register.

The module deliberately performs no floppy I/O during CP/M initialization so a missing disk cannot prevent the IDE/CF system from booting. Command polling also includes a software timeout to avoid a permanent CP/M hang if the floppy subsystem is absent or not ready.

## Acceptance sequence

Do not begin with a valuable archive disk.

1. Build with `make fdcplus`.
2. Prefer `make fdcplus-image` and write the result to a spare/test CF.
3. Boot from CF.
4. Use a known-good IBM 3740 disk and run `DIR C:`.
5. Read and copy several files C: -> A:.
6. Repeat with D:.
7. Exercise repeated seeks across low/high tracks.
8. Only then use a scratch disk for write testing.
9. Verify files written by CP/M can be read back and, ideally, imaged independently.
10. After successful physical testing, record the exact system/image hashes and promote a new gold reference.

## Source references

- FDC+ User's Manual v2.0, sections 2.5 and 3.8.
- Mike Douglas / DeRamp iCOM FD3712 software and recovered interface material.
- Public `deltecent/icom-fds` FD3712 source reconstruction.
- Public `deltecent/altairsim` FD3712 controller implementation.

The current branch intentionally leaves the original DSI gold artifacts and normal build path untouched.
