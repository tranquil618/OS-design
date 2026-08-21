;==============================================================================
; OrangeOS 第二阶段引导程序（Loader）
; Boot Sector 已把本文件从 LBA 1 读到物理地址 0x9000。Loader 负责：
; 探测内存、装载 Kernel、播放启动视频、开启 A20、进入保护模式并跳转 Kernel。
;==============================================================================
org 0x9000                     ; 标签按 Loader 的实际装载地址计算
[BITS 16]                      ; BIOS 启动后 CPU 仍处于 16 位实模式

; 建立可靠的实模式环境。修改 SS:SP 时先关中断，避免中断使用不完整的栈。
cli
xor ax,ax
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0x7C00                  ; 实模式栈向低地址增长
sti

; BIOS INT 12h 返回传统内存容量（AX，单位 KiB）。放到 0x0500 传给 Kernel。
int 0x12
mov [0x0500],ax

;------------------------------------------------------------------------------
; BIOS E820 物理内存地图
; 0x0504 保存表项数量，0x0508 开始保存最多 16 条、每条 20 字节的记录：
; qword 起始地址 + qword 长度 + dword 类型（类型 1 表示可用内存）。
; EBX 是续传标识：首次为 0，BIOS 返回 0 表示没有下一项。
;------------------------------------------------------------------------------
xor ax,ax
mov es,ax                      ; BIOS 将记录写入 ES:DI
xor ebx,ebx                    ; 第一次 E820 调用必须令 EBX=0
mov di,0x0508
mov dword [0x0504],0
.e820_next:
mov eax,0xE820
mov edx,0x534D4150             ; ASCII "SMAP" 协议签名
mov ecx,20                     ; 请求传统 20 字节 E820 表项
int 0x15
jc .e820_done                  ; CF=1 表示失败或结束
cmp eax,0x534D4150             ; BIOS 返回值也必须是 "SMAP"
jne .e820_done
inc dword [0x0504]
add di,20                      ; 指向下一条记录缓冲区
cmp dword [0x0504],16
jae .e820_done
test ebx,ebx
jnz .e820_next
.e820_done:

;------------------------------------------------------------------------------
; 使用 INT 13h Extensions（AH=42h）读取 Kernel。
; kernel_dap 指定：从 LBA 2 读取 80 个扇区到 1000:0000，即物理 0x10000。
;------------------------------------------------------------------------------
xor ax,ax
mov ds,ax
mov si,kernel_dap              ; DS:SI 指向 Disk Address Packet
mov dl,0x80                    ; BIOS 第一块硬盘
mov ah,0x42
int 0x13
jc disk_error

call play_boot_video16         ; Kernel 已装入内存，现在播放 4 秒视频
call enable_a20                ; 取消 1 MiB 地址回绕

; 加载临时 GDT，设置 CR0.PE，再远跳转刷新 CS 和 CPU 预取队列。
cli                            ; 此时保护模式 IDT 尚未建立，必须保持关中断
lgdt [gdt_descriptor]
mov eax,cr0
or eax,0x00000001              ; CR0 bit 0 = PE（Protection Enable）
mov cr0,eax
jmp dword CODE_SELECTOR:protected_mode_entry

; 磁盘读取失败：通过 BIOS 显示 E 并停机。
disk_error:
    mov ah,0x0E
    mov al,'E'
    int 0x10
    jmp $

; Fast A20 Gate：端口 0x92 bit 1 开启 A20，bit 0 是快速复位位。
enable_a20:
    in al,0x92
    and al,11111110b           ; 清 bit 0，防止意外复位
    or al,00000010b            ; 置 bit 1，开启 A20
    out 0x92,al
    ret

;------------------------------------------------------------------------------
; 播放启动视频
; Mode 13h 为 320×200、每像素 1 字节，显存位于 A000:0000。
; 一帧 64000 字节 = 125 个扇区；40 帧、每帧约 100 ms，即约 10 FPS / 4 秒。
;------------------------------------------------------------------------------
play_boot_video16:
    mov ax,0x0013              ; BIOS 设置 VGA Mode 13h
    int 0x10
    mov bp,40                  ; 剩余帧数
