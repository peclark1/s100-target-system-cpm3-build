;==============================================================================
; FDCPLUS3.ASM -- Altair FDC+ Drive Type 8 disk module for CP/M 3
; Version 0.2, non-banked, 2026-08-22
;
; Logical drives supplied by this module:
;   FDP0 = FDC+ physical drive 0
;   FDP1 = FDC+ physical drive 1
;
; Media:
;   IBM 3740 / 8-inch SSSD soft sector
;   77 tracks, 26 x 128-byte sectors, sector IDs 1..26, CP/M skew 6.
;
; Hardware assumptions:
;   FDC+ firmware 1.8, Drive Type 8, default I/O decode.
;
; IMPORTANT REGISTER MAP FOR DRIVE TYPE 8:
;   08H write = FD3712 command output
;   08H read  = FD3712 controller status / data input
;   09H write = FD3712 data output
;
; This is the exact register usage proven on the physical IMSAI by the
; read-only 3712TEST.COM and 3712BOOT.COM diagnostics.  It intentionally
; does NOT use port 0AH for the FD3712 emulation path.
;==============================================================================

        TITLE   'FDC+ TYPE 8 CP/M 3 DISK HANDLER V0.2'
        MACLIB  CPM3

;---------------- Proven FDC+3712 I/O registers ------------------------
CMDOUT  EQU     08H             ;write FD3712 command
DATAIN  EQU     08H             ;read FD3712 status/data
DATAOUT EQU     09H             ;write FD3712 data

;---------------- FD3712 command values -------------------------------
CSTATUS EQU     00H
CREAD   EQU     03H
CWRITE  EQU     05H
CRDCRC  EQU     07H
CSEEK   EQU     09H
CCLRERR EQU     0BH
CRESTOR EQU     0DH
CSETTRK EQU     11H
CLDCFG  EQU     15H
CDRVSEC EQU     21H
CWRTBUF EQU     31H
CRDBUF  EQU     40H
CSHIFT  EQU     41H
CRESET  EQU     81H

;---------------- FD3712 status bits ----------------------------------
SBUSY   EQU     01H
SSKERR  EQU     02H
SCRCERR EQU     08H
SWRTPRT EQU     10H
SNOTRDY EQU     20H

RDERR   EQU     28H             ;not-ready or CRC error
SKERR   EQU     2AH             ;not-ready, CRC, or seek error
WRERR   EQU     30H             ;not-ready or write-protect
UNITOFF EQU     25              ;hardware-unit byte after standard DPH

        EXTRN   @DMA,@TRK,@SECT
        PUBLIC  FDP0,FDP1
        CSEG

;---------------- Extended DPH: FDC+ unit 0 ---------------------------
        DW      FDP$WRITE
        DW      FDP$READ
        DW      FDP$LOGIN
        DW      FDP$INIT0
        DB      0               ;relative drive
        DB      0               ;media type
FDP0:   DPH     FDP$XLT,FDP$DPB,,
        DB      0               ;XDPH+25 hardware unit

;---------------- Extended DPH: FDC+ unit 1 ---------------------------
        DW      FDP$WRITE
        DW      FDP$READ
        DW      FDP$LOGIN
        DW      FDP$INIT1
        DB      1               ;relative drive
        DB      0               ;media type
FDP1:   DPH     FDP$XLT,FDP$DPB,,
        DB      1               ;XDPH+25 hardware unit

; Standard IBM 3740 CP/M layout.
FDP$DPB:        DPB     128,26,77,1024,64,2
FDP$XLT:        SKEW    26,6,0

;---------------- Driver state ----------------------------------------
FDP$TRK0:       DB      0FFH
FDP$TRK1:       DB      0FFH
FDP$UNIT:       DB      0
FDP$WANT:       DB      0
FDP$RETRY:      DB      0
FDP$INITMASK:   DB      0               ;bit0=unit0 restored, bit1=unit1

;---------------- Initialization / login -------------------------------
; Do not touch the floppy hardware during CP/M boot.  This keeps A:/B:
; usable even with empty or powered-down FDC+ floppy drives.  The proven
; FD3712 RESET/SELECT/RESTORE sequence is performed lazily on first access.
FDP$INIT0:
        MVI     A,0FFH
        STA     FDP$TRK0
        STA     FDP$TRK1
        XRA     A
        STA     FDP$INITMASK
        RET

