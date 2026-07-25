;=================================
; idt32.asm
; OrangeOS 32位中断描述符表
;=================================
[BITS 32]

global idt_init32

CODE_SELECTOR equ 0x08
IDT_ENTRIES equ 256
IDT_ENTRY_SIZE equ 8
TEST_VECTOR equ 0x80

section .text

;=================================
; idt_init32
; 功能：
; 建立int 0x80中断门并加载IDT
;=================================
idt_init32:
   ;安装0号除零异常处理程序
    mov ebx,0x00
    mov eax,isr_divide_error
    call set_idt_gate32

    ;安装0x80软件中断处理程序
    mov ebx,TEST_VECTOR
    mov eax,isr_test
    call set_idt_gate32

    ;加载IDT
    lidt [idt_descriptor]
    ret

;=================================
; set_idt_gate32
; 输入：
; EBX = 中断向量号
; EAX = 中断处理函数地址
;=================================
set_idt_gate32:
    ;保存被本函数修改的寄存器
    push edi
    ;计算对应IDT门的地址
    mov edi,idt_table
    lea edi,[edi+ebx*IDT_ENTRY_SIZE]
    ;处理函数地址低16位
    mov word [edi],ax
    ;Kernel代码段选择子
    mov word [edi+2],CODE_SELECTOR
    ;保留字节
    mov byte [edi+4],0
    ;P=1、DPL=0、32位中断门
    mov byte [edi+5],10001110b
    ;处理函数地址高16位
    shr eax,16
    mov word [edi+6],ax
    pop edi
    ret

;=================================
; 0号异常：Divide Error
;=================================
isr_divide_error:
    cli

    ;在屏幕第三行显示红色DIV0
    mov byte [0xB8000+320],'D'
    mov byte [0xB8000+321],0x0C

    mov byte [0xB8000+322],'I'
    mov byte [0xB8000+323],0x0C

    mov byte [0xB8000+324],'V'
    mov byte [0xB8000+325],0x0C

    mov byte [0xB8000+326],'0'
    mov byte [0xB8000+327],0x0C

.halt:
    hlt
    jmp .halt

;=================================
; int 0x80测试处理函数
;=================================
isr_test:
    ;保存通用寄存器
    pushad

    ;在屏幕第二行显示黄色字符I
    mov byte [0xB8000+160],'I'
    mov byte [0xB8000+161],0x0E
    ;恢复通用寄存器
    popad
    ;从32位中断返回
    iretd

;=================================
; Interrupt Descriptor Table
;=================================
idt_table:
    times IDT_ENTRIES dq 0

idt_end:

idt_descriptor:
    dw idt_end-idt_table-1
    dd idt_table