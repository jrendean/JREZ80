#INCLUDE	"constants.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  STRING ROUTINES  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; print_newline: prints a CR/LF pair to advance to the next line 
; affects: none
print_newline:	push	af						; save registers

				ld		a, CR					; print Carriage Return
				call	putc
				ld		a, LF					; print Line Feed
				call	putc
				
				pop		af						; restore registers
				ret
				
; print_string: prints a string which starts at adress HL and is terminated by EOS-character
; affects: none
print_string:	push	af
				push	hl
				
print_string_1:	LD		A,(HL)					; load next character
				CP		0						; is it en End Of String - character?
				jr		Z, print_string_2		; yes - return
				call 	putc					; no - print character
				INC		HL						; HL++
				jr		print_string_1			; do it again
				
print_string_2:	pop		hl
				pop		af
				ret


; get_nibble: gets a nibble from a correctly entered hexadecimal digit (blocks until one is recieved) 
; returns: A - nibble entered
get_nibble:
				call	getc					; get a character
				call	to_upper				; convert to upper case
				call	is_hex					; is character a hexadecimal?
				jr		nc, get_nibble			; no, get another one
				call	nibble2val				; convert hexadecimal
				call	print_nibble			; echo character
				ret
				
; get_byte: gets a byte from the serial port in two hexadecimal numbers, blocks since it calls get_nibble
; returns: A - byte entered
get_byte:		push bc
				call	get_nibble
				rlc		a
				rlc		a
				rlc		a
				rlc		a
				ld		b, a
				call	get_nibble
				or		b
				
				pop bc
				ret
; get_word: gets a word from 4 hexadecimal digits
; affects: none
get_word:		push	af						; save registers
				call	get_byte				; get one byte and put in h
				ld		h,a
				call	get_byte				; get one byte and put in l
				ld		l, a
				pop		af						; restore registers and return
				ret

		
; print_nibble: prints a single hex nibble which is given in the lower 4 bits of A
print_nibble:	push	af						; dont destroy the contents of a
				and		$0f						; just in case...
				add		a, '0'					; if we have a digit we are done here
				cp		'9' + 1					; is the result > 9 ?
				jr		c, print_nibble_1		
				add		a, 'A' - '0' - $0a		; Take care of A-F
print_nibble_1:	
				call	putc				; print nibble and return
				pop		af						; restore contents of a
				ret
				
; print_byte: prints a single byte in A as two hexadecimal charcters
; affects: none
print_byte:		push	af						; save registers
				push	bc
				ld		b, a					; copy byte to b register
				rrca							; shift down the high nibble in A
				rrca
				rrca
				rrca
				call 	print_nibble			; print high nibble
				ld		a, b					; move low nibble to a
				call	print_nibble			; print low nibble
				
				pop		bc						; restore registers
				pop		af
				ret
				
; print_word: prints a word contained in HL as 4 hexadecimal characters
; affects: none
print_word:		push 	hl						; save registers
				push 	af
				
				ld		a, h					; print high byte
				call	print_byte
				ld		a, l					; print low byte
				call	print_byte
				
				pop		af						; restore registers
				pop		hl
				ret

				;.EXPORT	getc, get_byte, get_byte, get_word, putc, print_byte, print_word, print_string

; read_line - reads a line of text, returns when enter is pressed. HL then contains the address to the read string
; affects: none
; arguments: HL - start address of string buffer
; returns: none (HL unaffectd)
read_line:		                push	af						; save registers
				push	bc
				push	hl
				
				ld		b,	0					; b stores how many characters have been entered				
read_line_loop:	
				call	getc                ; read a character
				
				cp		CR						; is this a carriage return?
				jr		Z, read_line_done
				
				cp		BS						; is this a backspace?
				jp		Z, read_line_bsp
				
				call	is_print				; is this a printable charater (no control character)?
				jr		NC, read_line_loop		; NO - skip to next
				
				
				call	putc  			; echo character back
				ld		(hl), a					; store entered character
				inc		hl						; increment pointer
				inc		b						; count characters
				
                bit     7,b                     ; sxb check for max of 128 chars
                jr      nz, read_line_done

				jr		read_line_loop			; read next character
				
read_line_bsp:	
				dec		b						; decrease number of characters entered
				jp		M, read_line_bsp_1		; if negative - skip echo and pointer decrease
				
				call	putc				; echo backspace
                ld      a,SPACE
                call    putc
                ld      a,BS
                call    putc

				dec		hl						; decrement counter (effectively erasing the last character)
				jr		read_line_loop
				
read_line_bsp_1: 
				inc		b						; b negative (= -1) - reset b to 0 and read in next character
				jr		read_line_loop

				
read_line_done:	
				ld		(hl), EOS				; put EOS at the end of the string
				
				pop		hl						; restore registers
				pop		bc
				pop		af
				ret								; return
