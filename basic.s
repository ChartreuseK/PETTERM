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
	STA	LOADB		; Clear BASIC load flag
	STA	BTMP1		; Clear BTMP1 byte count

        JSR     CLRSCR

        LDX     #0
        LDY     #0
        JSR     GOTOXY

        LDA     #<L_WAIT
        LDY     #>L_WAIT
        JSR     PRINTSTR

        LDX     #0
        LDY     #2#
        JSR     GOTOXY

        LDX     #<SOB
        STX     PTRLO
        LDY     #>SOB
        STY     PTRHI		
	STY	ENDHI		; Init value

.lloop				; Load loop

        LDX     RXBUFR
        CPX     RXBUFW
        BEQ     .lnorx          ; Loop till we get a character in

        ; Handle new byte
        LDA     RXBUF,X         ; New character
        TAX                     ; Save
        INC     RXBUFR          ; Acknowledge byte by incrementing 
        TXA

	;TAX			; Debug print
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
        LDY     #0
        STA     (PTRLO),Y	; Store to BASIC mem

        LDA     BTMP1
        CMP	#$02
	BCS	.inc16a		
        INC     BTMP1            ; Inc BTMP1 if less than 2

; increment BASIC ptr
.inc16a
	INC	PTRLO
	BNE	.inc16ena
	INC	PTRLO
.inc16ena

	LDX	PTRHI
	CPX	ENDHI		; cmp step ptr to end hi
	BNE	.lloop		; keep reading
	LDX	PTRLO
	CPX	ENDLO		; cmp step ptr to end lo
	BNE	.lloop		; keep reading

; end of BASIC LOAD code

        LDA     #<L_DONE
        LDY     #>L_DONE
        JSR     PRINTSTR

; exit to menu
.lmenu
        RTS

.lnorx
	LDA	KBDNEW
	BEQ	.lnokey
        LDA     #$0
        STA     KBDNEW

        LDA     KBDBYTE
        BMI     .ltrmkey        ; Key's above $80 are special keys for the terminal
.ltrmkey
        CMP     #$F0            ; $F0 - Menu key
        BEQ     .lmenu
        JMP     .lloop

.lnokey
	JMP	.lloop

.bsave
	LDA	#0
	STA	SAVEB		; Clear BASIC save flag
	STA	FNAMEW
	STA	FNAMER
	STA	FNAME
	STA	BLENLO
	STA	BLENHI

	JSR	BLEN		; Calc BASIC len

; increment BASIC length by 2 bytes
        INC     BLENLO
        BNE     .inc16enc
        INC     BLENLO
.inc16enc
        INC     BLENLO
        BNE     .inc16end
        INC     BLENLO
.inc16end

        JSR     CLRSCR

        LDX     #0
        LDY     #0
        JSR     GOTOXY

        LDA     #<S_PROMPT
        LDY     #>S_PROMPT
        JSR     PRINTSTR

	LDX     #$14
        LDY     #0
        JSR     GOTOXY

.keys	LDA     KBDNEW
        BEQ     .keys		; Wait for keypresses
        LDA     #$0
        STA     KBDNEW

        LDA     KBDBYTE

	PHA
        JSR     ANSICH          ; Local-echoback for now
        PLA

	CMP	#$0D
	BEQ	.scont		; Got filename, continue

        LDX     FNAMEW
        STA     FNAME,X
        INC     FNAMEW
	JMP	.keys

.scont
	JSR	CLRSCR
.fsend	
        LDX     FNAMER
        CPX     FNAMEW
        BEQ     .dsend		; Filename has been sent

        ; Handle new byte
        LDA     FNAME,X         ; New character
        TAX                     ; Save
        INC     FNAMER          ; Acknowledge byte by incrementing 
        TXA

	;JSR	SENDCH
	JMP	.fsend		; Filename loop

.dsend				; Send data

	LDX	#0
	STX	BTMP1
	LDX	#<SOB
	STX	PTRLO
	LDY	#>SOB
	STY	PTRHI
.sloop				; Save loop
	LDX	BTMP1
	LDY	#0
	LDA	(PTRLO),Y
	CPX	#0
	BNE	.read1
; save start
.bsstart
	STA	ENDLO		; Store end lo byte

; send header
	LDA	#0
	JSR	SENDCH
        LDA     #0
        JSR     SENDCH
        LDA     #0
        JSR     SENDCH
	LDA	#$53		; S
	JSR	SENDCH
	LDA	#$41		; A
        JSR     SENDCH
	LDA	#$56		; V
        JSR     SENDCH
	LDA	#$45		; E
        JSR     SENDCH

; send length
	LDA	BLENLO		; BASIC len lo byte
        JSR     SENDCH
	LDA	BLENHI		; BASIC len hi byte
        JSR     SENDCH

; send SOB address
        LDA     #<SOB
        JSR	SENDCH
        LDA     #>SOB
        JSR	SENDCH

	LDA	ENDLO

	LDX	BTMP1
.read1	CPX	#$01
	BNE	.read2
	STA	ENDHI		; store end hi byte
.read2				; read BASIC program
	INX
	STX	BTMP1
	JSR	SENDCH		; send BASIC program byte

; increment BASIC ptr
	INC	PTRLO
	BNE	.inc16enb
	INC	PTRLO
.inc16enb

	LDX	PTRHI
	CPX	ENDHI		; cmp step ptr to end hi
	BNE	.sloop		; keep reading
	LDX	PTRLO
	CPX	ENDLO		; cmp step ptr to end lo
	BNE	.sloop		; keep reading
; end of BASIC SAVE code

        LDA     #<S_DONE
        LDY     #>S_DONE
        JSR     PRINTSTR

	RTS

BLEN SUBROUTINE
	LDX	#<SOB  		; lo byte of basic
	STX	BASICLO
	LDX	#>SOB  		; hi byte of basic
	STX	BASICHI
	SEC			; set carry flag
	LDA 	SOB		; first lo byte
	SBC	BASICLO		; sub other lo byte
	STA	BLENLO 		; resulting lo byte
	LDA	SOB+1		; first hi byte
	SBC	BASICHI		; carry flg complmnt
	STA	BLENHI		; resulting hi byte
	RTS

HEXDIG SUBROUTINE
	CMP	#$0A		; alpha digit?
	BCC	.skip		; if no, then skip
	ADC	#$06		; add seven
.skip	ADC	#$30		; convert to ascii
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
	DC.B    "ENTER PROGRAM NAME: ",0

S_DONE
	DC.B	"SAVING DONE!",0

L_WAIT
        DC.B    "WAITING FOR PROGRAM DATA... ",0

L_DONE
	DC.B	"LOADING DONE!",0

