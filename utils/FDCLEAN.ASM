;==============================================================================
; FDCLEAN.ASM -- CP/M floppy head cleaning utility for Altair FDC+ Drive Type 8
; Version 0.1, 2026-08-23
;
; Modelled after Greaseweazle "gw clean": keep the drive selected and move the
; head in a zig-zag pattern with a short dwell at each endpoint.
;
; IMPORTANT:
;   * This program performs NO sector reads and NO writes.
;   * It talks directly to the FDC+ 3712-compatible interface at ports 08H/09H.
;   * C: maps to FDC+ physical unit 0 and D: maps to physical unit 1, matching
;     the current s100-target-system CP/M 3 configuration. Unit numbers 0/1 may
;     also be specified directly.
;   * The cleaning pattern is for a 77-cylinder 8-inch drive (tracks 0..76).
;   * The dwell loop is approximately 100 ms on a 4 MHz 8080/Z80.
;
; Usage:
;       FDCLEAN C:
;       FDCLEAN D:
;       FDCLEAN 0
;       FDCLEAN 1
;       FDCLEAN C: 5       ; optional pass count 1..9, default 3
;
; The zig-zag sequence is the 77-cylinder equivalent of Greaseweazle's:
;   step = max(cylinders / 8, 2) = 9
;   for base = 0,9,18,...72:
;       seek min(base+8,76), linger, seek base, linger
;
; Sequence per pass:
;   8 0 17 9 26 18 35 27 44 36 53 45 62 54 71 63 76 72
;
; 8080-compatible source, assembled with Digital Research RMAC/LINK.
;==============================================================================

        TITLE   'FDC+ 3712 HEAD CLEANER V0.1'

BDOS    EQU     0005H

; FDC+ 3712 command set (same values used by FDC3712.ASM).
C_SEEK  EQU     09H
C_CLRER EQU     0BH
C_REST  EQU     0DH
C_SETTR EQU     11H
C_LDCFG EQU     15H
C_DRVSC EQU     21H
C_RESET EQU     81H

; Status bits.
S_BUSY  EQU     01H
S_CRCER EQU     08H
S_NRDY  EQU     20H
S_SEKER EQU     S_CRCER+S_NRDY

; FDC+ Drive Type 8 I/O ports.
CMDOUT  EQU     08H
DATAIN  EQU     08H
DATAOUT EQU     09H

PATLEN  EQU     18

        CSEG

START:
        LXI     SP,STACKTOP
        LXI     D,BANNER
        CALL    PSTR

        CALL    PARSE
        ORA     A
        JNZ     BADUSE

        LXI     D,READYMSG
        CALL    PSTR
        LDA     UNIT
        ORA     A
        JZ      SHOWU0
        MVI     A,'1'
        JMP     SHOWUNIT
SHOWU0:
        MVI     A,'0'
SHOWUNIT:
        CALL    PCHR
        LXI     D,PASSMSG
        CALL    PSTR
        LDA     PASSES
        CALL    PDEC
        CALL    CRLF

        CALL    INITDRV
        ORA     A
        JNZ     HWFAIL

        MVI     A,1
        STA     PASSNO

PASSLP:
        LXI     D,PASSHDR
        CALL    PSTR
        LDA     PASSNO
        CALL    PDEC
        LXI     D,COLONSP
        CALL    PSTR

        LXI     H,PATTERN
        MVI     B,PATLEN

TRACKLP:
        MOV     A,M
        INX     H
        STA     CURTRK

        PUSH    B
        PUSH    H

        LDA     CURTRK
        CALL    PDEC
        MVI     A,' '
        CALL    PCHR

        LDA     CURTRK
        CALL    SEEKTRK
        STA     SEEKRC
        ORA     A
        JNZ     NOLINGER
        CALL    LINGER
NOLINGER:
        POP     H
        POP     B

        LDA     SEEKRC
        ORA     A
        JNZ     SEEKFAIL

        DCR     B
        JNZ     TRACKLP

        CALL    CRLF

        LDA     PASSNO
        MOV     B,A
        LDA     PASSES
        CMP     B
        JZ      ALLDONE
        MOV     A,B
        INR     A
        STA     PASSNO
        JMP     PASSLP

ALLDONE:
        ; Return the mechanism to track zero. Ignore a late restore error: any
        ; earlier seek error would already have stopped the run.
        CALL    RESTORE
        LXI     D,DONEMSG
        CALL    PSTR
        JMP     EXIT

