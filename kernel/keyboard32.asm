;=================================
; keyboard32.asm
; PS/2键盘IRQ1处理
;=================================
[BITS 32]
global irq1_keyboard
global keyboard_get_cursor32
global keyboard_set_cursor32

%include "input32.inc"

KEYBOARD_DATA equ 0x60
PIC1_COMMAND equ 0x20
PIC_EOI equ 0x20

VGA_MEMORY equ 0xB8000
INPUT_START equ 320
INPUT_AREA_SIZE equ 23*160

;=================================
; IRQ1键盘中断处理程序
;=================================
irq1_keyboard:
    pushad

    ;读取键盘扫描码
    in al,KEYBOARD_DATA
    ;处理左Shift释放
    cmp al,0xAA
    je .left_shift_release

    ;处理右Shift释放
    cmp al,0xB6
    je .right_shift_release
    ;最高位为1表示键盘释放，暂时忽略
    test al,0x80
    jnz .send_eoi
    ;处理左Shift按下
    cmp al,0x2A
    je .left_shift_press

    ;处理右Shift按下
    cmp al,0x36
    je .right_shift_press
    ;处理Backspace
    cmp al,0x0E
    je .backspace
    ;处理Enter
    cmp al,0x1C
    je .enter
    ;将扫描码转换为数组索引
    movzx eax,al
    ;检查是否超过当前映射表
    cmp eax,scan_code_table_end-scan_code_table
    jae .send_eoi
    ;默认使用普通映射表
    mov dl,[scan_code_table+eax]

    ;Shift没有按下则直接使用普通字符
    cmp byte [shift_state],0
    je .ascii_ready

    ;Shift按下时使用大写/符号映射表
    mov dl,[scan_code_shift_table+eax]

.ascii_ready:
    test dl,dl
    jz .send_eoi
    
    ;写入输入缓冲区
    mov al,dl
    call input_append32

    ;缓冲区已满或正在等待处理时不显示
    test eax,eax
    jz .send_eoi

    ;读取当前键盘输出位置
    mov edi,[keyboard_cursor]
    ;在屏幕第三行显示字符
    mov byte [0xB8000+INPUT_START+edi],dl
    mov byte [0xB8000+INPUT_START+edi+1],0x0F
    ;移动到下一个字符位置
    add edi,2
    ;到达行尾后回到第三行开头
    cmp edi,INPUT_AREA_SIZE
    jb .save_cursor
    xor edi,edi

.save_cursor:
    mov [keyboard_cursor],edi
    jmp .send_eoi

;=================================
; Shift状态处理
;=================================
.left_shift_press:
    or byte [shift_state],00000001b
    jmp .send_eoi

.right_shift_press:
    or byte [shift_state],00000010b
    jmp .send_eoi

.left_shift_release:
    and byte [shift_state],11111110b
    jmp .send_eoi

.right_shift_release:
    and byte [shift_state],11111101b
    jmp .send_eoi
;=================================
; Enter
;=================================
.enter:
    ;提交当前输入缓冲区
    call input_submit32

    ;已有命令等待处理时不重复换行
    test eax,eax
    jz .send_eoi

    mov eax,[keyboard_cursor]

    ;计算当前行号
    xor edx,edx
    mov ecx,160
    div ecx

    ;移动到下一行
    inc eax
    imul edi,eax,160

    ;超过输入区域后回到起点
    cmp edi,INPUT_AREA_SIZE
    jb .save_cursor

    xor edi,edi
    jmp .save_cursor

;=================================
; Backspace
;=================================
.backspace:
    ;先删除输入缓冲区字符
    call input_backspace32
    ;缓冲区没有字符时不删除屏幕内容
    test eax,eax
    jz .send_eoi
    mov edi,[keyboard_cursor]
    ;向前移动一个字符
    sub edi,2
    ;使用空格覆盖原字符
    mov byte [VGA_MEMORY+INPUT_START+edi],' '
    mov byte [VGA_MEMORY+INPUT_START+edi+1],0x07
    ;保存新的光标位置
    mov [keyboard_cursor],edi
    jmp .send_eoi


.send_eoi:
    ;向主PIC发送EOI
    mov al,PIC_EOI
    out PIC1_COMMAND,al

    popad
    iretd

;=================================
; keyboard_get_cursor32
; 返回：
; EAX = 输入区相对光标位置
;=================================
keyboard_get_cursor32:
    mov eax,[keyboard_cursor]
    ret


;=================================
; keyboard_set_cursor32
; 输入：
; EAX = 输入区相对光标位置
;=================================
keyboard_set_cursor32:
    ;超过输入区域时回到起点
    cmp eax,INPUT_AREA_SIZE
    jb .save

    xor eax,eax

.save:
    mov [keyboard_cursor],eax
    ret

keyboard_cursor:
    dd 0

;Shift状态
;Bit 0=左Shift
;Bit 1=右Shift
shift_state:
    db 0
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
    
;=================================
; Shift按下时的映射表
; 必须与普通映射表保持相同长度
;=================================
scan_code_shift_table:
    ;0x00-0x01
    db 0,0
    ;0x02-0x0D
    db '!@#$%^&*()_+'
    ;0x0E-0x0F
    db 0,0
    ;0x10-0x1B
    db 'QWERTYUIOP{}'
    ;0x1C-0x1D
    db 0,0
    ;0x1E-0x29
    db 'A','S','D','F','G','H','J','K','L',':',34,'~'
    ;0x2A
    db 0
    ;0x2B
    db '|'
    ;0x2C-0x35
    db 'ZXCVBNM<>?'
    ;0x36-0x38
    db 0,'*',0
    ;0x39
    db ' '
scan_code_shift_table_end: