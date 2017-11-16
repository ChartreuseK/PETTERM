;-----------------------------------------------------------------------
; PET Term
; Version 0.1
;
; A bit-banged full duplex serial terminal for the PET 2001 computers,
; including those running BASIC 1.
;
; Targets 8N1 serial. Baud rate will be whatever we can set the timer for
; and be able to handle interrupts fast enough.
;
; References:
;     http://www.6502.org/users/andre/petindex/progmod.html 
;     http://www.zimmers.net/cbmpics/cbm/PETx/petmem.txt
;     http://www.commodore.ca/manuals/commodore_pet_2001_quick_reference.pdf

; I believe the VIA should be running at CPU clock rate of 1MHz
; This does not divide evenly to common baud rates, there will be some error
; Though the error values seem almost insignificant, even with the int. divisor
;  Timer values for various common baud rates:
;	110  - $2383  (9090.90...)  0.001% error
;	  Are you hooking this up to an ASR-33 or something?
; 	300  - $0D05  (3333.33...)  -0.01% error
;	600  - $0683  (1666.66...)  -0.04% error
;	1200 - $0341  (833.33...)   -0.04% error
;	2400 - $01A1  (416.66...)    0.08% error
;	4800 - $00D0  (208.33...)   -0.16% error
;	9600 - $0068  (104.16...)   -0.16% error
;	  I'd be impressed if we could run this fast without overrun
; Since we need 3x oversampling for our bit-bang routines, the valus we need
; are for 3x the baud rate:
;	110  - $0BD6  (3030.30...)  -0.01% error
; 	300  - $0457  (1111.11...)  -0.01% error
;	600  - $022C  (555.55...)   +0.08% error
;	1200 - $0116  (277.77...)   +0.08% error
;	2400 - $008B  (138.88...)   +0.08% error
;	4800 - $0045  (69.44...)    -0.64% error
;	9600 - $0023  (34.722...)   +0.80% error
;
; All of these are within normal baud rate tollerances of +-2% 
; Thus we should be fine to use them, though we'll be limited by just how
; fast our bit-bang isr is. I don't think the slowest path is < 35 cycles
; 2400 is probably the upper limit if we optimize, especially since we have
; to handle each character as well as recieve it. Though with flow control
; we might be able to push a little bit.
;
; Hayden Kroepfl 2017
;
; Written for the DASM assembler
;----------------------------------------------------------------------- 
	PROCESSOR 6502

;-----------------------------------------------------------------------
; Zero page definitions
; TODO: Should we move this to program memory so we don't overwrite
;  any BASIC variables? Then we don't have to worry about using KERNAL
;  routines as much.
;-----------------------------------------------------------------------
	SEG.U	ZPAGE
	RORG	$0

SERCNT	DS.B	1		; Current sample number
TXTGT	DS.B	1		; Sample number of next send event
RXTGT	DS.B	1		; Sample number of next recv event
TXCUR	DS.B	1		; Current byte being transmitted
RXCUR	DS.B	1		; Current byte being received
TXSTATE	DS.B	1		; Next Transmit state
RXSTATE	DS.B	1		; Next Receive state
TXBIT	DS.B	1		; Tx data bit #
RXBIT	DS.B	1		; Rx data bit #
RXSAMP	DS.B	1		; Last sampled value

TXBYTE	DS.B	1		; Next byte to transmit
RXBYTE	DS.B	1		; Last receved byte

RXNEW	DS.B	1		; Indicates byte has been recieved
TXNEW	DS.B	1		; Indicates to start sending a byte

BAUD	DS.B	1		; Current baud rate, index into table

COL	DS.B	1		; Current cursor position		
ROW	DS.B	1

CURLOC	DS.W	1		; Pointer to current screen location

TMP1	DS.B	1	
TMP2	DS.B	1

TMPA	DS.W	1
TMPA2	DS.W	1

POLLRES	DS.B	1		; KBD Polling interval for baud
POLLTGT	DS.B	1		; Polling interval counter

KBDBYTE	DS.B	1
KBDNEW	DS.B	1
KEY	DS.B	1
SHIFT	DS.B	1

	RORG	$90

	DS.B	1		; Reserve so we get a compiler error
; Make sure not to use $90-95	, Vectors for BASIC 2+
	REND
;-----------------------------------------------------------------------

