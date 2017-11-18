
SERINIT	SUBROUTINE
	; Set-up timers based on BAUD
	LDX	BAUD
	LDA	BAUDTBLL,X	; Set interrupt timer 
	STA	VIA_TIM1LL
	LDA	BAUDTBLH,X
	STA	VIA_TIM1HL
	
	LDA	POLLINT,X	; Set keyboard polling interval based
	STA	POLLRES		; on current baud/timer rate
	STA	POLLTGT
	
	RTS

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
	BNE	.exit
	JSR	SERTX
.exit
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
	LDA	RXSAMP		; Make sure stop bit is 1
	BEQ	.nextstart	; Failed recv, unexpected value Ignore byte
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
	JMP	.next1		; Go to looking for next start bit immediatly
				; Since stop bit = idle tone, we don't need to 
				; wait
				; --Change this if we want to change 
				; --the stop bit length (3 = 1 bit, 6 = 2 bits)
	
		
.datab
	LDA	RXSAMP
	ROR	RXSAMP		; Rotate into carry
	ROR	RXCUR		; Shift bit into high bit
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
	LDA	#1
	JSR	SETTX		; Send stop bit
	LDA	#STRDY
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
	
; idle, A, idle
; (Mock Rx code
RXSAMPL	DC.B	1,0,1,1,0,0,0,0,1,0,1,0,1,0,0,0,0,0,1,0,$FF
TMP3	DC.B	0
	
	
MOCKRX  SUBROUTINE
	LDY	TMP3
	LDA	RXSAMPL,Y
	CMP	#$FF
	BNE	.no
	LDY	#$FF
	
	LDA	#$01
.no	
	INY	
	STY	TMP3
	LDA	RXSAMPL,Y
	AND	#$01		; Only read the Rx pin
	STA	RXSAMP
	RTS
;-----------------------------------------------------------------------
; Sample the Rx pin into RXSAMP
; 1 for high, 0 for low
; NOTE: If we want to support inverse serial do it in here, and SETTX
SAMPRX	SUBROUTINE
	LDA	VIA_PORTA
	AND	#$01		; Only read the Rx pin
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
