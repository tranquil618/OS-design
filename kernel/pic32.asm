;=================================
; pic32.asm
; 8259A 可编程中断控制器（PIC）初始化
; x86 异常占用向量 0x00～0x1F，因此必须把硬件 IRQ 从 BIOS 默认位置重映射到
; 0x20～0x2F。本系统只开放主 PIC 的 IRQ0（PIT）和 IRQ1（键盘）。
;=================================
[BITS 32]
global pic_init32

PIC1_COMMAND equ 0x20
PIC1_DATA    equ 0x21
PIC2_COMMAND equ 0xA0
PIC2_DATA    equ 0xA1


;=================================
; pic_init32
; 将IRQ0-15映射到IDT 0x20-0x2F
; 当前开放IRQ0时钟和IRQ1键盘中断
;=================================
pic_init32:
    push eax
    ; ICW1=0x11：边沿触发、级联模式，并要求后续发送 ICW4。
    mov al,0x11
    out PIC1_COMMAND,al
    call io_wait
    out PIC2_COMMAND,al
    call io_wait

    ; ICW2：主 PIC IRQ0～7 映射到 0x20～0x27，从 PIC 映射到 0x28～0x2F。
    mov al,0x20
    out PIC1_DATA,al
    call io_wait

    mov al,0x28
    out PIC2_DATA,al
    call io_wait

    ; ICW3：从 PIC 接在主 PIC 的 IRQ2；从 PIC 的级联编号也为 2。
    mov al,0x04
    out PIC1_DATA,al
    call io_wait

    mov al,0x02
    out PIC2_DATA,al
    call io_wait

    ; ICW4=1：使用 8086/88 中断模式。
    mov al,0x01
    out PIC1_DATA,al
    call io_wait
    out PIC2_DATA,al
    call io_wait

    ; OCW1 中 1=屏蔽、0=开放。0xFC=11111100，只开放 bit0/bit1。
    mov al,0xFC
    out PIC1_DATA,al

    ; 当前没有使用 IRQ8～15，因此从 PIC 全部屏蔽。
    mov al,0xFF
    out PIC2_DATA,al

    pop eax
    ret

;=================================
; 短暂IO延迟
;=================================
io_wait:
    ; 向历史 POST 端口 0x80 写一次，给老式 I/O 设备足够的寄存器锁存时间。
    out 0x80,al
    ret

