; inspiration (with many others): https://github.com/lmaurits/lm512
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           CONSTANTS            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RAMBEG:	EQU 0x8000
RAMEND:	EQU 0xffff

BOOT_FLAG_WARM	equ	$AA

#INCLUDE	"constants.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;             CODE               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Excecution starts here
org $0000
				DI									; disable interrupts
				jr		initialize					; skip reset vector(s)

;;;;;;;;;; AREA FOR RESET VECTORS AND SO ON HERE ;;;;;;;;;;;;
				;org 	$0030
				ds $002d
rst30:			jp		monitor_enter				; breakpoint reset vector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;               RAM TESTING & INITIALIZATION               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;initialize:		ld 		sp, BOTTOM_OF_STACK			; set up stack pointer 
initialize:		ld 		sp, RAMEND			; set up stack pointer 
				
				;call sio_init					; initialize serial communication
				call pc_16550_init					; initialize serial communication
				call pc_8255_init
				call lcd_init
				;call pio_init

				ld		HL, str_init				; print welcome message
				call	print_string

				ld		HL, str_lcd_init
				call lcd_print

				; cold/warm start
				ld		hl, boot_flag
				ld		a, (hl)						; load boot_flag contents into A register
				cp		BOOT_FLAG_WARM
				ld		hl,	str_warm_boot
				call	z, print_string				; if this is warm boot, print string
				jp		z, main_command_loop		; if this is warm boot, skip to main
				
				
				ld		hl, str_cold_boot			; print cold boot message
				call	print_string

				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;; STEP 1: Test and zero initial RAM
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				ld		hl, str_step1_init			; print step 1 message
				call	print_string
				
				; Test full RAM range from RAMBEG to RAMEND
				ld		hl, RAMBEG				; start of RAM to test
				ld		bc, RAMEND - RAMBEG		; test full range
				call	find_ram_end			; find actual RAM available
				
				; Test result
				ld		a, b
				or		c						; check if any RAM found
				jr		nz, step1_ram_found
				
				ld		hl, str_ram_test_failed
				call	print_string
				jr		step1_complete
				
step1_ram_found:
				ld		hl, str_ram_test_success
				call	print_string
				call	report_ram_size			; report size in BC
				
				; Zero out only the area where code will go
				ld		hl, RAMBEG
				ld		bc, END_OF_PROGRAM		; zero up to where code ends
				call	zero_memory
				
				ld		hl, str_ram_cleared
				call	print_string
				
step1_complete:

				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;; STEP 2: Copy entire code to RAM
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				ld		hl, str_step2_init		; print step 2 message
				call	print_string
				
				call	copy_code_to_ram		; copy code from ROM to RAM
				
				ld		hl, str_code_copied
				call	print_string
				
				; Switch execution to RAM
				; Calculate address of next instruction (step2_continue) and add RAMBEG offset
				ld		hl, step2_continue		; get address of next instruction
				ld		de, RAMBEG
				add		hl, de					; offset to RAM location
				jp		(hl)					; jump to RAM and continue execution there
				
step2_continue:
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;; VERIFY: We're running from RAM above 0x8000
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				; Get current PC by using call to push return address
				call get_current_pc			; HL will contain this instruction's address
				
				ld		(temp_pc), hl			; save PC temporarily
				
				ld		hl, str_pc_prefix
				call	print_string
				
				ld		hl, (temp_pc)
				call	print_word				; print the PC address
				
				; Check if PC is >= 0x8000 (in RAM)
				ld		hl, (temp_pc)
				ld		a, h
				cp		$80						; check if high byte >= 0x80
				jr		c, ram_exec_failed		; if less than 0x80, we're not in RAM
				
				; If we got here, PC is in RAM!
				ld		hl, str_ram_exec_success
				call	print_string
				jr		ram_exec_verified
				
get_current_pc:	pop		hl					; pop return address into HL
				push	hl					; push it back for the ret
				ret
				
ram_exec_failed:
				ld		hl, str_ram_exec_failed
				call	print_string
				
