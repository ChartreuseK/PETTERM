; zpage.s - Zero page location definitions
;-------------------------------------------------------------------------------
; This file is virtually positioned at address 0
; Nothing can be initialized here, just reserving addresses

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
CTRL	DS.B	1

MODE1	DS.B	1		; 76543210
				; |||||
				; ||||| 
				; ||||+----
				; |||+-----
				; ||+------ 1 = Inverse case 0 = normal
				; |+------- 1 = Mixed case  0 = UPPER CASE
				; +-------- 1 = local echo
				
SC_UPPERMOD	DS.B	1	; Modifier for uppercase letters, added to ch
	; -$40 for UPPERONLY, +$20 for MIXED?
SC_LOWERMOD	DS.B	1	; Modifier for lowercase letters, added to ch
	; -$60 for UPPERONLY, -$60 for MIXED

KEYOFF	DS.B	1		; Keyboard matrix offset for shift
KBDTMP	DS.B 	1		; Keyboard scanning temp, to allow BIT instruction



; Make sure not to use $90-95 these are Vectors for BASIC 2+
	RORG	$90
	DS.B	1		; Reserve so we get a compiler error if we
				; allocate too much before

