
; Poll a single row (58/63 cycles) 
; Assumes KROW has been setup, and SHIFT and CTRL are cleared before the first call
KBDROWPOLL	SUBROUTINE	;6;
	LDY	KROW		;3;
	STY	PIA1_PA		;4; Set scan row
	LDA	PIA1_PB		;4; Read in row
	EOR	#$FF		;2; Invert
	TAX			;2; Save
	AND	SHIFTMASK,Y	;4; Is a modifier pressed?
	ORA	SHIFT		;3; OR into shift if so
	STA	SHIFT		;3;
	TXA			;2;
	AND	CTRLMASK,Y	;4; Is a modifier pressed?
	ORA	CTRL		;3; OR into ctrl if so
	STA	CTRL		;3;
	TXA			;2;
	AND	KEYMASK,Y	;4; Mask out modifier keys
	BEQ	.nokey		;2/3 Do we have a keypress in this row?
	STY	KROWFND		;3; Found keypress in this row
	STA	KBITFND		;3; Saved bitmask
.nokey
	INC	KROW
	RTS			;6;
	; KBITFND and KROWFND will be set to the last key press found
	; if one is found, with CTRL and SHIFT non-zero if modifer pressed

; Setup for start of a keyboard polling by rows (29 cycles)
KBDROWSETUP	SUBROUTINE	;6;
	LDA	#0		;2;
	STA	KROW		;3;
	STA	SHIFT		;3;
	STA	CTRL		;3;
	STA	KROWFND		;3;
	STA 	KBITFND		;3; If KBITFND clear at end of polling then no key pressed
	RTS			;6

; If a key way pressed in the polling convert to a scancode
; Returns pressed key or 0
; 90 cycles worst case
KBDROWCONV	SUBROUTINE	;6;
	LDA	KBITFND		;3;
	TAX			;2
	BEQ	.nokey		;2/3
	BIT	KBITFND		;4;Test bits 6 and 7 of mask
	BMI	.k7		;2/3
	BVS	.k6		;2/3
	LDA	LOG2_TBL,X	;4; Get the highest bit pressed (6 and 7 are clear)
.found:	; We've got the column of our bitpress in A
	STA	KBITFND		;3; Overwrite bitmask with column to save
	LDA	KROWFND		;3; Each row is 8 long, so we need to multiply by 8
	ASL			;2; *2
	ASL			;2; *4
	ASL			;2; *8
				; CLC Not needed, KEYOFF's top 3 bits are 0
	ADC	KBITFND		;3; A now contains our offset into the tables
	TAX			;2; Save into X
	
	LDA	SHIFT		;3;
	BEQ	.notshift	;2/3
	; Shift pressed, read upper table
	LDA	KBDMATRIX_SHIFT,X	;4;
	RTS			;6 (57/59 cycles to here)
.notshift
	LDA	KBDMATRIX,X	;4;
	BMI	.special	;2/3; Don't have control modify special keys
	LDA	CTRL		;3;
	BEQ	.notctrl	;2/3
	; Ctrl pressed, read lower table and bitmask to CTRL keys
	LDA	KBDMATRIX,X	;4;
	AND	#$9F		;2;
.special			; 
	RTS			;6; (71/73 if we didn't take .special)
				;   (61/63 if we took .special)
.notctrl	
	LDA	MODE1		;3; Check mode
	AND	#MODE1_CASE	;2; Check if we need to do case fixing (all upper)
	BEQ	.casefix	;2/3;
	; Normal key
	LDA	KBDMATRIX,X	;4;
	RTS			;6; (77/79 to here)
.casefix
	LDA	KBDMATRIX,X	;4;
	CMP	#$61		;2; a
	BCC	.nocasefix	;2/3; <'a' don't change
	CMP	#$7B		;2; z+1
	BCS	.nocasefix	;2/3; >='z'+1 don't change
	ORA	#$20		;2; Convert lowercase to uppercase
.nocasefix
	RTS			;6; (88/90 max to here)

.k7	LDA	#0		;2; Table is backwards
	BEQ	.found		;3;
.k6	LDA	#1		;2;
	BNE	.found		;3;
.nokey
	RTS			;6; (20 cycles to here)




;----------------------------------------------------------------------
; Poll the keyboard
;~ 500 cycles
KBDPOLL		SUBROUTINE
	LDA	#$FF
	STA	KEY		; Indicate if we haven't found a key
	LDA	#0
	STA	CTRL
	STA	SHIFT
	LDY	#9 		; Keyboard matrix is 10x8 (9->0)

.loop	STY	PIA1_PA		; Set scan row	
	LDA	PIA1_PB		; Read in row
	EOR 	#$FF		; Invert bits so that 1 means pressed
	TAX			; Save scanned value
	AND	SHIFTMASK,Y	; Check if shift pressed for this row
	BEQ	.noshift
	STA	SHIFT		; Non-zero value indicates shift was pressed
.noshift
	TXA			; Restore scancode
	AND	CTRLMASK,Y	; Check if ctrl pressed for this row
	BEQ	.noctrl
	STA	CTRL		; Non-zero value indicates ctrl was pressed
.noctrl TXA			; Restore scancode
	AND	KEYMASK,Y	; Mask out modifiers
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
; Which bits indicate shift keys:
SHIFTMASK DC.B  $00,$00,$00,$00,$00,$00,$00,$00,$21,$00
; Which bits indicate ctrl keys
CTRLMASK DC.B   $00,$00,$00,$00,$00,$00,$00,$00,$08,$01

; Keyboard matrix with shift pressed, needed for consistent shifts	
; Matrix for Graphics keyboards 
KBDMATRIX_SHIFT
SKR0	DC.B	$F4,$F0,$5F, '(, '&, '%, '#, '!
SKR1	DC.B	$08,$F1,$EF, '), '\, '`, '$, '"   ;";
SKR2	DC.B	 '9, '7, '|, 'O, 'U, 'T, 'E, 'Q
SKR3	DC.B	 '/, '8,$EF, 'P, 'I, 'Y, 'R, 'W
SKR4	DC.B	 '6, '4,$EF, 'L, 'J, 'G, 'D, 'A
SKR5	DC.B	 '*, '5,$EF, ':, 'K, 'H, 'F, 'S
SKR6	DC.B	 '3, '1,$0D, ';, 'M, 'B, 'C, 'Z
SKR7	DC.B	 '+, '2,$EF, '?, ',, 'N, 'V, 'X
SKR8	DC.B	 '-, '0,$00, '>,$FF, '}, '~,$00
SKR9	DC.B	 '=, '.,$EF,$03, '<, ' , '{,$FF
    ENDIF



; Custom keys for graphic keyboards
; Shift + []   = {}
; Shift + '    = `
; Shift + @    = ~
; Shift + ^ (up arrow) = |
