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

## Front-panel-aware CP/M loader experiment

The normal `CPM3.SYS` BIOS already follows the IMSAI front-panel console selector. The earlier `CP/M V3.0 Loader`, BIOS/BDOS load-map and TPA messages are different: they are printed by `CPMLDR` through its own small loader BIOS before the normal BIOS takes control.

`src/LDRBIOS.ASM` supplies a target-system loader BIOS with the same physical switch convention used by the master ROM and normal CP/M BIOS:

| SW09 SW08 | Loader console |
|---|---|
| 00 | Console I/O V2, ports 00H/01H |
| 01 | Serial I/O V3 A, A1H/A3H, 38,400 8N1 |
| 10 | IMSAI MIO SIO, 42H/43H |
| 11 | Console I/O V2 fallback |

The loader BIOS also contains a read-only drive-A implementation for the Dual IDE/CF V3 board at 30H-34H. Its DPH/DPB matches the normal BIOS drive-A geometry (`DPB 512,64,256,2048,1024,1,8000H`) and includes the allocation vector and 512-byte directory/data buffers that LDRBDOS requires because GENCPM does not allocate those structures for a loader BIOS.

The loader build follows Digital Research's documented procedure: assemble the invariant CPMLDR module and `LDRBIOS.ASM`, then link `CPMLDR[L100]=CPMLDR,LDRBIOS`. By default `scripts/build_loader.sh` fetches the original 8080/RMAC-compatible CP/M 3.0 `CPMLDR.ASM` from a commit-pinned public archive and assembles it with the repository's Digital Research RMAC. This avoids storing a second opaque loader binary in the project and keeps the loader reproducible. An original `CPMLDR.REL` can still be supplied explicitly with `CPMLDR_REL=/path/to/CPMLDR.REL`.

Build the customized loader with:

```bash
make loader
```

The build verifies that the resulting `CPMLDR.COM` begins with the 31H opcode expected by the current 4K ROM and refuses a loader larger than the ROM's present 12-sector / 6144-byte load window. The result is `dist/CPMLDR.COM`.

To build a test CF image containing both the current `CPM3.SYS` and the customized loader:

```bash
make loader-image
```

This creates:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img
```

The image installer preserves LBA 0 and replaces LBA 1-12 with the new `CPMLDR.COM`, matching the current 4K ROM boot path (12 sectors loaded at 0100H). This remains an experimental path until all four front-panel selector values boot successfully on the physical IMSAI. See [docs/LOADER_TESTING.md](docs/LOADER_TESTING.md).

## Build stages

The normal CP/M system build is:

1. Compile the included Linux CP/M program runner.
2. Assemble the modular BIOS with Digital Research RMAC.
3. Link `BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,FDC3712`.
4. Run `GENCPM.COM AUTO` with `MEMTOP=EF`.
5. Verify the candidate `CPM3.SYS` hash.

The experimental loader path adds a separate CPMLDR/LDRBIOS build and raw-system-track installer; it does not alter the tested normal image path.

The previous DSI Gold V3.0 binaries remain in `reference/` as historical, hardware-tested recovery points. They are not inputs to the new build.
