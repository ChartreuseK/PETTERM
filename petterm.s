;-----------------------------------------------------------------------
; PETTerm
; Version 0.6.0
;
; A bit-banged full duplex serial terminal for the PET 2001 computers,
; including those running BASIC 1. 
;  Currently requires 8kB or more RAM (~4.5kB at the moment)
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
;     -----Unworkable below due to hardware speed------
;	4800 - $00D0  (208.33...)   -0.16% error
;	9600 - $0068  (104.16...)   -0.16% error
;
; All of these are within normal baud rate tollerances of +-2% 
; Thus we should be fine to use them, though we'll be limited by just how
; fast our bit-bang isr is. I don't think the slowest path is < 35 cycles
; 2400 is probably the upper limit if we optimize, especially since we have
; to handle each character as well as recieve it. Though with flow control
; we might be able to push a little bit.
;
; Hayden Kroepfl (Chartreuse) 2017-2020
; Adam Whitney (K0FFY) 2022 - Added Exit and BASIC Save/Load Extension
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
;
; 0.4.0
;   - Re-wrote serial recieve routines to use interrupt triggered start bit
;   -> Now Requires a jumper between pin B and C on the userport header
;      This is the same as most VIC-20 and C64 serial adapters so little 
;      change should be required
;   - Allows for significantly faster serial code with less overhead
;     as we don't have to oversample by 3x anymore
;   - 600 and 1200 baud works and appears to be stable
;     -> 80 column PETs may have an issue at 1200 baud if too many newlines
;        are sent in a row due to the time needed to scroll the screen.
;   - Significantly optimized screen handling code
;   - Fixed keyboard arrow keys bug
;   - Improved character rendering, all ASCII characters should look
;     as close to correct as possible. 
;      (~ is rendered as an inverted T block drawing character)
;
; 0.5.0
;   - Re-written, vastly more complete ANSI escape code handler
;   - NOW REQUIRES a PET with at least 8kB of RAM (For 4k PETs stick with the 0.4 series 0.3.1)
;     This was a consequence of the new escape code parser being much larger
;   - Improved keyboard and serial handling allowing for 2400 baud.
;   - Optimizations for screen/ansi handling
;   - More improved character rendering (backtick and curly braces)
;   - Added extra shift codes to keyboard
;      Shift-@ = ~    Shift-' = `   Shift-[ = {    Shift-] = }
;      Shift-^ (up arrow) = |
;   If connecting to a *nix shell, set the following environment variables:
;     TERM=ansi
;     COLUMNS=40
;     LINES=25
;     LANG=C
;   These should work well for most programs, PETTERM should support every escape sequence
;   used by the ansi TERMCAP/TERMINFO
;   Tested with: ls, vim, nano, elinks (web-browsing on the PET!), 
;     top (not recommended even at 2400 as it buffers quite a bit of text between keypress checks)
;     minicom (for nesting your serial terminals of course)
;     alpine (a bit cramped at 40 columns)
;     nethack (seems to work just fine)
;
; 0.6.0
; 
;   This version adds the option to Exit to BASIC and also SAVE/LOAD BASIC programs over serial.
;   by Adam Whitney (K0FFY) - 2022
;
;   - Added menu options and support for sending or receiving BASIC programs.
;
;     The SAVE BASIC PROGRAM option will send the current in-memory BASIC program over the 
;      serial connection with a header of the following bytes:
;         0x00 0x00 0x00 0x53 (S) 0x41 (A) 0x56 (V) 0x45 (E) 0x00
;      followed immediately by a program name entered in PETTERM terminated with a value of 0x00
; 
;      After the program name string will follow two bytes giving the starting address of the BASIC
;      program ($0401 on the Commodore PET), and then finally the remainder of the BASIC program
;      stored in the Commodore's memory.
;    
;     For example, let assume the following BASIC program is currenlty in memory:
;        10 PRINT"HI"
;
;     Let's also say the user enters a program name of "HELLO" when saving in PETTERM.
; 
;     The SAVE BASIC PROGRAM option will then send the following data over serial:
;
;        0x00 0x00 0x00 0x53 0x41 0x56 0x45 0x00
;        0x48 0x45 0x4c 0x4c 0x4f 0x00 0x01 0x04
;        0x0b 0x04 0x0a 0x00 0x99 0x22 0x48 0x49
;        0x22 0x00 0x00
;     
;     This is the "000SAVE0" header followed by the program name of "HELLO0". After that
;      is the entire contents of the BASIC program, including the first two bytes denoting the
;      starting address of $0401 (the start of BASIC on the PET), which would be the same bytes
;      saved if this program were written to tape or disk.
;
;     The LOAD BASIC PROGRAM option will wait to receive data over the serial connection,
;      and then write each byte received to the start of BASIC address ($0401 on the PET)
;      until all bytes have been received and stored according to the two bytes that 
;      specify the memory pointer to the final byte of the BASIC code.
;
;     For example, if the 10 PRINT"HI" program from above was loaded using this option,
;      then the following bytes would be written to the PET's memory starting at address
;      $0401:
;
;      Memory Address: 0401 0402 0403 0404 0405 0406 0407 0408 0409 040a 040b
;      Data:           0x0b 0x04 0x0a 0x00 0x99 0x22 0x48 0x49 0x22 0x00 0x00
;
;     The user can exit the LOAD BASIC PROGRAM option at any point by pressing the CLR/HOME
;      key.
;     
;     Note: The Makefile was modified to build versions of PETTERM that both include and
;      do not include these new options. The Makefile also now includes options to utilize
;      higher memory portions of 8K, 16K, and 32K PET. These high memory versions omit
;      the BASIC loader program, requiring the user to run the "SYS" command themselves.
;
;      Option MEM8K  : SYS 3400  : Max Size of BASIC Program is 2,375 bytes
;      Option MEM16K : SYS 8192  : Max Size of BASIC Program is 7,167 bytes
;      Option MEM32K : SYS 24576 : Max Size of BASIC Program is 23,551 bytes
;
;   - Included a POSIX C program and Makefile in the test folder than can be used for the
;     SAVE BASIC and LOAD BASIC options.
;   - Added an EXIT option to allow the user to exit PETTERM and return to BASIC, which was
;     needed to support the LOAD BASIC PROGRAM option.
;
;     To support the EXIT option to return to BASIC, the memory locate of this program was
;     shifted to starting address of $0D48 (SYS 3200). The program extends from this address
;     to memory below the beginning of top of 8K memory at $2000, so this should function
;     correctly on 8k PETs.
;
;     The starting address of $0D48 also means that the current maximum size of the BASIC
;     programs supported is 2,375 bytes unless you use one of the "higher memory" versions
;     (see more details regarding Makefile above).
;   
;
; Written for the DASM assembler
;----------------------------------------------------------------------- 
	PROCESSOR 6502

