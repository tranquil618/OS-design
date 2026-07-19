;=================================
; print.asm
; OrangeOS 字符输出模块
;=================================

[BITS 16]
;声明外部函数

;全局函数
global print_string
global print_color_string
global put_char
global set_cursor
global newline
global set_terminal_start
;全局变量
global cursor_pos
global terminal_start

;%include "../include/terminal.inc"
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
    mov [cursor_pos],di
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
    mov [cursor_pos],di
    ret

;=================================
; put_char
; 输入:
; AL = 字符
; 功能:
; 在当前位置显示一个字符
;=================================
put_char:

    ;Enter
    cmp al,0x0D
    je do_newline

    ;Backspace
    cmp al,0x08
    je do_backspace

    ;保存字符
    mov ah,al
    ;读取当前位置
    mov bx,[cursor_pos]
    ;写字符
    mov [es:bx],ah
    ;移动到颜色位置
    inc bx
    ;写颜色
    mov byte [es:bx],0x07
    ;下一个字符位置
    inc bx
    ;保存新的位置
    mov [cursor_pos],bx
    ret

do_newline:
    call newline
    ret



;==============================
; set_cursor
; 输入:
; BX = 显存偏移
; 功能:
; 设置当前输出位置
;==============================
set_cursor:
    mov [cursor_pos],bx
    ret

;=================================
; newline
; 功能：光标移动到下一行开头
;=================================
newline:
    mov ax,[cursor_pos]

    ;计算当前列
    mov dx,0
    mov bx,160
    div bx

    ;AX=行号
    ;DX=当前行剩余字节
    
    ;下一行
    inc ax

    ;行号*160
    mul bx

    mov [cursor_pos],ax
    ret


;=================================
; do_backspace
; 功能：实现Backspace的功能
;=================================
do_backspace:
    mov bx,[cursor_pos]

    ;防止删除到屏幕外
    cmp bx,[terminal_start]
    je backspace_done

    ;后退一个字符
    sub bx,2
    ;删除字符
    mov byte [es:bx],' '
    ;恢复颜色
    mov byte [es:bx+1],0x07
    ;保存新位置
    mov [cursor_pos],bx

backspace_done:
    ret

;=================================
; set_terminal_start
; BX = 输入区域开始位置
;=================================
set_terminal_start:
    mov [terminal_start],bx
    mov [cursor_pos],bx
    ret


;========================
; Data
;========================

;========================
; Terminal State
;========================
;当前光标位置
cursor_pos:
    dw 0
;输入区域起始位置
terminal_start:
    dw 0