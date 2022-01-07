; Constants
;-------------------------------------------------------------------------------

STSTART	EQU	0		; Waiting/Sending for start bit
STRDY	EQU	1		; Ready to start sending
STBIT	EQU	2		; Sending/receiving data
STSTOP	EQU	3		; Sending/receiving stop bit
STIDLE	EQU	4

BITCNT	EQU	8		; 8-bit bytes to recieve
BITMSK	EQU	$FF		; No mask

    IFCONST COL80
SCRCOL	EQU	80		; Screen columns
COLMAX	EQU	80		; Max display columns    
    ELSE
SCRCOL	EQU	40		; Screen columns
COLMAX	EQU	40		; Max display columns
    ENDIF
SCRROW	EQU	25
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

; 6520 PIA
PIA1_PA	   EQU	$E810
PIA1_PB	   EQU	$E812
PIA1_CRA   EQU  $E811
PIA1_CRB   EQU  $E813

RXBUF	   EQU $0300		; Ring buffer of recieved chars

PIA2_PB    EQU	$E822
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

; Start of BASIC on PET/CBM computers
SOB		EQU	$0401

; Zero Page variables
; $4B to $50 is free
CURLOC		EQU	$4B	; 16-bit word
TMPA		EQU	$4D	; 16-bit word
TMPA2		EQU	$4F	; 16-bit word
; $54 to $5D is free
PTRLO		EQU	$54	; byte
PTRHI		EQU	$55	; byte
; $B1 to $C3 is free if tape not being read or written
ANSISTK		EQU	$B1	; 16 bytes


MODE1_ECHO	EQU	$80
MODE1_CASE	EQU	$40
MODE1_INV	EQU	$20

BAUD_MAX	EQU	4		; 2400 max (Any higher and the code gets bogged in the interrupts)

SCUM_UPPER	EQU	-$40
SCUM_MIXED	EQU	-$00
SCUM_MIXEDINV	EQU	-$40

SCLM_UPPER	EQU	-$60
SCLM_MIXED	EQU	-$60
SCLM_MIXEDINV	EQU	-$20