;-----------------------------------------------------------------------
; Zero page definitions
; Originally in zero page memory, these variables have been moved to
; program memory. For any needed to be zero page for indirect, indexed
; addressing mode, we have now located these explictly in constants.s.

;-----------------------------------------------------------------------
	SEG.U	ZPAGE
	RORG	MYRORG		; RORG location for this memory segment
	
	INCLUDE	"zpage.s"
	
	REND
;-----------------------------------------------------------------------

; RX Ring buffer takes up whole of page 3 ($3xx)

;-----------------------------------------------------------------------
; GLOBAL Defines
;-----------------------------------------------------------------------
	INCLUDE "constants.s"


;-----------------------------------------------------------------------
; Start of loaded data
	SEG	CODE

    IFNCONST HIMEM
	ORG	SOB

;-----------------------------------------------------------------------
; Simple Basic 'Loader' - BASIC Statement to jump into our program
BLDR
	DC.W BLDR_ENDL	; LINK (To end of program)
	DC.W 10		; Line Number = 10
	DC.B $9E	; SYS
	; Decimal Address in ASCII $30 is 0 $31 is 1, etc
	DC.B (MYORG/10000)%10 + '0
	DC.B (MYORG/ 1000)%10 + '0
	DC.B (MYORG/  100)%10 + '0
	DC.B (MYORG/   10)%10 + '0
	DC.B (MYORG/    1)%10 + '0

	DC.B $0		; Line End
BLDR_ENDL
	DC.W $0		; LINK (End of program)
;-----------------------------------------------------------------------
    ENDIF

	ORG MYORG
