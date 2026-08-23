# Changelog

## FDC+3712 Candidate V0.1 - 2026-08-22

Replaces the Digital Systems floppy path with Altair FDC+ firmware 1.8 Drive Type 8 support.

- Preserves the proven A:/B: Dual IDE/CF implementation and MEMTOP=EF layout.
- Maps C: to FDC+3712 unit 0 and D: to unit 1.
- Adds direct 08H/09H controller access for IBM-3740 77x26x128 media.
- Adds bounded controller waits and deferred first-access initialization.
- Adds read retry, write retry, write-protect reporting, and post-write CRC verification.
- Updates the boot banner to identify the IMSAI target FDC+3712 candidate and its A:/B:/C:/D: map.
- Removes `DSIFDC2.ASM` from the source and build.
- Removes all CDBL and F400H PROM dependencies from the CP/M 3 design.
- Candidate CPM3.SYS SHA-256: `c2ad51aaf8638fb0faf939c0f15a971b7d5fb9a0e3846dce2a4aa3c665045b17`.
- Candidate CF image SHA-256: `ee523fbab81dd4e2fe67637f76b8d3de10ae14311e838df37d4c7395259d2f77`.

This version is reproducibly built but not yet promoted to gold; physical testing is required.

## Gold V3.0 - 2026-08-20

First fully hardware-validated four-drive build.

- A: Dual IDE/CF #0 - read/write proven.
- B: Dual IDE/CF #1 - read/write proven.
- C: Digital Systems FDC-2 unit 0 - read/write proven.
- D: Digital Systems FDC-2 unit 1 - read/write proven.
- DSI-to-DSI D: to C: file copy proven.
- IDE/CF layout fixed at ZSOS 64-sector no-holes mapping.
- Dual-CF initialization matched to the recovered working image/later ZSOS source.
- DSI driver used HB-1.3/FDC-2 DMA with a private descriptor/data bounce buffer.

Gold V3.0 is retained under `reference/` for recovery and comparison.
