; Mostly ANSI (TERM=ansi) compatible terminal emulation
; (Not the same as TERM=vt100)
; ANSI codes from:
; https://www.inwap.com/pdp10/ansicode.txt
; Subset used gathered through testing of common linux apps
; and what is easy to support
;-----------------------------------------------------------------------


;-----------------------------------------------------------------------
ANSICH	SUBROUTINE
	LDX	ANSIIN
	BNE	.doesc
	CMP	#$1B		; ESC
	BEQ	.enter
	LDX	ANSIINOS
	BNE	.ignore		; Ignore characters inside OS strings
	JMP	PRINTCH		; Otherwise handle normally
.enter
	INC	ANSIIN		; Indicate we're in an escape sequence
	LDX	#ANSISTKL	
	LDA	#0
	STA	ANSISTKI
.clrstk				; Clear the parameter stack to be ready
	STA	ANSISTK-1,X
	DEX	

	BNE	.clrstk
.ignore
	RTS			; And wait for the next character
.doesc
	; We're in an escape code and got a new character
	CPX	#$2
	BEQ	.csi		; We're still in a CSI sequence
	; Otherwise we're at the first character and unsure
	CMP	#'[		; CSI sequence
	BEQ	.entercsi
	CMP	#']		; OS string sequence
	BEQ	.enteros
	CMP	#'\		; End of OS string
	BEQ	.endos
	; Otherwise we don't support any other sequences of ESC ...
.exit
	LDA	#0
	STA	ANSIIN
	RTS
.entercsi
	INC	ANSIIN
	LDA	#0
	STA	ANSISTKI
	RTS
.enteros
	LDA	#$FF
	STA	ANSIINOS	; We're in an OS string
	RTS
.endos
	INC	ANSIINOS
	RTS
.csi
	; We're in a CSI escape sequence
	CMP	#$40		; $40 <= x
	BCS	.final		; Final character byte >= $40
	CMP	#$30		; $30 <= x < $40
	BCS	.param		; Parameter byte
	CMP	#$20		; $20 <= x < $30
	BCS	.inter		; Intermediary byte (No param must follow)
	; Invalid character, abort sequence
	BCC	.exit
.inter
	RTS			; Ignore intermediary bytes
.param
	LDX	ANSISTKI
	CMP	#$39+1		; $30 <= x <= $39 (0-9)
	BCC	.digit		; 0-9 ascii
	CMP	#';
	BEQ	.sep		; Seperator
	RTS			; Otherwise ignore
.sep
	CPX	#ANSISTKL
	BEQ	.stkfull	; STKI == STKL, don't increment
	INC	ANSISTKI
.stkfull
	RTS
