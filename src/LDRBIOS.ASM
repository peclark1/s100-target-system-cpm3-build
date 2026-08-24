	TITLE	'IMSAI TARGET CP/M 3 LDRBIOS - FRONT PANEL CONSOLE'
;
; Loader BIOS for CPMLDR on the IMSAI target system.
;
; Purpose:
;   - make CPMLDR sign-on/load-map output follow the same front-panel
;     console convention as the 4K master ROM and normal CP/M 3 BIOS;
;   - read CPM3.SYS from drive A: on the Dual IDE/CF V3 board.
;
; Front-panel selector, physical IMSAI mapping verified 2026-08-23:
;   SW09 SW08 = 00 -> Console I/O V2
;               01 -> Serial I/O V3 channel A
;               10 -> IMSAI MIO SIO
;               11 -> Console I/O V2 fallback
;
; CPMLDR uses only BOOT, CONOUT, HOME, SELDSK, SETTRK, SETSEC,
; SETDMA, READ and SECTRAN from this BIOS.  The other vector entries
; are retained in the standard CP/M 3 order and return immediately.
;
; Disk geometry MUST match drive A: in the normal CP/M 3 BIOS:
;   512-byte physical sectors
;   64 physical sectors/track
;   256 tracks
;   2K allocation blocks
;   1024 directory entries
;   1 reserved track
;   permanent media
;
; CP/M 3's LDRBDOS performs blocking/deblocking because PSH=2/PHM=3.
; Therefore READ transfers one complete 512-byte physical sector.
;
	CSEG
;
;=============================================================================
; Hardware map
;=============================================================================
PANEL$PORT	EQU	0FFH
PANEL$MASK	EQU	0C0H
PANEL$SERIAL	EQU	080H
PANEL$MIO	EQU	040H

CONSOLE$CIO	EQU	0
CONSOLE$SERIAL	EQU	1
CONSOLE$MIO	EQU	2

CIO$STATUS	EQU	00H
CIO$DATA	EQU	01H
CIO$TX$READY	EQU	04H

SER$A$CTRL	EQU	0A1H
SER$A$DATA	EQU	0A3H
SER$TX$READY	EQU	04H

MIO$DATA	EQU	042H
MIO$STATUS	EQU	043H
MIO$TX$READY	EQU	01H

IDE$A		EQU	030H
IDE$B		EQU	031H
IDE$C		EQU	032H
IDE$CTRL	EQU	033H
IDE$DRIVE	EQU	034H

IDE$RD$CFG	EQU	092H
IDE$WR$CFG	EQU	080H
IDE$RESET	EQU	080H
IDE$RD		EQU	040H
IDE$WR		EQU	020H

REG$DATA	EQU	008H
REG$COUNT	EQU	00AH
REG$SECTOR	EQU	00BH
REG$CYL$LO	EQU	00CH
REG$CYL$HI	EQU	00DH
REG$SDH		EQU	00EH
REG$STATUS	EQU	00FH
REG$COMMAND	EQU	00FH
CMD$READ	EQU	020H

; Drive-A DPB expansion of: DPB 512,64,256,2048,1024,1,8000H
DSM0		EQU	0FEFH		; 4079 = maximum 2K block number
ALV$SIZE	EQU	1021		; double-bit ALV: (DSM/4)+2
PHY$SIZE	EQU	512

;=============================================================================
; Standard CP/M 3 BIOS jump vector
;=============================================================================
	JMP	BOOT
	JMP	WBOOT
	JMP	CONST
	JMP	CONIN
	JMP	CONOUT
	JMP	LIST
	JMP	AUXOUT
	JMP	AUXIN
	JMP	HOME
	JMP	SELDSK
	JMP	SETTRK
	JMP	SETSEC
	JMP	SETDMA
	JMP	READ
	JMP	WRITE
	JMP	LISTST
	JMP	SECTRAN
	JMP	CONOST
	JMP	AUXIST
	JMP	AUXOST
	JMP	DEVTBL
	JMP	DEVINI
	JMP	DRVTBL
	JMP	MULTIO
	JMP	FLUSH
	JMP	MOVE
	JMP	TIME
	JMP	SELMEM
	JMP	SETBNK
	JMP	XMOVE
	JMP	0
	JMP	0
	JMP	0

