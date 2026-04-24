; TABLE OF COMMANDS, holds pointer to string, and address
str_cmd_help:	db		"help", EOS
str_cmd_rst:		db		"reset", EOS
str_cmd_dump: 	db		"dump", EOS
str_cmd_fill:    DB      "fill", EOS
str_cmd_move:    DB      "move", EOS
str_cmd_jump:		db		"jump", EOS
str_cmd_breaktest: db	"break", EOS
str_cmd_continue: db	"cont", EOS
str_cmd_reg:		db		"reg", EOS
str_cmd_pio:		db		"pio", EOS
str_cmd_load:		db		"load", EOS
str_cmd_rdump: 	db		"rdump", EOS
str_cmd_pc16o1on:		db		"1o", EOS
str_cmd_pc16o1of:		db		"1f", EOS
str_cmd_pc16o2on:		db		"2o", EOS
str_cmd_pc16o2of:		db		"2f", EOS


command_table:	dw		str_cmd_help, cmd_help
				dw		str_cmd_rst, cmd_reset	; reset command
				dw		str_cmd_dump, cmd_dump	; dump command
				DW		str_cmd_fill, cmd_fill	    ; fill command
                DW		str_cmd_move, cmd_move	    ; move command
				dw		str_cmd_jump, cmd_jump ; jump
				dw		str_cmd_continue, cmd_continue
				;dw		str_cmd_test, cmd_test	; test command
				dw		str_cmd_breaktest, cmd_breaktest ; breaktest command
				dw		str_cmd_reg, dump_registers ; dump registers command
				;dw		str_cmd_pio, cmd_pio ; pio
				dw		str_cmd_load, LOAD ; LOAD
				dw		str_cmd_rdump, rdump	; dump command
				dw		str_cmd_pc16o1on, cmd_pc16o1on ; pio
				dw		str_cmd_pc16o1of, cmd_pc16o1of ; pio
				dw		str_cmd_pc16o2on, cmd_pc16o2on ; pio
				dw		str_cmd_pc16o2of, cmd_pc16o2of ; pio

command_table_entries:	equ	($ - command_table) / (2*2)	; calculate size using bytes


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_help - prints the help info for the user				
cmd_help:		ld		hl, str_commands
				call	print_string
				ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_reset	- does a cold or warm reset
cmd_reset:		push	af
				push	hl
				
				ld		hl, cmd_reset_str
				call	print_string

				call	getc
				call	to_upper

				call	print_newline
				rst		30H
				cp		'Y'						; cold reset?
				jr		nz, cmd_reset_1			; no - skip to reset
				ld		hl, boot_flag			; reset warm boot flag (force cold boot)
				ld		(hl), 0		
				
cmd_reset_1:	rst		00				
				
				pop		hl
				pop		af
				ret
cmd_reset_str:	db		"Reset: Cold reset? (Y/N): ", EOS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_dump - parses command line for a start and end address and then calls the dump_memory function to dump the data
cmd_dump:		ld		a, (argc)				; load number of arguments
				cp		2
				jr		nz, cmd_dump_err		; if there are not 2 arguments, print error message

				ld		hl, (argv)				; first argument
				call	str_parse_word
				jr		nc, cmd_dump_err
				push	de

				ld		hl, (argv + 2)			; second argumend
				call	str_parse_word
				jr		nc, cmd_dump_err
;// TODO: fix uneeven push/pop caused by invalid arguments				
				pop		hl
				call	dump_memory
				ret

cmd_dump_err:	ld		hl, str_cmd_dump_err
				call	print_string
				ret


str_cmd_dump_err: DB	"Usage: dump <START> [END]", CR, LF, EOS


; dump_memory: prints a nice table of the memory contents starting at address HL and ending at address DE (rounded up to closest multiple of 16)
; affects: none
dump_memory:
				push	hl						; save registers
				push	de
				push	af
				
				ld		a, l					; align start address in HL to 16 byte chunks (rounds down)
				and		$f0
				ld		l, a
				
				inc		de						; to include DE if it happens to be a multiple of 16 (prints one extra line in that case)
				
				push	hl						; save start address
				ld		hl, dump_memory_header	; print header
				call	print_string

				pop		hl						; restore start address
				