; str_next_token - iterates through the string in HL until first space or EOS is found, replaces that character with EOS and returns the address to the next character in DE
; returns: DE - pointer to start of next string
; affects: A - holds character
str_next_token:
                push    hl                      ; store string start

str_next_token_loop:
                ld      a, (hl)
                cp      ' '
                jr      Z, str_next_token_space
                cp      EOS
                jr      Z, str_next_token_ret

                inc     hl
                jr      str_next_token_loop

str_next_token_space:
                ld      (hl), EOS				; add an end of line character

str_next_token_ret:
                inc     HL                      ; point to next character in string
                ld      d, h                    ; store starting point of next string in DE
                ld      e, l

                pop     hl                      ; restore original string start
                ret
				

; skips all non-word characters (basically space only)
str_skip_whitespace:
				ld		a, (hl)
				cp		' '						; compare to space
				ret		nz						; no space -> return
				inc		hl						; point to next character
				jr		str_skip_whitespace


; str_parse_nibble - parses a single hexadecimal nibble from the string in HL. Sets carry flag if sucessful
; returns: A - parsed nibble
str_parse_nibble:
				ld		a, (hl)					; load a character
				cp		EOS						; is it the end of the string?
				jr		Z, str_parse_nibble_err	; yes - error

				call	to_upper
				call	is_hex					; check if this is a valid hex character
				jr		nc, str_parse_nibble_err ; no - error

				inc		hl						; move pointer to next character

				call	nibble2val				; yes - parse it
				scf								; set carry flag to indicate success
				ret								; return nibble in a

str_parse_nibble_err:
				or		a						; reset carry flag to indicate failure
				ret




; str_parse_byte - reads a byte from the string. if not possible, carry flag will be cleared
; returns: A - parsed byte value
str_parse_byte:	call	str_parse_nibble
				ret		NC						; carry reset = failure
				rlc		a
				rlc		a
				rlc		a
				rlc		a
				ld		b, a
				call	str_parse_nibble
				ret		NC						; carry reset = failure
				or		b						; add first nibble (this resets carry flag)

				scf								; set carry flag to indicate success
				ret								; return

; str_parse_word - reads a word from the string. If not possible, carry flag will be cleared
; returns: DE - parsed word value
str_parse_word:	
				call	str_parse_byte
				ret		nc						; carry reset = failure
				ld		d, a
				call	str_parse_byte
				ret		nc						; carry reset = failure
				ld		e, a

				scf								; set carry flag to indicate success
				ret								; return

; is_hex: checks a character stored in A for being a valid hexadecimal digit
; a valid hexadecimal digit is denoted by a set carry flag
; affects: none
is_hex:			CP		'F' + 1					; Greater than 'F'?
				RET		NC						; Yes
				CP		'0'						; Less than '0'?
				JR		NC, is_hex_1			; No, continue
				
				CCF								; Complment carry flag (= clear it)
				RET								; return
is_hex_1:		CP		'9' + 1					; Less or equal to '9'?
				RET		C						; Yes (carry is set)
				
				CP		'A'						; Less than 'A'?
				JR		NC, is_hex_2			; No, continue
				
				CCF								; Yes, clear carry and return
				RET
is_hex_2:		SCF								; Set carry
				RET
		

; is_print: checks if a character is a printable ASCII character. A valid character is denoted by a set carry flag
; affects: none
is_print:		cp		SPACE
				jr		nc, is_print_1
				ccf
				ret
is_print_1:		cp		$7f
				ret

; nibble2val: expects a hexadecimal digit (in upper case!) in A and returns the corresponding value in A
; affects: A
nibble2val:		CP		'9' + 1					; Is it a digit (Less or equal to '9') ?
				JR		C, nibble2val_1			; Yes
				SUB		7						; Adjust for A-F
nibble2val_1:	SUB		'0'						; Fold back to 0..15
				AND		$0f						; Only return lower 4 bits
				RET
		
		
; to_upper: Converts a single character contained in A to upper case
; returns: character in A
to_upper:		CP		'a'						; Nothing to do if not lower case
				RET		C
				CP		'z' + 1					; > 'z' ?
				RET		NC						; Nothing to do either
				AND		$5f						; Convert to upper case
				RET

; str_cmp - compares two strings and sets carry flag if there is a match
; parameters: HL, DE - string pointers
; affects: A
str_cmp:		push	hl
				push	de

str_cmp_loop:	ld		a, (DE)					; load character into A
				cp		(HL)					; compare with character in HL
				jr		NZ, str_cmp_ns			; strings are not the same

				cp		EOS						; the strings are the same so far and we have reached EOS character?
				inc		hl						; increment pointers (does not affect flags)
				inc		de
				jr		NZ, str_cmp_loop		; no EOS-character?
				
				scf								; set carry flag
				jr		str_cmp_ret				; return

str_cmp_ns:		or		a						; reset carry flag

str_cmp_ret:	pop		de						; pop registers and return
				pop		hl
				ret
; function end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;