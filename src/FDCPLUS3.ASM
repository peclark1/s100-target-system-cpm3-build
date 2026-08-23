;==============================================================================
; FDCPLUS3.ASM -- Altair FDC+ Drive Type 8 adapter for CP/M 3
; Version 0.3, non-banked, 2026-08-22
;
; This module deliberately does NOT duplicate the FD3712 controller driver.
; The target 4K master ROM already contains the physically-proven native
; FDC+3712 implementation used to boot/read/write CP/M 2.2 on this IMSAI.
;
; Stable master-ROM API (added to the former FB92H-FB9FH reserved gap):
;   FB92H  INIT    - initialize/reset/restore the FDC+3712 path
;   FB95H  SELDRV  - C = physical unit 0/1
;   FB98H  READ    - read one 128-byte sector
;   FB9BH  WRITE   - write one 128-byte sector
;
; The ROM service uses its original Mike-Douglas-compatible workspace at
; 0040H-0047H.  CP/M 3 must not lose page-zero contents, so this adapter saves
; those eight bytes, installs a private persistent ROM-driver state, performs
; the operation, captures the updated state, and restores page zero.
;
; Logical drives supplied by this module:
;   FDP0 = FDC+ physical drive 0
;   FDP1 = FDC+ physical drive 1
;
; Media:
;   IBM 3740 / 8-inch SSSD soft sector
;   77 tracks, 26 x 128-byte sectors, sector IDs 1..26, CP/M skew 6.
;==============================================================================

        TITLE   'FDC+ TYPE 8 CP/M 3 ROM ADAPTER V0.3'
        MACLIB  CPM3

;---------------- Stable target-ROM FDC API ----------------------------
ROMINIT EQU     0FB92H
ROMSEL  EQU     0FB95H
ROMREAD EQU     0FB98H
ROMWRITE EQU    0FB9BH

;---------------- ROM driver's page-zero workspace --------------------
RDRVNUM EQU     0040H
RTRKNUM EQU     0041H
RSECNUM EQU     0042H
RDMAADR EQU     0043H           ;word, 0043H-0044H
RDRVTRK EQU     0045H
RBIOSAD EQU     0046H           ;word, 0046H-0047H
RWSLEN  EQU     8
MODELOC EQU     0033H           ;ROM WRITE checks BIOSADR+33H bit 6

        EXTRN   @DMA,@TRK,@SECT,@RDRV
        PUBLIC  FDP0,FDP1
        CSEG

;---------------- Extended DPH: FDC+ unit 0 ---------------------------
        DW      FDP$WRITE
        DW      FDP$READ
        DW      FDP$LOGIN
        DW      FDP$INIT0
        DB      0               ;relative drive -> @RDRV
        DB      0               ;media type
FDP0:   DPH     FDP$XLT,FDP$DPB,,

;---------------- Extended DPH: FDC+ unit 1 ---------------------------
        DW      FDP$WRITE
        DW      FDP$READ
        DW      FDP$LOGIN
        DW      FDP$INIT1
        DB      1               ;relative drive -> @RDRV
        DB      0               ;media type
FDP1:   DPH     FDP$XLT,FDP$DPB,,

; Standard IBM 3740 CP/M layout.
FDP$DPB:        DPB     128,26,77,1024,64,2
FDP$XLT:        SKEW    26,6,0

;---------------- Adapter state ---------------------------------------
; FDP$STATE mirrors ROM workspace 0040H-0047H between calls.  The ROM's
; single DRVTRK cache is therefore preserved without leaving private data in
; CP/M page zero.  SELDRV invalidates that cache when the physical unit changes,
; exactly as the proven ROM BIOS path does.
FDP$STATE:      DS      RWSLEN
FDP$SAVE:       DS      RWSLEN
FDP$INITED:     DB      0
FDP$OP:         DB      0               ;0=read, 1=write
FDP$LAST:       DB      0
FDP$MODE:       DB      0               ;match proven ROM: write verify disabled

;---------------- Initialization / login -------------------------------
; Keep CP/M cold boot hardware-silent.  The ROM FDC initialization is invoked
; lazily on the first actual C:/D: read or write.
FDP$INIT0:
        XRA     A
        STA     FDP$INITED

        LXI     H,FDP$STATE
        MVI     B,RWSLEN
FDP$I0CLR:
        MOV     M,A
        INX     H
        DCR     B
        JNZ     FDP$I0CLR

        LXI     H,FDP$STATE+5           ;ROM DRVTRK starts unknown
        MVI     M,0FFH
        RET

FDP$INIT1:
        RET

FDP$LOGIN:
        XRA     A
        RET

;---------------- CP/M 3 READ / WRITE entry points --------------------
FDP$READ:
        XRA     A
        STA     FDP$OP
        JMP     FDP$RW

FDP$WRITE:
        MVI     A,1
        STA     FDP$OP

