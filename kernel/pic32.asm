;=================================
; pic32.asm
; 8259A PIC初始化
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
    ;ICW1:开始初始化
    mov al,0x11
    out PIC1_COMMAND,al
    call io_wait
    out PIC2_COMMAND,al
    call io_wait

    ;ICW2:设置中断向量起点
    mov al,0x20
    out PIC1_DATA,al
    call io_wait

    mov al,0x28
    out PIC2_DATA,al
    call io_wait

    ;ICW3:设置主从PIC连接关系
    mov al,0x04
    out PIC1_DATA,al
    call io_wait

    mov al,0x02
    out PIC2_DATA,al
    call io_wait

    ;ICW4：使用8086模式
    mov al,0x01
    out PIC1_DATA,al
    call io_wait
    out PIC2_DATA,al
    call io_wait

    ;主PIC开放IRQ0时钟和IRQ1键盘
    mov al,0xFC
    out PIC1_DATA,al

    ;从PIC全部屏蔽
    mov al,0xFF
    out PIC2_DATA,al

    pop eax
    ret

;=================================
; 短暂IO延迟
;=================================
io_wait:
    out 0x80,al
    ret