;-----------------------------------------------------------------------
; Initialization
INIT	SUBROUTINE
	SEI			; Disable interrupts
	
	; Clear ZP?

	; We do plan to return to BASIC. Save the stack pointer.
	TSX
	STX	SP

	; We never plan to return to BASIC, steal everything!
	;LDX	#$FF		; Set start of stack
	;TXS			; Set stack pointer to top of stack
	
	; Determine which version of BASIC we have for a KERNAL
	; TODO: What's a reliable way? Maybe probe for a byte that's
	; different in each version. Find such a byte using emulators.
	
	
	; Initial baud rate	
	LDA	#$03		; 1200 baud
	STA	BAUD

        ; Disable all PIA interrupt sources
        LDA     PIA1_CRB
        ;STA     PIA1B           ; Save PIA1_CRB init value
        AND     #$FE            ; Disable interrupts (60hz retrace int?)
        STA     PIA1_CRB        
        LDA     PIA1_CRA
        ;STA     PIA1A           ; Save PIA1_CRA init value
        AND     #$FE
        STA     PIA1_CRA        ; Disable interrupts
        
        LDA     PIA2_CRB
        ;STA     PIA2B           ; Save PIA2_CRB init value
        AND     #$FE            ; Disable interrupts (60hz retrace int?)
        STA     PIA2_CRB        
        LDA     PIA2_CRA
        ;STA     PIA2A           ; Save PIA1_CRAB init value
        AND     #$FE
        STA     PIA2_CRA        ; Disable interrupts

        ; Save IRQ init value
        LDA     BAS1_VECT_IRQ
        STA     IRQB1LO         ; Save IRQ lo byte for BASIC 1
        LDA     BAS1_VECT_IRQ+1
        STA     IRQB1HI         ; Save IRQ hi byte for BASIC 1
        LDA     BAS4_VECT_IRQ
        STA     IRQB4LO         ; Save IRQ lo byte for BASIC 2/4
        LDA     BAS4_VECT_IRQ+1
        STA     IRQB4HI         ; Save IRQ hi byte for BASIC 2/4

        ; Save PIA1 PA/PB init values
        ;LDA     PIA1_PA
        ;STA     PIA1PA
        ;LDA     PIA1_PB
        ;STA     PIA1PB
	
	; Install IRQ
	LDA	#<IRQHDLR
	LDX	#>IRQHDLR
	STA	BAS1_VECT_IRQ	; Modify based on BASIC version
	STX	BAS1_VECT_IRQ+1
	STA	BAS4_VECT_IRQ	; Let's see if we can get away with modifying
	STX	BAS4_VECT_IRQ+1	; both versions vectors
	
	
	JSR	INITVIA
	
	
	; Initialize state
	LDA	#STIDLE		; Output 1 idle tone first
	STA	TXSTATE
	
	LDA	#1
	JSR	SETTX		; Make sure we're outputting idle tone
	
	LDA	#0
	STA	SERCNT
	STA	TXTGT		; Fire Immediatly
	STA	RXBUFW
	STA	RXBUFR
	STA	TXNEW		; No bytes ready
	STA	ROW
	STA	COL
	STA	KFAST
	STA	DLYSCROLL
	STA	ANSISTKI
	STA	ANSIIN
	STA	ANSIINOS
	STA	ATTR
	STA	EXITFLG

	; Set-up screen
	STA	CURLOC
	LDA	#$80
	STA	CURLOC+1	;$8000 = top left of screen
	JSR	CLRSCR
	

	LDA	#$40
	STA	MODE1		; Default to mixed case, non-inverted

	LDA	#0
	STA	VIA_TIM1L
	STA	VIA_TIM1H	; Need to clear high before writing latch
				; Otherwise it seems to fail half the tile?

	; Set up the VIA timer based on the baud rate
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

    IFCONST BASIC
	; Clear BASIC I/O flags
	LDA	#0
	STA	LOADB
	LDA	#0
	STA	SAVEB
    ENDIF
	
	JSR	SERINIT
	
	; Fall into START
;-----------------------------------------------------------------------
; Start of program (after INIT called)
START	SUBROUTINE
	CLI	; Enable interrupts

