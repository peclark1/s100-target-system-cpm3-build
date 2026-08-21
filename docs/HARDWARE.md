# Hardware Assumptions

## Memory / CPU environment

The system is a non-banked CP/M 3 build. `GENCPM.DAT` uses `MEMTOP=EF`, consistent with RAM through EFFFh and the monitor ROM above it.

## Console I/O

`CHARIO3.ASM` is configured for the S100Computers Console I/O board:

```text
status port: 00h
data port:   01h
```

## Dual IDE/CF board

`HIDE3.ASM` uses the S100Computers Dual IDE/CF board 8255 interface:

```text
30h  IDE 8255 port A, lower data byte
31h  IDE 8255 port B, upper data byte
32h  IDE 8255 port C, control lines
33h  IDE 8255 control register
34h  physical CF selector, bit 0: 0=CF #0, 1=CF #1
```

The recovered working dual-CF image established the initialization behavior used by the gold source: after the IDE reset pulse, wait for the selected CF to become not-busy/ready before ATA task-file programming.

## Digital Systems FDS

The DSI path is:

```text
S-100 bus -> Digital Systems HB-1.3 -> FDC-2 -> two 8-inch drives
```

FDC-2 ports used by `DSIFDC2.ASM`:

```text
7Dh OUT  DMA address low
7Eh OUT  DMA address high
7Fh OUT  FDC command
7Fh IN   FDC status
```

Physical unit mapping:

```text
C: -> FDC-2 unit 0
D: -> FDC-2 unit 1
```

The DSI controller bus-masters/DMA-transfers through the HB-1.3. The driver uses a private 131-byte bounce buffer so the FDC's three-byte `track, sector, FBh` descriptor does not overwrite memory immediately preceding CP/M's DMA buffer.
