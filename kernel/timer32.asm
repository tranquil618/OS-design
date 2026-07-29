;=================================
; timer32.asm
; PIT时钟与IRQ0处理
;=================================
[BITS 32]

global pit_init32
global irq0_timer

PIT_COMMAND equ 0x43
PIT_CHANNEL0 equ 0x40
PIC1_COMMAND equ 0x20
PIC_EOI equ 0x20

PIT_DIVISOR equ 11931

;=================================
; pit_init32
; 将PIT频率设置为约100Hz
;=================================
pit_init32:
    push eax

    ;通道0、先低字节后高字节、模式3
    mov al,0x36
    out PIT_COMMAND,al

    ;写入分频值低字节
    mov ax,PIT_DIVISOR
    out PIT_CHANNEL0,al

    ;写入分频值高字节
    mov al,ah
    out PIT_CHANNEL0,al

    pop eax
    ret


;=================================
; IRQ0时钟中断处理程序
;=================================
irq0_timer:
    pushad

    ;增加系统时钟计数
    inc dword [timer_ticks]

    ;根据计数选择旋转符号
    mov eax,[timer_ticks]
    ;每16次时钟中断才切换一次符号
    shr eax,4
    ;在四个符号之间循环
    and eax,0x03
    mov dl,[spinner+eax]

    ;在屏幕第二行显示黄色旋转符号
    mov byte [0xB8000+160],dl
    mov byte [0xB8000+161],0x0E

    ;向主PIC发送EOI
    mov al,PIC_EOI
    out PIC1_COMMAND,al

    popad
    iretd


timer_ticks:
    dd 0

spinner:
    db '|','/','-','\'