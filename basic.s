;#######################################################################
; BASIC Program Save/Load Routines
;#######################################################################

;-----------------------------------------------------------------------
; Program I/O subroutine
SAVELOAD SUBROUTINE
	LDA	#1
	CMP	LOADB
	BEQ	.bload
	LDA	#1
	CMP	SAVEB
	BEQ	.bjmp
	RTS
.bjmp
	JMP	.bsave
.bload
	LDA	#0
	STA	LOADB	; Clear BASIC load flag

	JSR	CLRSCR

	LDX	#0
	LDY	#0
	JSR	GOTOXY

	LDA	#<L_PROMPT
	LDY	#>L_PROMPT
	JSR	PRINTSTR

.keys
	LDA	KBDNEW
	BEQ	.keys		; wait for keypress
	LDA	#$0
	STA	KBDNEW		; reset keypress flag

	JSR	CLRSCR

	LDX	#0
	LDY	#0
	JSR	GOTOXY

	LDA	#<L_WAIT
	LDY	#>L_WAIT
	JSR	PRINTSTR

	LDX	#0
	LDY	#2
	JSR	GOTOXY

	JSR	XINITRX		; initial XMODEM transmission
	JSR	XRECV		; receive first block of data

	LDX	#2
	LDA	XBUF,X
	STA	PTRLO
	INX
	LDA	XBUF,X
	STA	PTRHI		
	INX

	STX	XBUFIX		; set buffer index to first program byte after reading memory start loc

.lloop				; Load BASIC loop

	LDX	XBUFIX
	LDA	XBUF,X
	INC	XBUFIX

	;TAX	; Debug print
	;JSR	HEXOUT
	;TXA

	LDY	#0
	STA	(PTRLO),Y

	LDX	XBUFIX
	CPX	#$82		; check for end of buffer
	BNE .inc16a

	; finished loading the block

	LDX	XFINAL	; was it the final block?
	CPX	#1
	BEQ	.ldone

	; it was not the final block

	LDX	#2
	STX	XBUFIX		; reset buffer index
	JSR	XRECV		; receive next block of data

.inc16a
; increment BASIC ptr
	INC	PTRLO
	BNE	.inc16ena
	INC	PTRLO+1
.inc16ena

	LDX	XABRT
	CPX	#1			; check abort flag
	BEQ	.ldone

	JMP .lloop

; end of BASIC LOAD code
.ldone
	; Save the current End of Basic Location
	LDX	PTRLO
	STX	EOB
	LDX	PTRLO+1
	STX	EOB+1
	
	LDA	#<L_DONE
	LDY	#>L_DONE
	JSR	PRINTSTR

; exit to menu
.lmenu
	RTS

.lnorx
	LDA	KBDNEW
	BEQ	.lnokey
	LDA	#$0
	STA	KBDNEW

	LDA	KBDBYTE
	BMI	.ltrmkey	; Key's above $80 are special keys for the terminal
.ltrmkey
	CMP	#$F0		; $F0 - Menu key
	BEQ	.lmenu
	JMP	.lloop

.lnokey
	JMP	.lloop

.bsave
	LDA	#0
	STA	SAVEB		; Clear BASIC save flag
	STA	FNAMEW
	STA	FNAMER
	STA	FNAME

	JSR	CLRSCR

	LDX	#0
	LDY	#0
	JSR	GOTOXY

	LDA	#<S_WAIT
	LDY	#>S_WAIT
	JSR	PRINTSTR

; Begin Saving

	JSR	XINITTX	; Initialize first XMODEM packet.

	LDX	#0
	STX	BTMP1
	LDX	#<SOB
	STX	PTRLO
	LDY	#>SOB
	STY	PTRHI

	LDX	BTMP1
	LDY	#0
	LDA	(PTRLO),Y
	STA	ENDLO		; Store end lo byte

; send SOB address
	LDA	#<SOB
	JSR	XSEND
	LDA	#>SOB
	JSR	XSEND

	LDA	ENDLO

.sloop
	LDX	BTMP1
	LDY	#0
	LDA	(PTRLO),Y
	CPX	#$01
	BNE	.read2
	STA	ENDHI		; store end hi byte

	INX
	STX	BTMP1		; increment BTMP1

	CMP	#0			; check for hi byte of zero
	BNE	.read2		; continue if not zero
	LDA	ENDLO
	CMP	#0			; check for lo byte also zero
	BEQ	.savend		; reached program end

	LDA	ENDHI		; restore value in accumulator

.read2				

	LDX	BTMP1
	CPX	#0
	BNE	.read3
	INX
	STX	BTMP1		; increment BTMP1

.read3

	JSR	XSEND		; send BASIC program byte

; increment BASIC ptr
	INC	PTRLO
	BNE	.inc16enb
	INC	PTRLO+1
.inc16enb

	LDX	PTRHI
	CPX	ENDHI		; cmp step ptr to end hi
	BNE	.sloop		; keep reading
	LDX	PTRLO
	CPX	ENDLO		; cmp step ptr to end lo
	BNE	.sloop		; keep reading

; reached the end of the current BASIC line, check for next pointer
	LDY	#0
	LDA	(PTRLO),Y
.newlo

	PHA
	JSR	XSEND		; send the byte
	PLA

	STA	ENDLO		; save the new ENDLO byte for the next line

	LDX	#1
	STX	BTMP1		; set BTMP1 to read the ENDHI byte next

; increment BASIC ptr
	INC	PTRLO
	BNE	.inc16enc
	INC	PTRLO+1
.inc16enc

	JMP	.sloop

.savend
; end of BASIC SAVE code

	LDA	ENDHI

	JSR	XFINISH		; send final end hi byte (zero value) and finish transfer

	LDA	#<S_DONE
	LDY	#>S_DONE
	JSR	PRINTSTR

	RTS

L_PROMPT
	DC.B	"HIT ANY KEY WHEN SENDER IS READY. ",0

S_WAIT
	DC.B	"SENDING PROGRAM DATA... ",0

S_DONE
	DC.B	"SAVING DONE!",0

L_WAIT
	DC.B	"WAITING FOR PROGRAM DATA... ",0

L_DONE
	DC.B	"LOADING DONE!",0
