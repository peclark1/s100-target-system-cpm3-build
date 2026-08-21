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
