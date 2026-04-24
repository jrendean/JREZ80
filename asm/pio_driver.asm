    PIOBase: equ $20
	PIOAD:	EQU PIOBase + 0
	PIOBD:	EQU PIOBase + 1
	PIOAC:	EQU PIOBase + 2
	PIOBC:	EQU PIOBase + 3

pio_init:
	; init pio
	LD	A, 0xcf ; bit mode (mode 3)
	OUT	(PIOAC), A
	LD	A, 0x00 ; all ports are output
	OUT	(PIOAC), A
    ret

pio_output_a:
  OUT   (PIOAD), A
  ret