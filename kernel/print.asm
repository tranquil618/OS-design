;=================================
; print.asm
; OrangeOS 字符输出模块
;=================================

[BITS 16]
global print_string
global print_color_string

;---------------------------------
; print_string
; 功能:
; 输出字符串
; 输入:
; DS:SI  字符串地址
; ES:DI  显存位置
; 输出:
; 屏幕显示字符
;---------------------------------
print_string:
    ;SI指向字符串

.loop:
    mov al,[si]

    cmp al,0;
    je .done

    mov [es:di],al
    inc di
    mov byte [es:di],0x07

    inc di
    inc si
    jmp .loop

.done:
    ret

;--------------------------------
; 彩色打印
; 输入:
; DS:SI 字符串
; DS:BX 颜色表
; ES:DI 显存
;--------------------------------
print_color_string:

.color_loop:
    mov al,[si]    ;读取字符

    cmp al,0
    je .color_done
    ;写字符
    mov [es:di],al
    inc di

    ;写颜色
    mov al,[bx]
    mov [es:di],al
    inc di
    ;下一个字符
    inc si
    inc bx

    jmp .color_loop

.color_done:
    ret