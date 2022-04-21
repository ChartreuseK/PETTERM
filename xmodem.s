;#######################################################################
; Xmodem Routines
;#######################################################################

;-----------------------------------------------------------------------
; Receive a byte over the serial connection.
RXBYTE SUBROUTINE
.norx
	LDA	#0		; Return 0 if no byte available
	LDX	RXBUFR
	CPX	RXBUFW		; Data available?
	BEQ	.norx		; Z will be set here to 0 so we can test
	; Handle new byte
	INC	RXBUFR		; acknowledge byte by incrementing
	LDA	RXBUF,X		; new character (sets Z if 0, clears otherwise)
	RTS

;-----------------------------------------------------------------------
; Flush the receive buffer
RXFLUSH SUBROUTINE
	LDX	RXBUFW		; Reset read point to write pointer to clear
	STX	RXBUFR		; All waiting bytes
	RTS

;-----------------------------------------------------------------------
; Initialize an XMODEM receive transfer.
XINITRX SUBROUTINE
	LDA	#1
	STA	XBLK		; reset block number to first block
	LDA	#0
	STA	XFINAL		; reset XMODEM final byte of transmission flag.
	STA	XABRT		; reset the abort flag
	LDA	#NAK		; Request transfer with NAK
	JSR	SENDCH
	RTS

;-----------------------------------------------------------------------
; Receive a block via XMODEM.
XRECV SUBROUTINE
.xrxstart
	JSR	RXBYTE
	
	CMP	#ESC		; ESC character
	BNE	.xrx
	LDA	#1
	STA	XABRT		; set abort flag
	LDA	#"X"
	JMP	XERROR
