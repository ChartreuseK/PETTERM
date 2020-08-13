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
	
	IFCONST	COL80
	STA	SCRMEM+1024,X	; Clear the extra 1024 bytes on 80 col pets
	STA	SCRMEM+1280,X
	STA	SCRMEM+1536,X
	STA	SCRMEM+1792,X
	ENDIF

	DEX
	BNE	.loop
	RTS


; Fast screen scroll code
SCROLL	SUBROUTINE
	LDX	#SCRCOL-1
.loopclr
	LDA	SCRMEM+[ 1*SCRCOL],X	;4;
	STA	SCRMEM+[ 0*SCRCOL],X	;4;
	LDA	SCRMEM+[ 2*SCRCOL],X	;4;
	STA	SCRMEM+[ 1*SCRCOL],X	;4;
	LDA	SCRMEM+[ 3*SCRCOL],X	;4;
	STA	SCRMEM+[ 2*SCRCOL],X	;4;
	LDA	SCRMEM+[ 4*SCRCOL],X	;4;
	STA	SCRMEM+[ 3*SCRCOL],X	;4;
	LDA	SCRMEM+[ 5*SCRCOL],X	;4;
	STA	SCRMEM+[ 4*SCRCOL],X	;4;
	LDA	SCRMEM+[ 6*SCRCOL],X	;4;
	STA	SCRMEM+[ 5*SCRCOL],X	;4;
	LDA	SCRMEM+[ 7*SCRCOL],X	;4;
	STA	SCRMEM+[ 6*SCRCOL],X	;4;
	LDA	SCRMEM+[ 8*SCRCOL],X	;4;
	STA	SCRMEM+[ 7*SCRCOL],X	;4;
	LDA	SCRMEM+[ 9*SCRCOL],X	;4;
	STA	SCRMEM+[ 8*SCRCOL],X	;4;
	LDA	SCRMEM+[10*SCRCOL],X	;4;
	STA	SCRMEM+[ 9*SCRCOL],X	;4;
	LDA	SCRMEM+[11*SCRCOL],X	;4;
	STA	SCRMEM+[10*SCRCOL],X	;4;
	LDA	SCRMEM+[12*SCRCOL],X	;4;
	STA	SCRMEM+[11*SCRCOL],X	;4;
	LDA	SCRMEM+[13*SCRCOL],X	;4;
	STA	SCRMEM+[12*SCRCOL],X	;4;
	LDA	SCRMEM+[14*SCRCOL],X	;4;
	STA	SCRMEM+[13*SCRCOL],X	;4;
	LDA	SCRMEM+[15*SCRCOL],X	;4;
	STA	SCRMEM+[14*SCRCOL],X	;4;
	LDA	SCRMEM+[16*SCRCOL],X	;4;
	STA	SCRMEM+[15*SCRCOL],X	;4;
	LDA	SCRMEM+[17*SCRCOL],X	;4;
	STA	SCRMEM+[16*SCRCOL],X	;4;
	LDA	SCRMEM+[18*SCRCOL],X	;4;
	STA	SCRMEM+[17*SCRCOL],X	;4;
	LDA	SCRMEM+[19*SCRCOL],X	;4;
	STA	SCRMEM+[18*SCRCOL],X	;4;
	LDA	SCRMEM+[20*SCRCOL],X	;4;
	STA	SCRMEM+[19*SCRCOL],X	;4;
	LDA	SCRMEM+[21*SCRCOL],X	;4;
	STA	SCRMEM+[20*SCRCOL],X	;4;
	LDA	SCRMEM+[22*SCRCOL],X	;4;
	STA	SCRMEM+[21*SCRCOL],X	;4;
	LDA	SCRMEM+[23*SCRCOL],X	;4;
	STA	SCRMEM+[22*SCRCOL],X	;4;
	LDA	SCRMEM+[24*SCRCOL],X	;4;
	STA	SCRMEM+[23*SCRCOL],X	;4;	
	LDA	#$20			;2;
	STA	SCRMEM+[24*SCRCOL],X	;4;=198 from first LDA
	DEX				;2;
	BMI	.loopend		;2;
	JMP	.loopclr		;3; = Each loop takes 205, 40col = 8200, 80col = 16400
.loopend
	RTS

;-----------------------------------------------------------------------
; Print a character, no ansi escape hanlding
; A - character
PRINTCH SUBROUTINE
	CMP	#$20
	BCS	.normal
	CMP	#$0A
	BEQ	.nl
	CMP	#$0D
	BEQ	.cr
	CMP	#$09
	BEQ	.tab
	CMP	#$08
	BEQ	.bksp
	; Ignore other ctrl characters for now
	RTS