.digit
	SEC
	SBC	#'0		; Convert to digit
	; Multiply previous by 10 and add digit to it
	TAY			;2; 2; Save digit 
	LDA	ANSISTK,X	;4; 6; Read in previous
	ASL			;2; 8; x2
	ASL			;2;10; x4
	CLC			;2;12;
	ADC	ANSISTK,X	;4;16; x5 (prev*4 + prev)
	ASL			;2;18; x10
	STY	ANSISTK,X	;4;22; Save current digit (Can't add A+Y)
	ADC	ANSISTK,X	;4;26; 10*prev + cur
	STA	ANSISTK,X	;4;30;	(loop approach takes 184)
.exit2
	RTS			; Digit has been handled
.final
	; Final byte of a CSI sequence, do the command
	LDY 	#0
	STY	ANSIIN
	CMP	#'p		; p to DEL are private sequences we don't support
	BCS	.exit2
	
	SEC
	SBC	#$40		; Convert final alphabetic char to offset
	ASL			; *2 for word sized jump table
	TAX	
	LDA	CSITBL,X	; Low byte of address
	STA	.tgt+0
	LDA	CSITBL+1,X	; High byte
	STA	.tgt+1

	LDY	ANSISTK+0	; Preload Y with first argument on stack 
	; (Leave LDY as last before JMP so Z flag is set on it)
.tgt 	equ .+1
	JMP	A_NOP		; Address is modified by above
;-----------------------------------------------------------------------


;-----------------------------------------------------------------------
A_NOP	SUBROUTINE
	RTS			; Ignore this CSI, nothing else to do
;-----------------------------------------------------------------------

; Jump table 94 bytes (2*47 possible from $40-$6f)
; vs 19 CMP/BEQ operations = 19*4=76, plus any JMP trampoilines if they're long

CSITBL:
	DC.W A_INSCHR		; @ - Insert characters
	DC.W A_CURUP		; A - Cursor Up
	DC.W A_CURDOWN		; B - Cursor Down
	DC.W A_CURRIGHT		; C - Cursor Right
	DC.W A_CURLEFT		; D - Cursor Left
	DC.W A_CURNEXT		; E - Cursor Next Line
	DC.W A_CURPREV		; F - Cursor Prev. Line
	DC.W A_CURCOL		; G - Cursor abs. to column
	DC.W A_CURABS		; H - Cursor to abs. position
	DC.W A_CURTAB		; I - Go forward tabstop
	DC.W A_ERA		; J - Erase lines
	DC.W A_ERALINE		; K - Erase within line
	DC.W A_INSLINE		; L - Insert lines
	DC.W A_DELLINE		; M - Delete lines
	DC.W A_NOP		; N - Erase in Field (not impl.)
	DC.W A_NOP		; O - Erase in qualified (not impl.)
	DC.W A_DELCHR		; P - Delete characters
	DC.W A_NOP		; Q - Editing extent mode (not impl.)
	DC.W A_NOP		; R - Cursor pos report (invalid host to term)
	DC.W A_SCRUP		; S - Scroll up
	DC.W A_SCRDOWN		; T - Scroll down
	DC.W A_NOP		; U - Next page (not impl.)
	DC.W A_NOP		; V - Prev. page (not impl.)
	DC.W A_NOP		; W - Tab stop control (not impl.)
	DC.W A_NOP		; X - Erase character (erased state) (not impl.)
	DC.W A_NOP		; Y - Cursor vert tab (not impl.)
	DC.W A_NOP		; Z - Cursor back tab (not impl.)
	DC.W A_NOP		; [ - Reserved
	DC.W A_NOP		; | - Reserved
	DC.W A_NOP		; ] - Reserved
	DC.W A_NOP		; ^ - Reserved
	DC.W A_NOP		; _ - Reserved
	DC.W A_HABS		; ` - Horizontal Pos abs. 
	DC.W A_HREL		; a - Horizontal Pos rel. 
	DC.W A_REPEAT		; b - Repeat previous drawn character
	DC.W A_NOP		; c - Device Attr. (term to host)
	DC.W A_VABS		; d - Vertical pos abs.
	DC.W A_VREL		; e - Vertical pos rel.
	DC.W A_CURABS		; f - Vert+Horiz pos abs.
	DC.W A_NOP		; g - Tab stop clear (not impl)
	DC.W A_NOP		; h - Set mode (not impl)
	DC.W A_NOP		; i - Media copy (print) (not impl)
	DC.W A_NOP		; j - Reserved
	DC.W A_NOP		; k - Reserved
	DC.W A_NOP		; l - Reset mode (not impl)
	DC.W A_SGR		; m - Graphic commands (SGR)
	DC.W A_NOP		; n - Device status report (not impl)
	DC.W A_NOP		; o - Define area qualification (not impl)
	; PRIVATE CTRL (vt sequences) from p to DEL 


;----------------------------------------------
; @ - Insert characters
;  (Painfully slow, requires copying characters forward till end of screen)
A_INSCHR	SUBROUTINE
	RTS

;----------------------------------------------
; A - Cursor Up
A_CURUP		SUBROUTINE
	BNE	.noadj
	INY			; Convert 0 to 1
.noadj
	CPY	ROW		; Check if subtraction would underflow
	BCS	.zero		; If up movement >= row, then go to line 0
	; Otherwise subtract Y from ROW
	LDA	ROW
	STY	ROW
	SEC
	SBC	ROW
	STA	ROW
	TAY
	LDX	COL
	JMP	GOTOXY
.zero	LDY	#0
	STY	ROW
	LDX	COL
	JMP	GOTOXY

;----------------------------------------------
; B - Cursor Down
A_CURDOWN	SUBROUTINE
	BNE	.noadj
	INY			; Convert 0 to 1
.noadj
	CPY	#SCRROW		; Check if addition would hit the bottom
	BCS	.end		; If up movement > hight, then go to line SCRROW
	; Otherwise add Y to row (and cap)
	LDA	ROW
	STY	ROW
	CLC
	ADC	ROW
	STA	ROW
	CMP	#SCRROW		; Went past the end anyways, cap off
	BCS	.end
	TAY
	LDX	COL		; Otherwise just position ourselves
	JMP	GOTOXY
.end	LDY	#SCRROW-1
	STY	ROW
	LDX	COL
	JMP	GOTOXY


;----------------------------------------------
; C - Cursor Right
A_CURRIGHT	SUBROUTINE
	BNE	.noadj
	INY			; Convert 0 to 1
.noadj
	CPY	#SCRCOL		; Check if addition would hit the right
	BCS	.end		; If up movement > width, then go to right edge
	; Otherwise add Y to row (and cap)
	LDA	COL
	STY	COL
	CLC
	ADC	COL
	STA	COL
	CMP	#SCRCOL		; Went past the end anyways, cap off
	BCS	.end
	TAX
	LDY	ROW		; Otherwise just position ourselves
	JMP	GOTOXY
.end	LDX	#SCRCOL-1
	STX	COL
	LDY	ROW
	JMP	GOTOXY

;----------------------------------------------
; D - Cursor Left
A_CURLEFT	SUBROUTINE
	BNE	.noadj
	INY			; Convert 0 to 1
.noadj
	CPY	COL		; Check if subtraction would underflow
	BCS	.zero		; If up movement >= col, then go to col 0
	; Otherwise subtract Y from COL
	LDA	COL
	STY	COL
	SEC
	SBC	COL
	STA	COL
	TAX
	LDY	ROW
	JMP	GOTOXY
.zero	LDX	#0
	STX	COL
	LDY	ROW
	JMP	GOTOXY

;----------------------------------------------
; E - Cursor Next Line
A_CURNEXT	SUBROUTINE
	LDX	#0
	STX	COL
	CPY	#0		; Reset flags based on Y
	JMP	A_CURDOWN

;----------------------------------------------
; F - Cursor Prev. Line
A_CURPREV	SUBROUTINE
	LDX	#0
	STX	COL
	CPY	#0		; Reset flags based on Y
	JMP	A_CURUP


;----------------------------------------------
; G - Cursor abs. to column
A_CURCOL	SUBROUTINE
	BEQ	.nofix		; If 0 stay as 0
	DEY			; Absolute is 1 based, convert to 0
.nofix
	CPY	#SCRCOL
	BCC	.nocap		; < COLS
	LDY	#SCRCOL-1	; Cap at right side if > SCRCOL
.nocap
	TYA
	TAX
	LDY	ROW
	JMP	GOTOXY

;----------------------------------------------
; H - Cursor to abs. position
; f - Vert+Horiz pos abs.
A_CURABS	SUBROUTINE
	BEQ	.nofixy		; If 0 stay as 0
	DEY			; Absolute is 1 based, convert to 0
.nofixy
	CPY	#SCRROW
	BCC	.nocapy		; < ROWS
	LDY	#SCRROW-1	; Cap at bottom of screen
.nocapy
	LDX	ANSISTK+1
	BEQ	.nofixx
	DEX
.nofixx
	CPX	#SCRCOL
	BCC	.nocapx		; < COLS
	LDX	#SCRCOL-1	; Cap at right side if > SCRCOL
.nocapx
	JMP	GOTOXY
	
;----------------------------------------------
; I - Go forward tabstop
A_CURTAB	SUBROUTINE
	BNE	.noadj
	INY
.noadj
	; Lazy for now, just do it in a loop since this is an uncommon escape
	; THIS can be slow as each tab will be calling GOTOXY and more
.loop
	TYA
	PHA
	JSR	PRINTCH_TAB	; Call our normal tab function
	PLA
	TAY
	DEY
	BNE	.loop
	RTS

;----------------------------------------------
; J - Erase lines
A_ERA		SUBROUTINE
	BEQ	.forward	;From current to end of screen
	CPY	#1
	BEQ	.backward	; From current to start
	JMP	CLRSCR		; Otherwise clear entire screen
.forward
	LDA	CURLOC
	STA	TMPA
	LDA	CURLOC+1
	STA	TMPA+1
	
	LDA	#$20		; Clear fill character
	LDY	#0
.loopf
	STA	(TMPA),Y
	INC	TMPA
	BNE	.nocarryf
	INC	TMPA+1
.nocarryf
	LDX	TMPA+1
	CPX	#>(SCREND+1)
	BCC	.loopf		; < end of screen
	LDX	TMPA		
	CPX	#<(SCREND+1)	
	BCC	.loopf		; < end of screen
	RTS			; And we're done

.backward
	LDA	CURLOC
	STA	TMPA
	LDA	CURLOC+1
	STA	TMPA+1
	
	LDA	#$20		; Clear fill character
	LDY	#0
.loopb
	STA	(TMPA),Y
	
	LDY	TMPA		; Set z flag
	BNE	.nocarryb
	DEC	TMPA+1
.nocarryb
	DEC	TMPA
	
	LDX	TMPA+1
	CPX	#>(SCRMEM-1)
	BNE	.loopb		; > start of screen
	RTS			; And we're done

;----------------------------------------------
; K - Erase within line
A_ERALINE	SUBROUTINE
	BEQ	.toend		; Erase to end of line
	CPY	#1
	BEQ	.tostart	; Erase to start of line
	; Otherwise erase entire line
	JSR	.tostart
.toend
	LDX	COL
	LDA	#$20		; Clear fill character
	LDY	#0
.loope
	STA	(CURLOC),Y
	INY
	INX
	CPX	#SCRCOL
	BNE	.loope
	RTS
.tostart
	LDA	COL
	PHA			; Save column
	LDX	#0
	LDY	ROW
	JSR	GOTOXY		; Go to start of this line
	PLA			; Restore column
	TAY
	STY	COL		; COL now disjoint from CURLOC
	LDA	#$20		; Clear fill character
.loops
	STA	(CURLOC),Y
	DEY
	BNE	.loops
	STA	(CURLOC),Y	; Don't forget first column
	LDX	COL
	LDY	ROW
	JSR	GOTOXY		; Restore cursor to where we started
	RTS

;----------------------------------------------
; L - Insert lines
A_INSLINE	SUBROUTINE
	RTS
;----------------------------------------------
; M - Delete lines
A_DELLINE	SUBROUTINE
	RTS
;----------------------------------------------
; P - Delete characters (painfully slow, requires copying
;  back characters till the end of the screen...)
A_DELCHR	SUBROUTINE
	RTS


; TODO: These scroll commands are going to be
; painfully slow if not optimized as much as 
; possible
;----------------------------------------------
; S - Scroll up
A_SCRUP		SUBROUTINE
	RTS
;----------------------------------------------
; T - Scroll down
A_SCRDOWN	SUBROUTINE
	RTS




;----------------------------------------------
; ` - Horizontal Pos abs. 
A_HABS		SUBROUTINE
	STY	ANSISTK+1
	LDY	ROW
	STY	ANSISTK+0
	JMP	A_CURABS
	RTS

;----------------------------------------------
; a - Horizontal Pos rel. 
A_HREL		SUBROUTINE
	RTS
;----------------------------------------------
; b - Repeat previous drawn character
A_REPEAT	SUBROUTINE
	BNE	.loop
	INY
.loop
	TYA
	PHA
	LDA	LASTCH
	JSR	PUTCH
	PLA
	TAY
	DEY
	BNE	.loop
	RTS

;----------------------------------------------
; d - Vertical pos abs.
A_VABS		SUBROUTINE
	LDX	COL
	STX	ANSISTK+1
	CPY	#0		; Reset flags
	JMP	A_CURABS

;----------------------------------------------
; e - Vertical pos rel.
A_VREL		SUBROUTINE
	RTS
;----------------------------------------------
;----------------------------------------------
; m - Graphic commands (SGR)
;  The only ones we support is inverse text 7 and reset 0
A_SGR		SUBROUTINE
	LDX	#0
.loop
	LDA	ANSISTK,X
	BEQ	.reset
	CMP	#7		; Reverse video
	BNE	.cont
.reset

	STA	ATTR		; A = 0 for reset or 7 for inverse
.cont
	INX
	CPX	ANSISTKI
	BCC	.loop
	RTS

;----------------------------------------------




