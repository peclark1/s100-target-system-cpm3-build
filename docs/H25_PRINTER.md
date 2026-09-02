# Heath/Zenith H-25 CP/M 3 list-device support

Status: **hardware path proven; CP/M integration candidate awaiting physical acceptance test**

## Purpose

This build adds the period Heath/Zenith H-25 dot-matrix printer as CP/M physical character device `H25` and allows it to be assigned to the logical `LST:` device.

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

The `FDB` preset is binary `1111 1101 1011`. In the MIO baud jumper area, row A is logic 0, row B is logic 1, and row C is the counter input. The current preset is:

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

Use the same RS-232 cable/adapter arrangement proven with `H25MIO2.COM`. Record the final straight-through/null-modem wiring in this document after the final CP/M acceptance test.

## Hardware verification already completed

A standalone CP/M transient program, `H25MIO2.COM`, successfully printed a long test through MIO ports `42H/43H` at actual 9600 baud while honoring H-25 DC1/DC3 flow control. This verifies:

- MIO serial transmit;
- MIO serial receive;
- actual 9600-baud operation with the nominal-4800 MIO preset;
- H-25 serial receive;
- H-25 XOFF generation;
- H-25 XON generation;
- bidirectional software flow control during a print job.

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

## Assigning LST:

The H-25 is deliberately **not assigned to `LST:` permanently in the system image**, because the printer will not always be connected.

After booting CP/M 3 with the printer connected and online, assign it with:

```text
DEVICE LST:=H25[XON]
```

Use `DEVICE` without arguments to inspect the current assignments.

A simple print test is then:

```text
PIP LST:=README.TXT
```

Any ordinary CP/M program that writes to the logical list device will then use the H-25.

If permanent automatic assignment is later desired, put the `DEVICE LST:=H25[XON]` command in `PROFILE.SUB`.

## Shared MIO-port caveat

The H-25 physical device and the front-panel-selectable MIO console both refer to the same MIO SIO hardware at `42H/43H`.

While the H-25 is connected and assigned as `LST:`, select Console I/O or Serial I/O A as the system console. Do not simultaneously use MIO as the interactive console and H-25 printer.

The MIO console capability is intentionally retained. With the printer disconnected, a suitable 9600-baud terminal can still be connected to the MIO and selected by the front-panel console switches.

The existing boot-time console announcement probes all three console outputs. Consequently an online H-25 attached to the MIO may receive the short `Console device selected:` startup announcement even when another console is selected. This is harmless and preserves the existing console-failsafe behavior.

## Physical CP/M acceptance test

1. Install the candidate `CPM3.SYS` or candidate CF image built from `feature/h25-lst`.
2. Select Console I/O as the IMSAI console.
3. Boot CP/M 3 and confirm A:/B:/C:/D: behavior is unchanged.
4. Run `DEVICE` and confirm physical device `H25` is present.
5. Run:

   ```text
   DEVICE LST:=H25[XON]
   ```

6. Print a short file with `PIP LST:=filename`.
7. Print a file substantially larger than the H-25's input buffer and verify that output completes without corruption or hanging.
8. Take the H-25 offline during a long job, then return it online and verify that XOFF/XON pauses and resumes the job correctly.
9. After successful hardware testing, record the exact cable wiring and promote the candidate as tested.
