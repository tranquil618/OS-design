;==============================================================================
; Kernel 正式 GDT 与 32 位 TSS   Global Descriptor Table 全局描述符表
; 描述符布局：0x00 空、0x08 Ring0代码、0x10 Ring0数据、0x18 Ring3代码、
; 0x20 Ring3数据、0x28 TSS。TSS 的 SS0:ESP0 用于 Ring3 中断进入 Ring0 时换栈。
;==============================================================================
[BITS 32]

global gdt_init32
global gdt_is_ready32

KERNEL_CODE equ 0x08
KERNEL_DATA equ 0x10
TSS_SELECTOR equ 0x28
TSS_ESP0 equ 0x0008F000

gdt_init32:
    pushad
    ; TSS 描述符的 Base 必须填写 tss32 的实际线性地址，分散在描述符三个字段中。
    mov eax,tss32
    mov word [gdt_tss+2],ax
    shr eax,16
    mov byte [gdt_tss+4],al
    mov byte [gdt_tss+7],ah

    mov dword [tss32+4],TSS_ESP0 ; ESP0：特权级切换后的 Ring0 栈顶
    mov word [tss32+8],KERNEL_DATA ; SS0：Ring0 数据/栈段
    mov word [tss32+102],104     ; I/O Map Base=结构末尾，禁止用户态直接使用 I/O 端口

    lgdt [gdt_descriptor]       ; GDTR 指向 Kernel 自己的 GDT
    mov ax,KERNEL_DATA
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov ax,TSS_SELECTOR
    ltr ax                       ; 把 0x28 装入任务寄存器 TR
    mov byte [gdt_ready],1
    popad
    ret

gdt_is_ready32:
    ; 自检模块使用该标志确认正式 GDT/TSS 已成功加载。
    movzx eax,byte [gdt_ready]
    ret

align 8
gdt_start:
    dq 0
    dq 0x00CF9A000000FFFF       ; 0x08：Ring 0 平坦可读代码段
    dq 0x00CF92000000FFFF       ; 0x10：Ring 0 平坦可读写数据段
    dq 0x00CFFA000000FFFF       ; 0x18：DPL=3 的用户代码段
    dq 0x00CFF2000000FFFF       ; 0x20：DPL=3 的用户数据/栈段
gdt_tss:
    dw 103,0                    ; Limit=sizeof(TSS)-1，Base 运行时填写
    db 0,0x89,0,0               ; P=1、DPL=0、可用 32 位 TSS（type 1001）
gdt_end:

gdt_descriptor:
    dw gdt_end-gdt_start-1
    dd gdt_start

align 4
tss32: times 104 db 0
gdt_ready: db 0
