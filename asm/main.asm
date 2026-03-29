; inspiration (with many others): https://github.com/lmaurits/lm512
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           CONSTANTS            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;LED_PORT		equ	$00


;BOTTOM_OF_STACK	equ 	$2000	; "top" stack adress at 4 KB
;BOTTOM_OF_STACK	equ 	0xffff	; "top" stack adress at 4 KB
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
				ds $002D
rst30:			jp		monitor_enter				; breakpoint reset vector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;initialize:		ld 		sp, BOTTOM_OF_STACK			; set up stack pointer 
initialize:		ld 		sp, RAMEND			; set up stack pointer 
				
				call sio_init					; initialize serial communication
				call pc_16550_init					; initialize serial communication
				call pio_init
				call lcd_init

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
				
				; clear RAM
				;ld		hl, END_OF_PROGRAM			; load hl with starting point of area to be cleared
				;ld		de, END_OF_PROGRAM + 1		; load de with starting point of area to be cleared + 1
				;ld		bc,	$7fff - END_OF_PROGRAM  ; bc holds number of bytes to clear (NO parantesis since this is another command!!)
				ld		hl, RAMBEG			; load hl with starting point of area to be cleared
				ld		de, RAMBEG + 1		; load de with starting point of area to be cleared + 1
				ld		bc,	RAMEND - RAMBEG -1 ; bc holds number of bytes to clear (NO parantesis since this is another command!!)
				ld		(hl), $00					; load the first byte with 0
				ldir								;d do (DE)<-(HL); HL++, DE++, until BC == 0. Since HL is one byte behind DE, zeroes will be copied one byte forward untill all of memory is cleared
				
				ld		hl, boot_flag				; set the boot flag
				ld		(hl), BOOT_FLAG_WARM

				jr		main_command_loop			; enter main command line	


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


// getc:
// ;call sio_getc
// call pc_getc
// ret

// putc:
// ;call sio_putc
// call pc_putc
// ret

#INCLUDE	"cli.asm"
#INCLUDE	"commands.asm"
#INCLUDE	"string.asm"
#INCLUDE	"pio_driver.asm"
#INCLUDE	"sio_driver.asm"
#INCLUDE	"16550_driver.asm"
#INCLUDE	"8255_driver.asm"
#INCLUDE	"lcd_driver.asm"




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

SECTION bss
org $8000

;// TODO: MOVE THIS TO ITS OWN "RAM"-FILE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           VARIABLES            ;;
;;	BLOCK n, reserves n bytes and ;;
;;  the label gets the value of	  ;;
;;  the first address			  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

boot_flag:      db     0                ; boot flag

argc:           ds      1               ; holds number of arguments
argv:           ds      16*2            ; array of pointers to the respective arguments (16 arguments = 32 bytes in size, see below)
str_buffer:     ds      128             ; a string buffer

; temporary stack storage space

mon_reg_stack:      ds  20              ; register stack for storing the register contents while in the monitor (BREAKPOINT)
                                        ; 20 bytes: A F B C D E H L + A' F' B' C' D' E' H' L' + IX IY

mon_reg_rtn_addr:   ds  2               ; stores the return address (just for displaying purposes)
mon_stack_backup:   ds  2               ; just a backup variable to not mess up the original stack pointer while saving/restoring

cf_sector_buffer:   ds  512
END_OF_PROGRAM:  equ    ($ + 0FFH) & 0FF00H   ; next 256 byte boundary

; .ECHO	"END_OF_PROGRAM: "
; .ECHO	END_OF_PROGRAM
; .ECHO	"\n"

.END