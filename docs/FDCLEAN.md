# FDCLEAN.COM

`FDCLEAN.COM` is a CP/M transient utility for cleaning 8-inch floppy-drive heads through the Altair FDC+ Drive Type 8 (iCOM 3712-compatible) interface.

Its motion pattern is modelled on Keir Fraser's Greaseweazle `gw clean` command: the drive remains selected while the head is moved in a zig-zag pattern, pausing briefly at each endpoint. Greaseweazle credits the same general technique to Dave Dunfield's ImageDisk and Phil Pemberton's Magpie/DiscFerret.

## Safety

FDCLEAN issues only controller reset/configure/select/restore/seek commands. It contains no READ or WRITE command and does not transfer sector data.

Use a proper wet or dry head-cleaning disk according to its instructions. Running FDCLEAN with an ordinary floppy inserted will only seek the head; it does not intentionally modify the media.

## Hardware assumptions

- Altair FDC+ Drive Type 8 / iCOM 3712-compatible command interface
- command/status port `08h`
- data-output port `09h`
- 77-cylinder 8-inch mechanism, tracks 0 through 76
- current CP/M 3 mapping:
  - `C:` -> FDC+ physical unit 0
  - `D:` -> FDC+ physical unit 1

Physical unit numbers `0` and `1` may also be supplied directly, so the utility itself does not depend on BDOS disk selection.

## Usage

```text
FDCLEAN C:
FDCLEAN D:
FDCLEAN 0
FDCLEAN 1
FDCLEAN C: 5
```

The optional pass count is 1 through 9. The default is 3 passes, matching Greaseweazle.

For 77 cylinders, Greaseweazle's `step = max(cylinders / 8, 2)` becomes 9. One pass therefore seeks:

```text
8 0 17 9 26 18 35 27 44 36 53 45 62 54 71 63 76 72
```

The program pauses approximately 100 ms at every listed cylinder on a 4 MHz 8080/Z80, matching Greaseweazle's default linger time closely enough for head cleaning. The delay is intentionally a software loop so the utility remains usable on ordinary CP/M without requiring a non-standard timer service.

The drive is restored to track 0 when the cleaning sweep completes or after a seek error.

## Build

From the repository root:

```sh
make fdclean
```

The build uses the repository's existing Digital Research RMAC/LINK tools through `tools/cpmrun` and writes:

```text
dist/FDCLEAN.COM
```

The source is 8080-compatible assembly even though the target IMSAI currently uses a Z80.
