
;-----------------------------------------------------------------------
; Get a character from the serial port (blocking)
GETCH	SUBROUTINE	
	LDA	RXNEW
	BEQ	GETCH		; Loop till we get a character in
	LDA	#$0
	STA	RXNEW		; Acknowledge byte
	LDA	RXBYTE
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
	



;#######################################################################
; Device dependent routines
;-----------------------------------------------------------------------
; May need to be modified depending on hardware used
;#######################################################################
	
;
;               -          C                   A
;               E S   1100   0010   E S   1000  0010    
RXSAMPL	DC.B	1,0,1,1,0,0,0,0,1,0,1,0,1,0,0,0,0,0,1,0,$FF
TMP3	DC.B	0
	
; Mock up serial Rx for development with the emulator
MOCKRX  SUBROUTINE
	LDY	TMP3
	LDA	RXSAMPL,Y
	CMP	#$FF
	BNE	.no
	LDY	#$FF		; -1, inc'd to 0
.no	
	INY	
	STY	TMP3
	LDA	RXSAMPL,Y
	AND	#$01		; Only the low bit matters
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
