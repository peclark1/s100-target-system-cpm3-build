# Source File Roles

| File | Purpose |
|---|---|
| `BIOSKRNL.ASM` | CP/M 3 modular BIOS kernel |
| `SCB3.ASM` | CP/M 3 System Control Block module |
| `HBOOT3.ASM` | cold/warm boot and sign-on logic |
| `CHARIO3.ASM` | Console I/O character driver, ports 00H/01H |
| `MOVE3.ASM` | non-banked memory move support |
| `HDRVTBL3.ASM` | logical drive table A/B/C/D |
| `HIDE3.ASM` | Dual IDE/CF driver and ZSOS 64-sector LBA mapping |
| `FDC3712.ASM` | Altair FDC+ Drive Type 8 C:/D: driver |
| `GENCPM.DAT` | non-banked GENCPM configuration with MEMTOP=EF |
| `BDOS3.SPR` | Digital Research CP/M 3 BDOS system module |
| `CPM3.LIB` | CP/M 3 BIOS macros |
| `Z80.LIB` | Z80 macro library |
| `MODEBAUD.LIB` | character-I/O mode/baud macro support |

`reference/` contains the prior Dual-CF and Gold V3.0 DSI binaries/images. They are retained for recovery and are not linked into the FDC+3712 candidate.