.xrx
	CMP	#SOH		; SOH character
	BEQ	.xrxdata0
	CMP	#EOT		; EOT character
	BNE	.xrxretry
	; EOT recieved (we're done)
	LDA	#1
	STA	XFINAL
	JSR	RXFLUSH		; flush RX buffer
	JMP	XACK		; send ACK and return
.xrxretry
	JSR	RXFLUSH
	LDA	#NAK		; NAK character
	JSR	SENDCH
	; After sending NAK, check for keypress on terminal
.rxkey
	LDA	KBDNEW
	BEQ	.norxkey
	LDA	#$0
	STA	KBDNEW
	LDA	KBDBYTE
	BMI	.rxtrmkey	; Key's above $80 are special keys for the terminal
.rxtrmkey
	CMP	#$F0		; $F0 - Menu key
	BEQ	.rxmenu
.norxkey
	JMP	.xrxstart
.xrxdata0
	LDY	#0
.xrxdata1
	JSR	RXBYTE
	STA	XBUF,Y
	INY
	CPY	#XMDM_PKTLEN	; received entire block of 132 bytes?
	BNE	.xrxdata1
	; we have received the full block into XBUF
	LDY	#0
	LDA	XBUF,Y		; get block number
	CMP	XBLK
	BEQ	.xrxblockchksm
	LDA	#"N"
	JMP	XERROR
.xrxblockchksm
	EOR	#$FF
	INY
	CMP	XBUF,Y		; compare block number checksum
	BEQ	.xrxblockdata0
	LDA	#"K"
	JMP	XERROR
.xrxblockdata0
	LDY	#2
	LDA	#0
.xrxblockdata1
	CLC
	ADC	XBUF,Y
	INY
	CPY	#$82		; 128 bytes of data
	BNE	.xrxblockdata1
	; we have calculated the checksum
	CMP	XBUF,Y		; Compare with sent checksum byte
	BNE	.xrxretry
	; At this point, we have a good block of data in XBLK	
	JMP	XACK
.rxmenu
	LDX	#1
	STX	XABRT
	RTS

;-----------------------------------------------------------------------
; Acknowledge receipt of XMODEM block.
XACK SUBROUTINE
	INC	XBLK		; increment block counter
	LDA	#$06		; ACK character
	JSR	SENDCH		; send ACK
	RTS

;-----------------------------------------------------------------------
; Initialize an XMODEM send transfer.
XINITTX SUBROUTINE
	LDA	#0
	STA	XFINAL		; reset XMODEM final byte of transmission flag.
	LDA	#1
	STA	XBLK		; reset block number to first block

	LDX	#$02		; start data at buffer index 2
	STX	XBUFIX		; save XBUF index
.xinittx
	JSR	RXBYTE
	CMP	#NAK		; Nak begins transfer
	BNE	.xesctx
	; received the NAK byte to begin the transfer
	RTS
.xesctx
	CMP	#ESC		; ESC character
	BNE	.xinittx
	LDA	#"X"
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
	BEQ	.xmit		; yes, then send
	LDA	#0		; If not,
	STA	XBUF,X		; fill rest of buffer with 0
	JMP	.xsendfinal	; loop until buffer filled
.xsendmore
	INX
	CPX	#$82		; buffer contain 128 bytes?
	BEQ	.xmit		; yes, then transmit block
	STX	XBUFIX		; Save new XBUF offset
	RTS
.xmit
	JMP	XMIT


;-----------------------------------------------------------------------
; Start a new block.
XNEWTX SUBROUTINE
	LDY	#$AE
	LDX	#0
	STX	XERRCNT		; XMODEM error count

	LDA	XBLK
	STA	XBUF		; store block number in first byte of buffer

	EOR	#$FF
	STA	XBUF+1		; store block number checksum in second byte

	RTS

;-----------------------------------------------------------------------
; Transmit XMODEM block.
XMIT SUBROUTINE

	JSR	XNEWTX

	LDA	#0
	STA	XBUFIX		; reset the buffer index to 0
	LDY	#2
.chksum
	CLC
	ADC	XBUF,Y
	INY
	CPY	#$82
	BNE	.chksum
	STA	XBUF,Y
.xsendsoh
	LDA	#SOH		; Start of block
	JSR	SENDCH
	LDX	#0
	STX	XBUFIX
.xsend
	LDA	XBUF,X
	JSR	SENDCH

	INC	XBUFIX
	LDX	XBUFIX	
	CPX	#XMDM_PKTLEN-1	; sent final byte?
	BNE	.xsend

	JSR	RXBYTE
	CMP	#ACK		; ACK character
	BNE	.xnak

	; Block was sent successfully!
	INC	XBLK		; increment block number
	LDX	#$02		; start data at buffer index 2 for next block
	STX	XBUFIX		; save XBUF index

	LDA	XFINAL
	CMP	#1
	BNE	.xmitexit
	JMP	XFINISH
.xmitexit
	RTS			; return after transmitting
.xnak
	CMP	#NAK		; NAK character
	BEQ	.xerror
	CMP	#ESC		; ESC character
	BEQ	.xabort
.xerror
	INC	XERRCNT
	LDA	XERRCNT
	CMP	#$0A		; 10 errors?
	BNE	.xsendsoh	; if no, resend block
.xabort
	LDA	#"X"
	JMP	XERROR

;-----------------------------------------------------------------------
; Finish an XMODEM transfer by sending final block and the
; End of Transmission sequence.
XFINISH SUBROUTINE
	LDX	XBUFIX
	CPX	#$02		; no data bytes?
	BEQ	.xtxeot
.xfinish
	CPX	#XMDM_PKTLEN-2	; buffer contain 128 bytes?
	BNE	.xfinfill
	JSR	XMIT		; transmit final block
	JMP	.xtxeot
.xfinfill
	LDA	#0
	STA	XBUF,X		; fill rest of buffer with 0
	INX
	JMP	.xfinish
.xtxeot
	INC	XFINAL
	LDX	XFINAL
	CPX	#3		; wait for ACK at most 3 times
	BEQ	.xtxdone
	LDA	#EOT		; EOT charachter
	JSR	SENDCH		; send EOT

	JSR	RXBYTE
	CMP	#ACK		; ACK character
	BNE	.xtxeot
.xtxdone
	JSR	RXFLUSH
	RTS

;-----------------------------------------------------------------------
; Flush RX buffer, print error, and return.
XERROR SUBROUTINE
	JSR	PRINTCH		; Print the error indicator character in A
	JSR	RXFLUSH
	LDA	#<S_XERROR
	LDY	#>S_XERROR
	JSR	PRINTSTR
	RTS
	
S_XERROR
	DC.B    " XMODEM ERROR!",0