.bksp	
	LDA	COL
	CMP	#0
	BNE	.bkspnw
	LDA	ROW
	CMP	#0
	BEQ	.bkspnw2
	
	DEC	ROW
	LDA	#COLMAX
	STA	COL
.bkspnw
	DEC	COL
	LDA	#-1
	JSR	ADDCURLOC
.bkspnw2
	RTS
PRINTCH_TAB
.tab	
	; Increment COL to next multiple of 8
	LDA	COL
	AND	#$F8		
	CLC
	ADC	#8
	STA	COL
	CMP	#COLMAX
	BCS	.tabw	
	TAX
	LDY	ROW
	JMP	GOTOXY
.tabw
	LDA	#0
	STA	COL
	JMp	.nl
	
.cr
	LDX	#0
	LDY	ROW
	JMP	GOTOXY
.nl
	INC	ROW
	LDY	ROW
	CPY	#ROWMAX
	BNE	.nlrow
	JSR	SCROLL
	LDY	#ROWMAX-1
.nlrow
	STY	ROW
	LDX	COL
	JMP	GOTOXY
	
.normal
	JMP	PUTCH		; Tail call into PUTCH



;-----------------------------------------------------------------------
; Write a character to the current position
; A - character to write
PUTCH	SUBROUTINE
	STA	LASTCH
	JSR	SCRCONV		; Convert ASCII to screen representation
	LDY	#0 
	STA	(CURLOC),Y	; Store to current position
	; Advance to the next position
	INC	CURLOC
	BNE	.nocarry
	INC	CURLOC+1
.nocarry
	

	INC	COL		; Advance to the right
	LDA	COL		
	CMP	#COLMAX
	BCC	.done		; If < COLMAX then don't wrap back
	LDA	#0		; Reset to column 0
	STA	COL
	INC	ROW		; Advance to the next row
	; Check if we wrote the character in the bottom right
	; and need to scroll the screen
	LDA	ROW
	CMP	#ROWMAX	
	BCC	.done		; ROW < ROWMAX, Still on the screen
	DEC	ROW		; We went past the end, return to the last line
	; Need to scroll the screen
	JSR	SCROLL
	; Move cursor pointer to the bottom left corner
	LDA	#<SCRBTML
	STA	CURLOC
	LDA	#>SCRBTML
	STA	CURLOC+1
.done
	RTS


;-----------------------------------------------------------------------
; Convert ASCII to screen characters
; A - character to convert, returned in A
; If this is too slow and we have RAM avail, then use a straight lookup table
; ( Ie TAX; LDA LOOKUP,X; RTS )
SCRCONV	SUBROUTINE
	CMP	#$40		; <$41 don't adjust
	BCC	.done
	CMP	#$5A		; $41 to $5A are 'uppercase' letters
	BCC	.upper
	CMP	#$61
	BCC	.done		; $5B to 60 don't need case conversion
	CMP	#$7A		; $60 to $7A are 'lowercase' letters
	BCC	.lower
	BPL	.done		; 7B to 7F don't need case conversion
	; >$80, map to arbitrary inverted screen codes
	RTS
.done
	TAX
	LDA	SCRCONVTBL,X
	RTS
.upper
	CLC
	ADC	SC_UPPERMOD
	RTS
.lower
	CLC
	ADC	SC_LOWERMOD	; Convert to uppercase letters
	RTS


SCRCONVTBL
	DC.B	$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0	
	DC.B	$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0	; 0-1F unprintable (A0 is inverse space)
	DC.B	$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
	DC.B	$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F ; 20-3f don't adjust, all correct
	DC.B    $00,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4a,$4b,$4c,$4d,$4e,$4f	; Uppercase ascii -> screen code
        DC.B    $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5a,$1b,$1c,$1d,$1e,$64
        DC.B    $7D,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f ; Backtick becomes _| box drawing char
        DC.B    $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$AC,$5D,$AE,$71,$66	; Fixed pipe, tidla becomes inverse T shaped box drawing
										; DEL becomes half shaded box


;-----------------------------------------------------------------------
; Add sign-extended A to CURLOC	
; A - signed 8-bit displacement
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
	
;-----------------------------------------------------------------------
; Check CURLOC is within the screen. 
; Carry set on fail, clear on pass
CHKBOUNDS	SUBROUTINE
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

;-----------------------------------------------------------------------
; Cursor movement
; Moves cursor one position for each direction.
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