row_loop:		call	print_word				; print the starting address
				ld		a, SPACE
				
				call	putc					; print space
				call	putc
				
				push	hl						; store the value of HL
				ld		b, 16					; load 16 into b register 
byte_loop:		ld		a, (HL)					; load byte at (HL)
				call	print_byte				; print it
				
				ld		a, SPACE				; print a space
				call 	putc
				
				inc		HL						; HL now points to the next byte in memory
				
				djnz	byte_loop				; do this B times (16)
				
				
				ld		a, '|'					; print a '|'
				call	putc
				
				ld		b, 16					; load 16 into b register	
				
				pop		hl						; restore the value of HL
ascii_loop:		ld		a, (HL)					; load byte at (HL)
				cp		SPACE					; is this a valid (>= 20 <=> no control character) character? 
				jr		nc, ascii_loop_1		; yes
				ld		a, '.'					; no - print '.' instead
ascii_loop_1:	call	putc					; print character
				
				inc		HL						; HL now points to the next byte in memory
				djnz	ascii_loop				; do this B times (16)
				
				ld		a, '|'					; print a '|'
				call	putc
				
				call	print_newline
				
				; check to do this until de >= hl
				push	hl						; save hl
				and		a						; reset carry flag
				sbc		hl, de					; do HL - DE, carry inticates DE > HL
				pop		hl						; restore hl since the above modifies it
				jr		c, row_loop				; if DE > HL, do next row
				
				pop		af						; restore registers
				pop		de
				pop		hl
				ret
				
				
dump_memory_header:
				db		"      00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F", CR, LF, CR, LF, EOS

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_fill - fill memory with pattern		
; > fill 8000 80ff 12		
cmd_fill:		; make sure there are 3 arguments
				ld		a, (argc)
				cp		3				
				jr		nz, cmd_fill_err
				
				ld		hl, (argv)			; first argument
				call	str_parse_word
				jr		nc, cmd_fill_err
				push	de                      ; save first hex word

				ld		hl, (argv + 2)		; second argument
				call	str_parse_word
				jr		nc, cmd_fill_err2
                push    de

                ld		hl, (argv + 4)		; third argument
				call	str_parse_byte
				jr		nc, cmd_fill_err2

                pop     de
				pop		hl                      
				call	fill_memory             ; HL = <START> DE = <END> A = <PATTERN>
				ret

cmd_fill_err2:  pop     de                      ; sync stack
cmd_fill_err:	ld		hl, str_cmd_fill_err
				call	print_string
				ret							    

str_cmd_fill_err: DB	"Usage: fill <START> <END> <PATTERN>", CR, LF, EOS

fill_memory:    push    af
                
                ld      a, d
                sub     h
                ld      b, a
                ld      a, e
                sub     l
                ld      c, a
                
                ld      d, h
                ld      e, l
                inc     de
                
                pop     af
                ld      (hl), a
                ldir

                ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_move - move a block of memory		
; > move <FROM> <TO> <SIZE>
cmd_move:		; make sure there are 3 arguments
				ld		a, (argc)
				cp		3				
				jr		nz, cmd_move_err
				
				ld		hl, (argv)			; first argument
				call	str_parse_word
				jr		nc, cmd_move_err
				push	de                      ; save first hex word

				ld		hl, (argv + 2)		; second argument
				call	str_parse_word
				jr		nc, cmd_move_err2
                push    de

                ld		hl, (argv + 4)		; third argument
				call	str_parse_word
				jr		nc, cmd_move_err3
                push    de
                
                pop     bc
                pop     de
				pop		hl                      
				call	move_memory             ; HL = <FROM> DE = <TO> BC = <SIZE>
				ret

cmd_move_err3:  pop     de                      ; sync stack
cmd_move_err2:  pop     de                      ; sync stack
cmd_move_err:	ld		hl, str_cmd_move_err
				call	print_string
				ret							    

str_cmd_move_err: DB	"Usage: move <FROM> <TO> <SIZE>", CR, LF, EOS

