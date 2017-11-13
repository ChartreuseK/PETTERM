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


BITCNT	EQU	8		; 8-bit bytes to recieve
BITMSK	EQU	$FF		; No mask

SCRCOL	EQU	40		; Screen columns
SCRROW	EQU	25

COLMAX	EQU	40		; Max display columns
ROWMAX	EQU	25

; 6522 VIA 
VIA_PORTAH EQU	$E841		; User-port with CA2 handshake (messes with screen)
VIA_DDRA   EQU	$E843		; User-port directions

VIA_TIM1L  EQU	$E844		; Timer 1 low byte
VIA_TIM1H  EQU	$E845		; high
VIA_TIM1LL EQU	$E846		; Timer 1 low byte latch
VIA_TIM1HL EQU	$E847		; high latch
VIA_TIM2L  EQU	$E848		; Timer 2 low byte
VIA_TIM2H  EQU	$E849		; high

VIA_IFR    EQU	$E84D		; Interrupt flag register
VIA_IER    EQU	$E84E		; Interrupt enable register

VIA_PORTA  EQU	$E84F		; User-port without CA2 handshake

SCRMEM     EQU	$8000		; Start of screen memory

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

; Kernal routines (confirm these are the same between BASIC 1,2,4
KRN_WRT	EQU	$FFD2		; Write character in A
KRN_GET EQU	$FFE4		; Get a character NZ if key pressed, Z if. ch in A
; I don't think these are portable
KRN_SCROLL EQU	$E559		; Scroll screen one line
KRN_CLR EQU	$E236		; Clear screen

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
	; We never plan to return to BASIC, steal everything!
	LDX	#$FF		; Set start of stack
	TXS			; Set stack pointer to top of stack
	
	; Determine which version of BASIC we have for a KERNAL
	; TODO: What's a reliale way? Maybe probe for a byte that's
	; different in each version. Find such a byte using emulators.
	
	
	; Set timer to 3x desired initial baud rate
	LDA	#$01		; 300 baud
	STA	BAUD
	
	LDX	BAUD
	LDA	BAUDTBLL,X
	STA	VIA_TIM1LL
	LDA	BAUDTBLH,X
	STA	VIA_TIM1HL
	
	; Set VIA interrupts so that our timer is the only interrupt source
	; This should also disable the CA1 60Hz interrupt. We don't care
	; about the jiffies. (I hope)
	LDA	#$C0		; Enable VIA interrupt and Timer 1 interrupt
	STA	VIA_IER
	
	; Install IRQ
	LDA	#<IRQHDLR
	LDX	#>IRQHDLR
	STA	BAS1_VECT_IRQ	; Modify based on BASIC version
	STX	BAS1_VECT_IRQ+1
	STA	BAS4_VECT_IRQ	; Let's see if we can get away with modifying
	STX	BAS4_VECT_IRQ+1	; both versions vectors
	
	; Initialize state
	LDA	#STSTART
	STA	RXSTATE
	LDA	#STRDY
	STA	TXSTATE
	
	LDA	#0
	STA	SERCNT
	STA	TXTGT		; Fire Immediatly
	STA	RXTGT		; Fire immediatly
	STA	RXNEW		; No bytes ready
	STA	TXNEW		; No bytes ready
	
	; Set-up screen
	JSR	CLRSCR
	
	; Fall into START
;-----------------------------------------------------------------------
; Start of program (after INIT called)
START	SUBROUTINE
	
	LDA	#'H
	JSR	PUTCH
	LDA	#'E
	JSR	PUTCH
	LDA	#'L
	JSR	PUTCH
	LDA	#'L
	JSR	PUTCH
	LDA	#'O
	JSR	PUTCH
	LDA	#' 
	JSR	PUTCH
	LDA	#'W
	JSR	PUTCH
	LDA	#'O
	JSR	PUTCH
	LDA	#'R
	JSR	PUTCH
	LDA	#'L
	JSR	PUTCH
	LDA	#'D
	JSR	PUTCH
HALT	
	JMP	HALT


;-----------------------------------------------------------------------
; Static data

; Baud rate timer values
;		 110  300  600 1200 2400 4800 9600
BAUDTBLL 
	DC.B	$D6, $57, $2c, $16, $8B, $45, $23
BAUDTBLH	
	DC.B	$0B, $04, $02, $01, $00, $00, $00
	
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
	CMP	TXTGT
	BNE	.end
	JSR	SERTX
.end
	INC	SERCNT
	RTS
	
	
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
	LDA	RXSAMP
	CMP	#1		; Make sure stop bit is 0
	BEQ	.nextstart	; Failed recv, unexpected value Ignore byte 
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
	INC	RXBIT
	LDA	RXBIT
	CMP	#BITCNT		; Check if we've read our last bit
	BNE	.next3
	LDA	#STSTOP		; Next is the stop bit
	STA	RXSTATE
	JMP	.next3
	
.start
	LDA	RXSAMP
	CMP	#1		; Check if high
	BEQ	.next1		; If we didn't find it, try again next sample
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
	; Invalid state
	LDA	#STRDY
	STA	TXSTATE
	JMP	.ready		; Treat as ready state
.stop	; Send stop bit
	LDA	#0
	JSR	SETTX		; Send stop bit
	LDA	#STRDY
	STA	TXSTATE
	JMP	.next3		; Change this if we want to change 
				; the stop bit length (3 = 1 bit, 6 = 2 bits)
.datab	; Send data bit
	LDA	#0
	ROL	TXCUR		; Rotate current bit into carry
	ROL			; Place into A
	JSR	SETTX
	INC	RXBIT
	LDA	RXBIT
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
	BPL	.next1		; If not check again next sample		
	LDA	TXBYTE
	STA	TXCUR		; Copy byte to read
	LDA	#0
	STA	TXNEW		; Reset new flag
	LDA	#STSTART	
	STA	TXSTATE
	JMP	.next1		; Start sending next sample period
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
	
	RTS

;-----------------------------------------------------------------------
; Set Tx pin to value in A
SETTX	SUBROUTINE
	




;-----------------------------------------------------------------------
; Clear screen
CLRSCR	SUBROUTINE
	; Screen is 40x25 (1000 bytes)
	; We probably should clear the remaining part of the screen
	; on 80 column PETs. Should just be 4 more STA statements
	LDA	#0		; Fill byte for screen
	LDX	#0		; We want to write 256 times
.loop
	STA	SCRMEM+0,X	; Clear all 1024 bytes in one pass
	STA	SCRMEM+256,X
	STA	SCRMEM+512,X
	STA	SCRMEM+768,X
	DEX
	BNE	.loop
	RTS
	
;-----------------------------------------------------------------------
; Scroll the screen by one line
; TODO: Is there a cleaner way to do this fairly fast?
SCROLL	SUBROUTINE
	; Scroll characters upwards
	LDA	#<SCRMEM
	STA	.first
	LDA	#>SCRMEM
	STA	.first+1
	
	LDA	#<(SCRMEM+SCRCOL)
	STA	.second
	LDA	#>(SCRMEM+SCRCOL)
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

	; Check if we wrote the character in the bottom right
	; and need to scroll the screen
	
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
	SEC
	SBC	#$40
.done
	RTS
.upper
	SEC
	SBC	#$20
	RTS
.lower
	SEC
	SBC	#$60		; Convert to uppercase letters
	RTS
.nonprint
	LDA	#$A0		; Inverse Space
	RTS
	

