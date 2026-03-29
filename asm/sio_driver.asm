
#IFNDEF		SIO_DRIVER
#DEFINE		SIO_DRIVER

; port definitions for the SIO/2 chip
SIO_BASE			equ	$A0
SIO_A_DATA			equ	SIO_BASE + 0 + 0
SIO_A_CTRL			equ	SIO_BASE + 0 + 2
SIO_B_DATA			equ	SIO_BASE + 1 + 0
SIO_B_CTRL			equ	SIO_BASE + 1 + 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Serial I/O-routines  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; sio_init: initializes the SIO/2 for serial communication
; affects: HL, B, C
sio_init:		LD		B, 12					; load B with number of bytes (12)
				LD		HL, sio_init_data		; HL points to start of data
				LD 		C, SIO_A_CTRL			; I/O-port for write
				OTIR							; block write of B bytes to [C] starting from HL
				ret

sio_init_data:	db		$00, %00110000			; write to WR0: error reset
				db		$00, %00011000			; write to WR0: channel reset
				db		$01, %00000000	 		; write to WR1: no interrupts enabled
				db		$03, %11000001			; write to WR3: enable RX 8bit
				;db		$04, %10000100			; write to WR4: clkx32,1 stop bit, no parity
                DB      $04, %11000100     ; Wr4 /64, async mode, no parity
				db		$05, %01101000			; write to WR5: DTR inactive, enable TX 8bit, BREAK off, TX on, RTS inactive


; tx_ready: waits for transmitt buffer to become empty
; affects: none
sio_tx_ready:	push	af
sio_tx_ready_loop:
				in		a, (SIO_A_CTRL)			; read RR0
				bit		2, a					; check if bit 2 is set
				jr		z, sio_tx_ready_loop			; if no - check again
				pop		af
				ret
				
; rx_ready: waits for a character to become available
; affects: none
sio_rx_ready:	push	af
sio_rx_ready_loop:	
				in		a, (SIO_A_CTRL)			; read RR0
				bit		0, a					; check if bit 0 is set
				jr		z, sio_rx_ready_loop		; if no - rx buffer has no data => check again
				pop		af
				ret
				
		
; sends byte in reg A	
; affects: none
sio_putc:			call	sio_tx_ready
				out		(SIO_A_DATA), a			; write charactet
				ret								; return

; getc: waits for a byte to be available and reads it
; returns: A - read byte
sio_getc:			call	sio_rx_ready
				in		a, (SIO_A_DATA)
				ret

#ENDIF