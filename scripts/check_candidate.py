#!/usr/bin/env python3
"""Static consistency checks for the FDC+3712 CP/M 3 candidate."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
driver = (ROOT / "src/FDC3712.ASM").read_text(encoding="ascii")
table = (ROOT / "src/HDRVTBL3.ASM").read_text(encoding="ascii")
build_script = (ROOT / "scripts/build.sh").read_text(encoding="utf-8")
link_log = (ROOT / "build/logs/link.log").read_text(encoding="ascii")
hboot = (ROOT / "src/HBOOT3.ASM").read_text(encoding="ascii")

required_driver_lines = {
    "C$READ": "03H",
    "C$WRITE": "05H",
    "C$RDCRC": "07H",
    "C$SEEK": "09H",
    "C$CLRERR": "0BH",
    "C$RESTOR": "0DH",
    "C$SETTRK": "11H",
    "C$LDCFG": "15H",
    "C$DRVSEC": "21H",
    "C$WRTBUF": "31H",
    "C$RDBUF": "40H",
    "C$SHIFT": "41H",
    "C$RESET": "81H",
    "CMDOUT": "08H",
    "DATAIN": "08H",
    "DATAOUT": "09H",
}
for symbol, value in required_driver_lines.items():
    pattern = rf"(?m)^{re.escape(symbol)}\s+EQU\s+{re.escape(value)}\s*$"
    if not re.search(pattern, driver):
        raise SystemExit(f"missing or changed controller definition: {symbol}={value}")

required_fragments = [
    "FDC$DPB:\tDPB\t128,26,77,1024,64,2",
    "FDC$XLT:\tSKEW\t26,6,0",
    "MVI\tD,4",
    "MVI\tA,C$RDCRC",
    "MVI\tA,2",
]
for fragment in required_fragments:
    if fragment not in driver:
        raise SystemExit(f"missing FDC+3712 safety/geometry fragment: {fragment!r}")

if "DPH0,DPH1,FDC0,FDC1" not in table:
    raise SystemExit("logical drive table is not A:/B: IDE plus C:/D: FDC+3712")
if "DSIFDC2" in build_script or (ROOT / "src/DSIFDC2.ASM").exists():
    raise SystemExit("obsolete DSI module is still active")
if "FDC3712" not in build_script:
    raise SystemExit("FDC3712 is missing from the RMAC/LINK build")
for banner in (
    "CP/M 3 NON-BANKED - IMSAI TARGET FDC+3712",
    "A:IDE0 B:IDE1 C:FDC8-0 D:FDC8-1",
):
    if banner not in hboot:
        raise SystemExit(f"candidate boot banner is missing: {banner}")

code_lines = [
    line.split(";", 1)[0].upper()
    for line in driver.splitlines()
]
code = "\n".join(code_lines)
for address in ("0F400H", "0FF00H"):
    if address in code:
        raise SystemExit(f"forbidden ROM dependency found in executable source: {address}")

if "UNDEFINED" in link_log.upper():
    raise SystemExit("LINK reported undefined symbols")
for symbol in ("FDC0", "FDC1"):
    if not re.search(rf"\b{symbol}\b", link_log):
        raise SystemExit(f"linked BIOS is missing {symbol}")

print("FDC+3712 candidate source/link consistency checks passed")
