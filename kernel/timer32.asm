;=================================
; timer32.asm
; PIT 时钟与 IRQ0 处理
; PIT 输入频率约 1.193182 MHz，除以 11931 后约为 100 Hz，即每个 tick 约 10 ms。
; 每次 IRQ0 保存寄存器、累计 tick、发送 EOI，再让调度器选择应恢复的寄存器帧。
;=================================
[BITS 32]

global pit_init32
global irq0_timer
global timer_get_ticks32

extern scheduler_switch32

PIT_COMMAND equ 0x43
PIT_CHANNEL0 equ 0x40
PIC1_COMMAND equ 0x20
PIC_EOI equ 0x20

PIT_DIVISOR equ 11931          ; 1193182 / 11931 ≈ 100 Hz

;=================================
; pit_init32
; 将PIT频率设置为约100Hz
;=================================
pit_init32:
    push eax

    ; 0x36：通道0、先低后高、模式3方波、二进制计数。
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
    ; pushad 后 ESP 指向完整的通用寄存器快照；调度器可以返回另一任务的 ESP。
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

    ; 在切换任务前发送 EOI，允许 PIC 继续产生后续时钟中断。
    mov al,PIC_EOI
    out PIC1_COMMAND,al

    ; EAX=当前帧 ESP；返回 EAX=本次应恢复的任务帧 ESP。
    mov eax,esp
    call scheduler_switch32
    mov esp,eax

    popad
    iretd

timer_get_ticks32:
    mov eax,[timer_ticks]
    ret


timer_ticks:
    dd 0

spinner:
    db '|','/','-','\'
