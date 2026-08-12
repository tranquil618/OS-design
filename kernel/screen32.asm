;=================================
; screen32.asm
; OrangeOS 32位屏幕模块
;=================================
[BITS 32]
global clear_screen32
global scroll_input32
global screen_scrollback_up32
global screen_scrollback_down32

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

; Scroll rows 3-25 upward while preserving the two status rows.
scroll_input32:
    push eax
    push ecx
    push esi
    push edi

    cmp byte [scrollback_active],0
    jne .skip_capture
    mov esi,scrollback_lines+160
    mov edi,scrollback_lines
    mov ecx,15*80
    rep movsw
    mov esi,VGA_MEMORY+320
    mov ecx,80
    rep movsw
    cmp dword [scrollback_count],16
    jae .skip_capture
    inc dword [scrollback_count]
.skip_capture:

    cld
    mov esi,VGA_MEMORY+480
    mov edi,VGA_MEMORY+320
    mov ecx,22*80
    rep movsw

    mov edi,VGA_MEMORY+320+22*160
    mov ecx,80
    mov ax,DEFAULT_CELL
    rep stosw

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

screen_scrollback_up32:
    pushad
    mov ebx,[scrollback_count]
    test ebx,ebx
    jz .up_done
    cmp byte [scrollback_active],0
    jne .up_done
    mov esi,VGA_MEMORY+320
    mov edi,scrollback_live
    mov ecx,23*80
    rep movsw
    mov byte [scrollback_active],1
    mov edi,VGA_MEMORY+320
    mov ecx,23*80
    mov ax,DEFAULT_CELL
    rep stosw
    mov eax,16
    sub eax,ebx
    imul esi,eax,160
    add esi,scrollback_lines
    mov eax,23
    sub eax,ebx
    imul edi,eax,160
    add edi,VGA_MEMORY+320
    imul ecx,ebx,80
    rep movsw
    mov edi,VGA_MEMORY+320+2*79
    mov ecx,23
.bar:
    mov word [edi],0x7020
    add edi,160
    loop .bar
    mov word [VGA_MEMORY+320+2*79],0x705E
.up_done:
    popad
    ret

screen_scrollback_down32:
    pushad
    cmp byte [scrollback_active],0
    je .down_done
    mov esi,scrollback_live
    mov edi,VGA_MEMORY+320
    mov ecx,23*80
    rep movsw
    mov byte [scrollback_active],0
.down_done:
    popad
    ret

align 4
scrollback_count: dd 0
scrollback_active: db 0
align 4
scrollback_lines: times 16*80 dw DEFAULT_CELL
scrollback_live:  times 23*80 dw DEFAULT_CELL