.frame:
    ; 从视频当前 LBA 读取一帧到 2000:0000（物理地址 0x20000）。
    xor ax,ax
    mov ds,ax
    mov si,video_dap
    mov dl,0x80
    mov ah,0x42
    int 0x13
    jc disk_error

    ; 把帧缓冲区复制到 VGA 显存。
    mov ax,0x2000
    mov ds,ax
    xor si,si                   ; 源 DS:SI = 2000:0000
    mov ax,0xA000
    mov es,ax
    xor di,di                   ; 目标 ES:DI = A000:0000
    mov cx,32000
    rep movsw                   ; 32000 个 word = 64000 字节

    ; INT 15h/AH=86h 等待 CX:DX 微秒；0x000186A0=100000 微秒=100 ms。
    xor ax,ax
    mov ds,ax
    mov ah,0x86
    mov cx,0x0001
    mov dx,0x86A0
    int 0x15

    ; DAP 的 64 位 LBA 加 125，指向下一帧。
    add dword [video_dap+8],125
    adc dword [video_dap+12],0 ; 传播低 32 位产生的进位
    dec bp
    jnz .frame

    ; 视频结束，恢复 BIOS 80×25 文本模式。
    xor ax,ax
    mov ds,ax
    mov ax,0x0003
    int 0x10
    ret

align 4
; Disk Address Packet：16 字节结构，供 INT 13h/AH=42h 使用。
kernel_dap:
    db 0x10                    ; DAP 大小
    db 0                       ; 保留字段
    dw 80                      ; 80*512=40 KiB
    dw 0x0000                  ; 目标偏移
    dw 0x1000                  ; 目标段，物理地址 0x10000
    dq 2                       ; Kernel 从 LBA 2 开始

video_dap:
    db 0x10,0
    dw 125                     ; 每帧 125*512=64000 字节
    dw 0x0000,0x2000           ; 目标 2000:0000（物理 0x20000）
    dq 128                     ; 视频从 LBA 128 开始

;------------------------------------------------------------------------------
; 临时 GDT：空描述符 + Ring 0 平坦代码段 + Ring 0 平坦数据段。
; Base=0，G=1（4 KiB 粒度），Limit=0xFFFFF，因此覆盖完整 4 GiB。
; Kernel 稍后会建立包含 TSS 和 Ring 3 段的正式 GDT。
;------------------------------------------------------------------------------
gdt_start:
gdt_null:
    dq 0                       ; GDT 第 0 项必须为空

gdt_code:
    dw 0xFFFF                  ; Limit 低 16 位
    dw 0x0000                  ; Base 低 16 位
    db 0x00                    ; Base 位 16～23
    db 10011010b               ; P=1,DPL=0,S=1,代码段,可读
    db 11001111b               ; G=1,D=1,Limit 高 4 位=0xF
    db 0x00                    ; Base 位 24～31

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b               ; P=1,DPL=0,S=1,数据段,可读写
    db 11001111b
    db 0x00
gdt_end:

; LGDT 需要：2 字节 GDT 界限 + 4 字节 GDT 线性基址。
gdt_descriptor:
    dw gdt_end-gdt_start-1
    dd gdt_start

; 每个描述符 8 字节，所以代码选择子=0x08，数据选择子=0x10。
CODE_SELECTOR equ gdt_code-gdt_start
DATA_SELECTOR equ gdt_data-gdt_start

;------------------------------------------------------------------------------
; 32 位保护模式入口。此时 CR0.PE=1，CS 已由远跳转装入 CODE_SELECTOR。
;------------------------------------------------------------------------------
[BITS 32]
protected_mode_entry:
    ; 保护模式下段寄存器保存 GDT 选择子，不再是实模式段地址。
    mov ax,DATA_SELECTOR
    mov ds,ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov ss,ax
    mov esp,0x90000             ; 建立 32 位启动栈

    ; 代码段 Base=0，所以偏移 0x10000 就是 Kernel 的线性/物理入口。
    jmp dword CODE_SELECTOR:0x10000

; Loader 必须放入一个 512 字节扇区，超过 510 字节时 NASM 会直接报错。
times 510-($-$$) db 0
dw 0xAA55
