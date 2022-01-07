; zpage.s - Zero page location definitions
;-------------------------------------------------------------------------------
; This file is virtually positioned at address 0
; Nothing can be initialized here, just reserving addresses

SERCNT	DS.B	1		; Current sample number
TXTGT	DS.B	1		; Sample number of next send event
;RXTGT	DS.B	1		; Sample number of next recv event
TXCUR	DS.B	1		; Current byte being transmitted
RXCUR	DS.B	1		; Current byte being received
TXSTATE	DS.B	1		; Next Transmit state
TXBIT	DS.B	1		; Tx data bit #
RXBIT	DS.B	1		; Rx data bit #
;RXSAMP	DS.B	1		; Last sampled value

TXBYTE	DS.B	1		; Next byte to transmit
TXNEW	DS.B	1		; Indicates to start sending a byte

BAUD	DS.B	1		; Current baud rate, index into table

COL	DS.B	1		; Current cursor position		
ROW	DS.B	1

;CURLOC	DS.W	1		; Pointer to current screen location
TMP1	DS.B	1	
TMP2	DS.B	1

;TMPA	DS.W	1
;TMPA2	DS.W	1
CNT	DS.B	1	


POLLRES	DS.B	1		; KBD Polling interval for baud
POLLTGT	DS.B	1		; Polling interval counter

KBDBYTE	DS.B	1
KBDNEW	DS.B	1
KEY	DS.B	1
SHIFT	DS.B	1
CTRL	DS.B	1

KROW	DS.B 1			; Temp variables for split/fast key scanning
KROWFND	DS.B 1
KBITFND	DS.B 1


MODE1	DS.B	1		; 76543210
				; |||||
				; ||||| 
				; ||||+----
				; |||+-----
				; ||+------ 1 = Inverse case 0 = normal
				; |+------- 1 = Mixed case  0 = UPPER CASE
				; +-------- 1 = local echo
ATTR	DS.B	1		; 0 = normal, non-zero = reverse video
				
SC_UPPERMOD	DS.B	1	; Modifier for uppercase letters, added to ch
	; -$40 for UPPERONLY, +$20 for MIXED?
SC_LOWERMOD	DS.B	1	; Modifier for lowercase letters, added to ch
	; -$60 for UPPERONLY, -$60 for MIXED

KEYOFF	DS.B	1		; Keyboard matrix offset for shift
KBDTMP	DS.B 	1		; Keyboard scanning temp, to allow BIT instruction

ANSISTKL	EQU	16	; Allow up to 16 arguments (any more will just be dropped)
;ANSISTK	DS.B	ANSISTKL	; The commands we support mainly take 1 or 2, though SGR 
				; could have a long chain of attributes
ANSISTKI DS.B	1
ANSIIN	DS.B	1		; Are we inside an escape sequence
ANSIINOS DS.B	1		; Are we inside an os string (to ignore)

DLYSCROLL DS.B	1		; If non-zero, scrolling has been delayed and needs to happen on next character
				; (Used so that the cursor can sit on the last column of screen)

LASTCH	DS.B	1		; Last printable character drawn to screen

RXBUFW	DS.B	1		; Write pointer
RXBUFR	DS.B	1		; Read pointer
KFAST	DS.B	1		; 0 if slow/normal scanning, 1 for fast split scanning

LOADB	DS.B	1		; Load BASIC program flag
SAVEB	DS.B	1		; Save BASIC program flag
FNAMEW	DS.B	1		; File name write pointer
FNAMER	DS.B	1		; File name read pointer
FNAME	DS.B	1		; File name pointer
BASICLO	DS.B	1		; SOB lo byte
BASICHI	DS.B	1		; SOB hi byte
BLENLO	DS.B	1		; BASIC len lo byte
BLENHI	DS.B	1		; BASIC len hi byte
BTMP1	DS.B	1		; BASIC temp var
ENDLO	DS.B	1		; BASIC end lo byte
ENDHI	DS.B	1		; BASIC end hi byte
;PTRLO	DS.B	1		; BASIC ptr lo byte
;PTRHI	DS.B	1		; BASIC ptr hi byte
;IRQB1LO DS.B    1               ; Hardware interrupt lo byte for BASIC 1
;IRQB1HI DS.B    1               ; Hardware interrupt hi byte for BASIC 1
IRQB4LO DS.B    1               ; Hardware interrupt lo byte for BASIC 2/4
IRQB4HI	DS.B	1		; Hardware interrupt hi byte for BASIC 2/4
SP	DS.B	1
EXITFLG	DS.B	1		; Exit flag


; Make sure not to use $90-95 these are Vectors for BASIC 2+
	RORG	$90
	DS.B	1		; Reserve so we get a compiler error if we
				; allocate too much before