ram_exec_verified:
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;; STEP 3: Test extended RAM (formerly ROM area)
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				ld		hl, str_step3_init		; print step 3 message
				call	print_string
				
				; Test ROM area (0x0000 to 0x7FFF) - now available since code copied to RAM
				ld		hl, $0000				; start at ROM area
				ld		bc, RAMBEG				; test up to RAMBEG (0x8000 - 32KB)
				call	find_ram_end			; test extended RAM
				
				ld		a, b
				or		c
				jr		nz, step3_ram_found
				
				ld		hl, str_extended_ram_test_failed
				call	print_string
				jr		step3_complete
				
step3_ram_found:
				ld		hl, str_extended_ram_test_success
				call	print_string
				call	report_ram_size			; report additional RAM size
				
				; Zero out the formerly-ROM area
				ld		hl, $0000
				ld		bc, RAMBEG				; zero from 0x0000 to 0x7FFF
				call	zero_memory
				
				ld		hl, str_extended_ram_cleared
				call	print_string
				
step3_complete:

				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				;; Continue with normal initialization
				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
				ld		hl, boot_flag				; set the boot flag
				ld		(hl), BOOT_FLAG_WARM

				jp		main_command_loop			; enter main command line

; test_ram_byte - test a single RAM byte with safer pattern
; Input: HL = address to test
; Output: A = 0 if test passed, 1 if failed
test_ram_byte:	push	bc
				push	de
				
				; Save original value
				ld		a, (hl)
				ld		b, a					; save in B
				
				; Test pattern 1: $55
				ld		a, $55
				ld		(hl), a
				ld		c, a					; expected value
				ld		a, (hl)
				cp		c
				jr		nz, test_failed_restore
				
				; Test pattern 2: $AA
				ld		a, $AA
				ld		(hl), a
				ld		c, a
				ld		a, (hl)
				cp		c
				jr		nz, test_failed_restore
				
				; Restore original value
				ld		a, b
				ld		(hl), a
				xor		a						; return 0 (success)
				pop		de
				pop		bc
				ret
				
test_failed_restore:
				ld		a, b					; restore original value
				ld		(hl), a
				ld		a, 1					; return 1 (failed)
				pop		de
				pop		bc
				ret

; find_ram_end - find the end of available RAM (safer version)
; Input: HL = start address, BC = max size to test
; Output: HL = address of last good RAM location, BC = size of RAM found
find_ram_end:	push	de
				push	af
				ld		d, h					; save start address in DE
				ld		e, l
				ld		a, 0					; failure counter
				
test_loop:		call	test_ram_byte			; test current location
				cp		0						; check if test passed
				jr		z, test_ok				; if passed, continue
				
				inc		a						; increment failure counter
				cp		3						; allow 3 consecutive failures before giving up
				jr		c, test_ok				; continue if under 3 failures
				jr		test_failed				; give up if 3 consecutive failures
				
test_ok:		cp		0						; reset failure counter on success
				jr		nz, continue_test
				xor		a						; failure counter back to 0
				
continue_test:	inc		hl						; move to next address
				dec		bc						; decrement count
				ld		a, b
				or		c						; check if BC == 0
				jr		nz, test_loop			; continue if more to test
				jr		test_complete			; done with loop
				
test_failed:	dec		hl						; back up to last good address
				
test_complete:	ld		a, l					; calculate size: HL - DE
				sub		e
				ld		c, a
				ld		a, h
				sbc		d
				ld		b, a						; BC now holds size (low byte in C, high byte in B)
				
				pop		af
				pop		de
				ret

; zero_memory - zero out memory range
; Input: HL = start address, BC = number of bytes
; Output: Memory cleared
zero_memory:	ld		(hl), $00				; write first byte
				ld		de, hl
				inc		de						; point DE to next byte
				dec		bc						; decrement count
				ldir								; copy zeros to rest of range
				ret

; copy_code_to_ram - copy code from ROM to RAM
; Input: None (uses END_OF_PROGRAM)
; Output: None (code copied from $0000 to RAMBEG)
copy_code_to_ram:
				ld		hl, $0000				; source: ROM start
				ld		de, RAMBEG				; destination: RAM start
				ld		bc, END_OF_PROGRAM		; size: up to END_OF_PROGRAM
				ldir								; copy
				ret

; report_ram_size - print RAM size in hex
; Input: BC = RAM size in bytes
; Output: None
report_ram_size:
				push	bc
				ld		hl, str_ram_size_prefix
				call	print_string
				pop		bc
				
				; print BC in hex (4 hex digits)
				ld		a, b
				call	print_hex_byte
				ld		a, c
				call	print_hex_byte
				
				ld		hl, str_ram_size_suffix
				call	print_string
				ret

