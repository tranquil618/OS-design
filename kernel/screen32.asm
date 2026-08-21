;=================================
; screen32.asm
; OrangeOS 32 位 VGA 文本屏幕与回看缓冲
; 每个 VGA 单元为 2 字节：低字节 ASCII，高字节颜色。前两行保留系统状态，
; 第 3～25 行为 Shell 输入区。滚屏时把被卷走的行保存到 16 行 scrollback 环形窗口。
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

; 把第 3～25 行上移一行，同时保持顶部两行不动。
scroll_input32:
    push eax
    push ecx
    push esi
    push edi

    ; 仅在实时显示模式捕获即将被卷走的顶行；回看时不污染历史内容。
    cmp byte [scrollback_active],0
    jne .skip_capture
    ; 历史缓冲整体左移一行，末尾放入当前输入区最上方一行。
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

    ; VGA 输入区第 4～25 行复制到第 3～24 行，最后一行填空格。
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
    ; 第一次 PageUp 时保存实时屏幕，随后用最近的历史行替换输入区并画右侧滚动条。
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
    ; PageDown 恢复进入回看前保存的 23 行实时画面。
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
