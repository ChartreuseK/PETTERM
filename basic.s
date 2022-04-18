;-----------------------------------------------------------------------
; BASIC I/O subroutine
SAVELOAD SUBROUTINE
	LDA	#1
	CMP	LOADB
	BEQ	.bload
	LDA	#1
	CMP	SAVEB
	BEQ	.bjmp
	RTS
.bjmp	JMP	.bsave

.bload
	STA	LOADB	; Clear BASIC load flag

	JSR	CLRSCR

	LDX	#0
	LDY	#0
	JSR	GOTOXY

	LDA	#<L_WAIT
	LDY	#>L_WAIT
	JSR	PRINTSTR

	LDX	#0
	LDY	#2#
	JSR	GOTOXY

	LDX	#<SOB
	STX	PTRLO
	LDY	#>SOB
	STY	PTRHI		

	JSR	XINITRX		; initial XMODEM transmission
	LDA	#0
	STA	XBUFIX		; reset buffer index
	JSR	XRECV		; receive first block of data

.lloop				; Load loop

	LDA	XBUF, XBUFIX
	INC	XBUFIX

	LDX	XBUFIX
	CPX	#$82		; check for end of buffer
	BNE .lcont

	LDX	#0
	STX	XBUFIX		; reset buffer index
	JSR	XRECV		; receive next block of data
.lcont
	;TAX	; Debug print
	;JSR	HEXOUT
	;TXA

	LDY	XBUFIX
	STA	(PTRLO),Y
	INC	XBUFIX

; increment BASIC ptr
.inc16a
	INC	PTRLO
	BNE	.inc16ena
	INC	PTRLO+1
.inc16ena

	CPY	#$82
	BNE	.lloop
	; finished loading the block
	LDX	XFINAL	; check if it is the final block
	CPX	#1
	BNE	.lloop

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

;BLEN SUBROUTINE
;	LDX	#<SOB		; lo byte of basic
;	STX	BASICLO
;	LDX	#>SOB		; hi byte of basic
;	STX	BASICHI
;	SEC				; set carry flag
;	LDA		SOB		; first lo byte
;	SBC	BASICLO		; sub other lo byte
;	STA	BLENLO		; resulting lo byte
;	LDA	SOB+1		; first hi byte
;	SBC	BASICHI		; carry flg complmnt
;	STA	BLENHI		; resulting hi byte
;	RTS

HEXDIG SUBROUTINE
	CMP	#$0A		; alpha digit?
	BCC	.skip		; if no, then skip
	ADC	#$06		; add seven
.skip
	ADC	#$30		; convert to ascii
	JMP	$ffd2		; print it
	; no rts, proceed to HEXOUT

HEXOUT SUBROUTINE
	PHA		; save the byte
	LSR
	LSR		; extract 4...
	LSR		; ...high bits
	LSR
	JSR	HEXDIG
	PLA		; bring byte back
	AND	#$0f	; extract low four
	JMP	HEXDIG	; print ascii

S_PROMPT
	DC.B	"ENTER PROGRAM NAME: ",0

S_WAIT
	DC.B	"SENDING PROGRAM DATA... ",0

S_DONE
	DC.B	"SAVING DONE!",0

L_WAIT
	DC.B	"WAITING FOR PROGRAM DATA... ",0

L_DONE
	DC.B	"LOADING DONE!",0

