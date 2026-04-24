;8255 port address(base 00h):	
paadr: 		equ 60h		; Address of PortA
pbadr: 		equ 61h		; Address of PortB
pcadr: 		equ 62h		; Address of PortC
cwadr: 		equ 63h		; Address of Control Word
;stuff to be written into the control word of the 8255:
;Some of the change the state of the ports and some manipulate
;bits on port C
allpsin: 	equ 9bh		; set all ports to input mode
paincout: 	equ 90h		; A input,C output,B output
pandcout:	equ 80h		; set all ports to output mode
pacoutbin:	equ 82h		; A output,C output,B input
	
;bit set/reset commands.These bits are the control signals for the LCD
enable: 	equ 0fh		; set portC bit #6
disable:	equ 0eh		; reset portC bit #6
read: 		equ 0dh		; set portC bit #5
write :		equ 0ch		; reset portC bit #5
command: 	equ 0ah		; reset portC bit #4
data :		equ 0bh		; set portC bit #4


lcd_init:
    ld c, cwadr 
    ld a, pandcout     ; Ports A&C output, B input
    out (c), a
    
    ; 4-bit mode initialization sequence
    ld a, $30           ; First init command (8-bit)
    call init_command_8bit
    
    ld a, $30           ; Second init command (8-bit)
    call init_command_8bit
    
    ld a, $30           ; Third init command (8-bit)
    call init_command_8bit
    
    ld a, $20           ; Set to 4-bit mode
    call init_command_8bit
    
    ; Now in 4-bit mode
    ld a, $28           ; Function set: 4-bit interface, 2-line, 5x8 font
    call init_command_4bit
    
    ld a, $0f           ; Display on, cursor on
    call init_command_4bit
    
    ld a, $01           ; Clear display
    call init_command_4bit
    
    ld a, $06           ; Entry mode: left to right, no shift
    call init_command_4bit
    ret


lcd_print:
    ;ld hl,message   ;Message address
message_loop:       ;Loop back here for next character
    ld a,(hl)       ;Load character into A
    and a           ;Test for end of string (A=0)
    jr z,done

    ; Send data in 4-bit mode
	push bc		; save BC
	push de		; save DE
	call bfcheck    	; See if the LCD is busy. If it is busy wait,till it is not.
	call lcd_data_4bit
	pop de		; restore DE
	pop bc		; restore BC

    ; at higher than 1mhz something is needed in here
    ;call delay
    inc hl          ;Point to next character (INC=increment, or add 1, to HL)
    jr message_loop ;Loop back for next character
done:
    ret


init_command_8bit:
	ld 	c,cwadr
	ld 	d,command	
	out	(c),d		; select the instruction register 
	ld 	d,write
	out	(c),d		; reset RW pin for writing to LCD
	; Shift command right by 4 bits for pins 1-4 (bits 0-3)
	sra a
	sra a
	sra a
	sra a
	out	(paadr),a	; place the command into portA (bits 0-3)
	ld 	d,enable	
	out	(c),d		; enable the LCD
	ld 	d,disable
	out	(c),d		; disable the LCD 
	call 	bfcheck    	; See if the LCD is busy. If it is busy wait,till it is not.
    ret

; ====================================================================
; 4-bit mode write functions
; ====================================================================

init_command_4bit:
	; Send high nibble (bits 7-4 of A to pins 1-4, bits 0-3 of port)
	push af			; Save original value
	ld c, cwadr
	ld d, command
	out (c), d		; Select instruction register
	ld d, write
	out (c), d		; Reset RW pin for writing
	; Shift right 4 times to move bits 7-4 to bits 3-0
	sra a
	sra a
	sra a
	sra a
	out (paadr), a	; Send high nibble (now in bits 3-0, pins 1-4)
	ld d, enable
	out (c), d		; Pulse enable
	ld d, disable
	out (c), d
	
	; Send low nibble - keep bits 3-0 and mask to bits 3-0
	pop af			; Restore original value
	and $0f			; Mask to keep only bits 3-0
	ld d, write
	out (c), d
	out (paadr), a	; Send low nibble (bits 3-0 stay in bits 3-0)
	ld d, enable
	out (c), d		; Pulse enable
	ld d, disable
	out (c), d
	
	call bfcheck		; Check busy flag
    ret

lcd_data_4bit:
	; Send data in 4-bit mode via pins 1-4 (bits 0-3)
	; High nibble first
	push af			; Save original value
	ld c, cwadr
	ld d, data
	out (c), d		; Select data register
	ld d, write
	out (c), d		; Reset RW pin
	; Shift right 4 times to move bits 7-4 to bits 3-0
	sra a
	sra a
	sra a
	sra a
	out (paadr), a	; Send high nibble (bits 7-4 now in bits 3-0, pins 1-4)
	ld d, enable
	out (c), d
	ld d, disable
	out (c), d
	
	; Send low nibble
	pop af
	and $0f			; Mask to keep only bits 3-0
	ld d, write
	out (c), d
	out (paadr), a	; Send low nibble (bits 3-0 in pins 1-4)
	ld d, enable
	out (c), d
	ld d, disable
	out (c), d
    ret

; ====================================================================
; Subroutine name:bfcheck
; programmer:Dincer Aydin
; input:
; output:
; Registers altered:D
; function:Checks if the LCD is busy and waits until it is not busy
; ====================================================================
bfcheck:
	push 	af		; save AF
	ld 	c,cwadr
	ld 	d,paincout
	out 	(c),d		; make A input,C output,B output
	ld 	d,read		
	out 	(c),d		; set RW pin for reading from LCD
	ld 	d,command
	out	(c),d		; select the instruction register 
check_again:	
	ld 	d,enable	
	out	(c),d		; enable the LCD
	in 	a,(paadr)	; read from LCD (busy flag in bit 3, pins 1-4)
	ld 	d,disable
	out 	(c),d		; disable the LCD 
	and $08			; Check bit 3 (busy flag from bits 0-3)
	jp 	nz,check_again	; if busy (NZ) check it again, else continue
	ld 	d,pandcout	
	out	(c),d		; set all ports to output mode
	pop 	af		; restore AF
	ret
