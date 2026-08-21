;==============================================================================
; DSIFDC2.ASM -- Digital Systems FDC-2 disk module for CP/M 3
; Version 0.2, non-banked, 2026-08-19
;
; Derived at the controller-protocol level from the period Digital Systems
; CBIOS14.ASM.  Intended for the HB-1.3 + FDC-2 in an S-100 system.
;
; Logical drives supplied by this module:
;   DSI0 = FDC-2 physical drive 0
;   DSI1 = FDC-2 physical drive 1
;
; V0.2 media: IBM 3740 / CP/M standard 8-inch single density
;   77 tracks, 26 x 128-byte sectors, sector IDs 1..26, CP/M skew 6.
;
; CP/M sector translation follows John Monahan's non-banked floppy BIOS:
;   SKEW 26,6,0 gives @SECT = 0..25; the driver adds 1 for the FDC.
;
; FDC-2 ports:
;   7DH DMA address low
;   7EH DMA address high
;   7FH command output / status input
;
; FDC-2 sector DMA requires track,sector,FB immediately ahead of 128 data
; bytes.  This driver uses a private 131-byte bounce buffer rather than
; overwriting the three bytes before CP/M's DMA address.
;==============================================================================

	TITLE	'DSI FDC-2 CP/M 3 DISK HANDLER V0.2'
	MACLIB	CPM3

FDCLO	EQU	7DH
FDCHI	EQU	7EH
FDCCMD	EQU	7FH
FDCSTS	EQU	7FH
UNIT$OFF EQU	25		;extra hardware-select byte after standard DPH

	EXTRN	@DMA,@TRK,@SECT
	PUBLIC	DSI0,DSI1
	CSEG

;---------------- Extended DPH: FDC-2 unit 0 --------------------------
	DW	DSI$WRITE
	DW	DSI$READ
	DW	DSI$LOGIN
	DW	DSI$INIT0
	DB	0			;relative drive
	DB	0			;media type
DSI0:	DPH	DSI$XLT,DSI$DPB,,
	DB	0			;XDPH+25 hardware unit

;---------------- Extended DPH: FDC-2 unit 1 --------------------------
	DW	DSI$WRITE
	DW	DSI$READ
	DW	DSI$LOGIN
	DW	DSI$INIT1
	DB	1			;relative drive
	DB	0			;media type
DSI1:	DPH	DSI$XLT,DSI$DPB,,
	DB	1			;XDPH+25 hardware unit

DSI$DPB:	DPB	128,26,77,1024,64,2
DSI$XLT:	SKEW	26,6,0

;---------------- Driver state ----------------------------------------
DSI$TRK0:	DB	0FFH		;unknown physical track
DSI$TRK1:	DB	0FFH
DSI$UNIT:	DB	0
DSI$WANT:	DB	0
DSI$RWCMD:	DB	0
DSI$RETRY:	DB	0
DSI$LAST:	DB	0

; FDC descriptor + 128-byte data field.
DSI$BUF:	DS	131

;---------------- Initialization / login ------------------------------
DSI$INIT0:
	MVI	A,0FFH
	STA	DSI$TRK0
	STA	DSI$TRK1
	RET
DSI$INIT1:
	RET

DSI$LOGIN:
	CALL	DSI$SETUNIT
	XRA	A
	RET

; DE points at the current XDPH. Preserve caller's DE and HL.
DSI$SETUNIT:
	PUSH	H
	PUSH	D
	XCHG
	LXI	D,UNIT$OFF
	DAD	D
	MOV	A,M
	ANI	01H
	STA	DSI$UNIT
	POP	D
	POP	H
	RET

;---------------- CP/M 3 READ / WRITE entry points --------------------
DSI$READ:
	PUSH	D
	CALL	DSI$SETUNIT
	MVI	A,40H
	STA	DSI$RWCMD
	CALL	DSI$RW
	ORA	A
	JNZ	DSI$RDEXIT
	CALL	DSI$COPYOUT
	XRA	A
DSI$RDEXIT:
	POP	D
	RET

DSI$WRITE:
	PUSH	D
	CALL	DSI$SETUNIT
	CALL	DSI$COPYIN
	MVI	A,80H
	STA	DSI$RWCMD
	CALL	DSI$RW
	POP	D
	RET

;---------------- One 128-byte physical sector ------------------------
DSI$RW:
	CALL	DSI$VALID
	ORA	A
	RNZ
	CALL	DSI$SEEK
	ORA	A
	RNZ

	LHLD	@TRK
	MOV	A,L
	STA	DSI$BUF		;descriptor track
	LDA	@SECT
	INR	A			;CP/M 0..25 -> FDC 1..26
	STA	DSI$BUF+1
	MVI	A,0FBH
	STA	DSI$BUF+2

	MVI	A,10D
	STA	DSI$RETRY

