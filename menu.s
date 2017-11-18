; Options menu
;-------------------------------------------------------------------------------


DOMENU	SUBROUTINE
	JSR	CLRSCR
	
	LDX	#0
	
	
	LDA	#<S_BANNER
	LDY	#>S_BANNER
	JSR	PRINTSTR
	
	LDA	#<S_MENU
	LDY	#>S_MENU
	JSR	PRINTSTR

.update
	LDX	#0
	LDY	#18
	JSR	GOTOXY
	
	LDA	#<S_CUR
	LDY	#>S_CUR
	JSR	PRINTSTR
	
	; Print BAUD rate
	LDX	BAUD
	LDA	S_BAUD1,X
	JSR	PUTCH
	LDX	BAUD
	LDA	S_BAUD2,X
	JSR	PUTCH
	LDX	BAUD
	LDA	S_BAUD3,X
	JSR	PUTCH
	LDX	BAUD
	LDA	S_BAUD4,X
	JSR	PUTCH
	
	LDA	#' 
	JSR	PUTCH
	
	; Bits per character
	LDA	#'8
	JSR	PUTCH
	
	; Parity
	LDA	#'N
	JSR	PUTCH
	
	; Stop bit
	LDA	#'1
	JSR	PUTCH
	
	; Mixed/UPPER
	LDA	MODE1
	AND	#MODE1_CASE
	BEQ	.upper
	LDA	#<S_MIXED
	LDY	#>S_MIXED
	JMP	.case
.upper
	LDA	#<S_UPPER
	LDY	#>S_UPPER
.case
	JSR	PRINTSTR
	
	LDA	MODE1
	AND	#MODE1_INV
	BEQ	.noinv
	LDA	#<S_INV
	LDY	#>S_INV
	JMP	.inv
.noinv
	LDA	#<S_NOINV
	LDY	#>S_NOINV
.inv
	JSR	PRINTSTR
	
	
	; Echo / No Echo
	LDA	MODE1
	AND	#MODE1_ECHO
	BEQ	.noecho
	LDA	#<S_ECHO
	LDY	#>S_ECHO
	JMP	.echo
.noecho
	LDA	#<S_NOECHO
	LDY	#>S_NOECHO
.echo
	JSR	PRINTSTR
	; Wait for user input
.keywait
	LDA	KBDNEW
	BEQ	.keywait
	
	LDA	#0
	STA	KBDNEW		; Acknowledge keypress
	
	LDA	KBDBYTE
	CMP	#'1
	BEQ	.bauddec
	CMP	#'2
	BEQ	.baudinc
	CMP	#'3
	BEQ	.tglecho
	CMP	#'4
	BEQ	.tglcase
	CMP	#'5
	BEQ	.tglinv
	CMP	#$0D		; CR
	BEQ	.done
	BNE	.keywait
.baudinc
	LDA	BAUD
	CMP	#BAUD_MAX
	BEQ	.doupdate	; If at max don't increase
	INC	BAUD
	JMP	.update
.bauddec
	LDA	BAUD
	BEQ	.doupdate	; If at min don't decrease
	DEC	BAUD
	JMP	.update		; (BAUD is always < $80)
.tglecho
	LDA	MODE1
	EOR	#MODE1_ECHO
	STA	MODE1
	JMP	.update
.tglcase
	LDA	MODE1
	EOR	#MODE1_CASE
	STA	MODE1
	JMP	.update
.tglinv
	LDA	MODE1
	EOR	#MODE1_INV
	STA	MODE1
	; Fall into .doupdate
.doupdate
	JMP	.update
.done
	RTS
	
	;	 0123456789012345678901234567890123456789
S_BANNER
	DC.B	"PETTERM v0.2.0    HAYDEN KROEPFL - 2017",13,10
	DC.B	"---------------------------------------",13,10,10,0
S_MENU
	DC.B	"[1] DECREASE BAUD RATE",13,10,10
	DC.B	"[2] INCREASE BAUD RATE",13,10,10
	DC.B	"[3] TOGGLE LOCAL ECHO",13,10,10
	DC.B	"[4] TOGGLE UPPERCASE/MIXED CASE",13,10,10
	DC.B	"[5] TOGGLE INVERSE CASE (FOR ORIG ROMS)"
	DC.B	0
S_MENU2
	DC.B	13,10,"[RETURN] START TERMINAL",13,10,0
	
S_CUR
	DC.B	"CURRENT: ",0
	
S_UPPER
	DC.B	" UPPER ",0
S_MIXED
	DC.B	" MIXED ",0
S_ECHO
	DC.B	"ECHO",0
S_NOECHO
S_NOINV	DC.B	"    ",0	; 4 spaces

S_INV	DC.B	"INV ",0

S_BAUD1	DC.B	"   1249"
S_BAUD2	DC.B	"1362486"
S_BAUD3	DC.B	"1000000"
S_BAUD4	DC.B	"0000000"
