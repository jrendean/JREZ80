
org $8300

;ld		hl, hello
;call	print_string
;hello: db "hello",$0d, $0a, $00
;print_string: equ $065B
;ret


;PIOAD:	EQU 0x10
;ld a, 0xAA
;OUT   (PIOAD), A
;ret




//  PPIBase: equ $60
// 	PortA:	EQU PPIBase + 0
// 	PortB:	EQU PPIBase + 1
// 	PortC:	EQU PPIBase + 2
// 	CWR:	EQU PPIBase + 3


// 	LD A,  $81 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (CWR), A

// LD A,  $aa 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (PortA), A
// call delay

// LD A,  $55 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (PortA), A
// call delay


// LD A,  $aa 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (PortA), A
// call delay

// LD A,  $55 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (PortA), A
// call delay


// LD A,  $aa 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (PortA), A
// call delay

// LD A,  $55 	; Port mode config command to 8255: A out, C high out, C low in, B out.
// 	OUT (PortA), A
// call delay

// ret




// lcd_command equ $40 ;LCD command I/O port
// lcd_data equ $41    ;LCD data I/O port

// lcd_init:
//     call delay

//     ld a,$3f        ;Function set: 8-bit interface, 2-line, small font
//     out (lcd_command),a
//     call delay

//     ld a,$0f        ;Display on, cursor on
//     out (lcd_command),a     ;(I find turning the cursor on is very helpful when debugging)
//     call delay

//     ld a,$01        ;Clear display
//     out (lcd_command),a
//     call delay

//     ld a,$06        ;Entry mode: left to right, no shift
//     out (lcd_command),a
//     call delay

// ;ret

// lcd_print:
//     ld hl,message   ;Message address
// message_loop:       ;Loop back here for next character
//     ld a,(hl)       ;Load character into A
//     and a           ;Test for end of string (A=0)
//     jr z,done

//     out (lcd_data),a     ;Output the character
//     inc hl          ;Point to next character (INC=increment, or add 1, to HL)
//     jr message_loop ;Loop back for next character

// done:
//   ret








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
; initialization:		
	;ld 	sp,200h 	; Set stack pointer
	ld 	c,cwadr 
	ld 	a,pacoutbin 	; Ports A&C output,B input
	out	(c),a


    ld a,$3f        ;Function set: 8-bit interface, 2-line, small font
    call init_write

    ld a,$0f        ;Display on, cursor on
    call init_write

    ld a,$01        ;Clear display
    call init_write

    ld a,$06        ;Entry mode: left to right, no shift
    call init_write

	ld		HL, str_lcd_init
	call lcd_print
ret


lcd_print:
    ;ld hl,message   ;Message address
message_loop:       ;Loop back here for next character
    ld a,(hl)       ;Load character into A
    and a           ;Test for end of string (A=0)
    jr z,done

    //out (lcd_data),a     ;Output the character
	push 	bc		; save BC
	push 	de		; save DE
	;jp 	common
	call 	bfcheck    	; See if the LCD is busy. If it is busy wait,till it is not.
	ld 	e,data		;  
	out 	(c),e		; Set/reset RS accoring to the content of register E
	ld 	d,write		
	out	(c),d		; reset RW pin for writing to LCD
	out	(paadr),a	; place data/instrucrtion to be written into portA
	ld 	d,enable	
	out	(c),d		; enable the LCD
	ld 	d,disable	
	out 	(c),d		; disable the LCD 
	pop 	de		; restore DE
	pop 	bc		; restore BC

    ; at higher than 1mhz something is needed in here
    ;call delay
    inc hl          ;Point to next character (INC=increment, or add 1, to HL)
    jr message_loop ;Loop back for next character
done:
    ret


init_write:
	ld 	c,cwadr
	ld 	d,command	
	out	(c),d		; select the instruction register 
	ld 	d,write
	out	(c),d		; reset RW pin for writing to LCD
	out	(paadr),a	; place the command into portA
	ld 	d,enable	
	out	(c),d		; enable the LCD
	ld 	d,disable
	out	(c),d		; disable the LCD 
	;call delay		; wait for a while
	call 	bfcheck    	; See if the LCD is busy. If it is busy wait,till it is not.

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
	in 	a,(paadr)	; read from LCD
	ld 	d,disable
	out 	(c),d		; disable the LCD 
	rlca			; rotate A left through C flag to see if the busy flag is set
	jp 	c,check_again	; if busy check it again,else continue
	ld 	d,pandcout	
	out	(c),d		; set all ports to output mode
	pop 	af		; restore AF
	ret

str_lcd_init: db "JREZ80 ...", $00
