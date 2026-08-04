;=================================
; input32.asm
; OrangeOS 32位输入缓冲区
;=================================
[BITS 32]

global input_append32
global input_backspace32
global input_submit32
global input_poll32

global input_buffer
global input_length
global command_ready

%include "shell32.inc"

BUFFER_SIZE equ 64
VGA_MEMORY equ 0xB8000

;=================================
; input_append32
; 输入：
; AL = ASCII字符
; 返回：
; EAX = 1 成功
; EAX = 0 缓冲区不可写
;=================================
input_append32:
    push ecx
    push edx

    ;暂存输入字符
    mov dl,al
    xor eax,eax

    ;上一条命令尚未处理时不接收新字符
    cmp byte [command_ready],0
    jne .done

    mov ecx,[input_length]

    ;为字符串结尾0保留一个字节
    cmp ecx,BUFFER_SIZE-1
    jae .done

    mov [input_buffer+ecx],dl
    inc ecx
    mov [input_length],ecx
    mov byte [input_buffer+ecx],0

    mov eax,1

.done:
    pop edx
    pop ecx
    ret


;=================================
; input_backspace32
; 返回：
; EAX = 1 成功删除
; EAX = 0 当前没有字符
;=================================
input_backspace32:
    push ecx

    xor eax,eax

    cmp byte [command_ready],0
    jne .done

    mov ecx,[input_length]
    cmp ecx,0
    je .done

    dec ecx
    mov [input_length],ecx
    mov byte [input_buffer+ecx],0

    mov eax,1

.done:
    pop ecx
    ret


;=================================
; input_submit32
; 返回：
; EAX = 1 成功提交
; EAX = 0 已有命令等待处理
;=================================
input_submit32:
    push ecx

    xor eax,eax

    cmp byte [command_ready],0
    jne .done

    mov ecx,[input_length]
    mov byte [input_buffer+ecx],0
    mov byte [command_ready],1

    mov eax,1

.done:
    pop ecx
    ret


;=================================
; input_poll32
; Kernel主循环调用
; 当前功能：
; 检测到完整输入后显示R并清空缓冲区
;=================================
input_poll32:
    pushfd
    cli

    cmp byte [command_ready],0
    je .done

    ;先执行命令，再清空缓冲区状态
    mov esi,input_buffer
    call shell_execute32

    mov dword [input_length],0
    mov byte [input_buffer],0
    mov byte [command_ready],0
    
    ;为下一条命令显示提示符
    call shell_prompt32

.done:
    popfd
    ret


;=================================
; Input State
;=================================
input_buffer:
    times BUFFER_SIZE db 0

input_length:
    dd 0

command_ready:
    db 0
