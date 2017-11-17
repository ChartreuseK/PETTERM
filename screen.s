;#######################################################################
; Screen routines
;#######################################################################

;-----------------------------------------------------------------------
; Clear screen
CLRSCR	SUBROUTINE
	; Screen is 40x25 (1000 bytes)
	; We probably should clear the remaining part of the screen
	; on 80 column PETs. Should just be 4 more STA statements
	LDA	#$20		; Fill byte for screen
	LDX	#0		; We want to write 256 times
.loop
	STA	SCRMEM+0,X	; Clear all 1024 bytes in one pass
	STA	SCRMEM+256,X
	STA	SCRMEM+512,X
	STA	SCRMEM+768,X
	STA	SCRMEM+1024,X	; Clear the extra 1024 bytes on 80 col pets
	STA	SCRMEM+1280,X
	STA	SCRMEM+1536,X
	STA	SCRMEM+1792,X
	DEX
	BNE	.loop
	RTS
	
;-----------------------------------------------------------------------
; Scroll the screen by one line
; TODO: Is there a cleaner way to do this fairly fast?
SCROLL	SUBROUTINE
	; Scroll characters upwards
	LDA	#<(SCRMEM-1)
	STA	.first
	LDA	#>(SCRMEM-1)
	STA	.first+1
	
	LDA	#<(SCRMEM+SCRCOL-1)
	STA	.second
	LDA	#>(SCRMEM+SCRCOL-1)
	STA	.second+1
	
	LDY	#SCRROW		; Do 1 screen of rows
.loopb
	LDX	#SCRCOL		; Do 1 row of columns
.loopa
.second EQU	.+1		; Address word of LDA
	LDA	$FFFF,X		; Read from second row
.first	EQU	.+1		; Address word of STA
	STA	$FFFF,X		; Store in first row
	DEX
	BNE	.loopa
	; Add SCRCOL to .first and .second
	CLC
	LDA	#SCRCOL
	ADC	.first
	STA	.first
	LDA	#0
	ADC	.first+1
	STA	.first+1
	
	CLC
	LDA	#SCRCOL
	ADC	.second
	STA	.second
	LDA	#0
	ADC	.second+1
	STA	.second+1
	
	DEY
	BNE	.loopb
	; Clear last row
	LDA	#$20		; Blanking character
	LDX	#SCRCOL
.clrloop
	STA	SCRBTML,X
	DEX
	BNE	.clrloop
	RTS
	
	


;-----------------------------------------------------------------------
; Write a character to the current position
PUTCH	SUBROUTINE
	JSR	SCRCONV		; Convert ASCII to screen representation
	LDY	#0 
	STA	(CURLOC),Y	; Store to current position
	
	LDA	#1		; 16-bit increment
	CLC
	ADC	CURLOC
	STA	CURLOC
	LDA	#0
	ADC	CURLOC+1
	STA	CURLOC+1
	
	INC	COL
	
	LDA	COL
	CMP	#COLMAX
	BCC	.nowrap
	LDA	#0
	STA	COL
	INC	ROW
.nowrap
	; Check if we wrote the character in the bottom right
	; and need to scroll the screen
	LDA	ROW
	CMP	#ROWMAX
	BCC	.done
	DEC	ROW
		;LDA	#<(SCREND)
		;CMP	CURLOC
		;BNE	.done
		;LDA	#>(SCREND)
		;CMP	CURLOC+1
		;BNE	.done
	; Need to scroll
	JSR	SCROLL
	; Move cursor to bottom left
	LDA	#<SCRBTML
	STA	CURLOC
	LDA	#>SCRBTML
	STA	CURLOC+1
.done
	RTS


;-----------------------------------------------------------------------
; Convert ASCII to screen characters
; If this is too slow and we have RAM avail, then use a straight lookup table
; ( Ie TAX; LDA LOOKUP,X; RTS )
SCRCONV	SUBROUTINE
	CMP	#$20
	BCC	.nonprint	; <$20 aren't printable, may have sideeffects
	CMP	#$40		; $20 to $3F don't adjust
	BCC	.done
	CMP	#$60		; $40 to $5F are 'uppercase' letters
	BCC	.upper
	CMP	#$80		; $60 to $7F are 'lowercase' letters
	BCC	.lower
	; > $80 Then just map to arbitrary PETSCII for now
.upper
	SEC
	SBC	#$40
.done
	RTS
.lower
	SEC
	SBC	#$60		; Convert to uppercase letters
	RTS
.nonprint
	LDA	#$A0		; Inverse Space
	RTS
	

; Add sign-extended A to CURLOC	
; If CURLOC+A exceeds screen then don't change
ADDCURLOC	SUBROUTINE
	TAX
	CLC
	ADC	CURLOC
	STA	CURLOC
	TXA
	ORA	#$7F		; Sign extend A
	BMI	.minus
	LDA	#0
.minus				; Sign extended A now in A
	ADC	CURLOC+1	; Add to upper byte
	STA	CURLOC+1
	
	; Check if we fit
	RTS
	TXA			; Restore A
	EOR	#$FF		; Invert
	SEC			; Add 1
	ADC	#0		; (Negate A)
	JSR	CHKBOUNDS
	BCS	ADDCURLOC	; If out of bounds, invert add
	RTS
	

CHKBOUNDS	SUBROUTINE
	; Check if before the screen
	LDA	CURLOC+1
	CMP	#$80		; Start of screen is $8000
	BCC	.fail
	CMP	#>SCREND	; Past end of screen
	BEQ	.testlow	; Test low byte if high is the end
	BCS	.fail		
.pass
	CLC
	RTS
.testlow
	LDA	CURLOC
	CMP	#(<SCREND)+1
	BCC	.pass		
.fail
	SEC
	RTS


; Cursor movement
CURSUP	SUBROUTINE
	LDA	ROW
	BEQ	CURNONE
	DEC	ROW
	LDA	#-(SCRCOL)	; Subtract one row
	JMP	ADDCURLOC
CURSDN
	LDA	ROW
	CMP	#ROWMAX-1
	BEQ	CURNONE
	INC	ROW
	LDA	#(SCRCOL)	; Add one row
	JMP	ADDCURLOC
CURSL
	LDA	COL
	BEQ	CURNONE
	DEC	COL
	LDA	#-1
	JMP	ADDCURLOC
CURSR
	LDA	COL
	CMP	#COLMAX-1
	BEQ	CURNONE
	INC	COL
	LDA	#1
	JMP	ADDCURLOC
CURNONE
	RTS


; X - column
; Y - row
GOTOXY		SUBROUTINE
	STX	CURLOC
	STX	COL
	STY	ROW
	LDA	#$80
	STA	CURLOC+1
	CPY	#0
	BEQ	.done
.rowl
	LDA	CURLOC
	CLC
	ADC	#SCRCOL		; Add one row
	STA	CURLOC
	LDA	CURLOC+1
	ADC	#0
	STA	CURLOC+1
	DEY
	BNE	.rowl
.done
	RTS
