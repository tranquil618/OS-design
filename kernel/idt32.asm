;=================================
; idt32.asm
; OrangeOS 32 位中断描述符表（IDT）
; 当前安装：#DE(0)、#PF(14)、IRQ0(0x20)、IRQ1(0x21) 和系统调用门(0x80)。
; 普通门 DPL=0，仅内核可用；int 0x80 单独设为 DPL=3，允许 Ring 3 主动进入内核。
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

    ; #PF 向量 14。CPU 进入处理器前会额外压入 page-fault error code。
    mov ebx,0x0E
    mov eax,isr_page_fault
    call set_idt_gate32

    ;安装int 0x80
    mov ebx,TEST_VECTOR
    mov eax,isr_syscall32
    call set_idt_gate32
    ; type=32位中断门、P=1、DPL=3。用户态只能主动调用这一扇门。
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
    ; P=1、DPL=0、type=1110（32 位中断门）。中断门进入时自动清 IF。
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
; Page Fault（向量14）
; CPU 栈帧：error code、EIP、CS、EFLAGS；跨特权级时后面还有 user ESP、user SS。
; pushad 又压入 32 字节，所以 [ESP+40] 是保存的 CS，[ESP+32] 是错误码。
;=================================
isr_page_fault:
    cli
    pushad

    ; 检查故障前 CS 的 RPL。RPL=3 表示用户进程故障，可以只终止 PID4。
    mov eax,[esp+40]
    and eax,3
    cmp eax,3
    jne .kernel_fault
    mov eax,cr2                 ; CR2 保存导致 #PF 的线性地址
    mov ebx,[esp+32]            ; 页故障错误码（P/W/U/RSVD/I-D）
    mov ecx,[esp+36]            ; 故障指令 EIP
    call process_fault_current32
    mov esp,eax                 ; 调度器返回下一任务的内核寄存器帧
    popad
    iretd

.kernel_fault:
    ; Ring 0 页故障意味着内核自身损坏。显示 CR2 后保护性停机，不尝试继续执行。

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
    ; 256 个向量，每个门描述符 8 字节，共 2048 字节。
    times IDT_ENTRIES dq 0

idt_end:

idt_descriptor:
    dw idt_end-idt_table-1
    dd idt_table
