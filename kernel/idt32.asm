;=================================
; idt32.asm
; OrangeOS 32位中断描述符表
;=================================
[BITS 32]

global idt_init32

extern irq1_keyboard
extern irq0_timer
extern isr_syscall32
extern process_fault_current32

IRQ0_VECTOR equ 0x20
IRQ1_VECTOR equ 0x21
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
    ;安装0号异常
    mov ebx,0x00
    mov eax,isr_divide_error
    call set_idt_gate32

    ; Install the page-fault exception handler (vector 14).
    mov ebx,0x0E
    mov eax,isr_page_fault
    call set_idt_gate32

    ;安装int 0x80
    mov ebx,TEST_VECTOR
    mov eax,isr_syscall32
    call set_idt_gate32
    ; Permit future ring-3 callers to invoke only the system-call gate.
    mov byte [idt_table+TEST_VECTOR*IDT_ENTRY_SIZE+5],11101110b

    ;安装IRQ0
    mov ebx,IRQ0_VECTOR
    mov eax,irq0_timer
    call set_idt_gate32

    ;安装IRQ1键盘中断
    mov ebx,IRQ1_VECTOR
    mov eax,irq1_keyboard
    call set_idt_gate32

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
; Page Fault (vector 14)
; CPU pushes an error code before entering this handler.
;=================================
isr_page_fault:
    cli
    pushad

    ; A CPL3 exception frame contains error/EIP/CS/EFLAGS/user ESP/user SS.
    mov eax,[esp+40]
    and eax,3
    cmp eax,3
    jne .kernel_fault
    mov eax,cr2
    mov ebx,[esp+32]
    mov ecx,[esp+36]
    call process_fault_current32
    mov esp,eax
    popad
    iretd

.kernel_fault:

    mov esi,page_fault_message
    mov edi,0xB8000+320
.print_message:
    lodsb
    test al,al
    jz .print_address
    mov byte [edi],al
    mov byte [edi+1],0x0C
    add edi,2
    jmp .print_message

.print_address:
    mov eax,cr2
    mov ecx,8
.hex_digit:
    rol eax,4
    mov edx,eax
    and edx,0x0F
    mov dl,[page_fault_hex+edx]
    mov byte [edi],dl
    mov byte [edi+1],0x0C
    add edi,2
    loop .hex_digit

.page_fault_halt:
    hlt
    jmp .page_fault_halt

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

page_fault_message:
    db 'PAGE FAULT CR2=0x',0
page_fault_hex:
    db '0123456789ABCDEF'

;=================================
; Interrupt Descriptor Table
;=================================
idt_table:
    times IDT_ENTRIES dq 0

idt_end:

idt_descriptor:
    dw idt_end-idt_table-1
    dd idt_table
