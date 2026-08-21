# Changelog

## Gold V3.0 — 2026-08-20

First fully hardware-validated four-drive build.

- A: Dual IDE/CF #0 — read/write proven.
- B: Dual IDE/CF #1 — read/write proven.
- C: Digital Systems FDC-2 unit 0 — read/write proven.
- D: Digital Systems FDC-2 unit 1 — read/write proven.
- DSI-to-DSI D:→C: file copy proven.
- IDE/CF layout fixed at ZSOS 64-sector no-holes mapping.
- Dual-CF initialization matched to the recovered working image/later ZSOS source.
- DSI driver uses HB-1.3/FDC-2 DMA with a private 131-byte descriptor/data bounce buffer.

Earlier V0.x–V2.x builds were diagnostic/development builds and are not release baselines.
