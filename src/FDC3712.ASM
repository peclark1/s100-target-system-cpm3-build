;==============================================================================
; FDC3712.ASM -- Altair FDC+ Drive Type 8 disk module for CP/M 3
; Candidate version 0.2, non-banked, 2026-08-23
;
; Controller protocol derived from Mike Douglas's FDC+3712 PROM.ASM and
; BIOS.ASM. The register sequence was independently verified on the target
; IMSAI by 3712TEST.COM and 3712BOOT.COM from altair-fdcplus-software.
;
; Logical drives:
;   FDC0 = FDC+3712 physical drive 0
;   FDC1 = FDC+3712 physical drive 1
;
; Media: IBM 3740 / CP/M standard 8-inch single density
;   77 tracks, 26 x 128-byte sectors, sector IDs 1..26, CP/M skew 6.
;
; This module talks directly to ports 08H/09H. It does not call the original
; iCOM PROM vectors at F400H or the Altair CDBL image at FF00H.
;==============================================================================

	TITLE	'FDC+3712 CP/M 3 DISK HANDLER V0.2'
	MACLIB	CPM3

; FDC+3712 controller commands.
C$READ	 EQU	03H
C$WRITE  EQU	05H
C$RDCRC  EQU	07H
C$SEEK	 EQU	09H
C$CLRERR EQU	0BH
C$RESTOR EQU	0DH
C$SETTRK EQU	11H
C$LDCFG  EQU	15H
C$DRVSEC EQU	21H
C$WRTBUF EQU	31H
C$RDBUF  EQU	40H
C$SHIFT  EQU	41H
C$RESET  EQU	81H

; Controller status bits from the iCOM FD360/FD3712 interface.
; Bits 1-2 are the selected-unit code, NOT error bits. Bit 6 is always 1.
; A failed seek is reported through CRC/media-error or drive-fail status.
S$BUSY	 EQU	01H
S$UN0	 EQU	02H
S$UN1	 EQU	04H
S$CRCERR EQU	08H
S$WRTPRT EQU	10H
S$NOTRDY EQU	20H
S$ALW1	 EQU	40H
S$DDAM	 EQU	80H
S$FATAL  EQU	S$CRCERR+S$NOTRDY
S$SEEKER EQU	S$CRCERR+S$NOTRDY

; Default FDC+ I/O addresses for Drive Type 8.
CMDOUT	 EQU	08H
DATAIN	 EQU	08H
DATAOUT  EQU	09H

UNIT$OFF EQU	25		; hardware-select byte after standard DPH
NUM$TRK  EQU	77
NUM$SEC  EQU	26
SEC$LEN  EQU	128

	EXTRN	@DMA,@TRK,@SECT
	PUBLIC	FDC0,FDC1
	CSEG

;---------------- Extended DPH: FDC+3712 unit 0 ----------------------
	DW	FDC$WRITE
	DW	FDC$READ
	DW	FDC$LOGIN
	DW	FDC$INIT0
	DB	0			; relative drive
	DB	0			; media type
FDC0:	DPH	FDC$XLT,FDC$DPB,,
	DB	0			; XDPH+25 hardware unit

;---------------- Extended DPH: FDC+3712 unit 1 ----------------------
	DW	FDC$WRITE
	DW	FDC$READ
	DW	FDC$LOGIN
	DW	FDC$INIT1
	DB	1			; relative drive
	DB	0			; media type
FDC1:	DPH	FDC$XLT,FDC$DPB,,
	DB	1			; XDPH+25 hardware unit

FDC$DPB:	DPB	128,26,77,1024,64,2
FDC$XLT:	SKEW	26,6,0

;---------------- Driver state ---------------------------------------
FDC$UNIT:	DB	0
FDC$RESETN:	DB	0FFH		; controller reset required
FDC$NEED0:	DB	0FFH		; drive requires restore
FDC$NEED1:	DB	0FFH
FDC$RETRY:	DB	0
FDC$LAST:	DB	0

