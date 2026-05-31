//https://www.jameco.com/Jameco/Products/ProdDS/52417OKI.pdf
    PPIBase: equ $40
	PortA:	EQU PPIBase + 0
	PortB:	EQU PPIBase + 1
	PortC:	EQU PPIBase + 2
	CWR:	EQU PPIBase + 3

pc_8255_init:

	LD A, %10000000
	// 1 00 0 0 0 0 0
	// ^ ^^ ^ ^ ^ ^ ^
	// | || | | | | |
	// | || | | | | Port C (LOWER) 1=in or 0=out
	// | || | | | Port B 1=in or 0=out
	// | || | | Mode for Port B and Port C (LOWER)
	// | || | Port C (UPPER) 1=in or 0=out
	// | || Port A 1=in or 0=out
	// | Mode for Port A and Port C (UPPER)
	// When 1 - Setup the above
	// When 0 - And Port C is output, individualy set Port C bits via D3, D2, D1, to the value in D0
	//   Mode 0 - Basic input/output
	//   Mode 1 - Strobe input/output
	//   Mode 2 - Strobe bidirectionla bus I/O (only for Port A and Port C (UPPER))
	OUT (CWR), A

	ret