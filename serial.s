
;-----------------------------------------------------------------------
; Get a character from the serial port (blocking)
GETCH	SUBROUTINE
	LDX	RXBUFR
	CPX	RXBUFW
	BEQ	GETCH		; Loop till we get a character in
	LDA	RXBUF,X		; New character
	INC	RXBUFR		; Acknowledge byte by incrementing 
	RTS

	
;-----------------------------------------------------------------------
; Send a character to the serial port (blocking)
SENDCH	SUBROUTINE
	LDX	TXNEW
	BNE	SENDCH		; Loop till we can send a character
	STA	TXBYTE
	LDA	#$FF
	STA	TXNEW
	RTS

;-----------------------------------------------------------------------
; Initialize serial interrupt
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

	LDA	#0
	STA	RXBUFW
	STA	RXBUFR
	STA	KFAST

	; Below 1200 baud there's not enough serial events between
	; keyboard polls to use the split routines
	CPX	#3		; Use fast keyboard scanning above 600
	BCC	.slow
	LDA	#$FF		; Fast/split keyboard scanning
	STA	KFAST		
.slow
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
	RTS
.stop	; Send stop bit
	LDA	#1
	JSR	SETTX		; Send stop bit
	LDA	#STRDY
	STA	TXSTATE
	RTS
.datab	; Send data bit
	LDA	#0
	ROR	TXCUR		; Rotate current bit into carry
	ROL			; Place into A
	JSR	SETTX
	INC	TXBIT
	LDA	TXBIT
	CMP	#BITCNT
	BNE	.done		; If more bits to go
	LDA	#STSTOP
	STA	TXSTATE
	RTS
	
.start	; Send start bit
	LDA	#0	
	STA	TXBIT		; Reset bit count
	JSR	SETTX		; Send Start bit
	LDA	#STBIT
	STA	TXSTATE
	RTS
	
.ready
	LDA	#1
	JSR	SETTX		; Idle state
	
	LDA	TXNEW		; Check if we have a byte waiting to send
	BPL	.done		; If not check again next baud		
	LDA	TXBYTE
	STA	TXCUR		; Copy byte to read
	LDA	#0
	STA	TXNEW		; Reset new flag
	LDA	#STSTART	
	STA	TXSTATE
.done
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
