
;-----------------------------------------------------------------------
; Poll the keyboard
KBDPOLL	SUBROUTINE
	LDY	#10
	LDX	#0		; Offset into scan matrix
	STX	SHIFT
	STX	CTRL
	STX	KEY		; Reset key and shift
	STY	PIA1_PA
.loop
	DEC	PIA1_PA		; Set scan row
	LDA	PIA1_PB		; Read in row

	LDY	#8		; 8 bits
.bitloop
	PHA
	ORA	#0		; Reset flags based on A
	BMI	.nextbit	; Check if key pressed
	; Found a keypress
	LDA	KBDMATRIX,X	; Read in scan
	BNE	.noshift	
	
	
	; A shift key has been pressed
	LDA	#$80
	STA	SHIFT
	BNE	.nextbit
.noshift
	CMP	#$FF
	BNE	.noctrl
	; Ctrl key has been pressed
	LDA	#$80
	STA	CTRL
	BNE	.nextbit
.noctrl
	CMP	#$F0		; Special keys $F0 to FE
	BCS	.special
	; Otherwise we found our keypress
	STA	KEY
	; Keep going (incase of shift and ctrl keys)
.nextbit
	PLA			; Restore press
	ROL			; Shift left
	INX			; Next char in table
	DEY
	BNE	.bitloop	
	; Next row
.next
	LDA	PIA1_PA		; Check if we're done
	AND	#$0F
	BNE	.loop
	; We're done, apply shift if needed
	LDA	SHIFT
	BPL	.tryctrl	; If not then keep the same
	; Do shift
	LDA	KEY
	BMI	.std		; If high bit set, key can't be shifter
	BEQ	.nokey		; Ignore shift by itself
	AND	#$DF		; Convert lowercase to uppercase
.nokey
	RTS
.tryctrl
	LDA	CTRL
	BPL	.std
	; Do ctrl
	LDA	KEY
	BEQ	.nokey
	AND	#$9F		; Convert lowercase to ctrl keys
	RTS
	
.std
	LDA	MODE1
	AND	#MODE1_CASE
	BEQ	.casefix
.nocasefix
	LDA	KEY
	AND	#$7F		; Remove high bit, if no shift key
	RTS
.casefix
	TXA
	CMP	#$61		; a
	BCC	.nocasefix	
	CMP	#$7B		; z+1
	BCS	.nocasefix	
	ORA	#$20		; Always uppercase letters
	BNE	.nocasefix
	
.special
	TAX
	PLA
	TXA
	RTS
	

	
	
KBDMATRIX 
; This is the matrix for Graphics keyboards only!
; Buisness keyboards use a different matrix >_<
; $00 = shift
; $EF = non-existant
; $FF = REV  (ctrl key)
; $F0 = HOME (MENU key)
; If $80 set then don't apply shift 
KR9	DC.B	 '=, '.,$EF,$83, '<, ' , '[,$FF
KR8	DC.B	 '-, '0,$00, '>,$FF, '], '@,$00
KR7	DC.B	 '+, '2,$EF, '?, ',, 'n, 'v, 'x
KR6	DC.B	 '3, '1,$8D, ';, 'm, 'b, 'c, 'z
KR5	DC.B	 '*, '5,$EF, ':, 'k, 'h, 'f, 's
KR4	DC.B	 '6, '4,$EF, 'l, 'j, 'g, 'd, 'a
KR3	DC.B	 '/, '8,$EF, 'p, 'i, 'y, 'r, 'w
KR2	DC.B	 '9, '7, '^, 'o, 'u, 't, 'e, 'q
KR1	DC.B	$88,$11,$EF, '), '\, '', '$, '"
KR0	DC.B	$9D,$F0,$5F, '(, '&, '%, '#, '!

; $88 (08) is on DEL, (Should be $94/$14)
; $5f (_) is on the <- key?




