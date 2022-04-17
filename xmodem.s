;#######################################################################
; Xmodem Routines
;#######################################################################

;-----------------------------------------------------------------------
; Receive a byte over the serial connection.
RXBYTE SUBROUTINE
.norx
	LDX	RXBUFR
	CPX	RXBUFW
	BEQ	.norx		; loop till we get a character in
	; Handle new byte
	LDA	RXBUF,X		; new character
	INC	RXBUFR		; acknowledge byte by incrementing
	RTS

;-----------------------------------------------------------------------
; Flush the receive buffer
RXFLUSH SUBROUTINE
.rxflush
	LDX	RXBUFR
	CPX	RXBUFW
	BEQ	.rxempty	; loop till flushed
	INC	RXBUFR		; acknowledge byte by incrementing
	JMP	.rxflush	
.rxempty
	RTS

;-----------------------------------------------------------------------
; Initialize an XMODEM transfer.
XINIT SUBROUTINE
	LDA	#0
	STA	XFINAL	; XMODEM final byte of transmission flag.
	LDA	#1
	STA	XPACK	; XMODEM packet counter

	LDX	#$02	; start data at buffer index 2
	STX	XBUFIX	; save XBUF index
.xinit
	JSR	RXBYTE
	CMP	#"C"
	BNE	.xesc
	; received the "C" byte to begin the transfer
	RTS
.xesc
	CMP	#$1B		; ESC character
	BNE	.xinit
	JMP	XERROR

;-----------------------------------------------------------------------
; Send accumulator byte via XMODEM.
XSEND SUBROUTINE
	LDX	XBUFIX		; Retrieve XBUF offset
	STA	XBUF,X		; send BASIC program byte to buffer

	LDA	XFINAL
	CMP	#1
	BNE	.xsendmore
.xsendfinal	
	INX
	CPX	#$82		; buffer contain 128 bytes?
	BEQ	.xmit		; yes, then fetch CRC
	LDA	#0
	STA	XBUF,X		; fill rest of buffer with 0
	JMP	.xsendfinal	; loop until buffer filled
.xsendmore
	INX
	CPX	#$82		; buffer contain 128 bytes?
	BEQ	.xmit		; yes, then transmit packet
	STX	XBUFIX		; Save new XBUF offset
	RTS
.xmit
	JMP	XMIT


;-----------------------------------------------------------------------
; Start a new packet.
XNEW SUBROUTINE
	LDY	#$AE
	LDX	#0
	STX	XERRCNT		; XMODEM error count

	LDA	XPACK
	STA	XBUF		; store packet counter in first byte of buffer

	EOR	#$FF
	STA	XBUF+1		; store packet count checksum in second byte

	RTS

;-----------------------------------------------------------------------
; Transmit XMODEM packet.
XMIT SUBROUTINE

	JSR	XNEW

	LDA	#0
	STA	XBUFIX		; reset the buffer index to 0
	STA	XCRC
	STA	XCRC+1
	LDY	#2
.crcbuf
	LDA	XBUF,Y
	JSR	FINDXCRC
	INY
	CPY	#$82
	BNE	.crcbuf
	LDA	XCRC+1
	STA	XBUF,Y
	INY
	LDA	XCRC
	STA	XBUF,Y
.xsendsoh
	LDA	#$01		; SOH character
	JSR	SENDCH
;	JSR	HEXOUT

	LDX	#0
	STX	XBUFIX
.xsend
	LDA	XBUF,X
	JSR	SENDCH
;	JSR	HEXOUT

	INC	XBUFIX
	LDX	XBUFIX	
	CPX	#$84		; sent final byte?
	BNE	.xsend

	JSR	RXBYTE
	CMP	#$06		; ACK character
	BNE	.xnak

	; packet was sent successfully!

	INC	XPACK		; increment packet counter
	LDX	#$02		; start data at buffer index 2 for next packet
	STX	XBUFIX		; save XBUF index

	LDA	XFINAL
	CMP	#1
	BNE	.xmitexit
	JMP	XFINISH
.xmitexit
	RTS				; return after transmitting
.xnak
	CMP	#$15		; NAK character
	BEQ	.xerror
	CMP	#$1B		; ESC character
	BEQ	.xabort
.xerror
	INC	XERRCNT
	LDA	XERRCNT
	CMP	#$0A		; 10 errors?
	BNE	.xsendsoh	; if no, resend packet
.xabort
	JMP	XERROR

;-----------------------------------------------------------------------
; Finish an XMODEM transfer by sending final block and the
; End of Transmission sequence.
XFINISH SUBROUTINE
	LDX	XBUFIX
	CPX	#0
	BEQ	.xfinnak
.xfinish
	CPX	#$82            ; buffer contain 128 bytes?
	BNE	.xfinfill
	JMP	XMIT            ; buffer contains 128 bytes, so transmit
.xfinfill
	LDA	#0
	STA	XBUF,X          ; fill rest of buffer with 0
	INX
	JMP	.xfinish
.xfinnak
	LDA	#$04		; EOT charachter
	JSR	SENDCH

	JSR	RXBYTE
	CMP	#$06		; ACK character
	BNE	.xfinnak
	JSR	RXFLUSH
	RTS

;-----------------------------------------------------------------------
; Use the CRC lookup tables to determine the CRC.
FINDXCRC SUBROUTINE
	EOR	XCRC+1
	TAX
	LDA	XCRC
	EOR	XCRCHI,X
	STA	XCRC+1
	LDA	XCRCLO,X
	STA	XCRC
	RTS

;-----------------------------------------------------------------------
; Flush RX buffer, print error, and return.
XERROR SUBROUTINE
	JSR	RXFLUSH
	LDA	#<X_ERROR
	LDY	#>X_ERROR
	JSR	PRINTSTR
	RTS

