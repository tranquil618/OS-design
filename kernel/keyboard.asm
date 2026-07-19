;=================================
; keyboard.asm
; OrangeOS 键盘驱动
;=================================
[BITS 16]

global get_key

;%include "../include/io.inc"
;---------------------------------
; get_key
; 功能：
; 获取一个键盘输入
; 返回：
; AL = ASCII字符
;---------------------------------
get_key:
    mov ah,0x00     ;表示BIOS键盘功能读取键盘
    int 0x16        ;调用BIOS键盘中断，返回AL=ASCII

    ret