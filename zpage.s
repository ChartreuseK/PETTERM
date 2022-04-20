; zpage.s - Zero page location definitions
;-------------------------------------------------------------------------------
; Don't use locations that would interfere with returning to BASIC and 
; require an re-initialization

; $4B to $50 is free
CURLOC		EQU	$4B	; 4B/4C 16-bit word
TMPA		EQU	$4D	; 4D/4E 16-bit word
TMPA2		EQU	$4F	; 4F/50 16-bit word
; $54 to $5D is free
PTRLO		EQU	$54	; 54 byte
PTRHI		EQU	$55	; 55 byte
				; 56-5D free remaining
; $B1 to $C3 is free if tape not being read or written
ANSISTK		EQU	$B1	; B1-C1, 16 bytes
				; C2/C3 free