; print_hex_byte - print a byte as 2 hex digits
; Input: A = byte to print
; Output: None
print_hex_byte:	push	af
				rra
				rra
				rra
				rra							; rotate high nibble to low
				and		0x0F					; mask to low nibble
				call	print_hex_digit
				pop		af
				and		0x0F					; mask to low nibble
				
print_hex_digit:
				add		a, $30					; add ASCII '0'
				cp		$3A						; check if > 9
				jr		c, is_digit				; if <= 9, it's a digit
				add		a, $07					; add 7 to convert to A-F
				
is_digit:		call	putc
				ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




; monitor program starts here
; monitor_enter - saves all the registers to a special area in ram
monitor_enter:	ld		(mon_stack_backup), SP	; backup stack pointer

				; Save all registers
				ld		SP, mon_reg_stack + 1;

				push	af
				push	bc
				push	de
				push	hl
				ex		af,af'					; swap registers
				exx	

				push	af
				push	bc
				push	de
				push	hl
				ex		af,af'					; swap registers again
				exx	

				push	ix						; save ix and iy
				push	iy

				
				
				ld		SP, (mon_stack_backup)	; restore original stack pointer

				pop		hl						; pop return address to hl
				push	hl						; push return address again

				ld		(mon_reg_rtn_addr), hl	; save return address in variable

				; DO REAL STUFF HERE!!! WE ARE IN A SAFE ENVIRONMENT
				
				call	dump_registers

				ld		hl, str_mon_cont
				call	print_string
				call	getc					; wait for a character
				;call	to_upper
				;cp		'M'
				cp		'm'
				jr		NZ, monitor_leave

main_command_loop:			

				call	print_newline
				ld		a, '>'					; print command prompt
				call	putc

				ld		hl, str_buffer			; hl points to start of string buffer
				call	read_line				; read input line

				ld		a, (hl)					; if command line is empty, just skip
				cp		EOS
				jr		Z, main_command_loop

				call	print_newline	

				ld		bc, argc				; load pointer to argc/argv array
				call	parse_line				; parse entered command line string

				ld		ix, command_table		; pointer to command table	
				ld		b, command_table_entries	; load b with number of entries to test (this is precalculated in the assembler)
				call	excecute_command		; excecute the command

				jr		main_command_loop		; do it again


				;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; monitor_leave - restores all registers and returns to original caller, effectively leaves "monitor" mode
monitor_leave:
				ld		(mon_stack_backup), SP	; backup stack pointer

				; Restore all registers
				ld		SP, mon_reg_stack - (20-1); set stack pointer to start at the bottom of our saved registers stack

				pop		iy						; restore iy and ix
				pop		ix

				ex		af,af'					; swap registers
				exx	
				pop		hl
				pop		de
				pop		bc
				pop		af

				ex		af,af'					; swap registers again
				exx	
				pop		hl
				pop		de
				pop		bc
				pop		af							
				
				ld		SP, (mon_stack_backup)	; restore stack pointer
				ret								; return!

str_mon_cont:	db		"Press m to re-enter monitor, or any other key to continue excecution.", CR, LF, EOS

; dump_registers - prints the contents of the stored register stack in a nice format
dump_registers:	
				ld		hl, str_regdump_pc		; print pc string
				call	print_string
				ld		hl, (mon_reg_rtn_addr)	; print return address
				dec		hl						; will now point at the rst instruction
				call	print_word
				call	print_newline
				call	print_newline

				ld		de, mon_reg_stack		; pointer to saved registers

				ld		hl, str_regdump			; print header for normal registers
				call	print_string
				ld		b, 8					; dump 8 registers
				call	dump_registers_loop
				call	print_newline
				call	print_newline

				ld		hl, str_regdump_alt		; print header for alterative registers
				call	print_string
				ld		b, 8					; dump 8 registers
				call	dump_registers_loop
				call	print_newline
				call	print_newline

				ld		hl, str_regdump_index	; print header for index registers
				call	print_string
				ld		b, 4					; dump 4 registers
				call	dump_registers_loop
				call	print_newline
				call	print_newline

				ret								; return

