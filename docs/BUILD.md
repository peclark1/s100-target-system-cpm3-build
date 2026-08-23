# Reproducible Build Procedure

## Host prerequisites

Tested on 64-bit Ubuntu/Linux. Install a C compiler, Make, Python 3, and standard GNU command-line tools.

No CP/M emulator installation is required. `tools/cpmrun.c` is a host-side 8080/BDOS shim used only to execute RMAC, LINK, and GENCPM.

## Build

```bash
make clean
make
```

Expected candidate hash:

```text
c2ad51aaf8638fb0faf939c0f15a971b7d5fb9a0e3846dce2a4aa3c665045b17  CPM3.SYS
```

The build is successful only if the generated system matches this reproducible candidate hash. That proves source/build consistency; it does not replace physical hardware testing.

## Full CF image

```bash
make image
```

The image installer accepts only the recovered known-working base image with SHA-256:

```text
a51b3220f793059ab6653d64ec94cce540d0bb68b5c0ede754d82877e6154cc9
```

It locates user-0 `CPM3.SYS`, verifies allocation blocks 16-21, writes the candidate into those blocks, updates the CP/M record count, and verifies the embedded bytes.

Output:

```text
dist/S100-cpm3-nonbanked-prop-dualcf-fdc3712-candidate.img
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
FDC3712
```

Link command:

```text
LINK BIOS3[B]=BIOSKRNL,SCB3,HBOOT3,CHARIO3,MOVE3,HDRVTBL3,HIDE3,FDC3712
```

GENCPM command:

```text
GENCPM AUTO
```

Candidate link map:

```text
@DTBL  0489
DPH0   0901
DPH1   0925
FDC0   051E
FDC1   0542
CODE SIZE 074D
DATA SIZE 02D1
```
