
;-----------------------------------------------------------------------
; Poll the keyboard
KBDPOLL	SUBROUTINE
	LDY	#10
	LDX	#0		; Offset into scan matrix
	STX	SHIFT
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
	; Otherwise we found our keypress
	STA	KEY
	; Keep going (incase of shift keys)
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
	BPL	.std		; If not then keep the same
	; Do shift
	LDA	KEY
	BMI	.std		; If high bit set, key can't be shifter
	BEQ	.nokey		; Ignore shift by itself
	ORA	#$80		; For now set the high bit if shift pressed
.nokey
	RTS
.std
	LDA	KEY
	AND	#$7F		; Remove high bit, if no shift key
	RTS
	
	
		
	

	
	
KBDMATRIX 
; This is the matrix for Graphics keyboards only!
; Buisness keyboards use a different matrix >_<
; $00 = shift
; $FF = non-existant
; If $80 set then don't apply shift 
KR9	DC.B	 '=, '.,$FF,$83, '<, ' , '[,$92
KR8	DC.B	 '-, '0,$00, '>,$FF, '], '@,$00
KR7	DC.B	 '+, '2,$FF, '?, ',, 'N, 'V, 'X
KR6	DC.B	 '3, '1,$8D, ';, 'M, 'B, 'C, 'Z
KR5	DC.B	 '*, '5,$FF, ':, 'K, 'H, 'F, 'S
KR4	DC.B	 '6, '4,$FF, 'L, 'J, 'G, 'D, 'A
KR3	DC.B	 '/, '8,$FF, 'P, 'I, 'Y, 'R, 'W
KR2	DC.B	 '9, '7, '^, 'O, 'U, 'T, 'E, 'Q
KR1	DC.B	$88,$11,$FF, '), '\, '', '$, '"
KR0	DC.B	$9D,$13,$5F, '(, '&, '%, '#, '!

; $88 (08) is on DEL, (Should be $94/$14)
; $5f (_) is on the <- key?