;-----------------------------------------------------------------------
; GLOBAL Defines
;-----------------------------------------------------------------------
STSTART	EQU	0		; Waiting/Sending for start bit
STRDY	EQU	1		; Ready to start sending
STBIT	EQU	2		; Sending/receiving data
STSTOP	EQU	3		; Sending/receiving stop bit
STIDLE	EQU	4

BITCNT	EQU	8		; 8-bit bytes to recieve
BITMSK	EQU	$FF		; No mask

SCRCOL	EQU	40		; Screen columns
SCRROW	EQU	25

COLMAX	EQU	40		; Max display columns
ROWMAX	EQU	25

; 6522 VIA 
VIA_PORTB  EQU	$E840
VIA_PORTAH EQU	$E841		; User-port with CA2 handshake (messes with screen)
VIA_DDRB   EQU	$E842
VIA_DDRA   EQU	$E843		; User-port directions
VIA_TIM1L  EQU	$E844		; Timer 1 low byte
VIA_TIM1H  EQU	$E845		; high
VIA_TIM1LL EQU	$E846		; Timer 1 low byte latch
VIA_TIM1HL EQU	$E847		; high latch
VIA_TIM2L  EQU	$E848		; Timer 2 low byte
VIA_TIM2H  EQU	$E849		; high
VIA_SR     EQU	$E84A
VIA_ACR	   EQU	$E84B
VIA_PCR    EQU  $E84C
VIA_IFR    EQU	$E84D		; Interrupt flag register
VIA_IER    EQU	$E84E		; Interrupt enable register
VIA_PORTA  EQU	$E84F		; User-port without CA2 handshake


PIA1_PA	   EQU	$E810
PIA1_PB	   EQU	$E812
PIA1_CRA   EQU  $E811
PIA1_CRB   EQU  $E813



PIA2_CRA   EQU  $E821
PIA2_CRB   EQU  $E823

SCRMEM     EQU	$8000		; Start of screen memory
SCREND	   EQU	SCRMEM+(SCRCOL*SCRROW) ; End of screen memory
SCRBTML	   EQU  SCRMEM+(SCRCOL*(SCRROW-1)) ; Start of last row

; These are for BASIC2/4 according to 
; http://www.zimmers.net/cbmpics/cbm/PETx/petmem.txt
; Also make sure our ZP allocations don't overwrite
BAS4_VECT_IRQ  EQU	$0090	; 90/91 - Hardware interrupt vector
BAS4_VECT_BRK  EQU	$0092	; 92/93 - BRK vector

; This is for a 2001-8 machine according to:
; http://www.commodore.ca/manuals/commodore_pet_2001_quick_reference.pdf
; This is presumably for a BASIC 1.0 machine!
BAS1_VECT_IRQ  EQU	$0219	; 219/220 - Interrupt vector
BAS1_VECT_BRK  EQU	$0216	; 216/217 - BRK vector


;-----------------------------------------------------------------------
; Start of loaded data
	SEG	CODE
	ORG	$0401           ; For PET 2001 
	; I saw that the PET 2001 with BASIC 1.0 might need to be loaded at $400
	; instead of $401? Confirm?
	


;-----------------------------------------------------------------------
; Simple Basic 'Loader' - BASIC Statement to jump into our program
BLDR
	DC.W BLDR_ENDL	; LINK (To end of program)
	DC.W 10		; Line Number = 10
	DC.B $9E	; SYS
	; Decimal Address in ASCII $30 is 0 $31 is 1, etc
	DC.B (INIT/10000)%10 + '0
	DC.B (INIT/ 1000)%10 + '0
	DC.B (INIT/  100)%10 + '0
	DC.B (INIT/   10)%10 + '0
	DC.B (INIT/    1)%10 + '0

	DC.B $0		; Line End
BLDR_ENDL
	DC.W $0		; LINK (End of program)
;-----------------------------------------------------------------------