;=============================================================================
; BOOT - called by CPMLDR, and MUST return to CPMLDR
;=============================================================================
BOOT:
	; Decode the same two physical front-panel switch bits as the ROM/BIOS.
	IN	PANEL$PORT
	ANI	PANEL$MASK
	CPI	PANEL$SERIAL
	JZ	BOOT$SERIAL
	CPI	PANEL$MIO
	JZ	BOOT$MIO

	XRA	A			; 00 or reserved C0 -> Console I/O
	STA	CONSOLE$SEL
	JMP	BOOT$CONSOLE$DONE

BOOT$SERIAL:
	MVI	A,CONSOLE$SERIAL
	STA	CONSOLE$SEL
	CALL	SERIAL$INIT$A
	JMP	BOOT$CONSOLE$DONE

BOOT$MIO:
	MVI	A,CONSOLE$MIO
	STA	CONSOLE$SEL

BOOT$CONSOLE$DONE:
	; CPMLDR will immediately begin reading CPM3.SYS from drive A:.
	CALL	IDE$INIT
	RET

; Entries unused by CPMLDR.
WBOOT:
CONST:
CONIN:
LIST:
AUXOUT:
AUXIN:
WRITE:
LISTST:
CONOST:
AUXIST:
AUXOST:
DEVTBL:
DEVINI:
DRVTBL:
MULTIO:
FLUSH:
MOVE:
TIME:
SELMEM:
SETBNK:
XMOVE:
	RET

;=============================================================================
; CONOUT - CPMLDR passes the character in C
;=============================================================================
CONOUT:
	LDA	CONSOLE$SEL
	CPI	CONSOLE$SERIAL
	JZ	SERIAL$OUT
	CPI	CONSOLE$MIO
	JZ	MIO$OUT

CIO$OUT$WAIT:
	IN	CIO$STATUS
	ANI	CIO$TX$READY
	JZ	CIO$OUT$WAIT
	MOV	A,C
	ORA	A
	RZ				; do not send NUL to Console I/O
	OUT	CIO$DATA
	RET

SERIAL$OUT:
	IN	SER$A$CTRL
	ANI	SER$TX$READY
	JZ	SERIAL$OUT
	MOV	A,C
	OUT	SER$A$DATA
	RET

MIO$OUT:
	IN	MIO$STATUS
	ANI	MIO$TX$READY
	JZ	MIO$OUT
	MOV	A,C
	OUT	MIO$DATA
	RET

; Exact physically-proven Serial I/O V3 Channel-A setup used by the
; target 4K master ROM and normal CP/M 3 CHARIO driver: 38,400 8N1.
SERIAL$INIT$A:
	MVI	A,04H
	OUT	SER$A$CTRL
	MVI	A,44H
	OUT	SER$A$CTRL
	MVI	A,03H
	OUT	SER$A$CTRL
	MVI	A,0C1H
	OUT	SER$A$CTRL
	MVI	A,05H
	OUT	SER$A$CTRL
	MVI	A,0EAH
	OUT	SER$A$CTRL
	MVI	A,0BH
	OUT	SER$A$CTRL
	MVI	A,56H
	OUT	SER$A$CTRL
	MVI	A,0CH
	OUT	SER$A$CTRL
	MVI	A,02H
	OUT	SER$A$CTRL
	MVI	A,0DH
	OUT	SER$A$CTRL
	XRA	A
	OUT	SER$A$CTRL
	MVI	A,0EH
	OUT	SER$A$CTRL
	MVI	A,01H
	OUT	SER$A$CTRL
	RET

;=============================================================================
; CPMLDR disk interface - drive A: only
;=============================================================================
HOME:
	LXI	B,0
	JMP	SETTRK

SELDSK:
	; Only drive A: is visible to CPMLDR.
	MOV	A,C
	ORA	A
	JNZ	SELDSK$BAD
	LXI	H,DPH0
	RET
