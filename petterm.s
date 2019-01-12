;-----------------------------------------------------------------------
; PET Term
; Version 0.3.1
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
; Hayden Kroepfl 2017-2019
;
; Changelog
; 0.2.0	
;	- First semi-public release
;	- Added configuration menu for baud, mixed case support
; 0.2.1	
;	- Added control key support (OFF/RVS key)
;	- Added ability to re-open menu (CLR/HOME key)
; 0.2.2
;	- Inverted mixed-case, was backwards compared with real hardware.
; 0.3.0
;   - Re-wrote keyboard shift handling.
;   - Added compile time support for 80 column, buisness layout machines
;   - Made _ and | display correctly in PETSCII
;   ! Completely broke on real hardware
;   !! Keyboard scan routine takes ~1943 cycles to complete
;      But interrupt handler needs to be called every 1111 to not lose
;      bits at 300 baud!
; 0.3.1
;   - Re-wrote keyboard scanning code, old one was too slow and caused desync
;   - Added simple inverted cursor
;   - Optimizations

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
	
	INCLUDE	"zpage.s"
	
	REND
;-----------------------------------------------------------------------

;-----------------------------------------------------------------------
; GLOBAL Defines
;-----------------------------------------------------------------------
	INCLUDE "constants.s"


;-----------------------------------------------------------------------
; Start of loaded data
	SEG	CODE
	ORG	$0401           ; Start address for PET computers
	
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
	STA	MODE1
	; Set-up screen
	STA	CURLOC
	LDA	#$80
	STA	CURLOC+1	;$8000 = top left of screen
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
	
	; Set default modifiers so menu can print 
	LDA	#SCUM_UPPER	; Default mode is uppercase only
	STA	SC_UPPERMOD	
	LDA	#SCLM_UPPER	; Default mode is uppercase only
	STA	SC_LOWERMOD
	
	
	; Fall into START
;-----------------------------------------------------------------------
; Start of program (after INIT called)
START	SUBROUTINE
	CLI	; Enable interrupts
	
.remenu
	JSR	DOMENU
	
	JSR	SERINIT		; Re-initialize serial based on menu choices
	
	JSR	CASEINIT	; Setup for Mixed or UPPER case 
	
	
	JSR	CLRSCR
	LDX	#0
	LDY	#0
	JSR	GOTOXY

.loop
	LDA	RXNEW
	BEQ	.norx		; Loop till we get a character in

	; Remove cursor from old position before handling
	LDY	#0
	LDA	(CURLOC),Y
	;AND	#$7F
	EOR	#$80
	STA	(CURLOC),Y

	; Handle new byte
	LDA	#$0
	STA	RXNEW		; Acknowledge byte
	LDA	RXBYTE
	JSR	PARSECH

	; Set cursor at new position
	LDY	#0
	LDA	(CURLOC),Y
	;ORA	#$80
	EOR	#$80
	STA	(CURLOC),Y
.norx
	LDA	KBDNEW
	BEQ	.nokey
	LDA	#$0
	STA	KBDNEW
	
	LDA	KBDBYTE
	BMI	.termkey	; Key's above $80 are special keys for the terminal
	
	LDA	MODE1
	AND	#MODE1_ECHO
	BEQ	.noecho
	
; LOCAL ECHOBACK CODE
	LDA	KBDBYTE
	PHA
	JSR	PARSECH		; Local-echoback for now
	PLA
	PHA
	CMP	#$0D		; \r
	BNE	.noechonl
	LDA	#$0A;
	JSR	PARSECH
.noechonl
	PLA
; LOCAL ECHOBACK CODE
.noecho
	LDA	KBDBYTE
	
	; Check if we can push the byte
	LDX	TXNEW
	CPX	#$FF
	BEQ	.nokey		; Ignore key if one waiting to send
	STA	TXBYTE
	LDA	#$FF
	STA	TXNEW		; Signal to transmit
.nokey
	JMP	.loop

.termkey
	CMP	#$F0		; $F0 - Menu key
	BEQ	.remenu
	CMP	#$F1		; $F1 - Up arrow
	BEQ	.arrowkey
	CMP	#$F2		; $F2 - Down arrow
	BEQ	.arrowkey
	CMP	#$F3		; $F3 - Right arrow
	BEQ	.arrowkey
	CMP	#$F4		; $F4 - Left arrow
	BEQ	.arrowkey
	JMP	.loop
.arrowkey
	PHA
	; We'll be sending ANSI cursor positioning codes
	; ESC [ A, through ESC [ B
	LDA	#$1B		; ESC
	JSR	SENDCH
	LDA	#'[		; [ - CSI
	JSR	SENDCH
	PLA
	; Convert F1-F4 to 'A'-'D' (41-44)
	AND	#$4F
	JSR	SENDCH
	JMP	.loop


;-----------------------------------------------------------------------
;-- Bit-banged serial code ---------------------------------------------
;-----------------------------------------------------------------------
	INCLUDE "serial.s"
;-----------------------------------------------------------------------
;-- ANSI escape code handling ------------------------------------------
;-----------------------------------------------------------------------
	INCLUDE "ansi.s"
;-----------------------------------------------------------------------
;-- Screen routines and cursor control ---------------------------------
;-----------------------------------------------------------------------
	INCLUDE "screen.s"
;-----------------------------------------------------------------------
;-- Keyboard polling code ----------------------------------------------
;-----------------------------------------------------------------------
	INCLUDE "kbd.s"
;-----------------------------------------------------------------------
;-- Options menu code --------------------------------------------------
;-----------------------------------------------------------------------
	INCLUDE "menu.s"

	
	


	
	

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
;Val for 60Hz   5.5   15   30   60  120  240  480
;Poll freq Hz  	66    60   60   60   60   60   60
;-----------------------------------------------------------------------




;-----------------------------------------------------------------------
; Interrupt handler
IRQHDLR	SUBROUTINE
	; We'll assume that the only IRQ firing is for the VIA timer 1
	; (ie. We've set it up right)
	LDA	VIA_TIM1L	; Acknowlege the interrupt
	JSR	SERSAMP		; Do our sampling
	
	DEC	POLLTGT		; Check if we're due to poll
	BNE	.exit
	
	LDA	POLLRES
	STA	POLLTGT
	JSR	KBDPOLL		; Do keyboard polling
	

	
	CMP	KBDBYTE		; Check if the same byte as before
	STA	KBDBYTE
	BEQ	.exit		; Don't repeat
	LDA	KBDBYTE
	BEQ	.exit		; Don't signal blank keys
	LDA	#$FF
	STA	KBDNEW		; Signal a pressed key
.exit
	; Restore registers saved on stack by KERNAL
	PLA			; Pop Y
	TAY
	PLA			; Pop X
	TAX
	PLA			; Pop A
	RTI			; Return from interrupt


	


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
	
	