;-----------------------------------------------------------------------
; XMODEM Control Characters
;SOH	EQU	#$01
;EOT	EQU	#$04
;ACK	EQU	#$06
;NAK	EQU	#$15
;CAN	EQU	#$18
;CR	EQU	#$0d
;LF	EQU	#$0a
;ESC	EQU	#$1b

;-----------------------------------------------------------------------
; CRC lookup table for low byte
XCRCLO
	DC.B	$00,$21,$42,$63,$84,$A5,$C6,$E7,$08,$29,$4A,$6B,$8C,$AD,$CE,$EF
	DC.B	$31,$10,$73,$52,$B5,$94,$F7,$D6,$39,$18,$7B,$5A,$BD,$9C,$FF,$DE
	DC.B	$62,$43,$20,$01,$E6,$C7,$A4,$85,$6A,$4B,$28,$09,$EE,$CF,$AC,$8D
	DC.B	$53,$72,$11,$30,$D7,$F6,$95,$B4,$5B,$7A,$19,$38,$DF,$FE,$9D,$BC
	DC.B	$C4,$E5,$86,$A7,$40,$61,$02,$23,$CC,$ED,$8E,$AF,$48,$69,$0A,$2B
	DC.B	$F5,$D4,$B7,$96,$71,$50,$33,$12,$FD,$DC,$BF,$9E,$79,$58,$3B,$1A
	DC.B	$A6,$87,$E4,$C5,$22,$03,$60,$41,$AE,$8F,$EC,$CD,$2A,$0B,$68,$49
	DC.B	$97,$B6,$D5,$F4,$13,$32,$51,$70,$9F,$BE,$DD,$FC,$1B,$3A,$59,$78
	DC.B	$88,$A9,$CA,$EB,$0C,$2D,$4E,$6F,$80,$A1,$C2,$E3,$04,$25,$46,$67
	DC.B	$B9,$98,$FB,$DA,$3D,$1C,$7F,$5E,$B1,$90,$F3,$D2,$35,$14,$77,$56
	DC.B	$EA,$CB,$A8,$89,$6E,$4F,$2C,$0D,$E2,$C3,$A0,$81,$66,$47,$24,$05
	DC.B	$DB,$FA,$99,$B8,$5F,$7E,$1D,$3C,$D3,$F2,$91,$B0,$57,$76,$15,$34
	DC.B	$4C,$6D,$0E,$2F,$C8,$E9,$8A,$AB,$44,$65,$06,$27,$C0,$E1,$82,$A3
	DC.B	$7D,$5C,$3F,$1E,$F9,$D8,$BB,$9A,$75,$54,$37,$16,$F1,$D0,$B3,$92
	DC.B	$2E,$0F,$6C,$4D,$AA,$8B,$E8,$C9,$26,$07,$64,$45,$A2,$83,$E0,$C1
	DC.B	$1F,$3E,$5D,$7C,$9B,$BA,$D9,$F8,$17,$36,$55,$74,$93,$B2,$D1,$F0 

;-----------------------------------------------------------------------
; CRC lookup table for high byte
XCRCHI
	DC.B	$00,$10,$20,$30,$40,$50,$60,$70,$81,$91,$A1,$B1,$C1,$D1,$E1,$F1
	DC.B	$12,$02,$32,$22,$52,$42,$72,$62,$93,$83,$B3,$A3,$D3,$C3,$F3,$E3
	DC.B	$24,$34,$04,$14,$64,$74,$44,$54,$A5,$B5,$85,$95,$E5,$F5,$C5,$D5
	DC.B	$36,$26,$16,$06,$76,$66,$56,$46,$B7,$A7,$97,$87,$F7,$E7,$D7,$C7
	DC.B	$48,$58,$68,$78,$08,$18,$28,$38,$C9,$D9,$E9,$F9,$89,$99,$A9,$B9
	DC.B	$5A,$4A,$7A,$6A,$1A,$0A,$3A,$2A,$DB,$CB,$FB,$EB,$9B,$8B,$BB,$AB
	DC.B	$6C,$7C,$4C,$5C,$2C,$3C,$0C,$1C,$ED,$FD,$CD,$DD,$AD,$BD,$8D,$9D
	DC.B	$7E,$6E,$5E,$4E,$3E,$2E,$1E,$0E,$FF,$EF,$DF,$CF,$BF,$AF,$9F,$8F
	DC.B	$91,$81,$B1,$A1,$D1,$C1,$F1,$E1,$10,$00,$30,$20,$50,$40,$70,$60
	DC.B	$83,$93,$A3,$B3,$C3,$D3,$E3,$F3,$02,$12,$22,$32,$42,$52,$62,$72
	DC.B	$B5,$A5,$95,$85,$F5,$E5,$D5,$C5,$34,$24,$14,$04,$74,$64,$54,$44
	DC.B	$A7,$B7,$87,$97,$E7,$F7,$C7,$D7,$26,$36,$06,$16,$66,$76,$46,$56
	DC.B	$D9,$C9,$F9,$E9,$99,$89,$B9,$A9,$58,$48,$78,$68,$18,$08,$38,$28
	DC.B	$CB,$DB,$EB,$FB,$8B,$9B,$AB,$BB,$4A,$5A,$6A,$7A,$0A,$1A,$2A,$3A
	DC.B	$FD,$ED,$DD,$CD,$BD,$AD,$9D,$8D,$7C,$6C,$5C,$4C,$3C,$2C,$1C,$0C
	DC.B	$EF,$FF,$CF,$DF,$AF,$BF,$8F,$9F,$6E,$7E,$4E,$5E,$2E,$3E,$0E,$1E

X_ERROR
	DC.B    "XMODEM ERROR!",0