FDP$RW:
        CALL    FDP$VALID
        ORA     A
        RNZ

; Preserve CP/M page-zero, then install the ROM driver's private state.
        CALL    FDP$SAVEZERO
        CALL    FDP$LOADSTATE

; First use verifies the ROM ABI and initializes the controller through the
; exact same INIT_ALL routine used by the native floppy boot path.
        CALL    FDP$ENSURE
        ORA     A
        JNZ     FDP$RWFAIL

        CALL    FDP$PREP
        ORA     A
        JNZ     FDP$RWFAIL

        LDA     FDP$OP
        ORA     A
        JNZ     FDP$CALLWRITE
        CALL    ROMREAD
        JMP     FDP$RWDONE

FDP$CALLWRITE:
        CALL    ROMWRITE
        JMP     FDP$RWDONE

FDP$RWFAIL:
        MVI     A,1

FDP$RWDONE:
; Save the ROM routine's return value before copying workspace bytes.
        STA     FDP$LAST
        CALL    FDP$SAVESTATE
        CALL    FDP$RESTOREZERO
        LDA     FDP$LAST
        RET

;---------------- Validate fixed IBM-3740 request ---------------------
FDP$VALID:
        LHLD    @TRK
        MOV     A,H
        ORA     A
        JNZ     FDP$BAD
        MOV     A,L
        CPI     77
        JNC     FDP$BAD

        LHLD    @SECT
        MOV     A,H
        ORA     A
        JNZ     FDP$BAD
        MOV     A,L
        CPI     26
        JNC     FDP$BAD

        XRA     A
        RET

FDP$BAD:
        MVI     A,1
        RET

;---------------- Lazy ROM/controller initialization ------------------
FDP$ENSURE:
        LDA     FDP$INITED
        ORA     A
        RNZ

; Refuse to jump into an older ROM whose reserved gap is still FFH.  Each
; public entry must begin with an absolute JP opcode (C3H).
        LDA     ROMINIT
        CPI     0C3H
        JNZ     FDP$BAD
        LDA     ROMSEL
        CPI     0C3H
        JNZ     FDP$BAD
        LDA     ROMREAD
        CPI     0C3H
        JNZ     FDP$BAD
        LDA     ROMWRITE
        CPI     0C3H
        JNZ     FDP$BAD

        CALL    ROMINIT
; INIT_ALL returns raw controller status.  The native ROM boot intentionally
; proceeds to READ and lets the proven read path classify/retry errors, so do
; the same here rather than inventing a second status policy.
        MVI     A,1
        STA     FDP$INITED
        XRA     A
        RET

;---------------- Translate CP/M request into ROM workspace -----------
FDP$PREP:
; CP/M BIOSKRNL publishes the XDPH relative drive in @RDRV immediately before
; entering this read/write routine.  Use that official interface rather than a
; private byte appended to the DPH.
        LDA     @RDRV
        ANI     01H
        MOV     B,A

; Avoid re-selecting an unchanged drive because the proven ROM SELDRV routine
; deliberately invalidates its track cache whenever a new drive is selected.
        LDA     RDRVNUM
        CMP     B
        JZ      FDP$UNITOK
        MOV     C,B
        CALL    ROMSEL
FDP$UNITOK:

        LHLD    @TRK
        MOV     A,L
        STA     RTRKNUM

; CP/M's SKEW table leaves @SECT in the 0..25 domain.  The FDC+3712 ROM
; expects physical IBM-3740 sector numbers 1..26.
        LHLD    @SECT
        MOV     A,L
        INR     A
        STA     RSECNUM

        LHLD    @DMA
        SHLD    RDMAADR

; ROM WRITE optionally reads MODE bit 6 at BIOSADR+33H.  Point BIOSADR at our
; private zero-valued FDP$MODE byte so CP/M 3 gets the same no-verify behavior
; as the physically-proven native 48K CP/M boot image.
        LXI     H,FDP$MODE
        LXI     D,-MODELOC
        DAD     D
        SHLD    RBIOSAD

        XRA     A
        RET

;---------------- Page-zero workspace preservation --------------------
FDP$SAVEZERO:
        LXI     H,RDRVNUM
        LXI     D,FDP$SAVE
        JMP     FDP$COPY8

FDP$LOADSTATE:
        LXI     H,FDP$STATE
        LXI     D,RDRVNUM
        JMP     FDP$COPY8

FDP$SAVESTATE:
        LXI     H,RDRVNUM
        LXI     D,FDP$STATE
        JMP     FDP$COPY8

FDP$RESTOREZERO:
        LXI     H,FDP$SAVE
        LXI     D,RDRVNUM
        ; fall through

FDP$COPY8:
        MVI     B,RWSLEN
FDP$C8LOOP:
        MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     FDP$C8LOOP
        RET

        END