;
; extra checks needed
; 1. no overlap in addresses
;
move_memory:    push    bc
                push    hl                      ; no not a mistake, later we want de and hl the same
                push    hl
                
                ldir                            ; move memory

                pop     hl
                pop     de
                pop     bc
                
                inc     de
                ld      a, $00
                ld      (hl), a
                ldir                            ; fill <FROM> with zero's

                ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; cmd_jump - jumps to specific address and continues excecution from there
cmd_jump:		; make sure there are exactly 1 argument
				ld		a, (argc)
				cp		1				
				jr		nz, cmd_jump_error
				
				; read in argument
				ld		hl, (argv)
				call	str_parse_word
				jr		nc, cmd_jump_error

				;push	de						; store address on stack...
				;ret								; ...wich makes this call the specified function
				ld (hl), de
				jp      (hl)            ; Start program (and hope for the best)

cmd_jump_error:
				ld		hl,str_cmd_jump_err
				call	print_string
				ret

str_cmd_jump_err: 	DB		"Usage: jump <ADDR>", CR, LF, EOS



rdump:           push    af
                push    hl
                ld      hl, rdump_msg_1 ; Print first two lines
                call    print_string
                pop     hl
                call    rdump_one_set
                exx
                ex      af, af'
                push    hl
                ld      hl, rdump_msg_2
                call    print_string
                pop     hl
                call    rdump_one_set
                ex      af, af'
                exx
                push    hl
                ld      hl, rdump_msg_3
                call    print_string
                push    ix
                pop     hl
                call    print_word
                ld      hl, rdump_msg_4
                call    print_string
                push    iy
                pop     hl
                call    print_word
                ld      hl, rdump_msg_5
                call    print_string
                ld      hl, 0
                add     hl, sp
                call    print_word
				ld      hl, rdump_msg_6
                call    print_string
				call get_pc ;returns pc in hl
				call    print_word
                call    print_newline
                pop     hl
                pop     af
                ret
rdump_msg_1:     db    "REGISTER DUMP", CR, LF, CR, LF, TAB, "1st:", EOS
rdump_msg_2:     db    TAB, "2nd:", EOS
rdump_msg_3:     db    TAB, "PTR: IX=", EOS
rdump_msg_4:     db    " IY=", EOS
rdump_msg_5:     db    " SP=", EOS
rdump_msg_6:     db    " PC=", EOS
;



get_pc:
Pop hl
Push hl
Ret
rdump_one_set:   push    hl              ; Print one register set
                ld      hl, rdump_os_msg_1
                call    print_string
                push    af              ; Move AF into HL
                pop     hl
                call    print_word      ; Print contents of AF
                ld      hl, rdump_os_msg_2
                call    print_string
                ld      hl, bc
                call    print_word      ; Print contents of BC
                ld      hl, rdump_os_msg_3
                call    print_string
                ld      hl, de
                call    print_word      ; Print contents of DE
                ld      hl, rdump_os_msg_4
                call    print_string
                pop     hl              ; Restore original HL
                call    print_word      ; Print contents of HL
                call    print_newline
                ret
rdump_os_msg_1:  db    " AF=", EOS
rdump_os_msg_2:  db    " BC=", EOS
rdump_os_msg_3:  db    " DE=", EOS
rdump_os_msg_4:  db    " HL=", EOS



// cmd_pio:
// 	ld a, (argc)
// 	jr		nz, cmd_pio_error
	
// 	; read in argument
// 	ld		hl, (argv)
// 	call	str_parse_word
// 	jr		nc, cmd_pio_error

// 	LD	A, e
// 	call pio_outpout_a
// 	ret

// cmd_pio_error:
// 	ld		hl,str_cmd_pio_err
// 	call	print_string
// 	ret

// str_cmd_pio_err: 	DB		"Usage: pio <value>", CR, LF, EOS


cmd_pc16o1on:
    in     a, (uart_register_4)
	or %00000100
	out     (uart_register_4), a
	ret
cmd_pc16o1of:
    in     a, (uart_register_4)
	and %11111011
	out     (uart_register_4), a
	ret
