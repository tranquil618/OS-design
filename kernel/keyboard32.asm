;=================================
; keyboard32.asm
; PS/2键盘IRQ1处理
;=================================
[BITS 32]
global irq1_keyboard

KEYBOARD_DATA equ 0x60
PIC1_COMMAND equ 0x20
PIC_EOI equ 0x20

;=================================
; IRQ1键盘中断处理程序
;=================================
irq1_keyboard:
    pushad

    ;读取键盘扫描码
    in al,KEYBOARD_DATA
    ;最高位为1表示键盘释放，暂时忽略
    test al,0x80
    jnz .send_eoi
    ;将扫描码转换为数组索引
    movzx eax,al
    ;检查是否超过当前映射表
    cmp eax,scan_code_table_end-scan_code_table
    jae .send_eoi
    ;转换为ASCII字符
    mov dl,[scan_code_table+eax]
    ;值为0表示暂不处理该按键
    test dl,dl
    jz .send_eoi
    ;读取当前键盘输出位置
    mov edi,[keyboard_cursor]
    ;在屏幕第三行显示字符
    mov byte [0xB8000+320+edi],dl
    mov byte [0xB8000+321+edi],0x0F
    ;移动到下一个字符位置
    add edi,2
    ;到达行尾后回到第三行开头
    cmp edi,160
    jb .save_cursor
    xor edi,edi

.save_cursor:
    mov [keyboard_cursor],edi

.send_eoi:
    ;向主PIC发送EOI
    mov al,PIC_EOI
    out PIC1_COMMAND,al

    popad
    iretd

keyboard_cursor:
    dd 0

;=================================
; Scan Code Set 1基础映射表
;=================================
scan_code_table:
    ;0x00-0x01:无效、Esc
    db 0,0

    ;0x02-0x0D
    db '1234567890-='
    ;0x0E-0x0F:Backspace、Tab
    db 0,0
    ;0x10-0x1B
    db 'qwertyuiop[]'
    ;0x1C-0x1D：Enter、Ctrl
    db 0,0
    ;0x1E-0x29
    db "asdfghjkl;'`"
    ;0x2A：左Shift
    db 0
     ;0x2B：反斜杠
    db 92
    ;0x2C-0x35
    db 'zxcvbnm,./'
    ;0x36-0x38：右Shift、数字键盘*、Alt
    db 0,'*',0
    ;0x39：空格
    db ' '  

scan_code_table_end:
    