FDP$INIT1:
        RET

FDP$LOGIN:
        CALL    FDP$SETUNIT
        XRA     A
        RET

; DE points at the current XDPH.  Preserve DE and HL for the caller.
FDP$SETUNIT:
        PUSH    H
        PUSH    D
        XCHG
        LXI     D,UNITOFF
        DAD     D
        MOV     A,M
        ANI     03H
        STA     FDP$UNIT
        POP     D
        POP     H
        RET

;---------------- CP/M 3 READ entry point ------------------------------
FDP$READ:
        PUSH    D
        CALL    FDP$SETUNIT
        CALL    FDP$VALID
        ORA     A
        JNZ     FDP$RDEXIT

        CALL    FDP$SETUP
        ORA     A
        JNZ     FDP$RDEXIT

        MVI     A,10
        STA     FDP$RETRY

FDP$RDTRY:
        MVI     A,CREAD
        CALL    FDP$DOCMD
        ANI     RDERR
        JZ      FDP$RDXFER

        CALL    FDP$CLRERR
        LXI     H,FDP$RETRY
        DCR     M
        JNZ     FDP$RDTRY
        JMP     FDP$RDBAD

; Exact buffer-read handshake used by the proven 3712TEST/3712BOOT code:
; issue RDBUF, read DATAIN, issue SHIFT, and repeat for all 128 bytes.
; Leave the interface in examine-status mode only after the final byte.
FDP$RDXFER:
        LHLD    @DMA
        MVI     B,128

FDP$RDLOOP:
        MVI     A,CRDBUF
        OUT     CMDOUT
        IN      DATAIN
        MOV     M,A

        MVI     A,CSHIFT
        OUT     CMDOUT

        INX     H
        DCR     B
        JNZ     FDP$RDLOOP

        XRA     A
        OUT     CMDOUT
        JMP     FDP$RDOK

FDP$RDOK:
        XRA     A
        JMP     FDP$RDEXIT

FDP$RDBAD:
        MVI     A,1
FDP$RDEXIT:
        POP     D
        RET

;---------------- CP/M 3 WRITE entry point -----------------------------
; The write-buffer handshake below follows the original FD3712 PROM driver.
; Hardware write testing must still use scratch media until verified.
FDP$WRITE:
        PUSH    D
        CALL    FDP$SETUNIT
        CALL    FDP$VALID
        ORA     A
        JNZ     FDP$WREXIT

        CALL    FDP$SETUP
        ORA     A
        JNZ     FDP$WREXIT

; Preload one 128-byte sector into the FD3712 write buffer.
        LHLD    @DMA
        MVI     B,128

FDP$WBLOOP:
        MOV     A,M
        OUT     DATAOUT
        MVI     A,CWRTBUF
        OUT     CMDOUT
        XRA     A
        OUT     CMDOUT
        INX     H
        DCR     B
        JNZ     FDP$WBLOOP

        MVI     A,10
        STA     FDP$RETRY

FDP$WRTRY:
        MVI     A,CWRITE
        CALL    FDP$DOCMD
        ANI     WRERR
        JNZ     FDP$WRFAIL

; Re-read the sector CRC before reporting success.
        MVI     A,CRDCRC
        CALL    FDP$DOCMD
        ANI     RDERR
        JZ      FDP$WROK

FDP$WRFAIL:
        CALL    FDP$CLRERR
        LXI     H,FDP$RETRY
        DCR     M
        JNZ     FDP$WRTRY
        MVI     A,1
        JMP     FDP$WREXIT

FDP$WROK:
        XRA     A
FDP$WREXIT:
        POP     D
        RET

;---------------- Validate fixed-format request ------------------------
FDP$VALID:
        LHLD    @TRK
        MOV     A,H
        ORA     A
        JNZ     FDP$BAD
        MOV     A,L
        CPI     77
        JNC     FDP$BAD

        LDA     @SECT
        CPI     26
        JNC     FDP$BAD

        XRA     A
        RET

FDP$BAD:
        MVI     A,1
        RET

;---------------- Select unit/sector and seek --------------------------
FDP$SETUP:
; Perform the proven RESET/SELECT/RESTORE sequence once per physical unit.
        CALL    FDP$ENSURE
        ORA     A
        RNZ

; Configuration zero selects the FD3712 single-density IBM 3740 path.
        XRA     A
        OUT     DATAOUT
        MVI     A,CLDCFG
        CALL    FDP$OUTCMD

