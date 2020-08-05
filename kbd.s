


;----------------------------------------------------------------------
; Poll the keyboard
;~ 500 cycles
KBDPOLL		SUBROUTINE
	LDA	#$FF
	STA	KEY		; Indicate if we haven't found a key
	LDA	#0
	STA	CTRL
	STA	SHIFT
	LDY	#9 		; Keyboard matrix is 10x8

.loop	STY	PIA1_PA		; Set scan row	
	LDA	PIA1_PB		; Read in row
	EOR 	#$FF		; Invert bits so that 1 means set
	TAX			; Save A
	AND	SHIFTMASK,Y
	BEQ	.noshift
	STA	SHIFT		; Non-zero value indicates shift was pressed
.noshift
	TXA
	AND	CTRLMASK,Y
	BEQ	.noctrl
	STA	CTRL		; Non-zero value indicates ctrl was pressed
.noctrl TXA
	AND	KEYMASK,Y
	BEQ	.nextrow	; No key was pressend in this row
	; Found a keypress, convert to an index in the table
	STA	KBDTMP
	BIT	KBDTMP		; Test high bits
	BMI	.b7
	BVS	.b6
	TAX	
	LDA	LOG2_TBL,X	; Read in highest set bit
	BPL	.store		; Branch always (Value is between 2 and 7)
.b7	LDA	#0		;   Table is backwards so 7->0
	BEQ	.store		; Branch always
.b6	LDA	#1		;   Table is backwards so 6->1
.store	STA	KEY		; Column in table
	STY	KEYOFF		; Row in table
.nextrow
	DEY			; Next row
	BPL	.loop
; Okay we have our key, if any, and our modifiers
	LDA	KEY
	BPL	.haskey		; Check if we have a key (KEY got changed from initial)
	LDA	#0
	RTS			; No key
.haskey 
	; Convert row+col into an index
	LDA	KEYOFF		; Each row is 8 long, so we need to multiply by 8
	ASL			; x2
	ASL			; x4
	ASL			; x8
				; CLC Not needed, KEYOFF's top 3 bits are 0
	ADC	KEY		; A now contains our offset into the tables
	TAX			; Save into X
	
	LDA	SHIFT
	BEQ	.notshift
	; Shift pressed, read upper table
	LDA	KBDMATRIX_SHIFT,X
	RTS
.notshift
	LDA	KBDMATRIX,X
	BMI	.special	; Don't have control modify special keys
	LDA	CTRL
	BEQ	.notctrl
	; Ctrl pressed, read lower table and bitmask to CTRL keys
	LDA	KBDMATRIX,X
	AND	#$9F		
.special
	RTS
.notctrl	
	LDA	MODE1		; Check mode
	AND	#MODE1_CASE	; Check if we need to do case fixing (all upper)
	BEQ	.casefix
	; Normal key
	LDA	KBDMATRIX,X
	RTS
.casefix
	LDA	KBDMATRIX,X
	CMP	#$61		; a
	BCC	.nocasefix	; <'a' don't change
	CMP	#$7B		; z+1
	BCS	.nocasefix	; >='z'+1 don't change
	ORA	#$20		; Convert lowercase to uppercase
.nocasefix
	RTS



; A log2 table allows quick decoding by giving the index of the highest bit set
; Remembering that modifers need to be checked seperatly
; This table is inverted due to our key tables being backwards
; 7 - LOG_2(x)
LOG2_TBL DC.B -1,7,6,6,5,5,5,5,4,4,4,4,4,4,4,4
         DC.B 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
         DC.B 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
         DC.B 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2

;LOG2_TBL DC.B -1,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3
;         DC.B 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
;         DC.B 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
;         DC.B 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
; To save 192 bytes, we'll can test bits 7 and 6 using BIT
;         DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;         DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;         DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;         DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;         DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7



	
;----------------------------------------------------------------------
; $00 = shift
; $EF = non-existant
; $FF = REV  (ctrl key)
; $F0 = HOME (MENU key)
;
; $F1 = UP
; $F2 = DOWN
; $F3 = RIGHT
; $F4 = LEFT
;
KBDMATRIX 
	IFCONST BUISKBD
; Matrix for Business Keyboards
KR0	DC.B	 '. ,$0E,$F3,'8 ,'- ,'8 ,'5 ,'2  ;$8E = BothShift+2, $1D = CursRight
KR1	DC.B	 '9 ,$EF,'^ ,'7 ,'0 ,'7 ,'4 ,'1
KR2	DC.B	 '5 ,'\ ,'k ,'; ,'h ,'f ,'s ,$1B ; $9B = ESC
KR3	DC.B	 '6 ,'[ ,'l ,$0D,'j ,'g ,'d ,'a
KR4	DC.B	 $08,'p ,'i ,'@ ,'y ,'r ,'w ,$09 ;$C0 = nonshiftable @, $FF= nonshift DEL
KR5	DC.B	 '4 ,'] ,'o ,$F2,'u ,'t ,'e ,'q	 ; $91 = CursUP
KR6	DC.B	 '3 ,$00,$19,'. ,'. ,'b ,'c ,$00 ; $AE-> KP.
KR7	DC.B	 '2 ,$04,$0F,'0 ,$2C,'n ,'v ,'z  ; Repeat->^D, $0F = Z+A+L??
KR8	DC.B	 '1 ,'/ ,$15,$F0,'m ,'  ,'x ,$FF ; $15 - RVS + A + L??, B1 = KP1
KR9	DC.B	 $16,$EF,': ,$03,'9 ,'6 ,'3 ,$08 ; $88 Left Arrow to BS?, ^V=TAB+<-+DEL

