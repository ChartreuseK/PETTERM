



; Poll the keyboard
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
	STA	SHIFT
.noshift
	TXA
	AND	CTRLMASK,Y
	BEQ	.noctrl
	STA	CTRL
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
	BPL	.store		; Branch always (Value is between 0 and 5)
.b7	LDA	#0	; Table is backwards so 7->0
	BEQ	.store		; Branch always
.b6	LDA	#1	; Table is backwards so 6->1
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
	; Offset is backwards 9->0 8->1 etc., so convert it
	LDA	#9
	SEC
	SBC	KEYOFF		; Now in the right direction...	
	; Each row is 8 long, so we need to multiply by 8
	ASL			; x2
	ASL			; x4
	ASL			; x8
	CLC			; (Not 100% needed, KEYOFF's top 3 bits are 0)
	ADC	KEY		; A now contains our offset into the tables
	TAX			; Save into X
	
	LDA	KBDMATRIX,X
	BMI	.special	; Keys with high bit set shouldn't be modified
	
	LDA	CTRL
	BEQ	.notctrl
	; Ctrl pressed, read lower table and bitmask to CTRL keys
	LDA	KBDMATRIX,X
	AND	#$9F
.special		
	RTS
.notctrl
	LDA	SHIFT
	BEQ	.notshift
	; Shift pressed, read upper table
	LDA	KBDMATRIX_SHIFT,X
	RTS
.notshift
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

KBDTMP	DC.B $00

; Doing this the previous way there's no way it can take less than
; 80 loops (8x10 matrix and all need to be checked)
; Just reading that byte from the table takes 4/5 cyles
;  So 200+ cycles just in that
;  That doesn't include the branches, testing A, incrementing, etc.
;  There's no way this approach can be done this way. 
;
;  We could split it out over 10 calls, each row being handled on a different interrupt.
;
; We could speed it up conditionally by checking if no bits are set first
;  CMP #FF
; However I don't really want an approach that could drop data if someone mashes on the 
; keyboard if possible, since it's still O(n*m) in the worst case

; We could also scan the modifiers seperatly.
; But how do we make sure we ignore modifiers?
;   -- A table of bitmasks for each row?

; A log2 table could quickly do decoding by giving the index of the highest bit set
;  LDY PIA1_PB
;  LDA LOG2_TBL,Y
; !!However how would we detect shift and ctrl?!!
; This table is inverted due to our key tables being backwards
LOG2_TBL DC.B -1,7,6,6,5,5,5,5,4,4,4,4,4,4,4,4
         DC.B 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
         DC.B 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
         DC.B 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2


;LOG2_TBL DC.B -1,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3
;         DC.B 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
;         DC.B 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
;         DC.B 5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
; To save 192 bytes, we'll test bits 7 and 6 using BIT
;        DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;        DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;        DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;         DC.B 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
;  	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
;    	   DC.B 7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7

;-----------------------------------------------------------------------
; Poll the keyboard -VERY VERY SLOW- TOO SLOW, will break Rx
; ~1943 cycles
; KBDPOLL_SLOW	SUBROUTINE
; 	LDY	#10
; 	LDX	#0		; Offset into scan matrix
; 	STX	SHIFT
; 	STX	CTRL
; 	STX	KEY		; Reset key and shift
; 	STX	KEYOFF
; 	STY	PIA1_PA
; .loop
; 	DEC	PIA1_PA		; Set scan row
; 	LDA	PIA1_PB		; Read in row

; 	LDY	#8		; 8 bits
; .bitloop
; 	PHA
; 	ORA	#0		; Reset flags based on A
; 	BMI	.nextbit	; Check if key pressed (Top bit)
; 	; Found a keypress
; 	LDA	KBDMATRIX,X	; Read in scan
; 	BNE	.noshift	; $00 indicates shift key
	
; 	; A shift key has been pressed
; 	LDA	#$80
; 	STA	SHIFT
; 	BNE	.nextbit
; .noshift
; 	CMP	#$FF
; 	BNE	.noctrl
; 	; Ctrl key has been pressed
; 	LDA	#$80
; 	STA	CTRL
; 	BNE	.nextbit
; .noctrl
; 	CMP	#$F0		; Special keys $F0 to FE
; 	BCS	.special
; 	; Otherwise we found our keypress
; 	STA	KEY
; 	STX	KEYOFF
; 	; Keep going (incase of shift and ctrl keys)
; .nextbitEOR
; 	PLA			; Restore press
; 	ROL			; Shift left
; 	INX			; Next char in table
; 	DEY
; 	BNE	.bitloop	
; 	; Next row
; .next
; 	LDA	PIA1_PA		; Check if we're done
; 	AND	#$0F
; 	BNE	.loop
	
; 	; We're done, apply shift if needed
; 	LDA	SHIFT
; 	BPL	.tryctrl	; If not then keep the same
; 	; Do shift
; 	LDA	KEY
; 	BEQ	.nokey		; Ignore shift by itself
; 	LDX	KEYOFF
; 	LDA	KBDMATRIX_SHIFT,X
; .nokey
; 	RTS
; .tryctrl
; 	LDA	CTRL
; 	BPL	.std
; 	; Do ctrl
; 	LDA	KEY
; 	BEQ	.nokey
; 	AND	#$9F		; Convert lowercase to ctrl keys
; 	RTS
	
; .std
; 	LDA	MODE1
; 	AND	#MODE1_CASE
; 	BEQ	.casefix
; .nocasefix
; 	LDA	KEY
; 	AND	#$7F		; Remove high bit, if no shift key
; 	RTS
; .casefix
; 	TXA
; 	CMP	#$61		; a
; 	BCC	.nocasefix	
; 	CMP	#$7B		; z+1
; 	BCS	.nocasefix	
; 	ORA	#$20		; Always uppercase letters
; 	BNE	.nocasefix
	
; .special
; 	TAX
; 	PLA
; 	TXA
; 	RTS
	

	
	
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

; Keymasks to remove modifers from the scan results
; There are backward of the table above! Above goes from 9->0, these are 0->9
KEYMASK DC.B	$FF,$BF,$FF,$FF,$FF,$FF,$BE,$FF,$FE,$BF
; Which bits indicate shift keys
SHIFTMASK DC.B  $00,$00,$00,$00,$00,$00,$41,$00,$00,$00
; Which bits indicate ctrl keys
CTRLMASK DC.B   $00,$00,$00,$00,$00,$00,$00,$00,$01,$00
	ELSE
; This is the matrix for Graphics keyboards only!
; Buisness keyboards use a different matrix >_<
; $00 = shift
; $EF = non-existant
; $FF = REV  (ctrl key)
; $F0 = HOME (MENU key)
; If $80 set then don't apply shift 

KR9	DC.B	 '=, '.,$EF,$03, '<, ' , '[,$FF
KR8	DC.B	 '-, '0,$00, '>,$FF, '], '@,$00
KR7	DC.B	 '+, '2,$EF, '?, ',, 'n, 'v, 'x
KR6	DC.B	 '3, '1,$0D, ';, 'm, 'b, 'c, 'z
KR5	DC.B	 '*, '5,$EF, ':, 'k, 'h, 'f, 's
KR4	DC.B	 '6, '4,$EF, 'l, 'j, 'g, 'd, 'a
KR3	DC.B	 '/, '8,$EF, 'p, 'i, 'y, 'r, 'w
KR2	DC.B	 '9, '7, '^, 'o, 'u, 't, 'e, 'q
KR1	DC.B	$08,$11,$EF, '), '\, '', '$, '"
KR0	DC.B	$1D,$F0,$5F, '(, '&, '%, '#, '!

; Keymasks to remove modifers from the scan results
; There are backward of the table above! Above goes from 9->0, these are 0->9
KEYMASK DC.B	$FF,$DF,$FF,$DF,$DF,$DF,$FF,$DF,$D6,$DE
; Which bits indicate shift keys
SHIFTMASK DC.B  $00,$000,$00,$00,$00,$00,$00,$00,$21,$00
; Which bits indicate ctrl keys
CTRLMASK DC.B   $00,$00,$00,$00,$00,$00,$00,$00,$08,$01

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