;---------------- Initialization / login ------------------------------
; Do not touch the floppy hardware during CP/M startup. This keeps IDE/CF
; boot independent of drive power, media insertion, and READY state. The
; first actual C:/D: I/O performs the bounded reset/restore sequence.
FDC$INIT0:
	MVI	A,0FFH
	STA	FDC$RESETN
	STA	FDC$NEED0
	STA	FDC$NEED1
FDC$INIT1:
	XRA	A
	RET

FDC$LOGIN:
	CALL	FDC$SETUNIT
	XRA	A
	RET

; DE points at the current XDPH. Preserve caller's DE and HL.
FDC$SETUNIT:
	PUSH	H
	PUSH	D
	XCHG
	LXI	D,UNIT$OFF
	DAD	D
	MOV	A,M
	ANI	03H
	STA	FDC$UNIT
	POP	D
	POP	H
	RET

;---------------- CP/M 3 READ entry point -----------------------------
FDC$READ:
	PUSH	D
	CALL	FDC$SETUNIT
	CALL	FDC$VALID
	ORA	A
	JNZ	FDC$RDEXIT
	CALL	FDC$PREP
	ORA	A
	JNZ	FDC$RDEXIT

	MVI	A,10D
	STA	FDC$RETRY
FDC$RDTRY:
	CALL	FDC$SELECT$SEEK
	ORA	A
	JNZ	FDC$RDERR

	MVI	A,C$READ
	CALL	FDC$DOCMD
	STA	FDC$LAST
	ANI	S$FATAL
	JZ	FDC$RDXFR

FDC$RDERR:
	CALL	FDC$CLRERR
	LXI	H,FDC$RETRY
	DCR	M
	JNZ	FDC$RDTRY
	CALL	FDC$FAIL
	JMP	FDC$RDEXIT

FDC$RDXFR:
	LHLD	@DMA
	MVI	B,SEC$LEN
FDC$RDLOOP:
	MVI	A,C$RDBUF
	OUT	CMDOUT
	IN	DATAIN
	MOV	M,A
	MVI	A,C$SHIFT
	OUT	CMDOUT
	INX	H
	DCR	B
	JNZ	FDC$RDLOOP
	XRA	A			; leave interface in examine-status mode
	OUT	CMDOUT
	XRA	A
FDC$RDEXIT:
	POP	D
	RET

;---------------- CP/M 3 WRITE entry point ----------------------------
FDC$WRITE:
	PUSH	D
	CALL	FDC$SETUNIT
	CALL	FDC$VALID
	ORA	A
	JNZ	FDC$WREXIT
	CALL	FDC$PREP
	ORA	A
	JNZ	FDC$WREXIT

	MVI	A,10D
	STA	FDC$RETRY
FDC$WSEEK:
	CALL	FDC$SELECT$SEEK
	ORA	A
	JZ	FDC$WLOAD
	CALL	FDC$CLRERR
	LXI	H,FDC$RETRY
	DCR	M
	JNZ	FDC$WSEEK
	CALL	FDC$FAIL
	JMP	FDC$WREXIT

; Load the controller's 128-byte write buffer once. Mike's PROM retries
; WRITE/RDCRC from this buffer without reloading it.
FDC$WLOAD:
	LHLD	@DMA
	MVI	B,SEC$LEN
FDC$WLLOOP:
	MOV	A,M
	OUT	DATAOUT
	MVI	A,C$WRTBUF
	CALL	FDC$OUTCMD
	INX	H
	DCR	B
	JNZ	FDC$WLLOOP

	MVI	A,10D
	STA	FDC$RETRY
FDC$WRTRY:
	MVI	A,C$WRITE
	CALL	FDC$DOCMD
	STA	FDC$LAST
	ANI	S$WRTPRT
	JNZ	FDC$WRPROT
	LDA	FDC$LAST
	ANI	S$FATAL
	JNZ	FDC$WRERR

	MVI	A,C$RDCRC		; always verify the newly written sector
	CALL	FDC$DOCMD
	STA	FDC$LAST
	ANI	S$WRTPRT
	JNZ	FDC$WRPROT
	LDA	FDC$LAST
	ANI	S$FATAL
	JZ	FDC$WROK

