;==============================================================================
; FDCPLUS3.ASM -- Altair FDC+ Drive Type 8 disk module for CP/M 3
; Version 0.1, non-banked, 2026-08-22
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
;   08H read  = status
;   09H write = command
;   0AH read/write = controller data
;
; The command protocol is the iCOM/Pertec FD3712 protocol emulated by
; FDC+ Drive Type 8.  The FDC+ register placement above follows the
; FDC+ manual's default 08H-0AH interface.  This is an experimental
; module until verified on the physical IMSAI/FDC+.
;==============================================================================

        TITLE   'FDC+ TYPE 8 CP/M 3 DISK HANDLER V0.1'
        MACLIB  CPM3

;---------------- FDC+ default I/O registers ---------------------------
FDPSTS  EQU     08H             ;read controller status
FDPCMD  EQU     09H             ;write FD3712 command
FDPDAT  EQU     0AH             ;read/write controller data

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
CCLEAR  EQU     81H

;---------------- FD3712 status bits ----------------------------------
SBUSY   EQU     01H
SSKERR  EQU     02H
SCRCERR EQU     08H
SWRTPRT EQU     10H
SNOTRDY EQU     20H

RDERR   EQU     28H             ;not-ready or CRC error
SKERR   EQU     22H             ;not-ready or seek error
WRERR   EQU     38H             ;not-ready, write-protect, or CRC
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

;---------------- Initialization / login -------------------------------
; Do not touch the floppy hardware during CP/M boot.  This keeps A:/B:
; usable even with empty or powered-down FDC+ floppy drives.
FDP$INIT0:
        MVI     A,0FFH
        STA     FDP$TRK0
        STA     FDP$TRK1
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

; The FD3712 has a sector buffer.  CRDBUF exposes byte zero; each CSHIFT
; advances to the next byte.  The FDC+ data register is read at 0AH.
FDP$RDXFER:
        LHLD    @DMA
        MVI     B,128

        MVI     A,CRDBUF
        OUT     FDPCMD
        IN      FDPDAT
        MOV     M,A
        INX     H
        XRA     A
        OUT     FDPCMD
        DCR     B
        JZ      FDP$RDOK

FDP$RDLOOP:
        MVI     A,CSHIFT
        OUT     FDPCMD
        IN      FDPDAT
        MOV     M,A
        INX     H
        XRA     A
        OUT     FDPCMD
        DCR     B
        JNZ     FDP$RDLOOP

FDP$RDOK:
        XRA     A
        JMP     FDP$RDEXIT

FDP$RDBAD:
        MVI     A,1
FDP$RDEXIT:
        POP     D
        RET

;---------------- CP/M 3 WRITE entry point -----------------------------
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
        OUT     FDPDAT
        MVI     A,CWRTBUF
        OUT     FDPCMD
        XRA     A
        OUT     FDPCMD
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

; Ask the controller to re-read the sector CRC before reporting success.
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
; Configuration zero selects the FD3712 single-density IBM 3740 path.
        XRA     A
        OUT     FDPDAT
        MVI     A,CLDCFG
        CALL    FDP$OUTCMD

; CP/M @SECT is 0..25 after SKEW.  FD3712 sectors are numbered 1..26.
        LDA     FDP$UNIT
        ANI     03H
        RRC
        RRC
        MOV     C,A

        LDA     @SECT
        INR     A
        ORA     C
        OUT     FDPDAT
        MVI     A,CDRVSEC
        CALL    FDP$OUTCMD

        JMP     FDP$SEEK

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
        OUT     FDPDAT
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

; Commands are strobed with bit 0 set in the command value.  Writing zero
; afterward returns the emulated FD3712 interface to status mode.
FDP$OUTCMD:
        OUT     FDPCMD
        XRA     A
        OUT     FDPCMD
        RET

; Issue command A, wait for BUSY to clear, then return the full status byte.
; A software timeout prevents an absent/unpowered floppy subsystem from
; hanging CP/M forever.  The loop is deliberately generous at Z80 speeds.
FDP$DOCMD:
        PUSH    B
        PUSH    D
        CALL    FDP$OUTCMD
        MVI     D,8

FDP$WAIT0:
        LXI     B,0
FDP$WAIT1:
        IN      FDPSTS
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
        IN      FDPSTS
        POP     D
        POP     B
        RET

        END
