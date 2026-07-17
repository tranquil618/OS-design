;=========================
; screen.asm
; 屏幕相关函数
;=========================
[BITS 16]
global clear_screen

clear_screen:
    mov di,0
    mov cx,2000

clear_loop:
    mov byte [es:di],' '
    inc di

    mov byte [es:di],0x07
    inc di

    loop clear_loop

    ret