.remenu
	JSR	DOMENU
	
	JSR	SERINIT		; Re-initialize serial based on menu choices
	
	JSR	CASEINIT	; Setup for Mixed or UPPER case 
	
	; Reset ANSI parser
	LDA	#0
	STA	ANSISTKI
	STA	ANSIIN
	STA	ANSIINOS
	STA	DLYSCROLL
	
.go	JSR	CLRSCR
	LDX	#0
	LDY	#0
	JSR	GOTOXY
    IFCONST BASIC
	JSR	SAVELOAD	; Save or Load BASIC if requested
    ENDIF
.loop
	LDX	RXBUFR
	CPX	RXBUFW
	BEQ	.norx		; Loop till we get a character in

	; Remove cursor from old position before handling
	LDY	#0
	LDA	(CURLOC),Y
	;AND	#$7F
	EOR	#$80
	STA	(CURLOC),Y

	; Handle new byte
	LDA	RXBUF,X		; New character
	TAX			; Save
	INC	RXBUFR		; Acknowledge byte by incrementing 
	TXA
	JSR	ANSICH

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
	JSR	ANSICH		; Local-echoback for now
	PLA
	PHA
	CMP	#$0D		; \r
	BNE	.noechonl
	LDA	#$0A;
	JSR	ANSICH
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

	LDA 	#1
	CMP	EXITFLG
	BEQ	.done
.nokey
	JMP	.loop

.termkey
	CMP	#$F0		; $F0 - Menu key
	BNE	.tkmore
	JMP	.remenu
.tkmore	
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
.done	
	; We are about to exit to BASIC.
	
	; We have to make sure the system I/O controllers, vectors,
	; and the BASIC enviroment is reset to a functional state.

	; Reset the IRQ Vector

	JSR 	RESETIRQ

	; RESETVIA must be called first for initial VIA chip reset,
	; and then KRESETIO resets both the PIA and VIA to an
	; interactive state for the BASIC environment.

	SEI
	JSR	RESETVIA
	JSR	KRESETIO
	CLI

	; Next, move the Start of Variables, Start of Arrays, and
	; End of Arrays Location to the end of any BASIC programs
	; now in memory. This is essential if we loaded a new
	; BASIC program via PETTERM.

	; Check SOB pointer location to determine if we are running 
	; BASIC1 or BASIC2/4. If you don't find $0401 in the
	; BASIC 1 SOB Pointer Location, then assume BASIC 2/4.

	LDX	$007A
	CPX	#$01
	BNE	.done4
	LDX	$007B
	CPX	#$04
	BNE	.done4

	; We found $0401 in $7A/$7B, so assume we're running BASIC 1.

	; Load the current End of Basic Location
	LDX	BAS1_EOB	; Load End of Basic Location

	; Set the new SOV, SOA, and EOA values.
	STX	BAS1_SOV	; Set New Start of Variables
	STX	BAS1_SOA	; Set New Start of Arrays
	STX	BAS1_EOA	; Set New End of Arrays

.done4
	; As most will be running BASIC 2/4 and also the SOV, SOA,
	; and EOA pointers for BASIC 2/4 are within the Input Buffer
	; memory for BASIC 1, it is safest to go ahead and set
	; the new SOV, SOA, and EOA values there regardless of detected
	; BASIC version.

        ; Load the current End of Basic Location from the BASIC4 address.
        LDX     BAS4_EOB        ; Load End of Basic Location

        ; Set the new SOV, SOA, and EOA values.
        STX     BAS4_SOV        ; Set New Start of Variables
        STX     BAS4_SOA        ; Set New Start of Arrays
        STX     BAS4_EOA        ; Set New End of Arrays

	; Restore the Stack Pointer to the saved value.

        LDX	SP		; Retrieve initial start of stack
        TXS			; Set stack pointer to top of stack

	RTS

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

    IFCONST BASIC
;-----------------------------------------------------------------------
;-- BASIC load and save code -------------------------------------------
;-----------------------------------------------------------------------
        INCLUDE "basic.s"
    ENDIF
	

;-----------------------------------------------------------------------
; Static data
;
; Baud rate timer values, 1x baud rate
;		 110  300  600 1200 2400 4800 9600
BAUDTBLL 
	DC.B	$83, $05, $83, $41, $A1, $D0, $68
BAUDTBLH	
	DC.B	$23, $0D, $06, $03, $01, $00, $00

