
;-----------------------------------------------------------------------
; Poll the keyboard
KBDPOLL	SUBROUTINE
	LDY	#10
	LDX	#0		; Offset into scan matrix
	STX	SHIFT
	STX	CTRL
	STX	KEY		; Reset key and shift
	STX	KEYOFF
	STY	PIA1_PA
.loop
	DEC	PIA1_PA		; Set scan row
	LDA	PIA1_PB		; Read in row

	LDY	#8		; 8 bits
.bitloop
	PHA
	ORA	#0		; Reset flags based on A
	BMI	.nextbit	; Check if key pressed (Top bit)
	; Found a keypress
	LDA	KBDMATRIX,X	; Read in scan
	BNE	.noshift	; $00 indicates shift key
	
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
	STX	KEYOFF
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
	LDX	KEYOFF
	LDA	KBDMATRIX_SHIFT,X
	;BEQ	.nokey		; Ignore shift by itself	
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
	IFCONST BUISKBD

KR9	DC.B	 $16,$EF,': ,$03,'9 ,'6 ,'3 ,$08 ; $88 Left Arrow to BS?, ^V=TAB+<-+DEL
KR8	DC.B	 '1 ,'/ ,$15,$F0,'m ,'  ,'x ,$FF ; $15 - RVS + A + L??, B1 = KP1
KR7	DC.B	 '2 ,$04,$0F,'0 ,$2C,'n ,'v ,'z  ; Repeat->^D, $0F = Z+A+L??
KR6	DC.B	 '3 ,$00,$19,'. ,'. ,'b ,'c ,$00 ; $AE-> KP.
KR5	DC.B	 '4 ,'] ,'o ,$11,'u ,'t ,'e ,'q	 ; $91 = CursUP
KR4	DC.B	 $08,'p ,'i ,'@ ,'y ,'r ,'w ,$09 ;$C0 = nonshiftable @, $FF= nonshift DEL
KR3	DC.B	 '6 ,'[ ,'l ,$0D,'j ,'g ,'d ,'a
KR2	DC.B	 '5 ,'\ ,'k ,'; ,'h ,'f ,'s ,$1B ; $9B = ESC
KR1	DC.B	 '9 ,$EF,'^ ,'7 ,'0 ,'7 ,'4 ,'1
KR0	DC.B	 '. ,$0E,$1D,'8 ,'- ,'8 ,'5 ,'2  ;$8E = BothShift+2, $9D = CursRight
	ELSE
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

	ENDIF
	
; $88 (08) is on DEL, (Should be $94/$14)
; $5f (_) is on the <- key?


; Keyboard matrix with shift pressed, needed for consistent shifts	
KBDMATRIX_SHIFT
	IFCONST BUISKBD

SKR9	DC.B	 $16,$EF,'* ,$83,') ,'& ,'# ,$08 ; $88 Left Arrow to BS?, ^V=TAB+<-+DEL
SKR8	DC.B	 '1 ,'? ,$15,$F0,'M ,'  ,'X ,$FF ; $15 - RVS + A + L??, B1 = KP1
SKR7	DC.B	 '2 ,$04,$0F,'0 ,'< ,'N ,'V ,'Z  ; Repeat->^D, $0F = Z+A+L??
SKR6	DC.B	 '3 ,$00,$19,'. ,'> ,'B ,'C ,$00 ; $AE-> KP.
SKR5	DC.B	 '4 ,'} ,'O ,$11,'U ,'T ,'E ,'Q	 ; $91 = CursUP
SKR4	DC.B	 $08,'P ,'I ,'@ ,'Y ,'R ,'W ,$09 ;$C0 = nonshiftable @, $FF= nonshift DEL
SKR3	DC.B	 '6 ,'{ ,'L ,$0D,'J ,'G ,'D ,'A
SKR2	DC.B	 '5 ,'| ,'K ,'+ ,'H ,'F ,'S ,$1B ; $1B = ESC
SKR1	DC.B	 '9 ,$EF,'^ ,'7 ,'0 ,$27,'$ ,'!
SKR0	DC.B	 '> ,$0E,$1D,'8 ,'= ,'( ,'% ,'"  ;$8E = BothShift+2, $9D = CursRight

	ELSE
; This is the matrix for Graphics keyboards only!
; Buisness keyboards use a different matrix >_<
; $00 = shift
; $EF = non-existant
; $FF = REV  (ctrl key)
; $F0 = HOME (MENU key)
; If $80 set then don't apply shift 

SKR9	DC.B	 '=, '.,$EF,$03, '<, ' , '[,$FF
SKR8	DC.B	 '-, '0,$00, '>,$FF, '], '@,$00
SKR7	DC.B	 '+, '2,$EF, '?, ',, 'N, 'V, 'X
SKR6	DC.B	 '3, '1,$0D, ';, 'M, 'B, 'C, 'Z
SKR5	DC.B	 '*, '5,$EF, ':, 'K, 'H, 'F, 'S
SKR4	DC.B	 '6, '4,$EF, 'L, 'J, 'G, 'D, 'A
SKR3	DC.B	 '/, '8,$EF, 'P, 'I, 'Y, 'R, 'W
SKR2	DC.B	 '9, '7, '^, 'O, 'U, 'T, 'E, 'Q
SKR1	DC.B	$08,$11,$EF, '), '\, '', '$, '"
SKR0	DC.B	$1D,$F0,$5F, '(, '&, '%, '#, '!

	ENDIF