; Select requested physical sector, then seek requested track.
        CALL    FDP$SELECTSEC
        JMP     FDP$SEEK

; Lazy controller/drive initialization.  RESET is issued once globally;
; each drive is RESTOREd the first time CP/M actually accesses it.
FDP$ENSURE:
        MVI     B,1
        LDA     FDP$UNIT
        ORA     A
        JZ      FDP$ENMASK
        MVI     B,2
FDP$ENMASK:
        LDA     FDP$INITMASK
        ANA     B
        JNZ     FDP$ENOK

        LDA     FDP$INITMASK
        ORA     A
        JNZ     FDP$ENNORESET
        MVI     A,CRESET
        CALL    FDP$OUTCMD

FDP$ENNORESET:
; Select this unit with sector 1 exactly as the proven diagnostics do.
        CALL    FDP$SELECTONE
        MVI     A,CRESTOR
        CALL    FDP$DOCMD
        ANI     SKERR
        JNZ     FDP$ENBAD

; Mark this physical unit initialized and known at track zero.
        LDA     FDP$INITMASK
        ORA     B
        STA     FDP$INITMASK
        CALL    FDP$TRKPTR
        MVI     M,0
FDP$ENOK:
        XRA     A
        RET
FDP$ENBAD:
        MVI     A,1
        RET

; Select current physical unit, sector 1.
FDP$SELECTONE:
        LDA     FDP$UNIT
        ANI     03H
        RRC
        RRC
        ORI     01H
        OUT     DATAOUT
        MVI     A,CDRVSEC
        CALL    FDP$OUTCMD
        RET

; Select current physical unit and CP/M-translated sector.
; CP/M @SECT is 0..25 after SKEW; FD3712 sectors are 1..26.
FDP$SELECTSEC:
        LDA     FDP$UNIT
        ANI     03H
        RRC
        RRC
        MOV     C,A

        LDA     @SECT
        INR     A
        ORA     C
        OUT     DATAOUT
        MVI     A,CDRVSEC
        CALL    FDP$OUTCMD
        RET

FDP$TRKPTR:
        LXI     H,FDP$TRK0
        LDA     FDP$UNIT
        ORA     A
        RZ
        INX     H
        RET

FDP$SEEK:
        LHLD    @TRK
        MOV     A,L
        STA     FDP$WANT

        CALL    FDP$TRKPTR
        LDA     FDP$WANT
        CMP     M
        JNZ     FDP$SKMOVE
        XRA     A
        RET

FDP$SKMOVE:
        MVI     A,2
        STA     FDP$RETRY

FDP$SKTRY:
        LDA     FDP$WANT
        OUT     DATAOUT
        MVI     A,CSETTRK
        CALL    FDP$OUTCMD

        MVI     A,CSEEK
        CALL    FDP$DOCMD
        ANI     SKERR
        JZ      FDP$SKOK

        CALL    FDP$CLRERR
        CALL    FDP$TRKPTR
        MVI     M,0FFH
        LXI     H,FDP$RETRY
        DCR     M
        JNZ     FDP$SKTRY

        MVI     A,1
        RET

FDP$SKOK:
        CALL    FDP$TRKPTR
        LDA     FDP$WANT
        MOV     M,A
        XRA     A
        RET

;---------------- Command helpers -------------------------------------
FDP$CLRERR:
        MVI     A,CCLRERR

; Issue command in A and then write zero to return to examine-status mode.
FDP$OUTCMD:
        OUT     CMDOUT
        XRA     A
        OUT     CMDOUT
        RET

; Issue command A, wait for BUSY to clear, then return the full status byte.
; Mike Douglas's PROM waits indefinitely; this BIOS retains a bounded timeout
; so an absent/unpowered subsystem cannot hang CP/M forever.
FDP$DOCMD:
        PUSH    B
        PUSH    D
        CALL    FDP$OUTCMD
        MVI     D,8

FDP$WAIT0:
        LXI     B,0
FDP$WAIT1:
        IN      DATAIN
        ANI     SBUSY
        JZ      FDP$CMDDONE
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     FDP$WAIT1
        DCR     D
        JNZ     FDP$WAIT0

        POP     D
        POP     B
        MVI     A,SNOTRDY
        RET

FDP$CMDDONE:
        IN      DATAIN
        POP     D
        POP     B
        RET

        END
