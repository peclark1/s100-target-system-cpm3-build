# Provenance and Candidate Status

The recovered dual-CF image remains the source of truth for the target system's A:/B: implementation. Its embedded working system is preserved as:

```text
reference/CPM3_WORKING_DUALCF.SYS
SHA256 7af0e3980effae367831660d4d53911fa85ba4542e22111e48f70f3375842b94
```

Gold V3.0 combined that IDE/CF behavior with the hardware-tested Digital Systems FDC-2 path. Its binaries and image remain in `reference/` as recovery artifacts, but DSI source is no longer part of the active build.

The FDC+3712 candidate preserves the Gold V3.0 IDE/CF and GENCPM configuration and replaces only the C:/D: controller module and drive-table references.

Controller behavior was established from four mutually consistent sources:

1. Mike Douglas's `PROM.ASM` and `BIOS.ASM` in the supplied FDC+3712 package.
2. The supplied `CPM22v1.0-FDC+3712-48K.dsk` boot image.
3. The Altair FDC+ manual's Drive Type 8 and 08H/09H register definitions.
4. Physical tests in [altair-fdcplus-software](https://github.com/peclark1/altair-fdcplus-software): restore, arbitrary sector reads, directory reads, and complete system-sector staging.

The current candidate `CPM3.SYS` is reproducible with SHA-256:

```text
c2ad51aaf8638fb0faf939c0f15a971b7d5fb9a0e3846dce2a4aa3c665045b17
```

It remains a candidate until [TESTING.md](TESTING.md) passes on the physical IMSAI.
