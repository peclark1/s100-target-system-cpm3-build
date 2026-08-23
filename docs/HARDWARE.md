# Hardware Assumptions

## Memory / CPU environment

The system is a non-banked CP/M 3 build. `GENCPM.DAT` uses `MEMTOP=EF`, consistent with RAM through EFFFH and monitor ROM at F000H-FFFFH.

## Console I/O

`CHARIO3.ASM` retains the proven S100Computers Console I/O configuration:

```text
status port: 00H
data port:   01H
```

## Dual IDE/CF board

`HIDE3.ASM` retains the hardware-tested S100Computers Dual IDE/CF interface:

```text
30H  IDE 8255 port A, lower data byte
31H  IDE 8255 port B, upper data byte
32H  IDE 8255 port C, control lines
33H  IDE 8255 control register
34H  physical CF selector, bit 0: 0=CF #0, 1=CF #1
```

A: maps to CF #0 and B: maps to CF #1.

## Altair FDC+ Drive Type 8

Required configuration:

- FDC+ firmware 1.8 or later
- drive-type switches set to 1000 (type 8)
- default controller I/O base 08H
- Shugart SA-800/SA-801 configured per the FDC+ manual
- IBM-3740 8-inch SSSD media

Registers used by `FDC3712.ASM`:

```text
08H IN   controller status/data
08H OUT  controller command
09H OUT  controller data
```

Physical mapping:

```text
C: -> FDC+3712 unit 0
D: -> FDC+3712 unit 1
```

The BIOS does not access the controller during IDE/CF startup. Reset and restore occur only on first C:/D: I/O and all command waits are bounded.

## ROM relationship

The CP/M 3 driver does not use CDBL at FF00H and does not call the original iCOM PROM table at F400H. The current 4K monitor's CDBL path is therefore unrelated to C:/D: operation and may be removed/replaced independently.
