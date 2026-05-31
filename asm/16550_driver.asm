#IFNDEF		PC_16550_DRIVER
#DEFINE		PC_16550_DRIVER

; port definitions for the 16550 chip
uart_base       equ     $20

uart_register_0 equ     uart_base + 0
uart_register_1 equ     uart_base + 1
uart_register_2 equ     uart_base + 2
uart_register_3 equ     uart_base + 3
uart_register_4 equ     uart_base + 4
uart_register_5 equ     uart_base + 5
uart_register_6 equ     uart_base + 6
uart_register_7 equ     uart_base + 7

pc_16550_init:
			ld      a, $80           ; Line control register, Set DLAB=1
			out     (uart_register_3), a

			ld      a, $03           ; 1843200 / (16 * 57600)
			out     (uart_register_0), a
			xor     a
			out     (uart_register_1), a

			ld      a, $03           ; 8N1
			out     (uart_register_3), a

            LD      A, $02            ; Modem control register
            OUT     (uart_register_4), A    ; Enable RTS

			;ld a, %11000000
			;out (uart_register_2), a
 			;LD      A, 87H                  ; FIFO enable, reset RCVR/XMIT FIFO
            ;OUT     (uart_register_2), A

			;LD	   A,$01
			;OUT    (uart_register_1),A			;Enable receive data available interrupt only

			ret
	

getc:
		call    rx_ready
		in      a, (uart_register_0)
		ret

putc:
		call    tx_ready
        out     (uart_register_0), a
		ret


rx_ready:        push    af
rx_ready_loop:   in      a, (uart_register_5)
                bit     0, a
                jp      z, rx_ready_loop
                pop     af
                ret

tx_ready:        push    af
tx_ready_loop:   in      a, (uart_register_5)
                bit     5, a
                jp      z, tx_ready_loop
                pop af
                ret

#ENDIF