# CP/M 3 Gold Build — Dual IDE/CF + Digital Systems FDC-2

This directory is the reproducible source-of-truth for the hardware-tested non-banked CP/M 3 system used on the IMSAI/S-100 target system.

## Proven drive map

| CP/M drive | Hardware |
|---|---|
| A: | Dual IDE/CF board, CF #0 |
| B: | Dual IDE/CF board, CF #1 |
| C: | Digital Systems HB-1.3 + FDC-2, physical 8-inch drive 0 |
| D: | Digital Systems HB-1.3 + FDC-2, physical 8-inch drive 1 |

Hardware testing on 2026-08-20 verified booting, directory reads, file writes on B:/C:/D:, IDE↔DSI copies, and DSI D:→C: file copying.

## One-command reproduction on Ubuntu

Requirements: `make`, `cc`/`gcc`, `python3`, and standard GNU utilities.

```bash
make
```

A successful build ends with:

```text
SUCCESS: reproduced hardware-tested CPM3.SYS
SHA256: d714ab2c4742154751ccf1f20af073fcfec0a286b5b4500aadd12f3237d37f7d
```

The output is `dist/CPM3.SYS`.

To reproduce the complete tested CF image from the recovered working dual-CF base image:

```bash
make image
```

This creates:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-dsi-v3.0.img
```

and verifies that it is byte-identical to the hardware-tested image.

## What the build does

1. Compiles the included Linux CP/M program runner from `tools/cpmrun.c`.
2. Runs Digital Research `RMAC.COM` over all BIOS modules.
3. Links `BIOS3.SPR` with `LINK.COM` using:

```text
BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,DSIFDC2
```

4. Runs `GENCPM.COM AUTO` using `GENCPM.DAT` and `BDOS3.SPR`.
5. Verifies the final `CPM3.SYS` SHA-256 against the exact hardware-tested binary.

## Important preservation rule

`reference/CPM3_DUALCF_DSI_V3.0_TESTED.SYS` is the gold binary. Do not replace it after a source change until the new build has been tested on the real machine.

The source still contains an inherited sign-on string mentioning `CLEAN V2.0`. It is cosmetic. It is deliberately preserved because changing it would make the result differ from the exact binary that passed hardware testing.

See `docs/` for hardware assumptions, disk formats, build/provenance details, and the hardware acceptance test.

## Experimental FDC+ Drive Type 8 build

The `feature/fdcplus-8in` branch adds a second, isolated build path for the Altair FDC+ in Drive Type 8. It does **not** modify or replace the hardware-tested DSI gold build above.

Experimental drive map:

| CP/M drive | Hardware |
|---|---|
| A: | Dual IDE/CF board, CF #0 |
| B: | Dual IDE/CF board, CF #1 |
| C: | Altair FDC+ Drive Type 8, physical drive 0 |
| D: | Altair FDC+ Drive Type 8, physical drive 1 |

The floppy format is IBM 3740: 77 tracks, 26 128-byte sectors per track, single-sided single-density, with CP/M skew 6.

Build only the experimental system:

```bash
make fdcplus
```

Outputs:

```text
dist/CPM3-FDCPLUS.SYS
dist/BIOS3-FDCPLUS.SPR
dist/BIOS3-FDCPLUS.SYM
```

Build a complete test CF image from the preserved working dual-CF base image:

```bash
make fdcplus-image
```

Output:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdcplus-test.img
```

The experimental BIOS links:

```text
BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBLF,HIDE3,FDCPLUS3
```

### FDC architecture

`FDCPLUS3.ASM` is now intentionally a **thin CP/M 3 adapter**, not another FD3712 hardware driver. The target 4K master ROM already contains the native FDC+3712 implementation that has been physically proven for booting, directory reads, writes, both physical drives, and B:→A: copying under the native CP/M 2.2 path.

The updated master ROM exposes that implementation through a fixed jump table:

| ROM address | Service |
|---|---|
| `FB92H` | initialize/reset/restore FDC+3712 |
| `FB95H` | select physical drive in register C |
| `FB98H` | read one 128-byte sector |
| `FB9BH` | write one 128-byte sector |

The CP/M 3 adapter uses BIOSKRNL's official `@RDRV`, `@TRK`, `@SECT`, and `@DMA` parameters, translates sectors from CP/M's `0..25` domain to IBM-3740 `1..26`, and calls the resident ROM service.

The ROM driver uses its historical workspace at `0040H-0047H`. To avoid stealing those locations from CP/M 3, the adapter saves all eight bytes, installs a private persistent copy of the ROM-driver state for the duration of each operation, then restores page zero before returning to CP/M.

The adapter also checks that all four ROM API entries begin with `C3H` absolute-JP opcodes. With an older ROM that still has `FFH` in the former reserved gap, C:/D: therefore fail cleanly instead of jumping into erased ROM.

**The API-enabled master ROM must be installed before testing this CP/M 3 image.** The underlying 914-byte native FDC implementation itself is unchanged; only the former `FB92H-FB9FH` reserved gap gains the four public vectors.

Current CI build after conversion to the ROM adapter:

- `CPM3-FDCPLUS.SYS`: 11,264 bytes
- SHA-256: `8480161675bd0701384ace789e36068778c8c821951c2b39fd028e008d695cbf`
- test CF image SHA-256: `1d3fdff39e0a9c5c7d7efd396c2f638f9faa4787b8426b5fe005dd37c1aa4144`

These are build-verified but not yet hardware-tested.

### First hardware acceptance test

Use known-good/scratch IBM 3740 media and begin with reads:

1. Build and burn the API-enabled 4K master ROM from `s100-target-system-4k-master-rom` branch `feature/fdc3712-native-boot`.
2. Confirm the normal ROM monitor still boots the known-good FDC+3712 floppy.
3. Build this branch with `make fdcplus-image` and write the image to the spare/test CF.
4. Boot CP/M 3 from CF and confirm A: still works.
5. Insert the same known-good IBM 3740 disk in FDC+ drive 0 and run `DIR C:`.
6. Read/copy several files from C: to A: or B:.
7. Repeat on D: / physical drive 1.
8. Only after reads are reliable, test writes on a scratch floppy.

Do not promote `CPM3-FDCPLUS.SYS` to a gold/reference image until the physical IMSAI passes the acceptance tests.

See `docs/FDCPLUS.md` for the architecture and verification history.
