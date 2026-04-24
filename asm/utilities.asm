
;https://www.paleotechnologist.net/?p=2589
delay:
    LD BC, 1h            ;Loads BC with hex 1000
Outer:
    LD DE, 1000h            ;Loads DE with hex 1000
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
