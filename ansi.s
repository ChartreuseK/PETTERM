;-----------------------------------------------------------------------
; Parse character and handle it
; Ch in A
PARSECH	SUBROUTINE
	CMP	#$1B
	BEQ	DOESC
	JMP	PRINTCH		; Handle normal characters
	
; ANSI Escape code handling
DOESC	SUBROUTINE	
	JSR	GETCH		; Read next character
	CMP	#'[		
	BEQ	.csi		; Handle control sequence
	RTS			; Otherwise ignore sequence
.csi	; Esc [
	LDA	#0
	LDX	#PARSTKL
.clrstk
	STA	PARSTK-1,X	; Clear parameter stack
	DEX
	BNE	.clrstk		; X is left at 0 for the stk pointer
.csiloop
	JSR	GETCH		; Next char
	CMP	#$40		; $40 <= x
	BCS	.final		; Final character byte
	CMP	#$30		; $30 <= x < $40
	BCS	.param		; Parameter byte
	CMP	#$20		; $20 <= x < $30
	BCS	.inter		; Intermediary byte (No param must follow)
	; Invalid CSI sequence, abort
	RTS
.inter
	; Ignore intermediate bytes for now
	JMP	.csiloop
.param
	CMP	#':		; $30 <= x <= $39 (0-9)
	BCC	.digit		; 0-9 ascii
	CMP	#';
	BEQ	.sep		; Seperator
	; Otherwise ignore
	BNE	.csiloop
.sep
	INX			; Increment stack
	CPX	#PARSTKL
	BCC	.csiloop
	DEX			; Don't overflow, overwrite last
	JMP	.csiloop
.digit
	SEC
	SBC	#'0		; Convert to digit
	; Multiply previous by 10 and add digit to it
	TAY			;2; 2; Save digit 
	LDA	PARSTK,X	;4; 6; Read in previous
	ASL			;2; 8; x2
	ASL			;2;10; x4
	CLC			;2;12;
	ADC	PARSTK,X	;4;16; x5 (prev*4 + prev)
	ASL			;2;18; x10
	STY	PARSTK,X	;4;22; Save current digit (Can't add A+Y)
	ADC	PARSTK,X	;4;26; 10*prev + cur
	STA	PARSTK,X	;4;30;	(loop approach takes 184)
	JMP	.csiloop	; Keep in CSI state
.final	; Final byte of CSI sequence. Do it!
	LDY	PARSTK+0	; Preload first stack arg into Y
	CMP	#'A
	BEQ	.cup
	CMP	#'B
	BEQ	.cdn
	CMP	#'C
	BEQ	.cfw
	CMP	#'D
	BEQ	.cbk
	CMP	#'H
	BEQ	.cpos		; Position the cursor to X;Y
	CMP	#'J
	BEQ	.eras		; Erase display
	; Add more here as needed
	; Otherwise ignore sequence
	RTS
.cup
	CPY	#0		; If zero
	BNE	.cupl
	INY			; Make 1 instead
.cupl
	JSR	CURSUP
	DEY
	BNE	.cupl
	RTS
.cdn
	CPY	#0		; If zero
	BNE	.cdnl
	INY			; Make 1 instead
.cdnl
	JSR	CURSDN
	DEY
	BNE	.cdnl
	RTS
.cfw
	CPY	#0		; If zero
	BNE	.cfwl
	INY			; Make 1 instead
.cfwl
	JSR	CURSR
	DEY
	BNE	.cfwl
	RTS
.cbk
	CPY	#0		; If zero
	BNE	.cbkl
	INY			; Make 1 instead
.cbkl
	JSR	CURSL
	DEY
	BNE	.cbkl
	RTS


.cpos
	LDX	PARSTK+1
	BEQ	.cposnx		; Convert from 1 based to 0 based
	DEX
.cposnx
	LDY	PARSTK+0
	BEQ	.cposny		; Convert from 1 based to 0 based
	DEY
.cposny
	JMP	GOTOXY

.eras	; Erase part or all of the screen
	CPY	#0
	BEQ	.erasf
	CPY	#1
	BEQ	.erasb
	; Otherwise clear all
	JMP	CLRSCR		; Tail call
.erasb
	; Erase to start of screen
	LDA	CURLOC		; Save current CURLOC into TMPA
	STA	TMPA
	LDA	CURLOC+1
	STA	TMPA+1
	
	LDA	#0
	STA	CURLOC
	STA	ROW		; Reset CURLOC and ROW/COL to start of screen
	STA	COL
	LDA	#$80
	STA	CURLOC+1
.erasbl
	LDA	#$20
	JSR	PUTCH		; Lazy and slow way to clear from start to here
	LDA	CURLOC+1
	CMP	TMPA+1
	BNE	.erasbl
	LDA	CURLOC
	CMP	TMPA
	BNE	.erasbl
	RTS
	
.erasf
	; Erase to end of screen
	LDA	CURLOC
	STA	TMPA
	LDA	CURLOC+1
	STA	TMPA+1
	LDA	COL		; Save ROW and COL
	PHA
	LDA	ROW
	PHA
.erasfl
	LDA	#$20
	JSR	PUTCH		; Lazy and slow way to clear to end
	LDA	CURLOC+1
	CMP	#>(SCREND-1)
	BNE	.erasfl
	LDA	CURLOC
	CMP	#<(SCREND-1)
	BNE	.erasfl
	; We need to write the last location
	LDA	#$20
	STA	SCREND
	
	PLA			; Restore ROw and COL
	STA	ROW
	PLA	
	STA	COL
	
	LDA	TMPA		; Restore CURLOC
	STA	CURLOC
	LDA	TMPA+1
	STA	CURLOC+1
	RTS
