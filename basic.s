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
	LDA	#0
	STA	LOADB	; Clear BASIC load flag
	STA	BTMP1	; Clear BTMP1 byte count

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
	STY	ENDHI		; Init value

.lloop				; Load loop

	LDX	RXBUFR
	CPX	RXBUFW
	BEQ	.lnorx          ; Loop till we get a character in
	
	; Handle new byte
	LDA	RXBUF,X         ; New character
	TAX                     ; Save
	INC	RXBUFR          ; Acknowledge byte by incrementing 
	TXA
	
	;TAX	; Debug print
	;JSR	HEXOUT
	;TXA

; check for the first 2 bytes
	LDX	BTMP1
	CPX	#0
	BNE	.wri1
	STA	ENDLO		; Store end byte lo
.wri1	LDX	BTMP1
	CPX	#1
	BNE	.wri2
	STA	ENDHI		; Store end byte hi
.wri2

	LDY	#0
	STA	(PTRLO),Y

	LDA	BTMP1
	CMP	#$02
	BCS	.inc16a
	INC	BTMP1            ; Inc BTMP1 if less than 2
	JMP	.lloop

; increment BASIC ptr
.inc16a
	INC	PTRLO
	BNE	.inc16ena
	INC	PTRLO+1
.inc16ena

	LDX	PTRHI
	CPX	ENDHI		; cmp step ptr to end hi
	BNE	.lloop		; keep reading
	LDX	PTRLO
	CPX	ENDLO		; cmp step ptr to end lo
	BNE	.lloop		; keep reading

; end of BASIC LOAD code
.ldone
	; Save the current End of Basic Location
	LDX	ENDLO
	STX	EOB
	LDX	ENDHI
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
	BMI	.ltrmkey        ; Key's above $80 are special keys for the terminal
.ltrmkey
	CMP	#$F0            ; $F0 - Menu key
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

	LDA	#<S_PROMPT
	LDY	#>S_PROMPT
	JSR	PRINTSTR

	LDX	#$14
	LDY	#0
	JSR	GOTOXY

.keys
	LDA	KBDNEW
	BEQ	.keys		; Wait for keypresses
	LDA	#$0
	STA	KBDNEW

	LDA	KBDBYTE

	PHA
	JSR	ANSICH		; Local-echoback for now
	PLA

	CMP	#$0D
	BEQ	.scont		; Got filename, continue

	LDX	FNAMEW
	STA	FNAME,X
	INC	FNAMEW
	JMP	.keys

.scont
	JSR	CLRSCR

	LDX	#0
	LDY	#0
	JSR	GOTOXY

	LDA	#<S_WAIT
	LDY	#>S_WAIT
	JSR	PRINTSTR
.dsend				; Send data

	LDX	#0
	STX	BTMP1
	LDX	#<SOB
	STX	PTRLO
	LDY	#>SOB
	STY	PTRHI

; Begin Saving
	LDX	BTMP1
	LDY	#0
	LDA	(PTRLO),Y
	CPX	#0
	BNE	.sloop
; save start
.bsstart
	STA	ENDLO		; Store end lo byte

; send header
	LDA	#0
	JSR	SENDCH
	LDA	#0
	JSR	SENDCH
	LDA	#0
	JSR	SENDCH
	LDA	#$53		; S
	JSR	SENDCH
	LDA	#$41		; A
	JSR	SENDCH
	LDA	#$56		; V
	JSR	SENDCH
	LDA	#$45		; E
	JSR	SENDCH
	LDA	#0
	JSR	SENDCH

.fsend
	LDX	FNAMER
	CPX	FNAMEW
	BEQ	.bsgo           ; Filename has been sent

	; Handle new byte
	LDA	FNAME,X         ; New character
	TAX					; Save
	INC	FNAMER          ; Acknowledge byte by incrementing 
	TXA
	JSR	SENDCH
	JMP	.fsend          ; Filename loop

.bsgo
	LDA	#0
	JSR	SENDCH

; send SOB address
	LDA	#<SOB
	JSR	SENDCH
	LDA	#>SOB
	JSR	SENDCH

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

	JSR	SENDCH		; send BASIC program byte

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
	JSR	SENDCH          ; send the byte
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
	JSR	SENDCH		; send final end hi byte (zero value)

	LDA	#<S_DONE
	LDY	#>S_DONE
	JSR	PRINTSTR

	RTS

;BLEN SUBROUTINE
;	LDX	#<SOB  		; lo byte of basic
;	STX	BASICLO
;	LDX	#>SOB  		; hi byte of basic
;	STX	BASICHI
;	SEC			; set carry flag
;	LDA 	SOB		; first lo byte
;	SBC	BASICLO		; sub other lo byte
;	STA	BLENLO 		; resulting lo byte
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

