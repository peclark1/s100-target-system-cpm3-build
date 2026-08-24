# Front-Panel CPMLDR Acceptance Test

This test is for the experimental `feature/front-panel-cpmldr` path.  It verifies that the early CP/M 3 loader output follows the same physical IMSAI console selector used by the 4K master ROM and the normal CP/M 3 BIOS.

## Build

Supply the standard Digital Research CP/M 3 `CPMLDR.REL` as `tools/cpm/CPMLDR.REL` (or set `CPMLDR_REL`), then run:

```bash
make clean
make loader-image
```

Record the reported `CPMLDR.COM` byte count and SHA-256.  The build must remain at or below 6144 bytes because the current master ROM reads exactly 12 512-byte sectors beginning at LBA 1 into 0100H.

Write this image to a test CF card:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img
```

## Console selector matrix

Cold-reset the IMSAI for every row so both the ROM and CPMLDR read the same switch setting.

| SW09 SW08 | Expected ROM console | Expected CPMLDR console | Expected normal CP/M console |
|---|---|---|---|
| 00 | Console I/O V2 | Console I/O V2 | Console I/O V2 |
| 01 | Serial I/O V3 A, 38400 8N1 | Serial I/O V3 A, 38400 8N1 | Serial I/O V3 A, 38400 8N1 |
| 10 | IMSAI MIO SIO | IMSAI MIO SIO | IMSAI MIO SIO |
| 11 | Console I/O V2 fallback | Console I/O V2 fallback | Console I/O V2 fallback |

For each selection, verify that all of the following appear on the selected device and not only on Console I/O:

1. 4K master-ROM banner/countdown.
2. `CP/M V3.0 Loader` and Digital Research copyright line.
3. BIOS3/BDOS3 load-map lines and TPA size.
4. Target CP/M BIOS sign-on.
5. `A>` prompt.
6. Keyboard input and `DIR` work after the prompt.

## Disk regression

The custom LDRBIOS reads only drive A: and uses the same drive-A DPB as the runtime BIOS.  After each successful boot:

1. `DIR A:` and `DIR B:`.
2. Read a known file from A:.
3. Warm boot and confirm normal CP/M operation remains unchanged.
4. On one test pass, exercise C: and D: to ensure the loader change did not alter the FDC+3712 runtime driver.

## Failure interpretation

- ROM output correct, but no `CP/M V3.0 Loader`: first suspect the new loader image, its size, or the LDRBIOS disk read path.
- Loader text appears on the wrong console: inspect LDRBIOS FFH decoding / CONOUT dispatch.
- Loader text appears correctly but CPM3.SYS cannot be loaded: inspect the loader DPH/DPB and Dual IDE/CF READ routine.
- Loader completes but the final CP/M console changes: inspect normal `CHARIO3.ASM`; that stage is independent of LDRBIOS.

Do not merge this experimental loader path into the hardware-tested baseline until all four selector values and the disk regression pass on the physical IMSAI.
