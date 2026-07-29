;=================================
; kernel32.asm
; OrangeOS 32位Kernel入口
;=================================
[BITS 32]

global _start
%include "kernel32.inc"

;CODE_SELECTOR equ 0x08
DATA_SELECTOR equ 0x10

section .text

_start:
    ;建立CPU异常和软件中断门并加载IDT
    cli

    ;重新初始化32位段寄存器
    mov ax,DATA_SELECTOR
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax

    ;初始化32位Kernel栈
    mov esp,0x90000

    ;字符串操作向高地址进行
    cld

    ;清空VGA文本屏幕
    call clear_screen32

    ;显示Kernel启动信息
    mov esi,kernel_message
    mov edi,0xB8000
    call print_string32
    ;显示Shell提示符
    call shell_prompt32
    ;初始化并加载IDT
    call idt_init32
    ;初始化并重映射PIC
    call pic_init32
    ;初始化PIT时钟
    call pit_init32
    ;开启硬件中断
    sti

    ;开启硬件中断

.idle:
    ;等待硬件中断
    hlt
    ;处理中断产生的完整输入
    call input_poll32
    jmp .idle

.halt:
    cli
    hlt
    jmp .halt


kernel_message:
    db 'OrangeOS 32-bit Kernel Started!',0