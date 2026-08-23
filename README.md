# CP/M 3 Target-System Build - Dual IDE/CF + Altair FDC+3712

This repository builds the non-banked CP/M 3 system for the IMSAI/S-100 target system.

## Candidate drive map

| CP/M drive | Hardware |
|---|---|
| A: | Dual IDE/CF board, CF #0 |
| B: | Dual IDE/CF board, CF #1 |
| C: | Altair FDC+ firmware 1.8, Drive Type 8, physical drive 0 |
| D: | Altair FDC+ firmware 1.8, Drive Type 8, physical drive 1 |

A: and B: retain the hardware-tested IDE/CF implementation from Gold V3.0. The former Digital Systems FDC-2 module has been removed and replaced by `FDC3712.ASM`.

The new C:/D: driver is a hardware-test candidate. Do not promote it to gold until the physical acceptance test in [docs/TESTING.md](docs/TESTING.md) passes.

## FDC+3712 implementation

The driver targets IBM-3740 8-inch SSSD media:

- 77 tracks
- 26 physical sectors per track
- 128 bytes per sector
- sector IDs 1-26
- standard CP/M skew 6
- 1K allocation blocks
- 64 directory entries
- two reserved tracks

It talks directly to the Drive Type 8 interface:

| Port | Read | Write |
|---|---|---|
| 08H | controller status/data | controller command |
| 09H | - | controller data |

The command sequence is derived from Mike Douglas's FDC+3712 `PROM.ASM` and `BIOS.ASM` and matches the sequence physically verified by [altair-fdcplus-software](https://github.com/peclark1/altair-fdcplus-software).

The driver:

- supports read and write on two physical drives;
- verifies every completed write with the controller's read-CRC command;
- distinguishes write-protected media from general I/O errors;
- uses bounded command waits so absent or misconfigured hardware cannot hang CP/M forever;
- defers controller reset and drive restore until the first C:/D: access, so IDE/CF boot does not require powered floppy hardware or inserted media.

There is no dependency on the original iCOM PROM vectors at F400H or the Altair CDBL loader at FF00H.

## Build on Ubuntu

Requirements: `make`, `cc` or `gcc`, `python3`, and standard GNU utilities.

```bash
make clean
make
```

Successful output:

```text
SUCCESS: reproduced FDC+3712 candidate CPM3.SYS
SHA256: c2ad51aaf8638fb0faf939c0f15a971b7d5fb9a0e3846dce2a4aa3c665045b17
```

The result is `dist/CPM3.SYS`.

To install it into a copy of the verified working dual-CF image:

```bash
make image
```

This creates:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-candidate.img
```

The installer verifies the base image, preserves the existing CPM3.SYS allocation chain, and verifies the embedded candidate system byte-for-byte.

GitHub Actions runs both `make` and `make image` for every branch/PR and publishes the four hardware-test files as the `cpm3-fdc3712-candidate` artifact.

## Build stages

1. Compile the included Linux CP/M program runner.
2. Assemble the modular BIOS with Digital Research RMAC.
3. Link:

```text
BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,FDC3712
```

4. Run `GENCPM.COM AUTO` with `MEMTOP=EF`.
5. Verify the candidate `CPM3.SYS` hash.

The previous DSI Gold V3.0 binaries remain in `reference/` as historical, hardware-tested recovery points. They are not inputs to the new build.