SELDSK$BAD:
	LXI	H,0
	RET

SETTRK:
	MOV	L,C
	MOV	H,B
	SHLD	CUR$TRK
	RET

SETSEC:
	MOV	L,C
	MOV	H,B
	SHLD	CUR$SEC
	RET

SETDMA:
	MOV	L,C
	MOV	H,B
	SHLD	CUR$DMA
	RET

; No skew table.  Return physical sector = logical sector in HL.
SECTRAN:
	MOV	L,C
	MOV	H,B
	RET

; READ one 512-byte physical sector into CUR$DMA.
; Returns A=0 on success, A=1 on error.
READ:
	; LBA = track * 64 + sector.  The current CP/M DPB uses 64
	; physical 512-byte sectors per track and sector origin zero.
	LHLD	CUR$TRK
	MVI	B,6
READ$MUL64:
	DAD	H
	DCR	B
	JNZ	READ$MUL64
	XCHG				; DE = track * 64
	LHLD	CUR$SEC
	DAD	D			; HL = 16-bit LBA
	SHLD	CUR$LBA

	CALL	IDE$WAIT$READY
	JC	READ$ERROR

	; Program LBA28 registers.  This system uses only the low 16 bits.
	MVI	D,0E0H			; master, LBA mode
	MVI	E,REG$SDH
	CALL	IDE$WRITE8

	LHLD	CUR$LBA
	MOV	D,L
	MVI	E,REG$SECTOR
	CALL	IDE$WRITE8
	MOV	D,H
	MVI	E,REG$CYL$LO
	CALL	IDE$WRITE8
	MVI	D,0
	MVI	E,REG$CYL$HI
	CALL	IDE$WRITE8
	MVI	D,1
	MVI	E,REG$COUNT
	CALL	IDE$WRITE8
	MVI	D,CMD$READ
	MVI	E,REG$COMMAND
	CALL	IDE$WRITE8

	CALL	IDE$WAIT$DRQ
	JC	READ$ERROR

	LHLD	CUR$DMA
	MVI	B,0			; 256 words = 512 bytes
READ$WORD:
	MVI	A,REG$DATA
	OUT	IDE$C
	ORI	IDE$RD
	OUT	IDE$C
	IN	IDE$A
	MOV	M,A
	INX	H
	IN	IDE$B
	MOV	M,A
	INX	H
	MVI	A,REG$DATA
	OUT	IDE$C
	DJNZ	READ$WORD

	MVI	E,REG$STATUS
	CALL	IDE$READ8
	MOV	A,D
	ANI	01H
	JNZ	READ$ERROR
	XRA	A
	RET

READ$ERROR:
	MVI	A,1
	RET

;=============================================================================
; Dual IDE/CF V3 low-level support
;=============================================================================
IDE$INIT:
	MVI	A,IDE$RD$CFG
	OUT	IDE$CTRL
	XRA	A			; select CF #0 / drive A:
	OUT	IDE$DRIVE

	MVI	A,IDE$RESET
	OUT	IDE$C
	MVI	B,020H
IDE$RESET$DELAY:
	DCR	B
	JNZ	IDE$RESET$DELAY
	XRA	A
	OUT	IDE$C
	CALL	IDE$SETTLE

	; Establish master/LBA selection once here; READ repeats it as well.
	MVI	D,0E0H
	MVI	E,REG$SDH
	CALL	IDE$WRITE8
	RET

IDE$SETTLE:
	MVI	A,40
IDE$SETTLE$OUTER:
	MVI	B,0
IDE$SETTLE$INNER:
	DJNZ	IDE$SETTLE$INNER
	DCR	A
	JNZ	IDE$SETTLE$OUTER
	RET

; Wait for !BUSY and READY: status bits 7:6 must equal 01b.
; Carry set on timeout.
IDE$WAIT$READY:
	MVI	B,0FFH
	MVI	C,080H
