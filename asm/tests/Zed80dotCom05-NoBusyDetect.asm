;*******************************************************************************
; This program displays "!! Z80.com !!" on a 2-line HD44780-compatible LCD module.
;*******************************************************************************
; The Z80 was clocked at 4.09611 MHz for a no-name HD44780-compatible LCD display; link below.
; https://www.banggood.com/1Pc-1602-Character-LCD-Display-Module-Blue-Backlight-p-978160.html?rmmds=
; search&cur_warehouse=CN
;
; 8255 Control Group A: Port A 0-7 and Port C pins 4-7 (high). The output, LCD panel, uses Control Group A.
; 8255 Control Group B: Port B 0-7 and Port C pins 0-3 (low). The input, 4x4 keypad, uses Control Group B.
;
; Control Word Register:
;  portMode  Mode0  portA-Output  portC-HighOutput  portB-Output   portC-LowInput   Binary     Hex
;    1         00        0             0                   00            1          1000 0001  81
; 
;  portMode  Mode0  portA-Input   portC-HighOutput  portB-Output   portC-LowInput   Binary     Hex
;    1         00        1             0                   00            1          1001 0001  91
;
; For our needs, we will use control word 81h. If we wished to use the busy-check function as outlined by 
; Dincer Aydin in his code at the "common:" label, we would also use control word 91h. To keep things simple,
; we won't use the busy-check but will add a little delay between command/data writes to the LCD thus giving
; it ample time to catch up. http://dinceraydin.com/files/hello_asm.htm
; 
; OPERATIONS:
;Initialize RAM and 8255
;	Set Stack Pointer to some unused RAM location.
;	Output config to CWR: A out, C high out, C low in, B out.
;	Delay (at least 1010h. Set to 3F3Fh for a medium scroll effect).
;	Set # of times to loop this init.
;Init the LCD: RS & RW lines must be set before the command/data is sent and the E line is pulsed.
;	Set RS to Command (low) and output to CWR bit mode.
;	Set RW to Write (low) and Output to CWR bit mode.
;	Set LCD config to 38h (Clear, 8-bit, 2-line, 5x7 pixel characters) and Output to portA. 
;	Pulse the Enable line for the LCD to read RW, RS, D7-D0. Pulse requires Enable&Output then 
;       Disable&Output. Add short delay in pulse high/low to circumvent need to do busy-check.
;
;Send Command
;	Point to first/next Command byte.
;	Set RS according to whether Command (0) or Data (1) and output.
;	Set RW low to write and output.
;	Output Command to port A.
;	Pulse the Enable line with short delay in middle of pulse.
;	Repeat for all 4 Commands.
;
;Send Data
;	Repeat all of the Send Command block of actions above.
;	Repeat for all Data bytes.	
;==================================================================================================
; Connections:
	; LCD Data bus(pins #14-#7) connected to Port A of a 8255 with 10h base address
	; LCD Enable pin(#6) connected to Port C bit #7
	; LCD R/W pin(#5) connected to Port C bit #6
	; LCD RS pin(#4) connected to Port C bit #5

;8255 port address(base 10h):	
	pAadr 	EQU 10h		; Address of PortA.
	pBadr 	EQU 11h		; Address of PortB.
	pCadr 	EQU 12h		; Address of PortC.
	CWRadr 	EQU 13h		; Address of Control Word Register (CWR).

;8255 Port Configuration Mode:
	pAoChoCliBo EQU 81h		; A out, C high out, C low in, B out.	
	pAiChoCliBo EQU 91h		; A in,  C high out, C low in, B out. Used by busy-check function.
	
;8255 Bit Configuration Mode. Bit set/reset Commands for the E, RW, RS LCD lines:
;NOTE: With bit 7 being 0 instead of 1, we are in Bit Config Mode and not Port Config Mode.
;      These commands will apply to only Port C:
	Command EQU 0ah		; Reset LCD bit #4   portC bit #5(RS) 101-0
	Data 	EQU 0bh		;   Set LCD bit #4   portC bit #5(RS) 101-1
	Write 	EQU 0ch		; Reset LCD bit #5   portC bit #6(RW) 110-0
	Read 	EQU 0dh		;   Set LCD bit #5   portC bit #6(RW) 110-1
	Disable	EQU 0eh		; Reset LCD bit #6   portC bit #7(E)  111-0
	Enable 	EQU 0fh		;   Set LCD bit #6   portC bit #7(E)  111-1 
	
; Define number of Commands and length of string Data
	numComm	EQU 4h		; Number of Commands.
	numData	EQU 10h	    ; Number of string bytes.
	
; Initialize RAM and 8255:		
	LD SP, 81FFh 		; Set stack pointer to top of 512B.
	LD C, CWRadr 
	LD A, pAoChoCliBo 	; Port mode config command to 8255: A out, C high out, C low in, B out.
	OUT (C), A

			
REPEAT:	CALL Delay
	
; Config the LCD
	LD A, 38h			; Function set Command: 8-bit mode, AC=0, 2 lines, 5x7 characters.

initLCD: LD C, CWRadr		
	LD D, Command		  
	OUT (C), D			; Set RS low for command (select the instruction register).
	LD D, Write
	OUT (C), D			; Reset RW pin for writing to LCD.
	OUT (pAadr), A		; Place the 38h Command into portA.
	LD D, Enable		; Start LCD pulse.
	OUT (C), D			; ......Enable the LCD. 
	Call Delay			; ......Slow the pulse.
	LD D, Disable		; ......Disable the LCD.
	OUT (C), D			; End LCD pulse.

	
; This part sends 4 Commands to the LCD (clear display, set DD RAM address, turn on display with 
; cursor hidden, and set entry mode 6):
	LD HL, commBeginAdr 	; Set HL to point the first Command.
	LD B, numComm			; Put the number of Commands to be sent in B.
nextComm: CALL sendCommHL	; Send (HL) as a Command.
	INC HL					; Point to the next Command.
	DJNZ nextComm			; Loop until all 4 Commands are sent.
	
; This part sends Data strings to the LCD:
	LD HL, DataBegAdr	; Set HL to point the first string byte.
	LD B, numData		; Put the number of string Data bytes to be sent in B.
nextData:			
	CALL sendCharHL		; Send (HL) as string Data. 
	INC HL				; Point to the next string byte.
	DJNZ nextData		; Loop until all string bytes are sent.
	;HALT
	JP REPEAT	
	
; sendCharA sends the Data in A to the LCD. sendCharHL sends the Data in (HL) to the LCD.
; sendCommA sends the Command in A to the LCD. sendCommHL sends the Command in (HL) to the LCD.
sendCharHL:
	LD A, (HL)		; Put the Data to be sent to the LCD in A.
sendCharA:	
	PUSH BC			; Save BC and DE on Stack.
	PUSH DE			
	LD E, Data	  	
	JP Common

sendCommHL:
	LD A,(HL)
sendCommA:	
	PUSH BC			; Save BC & DE on Stack.
	PUSH DE			

Common:					; Removed BusyCheck...
	OUT (C), E			; Set/reset RS according to the content of register E (Command or Data).
	LD D, Write		
	OUT (C), D			; Reset RW pin (low) for writing to LCD.
	OUT (pAadr), A		; Place Data/instruction to be written into portA.
	PUSH HL				; ------------Save HL (HL is also used by Delay).
	CALL longDelay		; ------------Delay added between characters reads can create a scroll effect.
	POP HL				; ------------Recover HL. 
	LD D, Enable		; Start LCD pulse.
	OUT (C), D			; ......Enable the LCD. 
	LD D, Disable		; ......Disable the LCD. 
	OUT (C), D			; End LCD pulse.
	POP DE				; Restore DE.
	POP BC				; Restore BC.
	RET					; Return to CALLer.

; pDelay uses what you put into HL before you called the PDelay routine. 
longDelay:
	LD HL, 3F3Fh
	JP pDelay
Delay:	
	LD HL, 0200h		; Originally 1010h. 0200h is adequate to avoid busy-check function. 3F3Fh = slow scroll.
pDelay:	
	DEC L
	JP NZ, pDelay
	DEC H
	JP NZ, pDelay
	RET				; Return to CALLer.
	
; 4 Commands and 16-character string
commBeginAdr:
	db 01h,80h,0ch,06h  	; Clear display,set DD RAM adress, turn on display with cursor hidden,
	                        ; and set entry mode
DataBegAdr:	
	db 20h,21h,21h,20h,5ah,65h,64h,38h,30h,2eh,63h,6Fh,6Dh,20h,21h,21h ; !! Zed80.com !!
	  ; 0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f