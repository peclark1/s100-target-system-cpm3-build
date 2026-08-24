# Front-Panel CPMLDR Acceptance Test

This test is for the experimental `feature/front-panel-cpmldr` path. It verifies that the early CP/M 3 loader output follows the same physical IMSAI console selector used by the 4K master ROM and the normal CP/M 3 BIOS.

## What changes

The known-good CPMLDR is not rebuilt. Its loader-BIOS `CONOUT` routine at 0B78H is patched permanently in the CF image from:

```text
CD 84 0B 28 ...
```

to:

```text
79 C3 06 F0
MOV A,C
JMP F006H
```

CPMLDR supplies the character in C; the ROM's fixed F006H entry expects it in A. The ROM then sends the character through the front-panel-selected console. No CPMLDR IDE/CF disk code changes.

The patcher refuses to run unless it sees both the original CONOUT bytes and the loader-BIOS `JMP CONOUT` vector (`C3 78 0B`). It then verifies that exactly four bytes in the entire image changed.

## Build

Run:

```bash
make clean
make loader-image
```

Write this image to a test CF card:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-front-panel-loader.img
```

## Console selector matrix

Cold-reset the IMSAI for every row so the ROM establishes the selected console before CPMLDR starts.

| SW09 SW08 | Expected ROM console | Expected CPMLDR console | Expected normal CP/M console |
|---|---|---|---|
| 00 | Console I/O V2 | Console I/O V2 | Console I/O V2 |
| 01 | Serial I/O V3 A, 38400 8N1 | Serial I/O V3 A, 38400 8N1 | Serial I/O V3 A, 38400 8N1 |
| 10 | IMSAI MIO SIO | IMSAI MIO SIO | IMSAI MIO SIO |
| 11 | Console I/O V2 fallback | Console I/O V2 fallback | Console I/O V2 fallback |

For each selection, verify that all of the following appear on the selected device:

1. 4K master-ROM banner/countdown.
2. `CP/M V3.0 Loader` and Digital Research copyright line.
3. BIOS3/BDOS3 load-map lines and TPA size.
4. Target CP/M BIOS sign-on.
5. `A>` prompt.
6. Keyboard input and `DIR` work after the prompt.

## Disk regression

Because the loader disk code is deliberately unchanged, this is mainly a regression check:

1. `DIR A:` and `DIR B:`.
2. Read a known file from A:.
3. Warm boot and confirm normal CP/M operation remains unchanged.
4. On one test pass, exercise C: and D: to ensure the loader patch did not affect the runtime FDC+3712 driver.

## Failure interpretation

- ROM output is correct but no loader text appears: inspect the F006H call path and confirm the ROM remains visible at F000H-FFFFH while CPMLDR runs.
- Loader text appears on the wrong console: inspect the ROM's saved front-panel selector; CPMLDR itself no longer selects a console.
- Loader text appears correctly but CPM3.SYS cannot be loaded: because the IDE/CF loader code was not changed, compare against the unpatched candidate image and investigate an unrelated disk/read regression.
- Loader completes but the final CP/M console changes: inspect normal `CHARIO3.ASM`; that stage is independent of the loader patch.

Do not merge this experimental loader path into the hardware-tested baseline until all four selector values and the disk regression pass on the physical IMSAI.
