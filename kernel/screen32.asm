;=================================
; screen32.asm
; OrangeOS 32位屏幕模块
;=================================
[BITS 32]
global clear_screen32

VGA_MEMORY equ 0xB8000
SCREEN_SIZE equ 80*25
DEFAULT_CELL equ 0x0720     ;表示 空格字符+黑底白字   注：x86使用小端序，低字节字符，高字节颜色

;=================================
; clear_screen32
; 功能：
; 清空VGA文本屏幕
;=================================
clear_screen32:
    ;保存调用者寄存器
    push eax
    push ecx
    push edi

    mov edi,VGA_MEMORY
    mov ecx,SCREEN_SIZE
    mov ax,DEFAULT_CELL
    cld
    rep stosw

    ;回复调用者寄存器
    pop edi
    pop ecx
    pop eax
    ret