dump_registers_loop:
				ld		a, (de)					; load byte for next register
				dec		de						; move to next
				call	print_byte				; print byte
				ld		a, SPACE
				call	putc
				djnz	dump_registers_loop

		LD A,	$04
		OUT (uart_register_4), A

				ret

str_regdump_pc:		db		"BREAK @ 0x", EOS ;
str_regdump:		db		"A  F  B  C  D  E  H  L", CR, LF, EOS
str_regdump_alt:	db		"A' F' B' C' D' E' H' L'", CR, LF, EOS
str_regdump_index:	db		"IX    IY", CR, LF, EOS


#include "utilities.asm"
#INCLUDE	"cli.asm"
#INCLUDE	"commands.asm"
#INCLUDE	"string.asm"
;#INCLUDE	"pio_driver.asm"
;#INCLUDE	"lcd_bus_driver.asm"
#INCLUDE	"lcd_8255_driver.asm"
#INCLUDE	"8255_driver.asm"
#INCLUDE	"16550_driver.asm"
;#INCLUDE	"sio_driver.asm"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                        DATA   													                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
str_warm_boot:	db		"Warm Boot...", CR, LF, EOS
str_cold_boot:	db		"Cold Boot...", CR, LF, EOS
str_init:		db		$1B,"[2J", $1B,"[H", $1B,"[91mJREZ80", $1B,"[0m Monitor v0.1 initializing...", CR, LF, CR, LF, EOS
str_commands:	db		" Available Commands are: ", CR, LF
				db		"    help - show this list", CR, LF
				db		"    reset - Reset Cold/Warm", CR, LF
				db		"    dump - print memory contents", CR, LF
				db		"    fill - fill bytes in memory", CR, LF
				db		"    move - copy data in memory", CR, LF
				db		"    jump - jump to address", CR, LF
				db		"    reg - view register contents @ BREAK", CR, LF
				db		"    cont - continue excecution", CR, LF, EOS

str_lcd_init: db "JREZ80 ...", EOS

; RAM Testing and Initialization strings
str_step1_init:	db		CR, LF, "=== STEP 1: Testing & Zeroing Initial RAM ===", CR, LF, EOS
str_ram_test_success:	db		"RAM Test: PASSED - Size: 0x", EOS
str_ram_test_failed:	db		"RAM Test: FAILED", CR, LF, EOS
str_ram_cleared:	db		" bytes", CR, LF, "Initial RAM cleared.", CR, LF, EOS

str_step2_init:	db		CR, LF, "=== STEP 2: Copying Code to RAM ===", CR, LF, EOS
str_code_copied:	db		"Code copied to RAM.", EOS

str_pc_prefix:	db		CR, LF, "Current PC: 0x", EOS
str_ram_exec_success:	db		" (RAM confirmed)", CR, LF, EOS
str_ram_exec_failed:	db		" (ERROR: Not in RAM!)", CR, LF, EOS

str_step3_init:	db		CR, LF, "=== STEP 3: Testing Extended RAM ===", CR, LF, EOS
str_extended_ram_test_success:	db		"Extended RAM Test: PASSED - Size: 0x", EOS
str_extended_ram_test_failed:	db		"Extended RAM Test: FAILED", CR, LF, EOS
str_extended_ram_cleared:	db		" bytes)", CR, LF, "Extended RAM cleared.", CR, LF, EOS

str_ram_size_prefix:	db		"", EOS
str_ram_size_suffix:	db		"", EOS

END_OF_PROGRAM:  equ    ($ + 0FFH) & 0FF00H   ; next 256 byte boundary



SECTION bss
org $8000

boot_flag:      db     0                ; boot flag

temp_pc:        ds      2               ; temporary storage for PC value

argc:           ds      1               ; holds number of arguments
argv:           ds      16*2            ; array of pointers to the respective arguments (16 arguments = 32 bytes in size, see below)
str_buffer:     ds      128             ; a string buffer

; temporary stack storage space

mon_reg_stack:      ds  20              ; register stack for storing the register contents while in the monitor (BREAKPOINT)
                                        ; 20 bytes: A F B C D E H L + A' F' B' C' D' E' H' L' + IX IY

mon_reg_rtn_addr:   ds  2               ; stores the return address (just for displaying purposes)
mon_stack_backup:   ds  2               ; just a backup variable to not mess up the original stack pointer while saving/restoring

cf_sector_buffer:   ds  512