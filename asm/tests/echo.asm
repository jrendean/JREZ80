;***************************************************************************
;  PROGRAM:	UART Echo Test Program        
;  PURPOSE:	Any key typed on PC will display, any text file sent (use Tera Term v4.99) will echo back.  
;***************************************************************************

UARTbase:	EQU $80   			; UART uses addresses 08h to 0Fh. PPI uses addresses 00h to 03h.
UART_R0:	EQU UARTbase + 0	; Address 08h. (DL-LSB when DLAB bit 7 = 1.) Otherwise, Receiver Buffer Register RBR (read), 
								; Transmitter Holding Register THR (write).
UART_R1:	EQU UARTbase + 1	; Address 09h. (DL-MSB when DLAB bit 7 = 1.) Otherwise, Interrupt Enable Register IER (read/write).
UART_R2:	EQU UARTbase + 2	; Address 0Ah. Interrupt Identification Register (read only). FIFO Control Register FCR (write).
UART_R3:	EQU UARTbase + 3	; Address 0Bh. Line Control Register (LCR). 
UART_R4:	EQU UARTbase + 4	; Address 0Ch. Modem Control Register (MCR).
UART_R5:	EQU UARTbase + 5	; Address 0Dh. Line Status Register (LSR).
UART_R6:	EQU UARTbase + 6	; Address 0Eh. Modem Status Register (MSR).
UART_R7:	EQU UARTbase + 7	; Address 0Fh. Scratch Register.
EOS:         EQU $00		; End of string.
CR :         EQU $0d     ; Carriage return.
LF:          EQU $0a     ; Line feed.
space:       EQU $20     ; Space.
tab:         EQU $09     ; Tabulator.			  

ORG $0000
		LD SP,	$FFFF
	
;***************************************************************************
;	DLAB A2 A1 A0 Register
;   ---------------------- 
;	1    0  0  0  Divisor Latch: (least significant byte). Used during UART Init.
;	1    0  0  1  Divisor Latch: (most significant byte). Used during UART Init.

;	0    0  0  0  Receiver Buffer (read), Transmitter Holding Register (write).
;	0    0  0  1  Interrupt Enable Register IER.
;	X    0  1  0  Interrupt Identification Register IIR (read)
;	X    0  1  0  FIFO Control Register FCR (write)
;	X    0  1  1  Line Control Register LCR.
;	X    1  0  0  MODEM Control Register MCR.
;	X    1  0  1  Line Status Register LSR. Bit 0 - Data Ready Indicator. Bit 5 - THRE indicator.
;	X    1  1  0  MODEM Status Register MSR.
;	X    1  1  1  Scratch Register.

;***************************************************************************
;INIT_UART
;	Function: Initialize the UART to BAUD Rate 1200 (1.8432 MHz clock input)
;***************************************************************************
INIT_UART:
        LD A,	$80				; Mask to Set DLAB Flag
		OUT (UART_R3), A		; LCR.
			
		LD A,	$60				; Divisor = 96 ($60) @ 1200bps w/ 1.8432 Mhz. (Divisor $01 = 115,200bps.)
		OUT (UART_R0), A		; Set BAUD rate to 1200 (Divisor Latch LSB).
		LD A,	$00				; Divisor Latch MSB|LSB: $0060.
		OUT (UART_R1), A		; Set BAUD rate to 1200 (Divisor Latch MSB).
			
		LD A,	$03				; LCR.
		OUT (UART_R3), A	    ; Set 8-bit data, no parity, 1 stop bit, *reset* DLAB Flag.
						
MAIN:
		LD 	A,	$00		
			
;***************************************************************************
;GET_CHAR_UART
;Function: Get current character from UART and put in Accumulator.
;***************************************************************************
GET_CHAR_UART:   
		IN A,	(UART_R5)		; Get the line status register's contents.
		BIT 0,	A				; Tests if bit 0 (receiver Data Ready indicator DR) in LSR is 0 and sets the Z flag. 
		JP Z,	GET_CHAR_UART	; Bit 0 is set to a 1 whenever a complete incoming character is received and transferred to the RBR/FIFO.
		IN A,	(UART_R0)		; Get character from the UART. 
		LD B,	A				; Store character into B Register.
			
;***************************************************************************
;SEND_CHAR_UART
;Function: Send current character in Accumulator to UART.
;***************************************************************************
SEND_CHAR_UART:   
		IN A,	(UART_R5)		; Get the line status register's contents
		BIT 5,	A				; Read LSR THRE indicator. Test BIT 5, it will be set if the UART is ready to send.
		JP Z,	SEND_CHAR_UART	; If 0, no data sent so loop. Set to 1 if character in THR is sent to the Transmitter Shift Register so return to putChar.
		LD A,	B		    	; Get character from B Register obtained earlier
		OUT (UART_R0), A		; Send character through the UART. 
			
	JP  MAIN
			
.END			