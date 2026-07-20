;=================================
; kernel.asm
; format: elf32
; OrangeOS Kernel入口
;=================================
;实际加载地址由ld决定
[BITS 16]

global _start
%include "kernel.inc"

_start:
    ;在修改栈段期间关闭中断
    cli
    ;设置Kernel栈
    mov ax,0x1000
    mov ss,ax
    mov sp,0xFFFE
    ;设置数据段
    mov ds,ax
    ;栈设置完成，重新开启中断
    sti
    ;设置显存段
    mov ax,0xb800      ;设置显存段
    mov es,ax

    call clear_screen

    mov si,message      ;SI:Source Index，让SI指向字符串地址
    mov bx,colors       ;颜色表地址
    mov di,28*2         ;di表示显存偏移
    
    call print_color_string
    ;换行
    call newline
    ;显示提示符
    mov si,prompt
    mov di,[cursor_pos]
    call print_string
    ;设置输入区域
    mov bx,[cursor_pos]
    call set_terminal_start
    

;==========================
;键盘循环
;==========================
keyboard_loop:
    call get_key
    ;保存输入
    call input_char
    ;显示输入
    call put_char
    jmp keyboard_loop


halt:
    jmp $


message:
    db 'OrangeOS Kernel Started!',0

prompt:
    db 'OrangeOS>',0

colors:
    ;OrangeOS每个字母一个颜色
    db 0x0C    ;O 亮红
    db 0x0E    ;r 亮黄
    db 0x0A    ;a 亮绿
    db 0x09    ;n 亮蓝
    db 0x0D    ;g 亮紫
    db 0x0B    ;e 亮青
    db 0x0F    ;O 亮白
    db 0x06    ;S 棕黄

    ;后面的Kernel Started!统一白色
    db 0x07    ;空格
    
    ;Kernel Started!
    times 15 db 0x07

