	TITLE	'LDRPATCH - PATCH CP/M 3 LOADER TO USE ROM CONOUT'
;
; LDRPATCH.COM
;
; Runs under the target non-banked CP/M 3 system and patches the existing
; CPMLDR image in the reserved area of IDE/CF drive A: without rewriting the
; whole CF image.
;
; The 4K ROM loads raw CF LBA 1 at 0100H.  The known-good CPMLDR loader BIOS
; has CONOUT at 0B78H, therefore the routine begins at raw LBA 6 offset 078H.
;
; Original CONOUT bytes:
;   CD 84 0B 28 FB 79 FE 00 C8 D3 01 C9
;
; Patched first four bytes:
;   79 C3 06 F0       MOV A,C / JMP F006H
;
; This program deliberately uses the already-running CP/M 3 BIOS for the raw
; sector read/write.  HIDE3 maps track*64+sector directly to IDE LBA, so BIOS
; track 0, sector 6 is raw LBA 6.  It refuses to write unless the complete
; expected 12-byte CONOUT signature is present.
;
; For safety, run this utility with A: as the current drive.  It also verifies
; that the target ROM has a JP opcode at the fixed F006H public CONOUT entry.
;

BDOS		EQU	0005H
WBOOTV		EQU	0001H
CURDSK		EQU	25
CONIN		EQU	1
PSTRING		EQU	9

ROMCON		EQU	0F006H
TARGETSEC	EQU	0006H
PATCHOFF	EQU	0078H
SIGLEN		EQU	12
SECSIZE		EQU	512

	CSEG

START:
	LXI	SP,STACKTOP
	LXI	D,MSGBANNER
	CALL	PRINT

	; Require A: to be the current CP/M drive.  This avoids changing the
	; BIOS drive selection behind BDOS's back.
	MVI	C,CURDSK
	CALL	BDOS
	ORA	A
	JZ	DRIVEOK
	LXI	D,MSGDRIVE
	CALL	PRINT
	JMP	0000H

DRIVEOK:
	; The current target ROM publishes CONOUT at F006H as a JP entry.
	LDA	ROMCON
	CPI	0C3H
	JZ	ROMOK
	LXI	D,MSGROM
	CALL	PRINT
	JMP	0000H

ROMOK:
	CALL	INITBIOS
	CALL	READMAIN
	ORA	A
	JZ	READOK
	LXI	D,MSGREAD
	CALL	PRINT
	JMP	0000H

READOK:
	; First recognize an already-patched loader.
	LXI	H,BUFFER+PATCHOFF
	LXI	D,PATCHEDSIG
	MVI	B,SIGLEN
	CALL	CMPSIG
	JZ	ALREADY

	; Otherwise require an exact match to the known-good original routine.
	LXI	H,BUFFER+PATCHOFF
	LXI	D,ORIGSIG
	MVI	B,SIGLEN
	CALL	CMPSIG
	JZ	SIGOK

	LXI	D,MSGSIG
	CALL	PRINT
	JMP	0000H

ALREADY:
	LXI	D,MSGALREADY
	CALL	PRINT
	JMP	0000H

SIGOK:
	LXI	D,MSGPROMPT
	CALL	PRINT
	MVI	C,CONIN
	CALL	BDOS
	ANI	05FH
	CPI	'Y'
	JZ	DOPATCH
	LXI	D,MSGCANCEL
	CALL	PRINT
	JMP	0000H

DOPATCH:
	LXI	D,MSGCRLF
	CALL	PRINT

	; Replace only the first four bytes of the existing CONOUT routine.
	LXI	H,BUFFER+PATCHOFF
	MVI	M,079H		; MOV A,C
	INX	H
	MVI	M,0C3H		; JMP
	INX	H
	MVI	M,006H		; F006H low byte
	INX	H
	MVI	M,0F0H		; F006H high byte

	CALL	WRITEMAIN
	ORA	A
	JZ	WRITEOK
	LXI	D,MSGWRITE
	CALL	PRINT
	JMP	0000H

WRITEOK:
	; Read the complete sector back into a second buffer and compare all
	; 512 bytes against exactly what we intended to write.
	CALL	READVERIFY
	ORA	A
	JZ	VERIFYREADOK
	LXI	D,MSGVRD
	CALL	PRINT
	JMP	0000H

VERIFYREADOK:
	LXI	H,BUFFER
	LXI	D,VERIFYBUF
	LXI	B,SECSIZE
	CALL	CMPBLOCK
	JZ	SUCCESS
	LXI	D,MSGVERIFY
	CALL	PRINT
	JMP	0000H

SUCCESS:
	LXI	D,MSGSUCCESS
	CALL	PRINT
	JMP	0000H

