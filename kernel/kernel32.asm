;==============================================================================
; OrangeOS 32 位 Kernel 总入口
; Loader 已完成：Kernel 装载到 0x10000、进入保护模式、建立临时平坦 GDT 和栈。
; 本文件按依赖顺序初始化正式 GDT/TSS、显示、中断、内存、用户态、文件系统和调度器。
; 初始化完成后进入 HLT 空闲循环，真正的工作由硬件中断和 Shell 输入驱动。
;==============================================================================
[BITS 32]

global _start
%include "kernel32.inc"
extern process_init32
extern memory_init32
extern paging_init32
extern fs_init32
extern heap_init32
extern gdt_init32
extern usermode_init32

;CODE_SELECTOR equ 0x08
DATA_SELECTOR equ 0x10

section .text

_start:
    ; IDT/PIC 尚未就绪，初始化全过程先保持 IF=0。
    cli

    ; Loader 的平坦数据段选择子为 0x10。显式重载所有数据段，建立确定状态。
    mov ax,DATA_SELECTOR
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax

    ; 临时启动栈。x86 栈向低地址增长。
    mov esp,0x90000

    ; 清除方向标志，使 REP MOVS/STOS 默认从低地址向高地址处理。
    cld

    ; 用 Kernel 正式 GDT 替换 Loader 临时 GDT，并执行 LTR 加载 Ring 0 TSS。
    call gdt_init32

    ; 从这里开始建立用户可见环境。
    call clear_screen32

    ;显示Kernel启动信息
    mov esi,kernel_message
    mov edi,0xB8000
    call print_string32
    ;显示Shell提示符
    call shell_prompt32
    ; IDT 必须先于 PIC/PIT 初始化，避免硬件 IRQ 到来时没有有效的门。
    call idt_init32
    ;初始化并重映射PIC
    call pic_init32
    ;初始化PIT时钟
    call pit_init32
    ; 读取 Loader 放在 0x0504/0x0508 的 E820 地图，建立 4 KiB 物理页位图。
    call memory_init32
    ; 建立恒等映射页表并设置 CR0.PG，此后启用硬件分页。
    call paging_init32
    ; 初始化可动态分配的 Ring 3 代码、数据和栈页框架。
    call usermode_init32
    ; 在页分配器之上建立 first-fit 内核堆。
    call heap_init32
    ; 通过 ATA PIO 读取 OrangeFS；无有效目录时格式化默认文件系统。
    call fs_init32
    ; 最后初始化 PCB 和调度状态，因为定时器中断会读取这些结构。
    call process_init32
    ; 所有中断依赖已经就绪，现在才允许 IRQ0/IRQ1 进入 CPU。
    sti

.idle:
    ; HLT 在 IF=1 时休眠到下一次中断，比持续空转节省 CPU。
    hlt
    ; 键盘 IRQ 只负责收集字符；完整命令在普通内核上下文中解析执行。
    call input_poll32
    jmp .idle

.halt:
    cli
    hlt
    jmp .halt


kernel_message:
    db 'OrangeOS 32-bit Kernel Started!',0
