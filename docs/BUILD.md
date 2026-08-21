# Reproducible Build Procedure

## Host prerequisites

Tested on 64-bit Ubuntu/Linux. Install a C compiler, Make, Python 3, and standard GNU command-line tools.

No CP/M emulator installation is required. `tools/cpmrun.c` is a small host-side 8080/BDOS shim used only to execute RMAC, LINK, and GENCPM against files in the build directory.

## Build

```bash
make clean
make
```

Expected final hash:

```text
d714ab2c4742154751ccf1f20af073fcfec0a286b5b4500aadd12f3237d37f7d  CPM3.SYS
```

The build is considered successful only if the generated `CPM3.SYS` is byte-for-byte identical to the hardware-tested gold file.

## Full CF image

```bash
make image
```

The image installer is intentionally strict. It accepts only the recovered known-working base image with SHA-256:

```text
a51b3220f793059ab6653d64ec94cce540d0bb68b5c0ede754d82877e6154cc9
```

It locates user-0 `CPM3.SYS`, verifies its allocation chain is blocks 16–21, writes the rebuilt system into those same blocks, updates the CP/M record count, and verifies the embedded bytes.

Expected complete image SHA-256:

```text
0232a9d0c17948eac6701cf5f703054824f610290a745983c71cb7fac4da088a
```

## CP/M build stages

Modules assembled with RMAC:

```text
BIOSKRNL
SCB3
HBOOT3
CHARIO3
MOVE3
HDRVTBL3
HIDE3
DSIFDC2
```

Link command:

```text
LINK BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,DSIFDC2
```

GENCPM command:

```text
GENCPM AUTO
```

The tested link map includes:

```text
@DTBL  0487
DPH0   0901
DPH1   0925
DSI0   051C
DSI1   0540
CODE SIZE 0785
DATA SIZE 02D1
```