BADUSE:
        LXI     D,USAGE
        CALL    PSTR
        JMP     EXIT

SEEKFAIL:
        CALL    CRLF
        LXI     D,SEEKMSG
        CALL    PSTR
        LDA     LASTSTAT
        CALL    PHEX
        CALL    CRLF
        CALL    RESTORE
        JMP     EXIT

HWFAIL:
        LXI     D,HWMSG
        CALL    PSTR
        LDA     LASTSTAT
        CALL    PHEX
        CALL    CRLF

EXIT:
        MVI     C,0
        CALL    BDOS

;------------------------------------------------------------------------------
; Parse CCP command tail.
; Accepted drive selectors: C:, D:, 0, 1. Optional pass count 1..9.
; Returns A=0 success, A=1 syntax error.
;------------------------------------------------------------------------------
PARSE:
        MVI     A,3
        STA     PASSES

        LDA     0080H
        MOV     B,A
        LXI     H,0081H
        CALL    SKIPSP

        MOV     A,B
        ORA     A
        JZ      PARBAD

        MOV     A,M
        INX     H
        DCR     B

        CPI     '0'
        JZ      PARU0
        CPI     '1'
        JZ      PARU1
        ANI     05FH
        CPI     'C'
        JZ      PARU0
        CPI     'D'
        JZ      PARU1
        JMP     PARBAD

PARU0:
        XRA     A
        STA     UNIT
        JMP     PARAFTER

PARU1:
        MVI     A,1
        STA     UNIT

PARAFTER:
        MOV     A,B
        ORA     A
        JZ      PAROK
        MOV     A,M
        CPI     ':'
        JNZ     PARNCOL
        INX     H
        DCR     B

PARNCOL:
        CALL    SKIPSP
        MOV     A,B
        ORA     A
        JZ      PAROK

        MOV     A,M
        CPI     '1'
        JC      PARBAD
        CPI     ':'             ; ':' is one past '9'
        JNC     PARBAD
        SUI     '0'
        STA     PASSES
        INX     H
        DCR     B

        CALL    SKIPSP
        MOV     A,B
        ORA     A
        JNZ     PARBAD

PAROK:
        XRA     A
        RET

PARBAD:
        MVI     A,1
        RET

SKIPSP:
        MOV     A,B
        ORA     A
        RZ
        MOV     A,M
        CPI     ' '
        RNZ
        INX     H
        DCR     B
        JMP     SKIPSP

;------------------------------------------------------------------------------
; Controller initialization.
; Reset the FDC+, load configuration 0, select the requested drive, and restore
; it to track zero before beginning the cleaning sweep.
;------------------------------------------------------------------------------
INITDRV:
        MVI     A,C_RESET
        CALL    OUTCMD
        CALL    LINGER
        CALL    SETCFG
        CALL    RESTORE
        RET

SETCFG:
        XRA     A               ; 3712 configuration bits = 0
        OUT     DATAOUT
        MVI     A,C_LDCFG
        CALL    OUTCMD
        RET

; Select physical unit 0 or 1, sector field 1. Drive bits occupy 7..6.
SELECT:
        LDA     UNIT
        ORA     A
        JZ      SEL0
        MVI     A,41H           ; unit 1 + sector 1
        JMP     SELGO
SEL0:
        MVI     A,01H           ; unit 0 + sector 1
SELGO:
        OUT     DATAOUT
        MVI     A,C_DRVSC
        CALL    OUTCMD
        RET

RESTORE:
        CALL    SETCFG
        CALL    SELECT
        MVI     A,C_REST
        CALL    DOCMD
        STA     LASTSTAT
        ANI     S_SEKER
        RZ
        MVI     A,C_CLRER
        CALL    OUTCMD
        MVI     A,1
        RET

;------------------------------------------------------------------------------
; Seek to track in A. No read command is ever issued.
;------------------------------------------------------------------------------
SEEKTRK:
        STA     CURTRK
        CALL    SETCFG
        CALL    SELECT
        LDA     CURTRK
        OUT     DATAOUT
        MVI     A,C_SETTR
        CALL    OUTCMD
        MVI     A,C_SEEK
        CALL    DOCMD
        STA     LASTSTAT
        ANI     S_SEKER
        RZ
        MVI     A,C_CLRER
        CALL    OUTCMD
        MVI     A,1
        RET

;------------------------------------------------------------------------------
; Execute FDC command in A and wait for BUSY to clear.
; Timeout is intentionally the same bounded scheme used by FDC3712.ASM.
; Returns controller status in A; FFH on timeout.
;------------------------------------------------------------------------------
DOCMD:
        CALL    OUTCMD
        MVI     D,4