cmd_pc16o2on:
	in     a, (uart_register_4)
	or %00001000
	out     (uart_register_4), a
	ret
cmd_pc16o2of:
	in     a, (uart_register_4)
	and %11110111
	out     (uart_register_4), a
	ret


;
; Load an INTEL-Hex file (a ROM image) into memory. This routine has been 
; more or less stolen from a boot program written by Andrew Lynch and adapted
; to this simple Z80 based machine.
;
; The INTEL-Hex format looks a bit awkward - a single line contains these 
; parts:
; ':', Record length (2 hex characters), load address field (4 hex characters),
; record type field (2 characters), data field (2 * n hex characters),
; checksum field. Valid record types are 0 (data) and 1 (end of file).
;
; Please note that this routine will not echo what it read from stdin but
; what it "understood". :-)
; 
LOAD:         push    af
                push    de
                push    hl
                ld      hl, ih_load_msg_1
                call    print_string
ih_load_loop:    call    getc            ; Get a single character
                cp      CR              ; Don't care about CR
                jr      z, ih_load_loop
                cp      LF              ; ...or LF
                jr      z, ih_load_loop
                cp      SPACE           ; ...or a space
                jr      z, ih_load_loop
                call    to_upper        ; Convert to upper case
                call    putc            ; Echo character
                cp      ':'             ; Is it a colon?                
                jr      nz, ih_load_error
                call    get_byte        ; Get record length into A
                ld      d, a            ; Length is now in D
                ld      e, $0           ; Clear checksum
                call    ih_load_chk     ; Compute checksum
                call    get_word        ; Get load address into HL
                ld      a, h            ; Update checksum by this address
                call    ih_load_chk
                ld      a, l
                call    ih_load_chk
                call    get_byte        ; Get the record type
                call    ih_load_chk     ; Update checksum
                cp      $1              ; Have we reached the EOF marker?
                jr      nz, ih_load_data; No - get some data
                call    get_byte        ; Yes - EOF, read checksum data
                call    ih_load_chk     ; Update our own checksum
                ld      a, e
                and     a               ; Is our checksum zero (as expected)?
                jr      z, ih_load_exit ; Yes - exit this routine
ih_load_chk_err: ld      hl, ih_load_msg_3
                call    print_string            ; No - print an error message
                jr      ih_load_exit    ; and exit
ih_load_data:   ld      a, d            ; Record length is now in A
                and     a               ; Did we process all bytes?
                jr      z, ih_load_eol  ; Yes - process end of line
                call    get_byte        ; Read two hex digits into A
                call    ih_load_chk     ; Update checksum
                ld      (hl), a         ; Store byte into memory
                inc     hl              ; Increment pointer
                dec     d               ; Decrement remaining record length
                jr      ih_load_data    ; Get next byte
ih_load_eol:    call    get_byte        ; Read the last byte in the line
                call    ih_load_chk     ; Update checksum
                ld      a, e
                and     a               ; Is the checksum zero (as expected)?
                jr      nz, ih_load_chk_err
                jr      ih_load_loop    ; Yes - read next line
ih_load_error:  ld      hl, ih_load_msg_2
                call    print_string            ; Print error message
ih_load_exit:   pop     hl              ; Restore registers
                pop     de
                pop     af
				ret
;
ih_load_chk:    ld      c, a            ; All in all compute E = E - A
                ld      a, e
                sub     c
                ld      e, a
                ld      a, c
                ret

ih_load_msg_1:   db    "INTEL HEX LOAD: ", CR, LF, EOS
ih_load_msg_2:   db    " Syntax error!", CR, LF, EOS
ih_load_msg_3:   db    " Checksum error!", CR, LF, EOS





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_continue - exits out of monitor mode and continues on
cmd_continue:	pop		hl		; exit out of excecute_command
				jp 		monitor_leave	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; cmd_breatest - tests the "break" functionality by issuing rst 30H eight times
cmd_breaktest:
				ld		b, 8
				ld		a,0
cmd_breaktest_loop:
				inc		a

				rst		30H				; breakpoint!
				djnz	cmd_breaktest_loop
				ret

 