;-----------------------------------------------------------------------
; Initialization
INIT	SUBROUTINE
	SEI			; Disable interrupts
	
	; Clear ZP?
	
	; We never plan to return to BASIC, steal everything!
	LDX	#$FF		; Set start of stack
	TXS			; Set stack pointer to top of stack
	
	; Determine which version of BASIC we have for a KERNAL
	; TODO: What's a reliable way? Maybe probe for a byte that's
	; different in each version. Find such a byte using emulators.
	
	
	
	; Set timer to 3x desired initial baud rate
	LDA	#$01		; 300 baud
	STA	BAUD
	
	
	LDA	PIA1_CRB
	AND	#$FE		; Disable interrupts (60hz retrace int?)
	STA	PIA1_CRB	
	LDA	PIA1_CRA
	AND	#$FE
	STA	PIA1_CRA	; Disable interrupts
	
	LDA	PIA2_CRB
	AND	#$FE		; Disable interrupts (60hz retrace int?)
	STA	PIA2_CRB	
	LDA	PIA2_CRA
	AND	#$FE
	STA	PIA2_CRA	; Disable interrupts
	
	
	
	; Install IRQ
	LDA	#<IRQHDLR
	LDX	#>IRQHDLR
	STA	BAS1_VECT_IRQ	; Modify based on BASIC version
	STX	BAS1_VECT_IRQ+1
	STA	BAS4_VECT_IRQ	; Let's see if we can get away with modifying
	STX	BAS4_VECT_IRQ+1	; both versions vectors
	
	
	JSR	INITVIA
	
	
	; Initialize state
	LDA	#STSTART
	STA	RXSTATE
	LDA	#STIDLE		; Output 1 idle tone first
	STA	TXSTATE
	
	LDA	#1
	JSR	SETTX		; Make sure we're outputting idle tone
	
	LDA	#0
	STA	SERCNT
	STA	TXTGT		; Fire Immediatly
	STA	RXTGT		; Fire immediatly
	STA	RXNEW		; No bytes ready
	STA	TXNEW		; No bytes ready
	STA	ROW
	STA	COL
	
	STA	CURLOC
	LDA	#$80
	STA	CURLOC+1
	
	; Set-up screen
	JSR	CLRSCR
	
	LDA	#0
	STA	VIA_TIM1L
	STA	VIA_TIM1H	; Need to clear high before writing latch
				; Otherwise it seems to fail half the tile?
	LDX	BAUD
	LDA	BAUDTBLL,X
	STA	VIA_TIM1LL
	LDA	BAUDTBLH,X
	STA	VIA_TIM1HL
	LDA	POLLINT,X
	STA	POLLRES
	STA	POLLTGT
	
	
	
	; Fall into START
;-----------------------------------------------------------------------
; Start of program (after INIT called)
START	SUBROUTINE
	
	CLI	; Enable interrupts

; Init for GETBUF
;	LDA	#<BUF
;	STA	TMPA2
;	LDA	#>BUF
;	STA	TMPA2+1


.loop
	LDA	RXNEW
	BEQ	.norx		; Loop till we get a character in
	LDA	#$0
	STA	RXNEW		; Acknowledge byte
	LDA	RXBYTE
	JSR	PARSECH
.norx
	LDA	KBDNEW
	BEQ	.nokey
	LDA	#$0
	STA	KBDNEW
	LDA	KBDBYTE
	
; LOCAL ECHOBACK CODE
	PHA
	JSR	PARSECH		; Local-echoback for now
	PLA
	PHA
	CMP	#$0D		; \r
	BNE	.noechonl
	LDA	#$0A
	JSR	PARSECH
.noechonl
	PLA
; LOCAL ECHOBACK CODE
	
	; Check if we can push the byte
	LDX	TXNEW
	CPX	#$FF
	BEQ	.nokey		; Ignore key if one waiting to send
	STA	TXBYTE
	LDA	#$FF
	STA	TXNEW		; Signal to transmit
.nokey
	JMP	.loop




; Get a character from the serial port (blocking)
GETCH	SUBROUTINE	
	LDA	RXNEW
	BEQ	GETCH		; Loop till we get a character in
	LDA	#$0
	STA	RXNEW		; Acknowledge byte
	LDA	RXBYTE
	RTS
	
;-----------------------------------------------------------------------
; Parse character and handle it
; Ch in A
PARSECH	SUBROUTINE
	CMP	#$20
	BCS	.normal
	CMP	#$0A
	BEQ	.nl
	CMP	#$0D
	BEQ	.cr
	CMP	#$1B
	BEQ	DOESC
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

; Escape code handling
; Move variables to ZP space
PARSTKL	EQU	4		; Allow up to 4 arguments
PARSTK	DS.B	PARSTKL		

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
	CMP	#$40
	BCS	.final		; Final character byte
	CMP	#$30
	BCS	.param		; Parameter byte
	
	CMP	#$20
	BCS	.inter		; Intermediary byte (No param must follow)
	; Invalid CSI sequence, abort
	RTS