TOUTER:
        LXI     B,0
TLOOP:
        IN      DATAIN
        ANI     S_BUSY
        JZ      CMDDONE
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     TLOOP
        DCR     D
        JNZ     TOUTER
        MVI     A,0FFH
        RET
CMDDONE:
        IN      DATAIN
        RET

OUTCMD:
        OUT     CMDOUT
        XRA     A               ; return interface to examine-status mode
        OUT     CMDOUT
        RET

;------------------------------------------------------------------------------
; Approximately 100 ms at 4 MHz. Greaseweazle's default linger is 100 ms; the
; exact value is not critical for a cleaning disk, so a portable software delay
; is preferable to relying on a non-standard CP/M timer service.
;------------------------------------------------------------------------------
LINGER:
        MVI     D,8
DL1:
        LXI     B,2000D
DL2:
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     DL2
        DCR     D
        JNZ     DL1
        RET

;------------------------------------------------------------------------------
; Console helpers (BDOS only).
;------------------------------------------------------------------------------
PSTR:
        MVI     C,9
        CALL    BDOS
        RET

PCHR:
        MOV     E,A
        MVI     C,2
        CALL    BDOS
        RET

CRLF:
        MVI     A,13
        CALL    PCHR
        MVI     A,10
        CALL    PCHR
        RET

; Print A as unsigned decimal 0..99.
PDEC:
        STA     NUMTMP
        XRA     A
        STA     TENSTMP
        LDA     NUMTMP
PDIV10:
        CPI     10
        JC      PDONES
        SUI     10
        STA     NUMTMP
        LDA     TENSTMP
        INR     A
        STA     TENSTMP
        LDA     NUMTMP
        JMP     PDIV10

PDONES:
        STA     ONESTMP
        LDA     TENSTMP
        ORA     A
        JZ      PDNO10
        ADI     '0'
        CALL    PCHR
PDNO10:
        LDA     ONESTMP
        ADI     '0'
        CALL    PCHR
        RET

; Print A as two hexadecimal digits.
PHEX:
        STA     HEXTMP
        RRC
        RRC
        RRC
        RRC
        ANI     0FH
        CALL    PNIB
        LDA     HEXTMP
        ANI     0FH
        CALL    PNIB
        RET

PNIB:
        CPI     10
        JC      PNDEC
        ADI     'A'-10
        JMP     PCHR
PNDEC:
        ADI     '0'
        JMP     PCHR

;------------------------------------------------------------------------------
; Greaseweazle-style 77-cylinder zig-zag pattern.
;------------------------------------------------------------------------------
PATTERN:
        DB      8,0,17,9,26,18,35,27,44
        DB      36,53,45,62,54,71,63,76,72

;------------------------------------------------------------------------------
; Messages and state.
;------------------------------------------------------------------------------
BANNER:
        DB      13,10
        DB      'FDCLEAN 0.1 - Altair FDC+ 3712 head cleaner',13,10
        DB      'Greaseweazle-style zig-zag, 77 cylinders, ~100 ms linger',13,10
        DB      'NO DISK READS OR WRITES ARE PERFORMED.',13,10,'$'

READYMSG:
        DB      'Cleaning FDC+ physical unit ','$'
PASSMSG:
        DB      ', passes ','$'
PASSHDR:
        DB      'Pass ','$'
COLONSP:
        DB      ': ','$'
DONEMSG:
        DB      13,10,'Cleaning sweep complete; drive restored to track 0.',13,10,'$'
SEEKMSG:
        DB      'Seek failed. FDC status=',' $'
HWMSG:
        DB      'FDC initialization/restore failed. Status=',' $'
USAGE:
        DB      13,10,'Usage: FDCLEAN C: [passes]',13,10
        DB      '       FDCLEAN D: [passes]',13,10
        DB      '       FDCLEAN 0  [passes]',13,10
        DB      '       FDCLEAN 1  [passes]',13,10
        DB      'passes = 1..9 (default 3)',13,10,'$'

UNIT:       DB  0
PASSES:     DB  3
PASSNO:     DB  0
CURTRK:     DB  0
SEEKRC:     DB  0
LASTSTAT:   DB  0
NUMTMP:     DB  0
TENSTMP:    DB  0
ONESTMP:    DB  0
HEXTMP:     DB  0

        DS      64
STACKTOP:

        END     START
