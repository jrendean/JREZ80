
LCDBase: equ $40
lcd_command equ LCDBase + 0 ;LCD command I/O port
lcd_data equ LCDBase + 1    ;LCD data I/O port

lcd_init:
    call delay

    ld a,$3f        ;Function set: 8-bit interface, 2-line, small font
    out (lcd_command),a
    call delay
    call delay

    ld a,$0f        ;Display on, cursor on
    out (lcd_command),a     ;(I find turning the cursor on is very helpful when debugging)
    call delay
    call delay

    ld a,$01        ;Clear display
    out (lcd_command),a
    call delay
    call delay

    ld a,$06        ;Entry mode: left to right, no shift
    out (lcd_command),a
    
    ret


lcd_print:
    ;ld hl,message   ;Message address
message_loop:       ;Loop back here for next character
    ld a,(hl)       ;Load character into A
    and a           ;Test for end of string (A=0)
    jr z,done

    out (lcd_data),a     ;Output the character
    inc hl          ;Point to next character (INC=increment, or add 1, to HL)
    jr message_loop ;Loop back for next character
done:
    ret


delay:
    LD BC, 10h            ;Loads BC with hex 1000
Outer:
    LD DE, 10h            ;Loads DE with hex 1000
Inner:
    DEC DE                  ;Decrements DE
    LD A, D                 ;Copies D into A
    OR E                    ;Bitwise OR of E with A (now, A = D | E)
    JP NZ, Inner            ;Jumps back to Inner: label if A is not zero
    DEC BC                  ;Decrements BC
    LD A, B                 ;Copies B into A
    OR C                    ;Bitwise OR of C with A (now, A = B | C)
    JP NZ, Outer            ;Jumps back to Outer: label if A is not zero
    RET                     ;Return from call to this subroutine