IDE$READY$LOOP:
	MVI	E,REG$STATUS
	CALL	IDE$READ8
	MOV	A,D
	ANI	0C0H
	XRI	040H
	JZ	IDE$WAIT$OK
	DJNZ	IDE$READY$LOOP
	DCR	C
	JNZ	IDE$READY$LOOP
	STC
	RET

; Wait for !BUSY and DRQ: bits 7/3 masked must equal 08H.
IDE$WAIT$DRQ:
	MVI	B,0FFH
	MVI	C,080H
IDE$DRQ$LOOP:
	MVI	E,REG$STATUS
	CALL	IDE$READ8
	MOV	A,D
	ANI	088H
	CPI	008H
	JZ	IDE$WAIT$OK
	DJNZ	IDE$DRQ$LOOP
	DCR	C
	JNZ	IDE$DRQ$LOOP
	STC
	RET

IDE$WAIT$OK:
	ORA	A			; clear carry
	RET

; Read 8-bit ATA register E, return byte in D.
IDE$READ8:
	MOV	A,E
	OUT	IDE$C
	ORI	IDE$RD
	OUT	IDE$C
	IN	IDE$A
	MOV	D,A
	MOV	A,E
	OUT	IDE$C
	XRA	A
	OUT	IDE$C
	RET

; Write D to 8-bit ATA register E.
IDE$WRITE8:
	MVI	A,IDE$WR$CFG
	OUT	IDE$CTRL
	MOV	A,D
	OUT	IDE$A
	MOV	A,E
	OUT	IDE$C
	ORI	IDE$WR
	OUT	IDE$C
	MOV	A,E
	OUT	IDE$C
	XRA	A
	OUT	IDE$C
	MVI	A,IDE$RD$CFG
	OUT	IDE$CTRL
	RET

;=============================================================================
; Drive A: DPH/DPB and CPMLDR-owned buffers
;=============================================================================
; Unlike the normal BIOS, LDRBIOS is not processed by GENCPM.  It therefore
; supplies its own allocation vector, directory/data BCBs, and 512-byte
; physical-sector buffers.  The CP/M 3 BDOS uses DTABCB for 512->128 byte
; blocking/deblocking.
DPH0:
	DW	0			; no sector translation table
	DB	0,0,0,0,0,0,0,0,0	; BDOS scratch area
	DB	0			; media flag
	DW	DPB0
	DW	0			; no checksum vector; permanent media
	DW	ALV
	DW	DIRBCB
	DW	DTABCB
	DW	0FFFFH			; hashing disabled
	DB	0			; hash bank

; Exact expansion of the runtime BIOS drive-A definition:
;     DPB 512,64,256,2048,1024,1,8000H
DPB0:
	DW	0100H			; 256 logical 128-byte records/track
	DB	4,15			; 2K block shift/mask
	DB	0			; extent mask
	DW	0FEFH			; DSM = 4079
	DW	03FFH			; DRM = 1023
	DB	0FFH,0FFH		; 16 directory blocks reserved
	DW	08000H			; permanent-media checksum convention
	DW	1			; one reserved system track
	DB	2,3			; 512-byte physical sectors (PSH/PHM)

; CP/M 3 Buffer Control Block, one each for directory and data.
DTABCB:
	DB	0FFH			; drive owning buffer: none
	DB	0,0,0			; record position / BDOS state
	DB	0			; write flag
	DB	0			; BDOS scratch
	DW	0			; physical track
	DW	0			; physical sector
	DW	DTABUF			; buffer address
	DB	0			; bank
	DW	0			; next BCB

DIRBCB:
	DB	0FFH
	DB	0,0,0
	DB	0
	DB	0
	DW	0
	DW	0
	DW	DIRBUF
	DB	0
	DW	0

DIRBUF:	DS	PHY$SIZE
DTABUF:	DS	PHY$SIZE
ALV:	DS	ALV$SIZE

;=============================================================================
; Loader state
;=============================================================================
CONSOLE$SEL:	DB	0
CUR$TRK:	DW	0
CUR$SEC:	DW	0
CUR$DMA:	DW	080H
CUR$LBA:	DW	0

	END
