;=================================
; input.asm
; OrangeOS 输入缓冲区
;=================================
[BITS 16]
global input_char
global input_clear
global input_buffer

;最大输入长度
BUFFER_SIZE equ 64

;输入缓冲区
input_buffer:
    times BUFFER_SIZE db 0

;当前输入位置
buffer_index:
    dw 0

;=================================
; input_char
; AL = 输入字符
;=================================
input_char:
    ;判断回车
    cmp al,0x0D
    je .enter

    ;判断退格
    cmp al,0x08
    je .backspace

    ;普通字符
    mov bx,[buffer_index]
    cmp bx,BUFFER_SIZE-1
    jae .done

    mov [input_buffer+bx],al
    inc bx
    mov [buffer_index],bx

.done:
    ret

;=================================
; 回车
;=================================
.enter:
    mov bx,[buffer_index]
    mov byte [input_buffer+bx],0
    ret

;=================================
; 删除字符
;=================================
.backspace:
    cmp word [buffer_index],0
    je .done

    dec word [buffer_index]

    mov bx,[buffer_index]
    mov byte [input_buffer+bx],0

;=================================
; 清空输入
;=================================
input_clear:
    mov word [buffer_index],0
    ret