; Poll interval mask for ~60Hz keyboard polling based on the baud timer
	; 	110  300  600 1200 2400 4800  9600 (Baud)
POLLINT 
	DC.B	  2,   5,  10,  20,  40,  80, 160
;Poll freq Hz  	 55   60   60   60   60   60   60
;If POLLINT value is below 12 we need to use the all at once keyboard scan

; 1.5x buad timer for after VIA_IFRstart bit
B15TBLL
	DC.B	$44, $87, $C4, $E1, $71, $38, $9C
B15TBLH
	DC.B	$35, $13, $09, $04, $02, $01, $00

; Timer 2 isn't freerunning so we have to subtract the cycles till we reset
; it from the rate (- $5D)
TIM2BAUDL
	DC.B	$26, $A8, $26, $e4, $44, $73, $0B
TIM2BAUDH
	DC.B	$23, $0C, $06, $02, $01, $00, $00
;-----------------------------------------------------------------------




;-----------------------------------------------------------------------
; Interrupt handler
IRQHDLR	SUBROUTINE ; 36 cycles till we hit here from IRQ firing
	; 3 possible interrupt sources: (order of priority)
	;  TIM2 - RX timer (after start bit)
	;  CA1 falling - Start bit of data to recieve
	;  TIM1 - TX timer/kbd poll

	LDA	#$20		;2; TIMER2 flag
	BIT	VIA_IFR		;4;
	BNE	.tim2		;3; CA1 triggered $02
	BVS	.tim1		; Timer 1       $40
	JMP	.ca1
	;--------------------------------
	; Timer 2  $20
.tim2
	LDA	VIA_TIM2L	;4; Acknowledge
	LDA	VIA_PORTAH	;4; Clear any pending CA1 interrupts
	; Read in bit from serial port, build up byte
	; If 8 recieved, indicate byte, and disable our
	; interrupt
	LDA	VIA_PORTA	;4;
	AND	#$01		;2; Only read the Rx pin
	ROR			;2; Move into carry
	ROR	RXCUR		;5

	DEC	RXBIT		;5
	BNE	.tim2retrig	;3

	; We've receieved a byte, signal to program
	; disable our interrupt
	
	LDX	RXBUFW
	LDA	RXCUR
	STA	RXBUF,X
	
	INC	RXBUFW

	
	LDA	#$22		; Disable timer 2 interrupt and CA1
	STA	VIA_IER
	LDA	#$82		; Enable CA1 interrupt
	STA	VIA_IER
	; Clear any CA1 interrupt soruce
	LDA	VIA_PORTAH
	JMP	.exit

.tim2retrig
	LDX	BAUD		;3
	LDA	TIM2BAUDL,X	;4
	STA	VIA_TIM2L	;4
	LDA	TIM2BAUDH,X	;4
	STA	VIA_TIM2H	;4<--From start of IRQ to here is 93 ($5D) cycles!, need to subtract from BAUDTBL
	JMP	.exit		; to give us TIM2BAUD
	;--------------------------------
.tim1
	LDA	VIA_TIM1L
	; Transmit next bit if sending
	JSR	SERTX		; Use old routine for now


	LDA	KFAST		; Which keyboard scan routine
	BNE	.fastkbd

	;"Slow" keyboard polling (all rows at once)
	DEC	POLLTGT		; Check if we're due to poll
	BNE	.exit
	LDA	POLLRES		; Reset keyboard poll count
	STA	POLLTGT

	JSR	KBDPOLL		; Do keyboard polling
	JMP	.keyend
	
.fastkbd
	LDA	POLLTGT
	BEQ	.final		; 0 
	CMP	#$11
	BEQ	.first		; 12
	; One of the 10 scanning rows ;1-11
	JSR	KBDROWPOLL
	DEC	POLLTGT
	JMP	.exit
.first	
	JSR	KBDROWSETUP
	DEC	POLLTGT
	JMP	.exit
.final
	LDA	POLLRES
	STA	POLLTGT		; Reset polling counter
	JSR	KBDROWCONV