; Keymasks to remove modifers from the scan results
; There are backward of the table above! Above goes from 9->0, these are 0->9
KEYMASK DC.B	$FF,$BF,$FF,$FF,$FF,$FF,$BE,$FF,$FE,$BF
; Which bits indicate shift keys
SHIFTMASK DC.B  $00,$00,$00,$00,$00,$00,$41,$00,$00,$00
; Which bits indicate ctrl keys
CTRLMASK DC.B   $00,$00,$00,$00,$00,$00,$00,$00,$01,$00

; Keyboard matrix with shift pressed, needed for consistent shifts	
; Matrix for Business Keyboards
KBDMATRIX_SHIFT
SKR0	DC.B	 '> ,$0E,$F4,'8 ,'= ,'( ,'% ,'"  ;";$8E = BothShift+2, $9D = CursRight
SKR1	DC.B	 '9 ,$EF,'^ ,'7 ,'0 ,$27,'$ ,'!
SKR2	DC.B	 '5 ,'| ,'K ,'+ ,'H ,'F ,'S ,$1B ; $1B = ESC
SKR3	DC.B	 '6 ,'{ ,'L ,$0D,'J ,'G ,'D ,'A
SKR4	DC.B	 $08,'P ,'I ,'@ ,'Y ,'R ,'W ,$09 ;$C0 = nonshiftable @, $FF= nonshift DEL
SKR5	DC.B	 '4 ,'} ,'O ,$F1,'U ,'T ,'E ,'Q	 ; $91 = CursUP
SKR6	DC.B	 '3 ,$00,$19,'. ,'> ,'B ,'C ,$00 ; $AE-> KP.
SKR7	DC.B	 '2 ,$04,$0F,'0 ,'< ,'N ,'V ,'Z  ; Repeat->^D, $0F = Z+A+L??
SKR8	DC.B	 '1 ,'? ,$15,$F0,'M ,'  ,'X ,$FF ; $15 - RVS + A + L??, B1 = KP1
SKR9	DC.B	 $16,$EF,'* ,$83,') ,'& ,'# ,$08 ; $88 Left Arrow to BS?, ^V=TAB+<-+DEL




	ELSE
; Matrix for Graphics keyboards 
KR0	DC.B	$F3,$F0,$5F, '(, '&, '%, '#, '!
KR1	DC.B	$08,$F2,$EF, '), '\, '', '$, '"		;" ; (Appease the syntax highlighter)
KR2	DC.B	 '9, '7, '^, 'o, 'u, 't, 'e, 'q
KR3	DC.B	 '/, '8,$EF, 'p, 'i, 'y, 'r, 'w
KR4	DC.B	 '6, '4,$EF, 'l, 'j, 'g, 'd, 'a
KR5	DC.B	 '*, '5,$EF, ':, 'k, 'h, 'f, 's
KR6	DC.B	 '3, '1,$0D, ';, 'm, 'b, 'c, 'z
KR7	DC.B	 '+, '2,$EF, '?, ',, 'n, 'v, 'x
KR8	DC.B	 '-, '0,$00, '>,$FF, '], '@,$00
KR9	DC.B	 '=, '.,$EF,$03, '<, ' , '[,$FF 	

; $88 (08) is on DEL, (Should be $94/$14)
; $5f (_) is on the <- key?

; Keymasks to remove modifers from the scan results
KEYMASK DC.B	$FF,$DF,$FF,$DF,$DF,$DF,$FF,$DF,$D6,$DE
; Which bits indicate shift keys
SHIFTMASK DC.B  $00,$00,$00,$00,$00,$00,$00,$00,$21,$00
; Which bits indicate ctrl keys
CTRLMASK DC.B   $00,$00,$00,$00,$00,$00,$00,$00,$08,$01

; Keyboard matrix with shift pressed, needed for consistent shifts	
; Matrix for Graphics keyboards 
KBDMATRIX_SHIFT
SKR0	DC.B	$F4,$F0,$5F, '(, '&, '%, '#, '!
SKR1	DC.B	$08,$F1,$EF, '), '\, '', '$, '"   ;";
SKR2	DC.B	 '9, '7, '^, 'O, 'U, 'T, 'E, 'Q
SKR3	DC.B	 '/, '8,$EF, 'P, 'I, 'Y, 'R, 'W
SKR4	DC.B	 '6, '4,$EF, 'L, 'J, 'G, 'D, 'A
SKR5	DC.B	 '*, '5,$EF, ':, 'K, 'H, 'F, 'S
SKR6	DC.B	 '3, '1,$0D, ';, 'M, 'B, 'C, 'Z
SKR7	DC.B	 '+, '2,$EF, '?, ',, 'N, 'V, 'X
SKR8	DC.B	 '-, '0,$00, '>,$FF, '], '@,$00
SKR9	DC.B	 '=, '.,$EF,$03, '<, ' , '[,$FF
	ENDIF



