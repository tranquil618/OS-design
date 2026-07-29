;=================================
; shell32.asm
; OrangeOS 32位Shell
;=================================
[BITS 32]

global shell_prompt32

%include "keyboard32.inc"

extern print_string32

VGA_MEMORY equ 0xB8000
INPUT_START equ 320
INPUT_BASE equ VGA_MEMORY+INPUT_START

;=================================
; shell_prompt32
; 显示提示符并更新键盘输入位置
;=================================
shell_prompt32:
    push eax
    push esi
    push edi

    ;获取当前输入区域光标
    call keyboard_get_cursor32

    ;转换成VGA线性地址
    mov edi,INPUT_BASE
    add edi,eax

    ;显示提示符
    mov esi,shell_prompt
    call print_string32

    ;将显存地址重新转换为相对位置
    mov eax,edi
    sub eax,INPUT_BASE
    call keyboard_set_cursor32

    pop edi
    pop esi
    pop eax
    ret


shell_prompt:
    db 'OrangeOS> ',0