.inter
	; Ignore intermediate bytes for now
	JMP	.csiloop
.param
	CMP	#':
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
	LDY	#10
	
.digmul
	CLC
	ADC	PARSTK,X
	DEY
	BNE	.digmul
	STA	PARSTK,X
	JMP	.csiloop
	
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
	
	

;-----------------------------------------------------------------------
; Static data

; Baud rate timer values, 3x the baud rate
;		 110  300  600 1200 2400 4800 9600
BAUDTBLL 
	DC.B	$D6, $57, $2c, $16, $8B, $45, $23
BAUDTBLH	
	DC.B	$0B, $04, $02, $01, $00, $00, $00
	
; Poll interval mask for ~60Hz polling based on the baud timer
	; 	110  300   600 1200 2400 4800  9600 (Baud)
POLLINT	; 	330  900  1800 2400 4800 9600 19200 (Calls/sec)
	DC.B	  5,  15,  30,  60, 120, 240, 480
;Ideal for 60Hz 5.5   15   30   60  120  240  480
;Poll freq Hz  	66    60   60   60   60   60   60
;-----------------------------------------------------------------------




;-----------------------------------------------------------------------
; Interrupt handler
IRQHDLR	SUBROUTINE
	; We'll assume that the only IRQ firing is for the VIA timer 1
	; (ie. We've set it up right)
	LDA	VIA_TIM1L	; Acknowlege the interrupt
	JSR	SERSAMP		; Do our sampling
	
IRQEXIT
	; Restore registers saved on stack by KERNAL
	PLA			; Pop Y
	TAY
	PLA			; Pop X
	TAX
	PLA			; Pop A
	RTI			; Return from interrupt

;-----------------------------------------------------------------------
; Bit-banged serial sample (Called at 3x baud rate)
SERSAMP	SUBROUTINE
	LDA	SERCNT
	CMP	RXTGT		; Check if we're due for the next Rx event
	BNE	.trytx
	JSR	SERRX
.trytx
	LDA	SERCNT
	CMP	TXTGT
	BNE	.tryscan
	JSR	SERTX
.tryscan
	DEC	POLLTGT
	LDA	POLLTGT
	BNE	.exit
	
	LDA	POLLRES
	STA	POLLTGT
	JSR	KBDPOLL	
	CMP	KBDBYTE
	STA	KBDBYTE
	BEQ	.exit		; Don't repeat
	LDA	KBDBYTE
	BEQ	.exit		; Don't signal blank keys
	LDA	#$FF
	STA	KBDNEW		; Signal a pressed key
.exit
	INC	SERCNT
	RTS
	
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

;-----------------------------------------------------------------------
; Do a Rx sample
SERRX	SUBROUTINE
	JSR	SAMPRX		; Sample the Rx line
	LDA	RXSTATE
	CMP	#STSTART	; Waiting for start bit
	BEQ	.start
	CMP	#STBIT		; Sample data bit
	BEQ	.datab
	CMP	#STSTOP		; Sample stop bit
	BEQ	.stop
	; Invalid Rx state, reset to STSTART
	LDA	#STSTART
	STA	RXSTATE
	JMP	.next1
.stop
	LDA	RXSAMP		; Make sure stop bit is 0
	BNE	.nextstart	; Failed recv, unexpected value Ignore byte
				; (Framing error)
				; resume waiting for start bit
	; Otherwise save bit
	LDA	RXCUR
	STA	RXBYTE		; Save cur byte, as received byte
	LDA	#$FF
	STA	RXNEW		; Indicate byte recieved
.nextstart
	LDA	#STSTART
	STA	RXSTATE
	JMP	.next3		; Change this if we want to change 
				; the stop bit length (3 = 1 bit, 6 = 2 bits)
	
		
.datab
	CLC
	ROL	RXCUR		; Shift left to make room for bit
	LDA	RXCUR
	ORA	RXSAMP		; Or in current bit
	STA	RXCUR
	INC	RXBIT
	LDA	RXBIT
	CMP	#BITCNT		; Check if we've read our last bit
	BNE	.next3
	LDA	#STSTOP		; Next is the stop bit
	STA	RXSTATE
	JMP	.next3
	
.start
	LDA	RXSAMP		; Look for 0 for start bit
	BNE	.next1		; If we didn't find it, try again next sample
	LDA	#STBIT
	STA	RXSTATE
	LDA	#0		; Reset bit count
	STA	RXBIT
.next4
	INC	RXTGT		; Next sample at cur+4
.next3
	INC	RXTGT		; cur + 3
.next2
	INC	RXTGT		; Cur + 2
.next1
	INC	RXTGT		; Cur + 1
	RTS
	
	

;-----------------------------------------------------------------------
; Do a Tx sample event
SERTX	SUBROUTINE
	LDA	TXSTATE
	CMP	#STRDY
	BEQ	.ready
	CMP	#STSTART
	BEQ	.start
	CMP	#STBIT
	BEQ	.datab
	CMP	#STSTOP
	BEQ	.stop
	CMP	#STIDLE
	BEQ	.idle
	; Invalid state
	LDA	#STRDY
	STA	TXSTATE
	JMP	.ready		; Treat as ready state
.idle	; Force idle for 1 baud period
	LDA	#1
	JSR	SETTX		; Idle
	LDA	#STRDY
	STA	TXSTATE
	JMP	.next3		
.stop	; Send stop bit
	LDA	#0
	JSR	SETTX		; Send stop bit
	LDA	#STIDLE
	STA	TXSTATE
	JMP	.next3		; Change this if we want to change 
				; the stop bit length (3 = 1 bit, 6 = 2 bits)
.datab	; Send data bit
	LDA	#0
	ROR	TXCUR		; Rotate current bit into carry
	ROL			; Place into A
	JSR	SETTX
	INC	TXBIT
	LDA	TXBIT
	CMP	#BITCNT
	BNE	.next3		; If more bits to go
	LDA	#STSTOP
	STA	TXSTATE
	JMP	.next3		; Hold for 3 samples
	
.start	; Send start bit
	LDA	#0	
	STA	TXBIT		; Reset bit count
	JSR	SETTX		; Send Start bit
	LDA	#STBIT
	STA	TXSTATE
	JMP	.next3		; Hold start bit for 3 samples
	
.ready
	LDA	#1
	JSR	SETTX		; Idle state
	
	LDA	TXNEW		; Check if we have a byte waiting to send
	BPL	.next3		; If not check again next baud		
	LDA	TXBYTE
	STA	TXCUR		; Copy byte to read
	LDA	#0
	STA	TXNEW		; Reset new flag
	LDA	#STSTART	
	STA	TXSTATE
	;JMP	.next1		; Start sending next sample period
.next3	
	INC	TXTGT
.next2
	INC	TXTGT
.next1
	INC	TXTGT
	RTS
	
	


;#######################################################################
; Device dependent routines
;-----------------------------------------------------------------------
; May need to be modified depending on hardware used
;#######################################################################
	
	
	
;-----------------------------------------------------------------------
; Sample the Rx pin into RXSAMP
; 1 for high, 0 for low
; NOTE: If we want to support inverse serial do it in here, and SETTX
SAMPRX	SUBROUTINE
	LDA	VIA_PORTA
	AND	#$01		; Only read the Rx pin
	EOR	#$01		; Invert?
	STA	RXSAMP
	RTS

;-----------------------------------------------------------------------
; Set Tx pin to value in A
; Tx pin is on userport M (CB2)
; If serial inversion needed, change BEQ to BNE
SETTX	SUBROUTINE
	CMP	#0
	BEQ	.low		; BEQ for normal, BNE for 'inverted'
	LDA	VIA_PCR
	ORA	#$20		; Make bit 5 high
	STA	VIA_PCR
	RTS
.low
	LDA	VIA_PCR
	AND	#$DF		; Make bit 5 low
	STA	VIA_PCR
	RTS


;-----------------------------------------------------------------------
; Initialize VIA and userport
INITVIA SUBROUTINE
	LDA	#$00		; Rx pin in (PA0) (rest input as well)
	STA	VIA_DDRA	; Set directions
	LDA	#$40		; Shift register disabled, no latching, T1 free-run
	STA	VIA_ACR		
	LDA	#$EC		; Tx as output high, uppercase+graphics ($EE for lower)
	STA	VIA_PCR		
	; Set VIA interrupts so that our timer is the only interrupt source
	LDA	#$7F		; Clear all interrupt flags
	STA	VIA_IER
	LDA	#$C0		; Enable VIA interrupt and Timer 1 interrupt
	STA	VIA_IER
	RTS
	
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
	

