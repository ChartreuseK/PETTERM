
HEXDIG SUBROUTINE
	CMP	#$0A		; alpha digit?
	BCC	.skip		; if no, then skip
	ADC	#$06		; add seven
.skip
	ADC	#$30		; convert to ascii
	JMP	$ffd2		; print it
	; no rts, proceed to HEXOUT

HEXOUT SUBROUTINE
	PHA			; save the byte
	LSR
	LSR			; extract 4...
	LSR			; ...high bits
	LSR
	JSR	HEXDIG
	PLA			; bring byte back
	AND	#$0f		; extract low four
	JMP	HEXDIG		; print ascii