FDC$WRERR:
	CALL	FDC$CLRERR
	LXI	H,FDC$RETRY
	DCR	M
	JNZ	FDC$WRTRY
	CALL	FDC$FAIL
	JMP	FDC$WREXIT

FDC$WRPROT:
	MVI	A,2			; CP/M 3 write-protected return code
	JMP	FDC$WREXIT
FDC$WROK:
	XRA	A
FDC$WREXIT:
	POP	D
	RET

;---------------- Controller preparation ------------------------------
; Reset once after BIOS initialization or a terminal I/O error. Restore
; each physical drive on its first access after that reset.
FDC$PREP:
	LDA	FDC$RESETN
	ORA	A
	JZ	FDC$PREP$DRV
	MVI	A,C$RESET
	CALL	FDC$OUTCMD
	XRA	A
	STA	FDC$RESETN
	MVI	A,0FFH
	STA	FDC$NEED0
	STA	FDC$NEED1

FDC$PREP$DRV:
	CALL	FDC$NEEDPTR
	MOV	A,M
	ORA	A
	RZ
	CALL	FDC$SELECT$SECTOR
	MVI	A,C$RESTOR
	CALL	FDC$DOCMD
	STA	FDC$LAST
	ANI	S$SEEKER
	JNZ	FDC$FAIL
	CALL	FDC$NEEDPTR
	MVI	M,0
	XRA	A
	RET

FDC$NEEDPTR:
	LXI	H,FDC$NEED0
	LDA	FDC$UNIT
	ORA	A
	RZ
	INX	H
	RET

;---------------- Select sector and seek track ------------------------
FDC$SELECT$SEEK:
	XRA	A			; FDC+3712 configuration bits = 0
	OUT	DATAOUT
	MVI	A,C$LDCFG
	CALL	FDC$OUTCMD
	CALL	FDC$SELECT$SECTOR
	LHLD	@TRK
	MOV	A,L
	OUT	DATAOUT
	MVI	A,C$SETTRK
	CALL	FDC$OUTCMD
	MVI	A,C$SEEK
	CALL	FDC$DOCMD
	STA	FDC$LAST
	ANI	S$SEEKER
	RZ
	CALL	FDC$CLRERR
	MVI	A,1
	RET

; Drive number occupies bits 7-6; bit 5 is zero; sector occupies bits 4-0.
; CP/M supplies a translated 0..25 sector value, so add one for the FDC.
FDC$SELECT$SECTOR:
	LDA	FDC$UNIT
	ANI	03H
	RRC
	RRC
	MOV	C,A
	LDA	@SECT
	INR	A
	ORA	C
	OUT	DATAOUT
	MVI	A,C$DRVSEC
	JMP	FDC$OUTCMD

;---------------- Bounded command execution ---------------------------
; Mike's PROM waits forever. Four full 16-bit passes retain ample time for a
; restore at target CPU speeds while guaranteeing recovery if hardware is
; absent or misconfigured.
FDC$DOCMD:
	CALL	FDC$OUTCMD
	MVI	D,4
FDC$TMO$OUTER:
	LXI	B,0
FDC$TMO$LOOP:
	IN	DATAIN
	ANI	S$BUSY
	JZ	FDC$CMD$DONE
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	FDC$TMO$LOOP
	DCR	D
	JNZ	FDC$TMO$OUTER
	MVI	A,0FFH
	RET
FDC$CMD$DONE:
	IN	DATAIN
	RET

FDC$CLRERR:
	MVI	A,C$CLRERR
FDC$OUTCMD:
	OUT	CMDOUT
	XRA	A			; return interface to examine-status mode
	OUT	CMDOUT
	RET

;---------------- Validation / terminal error -------------------------
FDC$VALID:
	LHLD	@TRK
	MOV	A,H
	ORA	A
	JNZ	FDC$BAD
	MOV	A,L
	CPI	NUM$TRK
	JNC	FDC$BAD
	LDA	@SECT
	CPI	NUM$SEC
	JNC	FDC$BAD
	XRA	A
	RET
FDC$FAIL:
	MVI	A,0FFH		; reset/restore on the next operation
	STA	FDC$RESETN
FDC$BAD:
	MVI	A,1
	RET

	END