;-----------------------------------------------------------------------------
; Discover the resident CP/M 3 BIOS jump table from page zero.
;
; 0001H contains the target of JMP WBOOT, which is BIOS base + 3.  The
; standard CP/M 3 BIOS entry ordering is preserved by BIOSKRNL.ASM.
; These local JMP stubs let ordinary CALL instructions invoke the resident
; BIOS without knowing where GENCPM placed it.
;-----------------------------------------------------------------------------
INITBIOS:
	LHLD	WBOOTV
	LXI	D,001BH		; SETTRK: base+1EH = WBOOT+1BH
	DAD	D
	SHLD	VSETTRK+1

	LHLD	WBOOTV
	LXI	D,001EH		; SETSEC: base+21H = WBOOT+1EH
	DAD	D
	SHLD	VSETSEC+1

	LHLD	WBOOTV
	LXI	D,0021H		; SETDMA: base+24H = WBOOT+21H
	DAD	D
	SHLD	VSETDMA+1

	LHLD	WBOOTV
	LXI	D,0024H		; READ: base+27H = WBOOT+24H
	DAD	D
	SHLD	VREAD+1

	LHLD	WBOOTV
	LXI	D,0027H		; WRITE: base+2AH = WBOOT+27H
	DAD	D
	SHLD	VWRITE+1

	LHLD	WBOOTV
	LXI	D,0042H		; MULTIO: base+45H = WBOOT+42H
	DAD	D
	SHLD	VMULTIO+1
	RET

;-----------------------------------------------------------------------------
; Prepare the raw disk address.  The target HIDE3 driver computes IDE LBA as
; track*64 + sector, making track 0 / sector 6 exactly raw LBA 6.
;-----------------------------------------------------------------------------
PREPIO:
	MVI	A,1
	CALL	VMULTIO
	LXI	B,0000H
	CALL	VSETTRK
	LXI	B,TARGETSEC
	CALL	VSETSEC
	RET

READMAIN:
	CALL	PREPIO
	LXI	B,BUFFER
	CALL	VSETDMA
	CALL	VREAD
	RET

WRITEMAIN:
	CALL	PREPIO
	LXI	B,BUFFER
	CALL	VSETDMA
	MVI	C,0		; normal BIOS write
	CALL	VWRITE
	RET

READVERIFY:
	CALL	PREPIO
	LXI	B,VERIFYBUF
	CALL	VSETDMA
	CALL	VREAD
	RET

;-----------------------------------------------------------------------------
; Compare B bytes at HL and DE.  Return Z only if every byte matches.
;-----------------------------------------------------------------------------
CMPSIG:
	LDAX	D
	CMP	M
	RNZ
	INX	D
	INX	H
	DCR	B
	JNZ	CMPSIG
	XRA	A
	RET

;-----------------------------------------------------------------------------
; Compare BC bytes at HL and DE.  Return Z only if the complete blocks match.
;-----------------------------------------------------------------------------
CMPBLOCK:
	LDAX	D
	CMP	M
	RNZ
	INX	D
	INX	H
	DCX	B
	MOV	A,B
	ORA	C
	JNZ	CMPBLOCK
	XRA	A
	RET

PRINT:
	MVI	C,PSTRING
	CALL	BDOS
	RET

; Resident BIOS trampolines.  INITBIOS patches only their 16-bit JMP targets.
VSETTRK:	JMP	0000H
VSETSEC:	JMP	0000H
VSETDMA:	JMP	0000H
VREAD:		JMP	0000H
VWRITE:		JMP	0000H
VMULTIO:	JMP	0000H

ORIGSIG:
	DB	0CDH,084H,00BH,028H,0FBH,079H,0FEH,000H,0C8H,0D3H,001H,0C9H
PATCHEDSIG:
	DB	079H,0C3H,006H,0F0H,0FBH,079H,0FEH,000H,0C8H,0D3H,001H,0C9H

MSGBANNER:
	DB	13,10,'LDRPATCH - CP/M 3 loader ROM-CONOUT patch',13,10
	DB	'Checks raw A: LBA 6 and changes only four bytes.',13,10,'$'
MSGDRIVE:
	DB	13,10,'Refusing to run: make A: the current drive first.',13,10
	DB	'Use A: then run LDRPATCH again.',13,10,'$'
MSGROM:
	DB	13,10,'Refusing to run: expected ROM CONOUT entry not found at F006H.',13,10,'$'
MSGREAD:
	DB	13,10,'ERROR: BIOS could not read raw A: LBA 6. Nothing changed.',13,10,'$'
MSGSIG:
	DB	13,10,'Refusing to patch: CPMLDR CONOUT signature does not match.',13,10
	DB	'Nothing was written.',13,10,'$'
MSGALREADY:
	DB	13,10,'CPMLDR is already patched to use ROM CONOUT at F006H.',13,10,'$'
MSGPROMPT:
	DB	13,10,'Known-good original CPMLDR CONOUT found.',13,10
	DB	'Patch it to MOV A,C / JMP F006H? (Y/N) $'
MSGCANCEL:
	DB	13,10,'Cancelled. Nothing changed.',13,10,'$'
MSGWRITE:
	DB	13,10,'ERROR: BIOS write of raw A: LBA 6 failed.',13,10,'$'
MSGVRD:
	DB	13,10,'ERROR: patch was written, but verification read failed.',13,10
	DB	'Cold reset and inspect the loader before further writes.',13,10,'$'
MSGVERIFY:
	DB	13,10,'ERROR: sector read-back did not match the data written.',13,10
	DB	'Cold reset and inspect the loader before further writes.',13,10,'$'
MSGSUCCESS:
	DB	13,10,'SUCCESS: CPMLDR CONOUT patched and full sector verified.',13,10
	DB	'Cold RESET the IMSAI now to test loader console routing.',13,10,'$'
MSGCRLF:
	DB	13,10,'$'

	DS	64
STACKTOP	EQU	$

BUFFER:		DS	SECSIZE
VERIFYBUF:	DS	SECSIZE

	END	START
