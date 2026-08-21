# Provenance and Why This Is the Gold Build

Several historical S100Computers/ZSOS CP/M 3 source variants exist. They are not interchangeable at the CF-image level.

The decisive artifact was the recovered image:

```text
S100-cpm3-nonbanked-prop.img
```

It booted successfully on the real system and provided working A: and B: CF drives. Its exact embedded CP/M system file is preserved as:

```text
reference/CPM3_WORKING_DUALCF.SYS
SHA256 7af0e3980effae367831660d4d53911fa85ba4542e22111e48f70f3375842b94
```

Inspection of that working system, together with the later ZSOS source, established the correct 64-sector no-holes LBA layout and the required post-reset IDE ready wait.

The DSI module was developed from the period FDC-2 programming model and then proven on the real HB-1.3/FDC-2 hardware. The final V3.0 source build combines the recovered working dual-CF behavior with that proven DSI module.

The final V3.0 `CPM3.SYS` was then hardware-tested extensively. A:, B:, C:, and D: all operated; writes succeeded on B:/C:/D:; files copied between IDE and DSI; and a file copied directly from D: to C: successfully.

Earlier V0.x, V1.x, and V2.x experimental builds are development history only and should not be used as a source of truth.