DSI$TRY:
	LXI	H,DSI$BUF
	MOV	A,H
	OUT	FDCHI
	MOV	A,L
	OUT	FDCLO
	LDA	DSI$RWCMD
	OUT	FDCCMD

DSI$IOWAIT:
	IN	FDCSTS
	ANI	0F8H			;IO finish or any high error bit
	JZ	DSI$IOWAIT
	IN	FDCSTS
	STA	DSI$LAST
	ANI	0F0H
	JZ	DSI$OK

	LXI	H,DSI$RETRY
	DCR	M
	JZ	DSI$BAD

; Exact period CBIOS14 retry distinction:
; 20/40/80 errors retry directly; a 10H track error homes and reseeks.
	LDA	DSI$LAST
	ANI	0E0H
	JNZ	DSI$TRY

	CALL	DSI$HOME
	CALL	DSI$SEEK
	ORA	A
	RNZ
	JMP	DSI$TRY

DSI$OK:
	XRA	A
	RET
DSI$BAD:
	MVI	A,1
	RET

;---------------- Validate fixed-format request ------------------------
DSI$VALID:
	LHLD	@TRK
	MOV	A,H
	ORA	A
	JNZ	DSI$BAD
	MOV	A,L
	CPI	77
	JNC	DSI$BAD
	LDA	@SECT
	CPI	26
	JNC	DSI$BAD
	XRA	A
	RET

;---------------- Controller drive selection --------------------------
DSI$SELECT:
	LDA	DSI$UNIT
	ANI	01H
	RRC
	RRC
	RRC
	RRC
	ORI	08H
	OUT	FDCCMD
	RET

DSI$TRKPTR:
	LXI	H,DSI$TRK0
	LDA	DSI$UNIT
	ORA	A
	RZ
	INX	H
	RET

;---------------- Home selected drive ---------------------------------
DSI$HOME:
	CALL	DSI$SELECT
	CALL	DSI$TRKPTR
DSI$HLOOP:
	IN	FDCSTS
	ANI	04H
	JNZ	DSI$HDONE
	STC
	CALL	DSI$STEP
	JMP	DSI$HLOOP
DSI$HDONE:
	MVI	M,0
	XRA	A
	RET

;---------------- Seek selected drive to @TRK -------------------------
DSI$SEEK:
	LHLD	@TRK
	MOV	A,H
	ORA	A
	JNZ	DSI$BAD
	MOV	A,L
	CPI	77
	JNC	DSI$BAD
	STA	DSI$WANT

	CALL	DSI$SELECT
	CALL	DSI$TRKPTR
	MOV	A,M
	CPI	0FFH
	JNZ	DSI$SKLOOP
	CALL	DSI$HOME
	CALL	DSI$TRKPTR

DSI$SKLOOP:
	LDA	DSI$WANT
	CMP	M
	JZ	DSI$SETTLE
	JC	DSI$SKOUT
	ORA	A			;clear carry = step inward
	CALL	DSI$STEP
	JMP	DSI$SKLOOP
DSI$SKOUT:
	STC				;carry set = toward track zero
	CALL	DSI$STEP
	JMP	DSI$SKLOOP

DSI$SETTLE:
; The period CBIOS14 waits 18 ms using a loop calibrated for its IMSAI CPU.
; This build may run on a much faster Z80.  2800H iterations of this 24-T
; loop are about 24.6 ms even at 10 MHz (and longer at lower clocks), so the
; head-settle time remains conservative without depending on CPU speed.
	LXI	B,2800H
DSI$DLY1:
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	DSI$DLY1
	XRA	A
	RET

;---------------- One physical head step ------------------------------
; Carry set = OUT toward track 0; carry clear = IN.
; HL points at selected drive's software track byte.
DSI$STEP:
	PUSH	PSW
DSI$STWAIT:
	IN	FDCSTS
	ANI	02H			;FDC-2 Step Ready
	JZ	DSI$STWAIT
	POP	PSW
	JC	DSI$STEP$OUT
	INR	M
	MVI	A,04H			;direction IN
	JMP	DSI$PULSE
DSI$STEP$OUT:
	DCR	M
	XRA	A			;direction OUT
DSI$PULSE:
	OUT	FDCCMD
	ORI	02H
	OUT	FDCCMD
	ANI	0FDH
	OUT	FDCCMD
	RET

;---------------- 128-byte bounce-buffer copies -----------------------
DSI$COPYIN:
	LHLD	@DMA
	LXI	D,DSI$BUF+3
	MVI	B,128
DSI$CILOOP:
	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	DSI$CILOOP
	RET

DSI$COPYOUT:
	LHLD	@DMA
	XCHG				;DE = CP/M destination
	LXI	H,DSI$BUF+3
	MVI	B,128
DSI$COLOOP:
	MOV	A,M
	STAX	D
	INX	H
	INX	D
	DCR	B
	JNZ	DSI$COLOOP
	RET

	END
