# Heath/Zenith H-25 CP/M 3 list-device support

Status: **hardware tested on the physical IMSAI 8080, 2026-09-02**

## Purpose

This build adds the period Heath/Zenith H-25 dot-matrix printer as CP/M physical character device `H25` and makes it available through the logical `LST:` device.

The printer uses the IMSAI MIO serial interface rather than either channel of the S100Computers Serial I/O V3 board:

- Serial I/O V3 channel A remains available as the 38,400-baud selectable console.
- Serial I/O V3 channel B remains available for the speech synthesizer.
- IMSAI MIO SIO is dedicated to the H-25 while the printer is connected.

## Proven hardware configuration

### IMSAI MIO SIO

| Function | Setting |
|---|---|
| Data port | `42H` |
| Status/control port | `43H` |
| Transmitter ready | status bit 0 (`01H`) |
| Receiver ready | status bit 1 (`02H`) |
| Format | 8 data bits, no parity, 1 stop bit |
| Baud preset | nominal 4800 (`FDB`) |
| Actual baud on this IMSAI | approximately 9600 |

The MIO receives a serial clock approximately twice the rate assumed by the original baud table. Therefore the manual's nominal 4800 preset is used to obtain an actual baud rate of approximately 9600.

The `FDB` preset is binary `1111 1101 1011`. In the MIO baud jumper area, row A is logic 0, row B is logic 1, and row C is the counter input. The tested preset is:

```text
U13 (bits 11..8): C-B C-B C-B C-B
U14 (bits  7..4): C-B C-B C-A C-B
U27 (bits  3..0): C-B C-A C-B C-B
```

### Heath/Zenith H-25

Use:

```text
9600 baud
8 data bits
no parity
1 stop bit
DC1/DC3 (XON/XOFF) enabled
ETX/ACK disabled
busy polarity 0
```

The H-25's DC1/DC3 protocol sends `13H` (DC3/XOFF) when the printer must pause input and `11H` (DC1/XON) when transmission may resume.

### Cable

Use the same RS-232 cable/adapter arrangement proven during the physical H-25/MIO testing. The serial path was verified bidirectionally because the printer's DC1/DC3 flow-control characters must return to the MIO receiver.

## Hardware verification

The complete path has been verified on the physical IMSAI in two stages.

First, the standalone CP/M transient program `H25MIO2.COM` successfully printed a long test through MIO ports `42H/43H` at actual 9600 baud while honoring H-25 DC1/DC3 flow control. This verified:

- MIO serial transmit;
- MIO serial receive;
- actual 9600-baud operation with the nominal-4800 MIO preset;
- H-25 serial receive;
- H-25 XOFF/XON return path;
- bidirectional software flow control during a print job.

Second, the CP/M 3 BIOS integration was installed and tested on the physical IMSAI. A roughly ten-page assembler listing was printed successfully through `LST:` with no corruption or hang. The job is far larger than the H-25 input buffer, providing a sustained real-world validation of the CP/M list-device path and DC1/DC3 flow-control handling. Print quality was acceptable; the remaining weakness is a faded ribbon rather than a communications issue.

## CP/M 3 implementation

`src/CHARIO3.ASM` exposes two physical CP/M character devices:

```text
CRT     front-panel-selected console abstraction
H25     Heath/Zenith H-25 through IMSAI MIO SIO
```

`H25` is an output serial device with CP/M 3 XON/XOFF protocol enabled. Its device handlers use the existing MIO routines:

- initialize: write `00H` to MIO control/status port `43H`;
- input status / input: read returned XON/XOFF characters through the MIO receiver;
- output status: test MIO TRDY;
- output: write the character to MIO data port `42H`.

The normal CP/M 3 BIOS kernel already contains the XON/XOFF state machine. When the physical-device mode has XON/XOFF enabled, BIOSKRNL consumes DC3/DC1 from the device and stops/resumes list output automatically.

## LST: behavior on the tested build

On the hardware-tested generated system, `LST:` was already routed to the H-25 after boot. No manual `DEVICE LST:=H25[XON]` command was required before printing.

The `[XON]` qualifier is also unnecessary for this device because XON/XOFF capability is part of the `H25` physical-device definition in `@CTBL`.

`DEVICE` can still be used to inspect or change the current CP/M logical-device assignments. If reassignment is desired explicitly, `H25` remains available as the physical printer device.

A normal print command is simply:

```text
PIP LST:=README.TXT
```

Any ordinary CP/M program that writes to the logical list device can use the H-25 in the same way. The successful physical acceptance test used an assembler listing of approximately ten pages.

## Shared MIO-port caveat

The H-25 physical device and the front-panel-selectable MIO console both refer to the same MIO SIO hardware at `42H/43H`.

While the H-25 is connected as the printer, select Console I/O or Serial I/O A as the system console. Do not simultaneously use MIO as the interactive console and H-25 printer.

The MIO console capability is intentionally retained. With the printer disconnected, a suitable 9600-baud terminal can still be connected to the MIO and selected by the front-panel console switches.

The existing boot-time console announcement probes all three console outputs. Consequently an online H-25 attached to the MIO may receive the short `Console device selected:` startup announcement even when another console is selected. This is harmless and preserves the existing console-failsafe behavior.

## Physical acceptance result

Accepted on the physical IMSAI 8080 on 2026-09-02:

1. CP/M 3 booted successfully with the H-25 BIOS integration installed.
2. Native `LST:` output reached the H-25 without requiring a manual `DEVICE` assignment.
3. A roughly ten-page assembler listing printed successfully.
4. No serial corruption, buffer overrun, or print-job hang was observed.
5. Sustained output well beyond the H-25 input-buffer capacity validates the practical XON/XOFF flow-control path.

This configuration is considered hardware tested and suitable for the IMSAI target-system baseline.
