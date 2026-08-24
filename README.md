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

The normal `CPM3.SYS` BIOS already follows the IMSAI front-panel console selector. The earlier `CP/M V3.0 Loader`, BIOS/BDOS load-map, and TPA messages are printed by CPMLDR through its own loader BIOS before the normal BIOS takes control.

Rather than replace or rebuild that loader BIOS, the experimental image keeps the known-good CPMLDR and changes only its console-output entry. The matching S100Computers non-banked Propeller loader BIOS places `CONOUT` at 0B78H; CPMLDR passes the output character in C. The target 4K ROM exposes a stable `CONOUT` entry at F006H that expects the character in A and already dispatches through the front-panel-selected Console I/O, Serial I/O A, or MIO path.

The permanent on-disk patch is therefore only four bytes:

```text
0B78: 79          MOV A,C
0B79: C3 06 F0    JMP F006H
```

The original routine begins:

```text
CD 84 0B 28 FB 79 FE 00 C8 D3 01 C9
```

and its loader-BIOS jump vector at 0B0CH is `C3 78 0B`. `scripts/patch_cpmldr_rom_conout.py` requires both signatures before it will make any change, then verifies that exactly four bytes in the complete CF image changed. The loader's IDE/CF code, layout, size, and system-track location remain untouched.

Build the test image with:

```bash
make loader-image
```

This first builds the normal candidate image, then patches its already-present CPMLDR in place. The result is:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img
```

The current ROM still reads the same 12 sectors beginning at LBA 1 into 0100H and jumps to 0100H. The only changed behavior is that CPMLDR console output tail-jumps through the ROM's F006H console service. This remains experimental until all four front-panel selector values boot successfully on the physical IMSAI. See [docs/LOADER_TESTING.md](docs/LOADER_TESTING.md).

## Build stages

The normal CP/M system build is:

1. Compile the included Linux CP/M program runner.
2. Assemble the modular BIOS with Digital Research RMAC.
3. Link `BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,FDC3712`.
4. Run `GENCPM.COM AUTO` with `MEMTOP=EF`.
5. Verify the candidate `CPM3.SYS` hash.

The experimental loader path adds only the four-byte in-place CPMLDR patch; it does not rebuild CPMLDR or duplicate its disk BIOS.

The previous DSI Gold V3.0 binaries remain in `reference/` as historical, hardware-tested recovery points. They are not inputs to the new build.
