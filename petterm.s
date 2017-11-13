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
	; We never plan to return to BASIC, steal everything!
	LDX	#FF		; Set start of stack
	TXS			; Set stack pointer to top of stack
	
	; Determine which version of BASIC we have for a KERNAL
	; TODO: What's a reliale way? Maybe probe for a byte that's
	; different in each version. Find such a byte using emulators.
	
	; Set timer to 3x desired initial baud rate
	
	; Set VIA interrupts so that our timer is the only interrupt source
	
	; Install IRQ
	LDA	#<SOUND_IRQ
	LDX	#>SOUND_IRQ
	STA	BAS1_VECT_IRQ	; Modify based on BASIC version
	STX	BAS1_VECT_IRQ+1
	
	; Initialize state
	LDA	#STSTART
	STA	RXSTATE
	LDA	#STRDY
	STA	TXSTATE
	
	EOR	A		; LDA #0
	STA	SERCNT
	STA	TXTGT		; Fire Immediatly
	STA	RXTGT		; Fire immediatly
	STA	RXNEW		; No bytes ready
	STA	TXNEW		; No bytes ready
	; Fall into START
;-----------------------------------------------------------------------
; Start of program (after INIT called)
START	SUBROUTINE
	





;-----------------------------------------------------------------------
; Interrupt handler
IRQHLDR	SUBROUTINE
	; We'll assume that the only IRQ firing is for the VIA timer 1
	; (ie. We've set it up right)
	LDA	VIA_TIM1L	; Acknowlege the interrupt
	CALL	SERSAMP		; Do our sampling
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
	CMP	#STDATA		; Sample data bit
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
	LDA	#STDATA
	STA	RXSTATE
	EOR	A		; Reset bit count
	STA	RXBIT
.next4
	INC	RXSAMP		; Next sample at cur+4
.next3
	INC	RXSAMP		; cur + 3
.next2
	INC	RXSAMP		; Cur + 2
.next1
	INC	RXSAMP		; Cur + 1
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
	LDA	#STREADY
	STA	TXSTATE
	JMP	.ready		; Treat as ready state
.stop	; Send stop bit
	EOR	A
	CALL	SETTX		; Send stop bit
	LDA	#STRDY
	STA	TXSTATE
	JMP	.next3		; Change this if we want to change 
				; the stop bit length (3 = 1 bit, 6 = 2 bits)
.datab	; Send data bit
	EOR	A
	ROL	TXCUR		; Rotate current bit into carry
	ROL	A		; Place into A
	CALL	SETTX
	INC	RXBIT
	LDA	RXBIT
	CMP	#BITCNT
	BNE	.next3		; If more bits to go
	LDA	#STSTOP
	STA	TXSTATE
	JMP	.next3		; Hold for 3 samples
	
.start	; Send start bit
	EOR	A		
	STA	TXBIT		; Reset bit count
	CALL	SETTX		; Send Start bit
	LDA	#STBIT
	STA	TXSTATE
	JMP	.next3		; Hold start bit for 3 samples
	
.ready
	LDA	#1
	CALL	SETTX		; Idle state
	
	LDA	TXNEW		; Check if we have a byte waiting to send
	BPL	.next1		; If not check again next sample		
	LDA	TXBYTE
	STA	TXCUR		; Copy byte to read
	EOR	A
	STA	TXNEW		; Reset new flag
	LDA	#STSTART	
	STA	TXSTATE
	JMP	.next1		; Start sending next sample period
.next3	
	INC	TXSAMP
.next2
	INC	TXSAMP
.next1
	INC	TXSAMP
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
	
