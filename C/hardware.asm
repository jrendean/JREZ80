SECTION code_user

PUBLIC fputc_cons_native
PUBLIC _fputc_cons_native

PUBLIC fgetc_cons
PUBLIC _fgetc_cons

SIO_BASE			equ	$80
SIO_A_DATA			equ	SIO_BASE + 0 + 0
SIO_A_CTRL			equ	SIO_BASE + 0 + 2


fputc_cons_native:
_fputc_cons_native:
    pop     bc  ;return address
    pop     hl  ;character to print in l
    push    hl
    push    bc
    
push	af
sio_tx_ready_loop:
        in		a, (SIO_A_CTRL)			; read RR0
        bit		2, a					; check if bit 2 is set
        jr		z, sio_tx_ready_loop			; if no - check again
        pop		af
out		(SIO_A_DATA), a	

    ret

fgetc_cons:
_fgetc_cons:

push	af
sio_rx_ready_loop:	
    in		a, (SIO_A_CTRL)			; read RR0
    bit		0, a					; check if bit 0 is set
    jr		z, sio_rx_ready_loop		; if no - rx buffer has no data => check again
    pop		af
in		a, (SIO_A_DATA)

    ld      l,a     ;Return the result in hl
    ld      h,0
    ret