;-----------------------------------------------------------------------
; Set cursor position on the screen
; X - column
; Y - row
GOTOXY		SUBROUTINE
	STX	CURLOC
	STX	COL
	STY	ROW

	LDA	#0		;2; Clear for now till we've done our row
	STA	CURLOC+1	;3;

	;-----------------------------
	IFCONST	COL80
	;-----------------------------
	; ROW is between 0 and 24, we need to multiply it by 80
	; 80 = $40 + $10
	TYA			;2; Row
	ASL			;2; *2
	ASL			;2; *4
	ASL			;2; *8 
	ASL			;2; *16 (Don't have to worry about carry until 16 24*16=384)
	TAX			;2; (Save low byte of *16, may have overflowed!)
	ROL	CURLOC+1	;5;
	LDY	CURLOC+1	;3; (Save high byte of *16, in Y)
	ASL			;2; *32
	ROL	CURLOC+1	;5;
	ASL			;2; *64
	ROL	CURLOC+1	;5;
	; Now handle the low parts
	CLC			;2;
	ADC	CURLOC		;3;
	STA	CURLOC		;3; CURLOC = row*64 + col
	LDA	CURLOC+1	;3;
	ADC	#0		;2;
	STA	CURLOC+1	;3;
	; Now the *16 part
	TXA			;2; Low byte of *16
	CLC			;2;
	ADC	CURLOC		;3;
	STA	CURLOC		;3;
	TYA			;2; High byte of *16
	ADC	CURLOC+1	;3; To high byte (carry will be clear)
	ADC	#>SCRMEM	;2; Add high byte of scrmem to make this a pointer
	STA	CURLOC+1	;3; CURLOC = SCRMEM + COL + ROW*80
	; New code = 75, vs old worst case of 556
	;-----------------------------
	ELSE
	;-----------------------------
	; ROW is between 0 and 24, we need to multiply it by 40
	; 40 = $20 + $8   80 = $40 + $10
	TYA			;2; Row
	ASL			;2; *2
	ASL			;2; *4
	ASL			;2; *8 
	TAX			;2;  Save Row * 8 (Can't have overflowed)
	ASL			;2; *16 (Don't have to worry about carry until 16 24*16=384)
	ROL	CURLOC+1	;5;
	ASL			;2; *32
	ROL	CURLOC+1	;5;
	; Now handle the low part
	CLC			;2;
	ADC	CURLOC		;3;
	STA	CURLOC		;3; CURLOC = row*32 + col
	LDA	CURLOC+1	;3;
	ADC	#0		;2;
	STA	CURLOC+1	;3; TODO: check if previous adc can ever overflow
	; Now the *8 part
	TXA			;2;
	CLC			;2;
	ADC	CURLOC		;3;
	STA	CURLOC		;3;
	LDA	CURLOC+1	;3;
	ADC	#>SCRMEM	;2; Add carry and also high byte of scrmem to make this a pointer
	STA	CURLOC+1	;3;
	; New code = 63, vs old worst case of 556

	;-----------------------------
	ENDIF
	;-----------------------------
	
	RTS

;-----------------------------------------------------------------------
; Print a null terminated string to the screen using PUTCH
; Max 256 bytes long
; A - low byte of addr
; Y - high byte of addr
PRINTSTR SUBROUTINE
	STA	.addr+0
	STY	.addr+1
	
	LDX	#0
.loop:
	TXA
	PHA			; Save X
.addr 	EQU	.+1
	LDA	$FFFF,X		; (Modified address)
	BEQ	.done
	JSR	PRINTCH
	PLA
	TAX			; Restore X
	INX
	BNE	.loop
	RTS
.done
	PLA
	RTS
	
;-----------------------------------------------------------------------
; Set-up uppercase only or mixed case
CASEINIT SUBROUTINE
	LDA	MODE1
	AND	#MODE1_CASE
	BEQ	.upper
	; Mixed case
	LDA	VIA_PCR
	ORA	#$02		; Set flag for 2nd char set
	STA	VIA_PCR
	
	LDA	MODE1
	AND	#MODE1_INV
	BEQ	.noinv
	; Mixed case, inverted
	LDA	#SCUM_MIXEDINV
	LDY	#SCLM_MIXEDINV
	JMP	.store
.noinv
	; Mixed case, non-inverted
	LDA	#SCUM_MIXED
	LDY	#SCLM_MIXED
	JMP	.store
.upper
	; Upper case
	LDA	VIA_PCR
	AND	#$FD		; Clear flag for 2nd char set
	STA	VIA_PCR
	
	LDA	#SCUM_UPPER
	LDY	#SCLM_UPPER
	
.store
	STA	SC_UPPERMOD
	STY	SC_LOWERMOD
	RTS
