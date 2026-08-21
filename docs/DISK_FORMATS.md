# Disk Formats

## IDE/CF — A: and B:

The working image uses the later ZSOS/David Fry "no holes" geometry:

```text
physical sector size:    512 bytes
sectors per CP/M track:  64
CP/M tracks:             256
allocation block:        2048 bytes
reserved tracks:         1
LBA:                     track * 64 + sector
```

Source DPB:

```asm
DPB 512,64,256,2048,1024,1,8000H
```

The directory begins at LBA 64. The gold base image keeps `CPM3.SYS` in allocation blocks 16–21.

## Digital Systems 8-inch — C: and D:

The initial DSI driver targets standard IBM 3740 / CP/M single-density media:

```text
tracks:                  77
sectors per track:       26
sector size:             128 bytes
physical sector IDs:     1..26
CP/M sector values:      0..25 before driver adjustment
skew:                    6
allocation block:        1024 bytes
directory entries:       64
reserved tracks:         2
```

Source definitions:

```asm
DSI$DPB: DPB 128,26,77,1024,64,2
DSI$XLT: SKEW 26,6,0
```

The driver adds one to CP/M's translated sector value before issuing the FDC-2 operation, converting 0..25 to physical sector IDs 1..26.