.keyend
	CMP	KBDBYTE		; Check if same byte as before
	STA	KBDBYTE
	BEQ	.exit		; Don't signal the key for a repeat
	LDA	KBDBYTE		
	BEQ	.exit		; Don't signal for no key pressed
	LDA	#$FF
	STA	KBDNEW		; Signal a pressed key
	BNE	.exit		; Always
	;--------------------------------	
.ca1
	LDA	VIA_PORTAH	; Acknowledge int
	; We hit a start bit, set up TIM2
	; We want the first event to be in 1.5 periods
	; And enable tim2 interrupt
	LDX	BAUD
	LDA	BAUDTBLL,X
	STA	VIA_TIM2L
	LDA	BAUDTBLH,X
	STA	VIA_TIM2H	; Timer 2 is off


	LDA	#$02		; Disable CA1 interrupt
	STA	VIA_IER
	LDA	#$A0		; Enable Timer 2 interrupt
	STA	VIA_IER

	LDA	#8
	STA	RXBIT

	;--------------------------------
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
	LDA	#$40		; Shift register disabled, no latching, T1 free-run, T2 one-shot
	STA	VIA_ACR		

	LDA	#$EC		; Tx as output high, uppercase+graphics ($EE for lower)
				; CA1 trigger on falling edge
	STA	VIA_PCR		
	; Set VIA interrupts so that our timer is the only interrupt source
	LDA	#$7F		; Clear all interrupt flags
	STA	VIA_IER
	LDA	#$C2		; Enable Timer 1 interrupt and CA1 interrupt
	STA	VIA_IER
	RTS

;----------------------------------------------------------------------------
; Reset IRQ vector
RESETIRQ SUBROUTINE

        ; Disable interrupts
        SEI

	; Check BASIC version.
        LDX     $007A
        CPX     #$01
        BNE     .irqbas4
        LDX     $007B
        CPX     #$04
        BNE     .irqbas4

	; Found $0401 in Start of Basic Location for BASIC 1 

        ; Restore IRQ vector init values
        LDA     IRQB1LO
        STA     BAS1_VECT_IRQ
        LDA     IRQB1HI
        STA     BAS1_VECT_IRQ+1
	JMP	.irqdone

.irqbas4

	; Otherwise, this must be running BASIC 2/4

        ; Restore IRQ vector init values
        LDA     IRQB4LO
        STA     BAS4_VECT_IRQ
        LDA     IRQB4HI
        STA     BAS4_VECT_IRQ+1
.irqdone
        ; Enable interrupts
        CLI

        RTS

;-----------------------------------------------------------------------
; Reset VIA and userport
; http://www.zimmers.net/cbmpics/cbm/PETx/petmem.txt
RESETVIA SUBROUTINE
        LDA     #$00
        STA     VIA_DDRA
        STA     VIA_IFR
        LDA     #$1E
        STA     VIA_TIM1L
        LDA     #$FF
        STA     VIA_PORTAH
        STA     VIA_PORTA
        STA     VIA_TIM1HL
        LDA     #$0C
        STA     VIA_PCR
        RTS

;-----------------------------------------------------------------------
; Reset VIA and PIA according to how the PET kernel does it.
; http://www.zimmers.net/anonftp/pub/cbm/src/pet/pet_rom4_disassembly.txt
KRESETIO SUBROUTINE
.iE60F	LDA	#$7F
	STA	VIA_IER
 	LDX #$6D
.iE61C	DEX
 	BPL .iE61C
	LDA	#$0F
	STA	PIA1_PA		; PIA 1
	ASL
	STA	VIA_PORTB	; VIA
	STA	VIA_DDRB
	STX	PIA2_PB
	STX	VIA_TIM1H
	LDA	#$3D
	STA	PIA1_CRB
	BIT	PIA1_PB
	LDA	#$3C
	STA	PIA2_CRA
	STA	PIA2_CRB
	STA	PIA1_CRA
	STX	PIA2_PB
	LDA	#$0E
	STA	VIA_IER
	LDA	#$10
	STA	VIA_ACR
	LDA	#$0F
	STA	VIA_SR
	LDX	#$07
.iE6B7	LDA	$E74D,X	; Timer 2 LO Values			DATA
	STA	VIA_TIM2L
.sE6D0	RTS


;----------------------------------------------------------------------------

	ECHO "Program size in HEX: ", .-$401
	ECHO "Size from start of ram HEX: ", .
